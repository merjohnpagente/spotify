import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Thrown when Google sign-in cannot start because Firebase/Play Services
/// are not available on this platform or misconfigured.
class GoogleSignInUnavailableException implements Exception {
  final String message;
  const GoogleSignInUnavailableException(this.message);

  @override
  String toString() => message;
}

/// Signs the user in with their Google/Gmail account via Firebase
/// and returns a Firebase ID token to exchange with our backend.
class GoogleAuthService {
  // Web client ID from android/app/google-services.json (oauth_client, type 3).
  static const String _webClientId =
      '128394834246-fr2b1hk88mjs520bnl5qoh0pnkho8gua.apps.googleusercontent.com';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: _webClientId,
  );

  void _ensureAvailable() {
    final platform = defaultTargetPlatform;
    if (kIsWeb || (platform != TargetPlatform.android && platform != TargetPlatform.iOS)) {
      throw const GoogleSignInUnavailableException(
        'Google sign-in is only available on Android and iOS.',
      );
    }
    try {
      Firebase.app();
    } catch (_) {
      throw const GoogleSignInUnavailableException(
        'Firebase is not initialized. Check google-services.json in android/app/.',
      );
    }
  }

  /// Returns a Firebase ID token, or null if the user closed the dialog.
  Future<String?> getIdToken() async {
    _ensureAvailable();

    final account = await _googleSignIn.signIn();
    if (account == null) return null; // user cancelled

    final googleAuth = await account.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
    final user = userCredential.user;
    if (user == null) {
      throw Exception('Firebase sign-in returned no user');
    }

    return user.getIdToken();
  }

  /// Fully signs out of both the Google account picker session and Firebase.
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Best-effort
    }
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      // Best-effort - Firebase may not be configured on this platform
    }
  }
}
