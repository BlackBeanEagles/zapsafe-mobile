import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Day 257 — Google sign-in, front half.
///
/// Runs the Google + Firebase handshake on-device and returns a Firebase ID
/// token. The backend (`POST /auth/google-verify/`) verifies that token
/// against Google's public keys and issues ZapSafe's own JWTs, so nothing
/// here is trusted on its own — this class only obtains the token.
///
/// Why this exists rather than phone OTP: DLT registration is mandatory for
/// SMS to Indian numbers, costs money up front on every operator portal, and
/// takes 1-2 weeks of approvals. Until it clears, OTP cannot be delivered at
/// all. Google sign-in has no SMS, no regulator, and Google/Apple providers
/// carry no per-use cost (unlike Firebase *phone* auth, which is metered).
class GoogleAuthService {
  GoogleAuthService({FirebaseAuth? auth, GoogleSignIn? googleSignIn})
      : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn(scopes: const ['email']);

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  /// Signs in with Google and returns a Firebase ID token.
  ///
  /// Returns null when the user cancels the picker — a cancellation is not
  /// an error and must not surface as one.
  ///
  /// Throws [GoogleAuthException] when the handshake genuinely fails.
  Future<String?> signInAndGetIdToken() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // user dismissed the picker

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final result = await _auth.signInWithCredential(credential);
      // forceRefresh: false — a token minted seconds ago is fine, and
      // forcing a refresh adds a network round trip to every sign-in.
      final idToken = await result.user?.getIdToken();
      if (idToken == null || idToken.isEmpty) {
        throw GoogleAuthException('Signed in but no ID token was returned.');
      }
      return idToken;
    } on FirebaseAuthException catch (e) {
      throw GoogleAuthException(_messageFor(e.code), code: e.code);
    } catch (e) {
      if (kDebugMode) debugPrint('[google-auth] $e');
      throw GoogleAuthException('Google sign-in failed. Please try again.');
    }
  }

  /// Clears the local Google/Firebase session.
  ///
  /// Called on logout so the next sign-in shows the account picker instead
  /// of silently reusing the previous account — on a safety app, someone
  /// handing over a phone must not stay signed in invisibly.
  Future<void> signOut() async {
    try {
      await Future.wait([_googleSignIn.signOut(), _auth.signOut()]);
    } catch (e) {
      if (kDebugMode) debugPrint('[google-auth] sign-out: $e');
    }
  }

  /// User-facing text. Deliberately does not echo Firebase's raw codes —
  /// they are developer-facing and unhelpful mid-emergency.
  @visibleForTesting
  static String messageFor(String code) => _messageFor(code);

  static String _messageFor(String code) {
    switch (code) {
      case 'account-exists-with-different-credential':
        return 'This email is already registered with a different sign-in method.';
      case 'invalid-credential':
        return 'Could not verify your Google account. Please try again.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'network-request-failed':
        return 'No internet connection. Check your network and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      default:
        return 'Google sign-in failed. Please try again.';
    }
  }
}

class GoogleAuthException implements Exception {
  GoogleAuthException(this.message, {this.code});
  final String message;
  final String? code;

  @override
  String toString() => message;
}
