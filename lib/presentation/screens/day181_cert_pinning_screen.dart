/// Day 181 — Certificate Pinning & TLS Security
///
/// First day of Section C: Security Hardening (Days 181-190).
/// All of Section C is 🟢 FRONTEND-ONLY — no backend API changes needed.
///
/// Days 181-182: Certificate Pinning + Network Security Config.
/// Day 181: Cert-pinning status, SHA-256 pin hashes, connection
///           test simulation, Dio implementation code, pin rotation plan.
/// Day 182: Android Network Security Config + iOS ATS + proxy detection.
///
/// 🟢 FRONTEND-ONLY — certificate pinning runs entirely on the client.
///    The server certificate public key hash is compiled into the app binary.
///    No API call needed — the Dio interceptor handles validation locally.
///
/// Why ZapSafe needs cert pinning:
///   SOS events transmit location + contacts to api.zapsafe.app.
///   Evidence vault audio/video is uploaded over HTTPS.
///   A MITM attacker with a rogue CA cert could intercept these without pinning.
///   Pinning ensures ONLY ZapSafe's known certificate is accepted.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _d181TabProvider       = StateProvider<int>((ref) => 0);
final _testStateProvider     = StateProvider<_TestState>((ref) => _TestState.idle);
final _testResultsProvider   = StateProvider<List<_TestResult>>((ref) => []);
final _expandedPinProvider   = StateProvider<int?>((ref) => null);
final _expandedCodeProvider  = StateProvider<int?>((ref) => null);

enum _TestState { idle, testing, done }

// ── Data ───────────────────────────────────────────────────────────────────────
class _PinnedDomain {
  final String   domain;
  final String   purpose;
  final String   sha256Pin;         // primary pin
  final String   backupPin;         // backup for rotation
  final String   certExpiry;
  final String   certSubject;
  final Color    color;
  final bool     pinActive;
  const _PinnedDomain({
    required this.domain, required this.purpose,
    required this.sha256Pin, required this.backupPin,
    required this.certExpiry, required this.certSubject,
    required this.color, this.pinActive = true,
  });
}

const _kDomains = [
  _PinnedDomain(
    domain: 'api.zapsafe.app',
    purpose: 'Primary REST API — SOS dispatch, auth, account management',
    sha256Pin: 'sha256/AAAAAABBBBBBCCCCCCDDDDDDEEEEEEFFFFFFGGGGGG=',
    backupPin: 'sha256/HHHHHHIIIIIIJJJJJJKKKKKKLLLLLLMMMMMMNNNNNNN=',
    certExpiry: 'March 15, 2027',
    certSubject: 'CN=api.zapsafe.app, O=ZapSafe Pvt Ltd, C=IN',
    color: Color(0xFF10B981),
  ),
  _PinnedDomain(
    domain: 'exports.zapsafe.app',
    purpose: 'Data export downloads — presigned S3 proxied through CDN',
    sha256Pin: 'sha256/OOOOOOPPPPPPQQQQQQRRRRRRSSSSSSTTTTTTUUUUUU=',
    backupPin: 'sha256/VVVVVVWWWWWWXXXXXXYYYYYYYYZZZZZZ000000111=',
    certExpiry: 'June 1, 2027',
    certSubject: 'CN=exports.zapsafe.app, O=ZapSafe Pvt Ltd, C=IN',
    color: Color(0xFF8B5CF6),
  ),
  _PinnedDomain(
    domain: 'sentry.io',
    purpose: 'Crash reporting — only active if crash_reporting consent is ON',
    sha256Pin: 'sha256/2222222333333344444445555555666666677777=',
    backupPin: 'sha256/8888888999999AAAAAABBBBBBBCCCCCCDDDDDDE=',
    certExpiry: 'December 3, 2026',
    certSubject: 'CN=sentry.io, O=Functional Software Inc, C=US',
    color: Color(0xFFF59E0B),
    pinActive: false,   // intentionally not pinned — third-party rotates frequently
  ),
];

class _TestResult {
  final String  domain;
  final bool    passed;
  final String  detail;
  final Color   color;
  const _TestResult({
    required this.domain, required this.passed,
    required this.detail, required this.color,
  });
}

class _CodeSnippet {
  final String title, language, code;
  const _CodeSnippet({required this.title, required this.language, required this.code});
}

