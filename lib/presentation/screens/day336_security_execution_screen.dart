/// Day 336 — Security Pre-Launch: Execution
///
/// Section I (Days 331-340): reads Day 285's OWASP MASVS L2 checklist
/// (`day285_security_prelaunch_audit_screen.dart`) — which shipped as an
/// on-device checklist screen where every row simply *starts* at PASS/WARN
/// (see its `defaultStatus` values) — and replaces those assumed defaults
/// with real static-analysis results from grepping this repo's actual
/// Android/iOS/Dart source while building this screen.
///
/// **Real static findings** (this session, reproducible with the commands
/// quoted per row):
/// - Certificate/SPKI pinning: NOT implemented. `lib/data/services/api_client.dart`
///   builds a plain `Dio(BaseOptions(...))` with no `badCertificateCallback`,
///   no `HttpClientAdapter` override, and no cert-pinning package in
///   `pubspec.yaml`. Day 181's screen is a UI mock of what pinning *would*
///   look like, not a wired implementation. Contradicts Day 285's PASS.
/// - Cleartext traffic: real PASS. `ApiConfig.baseUrl` returns
///   `https://zapsafe.app` under `kReleaseMode`, and
///   `android/app/src/debug/res/xml/network_security_config.xml` only
///   permits cleartext for `10.0.2.2`/`localhost`/`127.0.0.1` in **debug**
///   builds; there is no release-variant network security config, so
///   Android's `cleartextTrafficPermitted=false` default applies to the
///   release build. No `NSAppTransportSecurity` exceptions exist in
///   `ios/Runner/Info.plist` either, so default (strict) ATS applies there.
/// - `FLAG_SECURE` / screen-capture blocking: NOT implemented. Grepped
///   `android/app/src/main/kotlin/**/MainActivity.kt` and the rest of
///   `android/app/src/main` — no `FLAG_SECURE`, no
///   `setRecentsScreenshotEnabled`. No `flutter_windowmanager` or
///   equivalent plugin in `pubspec.yaml`. Days 296/333 both catalogue this
///   as a parity target; neither wires it. Contradicts Day 285's implicit
///   assumption (via Day 186's tamper screen).
/// - Root / jailbreak detection: NOT implemented as real detection.
///   `day185_root_detection_screen.dart` is an animated scan **simulation**
///   (its own header says "detection logic runs entirely on device" but the
///   actual checks are UI-only — no `safe_device`, `flutter_jailbreak_detection`,
///   `freerasp`, or Play Integrity/SafetyNet call exists anywhere in
///   `pubspec.yaml` or `lib/`).
/// - Encrypted local storage: MIXED, not a clean PASS.
///   `lib/data/services/token_storage.dart` really does use
///   `FlutterSecureStorage` (Keychain/Keystore-backed) for JWT
///   access/refresh tokens — genuine PASS for that specific claim.
///   But `hive_flutter` is a pubspec dependency that is never actually
///   initialised: no `Hive.initFlutter()` call exists anywhere in `lib/`
///   (Days 306/307/333/334 all document SharedPreferences as the project's
///   real local-persistence precedent instead). Day 285's "Hive AES-256"
///   claim describes code that isn't wired. The vault PIN is hardcoded to
///   `kVaultDevPin = '1234'` in `lib/domain/providers/vault_providers.dart`
///   with its own comment: "hardcoded for dev; stored in
///   FlutterSecureStorage in prod" — i.e. not yet done.
/// - Biometric app lock: NOT wired into any real gated flow.
///   `LocalAuthentication()` is only ever constructed inside the demo code
///   of `day183_biometric_lock_screen.dart` and
///   `day184_biometric_hardening_screen.dart` — no standalone
///   `BiometricService` file exists, and nothing outside those two screens
///   calls it.
/// - Release build signing: real FAIL. `android/app/build.gradle`'s
///   `buildTypes.release` block reads
///   `signingConfig signingConfigs.debug` with the comment
///   "TODO: Add your own signing config for the release build." — the
///   release APK/AAB is still signed with debug keys.
/// - ProGuard/R8 + obfuscation: NOT configured. No `proguard-rules.pro`
///   file exists under `android/app`, `build.gradle` sets no
///   `minifyEnabled`/`isMinifyEnabled`, and there is no `.github/workflows`
///   directory in this repo at all, so no CI release lane can be passing
///   `--obfuscate --split-debug-info` either. Day 285 already flagged this
///   WARN rather than PASS; this screen confirms it is still true and
///   escalates it to FAIL since "on CI release lane" turned out not to
///   exist.
/// - Data export + deletion APIs (Day 285's last row): the two most
///   legally load-bearing DPDP rights are, in fact, real and wired — see
///   Day 337 for the detailed endpoint-by-endpoint breakdown.
///
/// Runtime-only items (actual penetration testing, Frida hook resistance,
/// live MITM proxy attempts) cannot be checked by grep and stay PENDING.
///
/// Tag: 🟢 FRONTEND-ONLY · real static findings from this repo, several of
/// which reverse Day 285's original PASS/WARN defaults · runtime-pentest
/// items pending, no device.
///
/// Route: [AppRoutes.securityExecution] → `/day-336-security-execution`
library;

