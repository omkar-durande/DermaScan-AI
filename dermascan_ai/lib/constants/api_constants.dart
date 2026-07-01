/// DermaScan AI — API Configuration
class ApiConstants {
  ApiConstants._();

  // FastAPI Backend
  // Change this to your deployed URL (e.g., https://your-app.onrender.com)
  // static const String baseUrl = 'http://10.0.2.2:8000'; // Android emulator → localhost
  // static const String baseUrl = 'http://localhost:8000'; // iOS simulator
  static const String baseUrl = 'https://omkardurande-dermascan-api.hf.space'; // Hugging Face Spaces cloud backend

  // Endpoints
  static const String predict = '$baseUrl/predict';
  static const String health = '$baseUrl/health';
  static const String classes = '$baseUrl/classes';
  static const String scans = '$baseUrl/scans';

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // OpenWeatherMap (UV Index)
  // Sign up at https://openweathermap.org/api and get a free API key
  static const String weatherApiKey = 'Y7e7624d99357de2877fef6494b3a4fe4';
  static const String uvApiUrl = 'https://api.openweathermap.org/data/2.5/uvi';
  static const String weatherApiUrl =
      'https://api.openweathermap.org/data/2.5/onecall';

  // Overpass API (free, no key — real hospital data from OpenStreetMap)
  static const String overpassApiUrl =
      'https://overpass-api.de/api/interpreter';

  // Image constraints
  static const int maxImageSizeMB = 10;
  static const int minImageDimensionPx = 100;
}
