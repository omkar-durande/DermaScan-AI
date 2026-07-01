import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service for GPS location and permissions
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Position? _lastPosition;

  /// Get last known position
  Position? get lastPosition => _lastPosition;

  /// Check and request location permission
  Future<bool> requestPermission() async {
    final status = await Permission.location.request();
    return status.isGranted;
  }

  /// Check if location permission is granted
  Future<bool> hasPermission() async {
    final status = await Permission.location.status;
    return status.isGranted;
  }

  /// Get current position
  Future<Position?> getCurrentPosition() async {
    try {
      final hasPerms = await requestPermission();
      if (!hasPerms) return null;

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      _lastPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return _lastPosition;
    } catch (e) {
      return null;
    }
  }

  /// Calculate distance between two points (in km)
  double distanceBetween(
      double startLat, double startLon, double endLat, double endLon) {
    return Geolocator.distanceBetween(startLat, startLon, endLat, endLon) /
        1000;
  }

  /// Get UV level label from index
  static String getUVLabel(double uvIndex) {
    if (uvIndex <= 2) return 'Low';
    if (uvIndex <= 5) return 'Moderate';
    if (uvIndex <= 7) return 'High';
    if (uvIndex <= 10) return 'Very High';
    return 'Extreme';
  }

  /// Get protection advice based on UV index
  static String getProtectionAdvice(double uvIndex) {
    if (uvIndex <= 2) {
      return 'Minimal protection needed. Enjoy the outdoors!';
    }
    if (uvIndex <= 5) {
      return 'Wear sunscreen SPF 30+. Seek shade during midday hours.';
    }
    if (uvIndex <= 7) {
      return 'Apply SPF 50+ sunscreen. Wear protective clothing and a hat.';
    }
    if (uvIndex <= 10) {
      return 'Avoid sun exposure 10am-4pm. SPF 50+ required. Wear UV-blocking sunglasses.';
    }
    return 'DANGER: Stay indoors if possible. Full sun protection required.';
  }
}
