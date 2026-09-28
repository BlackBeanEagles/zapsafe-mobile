import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Real TLS certificate pinning for ZapSafe's production API host (LP —
/// see day181_cert_pinning_screen.dart / Day 336-361's MSTG-NETWORK-1
/// finding this fixes).
///
/// Was: day181_cert_pinning_screen.dart's `buildPinnedDio()` /
/// `CertPinningInterceptor` only ever existed inside a *string literal*
/// code-preview sample, with placeholder pin values
/// ('sha256/AAAAAABBBBBBCCCCCCDDDDDDEEEEEEFFFFFFGGGGGG='). The app's real
/// Dio clients (api_client.dart, compatibility_service.dart) built plain
/// `Dio(BaseOptions(...))` with no badCertificateCallback, no
/// HttpClientAdapter override — a real Day 336/361 P0 finding (MITM not
/// blocked).
///
/// ── Why `badCertificateCallback` alone (the demo string's approach)
///    does NOT actually implement pinning ──────────────────────────────
/// `HttpClient.badCertificateCallback` is only invoked for certificates
/// that FAIL the platform's normal CA-trust validation. For zapsafe.app's
/// real, publicly-trusted certificate (issued by Google Trust Services),
/// that validation already succeeds — so a plain `badCertificateCallback`
/// override is never even called, and a MITM presenting any other
/// CA-trusted (but wrong) certificate would sail through untouched. This
/// is the standard, documented reason the demo string's own approach
/// wouldn't have worked even if it had been real code.
///
/// The real fix: construct the [HttpClient] with
/// `SecurityContext(withTrustedRoots: false)` — an empty trust store, so
/// EVERY certificate is "untrusted" by default and `badCertificateCallback`
/// is invoked on every single connection, handing full control to our own
/// pin check below.
///
/// ── Real pins ────────────────────────────────────────────────────────
/// Computed by live-connecting to zapsafe.app (`openssl s_client`) and
/// hashing each certificate in the real chain (SHA-256 of the full DER,
/// base64-encoded — dart:io's X509Certificate exposes `.der` and `.sha1`
/// but no built-in SHA-256, so it's computed here via package:crypto).
/// All three real chain certs are pinned (leaf + intermediate + root),
/// not just the leaf:
///   - The leaf (CN=zapsafe.app) is short-lived (~90 days, Cloudflare/
///     Google-managed auto-rotation) and WILL go stale — pinning it
///     alone would eventually hard-break all API traffic.
///   - The intermediate (Google Trust Services "WE1") and root (GTS
///     Root R4) are far more stable, but Cloudflare is known to serve
///     certs from more than one CA pool over time, so even these are
///     not permanently guaranteed.
/// Any ONE match (leaf OR intermediate OR root) is accepted — this is
/// the standard multi-pin approach, trading a little precision for
/// real resilience against routine cert rotation.
///
/// ⚠️ OPERATIONAL RISK — read before shipping: these pins were captured
/// on 2026-08-08 and are baked into the app binary. If zapsafe.app's
/// certificate chain changes to a CA/intermediate outside this pinned
/// set before an app update ships with refreshed pins, EVERY API call
/// (including SOS dispatch) will fail closed for every user on affected
/// builds — a real, severe risk for a safety app. Re-verify these pins
/// immediately before each Play Store release
/// (`openssl s_client -connect zapsafe.app:443 -showcerts`), and treat
/// "pin refresh" as a release-blocking checklist item, not an
/// afterthought. Not build/device-verified in this sandbox (no working
/// Gradle/Xcode toolchain) — the pin values themselves ARE real and
/// live-verified against the production host, but the actual TLS
/// handshake behavior on a real device has not been.
class CertPinning {
  CertPinning._();

  /// Only pin the real production API host. Local dev backends
  /// (10.0.2.2, localhost) intentionally skip pinning entirely — those
  /// only run over plain HTTP or self-signed certs during development,
  /// and pinning them would just break `flutter run` for every
  /// contributor.
  static const _pinnedHost = 'zapsafe.app';

  /// Date the pins below were captured from the live host. Paired with
  /// [pinnedLeafNotAfter] by `test/cert_pinning_staleness_test.dart`, which
  /// FAILS the build before the cert rotates rather than after.
  static final DateTime pinsCapturedOn = DateTime.utc(2026, 9, 28);

  /// `notAfter` of the pinned leaf. The staleness test fails once the build
  /// date is within [pinRefreshLeadDays] of this.
  static final DateTime pinnedLeafNotAfter = DateTime.utc(2026, 12, 11);

  /// How long before leaf expiry the staleness test starts failing.
  ///
  /// 21 days, because Google Trust Services renews ~30 days early: the
  /// 2026-08-08 pins were killed by a rotation on **2026-09-12**, more than
  /// a month before that leaf's own 2026-10-13 expiry. Keying the alarm to
  /// expiry alone would therefore have fired far too late.
  static const int pinRefreshLeadDays = 21;