const _kSnippets = [
  _CodeSnippet(
    title: 'Dio pinning interceptor',
    language: 'dart',
    code: '''// pubspec.yaml: dio: ^5.4.3

import 'dart:io';
import 'package:dio/dio.dart';

class CertPinningInterceptor extends Interceptor {
  // SHA-256 hashes of the SubjectPublicKeyInfo (SPKI) bytes.
  // Generate with: openssl s_client -connect api.zapsafe.app:443 |
  //   openssl x509 -pubkey -noout | openssl pkey -pubin -outform der |
  //   openssl dgst -sha256 -binary | base64
  static const _pins = {
    'api.zapsafe.app': [
      'AAAAAABBBBBBCCCCCCDDDDDDEEEEEEFFFFFFGGGGGG=', // primary
      'HHHHHHIIIIIIJJJJJJKKKKKKLLLLLLMMMMMMNNNNNNN=', // backup
    ],
    'exports.zapsafe.app': [
      'OOOOOOPPPPPPQQQQQQRRRRRRSSSSSSTTTTTTUUUUUU=',
      'VVVVVVWWWWWWXXXXXXYYYYYYYYZZZZZZ000000111=',
    ],
  };

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Note: cert pinning is handled at the HttpClient level below.
    // This interceptor just enforces HTTPS for all requests.
    assert(options.uri.scheme == 'https',
        'All ZapSafe requests must use HTTPS');
    handler.next(options);
  }
}

// In main.dart — build the Dio client with a custom HttpClient
Dio buildPinnedDio() {
  final httpClient = HttpClient()
    ..badCertificateCallback = (X509Certificate cert, String host, int port) {
      final pins = CertPinningInterceptor._pins[host];
      if (pins == null) return false; // unknown host → reject
      // Compare cert public key hash against pins
      final spkiHash = _spkiSha256(cert);
      return pins.contains(spkiHash);
    };

  return Dio()
    ..httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () => httpClient)
    ..interceptors.add(CertPinningInterceptor());
}

String _spkiSha256(X509Certificate cert) {
  // Extract Subject Public Key Info and hash it.
  // Implementation uses dart:crypto + X.509 parsing.
  // Full implementation: lib/services/cert_pinning.dart
  throw UnimplementedError('see cert_pinning.dart');
}''',
  ),
  _CodeSnippet(
    title: 'Extract pin hash from server (CLI)',
    language: 'bash',
    code: r'''# Get the SHA-256 SPKI hash for api.zapsafe.app
# Run this when you update certificates (before each deploy)

openssl s_client -connect api.zapsafe.app:443 \
  -servername api.zapsafe.app \
  < /dev/null 2>/dev/null \
  | openssl x509 -pubkey -noout \
  | openssl pkey -pubin -outform der \
  | openssl dgst -sha256 -binary \
  | base64

# Output example:
# AAAAAABBBBBBCCCCCCDDDDDDEEEEEEFFFFFFGGGGGG=
#
# Add to CertPinningInterceptor._pins in main.dart
# Ship a backup hash (from the next cert) for zero-downtime rotation''',
  ),
  _CodeSnippet(
    title: 'Pin rotation strategy',
    language: 'dart',
    code: '''// Rotation plan — prevents service outage when cert expires
//
// Step 1: 60 days before cert expiry, generate the new cert.
// Step 2: Add the NEW cert's hash as backup pin in _pins map.
// Step 3: Ship app update (both primary + backup pins present).
// Step 4: Deploy new cert on server (all clients now accept it via backup).
// Step 5: In next app release, promote backup to primary, remove old.
//
// If rotation fails and users are on an old binary:
//   → They receive CERTIFICATE_PINNING_FAILED error.
//   → App shows: "Update ZapSafe to restore connectivity."
//   → ForceUpdateBanner (Day 119 release notes) triggers.

class PinRotationError extends DioException {
  PinRotationError(super.requestOptions);

  @override
  String toString() =>
      'Certificate pinning failed for \${requestOptions.uri.host}. '
      'Please update ZapSafe to the latest version.';
}

// In Dio badCertificateCallback:
// If pins don't match → log to Sentry → show ForceUpdateBanner''',
  ),
];

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day181CertPinningScreen extends ConsumerWidget {
  const Day181CertPinningScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d181TabProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Certificate Pinning'),
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: ZapSpacing.md, top: 8, bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
            ),
            child: const Text('🟢 FRONTEND-ONLY',
                style: TextStyle(color: Color(0xFF10B981), fontSize: 10,
                    fontWeight: FontWeight.w800)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Hero(),
            const SizedBox(height: ZapSpacing.xl),
            const _SectionLabel('SELECT VIEW'),
            const SizedBox(height: ZapSpacing.md),
            _TabBar(active: tab,
                onSelect: (t) => ref.read(_d181TabProvider.notifier).state = t),
            const SizedBox(height: ZapSpacing.xl),
            if (tab == 0) const _StatusTab(),
            if (tab == 1) const _ImplementationTab(),
            if (tab == 2) const _RotationTab(),
            const SizedBox(height: ZapSpacing.huge),
          ],
        ),
      ),
    );
  }
}

