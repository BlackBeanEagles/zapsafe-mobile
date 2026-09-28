/// Day 366 — fail the build BEFORE the TLS pin dies, not after.
///
/// `CertPinning` uses `SecurityContext(withTrustedRoots: false)`, so the pin
/// callback is the only thing standing between the app and the network. A
/// stale pin does not degrade gracefully: it fails closed on every request,
/// SOS dispatch included, for every user on that build.
///
/// That is not hypothetical. The pins captured on 2026-08-08 were checked
/// against the live host on 2026-09-28 and **none of the three matched** —
/// the leaf had rotated on 2026-09-12. The class doc asked for a manual
/// re-verification before each release; it did not happen, and nothing
/// noticed. This test is that check, automated.
///
/// ## This test is designed to start failing on a date
///
/// That is the point, not flakiness. It goes red 21 days before the pinned
/// leaf expires so there is time to cut a release with fresh pins. When it
/// fails, the fix is to re-capture and update `_pinsBase64`,
/// `pinsCapturedOn` and `pinnedLeafNotAfter` — NOT to widen the window.
///
/// Re-capture with:
///   openssl s_client -connect zapsafe.app:443 -servername zapsafe.app \
///     -showcerts </dev/null 2>/dev/null \
///     | openssl x509 -outform DER | openssl dgst -sha256 -binary | base64
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/data/services/cert_pinning.dart';

void main() {
  group('TLS pin freshness', () {
    test('the pinned leaf is not within the refresh window', () {
      final now = DateTime.now().toUtc();
      final deadline = CertPinning.pinnedLeafNotAfter
          .subtract(const Duration(days: CertPinning.pinRefreshLeadDays));

      expect(
        now.isBefore(deadline),
        isTrue,
        reason: 'The pinned zapsafe.app leaf expires on '
            '${CertPinning.pinnedLeafNotAfter.toIso8601String()} and the '
            'refresh window opened on ${deadline.toIso8601String()}.\n'
            '\n'
            'CertPinning builds its HttpClient with '
            'SecurityContext(withTrustedRoots: false), so this pin is the '
            'ONLY gate — once it no longer matches, EVERY release-build API '
            'call fails closed, SOS dispatch included.\n'
            '\n'
            'Re-capture the leaf pin from the live host and update '
            '_pinsBase64, pinsCapturedOn and pinnedLeafNotAfter. Do not '
            'widen pinRefreshLeadDays to silence this.',
      );
    });

    test('pins were captured before the leaf they claim to pin expires', () {
      expect(
        CertPinning.pinsCapturedOn.isBefore(CertPinning.pinnedLeafNotAfter),
        isTrue,
        reason: 'capture date must precede the pinned leaf expiry — one of '
            'the two constants is wrong',
      );
    });

    test('the refresh lead time outruns early renewal', () {
      // Google Trust Services renewed the 2026-08-08 leaf on 2026-09-12,
      // 31 days before its 2026-10-13 expiry. A lead time shorter than that
      // would fire after the pin was already dead, which is the failure this
      // file exists to prevent.
      expect(CertPinning.pinRefreshLeadDays, greaterThanOrEqualTo(21),
          reason: 'observed early renewal was ~31 days ahead of expiry');
    });

    test('only the leaf is pinned — the callback never sees the rest', () {
      // HttpClient.badCertificateCallback is handed the PEER certificate
      // only. Intermediate and root pins can never match, so listing them
      // implies a rotation safety-margin that does not exist. The old list
      // carried all three and none of them matched the live chain.
      expect(CertPinning.pinCount, 1,
          reason: 'extra pins cannot be reached by badCertificateCallback; '
              'if multi-cert resilience is wanted it needs a different '
              'mechanism, not more entries here');
    });
  });
}
