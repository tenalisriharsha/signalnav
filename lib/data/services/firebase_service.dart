/// SignalNav - Firebase Service
///
/// Handles Auth, Firestore, and Cloud Functions initialization.
/// Supports anonymous auth and Google Sign-In only.
/// No Facebook to reduce data exposure.

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/errors.dart';
import '../../core/logger.dart';

/// Firebase service singleton.
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  bool _initialized = false;
  FirebaseAuth get auth => FirebaseAuth.instance;
  FirebaseFirestore get firestore => FirebaseFirestore.instance;
  FirebaseFunctions get functions => FirebaseFunctions.instance;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
  );

  bool get isInitialized => _initialized;

  /// Initialize Firebase. Must be called before any other Firebase operations.
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await Firebase.initializeApp();
      _initialized = true;
      logInfo(LogCategory.lifecycle, 'Firebase initialized');
    } catch (e, st) {
      logError(LogCategory.lifecycle, 'Firebase init failed: $e');
      throw BackendException(
        'Failed to initialize backend services',
        stackTrace: st,
      );
    }
  }

  /// Current authenticated user, or null.
  User? get currentUser => auth.currentUser;

  /// Stream of auth state changes.
  Stream<User?> get authStateChanges => auth.authStateChanges();

  /// Sign in anonymously. Used for crowdsourcing without requiring account creation.
  Future<User> signInAnonymously() async {
    _assertInitialized();
    try {
      final result = await auth.signInAnonymously();
      final user = result.user!;
      logInfo(LogCategory.lifecycle, 'Anonymous sign-in: ${user.uid}');
      return user;
    } on FirebaseAuthException catch (e, st) {
      logError(LogCategory.lifecycle, 'Anonymous sign-in failed: ${e.code}');
      throw BackendException(
        'Authentication failed: ${e.message}',
        code: e.code,
        stackTrace: st,
      );
    }
  }

  /// Sign in with Google. One-tap OAuth.
  Future<User> signInWithGoogle() async {
    _assertInitialized();
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw const PermissionException('Google sign-in was cancelled');
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final result = await auth.signInWithCredential(credential);
      final user = result.user!;
      logInfo(LogCategory.lifecycle, 'Google sign-in: ${user.uid}');
      return user;
    } on FirebaseAuthException catch (e, st) {
      logError(LogCategory.lifecycle, 'Google sign-in failed: ${e.code}');
      throw BackendException(
        'Google sign-in failed: ${e.message}',
        code: e.code,
        stackTrace: st,
      );
    }
  }

  /// Sign out current user.
  Future<void> signOut() async {
    _assertInitialized();
    try {
      await _googleSignIn.signOut();
      await auth.signOut();
      logInfo(LogCategory.lifecycle, 'User signed out');
    } catch (e, st) {
      logError(LogCategory.lifecycle, 'Sign out failed: $e');
      throw BackendException('Sign out failed', stackTrace: st);
    }
  }

  /// Delete the current user's account.
  /// Submits a deletion request to the backend queue (processed by GitHub Actions).
  /// This is a GDPR/CCPA requirement.
  Future<void> deleteAccount() async {
    _assertInitialized();
    final user = currentUser;
    if (user == null) {
      throw const ValidationException('No user is currently signed in');
    }

    try {
      // Submit deletion request to queue for backend processing
      await firestore.collection('deletion_requests').doc(user.uid).set({
        'uid': user.uid,
        'device_hash': _hashUid(user.uid),
        'status': 'pending',
        'requested_at': DateTime.now().toUtc(),
      });

      // Delete the auth account
      await user.delete();
      logInfo(LogCategory.privacy, 'User account deleted: ${user.uid}');
    } on FirebaseAuthException catch (e, st) {
      if (e.code == 'requires-recent-login') {
        throw const PermissionException(
          'Please sign in again to confirm account deletion',
        );
      }
      throw BackendException(
        'Account deletion failed: ${e.message}',
        code: e.code,
        stackTrace: st,
      );
    }
  }

  /// Request data export for GDPR/CCPA.
  /// Returns profile data available client-side.
  Future<Map<String, dynamic>> exportUserData() async {
    _assertInitialized();
    final user = currentUser;
    if (user == null) {
      throw const ValidationException('No user is currently signed in');
    }

    try {
      final userDocs = await firestore
          .collection('users')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      final profile = userDocs.docs.isNotEmpty ? userDocs.docs.first.data() : {};

      // Note: signal reports are server-side only (privacy).
      // A full export including reports requires backend access.
      // This returns the profile data the user can access client-side.
      logInfo(LogCategory.privacy, 'User data exported: ${user.uid}');
      return {
        'profile': profile,
        'exported_at': DateTime.now().toUtc().toIso8601String(),
        'note': 'Signal reports are anonymized and stored server-side. '
                'Full report history requires admin access.',
      };
    } catch (e, st) {
      throw BackendException(
        'Data export failed',
        stackTrace: st,
      );
    }
  }

  String _hashUid(String uid) {
    // Simple hash for device_hash consistency
    // In production, use the same algorithm as PrivacyAnonymizer
    return uid.substring(0, uid.length > 16 ? 16 : uid.length);
  }

  void _assertInitialized() {
    if (!_initialized) {
      throw const BackendException(
        'Firebase not initialized. Call initialize() first.',
      );
    }
  }
}
