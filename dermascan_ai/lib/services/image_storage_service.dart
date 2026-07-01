import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Service to handle local persistent image copying and base64 compression for Firestore.
class ImageStorageService {
  static final ImageStorageService _instance = ImageStorageService._internal();
  factory ImageStorageService() => _instance;
  ImageStorageService._internal();

  /// Copies a temporary/cached image file to the application's persistent documents directory.
  /// Returns the path to the persistent file.
  Future<String> saveImageLocally(File tempFile) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final String filename = 'scan_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String persistentPath = '${directory.path}/$filename';
      
      final File persistentFile = await tempFile.copy(persistentPath);
      debugPrint('[ImageStorageService] Saved image persistently at: ${persistentFile.path}');
      return persistentFile.path;
    } catch (e) {
      debugPrint('[ImageStorageService] Error saving image locally: $e');
      // If copying fails, return the original temp path as a fallback
      return tempFile.path;
    }
  }

  /// Helper to run image resizing and base64 encoding on a background thread or asynchronously.
  /// Returns a base64 data URI string suitable for storing directly in Firestore (approx 50-150KB).
  Future<String?> compressAndEncodeToBase64(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      
      // Decode image
      final img.Image? decodedImage = img.decodeImage(bytes);
      if (decodedImage == null) return null;

      // Resize the image so that it fits nicely inside the 1MB Firestore document limit
      // A width of 400px preserves details for classification view while keeping size tiny (~40-80KB)
      final img.Image resizedImage = img.copyResize(decodedImage, width: 400);

      // Encode as compressed JPEG (75% quality is optimal)
      final List<int> compressedBytes = img.encodeJpg(resizedImage, quality: 75);

      // Encode as Base64 Data URI
      final String base64Content = base64Encode(compressedBytes);
      return 'data:image/jpeg;base64,$base64Content';
    } catch (e) {
      debugPrint('[ImageStorageService] Error compressing/encoding image: $e');
      return null;
    }
  }
}