// ── Hero ───────────────────────────────────────────────────────────────────────
class _Hero extends StatelessWidget {
  const _Hero();
  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF081208), Color(0xFF050A05), Color(0xFF0A0A0A)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.5), width: 2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: ZapSpacing.sm, runSpacing: ZapSpacing.sm, children: [
          _badge('⚡  DAY 181',             const Color(0xFF10B981)),
          _badge('🟢 FRONTEND-ONLY',        const Color(0xFF10B981)),
          _badge('Section C  ·  Day 1/10',  const Color(0xFF3B82F6)),
          _badge('Cert Pinning  ·  Day 1/2',const Color(0xFF8B5CF6)),
        ]),
        const SizedBox(height: ZapSpacing.md),
        const Text('Certificate\nPinning & TLS',
            style: TextStyle(color: Colors.white, fontSize: 26,
                fontWeight: FontWeight.w900, height: 1.2)),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          'SHA-256 SPKI pinning via Dio custom HttpClient. '
          '2 domains pinned (api + exports). '
          'Backup pins for zero-downtime rotation. '
          'MITM attacks blocked even with rogue CA cert.',
          style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6)),
        const SizedBox(height: ZapSpacing.md),
        const Row(children: [
          _HStat('2',    '2 domains pinned',  Color(0xFF10B981)),
          _HStat('1',    'Not pinned (Sentry)',Color(0xFF6B7280)),
          _HStat('SHA256','Hash algorithm',   Color(0xFF3B82F6)),
          _HStat('2027', 'Cert expiry',       Color(0xFFF59E0B)),
        ]),
      ]));

  Widget _badge(String l, Color c) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.withOpacity(0.4))),
      child: Text(l, style: TextStyle(color: c, fontSize: 11,
          fontWeight: FontWeight.w700, letterSpacing: 0.5)));
}

class _HStat extends StatelessWidget {
  final String value, label; final Color color;
  const _HStat(this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(value, style: TextStyle(color: color, fontSize: 12,
        fontWeight: FontWeight.w800), textAlign: TextAlign.center),
    Text(label, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 9),
        textAlign: TextAlign.center),
  ]));
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);
  @override
  Widget build(BuildContext context) => Text(label,
      style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10,
          fontWeight: FontWeight.w700, letterSpacing: 1.5));
}

class _TabBar extends StatelessWidget {
  final int active; final ValueChanged<int> onSelect;
  const _TabBar({required this.active, required this.onSelect});
  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.lock_rounded,          Color(0xFF10B981), 'Pin Status'),
      (Icons.code_rounded,          Color(0xFF3B82F6), 'Implementation'),
      (Icons.sync_rounded,          Color(0xFFF59E0B), 'Rotation Plan'),
    ];
    return Row(children: List.generate(3, (i) {
      final (icon, color, label) = items[i];
      final isActive = i == active;
      return Expanded(child: GestureDetector(
        onTap: () => onSelect(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: EdgeInsets.only(right: i < 2 ? ZapSpacing.sm : 0),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
              color: isActive ? color.withOpacity(0.12) : const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(
                  color: isActive ? color.withOpacity(0.5) : const Color(0xFF2A2A2A),
                  width: isActive ? 2 : 1)),
          child: Column(children: [
            Icon(icon, color: isActive ? color : const Color(0xFF6B7280), size: 18),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(
                color: isActive ? color : const Color(0xFF6B7280), fontSize: 9,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400)),
          ]),
        ),
      ));
    }));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 1 — Pin Status
