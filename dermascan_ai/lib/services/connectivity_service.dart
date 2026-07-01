import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Connectivity service — monitors internet and backend availability
class ConnectivityService extends ChangeNotifier {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  bool _isOnline = true;
  Timer? _checkTimer;

  bool get isOnline => _isOnline;

  /// Start periodic connectivity monitoring (every 10 seconds)
  void startMonitoring() {
    _checkOnce();
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(const Duration(seconds: 10), (_) => _checkOnce());
  }

  void stopMonitoring() {
    _checkTimer?.cancel();
    _checkTimer = null;
  }

  Future<void> _checkOnce() async {
    final wasOnline = _isOnline;
    _isOnline = await _hasInternet();
    if (_isOnline != wasOnline) {
      notifyListeners();
    }
  }

  /// Force an immediate check and return the result
  Future<bool> checkNow() async {
    _isOnline = await _hasInternet();
    notifyListeners();
    return _isOnline;
  }

  Future<bool> _hasInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    super.dispose();
  }
}
