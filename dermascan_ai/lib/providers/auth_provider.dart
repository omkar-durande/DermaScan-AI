import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/api_service.dart';

/// Auth provider — Email/Password only
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final ApiService _apiService = ApiService();

  UserModel? _user;
  bool _isLoading = false;
  String? _error;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _authService.isSignedIn;
  String? get uid => _authService.currentUser?.uid;

  Future<void> initialize() async {
    listenToAuthChanges();
    final firebaseUser = _authService.currentUser;
    if (firebaseUser != null) await _loadUserProfile(firebaseUser);
  }

  void listenToAuthChanges() {
    _authService.authStateChanges.listen((user) async {
      if (user != null) {
        await _loadUserProfile(user);
      } else {
        _user = null;
        notifyListeners();
      }
    });
  }

  Future<void> _loadUserProfile(User firebaseUser) async {
    try {
      _user = await _firestoreService.getOrCreateUser(
        firebaseUser.uid,
        name: firebaseUser.displayName,
        email: firebaseUser.email,
        phone: firebaseUser.phoneNumber,
        photoUrl: firebaseUser.photoURL,
      );
      final token = await _authService.getIdToken();
      _apiService.setAuthToken(token);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load profile: $e';
      notifyListeners();
    }
  }

  // ── Sign Up ────────────────────────────────────────────────────

  Future<bool> signUpWithEmail(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final credential = await _authService.signUpWithEmail(
          email: email, password: password);
      if (credential.user != null) {
        // Send verification email immediately after account creation
        await _authService.sendEmailVerification();
        await _loadUserProfile(credential.user!);
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _friendlyError(e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString().replaceFirst(RegExp(r'\[.*\]\s*'), '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ── Sign In ────────────────────────────────────────────────────

  Future<bool> signInWithEmail(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final credential = await _authService.signInWithEmail(
          email: email, password: password);
      if (credential.user != null) await _loadUserProfile(credential.user!);
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _friendlyError(e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString().replaceFirst(RegExp(r'\[.*\]\s*'), '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ── Email Verification ─────────────────────────────────────────

  /// Resend verification email to current user
  Future<bool> sendEmailVerification() async {
    try {
      await _authService.sendEmailVerification();
      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'too-many-requests') {
        _error = 'Verification requests are temporarily blocked because of too many requests. Please wait a minute before requesting another.';
      } else {
        _error = e.message ?? 'Failed to send verification email.';
      }
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Could not send email: $e';
      notifyListeners();
      return false;
    }
  }

  /// Poll Firebase to check if the email link has been clicked
  Future<bool> checkEmailVerified() async {
    try {
      final firebaseUser = _authService.currentUser;
      if (firebaseUser == null) return false;

      // Skip email verification if the user signed up using their phone number
      // (which generates a fallback email address ending with '@dermascan.com')
      final email = firebaseUser.email ?? '';
      if (email.endsWith('@dermascan.com') || email.isEmpty) {
        return true;
      }

      final verified = await _authService.isEmailVerified();
      if (verified) {
        // Load/refresh user profile in Firestore
        await _loadUserProfile(firebaseUser);
      }
      return verified;
    } catch (e) {
      debugPrint('[AuthProvider] Error in checkEmailVerified: $e');
      if (e is FirebaseAuthException && e.code == 'too-many-requests') {
        _error = 'Too many requests. Please wait a minute before checking again.';
      } else {
        _error = e.toString();
      }
      notifyListeners();
      rethrow;
    }
  }

  // ── Delete Account ─────────────────────────────────────────────

  Future<bool> deleteAccount({required String password}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final user = _authService.currentUser;
      if (user == null) throw Exception('No user signed in');
      final uid = user.uid;

      // 1. Re-authenticate first to ensure session is fresh before deleting
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);

      // 2. Delete Firestore user document + scan history while still authenticated
      await _firestoreService.deleteUserData(uid);

      // 3. Delete the Firebase Auth user
      await user.delete();

      _user = null;
      _apiService.setAuthToken(null);
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _friendlyError(e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Failed to delete account: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ── Forgot Password ────────────────────────────────────────────

  Future<bool> sendPasswordResetEmail(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _authService.sendPasswordResetEmail(email.trim());
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _friendlyError(e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Failed to send reset email: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ── Profile ────────────────────────────────────────────────────

  Future<void> updateProfile(UserModel updatedUser) async {
    try {
      await _firestoreService.updateUser(updatedUser);
      _user = updatedUser;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to update profile: $e';
      notifyListeners();
    }
  }

  // ── Sign Out ───────────────────────────────────────────────────

  Future<void> signOut() async {
    await _authService.signOut();
    _user = null;
    _apiService.setAuthToken(null);
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ── Helpers ────────────────────────────────────────────────────

  String _friendlyError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}
