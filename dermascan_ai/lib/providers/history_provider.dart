import 'package:flutter/material.dart';
import '../models/scan_result.dart';
import '../models/treatment_log.dart';
import '../services/firestore_service.dart';

/// Provider for scan history and treatment log state management
class HistoryProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  List<ScanResult> _scans = [];
  List<TreatmentLog> _treatmentLogs = [];
  bool _isLoading = false;
  String? _error;
  String? _filterDisease;
  int _totalScans = 0;
  bool _hasLoadedOnce = false;

  // Getters
  List<ScanResult> get scans => _filterDisease != null
      ? _scans.where((s) => s.disease == _filterDisease).toList()
      : _scans;
  List<ScanResult> get allScans => _scans;
  List<TreatmentLog> get treatmentLogs => _treatmentLogs;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get filterDisease => _filterDisease;
  int get totalScans => _totalScans;
  bool get hasLoadedOnce => _hasLoadedOnce;

  /// Get last scan date
  DateTime? get lastScanDate =>
      _scans.isNotEmpty ? _scans.first.timestamp : null;

  /// Get recent scans (last 3)
  List<ScanResult> get recentScans =>
      _scans.length > 3 ? _scans.sublist(0, 3) : _scans;

  /// Calculate streak days (consecutive days with scans)
  int get streakDays {
    if (_scans.isEmpty) return 0;
    int streak = 1;
    final now = DateTime.now();
    DateTime lastDate = DateTime(
        _scans.first.timestamp.year,
        _scans.first.timestamp.month,
        _scans.first.timestamp.day);
    final today = DateTime(now.year, now.month, now.day);

    if (lastDate != today &&
        lastDate != today.subtract(const Duration(days: 1))) {
      return 0;
    }

    for (int i = 1; i < _scans.length; i++) {
      final scanDate = DateTime(
          _scans[i].timestamp.year,
          _scans[i].timestamp.month,
          _scans[i].timestamp.day);
      if (lastDate.difference(scanDate).inDays == 1) {
        streak++;
        lastDate = scanDate;
      } else if (lastDate.difference(scanDate).inDays > 1) {
        break;
      }
    }
    return streak;
  }

  /// Load all scans for a user from Firestore
  Future<void> loadScans(String userId) async {
    if (userId.isEmpty) {
      debugPrint('[HistoryProvider] loadScans called with empty userId!');
      return;
    }

    // Skip if already loading — avoids concurrent race conditions
    if (_isLoading) {
      debugPrint('[HistoryProvider] loadScans skipped — already loading');
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      debugPrint('[HistoryProvider] Loading scans for userId: $userId');
      final scans = await _firestoreService.getUserScans(userId);
      _scans = scans;
      _totalScans = _scans.length;
      _error = null;
      _hasLoadedOnce = true;
      debugPrint('[HistoryProvider] Loaded ${_scans.length} scans');
    } catch (e) {
      _error = 'Failed to load scans: $e';
      debugPrint('[HistoryProvider] ERROR loading scans: $e');
      // Keep existing in-memory scans — don't wipe them on error
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Save a scan to Firestore and immediately add to local in-memory list
  Future<void> saveScan(ScanResult scan) async {
    if (scan.userId.isEmpty) {
      debugPrint('[HistoryProvider] saveScan called with empty userId! Scan not saved.');
      _error = 'Cannot save: user not logged in.';
      notifyListeners();
      return;
    }

    debugPrint('[HistoryProvider] Saving scan for userId: ${scan.userId}, disease: ${scan.disease}');

    // Optimistically add to the local list immediately so UI updates right away
    _scans.insert(0, scan);
    _totalScans++;
    notifyListeners();

    try {
      final docId = await _firestoreService.saveScan(scan);
      debugPrint('[HistoryProvider] Scan saved to Firestore with docId: $docId');

      // Update the scan in the local list with the real Firestore doc ID
      final index = _scans.indexOf(scan);
      if (index != -1) {
        _scans[index] = ScanResult(
          id: docId,
          userId: scan.userId,
          disease: scan.disease,
          fullName: scan.fullName,
          severity: scan.severity,
          confidence: scan.confidence,
          allScores: scan.allScores,
          imageUrl: scan.imageUrl,
          imagePath: scan.imagePath,
          warning: scan.warning,
          notes: scan.notes,
          timestamp: scan.timestamp,
        );
      }
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to save to cloud (scan kept locally): $e';
      debugPrint('[HistoryProvider] ERROR saving scan to Firestore: $e');
      // Keep in local list even if Firestore failed
      notifyListeners();
    }
  }

  /// Delete a scan
  Future<void> deleteScan(String scanId) async {
    try {
      await _firestoreService.deleteScan(scanId);
      _scans.removeWhere((s) => s.id == scanId);
      _totalScans--;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to delete scan: $e';
      debugPrint('[HistoryProvider] ERROR deleting scan: $e');
      notifyListeners();
    }
  }

  /// Set disease filter
  void setFilter(String? disease) {
    _filterDisease = disease;
    notifyListeners();
  }

  /// Load treatment logs
  Future<void> loadTreatmentLogs(String userId, {String? disease}) async {
    try {
      _treatmentLogs = await _firestoreService.getUserTreatmentLogs(
        userId,
        disease: disease,
      );
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load treatment logs: $e';
      debugPrint('[HistoryProvider] ERROR loading treatment logs: $e');
      notifyListeners();
    }
  }

  /// Save a treatment log
  Future<void> saveTreatmentLog(TreatmentLog log) async {
    try {
      await _firestoreService.saveTreatmentLog(log);
      _treatmentLogs.insert(0, log);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to save treatment log: $e';
      debugPrint('[HistoryProvider] ERROR saving treatment log: $e');
      notifyListeners();
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
