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
/// - `FLAG_SECURE` / screen-capture blocking: FIXED post-Day 390.
///   `MainActivity.onCreate()` now sets
///   `WindowManager.LayoutParams.FLAG_SECURE` app-wide. Not
///   device/emulator-verified in this sandbox (no working Android build
///   toolchain here — unrelated Gradle/JDK environment issues) — reviewed
///   manually against the standard, well-documented pattern; real device
///   verification still recommended before shipping.
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
    verdict: _Verdict.mixed,
    detail: 'Fixed: cert_pinning.dart pins real, live-captured SHA-256(DER) '
        'hashes for zapsafe.app\'s actual production cert chain (leaf + '
        'Google Trust Services WE1 intermediate + GTS Root R4), wired '
        'into both real Dio clients (api_client.dart, '
        'compatibility_service.dart) via SecurityContext('
        'withTrustedRoots: false) — the only way badCertificateCallback '
        'actually fires for an already-CA-trusted cert; the demo '
        'string\'s plain badCertificateCallback approach would not have '
        'worked even if it had been real code. Pinning only applies to '
        'the real production host in release builds; dev/staging is '
        'unaffected. Not build/device-verified in this sandbox. Still '
        'MIXED, not full PASS: pins are static/baked-in with a real, '
        'disclosed operational risk (leaf cert rotates ~90 days; if the '
        'CA chain changes before an app update ships refreshed pins, '
        'ALL API traffic fails closed) — no server-driven pin-rotation '
        'mechanism exists to mitigate that.',
    sourceFile: 'lib/data/services/cert_pinning.dart · '
        'lib/data/services/api_client.dart · '
        'lib/data/services/compatibility_service.dart',
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
    verdict: _Verdict.pass,
    detail: 'FIXED (post-Day 390): MainActivity.onCreate() now sets '
        'WindowManager.LayoutParams.FLAG_SECURE app-wide, applied before '
        'super.onCreate() so it covers every screen from first frame — '
        'blocks screenshots, screen recording, and the Recents-tray '
        'thumbnail. Could not be device/emulator-verified in this sandbox '
        '(Gradle build environment unavailable here — daemon crashes / JDK '
        'version mismatch, unrelated to this change); reviewed manually '
        'against the standard, well-documented Android FLAG_SECURE pattern. '
        'Real device verification still recommended before shipping.',
    sourceFile: 'android/app/src/main/kotlin/com/zapsafe/zapsafe_mobile/MainActivity.kt',
    day285Default: '(assumed via Day 186 tamper screen)',
  ),
  _Finding(
    id: 'root_detection',
    mstgCode: 'MSTG-RESILIENCE-1',
    title: 'Root / jailbreak detection',
    verdict: _Verdict.mixed,
    detail: 'Fixed: safe_device is now a real pubspec.yaml dependency. '
        'DeviceIntegrityService (lib/data/services/'
        'device_integrity_service.dart) runs a real on-device scan '
        '(SafeDevice.isJailBroken / isRealDevice / isMockLocation / '
        'rootDetectionDetails), wired into day185_root_detection_screen.'
        'dart\'s Run Scan button, replacing the old '
        '_simulateJailbreakProvider fake toggle entirely. Per-row '
        'results are only genuine where safe_device exposes a matching '
        'signal (su binary, test-keys, debuggable on Android); other '
        'rows honestly defer to the one real combined verdict rather '
        'than a fabricated per-row "clean". Not build/device-verified in '
        'this sandbox. Still MIXED, not full PASS: Play Integrity/'
        'SafetyNet server-side attestation (the Day 186 spec\'s own '
        'stated follow-up) is still not implemented — safe_device is a '
        'client-only signal, spoofable by a sufficiently determined '
        'attacker in a way a real Play Integrity token is not.',
    sourceFile: 'lib/data/services/device_integrity_service.dart · '
        'lib/presentation/screens/day185_root_detection_screen.dart',
    day285Default: 'PASS',
  ),
  _Finding(
    id: 'encrypted_storage',
    mstgCode: 'MSTG-STORAGE-1',
    title: 'Encrypted local storage',
    verdict: _Verdict.mixed,
    detail: 'JWT tokens genuinely use FlutterSecureStorage (Keychain/'
        'Keystore) — real PASS for that. Vault PIN also now real: '
        'VaultPinStorage stores a salted SHA-256 hash of a user-chosen '
        'PIN in FlutterSecureStorage (was: hardcoded kVaultDevPin = '
        "'1234' shared by every install — fixed). hive_flutter is still "
        'never initialised (no Hive.initFlutter() call anywhere in lib/); '
        'SharedPreferences remains the project\'s real local-persistence '
        'precedent instead (Days 306/307/333/334) — that part is still '
        'MIXED, not a full PASS.',
    sourceFile: 'lib/data/services/token_storage.dart · '
        'lib/data/services/vault_pin_storage.dart · '
        'lib/domain/providers/vault_providers.dart',
    day285Default: 'PASS',
  ),
  _Finding(
    id: 'biometric_lock',
    mstgCode: 'MSTG-AUTH-1',
    title: 'Biometric app lock wired into a real gate',
    verdict: _Verdict.mixed,
    detail: 'Fixed for the Evidence Vault: a real standalone '
        'BiometricService now exists (LocalAuthentication() was '
        'previously only ever inside a *string literal* code sample in '
        'the Day 183 screen, never actually called). It gates '
        'day82_evidence_vault_screen.dart as a fast-path alongside the '
        'real vault PIN, with MainActivity switched from FlutterActivity '
        'to FlutterFragmentActivity (required by local_auth\'s Android '
        'implementation) and the real USE_BIOMETRIC / '
        'NSFaceIDUsageDescription platform declarations added. Not '
        'build/device-verified in this sandbox. Still MIXED, not PASS: '
        'the vault is the only real gate — app-wide lock-on-resume (the '
        'Day 183/184 demo\'s own AppLockNotifier concept) is still not '
        'built.',
    sourceFile: 'lib/data/services/biometric_service.dart · '
        'lib/presentation/screens/day82_evidence_vault_screen.dart',
    day285Default: 'PASS',
  ),
  _Finding(
    id: 'release_signing',
    mstgCode: 'MSTG-CODE-2',
    title: 'Release build signing',
    verdict: _Verdict.mixed,
    detail: 'PARTIALLY FIXED: buildTypes.release now reads real signing '
        'credentials from android/key.properties (gitignored) when '
        'present, via the standard documented Flutter pattern, falling '
        'back to debug-signing + a loud build-time warning otherwise. No '
        'real keystore exists in this environment — cannot be created '
        'here, needs the actual release keystore owner (see '
        'key.properties.example for the real steps) — and this sandbox '
        'has no working Android build toolchain to verify the Gradle '
        'change even compiles. Mixed, not PASS, until both exist.',
    sourceFile: 'android/app/build.gradle, android/key.properties.example',
    day285Default: '(not covered by Day 285)',
  ),
  _Finding(
    id: 'obfuscation',
    mstgCode: 'MSTG-CODE-1',
    title: 'ProGuard/R8 + Dart obfuscation',
    verdict: _Verdict.mixed,
    detail: 'PARTIALLY FIXED: android/app/proguard-rules.pro now exists '
        'with real, dependency-scoped keep rules (checked against the '
        "app's actual pubspec.yaml, not a generic template), and "
        'build.gradle sets minifyEnabled true + shrinkResources true for '
        'release. NOT build-verified — no working Android toolchain in '
        'this sandbox (Gradle daemon crashes / JDK mismatches, unrelated '
        'to this change, confirmed multiple times this session). R8 '
        'failures are a real, common release-only bug class; a real '
        'device smoke test on an actual minified build is required '
        'before this is a real PASS. No .github/workflows CI release '
        'lane still genuinely does not exist.',
    sourceFile: 'android/app/build.gradle, android/app/proguard-rules.pro',
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