// ══════════════════════════════════════════════════════════════════════════════
class _StatusTab extends ConsumerWidget {
  const _StatusTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final testState   = ref.watch(_testStateProvider);
    final testResults = ref.watch(_testResultsProvider);
    final expanded    = ref.watch(_expandedPinProvider);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.lock_rounded, color: const Color(0xFF10B981),
          text: 'Certificate pinning prevents Man-in-the-Middle (MITM) attacks. '
              'ZapSafe pins 2 domains using SHA-256 hashes of the '
              'Subject Public Key Info (SPKI) — not the full cert, '
              'so the pin survives certificate renewal.'),
      const SizedBox(height: ZapSpacing.lg),

      // How pinning works
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _SectionLabel('HOW IT WORKS'),
          const SizedBox(height: ZapSpacing.md),
          ...[
            ('1', Icons.phone_iphone_rounded, const Color(0xFF3B82F6),
                'App sends HTTPS request to api.zapsafe.app'),
            ('2', Icons.security_rounded, const Color(0xFF8B5CF6),
                'Server sends its TLS certificate during handshake'),
            ('3', Icons.calculate_rounded, const Color(0xFFF59E0B),
                'Dio HttpClient computes SHA-256 of the cert\'s public key (SPKI)'),
            ('4', Icons.compare_rounded, const Color(0xFF10B981),
                'Hash compared against compiled-in pins list'),
            ('5', Icons.check_circle_rounded, const Color(0xFF10B981),
                'Match → request proceeds. Mismatch → PinRotationError → block.'),
          ].map((t) {
            final (num, icon, color, desc) = t;
            return Padding(
              padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.12), shape: BoxShape.circle),
                  child: Center(child: Text(num, style: TextStyle(
                      color: color, fontSize: 10, fontWeight: FontWeight.w800)))),
                const SizedBox(width: ZapSpacing.sm),
                Icon(icon, color: color, size: 14),
                const SizedBox(width: 6),
                Expanded(child: Text(desc, style: const TextStyle(
                    color: Color(0xFFD1D5DB), fontSize: 11, height: 1.4))),
              ]));
          }),
        ]),
      ),
      const SizedBox(height: ZapSpacing.xl),

      // Domain cards
      _SectionLabel('${_kDomains.length} DOMAINS  ·  TAP TO SEE PIN DETAILS'),
      const SizedBox(height: ZapSpacing.md),

      ..._kDomains.asMap().entries.map((e) {
        final i   = e.key;
        final dom = e.value;
        final isExp = expanded == i;

        return GestureDetector(
          onTap: () => ref.read(_expandedPinProvider.notifier).state =
              isExp ? null : i,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            decoration: BoxDecoration(
                color: isExp ? dom.color.withOpacity(0.07) : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                    color: isExp ? dom.color.withOpacity(0.4) : const Color(0xFF2A2A2A),
                    width: isExp ? 2 : 1)),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(ZapSpacing.md),
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                        color: dom.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(9)),
                    child: Icon(
                        dom.pinActive ? Icons.lock_rounded : Icons.lock_open_rounded,
                        color: dom.color, size: 17)),
                  const SizedBox(width: ZapSpacing.md),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(dom.domain, style: const TextStyle(color: Colors.white,
                        fontSize: 12, fontWeight: FontWeight.w700,
                        fontFamily: 'monospace')),
                    Text(dom.purpose, style: const TextStyle(
                        color: Color(0xFF6B7280), fontSize: 10),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ])),
                  const SizedBox(width: ZapSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: (dom.pinActive
                            ? const Color(0xFF10B981)
                            : const Color(0xFF6B7280)).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(dom.pinActive ? 'Pinned ✅' : 'Not pinned',
                        style: TextStyle(
                            color: dom.pinActive
                                ? const Color(0xFF10B981) : const Color(0xFF6B7280),
                            fontSize: 9, fontWeight: FontWeight.w700))),
                  const SizedBox(width: ZapSpacing.sm),
                  Icon(isExp ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                      color: const Color(0xFF4B5563), size: 16),
                ]),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                child: isExp
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(
                            ZapSpacing.md, 0, ZapSpacing.md, ZapSpacing.md),
                        child: _DomainDetail(domain: dom))
                    : const SizedBox.shrink(),
              ),
            ]),
          ),
        );
      }),
      const SizedBox(height: ZapSpacing.xl),

      // Connection test
      const _SectionLabel('SIMULATED CONNECTION TEST'),
      const SizedBox(height: ZapSpacing.md),
      _infoBox(icon: Icons.info_outline_rounded, color: const Color(0xFF3B82F6),
          text: 'Simulates what happens when the app starts up: '
              'it tests each pinned domain and verifies the cert matches. '
              'In production, this runs silently on first API call.'),
      const SizedBox(height: ZapSpacing.md),

      if (testState == _TestState.idle)
        _primaryBtn(
          label: 'Run Pin Verification Test',
          color: const Color(0xFF10B981),
          onTap: () => _runTest(ref),
        )
      else if (testState == _TestState.testing)
        _TestRunning()
      else if (testState == _TestState.done)
        _TestDone(results: testResults, ref: ref)
      else
        _statusCard(Icons.error_outline_rounded, const Color(0xFFEF4444),
            'Test failed', 'Check network and try again.', loading: false),
    ]);
  }

  Future<void> _runTest(WidgetRef ref) async {
    ref.read(_testStateProvider.notifier).state = _TestState.testing;
    ref.read(_testResultsProvider.notifier).state = [];

    final domains = _kDomains.where((d) => d.pinActive).toList();
    final results = <_TestResult>[];

    for (final dom in domains) {
      await Future.delayed(const Duration(milliseconds: 700));
      results.add(_TestResult(
        domain: dom.domain,
        passed: true,
        detail: 'SHA-256 match: ${dom.sha256Pin.substring(7, 23)}… '
            'TLS 1.3  ·  Valid until ${dom.certExpiry}',
        color: const Color(0xFF10B981),
      ));
      ref.read(_testResultsProvider.notifier).state = List.from(results);
    }

    // Add non-pinned domain result
    await Future.delayed(const Duration(milliseconds: 400));
    results.add(const _TestResult(
      domain: 'sentry.io',
      passed: true,
      detail: 'Not pinned (intentional). Standard TLS validation used. '
          'Third-party certs rotate frequently — pinning would cause outages.',
      color: Color(0xFF6B7280),
    ));
    ref.read(_testResultsProvider.notifier).state = List.from(results);
    ref.read(_testStateProvider.notifier).state = _TestState.done;
  }
}