  /// SHA-256(DER) of the zapsafe.app leaf, re-captured **2026-09-28**.
  ///
  /// ## Day 366 — the previous pin set was DEAD, and the app was failing closed
  ///
  /// The 2026-08-08 pins were verified against the live host on 2026-09-28
  /// and **none of the three matched**. The leaf had rotated on 2026-09-12
  /// (valid 2026-09-12 → 2026-12-11). Because [buildPinnedHttpClient] uses
  /// `SecurityContext(withTrustedRoots: false)`, the pin callback is the
  /// ONLY gate — so every release-build HTTPS call to zapsafe.app, SOS
  /// dispatch included, would have failed. The class doc above predicted
  /// exactly this and asked for a pre-release re-verification that did not
  /// happen; the staleness test now does it automatically.
  ///
  /// ## Only the LEAF is pinned now, because only the leaf is ever checked
  ///
  /// The old list carried intermediate and root pins and the doc above
  /// describes accepting "any ONE match (leaf OR intermediate OR root)" as
  /// resilience against rotation. **That cannot work with this API.**
  /// `HttpClient.badCertificateCallback` receives the PEER (leaf)
  /// certificate only — the intermediate and root are never passed to it,
  /// so those two pins could never match anything and contributed no
  /// resilience whatsoever. Keeping them implied a safety margin that did
  /// not exist, which is worse than having none.
  ///
  /// The live intermediate is recorded below for operators, not as a pin:
  ///   CN=WE1, O=Google Trust Services  —  expires 2029-02-20
  ///   SHA-256(DER) oof/q3Ysxpom1IIDft9wH2U86JkCXGKn5cuIu5tBnLs=
  /// (Note it does not match the old "intermediate" pin either, so that
  /// entry was wrong independently of the leaf rotation.)
  ///
  /// ## This is now a ~quarterly maintenance obligation
  ///
  /// A 90-day leaf renewed 30 days early means this pin dies roughly every
  /// two months. Pinning the leaf with `withTrustedRoots: false` buys real
  /// MITM resistance and costs a release-blocking chore; for a safety app
  /// the failure mode is "no SOS at all", so if that chore is ever missed
  /// the right answer is to drop pinning, not to ship a stale pin.
  static const List<String> _pinsBase64 = [
    'AB8vhGEpDK4VExFtzJK+wHJFG/5mIKxHb24ixyrVpHM=', // leaf: CN=zapsafe.app (2026-09-12 → 2026-12-11)
  ];

  /// Number of pins actually enforced. Exposed for
  /// 47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU=, which asserts this stays at 1:
  /// badCertificateCallback only ever receives the leaf, so additional
  /// entries cannot match and would imply a safety margin that is not real.
  static int get pinCount => _pinsBase64.length;

  static bool _matchesPin(X509Certificate cert) {
    final hash = base64.encode(sha256.convert(cert.der).bytes);
    return _pinsBase64.contains(hash);
  }

  /// Builds an [HttpClient] for talking to [baseUrl].
  ///
  /// The decision to enable pinning is made ONCE here, at client
  /// construction — not per-request — because a single client (and the
  /// [Dio] instance built on top of it) only ever talks to the one host
  /// [baseUrl] was configured with for its entire lifetime in this app
  /// (ApiConfig.baseUrl is fixed for the process, not re-pointed
  /// mid-session). That makes it safe to fully switch strategy per
  /// client rather than needing to (unsafely, error-pronely) hand-roll
  /// real CA-chain validation inside the callback for non-pinned hosts:
  ///
  /// - [baseUrl]'s host is the real production host AND this is a
  ///   release build: use `SecurityContext(withTrustedRoots: false)` +
  ///   a real pin-check callback (the only way `badCertificateCallback`
  ///   fires for an otherwise-valid cert — see class doc). Every
  ///   connection this client makes is pin-enforced.
  /// - Anything else (dev IPs, localhost, staging override, debug
  ///   builds): the default [HttpClient()] with no callback override at
  ///   all — identical to what plain `Dio()` already did before this
  ///   change, i.e. normal OS/CA-trust-store validation. This is not a
  ///   downgrade; it's simply not pinning environments that were never
  ///   pinned, exactly as before.
  static HttpClient buildPinnedHttpClient(String baseUrl) {
    final host = Uri.tryParse(baseUrl)?.host;
    final shouldPin = !kDebugMode && host == _pinnedHost;

    if (!shouldPin) return HttpClient();

    final context = SecurityContext(withTrustedRoots: false);
    final client = HttpClient(context: context);
    client.badCertificateCallback = (cert, host, port) => _matchesPin(cert);
    return client;
  }
}