import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const _kAccent = Color(0xFF10B981);
const _kTabs = ['Findings', 'Runtime-only', 'Info'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');

enum _Verdict { pass, fail, mixed, pending }

String _verdictKey(_Verdict v) => switch (v) {
      _Verdict.pass => 'pass',
      _Verdict.fail => 'fail',
      _Verdict.mixed => 'mixed',
      _Verdict.pending => 'pending',
    };

Color _verdictColor(_Verdict v) => switch (v) {
      _Verdict.pass => ZapColors.safe,
      _Verdict.fail => ZapColors.danger,
      _Verdict.mixed => ZapColors.warning,
      _Verdict.pending => ZapColors.textMuted,
    };

IconData _verdictIcon(_Verdict v) => switch (v) {
      _Verdict.pass => Icons.check_circle_rounded,
      _Verdict.fail => Icons.cancel_rounded,
      _Verdict.mixed => Icons.warning_rounded,
      _Verdict.pending => Icons.hourglass_empty_rounded,
    };

class _Finding {
  const _Finding({
    required this.id,
    required this.mstgCode,
    required this.title,
    required this.verdict,
    required this.detail,
    required this.sourceFile,
    required this.day285Default,
  });

  final String id;
  final String mstgCode;
  final String title;
  final _Verdict verdict;
  final String detail;
  final String sourceFile;
  final String day285Default;
}

const _kFindings = [
  _Finding(
    id: 'cert_pinning',
    mstgCode: 'MSTG-NETWORK-1',
    title: 'TLS certificate / SPKI pinning',
    verdict: _Verdict.fail,
    detail: 'No badCertificateCallback, no HttpClientAdapter override, no '
        'cert-pinning package in pubspec.yaml. Dio is built plain.',
    sourceFile: 'lib/data/services/api_client.dart',
    day285Default: 'PASS',
  ),
  _Finding(
    id: 'cleartext',
    mstgCode: 'MSTG-NETWORK-2',
    title: 'Cleartext traffic / ATS blocked in release',
    verdict: _Verdict.pass,
    detail: 'baseUrl → https://zapsafe.app under kReleaseMode. Debug-only '
        'network_security_config permits cleartext to 10.0.2.2/localhost '
        'only. No release-variant config → Android default '
        'cleartextTrafficPermitted=false applies. No ATS exceptions in '
        'ios/Runner/Info.plist → default strict ATS applies.',
    sourceFile: 'lib/core/constants/api_config.dart · '
        'android/app/src/debug/res/xml/network_security_config.xml · '
        'ios/Runner/Info.plist',
    day285Default: 'PASS',
  ),
  _Finding(
    id: 'flag_secure',
    mstgCode: 'MSTG-STORAGE-2 (screen capture)',
    title: 'FLAG_SECURE / screen-capture blocking',
    verdict: _Verdict.fail,
    detail: 'No FLAG_SECURE, no setRecentsScreenshotEnabled, no '
        'flutter_windowmanager-equivalent package. Cataloged as a gap by '
        'Days 296/333, still not wired.',
    sourceFile: 'android/app/src/main/kotlin/.../MainActivity.kt',
    day285Default: '(assumed via Day 186 tamper screen)',
  ),
  _Finding(
    id: 'root_detection',
    mstgCode: 'MSTG-RESILIENCE-1',
    title: 'Root / jailbreak detection',
    verdict: _Verdict.fail,
    detail: 'day185_root_detection_screen.dart is an animated UI '
        'simulation, not real detection — no safe_device, '
        'flutter_jailbreak_detection, freerasp, or Play Integrity/'
        'SafetyNet call anywhere in pubspec.yaml or lib/.',
    sourceFile: 'lib/presentation/screens/day185_root_detection_screen.dart',
    day285Default: 'PASS',
  ),
  _Finding(
    id: 'encrypted_storage',
    mstgCode: 'MSTG-STORAGE-1',
    title: 'Encrypted local storage',
    verdict: _Verdict.mixed,
    detail: 'JWT tokens genuinely use FlutterSecureStorage (Keychain/'
        'Keystore) — real PASS for that. But hive_flutter is never '
        'initialised (no Hive.initFlutter() call anywhere in lib/); '
        'SharedPreferences is the project\'s real local-persistence '
        'precedent instead (Days 306/307/333/334). Vault PIN is hardcoded '
        'kVaultDevPin = \'1234\' with its own "stored in FlutterSecureStorage '
        'in prod" TODO comment.',
    sourceFile: 'lib/data/services/token_storage.dart · '
        'lib/domain/providers/vault_providers.dart:235-236',
    day285Default: 'PASS',
  ),
  _Finding(
    id: 'biometric_lock',
    mstgCode: 'MSTG-AUTH-1',
    title: 'Biometric app lock wired into a real gate',
    verdict: _Verdict.fail,
    detail: 'LocalAuthentication() is only constructed inside the demo '
        'code of the Day 183/184 screens themselves — no standalone '
        'BiometricService, nothing outside those two screens calls it.',
    sourceFile: 'lib/presentation/screens/day183_biometric_lock_screen.dart',
    day285Default: 'PASS',
  ),
  _Finding(
    id: 'release_signing',
    mstgCode: 'MSTG-CODE-2',
    title: 'Release build signing',
    verdict: _Verdict.fail,
    detail: 'buildTypes.release uses signingConfig signingConfigs.debug — '
        'release APK/AAB is still signed with the debug keystore. Own '
        'comment: "TODO: Add your own signing config for the release build."',
    sourceFile: 'android/app/build.gradle',
    day285Default: '(not covered by Day 285)',
  ),
  _Finding(
    id: 'obfuscation',
    mstgCode: 'MSTG-CODE-1',
    title: 'ProGuard/R8 + Dart obfuscation',
    verdict: _Verdict.fail,
    detail: 'No proguard-rules.pro, no minifyEnabled/isMinifyEnabled in '
        'build.gradle, and no .github/workflows directory exists at all — '
        'so no CI release lane can be running --obfuscate either.',
    sourceFile: 'android/app/build.gradle',
    day285Default: 'WARN',
  ),
];

// ── Providers ─────────────────────────────────────────────────────────────────
final _d336TabProvider = StateProvider<int>((ref) => 0);

// ── Screen ────────────────────────────────────────────────────────────────────
class Day336SecurityExecutionScreen extends ConsumerWidget {
  const Day336SecurityExecutionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fails = _kFindings.where((f) => f.verdict == _Verdict.fail).length;
    final pass = _kFindings.where((f) => f.verdict == _Verdict.pass).length;

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: Text('day331_340.security_exec_title'.tr()),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ZapColors.danger.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: ZapColors.danger.withOpacity(0.45)),
                ),
                child: Text('$pass pass · $fails fail', style: const TextStyle(
                  color: ZapColors.danger, fontSize: 10, fontWeight: FontWeight.w900,
                )),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _TabBar(tab: ref.watch(_d336TabProvider), onSelect: (i) => ref.read(_d336TabProvider.notifier).state = i),
          Expanded(
            child: switch (ref.watch(_d336TabProvider)) {
              0 => const _FindingsTab(),
              1 => const _RuntimeOnlyTab(),
              _ => const _InfoTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Findings ───────────────────────────────────────────────────────────
class _FindingsTab extends StatelessWidget {
  const _FindingsTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.danger.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.danger.withOpacity(0.3)),
          ),
          child: const Text(
            'Real static checks against this repo, replacing Day 285\'s '
            'assumed PASS/WARN defaults. Most of these come back FAIL — '
            'that\'s the honest current state, not a bug in this screen.',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 11, height: 1.4),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        ..._kFindings.map((f) => Container(
              margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
              padding: const EdgeInsets.all(ZapSpacing.md),
              decoration: BoxDecoration(
                color: ZapColors.bgCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _verdictColor(f.verdict).withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_verdictIcon(f.verdict), color: _verdictColor(f.verdict), size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(f.mstgCode, style: TextStyle(
                          color: _verdictColor(f.verdict), fontSize: 10, fontWeight: FontWeight.w800,
                        )),
                      ),
                      Text(_verdictKey(f.verdict).toUpperCase(), style: TextStyle(
                        color: _verdictColor(f.verdict), fontSize: 10, fontWeight: FontWeight.w900,
                      )),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(f.title, style: const TextStyle(
                    color: ZapColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13,
                  )),
                  const SizedBox(height: 6),
                  Text(f.detail, style: const TextStyle(color: ZapColors.textSecondary, fontSize: 11, height: 1.4)),
                  const SizedBox(height: 6),
                  Text(f.sourceFile, style: const TextStyle(
                    color: ZapColors.info, fontSize: 9, fontFamily: 'monospace',
                  )),
                  const SizedBox(height: 2),
                  Text('Day 285 default was: ${f.day285Default}', style: const TextStyle(
                    color: ZapColors.textMuted, fontSize: 9, fontStyle: FontStyle.italic,
                  )),
                ],
              ),
            )),
        OutlinedButton.icon(
          onPressed: () {
            final buf = StringBuffer('ZapSafe Security Pre-Launch — Execution Findings\n\n');
            for (final f in _kFindings) {
              buf.writeln('[${_verdictKey(f.verdict).toUpperCase()}] ${f.mstgCode} · ${f.title}');
              buf.writeln('  ${f.detail}');
              buf.writeln('  Source: ${f.sourceFile}');
              buf.writeln();
            }
            Clipboard.setData(ClipboardData(text: buf.toString()));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Findings report copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy findings report'),
        ),
      ],
    );
  }
}

