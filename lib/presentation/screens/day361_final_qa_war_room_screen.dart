/// Day 361 — Final QA War Room
///
/// Section L (Days 361-365, Public Launch Week): a live P0/P1/P2 bug
/// checklist that gates "ready to launch" on whether any P0 is still open.
///
/// **This is NOT a fictional bug list.** Every P0 item below is a real,
/// currently-open blocker already found by this project's own prior audits
/// on `main` and grepped again while building this screen:
/// - Release build signed with DEBUG keys — `android/app/build.gradle`'s
///   `buildTypes.release` reads `signingConfig signingConfigs.debug` (Day 336).
/// - No TLS certificate/SPKI pinning — `api_client.dart` builds a plain
///   `Dio(BaseOptions(...))`, no pinning package in `pubspec.yaml` (Day 336).
/// - `FLAG_SECURE` unset — no screen-capture/recents-thumbnail blocking
///   anywhere in `android/app/src/main` (Day 336).
/// - SOS trigger button hardcodes English text + `TextDirection.ltr` for its
///   TalkBack/VoiceOver countdown announcement — breaks screen-reader users
///   on RTL/non-English locales during the app's most safety-critical flow
///   (Day 344, `sos_trigger_button.dart:126/146/157`).
/// - Tamil and Telugu translation files (`ta.json`, `te.json`) have ZERO
///   `onboarding.*` keys — falls back to English at runtime for those two
///   locales' entire first-run flow (Day 347).
///
/// P1/P2 items are likewise pulled from real Day 336/337/344/345 findings,
/// not invented filler. Every item defaults to OPEN (unresolved) — nothing
/// here is pre-checked as fixed. "Ready to launch" is computed live: it is
/// FALSE as long as any P0 is open, which is true right now.
///
/// Tag: 🟢 FRONTEND-ONLY · real seeded findings, real gate logic, honest
/// defaults · toggling an item to "resolved" is a local checklist action
/// only — it does not verify or ship an actual fix.
///
/// Route: [AppRoutes.finalQaWarRoom] → `/day-361-final-qa-war-room`
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
const _kAccent = Color(0xFFDC2626);
const _kTabs = ['Checklist', 'Info'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');

enum _Priority { p0, p1, p2 }

String _priorityLabel(_Priority p) => switch (p) {
      _Priority.p0 => 'P0 · BLOCKER',
      _Priority.p1 => 'P1 · HIGH',
      _Priority.p2 => 'P2 · MEDIUM',
    };

Color _priorityColor(_Priority p) => switch (p) {
      _Priority.p0 => ZapColors.danger,
      _Priority.p1 => ZapColors.warning,
      _Priority.p2 => ZapColors.info,
    };

class _BugItem {
  const _BugItem({
    required this.id,
    required this.priority,
    required this.title,
    required this.detail,
    required this.source,
    required this.sourceRoute,
  });

  final String id;
  final _Priority priority;
  final String title;
  final String detail;
  final String source;
  final String? sourceRoute;
}

// Real, currently-open findings — grep-verified against this repo, not
// fabricated. See the file header for the P0 evidence trail.
const _kBugs = [
  _BugItem(
    id: 'p0_debug_signing',
    priority: _Priority.p0,
    title: 'Release build signed with DEBUG keys',
    detail: 'UPDATED: build.gradle now reads real signing credentials from '
        'android/key.properties (gitignored, see key.properties.example for '
        'the real setup steps) when present, falling back to debug-signing '
        '+ a loud build-time warning otherwise. No real keystore/key.'
        'properties exists in this environment (cannot be created here — '
        'needs the actual release keystore owner) and this sandbox has no '
        'working Android build toolchain to verify the Gradle change even '
        'compiles. Stays OPEN until both a real keystore exists AND a real '
        'build is verified.',
    source: 'Day 336 security execution',
    sourceRoute: AppRoutes.securityExecution,
  ),
  _BugItem(
    id: 'p0_cert_pinning',
    priority: _Priority.p0,
    title: 'TLS pinning now real; static pins are an operational risk',
    detail: 'Fixed: cert_pinning.dart pins real, live-captured SHA-256(DER) '
        'hashes for zapsafe.app\'s actual cert chain (leaf + intermediate '
        '+ root), wired into both real Dio clients via '
        'SecurityContext(withTrustedRoots: false) — required for '
        'badCertificateCallback to fire at all on an already-trusted '
        'cert. Not build/device-verified in this sandbox. Still open: '
        'pins are static/baked into the binary — the leaf cert rotates '
        '~90 days, so these need re-verifying before every release or a '
        'future build could hard-fail all API traffic including SOS '
        'dispatch.',
    source: 'Day 336 security execution',
    sourceRoute: AppRoutes.securityExecution,
  ),
  _BugItem(
    id: 'p0_flag_secure',
    priority: _Priority.p0,
    title: 'FLAG_SECURE unset — screenshots/recents not blocked',
    detail: 'No FLAG_SECURE, no setRecentsScreenshotEnabled anywhere under '
        'android/app/src/main. Evidence vault and active SOS screens can be '
        'screenshotted or appear in the recents thumbnail.',
    source: 'Day 336 security execution',
    sourceRoute: AppRoutes.securityExecution,
  ),
  _BugItem(
    id: 'p0_sos_rtl_tts',
    priority: _Priority.p0,
    title: 'SOS trigger hardcodes English + LTR for screen readers',
    detail: "sos_trigger_button.dart's TalkBack/VoiceOver countdown "
        "announcement hardcodes TextDirection.ltr AND English text via "
        "SemanticsService.announce(), bypassing .tr() entirely (lines "
        '126/146/157). Breaks the single most safety-critical flow for '
        'ar/ur/fa and every non-English screen-reader user.',
    source: 'Day 344 RTL regression',
    sourceRoute: AppRoutes.rtl25LangRegression,
  ),
  _BugItem(
    id: 'p0_ta_te_onboarding',
    priority: _Priority.p0,
    title: 'Tamil + Telugu onboarding translations missing entirely',
    detail: 'ta.json and te.json have ZERO onboarding.* keys — the whole '
        "namespace is absent, not just untranslated. Falls back to English "
        'at runtime for a first-run flow in two of India\'s largest languages.',
    source: 'Day 347 Indic copy review',
    sourceRoute: AppRoutes.indicCopyReview,
  ),
  _BugItem(
    id: 'p1_root_detection_sim',
    priority: _Priority.p1,
    title: 'Root/jailbreak detection now real; Play Integrity still missing',
    detail: 'Fixed: safe_device is a real pubspec.yaml dependency now. '
        'DeviceIntegrityService runs a real on-device scan, wired into '
        'day185_root_detection_screen.dart\'s Run Scan button in place '
        'of the old fake _simulateJailbreakProvider toggle. Not build/'
        'device-verified in this sandbox. Still open: no Play Integrity/'
        'SafetyNet server-side attestation — safe_device alone is a '
        'client-only signal, spoofable by a determined attacker in a way '
        'a real signed attestation token is not.',
    source: 'Day 336 security execution',
    sourceRoute: AppRoutes.securityExecution,
  ),
  _BugItem(
    id: 'p1_no_obfuscation',
    priority: _Priority.p1,
    title: 'ProGuard/R8 + obfuscation not configured',
    detail: 'UPDATED: android/app/proguard-rules.pro now exists with real, '
        'dependency-scoped keep rules (tflite_flutter, google_sign_in, '
        "Flutter's own required classes), and build.gradle now sets "
        'minifyEnabled true + shrinkResources true for release. NOT '
        'build-verified — no working Android toolchain in this sandbox '
        '(confirmed: Gradle daemon crashes / JDK mismatches unrelated to '
        'this change). R8 failures are a real, common release-only bug '
        'class; a real device smoke test on an actual minified release '
        'build is required before this can be marked resolved. No CI '
        '--obfuscate --split-debug-info lane still genuinely does not '
        'exist.',
    source: 'Day 336 security execution',
    sourceRoute: AppRoutes.securityExecution,
  ),
  _BugItem(
    id: 'p1_vault_pin_hardcoded',
    priority: _Priority.p1,
    title: 'Vault PIN now real and user-configurable; Hive still never initialised',
    detail: "Fixed: kVaultDevPin = '1234' (shared by every install) is gone. "
        'VaultPinStorage now stores a salted SHA-256 hash of a real, '
        'user-chosen PIN in FlutterSecureStorage, set via a real 2-step '
        'setup flow in day82_evidence_vault_screen.dart (choose → confirm), '
        'with weak-PIN rejection (no straight runs / repeated digits) and '
        'the LP23 wipe cascade now also clearing the stored PIN so a wipe '
        'forces real re-setup. Not build/device-verified in this sandbox — '
        'flutter analyze/test only. Still open: hive_flutter is a pubspec '
        'dependency that Hive.initFlutter() never actually calls anywhere '
        'in lib/.',
    source: 'Day 336 security execution',
    sourceRoute: AppRoutes.securityExecution,
  ),
  _BugItem(
    id: 'p1_biometric_not_wired',
    priority: _Priority.p1,
    title: 'Biometric unlock now real for the vault; no app-wide lock yet',
    detail: 'Fixed: BiometricService (lib/data/services/biometric_service.'
        'dart) is a real standalone implementation, wired as a fast-path '
        'into day82_evidence_vault_screen.dart alongside the real vault '
        'PIN. MainActivity now extends FlutterFragmentActivity (required '
        'by local_auth on Android) with USE_BIOMETRIC / '
        'NSFaceIDUsageDescription declared on both platforms. Not build/'
        'device-verified in this sandbox. Still open: LocalAuthentication '
        'is still only constructed inside day183/day184\'s own demo code '
        'for the app-wide auto-lock concept those screens describe — that '
        'part remains unbuilt.',
    source: 'Day 336 security execution',
    sourceRoute: AppRoutes.securityExecution,
  ),
  _BugItem(
    id: 'p1_dpdp_backend_unwired',
    priority: _Priority.p1,
    title: 'Consent sync + sessions + retention + audit-log now all wired',
    detail: 'Fixed: lib/data/services/account_service.dart + '
        'account_providers.dart now call all 4 real /api/v1/account/* DPDP '
        'routes — day319_gdpr_consent_wire_screen.dart (consent, real '
        'GET/PUT), day179_active_sessions_screen.dart Tab 1 (sessions, real '
        'GET/DELETE/revoke-all), day176_data_retention_settings_screen.dart '
        '(retention, real GET/PUT for the 2 of 7 categories the backend '
        'actually has fields for — evidence + gps), '
        'day173_data_access_audit_screen.dart (audit-log, real GET across '
        'up to 3 pages, honestly mapping the sparser real shape — bucketed '
        'type + server description + metadata, no per-entry category/'
        'actor/device/city/suspicious — onto this screen\'s richer UI '
        'model). Not build/device-verified against a live backend in this '
        'sandbox.',
    source: 'Day 337 legal blockers live',
    sourceRoute: AppRoutes.legalBlockersLive,
  ),
  _BugItem(
    id: 'p2_third_party_sharing',
    priority: _Priority.p2,
    title: 'Third-party sharing transparency not implemented',
    detail: 'No backend route or frontend screen exists for third-party '
        'data-sharing disclosure under any path — genuinely unbuilt on '
        'both sides, not just unwired.',
    source: 'Day 337 legal blockers live',
    sourceRoute: AppRoutes.legalBlockersLive,
  ),
  _BugItem(
    id: 'p2_rtl_minor_findings',
    priority: _Priority.p2,
    title: 'Minor RTL mirroring gaps (back icon, padding, alignment)',
    detail: 'OTP back-icon does not auto-mirror, plus physical '
        'Alignment.centerRight / EdgeInsets.only(right:) usages in OTP, '
        'onboarding step dots, vault tamper badge, and dashboard app bar.',
    source: 'Day 344 RTL regression',
    sourceRoute: AppRoutes.rtl25LangRegression,
  ),
  _BugItem(
    id: 'p2_legacy_locale_gaps',
    priority: _Priority.p2,
    title: '13 legacy locales still missing ~200 keys each',
    detail: 'Day 345\'s live scanner found 13 locale files still at 75/275 '
        'keys against en.json, plus an unlisted ja.json draft at 20/275 not '
        'even wired into kSupportedLanguages.',
    source: 'Day 345 i18n missing key scanner',
    sourceRoute: AppRoutes.i18nMissingKeyScanner,
  ),
];

Map<String, dynamic> _warRoomPayload(Map<String, bool> resolved) {
  final byPriority = {
    for (final p in _Priority.values)
      p.name: _kBugs.where((b) => b.priority == p).length,
  };
  final openP0 = _kBugs
      .where((b) => b.priority == _Priority.p0 && resolved[b.id] != true)
      .length;
  return {
    'endpoint': 'LOCAL — no backend war-room API exists',
    'total_items': _kBugs.length,
    'by_priority': byPriority,
    'open_p0_count': openP0,
    'ready_to_launch': openP0 == 0,
    'resolved_ids': resolved.entries.where((e) => e.value).map((e) => e.key).toList(),
    'wire_note': 'Real seeded findings from Day 336/337/344/345/347 audits · '
        'gate logic is real, toggle state is local-only',
  };
}

String _buildExportReport(Map<String, bool> resolved) {
  final buf = StringBuffer('ZapSafe Final QA War Room — Day 361\n\n');
  for (final p in _Priority.values) {
    final items = _kBugs.where((b) => b.priority == p).toList();
    if (items.isEmpty) continue;
    buf.writeln('── ${_priorityLabel(p)} ──');
    for (final b in items) {
      final status = resolved[b.id] == true ? 'RESOLVED' : 'OPEN';
      buf.writeln('[$status] ${b.title} (${b.source})');
    }
    buf.writeln();
  }
  final openP0 = _kBugs
      .where((b) => b.priority == _Priority.p0 && resolved[b.id] != true)
      .length;
  buf.writeln('open_p0_count=$openP0');
  buf.writeln('ready_to_launch=${openP0 == 0}');
  return buf.toString();
}

// ── Providers ─────────────────────────────────────────────────────────────────
final _d361TabProvider = StateProvider<int>((ref) => 0);
// Every item starts unresolved/open — honest default, no pre-filled green.
final _d361ResolvedProvider = StateProvider<Map<String, bool>>((ref) => {});

/// Public, live derived count of open P0 blockers — added for Day 390's
/// "Launch readiness" section so it can read this screen's REAL live state
/// (same in-memory [_d361ResolvedProvider] this screen itself uses) instead
/// of a hardcoded "5" that could silently drift stale. Not persisted (same
/// as [_d361ResolvedProvider] itself) — resets to the real default (5 open,
/// since every P0 is a real currently-open finding) on a fresh app launch,
/// and reflects any items resolved in this checklist during the current
/// session, live, everywhere it's watched.
final finalQaOpenP0CountProvider = Provider<int>((ref) {
  final resolved = ref.watch(_d361ResolvedProvider);
  return _kBugs.where((b) => b.priority == _Priority.p0 && resolved[b.id] != true).length;
});

// ── Screen ────────────────────────────────────────────────────────────────────
class Day361FinalQaWarRoomScreen extends ConsumerWidget {
  const Day361FinalQaWarRoomScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolved = ref.watch(_d361ResolvedProvider);
    final openP0 = _kBugs
        .where((b) => b.priority == _Priority.p0 && resolved[b.id] != true)
        .length;

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: Text('day361_370.qa_war_room_title'.tr()),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (openP0 == 0 ? ZapColors.safe : ZapColors.danger).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: (openP0 == 0 ? ZapColors.safe : ZapColors.danger).withOpacity(0.45),
                  ),
                ),
                child: Text(
                  openP0 == 0 ? 'READY' : '$openP0 P0 OPEN',
                  style: TextStyle(
                    color: openP0 == 0 ? ZapColors.safe : ZapColors.danger,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _TabBar(tab: ref.watch(_d361TabProvider), onSelect: (i) => ref.read(_d361TabProvider.notifier).state = i),
          Expanded(
            child: switch (ref.watch(_d361TabProvider)) {
              0 => const _ChecklistTab(),
              _ => const _InfoTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Checklist ──────────────────────────────────────────────────────────
class _ChecklistTab extends ConsumerWidget {
  const _ChecklistTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolved = ref.watch(_d361ResolvedProvider);
    final openP0 = _kBugs
        .where((b) => b.priority == _Priority.p0 && resolved[b.id] != true)
        .length;
    final readyToLaunch = openP0 == 0;

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: (readyToLaunch ? ZapColors.safe : ZapColors.danger).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: (readyToLaunch ? ZapColors.safe : ZapColors.danger).withOpacity(0.4),
              width: 2,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                readyToLaunch ? Icons.check_circle_rounded : Icons.gpp_bad_rounded,
                color: readyToLaunch ? ZapColors.safe : ZapColors.danger,
                size: 28,
              ),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      readyToLaunch ? 'READY TO LAUNCH' : 'NOT READY — $openP0 P0 blocker(s) open',
                      style: TextStyle(
                        color: readyToLaunch ? ZapColors.safe : ZapColors.danger,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      readyToLaunch
                          ? 'All seeded P0 items are marked resolved in this checklist. '
                              'Verify each fix actually shipped before treating this as real.'
                          : 'These are real, currently-open findings from Day 336/344/347 '
                              'audits on main. The gate below stays red until every P0 item '
                              'is genuinely fixed and verified — not just toggled here.',
                      style: const TextStyle(color: ZapColors.textSecondary, fontSize: 11, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        for (final p in _Priority.values) ...[
          _PrioritySection(priority: p, resolved: resolved, onToggle: (id, v) {
            ref.read(_d361ResolvedProvider.notifier).state = {...resolved, id: v};
          }),
          const SizedBox(height: ZapSpacing.lg),
        ],
        FilledButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: _buildExportReport(resolved)));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('War room checklist copied — paste into your share sheet of choice.')),
            );
          },
          icon: const Icon(Icons.ios_share_rounded, size: 18),
          label: const Text('Export checklist (copy for share sheet)'),
          style: FilledButton.styleFrom(backgroundColor: _kAccent, minimumSize: const Size(double.infinity, 48)),
        ),
        const SizedBox(height: ZapSpacing.sm),
        OutlinedButton.icon(
          onPressed: () {
            ref.read(_d361ResolvedProvider.notifier).state = {};
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Checklist reset — all items back to open.')),
            );
          },
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Reset all to open'),
        ),
      ],
    );
  }
}