class _DomainDetail extends StatelessWidget {
  final _PinnedDomain domain;
  const _DomainDetail({required this.domain});

  @override
  Widget build(BuildContext context) => Column(children: [
    Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: const Color(0xFF2A2A2A))),
      child: Column(children: [
        _kv('Domain',        domain.domain),
        _kv('Purpose',       domain.purpose),
        _kv('Status',        domain.pinActive ? 'Active — pinned ✅' : 'Not pinned'),
        _kv('Cert subject',  domain.certSubject),
        _kv('Cert expiry',   domain.certExpiry),
        _kv('Primary pin',   domain.sha256Pin, mono: true, copy: true, context: context),
        _kv('Backup pin',    domain.backupPin, mono: true, copy: true, context: context),
      ])),
    if (!domain.pinActive) ...[
      const SizedBox(height: ZapSpacing.sm),
      _infoBox(icon: Icons.info_outline_rounded, color: const Color(0xFF6B7280),
          text: 'Sentry is intentionally not pinned. Third-party services '
              'rotate certificates frequently and without notice. '
              'Pinning them would cause crash-reporting to silently break '
              'after each rotation. Standard TLS validation is sufficient '
              'for non-PII analytics data.'),
    ],
  ]);

  Widget _kv(String k, String v, {bool mono = false, bool copy = false,
      BuildContext? context}) =>
      GestureDetector(
        onTap: copy && context != null
            ? () {
                Clipboard.setData(ClipboardData(text: v));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Copied'), backgroundColor: Color(0xFF1A1A1A),
                    duration: Duration(seconds: 1)));
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 80, child: Text(k, style: const TextStyle(
                color: Color(0xFF6B7280), fontSize: 10))),
            Expanded(child: Text(v, style: TextStyle(
                color: copy ? const Color(0xFF3B82F6) : const Color(0xFFD1D5DB),
                fontSize: 10, fontFamily: mono ? 'monospace' : null,
                height: 1.4))),
            if (copy) const Icon(Icons.copy_rounded, color: Color(0xFF4B5563), size: 10),
          ])));
}

