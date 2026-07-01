import 'dart:io';
import 'package:flutter/material.dart';
import '../models/scan_result.dart';
import '../services/api_service.dart';
import '../services/image_storage_service.dart';

/// Provider for scan prediction state management
class ScanProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  ScanResult? _currentResult;
  bool _isLoading = false;
  bool _isServerHealthy = false;
  String? _error;

  // Getters
  ScanResult? get currentResult => _currentResult;
  bool get isLoading => _isLoading;
  bool get isServerHealthy => _isServerHealthy;
  String? get error => _error;

  /// Check if the backend server is reachable
  Future<bool> checkServerHealth() async {
    try {
      final health = await _apiService.checkHealth();
      _isServerHealthy =
          health['status'] == 'ok' && health['model_loaded'] == true;
      notifyListeners();
      return _isServerHealthy;
    } catch (e) {
      _isServerHealthy = false;
      notifyListeners();
      return false;
    }
  }

  /// Run prediction on an image file
  Future<ScanResult?> predictImage(File imageFile, String userId) async {
    _isLoading = true;
    _error = null;
    _currentResult = null;
    notifyListeners();

    try {
      // Validate image dimensions
      final imageBytes = await imageFile.readAsBytes();
      final decodedImage = await decodeImageFromList(imageBytes);
      if (decodedImage.width < 100 || decodedImage.height < 100) {
        throw ApiException('Image is too small. Please take a clearer photo.');
      }

      final response = await _apiService.predict(imageFile);

      if (response['success'] == true) {
        // Save the image persistently to documents directory and generate base64 URI
        final storageService = ImageStorageService();
        final persistentPath = await storageService.saveImageLocally(imageFile);
        final base64Image = await storageService.compressAndEncodeToBase64(imageFile);

        _currentResult = ScanResult.fromPrediction(response, userId);
        _currentResult = ScanResult(
          id: _currentResult!.id,
          userId: _currentResult!.userId,
          disease: _currentResult!.disease,
          fullName: _currentResult!.fullName,
          severity: _currentResult!.severity,
          confidence: _currentResult!.confidence,
          allScores: _currentResult!.allScores,
          imageUrl: base64Image,
          imagePath: persistentPath,
          warning: _currentResult!.warning,
          timestamp: _currentResult!.timestamp,
        );
        _isLoading = false;
        notifyListeners();
        return _currentResult;
      } else {
        throw ApiException('Prediction failed');
      }
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      _error = 'An unexpected error occurred: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Clear current result
  void clearResult() {
    _currentResult = null;
    _error = null;
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
