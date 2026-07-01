import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/scan_result.dart';
import '../models/user_model.dart';
import '../models/treatment_log.dart';


/// Service for Firestore CRUD operations
class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Users ───────────────────────────────────────────────────────

  /// Get or create user document
  Future<UserModel> getOrCreateUser(String uid,
      {String? name, String? email, String? phone, String? photoUrl}) async {
    final doc = await _db.collection('users').doc(uid).get();

    if (doc.exists) {
      return UserModel.fromFirestore(doc.data()!, uid);
    }

    // Create new user
    final user = UserModel(
      uid: uid,
      name: name,
      email: email,
      phone: phone,
      photoUrl: photoUrl,
      createdAt: DateTime.now(),
    );

    await _db.collection('users').doc(uid).set(user.toFirestore());
    return user;
  }

  /// Update user profile
  Future<void> updateUser(UserModel user) async {
    await _db.collection('users').doc(user.uid).update(user.toFirestore());
  }

  // ── Scans ───────────────────────────────────────────────────────

  /// Save a scan result
  Future<String> saveScan(ScanResult scan) async {
    final doc = await _db.collection('scans').add(scan.toFirestore());
    return doc.id;
  }

  /// Get all scans for a user (newest first) — sorted client-side to avoid composite index requirement
  Future<List<ScanResult>> getUserScans(String userId, {int? limit}) async {
    debugPrint('[FirestoreService] Fetching scans for userId: $userId');

    final snapshot = await _db
        .collection('scans')
        .where('userId', isEqualTo: userId)
        .get();

    final results = snapshot.docs
        .map((doc) =>
            ScanResult.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
        .toList();

    // Sort client-side — newest first
    results.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    debugPrint('[FirestoreService] Found ${results.length} scans');

    if (limit != null && results.length > limit) {
      return results.sublist(0, limit);
    }
    return results;
  }

  /// Get scans filtered by disease
  Future<List<ScanResult>> getScansByDisease(
      String userId, String disease) async {
    final snapshot = await _db
        .collection('scans')
        .where('userId', isEqualTo: userId)
        .where('disease', isEqualTo: disease)
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs
        .map((doc) =>
            ScanResult.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  /// Delete a scan
  Future<void> deleteScan(String scanId) async {
    await _db.collection('scans').doc(scanId).delete();
  }

  /// Get scan count for a user
  Future<int> getScanCount(String userId) async {
    final snapshot = await _db
        .collection('scans')
        .where('userId', isEqualTo: userId)
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  // ── Treatment Logs ──────────────────────────────────────────────

  /// Save a treatment log
  Future<String> saveTreatmentLog(TreatmentLog log) async {
    final doc = await _db.collection('treatments').add(log.toFirestore());
    return doc.id;
  }

  /// Get treatment logs for a user (newest first)
  Future<List<TreatmentLog>> getUserTreatmentLogs(String userId,
      {String? disease}) async {
    Query query = _db
        .collection('treatments')
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true);

    if (disease != null) {
      query = query.where('disease', isEqualTo: disease);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => TreatmentLog.fromFirestore(
            doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  /// Delete a treatment log
  Future<void> deleteTreatmentLog(String logId) async {
    await _db.collection('treatments').doc(logId).delete();
  }

  // ── Bookmarks ───────────────────────────────────────────────────

  /// Save bookmarked remedy
  Future<void> bookmarkRemedy(
      String userId, String disease, String remedyName) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('bookmarks')
        .doc('${disease}_$remedyName')
        .set({
      'disease': disease,
      'remedyName': remedyName,
      'savedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Remove bookmarked remedy
  Future<void> removeBookmark(
      String userId, String disease, String remedyName) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('bookmarks')
        .doc('${disease}_$remedyName')
        .delete();
  }

  /// Get all bookmarked remedies
  Future<List<Map<String, dynamic>>> getBookmarks(String userId) async {
    final snapshot = await _db
        .collection('users')
        .doc(userId)
        .collection('bookmarks')
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  // ── Account Deletion ────────────────────────────────────────────

  /// Delete ALL data for a user: user doc + all scans + all treatment logs
  Future<void> deleteUserData(String uid) async {
    final batch = _db.batch();

    // Delete user document
    batch.delete(_db.collection('users').doc(uid));

    // Delete all scans
    final scans = await _db.collection('scans').where('userId', isEqualTo: uid).get();
    for (final doc in scans.docs) {
      batch.delete(doc.reference);
    }

    // Delete all treatment logs
    final treatments = await _db.collection('treatments').where('userId', isEqualTo: uid).get();
    for (final doc in treatments.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }
}

