import 'package:firebase_auth/firebase_auth.dart';

/// Firebase Authentication service wrapper for the ANTIGRAVITY Weather App
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Stream of user authentication state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Currently logged in user
  User? get currentUser => _auth.currentUser;

  /// Sign up a new user using Email & Password
  Future<UserCredential> signUpWithEmail(String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  /// Sign in an existing user using Email & Password
  Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  /// Send password reset link to user's email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  /// Sign out the current user
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
