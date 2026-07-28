import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/data/services/google_auth_service.dart';

/// Day 257 — Google sign-in error surface.
///
/// The Firebase/Google handshake itself needs a device and real plugins, so
/// what is testable here is the part that actually reaches users: that raw
/// Firebase error codes never leak into the UI. Someone opening a safety app
/// in distress should not be shown
/// "account-exists-with-different-credential".
void main() {
  group('GoogleAuthException', () {
    test('carries a human message', () {
      final e = GoogleAuthException('Google sign-in failed. Please try again.');
      expect(e.toString(), 'Google sign-in failed. Please try again.');
    });

    test('optionally retains the raw code for logs, not for display', () {
      final e = GoogleAuthException('Could not verify your Google account.',
          code: 'invalid-credential');
      expect(e.code, 'invalid-credential');
      expect(e.toString(), isNot(contains('invalid-credential')));
    });
  });

  group('error messages', () {
    // The real implementation — a test against a copied mapper would prove
    // nothing about the code that actually ships.
    String msg(String code) => GoogleAuthService.messageFor(code);

    test('known codes map to plain language', () {
      expect(msg('network-request-failed'), contains('internet'));
      expect(msg('too-many-requests'), contains('Too many attempts'));
      expect(msg('user-disabled'), contains('disabled'));
      expect(msg('account-exists-with-different-credential'),
          contains('different sign-in method'));
    });

    test('unknown codes fall back to a safe generic message', () {
      expect(msg('some-new-firebase-code-2027'), 'Google sign-in failed. Please try again.');
    });

    test('no message leaks a raw firebase code', () {
      const codes = [
        'network-request-failed',
        'too-many-requests',
        'user-disabled',
        'invalid-credential',
        'account-exists-with-different-credential',
        'unknown-code',
      ];
      for (final c in codes) {
        expect(msg(c), isNot(contains(c)),
            reason: 'user-facing text must not echo the raw code');
      }
    });
  });
}