// ── Tab 1: Runtime-only ───────────────────────────────────────────────────────
class _RuntimeOnlyTab extends StatelessWidget {
  const _RuntimeOnlyTab();

  static const _kRuntimeItems = [
    'Live MITM proxy attempt against the release build (would confirm the '
        'cert-pinning gap in practice, not just in source).',
    'Frida hook resistance test on local_auth / biometric gates.',
    'Physical rooted/jailbroken device run against the app\'s actual '
        'behavior (source shows no detection exists, so this is expected '
        'to pass through undetected — worth confirming once, not urgently).',
    'Screen-recording / screenshot attempt during an active SOS on a real '
        'device, to confirm the FLAG_SECURE gap is user-visible.',
    'Static analysis tool run (MobSF or similar) against a built release '
        'APK/AAB, once release signing is fixed enough to produce one.',
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text('Cannot be checked by grep', style: TextStyle(
          color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13,
        )),
        const Text(
          'These require an actual build, an actual device, or an actual '
          'attacker tool. No physical device or CI runner is available in '
          'this environment, so they stay PENDING.',
          style: TextStyle(color: ZapColors.textMuted, fontSize: 11),
        ),
        const SizedBox(height: ZapSpacing.md),
        ..._kRuntimeItems.map((item) => Container(
              margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
              padding: const EdgeInsets.all(ZapSpacing.md),
              decoration: BoxDecoration(
                color: ZapColors.bgCard,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ZapColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.hourglass_empty_rounded, color: ZapColors.textMuted, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item, style: const TextStyle(
                    color: ZapColors.textSecondary, fontSize: 12, height: 1.4,
                  ))),
                ],
              ),
            )),
      ],
    );
  }
}