class _TestRunning extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Consumer(
      builder: (context, ref, _) {
        final results = ref.watch(_testResultsProvider);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.07),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(
                    color: Color(0xFF10B981), strokeWidth: 2)),
                SizedBox(width: ZapSpacing.sm),
                Text('Verifying certificate pins…',
                    style: TextStyle(color: Color(0xFF10B981), fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ]),
              if (results.isNotEmpty) ...[
                const SizedBox(height: ZapSpacing.md),
                ...results.map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(children: [
                        Icon(r.passed ? Icons.check_circle_rounded : Icons.cancel_rounded,
                            color: r.color, size: 14),
                        const SizedBox(width: 6),
                        Text(r.domain, style: TextStyle(
                            color: r.color, fontSize: 11, fontFamily: 'monospace')),
                      ]))),
              ],
            ])),
        ]);
      });
}

class _TestDone extends StatelessWidget {
  final List<_TestResult> results;
  final WidgetRef ref;
  const _TestDone({required this.results, required this.ref});

  @override
  Widget build(BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
    Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
          color: const Color(0xFF10B981).withOpacity(0.07),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.35))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 18),
          SizedBox(width: ZapSpacing.sm),
          Text('All pins verified ✅', style: TextStyle(color: Color(0xFF10B981),
              fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: ZapSpacing.md),
        ...results.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(r.passed ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      color: r.color, size: 14),
                  const SizedBox(width: 6),
                  Text(r.domain, style: TextStyle(color: r.color,
                      fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w700)),
                ]),
                Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Text(r.detail, style: const TextStyle(
                      color: Color(0xFF9CA3AF), fontSize: 10, height: 1.4))),
              ]))),
      ])),
    const SizedBox(height: ZapSpacing.sm),
    GestureDetector(
      onTap: () {
        ref.read(_testStateProvider.notifier).state = _TestState.idle;
        ref.read(_testResultsProvider.notifier).state = [];
      },
      child: const Text('Run again', style: TextStyle(
          color: Color(0xFF3B82F6), fontSize: 11,
          decoration: TextDecoration.underline))),
  ]);
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — Implementation
// ══════════════════════════════════════════════════════════════════════════════
class _ImplementationTab extends ConsumerWidget {
  const _ImplementationTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(_expandedCodeProvider);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.code_rounded, color: const Color(0xFF3B82F6),
          text: 'Three code snippets: (1) the Dio interceptor and custom '
              'HttpClient, (2) CLI command to extract the SHA-256 SPKI hash '
              'from the live server, (3) pin rotation strategy.'),
      const SizedBox(height: ZapSpacing.lg),

      ..._kSnippets.asMap().entries.map((e) {
        final i        = e.key;
        final snippet  = e.value;
        final isExp    = expanded == i;
        const colors   = [Color(0xFF3B82F6), Color(0xFF10B981), Color(0xFFF59E0B)];
        final color    = colors[i];

        return GestureDetector(
          onTap: () => ref.read(_expandedCodeProvider.notifier).state =
              isExp ? null : i,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            decoration: BoxDecoration(
                color: isExp ? color.withOpacity(0.07) : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                    color: isExp ? color.withOpacity(0.4) : const Color(0xFF2A2A2A),
                    width: isExp ? 2 : 1)),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(ZapSpacing.md),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(snippet.language.toUpperCase(), style: TextStyle(
                        color: color, fontSize: 9, fontWeight: FontWeight.w800))),
                  const SizedBox(width: ZapSpacing.md),
                  Expanded(child: Text(snippet.title, style: const TextStyle(
                      color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
                  Icon(isExp ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                      color: const Color(0xFF4B5563), size: 16),
                ]),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                child: isExp
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(
                            ZapSpacing.md, 0, ZapSpacing.md, ZapSpacing.md),
                        child: _codeBlock(context, snippet.code))
                    : const SizedBox.shrink(),
              ),
            ]),
          ),
        );
      }),

      const SizedBox(height: ZapSpacing.xl),
      const _SectionLabel('MITM ATTACK SIMULATION'),
      const SizedBox(height: ZapSpacing.md),
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFFEF4444).withOpacity(0.06),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.security_rounded, color: Color(0xFFEF4444), size: 16),
            SizedBox(width: ZapSpacing.sm),
            Text('Without pinning', style: TextStyle(color: Color(0xFFEF4444),
                fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            '1. Attacker installs rogue CA cert on device (e.g. Charles Proxy, mitmproxy)\n'
            '2. Device trusts the rogue cert — normal TLS succeeds\n'
            '3. Attacker intercepts SOS location, auth tokens, evidence uploads\n'
            '4. ZapSafe app has no way to detect the interception',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11, height: 1.7)),
          const SizedBox(height: ZapSpacing.md),
          const Row(children: [
            Icon(Icons.shield_rounded, color: Color(0xFF10B981), size: 16),
            SizedBox(width: ZapSpacing.sm),
            Text('With pinning (ZapSafe)', style: TextStyle(color: Color(0xFF10B981),
                fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            '1. Attacker installs rogue CA cert — device trusts it\n'
            '2. TLS handshake begins, server (proxy) sends its cert\n'
            '3. Dio computes SHA-256 of rogue cert\'s public key\n'
            '4. Hash doesn\'t match compiled pin → PinRotationError → request blocked\n'
            '5. User sees "Unable to connect" — attack fails',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11, height: 1.7)),
        ])),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 3 — Rotation Plan
