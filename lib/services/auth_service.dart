import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';

/// Firebase-backed auth layer. Keeps the exact same public API as the
/// old SharedPreferences demo version, so none of the other screens
/// (splash, profile, etc.) need to change.
///
/// fullName and email live directly on the Firebase Auth user record.
/// phone and the profile photo are both stored in Cloud Firestore at
/// users/{uid} — the photo as a small base64-encoded string field
/// rather than a separate file in Cloud Storage, since Storage requires
/// the pay-as-you-go Blaze plan to enable at all (even within its free
/// tier), while Firestore works on the free Spark plan. The trade-off:
/// Firestore caps a whole document at 1MiB, so the photo is resized and
/// compressed small at capture time (see edit_profile_screen.dart) to
/// comfortably fit.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  // Old local keys — read only during the one-time migration below, for
  // any user who already had a phone/photo saved before this update.
  static const _phoneKeyPrefix = 'ev_connect_phone_';
  static const _photoKeyPrefix = 'ev_connect_photo_';

  // Leaves headroom under Firestore's 1MiB document cap for the rest of
  // the profile doc's fields (phone, etc).
  static const _maxPhotoBytes = 700 * 1024;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _profileDoc(String uid) =>
      _db.collection('users').doc(uid);

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
      final uid = credential.user!.uid;
      String? photoData = user.photoPath;
      if (photoData != null && !_isAlreadyEncoded(photoData)) {
        photoData = await _encodePhotoAsDataUri(File(photoData));
      }
      await _profileDoc(uid).set({
        'phone': user.phone,
        'photoPath': photoData,
      });
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
      final result = await _auth.signInWithCredential(credential);
      final uid = result.user?.uid;
      if (uid != null) {
        final snap = await _profileDoc(uid).get();
        if (!snap.exists) {
          await _profileDoc(uid).set({'phone': '', 'photoPath': null});
        }
      }
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
    final profile = await _readOrMigrateProfile(firebaseUser.uid);
    return AppUser(
      fullName: firebaseUser.displayName ?? '',
      email: firebaseUser.email ?? '',
      phone: profile['phone'] as String? ?? '',
      provider: _mapProvider(firebaseUser),
      photoPath: profile['photoPath'] as String?,
    );
  }

  Future<void> updateUser(AppUser user) async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return;
    await firebaseUser.updateDisplayName(user.fullName);

    String? photoData = user.photoPath;
    if (photoData != null && !_isAlreadyEncoded(photoData)) {
      // A local file path (freshly picked, not yet embedded) — encode it.
      photoData = await _encodePhotoAsDataUri(File(photoData));
    }

    await _profileDoc(firebaseUser.uid).set({
      'phone': user.phone,
      'photoPath': photoData, // null clears the saved photo
    }, SetOptions(merge: true));
  }

  /// Encodes a local photo file as a data URI so it can live directly in
  /// the Firestore profile doc. Throws if the file is too large even
  /// after the picker's own resize/compression, so the caller can show
  /// the person a clear error instead of a confusing Firestore failure.
  Future<String> _encodePhotoAsDataUri(File file) async {
    final bytes = await file.readAsBytes();
    if (bytes.length > _maxPhotoBytes) {
      throw StateError(
          'Photo is too large (${(bytes.length / 1024).round()}KB) — please choose a smaller image.');
    }
    return 'data:image/jpeg;base64,${base64Encode(bytes)}';
  }

  /// True for a photoPath already saved to Firestore (a data: URI) or,
  /// for backward compatibility, an old Firebase Storage https:// URL
  /// from before this switch — neither needs re-encoding.
  bool _isAlreadyEncoded(String photoPath) =>
      photoPath.startsWith('data:') || photoPath.startsWith('http');

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

  /// Reads the Firestore profile doc, or — for a user who already had
  /// data saved under the old per-uid SharedPreferences keys — migrates
  /// it up to Firestore once and returns that instead. New/Google users
  /// with nothing saved either way get an empty default profile.
  Future<Map<String, dynamic>> _readOrMigrateProfile(String uid) async {
    final snap = await _profileDoc(uid).get();
    if (snap.exists && snap.data() != null) return snap.data()!;

    final prefs = await SharedPreferences.getInstance();
    final data = <String, dynamic>{
      'phone': prefs.getString('$_phoneKeyPrefix$uid') ?? '',
      'photoPath': prefs.getString('$_photoKeyPrefix$uid'),
    };
    await _profileDoc(uid).set(data);
    return data;
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
