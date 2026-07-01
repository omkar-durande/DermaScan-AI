import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../constants/api_constants.dart';

/// Service for communicating with the FastAPI backend
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String? _authToken;

  /// Set the Firebase ID token for authenticated requests
  void setAuthToken(String? token) {
    _authToken = token;
  }

  /// Common headers
  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  /// Check server health
  Future<Map<String, dynamic>> checkHealth() async {
    try {
      final response = await http
          .get(
            Uri.parse(ApiConstants.health),
            headers: _headers,
          )
          .timeout(ApiConstants.connectTimeout);

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      throw ApiException('Server error: ${response.statusCode}');
    } on SocketException {
      throw ApiException('No internet connection');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Connection failed: $e');
    }
  }

  /// Upload image for prediction
  Future<Map<String, dynamic>> predict(File imageFile) async {
    try {
      // Validate image size
      final fileSize = await imageFile.length();
      if (fileSize > ApiConstants.maxImageSizeMB * 1024 * 1024) {
        throw ApiException(
            'Image too large. Max size: ${ApiConstants.maxImageSizeMB}MB');
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConstants.predict),
      );

      if (_authToken != null) {
        request.headers['Authorization'] = 'Bearer $_authToken';
      }

      // Determine content type
      final ext = imageFile.path.split('.').last.toLowerCase();
      final mimeType = ext == 'png'
          ? 'image/png'
          : ext == 'webp'
              ? 'image/webp'
              : 'image/jpeg';

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
          contentType: MediaType.parse(mimeType),
        ),
      );

      final streamedResponse =
          await request.send().timeout(ApiConstants.receiveTimeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 503) {
        throw ApiException('Model not loaded. Please try again later.');
      } else if (response.statusCode == 400) {
        final detail =
            (json.decode(response.body) as Map)['detail'] ?? 'Bad request';
        throw ApiException(detail.toString());
      } else {
        throw ApiException('Server error: ${response.statusCode}');
      }
    } on SocketException {
      throw ApiException('No internet connection');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Prediction failed: $e');
    }
  }

  /// Get UV index data from OpenWeatherMap
  Future<Map<String, dynamic>> getUVIndex(double lat, double lon) async {
    try {
      final url =
          '${ApiConstants.weatherApiUrl}?lat=$lat&lon=$lon&exclude=minutely,hourly&appid=${ApiConstants.weatherApiKey}';

      final response = await http
          .get(Uri.parse(url))
          .timeout(ApiConstants.connectTimeout);

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      throw ApiException('Weather API error: ${response.statusCode}');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to fetch UV data: $e');
    }
  }
}

/// Custom exception for API errors
class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}
