import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Auth service — Email/Password only (100% free, no extra config needed)
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  bool get isSignedIn => currentUser != null;

  Future<String?> getIdToken() async => await currentUser?.getIdToken();

  // ── Email/Password ──────────────────────────────────────────────

  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
        email: email, password: password);
  }

  /// Send email verification to current user (Firebase sends it free)
  Future<void> sendEmailVerification() async {
    await currentUser?.sendEmailVerification();
  }

  /// Check if current user's email is verified (reload from Firebase first)
  Future<bool> isEmailVerified() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await user.reload();
        // Force refresh the ID token to ensure verification status propagates to client SDK
        await user.getIdToken(true);
      } catch (e) {
        debugPrint('[AuthService] Error reloading user verification state: $e');
        rethrow;
      }
      return _auth.currentUser?.emailVerified ?? false;
    }
    return false;
  }

  /// Delete account — deletes Firebase Auth user
  /// Call this after re-authenticating to avoid 'requires-recent-login' error
  Future<void> deleteAccount({required String password}) async {
    final user = currentUser;
    if (user == null) throw Exception('No user signed in');
    // Re-authenticate first (Firebase requires recent login for sensitive ops)
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);
    await user.delete();
  }

  /// Send a password-reset email (Firebase sends it for free)
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // ── Sign Out ────────────────────────────────────────────────────

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