// ══════════════════════════════════════════════════════════════════════════════
class _RotationTab extends StatelessWidget {
  const _RotationTab();

  @override
  Widget build(BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
    _infoBox(icon: Icons.sync_rounded, color: const Color(0xFFF59E0B),
        text: 'Cert pinning breaks if the server cert changes and '
            'the app isn\'t updated first. This tab documents the '
            'zero-downtime rotation strategy and expiry monitoring.'),
    const SizedBox(height: ZapSpacing.lg),

    // Cert expiry table
    const _SectionLabel('CERTIFICATE EXPIRY MONITOR'),
    const SizedBox(height: ZapSpacing.md),
    Container(
      decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: const Color(0xFF2A2A2A))),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.md, vertical: 8),
          decoration: const BoxDecoration(
              color: Color(0xFF111111),
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(ZapSpacing.radiusSmall),
                  topRight: Radius.circular(ZapSpacing.radiusSmall))),
          child: const Row(children: [
            Expanded(flex: 3, child: Text('Domain',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 9,
                    fontWeight: FontWeight.w700))),
            Expanded(flex: 2, child: Text('Expires',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 9,
                    fontWeight: FontWeight.w700))),
            Expanded(child: Text('Days left',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 9,
                    fontWeight: FontWeight.w700), textAlign: TextAlign.right)),
          ])),
        ...[
          ('api.zapsafe.app',     'Mar 15, 2027', 289, const Color(0xFF10B981)),
          ('exports.zapsafe.app', 'Jun 1, 2027',  367, const Color(0xFF10B981)),
          ('sentry.io',          'Dec 3, 2026',   187, const Color(0xFFF59E0B)),
        ].asMap().entries.map((e) {
          final i = e.key;
          final (domain, expiry, days, color) = e.value;
          final isLast = i == 2;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: ZapSpacing.md, vertical: 10),
              child: Row(children: [
                Expanded(flex: 3, child: Text(domain, style: const TextStyle(
                    color: Colors.white, fontSize: 10, fontFamily: 'monospace'))),
                Expanded(flex: 2, child: Text(expiry, style: const TextStyle(
                    color: Color(0xFF9CA3AF), fontSize: 10))),
                Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text('$days d', style: TextStyle(
                        color: color, fontSize: 9, fontWeight: FontWeight.w700))),
                ])),
              ])),
            if (!isLast) const Divider(height: 1, color: Color(0xFF222222)),
          ]);
        }),
      ]),
    ),
    const SizedBox(height: ZapSpacing.lg),

    // Rotation timeline
    const _SectionLabel('ZERO-DOWNTIME ROTATION TIMELINE'),
    const SizedBox(height: ZapSpacing.md),
    Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          border: Border.all(color: const Color(0xFF2A2A2A))),
      child: Column(children: [
        _timelineRow(const Color(0xFF3B82F6), 'T-60 days',
            'Generate new server certificate. Extract its SHA-256 SPKI hash.'),
        _spacer(),
        _timelineRow(const Color(0xFF8B5CF6), 'T-55 days',
            'Add NEW cert hash as backup pin in _pins map. Ship app update to stores.'),
        _spacer(),
        _timelineRow(const Color(0xFFF59E0B), 'T-30 days',
            'Verify ≥80% of users are on updated app (backup pin present).'),
        _spacer(),
        _timelineRow(const Color(0xFF10B981), 'T-0 (cert renewal)',
            'Deploy new cert on server. All clients already have the backup pin → accept.'),
        _spacer(),
        _timelineRow(const Color(0xFF10B981), 'Next release',
            'Promote backup to primary. Remove old primary pin. Rotation complete.'),
      ]),
    ),
    const SizedBox(height: ZapSpacing.lg),

    // Emergency rotation
    const _SectionLabel('EMERGENCY ROTATION (COMPROMISED KEY)'),
    const SizedBox(height: ZapSpacing.md),
    Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withOpacity(0.07),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.35))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.warning_rounded, color: Color(0xFFEF4444), size: 16),
          SizedBox(width: ZapSpacing.sm),
          Text('If private key is compromised:', style: TextStyle(
              color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: ZapSpacing.sm),
        ...[
          'Revoke old cert immediately (CA revocation).',
          'Deploy new cert with different key pair on server.',
          'Old app versions cannot connect (no matching pin) — intentional.',
          'ForceUpdateBanner (Day 119) triggers for users on old binary.',
          'New app version with new pin ships as emergency release.',
          'Accept ~24h window where old users cannot connect.',
        ].map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.circle, color: Color(0xFFEF4444), size: 5),
                const SizedBox(width: 7),
                Expanded(child: Text(s, style: const TextStyle(
                    color: Color(0xFF9CA3AF), fontSize: 11, height: 1.4))),
              ]))),
      ])),
    const SizedBox(height: ZapSpacing.lg),

    // Day 182 pointer
    _infoBox(icon: Icons.arrow_forward_rounded, color: const Color(0xFF3B82F6),
        text: 'Day 182 builds the Network Security Config viewer — '
            'Android\'s network_security_config.xml + iOS '
            'NSAppTransportSecurity settings + proxy detection (blocks '
            'Charles/Burp on non-debug builds).'),
  ]);

  Widget _timelineRow(Color color, String label, String desc) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          Container(
            width: 10, height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        ]),
        const SizedBox(width: ZapSpacing.md),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: color, fontSize: 10,
              fontWeight: FontWeight.w700)),
          Text(desc, style: const TextStyle(color: Color(0xFF9CA3AF),
              fontSize: 11, height: 1.4)),
        ])),
      ]);

  Widget _spacer() => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Container(width: 2, height: 16, color: const Color(0xFF2A2A2A)));
}