class _PrioritySection extends StatelessWidget {
  const _PrioritySection({required this.priority, required this.resolved, required this.onToggle});

  final _Priority priority;
  final Map<String, bool> resolved;
  final void Function(String id, bool value) onToggle;

  @override
  Widget build(BuildContext context) {
    final items = _kBugs.where((b) => b.priority == priority).toList();
    final color = _priorityColor(priority);
    final openCount = items.where((b) => resolved[b.id] != true).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: color.withOpacity(0.45)),
              ),
              child: Text(_priorityLabel(priority), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900)),
            ),
            const Spacer(),
            Text('$openCount/${items.length} open', style: const TextStyle(color: ZapColors.textMuted, fontSize: 10)),
          ],
        ),
        const SizedBox(height: ZapSpacing.sm),
        ...items.map((b) {
          final isResolved = resolved[b.id] == true;
          return Container(
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: (isResolved ? ZapColors.safe : color).withOpacity(0.35)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: isResolved,
                  activeColor: ZapColors.safe,
                  onChanged: (v) => onToggle(b.id, v ?? false),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.title,
                        style: TextStyle(
                          color: ZapColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          decoration: isResolved ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(b.detail, style: const TextStyle(color: ZapColors.textSecondary, fontSize: 10, height: 1.4)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(b.source, style: const TextStyle(color: ZapColors.textMuted, fontSize: 9, fontStyle: FontStyle.italic)),
                          ),
                          if (b.sourceRoute != null)
                            TextButton(
                              onPressed: () => context.push(b.sourceRoute!),
                              style: TextButton.styleFrom(minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2)),
                              child: const Text('Open source', style: TextStyle(fontSize: 10)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ── Tab 1: Info ───────────────────────────────────────────────────────────────
class _InfoTab extends ConsumerWidget {
  const _InfoTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payload = _warRoomPayload(ref.watch(_d361ResolvedProvider));

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text('Final QA War Room', style: TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
        const Text(
          'Section L Day 1/5 (Public Launch Week) · real seeded findings, '
          'not a fictional bug list.',
          style: TextStyle(color: ZapColors.textMuted, fontSize: 11),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(color: ZapColors.bgCard, borderRadius: BorderRadius.circular(8), border: Border.all(color: ZapColors.border)),
          child: SelectableText(
            _kJsonEncoder.convert(payload),
            style: const TextStyle(color: ZapColors.textSecondary, fontSize: 10, fontFamily: 'monospace', height: 1.45),
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: _kJsonEncoder.convert(payload)));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('War room spec copied.')));
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy spec JSON'),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(color: ZapColors.info.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: ZapColors.info.withOpacity(0.3))),
          child: const Text(
            'Next: Day 362 — Play Store Submission Executor (all steps '
            'default unchecked; nothing has been submitted).',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(label: const Text('Day 336 Security'), onPressed: () => context.push(AppRoutes.securityExecution)),
            ActionChip(label: const Text('Day 337 Legal'), onPressed: () => context.push(AppRoutes.legalBlockersLive)),
            ActionChip(label: const Text('Day 344 RTL'), onPressed: () => context.push(AppRoutes.rtl25LangRegression)),
            ActionChip(label: const Text('Day 347 Indic Copy'), onPressed: () => context.push(AppRoutes.indicCopyReview)),
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
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: selected ? _kAccent : Colors.transparent, width: 2))),
                child: Text(
                  _kTabs[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(color: selected ? _kAccent : ZapColors.textMuted, fontWeight: selected ? FontWeight.w800 : FontWeight.w500, fontSize: 12),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