// ── Tab 2: Info ───────────────────────────────────────────────────────────────
class _InfoTab extends StatelessWidget {
  const _InfoTab();

  @override
  Widget build(BuildContext context) {
    final payload = {
      'endpoint': 'GET /api/v1/qa/security-prelaunch-execution/ (mock)',
      'source': 'Static analysis over this repo, not a live scanner API',
      'total_items': _kFindings.length,
      'pass': _kFindings.where((f) => f.verdict == _Verdict.pass).length,
      'fail': _kFindings.where((f) => f.verdict == _Verdict.fail).length,
      'mixed': _kFindings.where((f) => f.verdict == _Verdict.mixed).length,
      'reverses_day285_default': _kFindings
          .where((f) => f.day285Default == 'PASS' && f.verdict != _Verdict.pass)
          .length,
      'launch_ready': false,
      'wire_note': 'Real grep-based findings; several reverse Day 285\'s '
          'assumed defaults. Not launch-ready as of this session.',
    };

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text('Security pre-launch — execution', style: TextStyle(
          color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13,
        )),
        const Text(
          'Section I Day 6/10 · replaces Day 285\'s assumed checklist '
          'defaults with real static-analysis results from this repo.',
          style: TextStyle(color: ZapColors.textMuted, fontSize: 11),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.border),
          ),
          child: SelectableText(
            _kJsonEncoder.convert(payload),
            style: const TextStyle(color: ZapColors.textSecondary, fontSize: 10, fontFamily: 'monospace', height: 1.45),
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: _kJsonEncoder.convert(payload)));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Spec copied.')));
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy spec JSON'),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: [
            ActionChip(label: const Text('Day 285 Audit'), onPressed: () => context.push(AppRoutes.securityPrelaunchAudit)),
            ActionChip(label: const Text('Day 331 Gate v2'), onPressed: () => context.push(AppRoutes.gonogoGateV2)),
          ],
        ),
      ],
    );
  }
}

// ── Shared ────────────────────────────────────────────────────────────────────
class _TabBar extends StatelessWidget {
  const _TabBar({required this.tab, required this.onSelect});
  final int tab;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ZapColors.bgCard,
      child: Row(
        children: List.generate(_kTabs.length, (i) {
          final selected = tab == i;
          return Expanded(
            child: InkWell(
              onTap: () => onSelect(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: selected ? _kAccent : Colors.transparent, width: 2)),
                ),
                child: Text(_kTabs[i], textAlign: TextAlign.center, style: TextStyle(
                  color: selected ? _kAccent : ZapColors.textMuted,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  fontSize: 12,
                )),
              ),
            ),
          );
        }),
      ),
    );
  }
}