// ── Shared helpers ─────────────────────────────────────────────────────────────
Widget _codeBlock(BuildContext context, String code) => GestureDetector(
    onLongPress: () {
      Clipboard.setData(ClipboardData(text: code));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Copied'), backgroundColor: Color(0xFF1A1A1A),
          duration: Duration(seconds: 1)));
    },
    child: Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: const Color(0xFF2A2A2A))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Expanded(child: Text('long-press to copy',
              style: TextStyle(color: Color(0xFF4B5563), fontSize: 9))),
          Icon(Icons.copy_rounded, color: Color(0xFF4B5563), size: 12),
        ]),
        const SizedBox(height: ZapSpacing.sm),
        Text(code, style: const TextStyle(color: Color(0xFF86EFAC),
            fontSize: 10, fontFamily: 'monospace', height: 1.6)),
      ])));

Widget _primaryBtn({required String label, required Color color,
    required VoidCallback onTap}) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color, color.withOpacity(0.8)]),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            boxShadow: [BoxShadow(color: color.withOpacity(0.3),
                blurRadius: 14, offset: const Offset(0, 4))]),
        child: Center(child: Text(label, style: const TextStyle(
            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)))));

Widget _statusCard(IconData icon, Color color, String title, String body,
    {required bool loading}) =>
    Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: color.withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          loading
              ? SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(color: color, strokeWidth: 2))
              : Icon(icon, color: color, size: 16),
          const SizedBox(width: ZapSpacing.sm),
          Text(title, style: TextStyle(color: color, fontSize: 13,
              fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: ZapSpacing.sm),
        Text(body, style: const TextStyle(color: Color(0xFF9CA3AF),
            fontSize: 11, height: 1.5)),
      ]));

Widget _infoBox({required IconData icon, required Color color, required String text}) =>
    Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: color.withOpacity(0.25))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: ZapSpacing.sm),
        Expanded(child: Text(text, style: const TextStyle(
            color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6))),
      ]));
