import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';

/// Firebase-backed auth layer. Keeps the exact same public API as the
/// old SharedPreferences demo version, so none of the other screens
/// (splash, profile, etc.) need to change.
///
/// Firebase Auth doesn't have a built-in "phone number" profile field,
/// so that one piece is still kept locally in SharedPreferences, keyed
/// by the user's Firebase uid, alongside real Firebase authentication
/// for everything else.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _phoneKeyPrefix = 'ev_connect_phone_';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  // ---------------------------------------------------------------------
  // Email / password
  // ---------------------------------------------------------------------

  /// Returns null on success, or an error message on failure.
  Future<String?> register(AppUser user) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: user.email,
        password: user.password ?? '',
      );
      await credential.user?.updateDisplayName(user.fullName);
      await _savePhone(credential.user!.uid, user.phone);
      return null;
    } on FirebaseAuthException catch (e) {
      return _friendlyError(e);
    }
  }

  /// Returns null on success, or an error message on failure.
  Future<String?> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return _friendlyError(e);
    }
  }

  // ---------------------------------------------------------------------
  // Google
  // ---------------------------------------------------------------------

  Future<String?> loginWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return 'Google sign-in was cancelled.';
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await _auth.signInWithCredential(credential);
      return null;
    } on FirebaseAuthException catch (e) {
      return _friendlyError(e);
    } catch (e, st) {
      // ignore: avoid_print
      print('Google sign-in error: $e\n$st');
      return 'Google sign-in failed: $e';
    }
  }

  // ---------------------------------------------------------------------
  // Password reset
  // ---------------------------------------------------------------------

  /// Sends a reset email. The link opens Firebase's hosted "Reset
  /// password" page, which has New password + Confirm password fields
  /// and enforces whatever password policy you set in the Firebase
  /// console (Authentication → Settings → Password policy).
  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      return _friendlyError(e);
    }
  }

  // ---------------------------------------------------------------------
  // Session / profile
  // ---------------------------------------------------------------------

  Future<void> logout() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }

  Future<AppUser?> currentUser() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;
    final phone = await _readPhone(firebaseUser.uid);
    return AppUser(
      fullName: firebaseUser.displayName ?? '',
      email: firebaseUser.email ?? '',
      phone: phone,
      provider: _mapProvider(firebaseUser),
    );
  }

  Future<void> updateUser(AppUser user) async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return;
    await firebaseUser.updateDisplayName(user.fullName);
    await _savePhone(firebaseUser.uid, user.phone);
  }

  Future<bool> isLoggedIn() async {
    // On app startup, Firebase needs a brief moment to restore a
    // persisted session from disk. authStateChanges() waits for that
    // first real value instead of reading currentUser too early.
    final user = await _auth
        .authStateChanges()
        .first
        .timeout(const Duration(seconds: 3), onTimeout: () => _auth.currentUser);
    return user != null;
  }

  AuthProvider _mapProvider(User firebaseUser) {
    if (firebaseUser.providerData.any((p) => p.providerId == 'google.com')) {
      return AuthProvider.google;
    }
    if (firebaseUser.providerData.any((p) => p.providerId == 'apple.com')) {
      return AuthProvider.apple;
    }
    return AuthProvider.email;
  }

  Future<void> _savePhone(String uid, String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_phoneKeyPrefix$uid', phone);
  }

  Future<String> _readPhone(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_phoneKeyPrefix$uid') ?? '';
  }

  String _friendlyError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found for that email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'weak-password':
        return 'Password does not meet the requirements.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }
}
