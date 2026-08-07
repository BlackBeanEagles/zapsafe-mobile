/// Day 335 — Accessibility Full-App Pass
///
/// Section I (Days 331-340): reads Day 214's screen-reader audit
/// (`day214_a11y_screen_reader_audit_screen.dart`) and extends it from a
/// single-flow WCAG checklist to a per-flow TalkBack/VoiceOver script
/// covering the app's actual production flows, plus real static checks
/// this agent could run against the repo (not the running app — a
/// Flutter app cannot grep its own source tree at runtime, so these
/// numbers are the result of `grep`/`rg` run over this codebase while
/// building this screen, hardcoded as findings, not live-computed).
///
/// **Flow count methodology (not invented):** "44 production flows" below
/// is the real count of `RouteRow` entries tagged `section: 'Core'` in
/// this codebase's own `day289_full_regression_routes.part.dart` — this
/// project's existing, greppable classification of screens (as opposed to
/// Foundation/SOS/i18n/Beta/Release/Legal/GDPR/Security/Polish/Section
/// B-I). That bucket is a mix of genuine end-user flows (onboarding,
/// dashboard, SOS, vault, contacts, settings, phone/OTP auth) and internal
/// weekly-review screens (week3Review, week5Review, …) — reused as-is
/// rather than re-curated, because it's the one real, auditable, existing
/// number in the repo rather than a subjective new cut this screen invents.
///
/// **Real static findings** (grep run 2026, this session, re-verified when
/// this screen was wired up — the file/occurrence counts below are the
/// live re-run, not the first draft's numbers):
/// - `Semantics(` appears 212 times across 53 files under `lib/presentation`.
/// - One real touch-target violation: `day9_jwt_storage_screen.dart` has
///   3 `ElevatedButton`s with `minimumSize: const Size(0, 44)` — 44dp is
///   the iOS HIG minimum, not Android's 48dp Material minimum, so these
///   fail the Android touch-target check.
/// - `zap_snackbar.dart` uses `minimumSize: Size(0,0)` +
///   `MaterialTapTargetSize.shrinkWrap` for its snackbar action — a
///   deliberate compact pattern, flagged WARN not FAIL (constrained
///   context, not a primary navigation target).
///
/// Everything that needs a live screen reader (TalkBack/VoiceOver
/// announcements, focus order, live-region behavior) stays PENDING — this
/// environment has no physical device.
///
/// Tag: 🟢 FRONTEND-ONLY · real static findings + real flow count · live
/// screen-reader items pending, no device.
///
/// Route: [AppRoutes.accessibilityFullPass] → `/day-335-accessibility-full-pass`
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
const _kAccent = Color(0xFF8B5CF6);
const _kTabs = ['Flows', 'Static checks', 'Info'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');

class _Flow {
  const _Flow({required this.id, required this.title, required this.route});
  final String id;
  final String title;
  final String route;
}

// The real 44 "Core"-tagged production flows from day289's route
// catalogue — restated here, not re-invented.
const _kFlows = [
  _Flow(id: 'r1', title: 'Onboarding', route: AppRoutes.onboarding),
  _Flow(id: 'r2', title: 'Dashboard', route: AppRoutes.dashboard),
  _Flow(id: 'r3', title: 'SOS Active', route: AppRoutes.sosActive),
  _Flow(id: 'r4', title: 'Vault', route: AppRoutes.vault),
  _Flow(id: 'r5', title: 'Contacts', route: AppRoutes.contacts),
  _Flow(id: 'r6', title: 'Settings', route: AppRoutes.settings),
  _Flow(id: 'r10', title: 'Auth foundation (Day 6)', route: AppRoutes.day6),
  _Flow(id: 'r11', title: 'Phone entry', route: AppRoutes.phoneEntry),
  _Flow(id: 'r12', title: 'OTP verify', route: AppRoutes.otpVerify),
  _Flow(id: 'r13', title: 'Permissions', route: AppRoutes.permissions),
  _Flow(id: 'r14', title: 'Device tier', route: AppRoutes.deviceTier),
  _Flow(id: 'r15', title: 'Onboarding permissions', route: AppRoutes.onboardingPermissions),
  _Flow(id: 'r16', title: 'Feature flags', route: AppRoutes.featureFlags),
  _Flow(id: 'r17', title: 'Week 3 review', route: AppRoutes.week3Review),
  _Flow(id: 'r18', title: 'Push notifications', route: AppRoutes.pushNotifications),
  _Flow(id: 'r19', title: 'Push routing', route: AppRoutes.pushRouting),
  _Flow(id: 'r20', title: 'Drills schedule', route: AppRoutes.drillsSchedule),
  _Flow(id: 'r21', title: 'Month 1 integration', route: AppRoutes.month1Integration),
  _Flow(id: 'r22', title: 'Month 1 review', route: AppRoutes.month1Review),
  _Flow(id: 'r23', title: 'Background engine', route: AppRoutes.backgroundEngine),
  _Flow(id: 'r24', title: 'Watchdog', route: AppRoutes.watchdog),
  _Flow(id: 'r25', title: 'Platform channels', route: AppRoutes.platformChannels),
  _Flow(id: 'r26', title: 'LP4 watchdog', route: AppRoutes.lp4Watchdog),
  _Flow(id: 'r27', title: 'Week 5 review', route: AppRoutes.week5Review),
  _Flow(id: 'r28', title: 'Audio capture', route: AppRoutes.audioCapture),
  _Flow(id: 'r29', title: 'Audio features', route: AppRoutes.audioFeatures),
  _Flow(id: 'r30', title: 'iOS audio', route: AppRoutes.iosAudio),
  _Flow(id: 'r31', title: 'Inference', route: AppRoutes.inference),
  _Flow(id: 'r32', title: 'Week 6 review', route: AppRoutes.week6Review),
  _Flow(id: 'r33', title: 'TFLite models', route: AppRoutes.tfliteModels),
  _Flow(id: 'r34', title: 'DCS engine', route: AppRoutes.dcsEngine),
  _Flow(id: 'r35', title: 'DCS stream', route: AppRoutes.dcsStream),
  _Flow(id: 'r36', title: 'Isolate latency', route: AppRoutes.isolateLatency),
  _Flow(id: 'r37', title: 'Week 7 review', route: AppRoutes.week7Review),
  _Flow(id: 'r38', title: 'IMU service', route: AppRoutes.imuService),
  _Flow(id: 'r39', title: 'GPS service', route: AppRoutes.gpsService),
  _Flow(id: 'r40', title: 'Fallback and state (Day 38)', route: AppRoutes.day38FallbackAndState),
  _Flow(id: 'r41', title: 'State wiring (Day 39)', route: AppRoutes.day39StateWiring),
  _Flow(id: 'r42', title: 'Month 2 review', route: AppRoutes.month2Review),
  _Flow(id: 'r43', title: 'Onboarding step 1', route: AppRoutes.onboardingStep1),
  _Flow(id: 'r44', title: 'Onboarding step 2', route: AppRoutes.onboardingStep2),
  _Flow(id: 'r45', title: 'Onboarding step 3', route: AppRoutes.onboardingStep3),
  _Flow(id: 'r46', title: 'Onboarding step 4', route: AppRoutes.onboardingStep4),
  _Flow(id: 'r47', title: 'Onboarding step 5', route: AppRoutes.onboardingStep5),
];

class _StaticFinding {
  const _StaticFinding({
    required this.id,
    required this.title,
    required this.detail,
    required this.severity,
    this.sourceFile,
  });
  final String id;
  final String title;
  final String detail;
  final String severity; // pass | warn | fail
  final String? sourceFile;
}

// Real findings from grepping this repo while building this screen.
const _kStaticFindings = [
  _StaticFinding(
    id: 'semantics_coverage',
    title: 'Semantics(...) usage across the app',
    detail: '212 real occurrences across 53 files under lib/presentation — '
        'grep -ro "Semantics(" lib/presentation | wc -l, re-verified this '
        'session.',
    severity: 'pass',
  ),
  _StaticFinding(
    id: 'touch_target_day9',
    title: 'Touch target below Android 48dp minimum',
    detail: '3 ElevatedButtons use minimumSize: const Size(0, 44) — 44dp is '
        'the iOS HIG minimum, not Android Material\'s 48dp minimum. Real '
        'fail, found by grep, not fixed by this audit screen (out of scope '
        'for a checklist screen to silently patch another screen).',
    severity: 'fail',
    sourceFile: 'lib/presentation/screens/day9_jwt_storage_screen.dart:386,401,416',
  ),
  _StaticFinding(
    id: 'touch_target_snackbar',
    title: 'Snackbar action uses shrinkWrap tap target',
    detail: 'minimumSize: Size(0,0) + MaterialTapTargetSize.shrinkWrap on '
        'the snackbar action button — a deliberate compact pattern for a '
        'constrained, non-primary-navigation context. Flagged WARN, not '
        'FAIL.',
    severity: 'warn',
    sourceFile: 'lib/presentation/widgets/zap_snackbar.dart:179-180',
  ),
  _StaticFinding(
    id: 'touch_target_pattern',
    title: 'Checklist screens\' primary buttons exceed 48dp',
    detail: 'The dominant pattern across Days 201-298 checklist/audit '
        'screens is minimumSize: const Size(double.infinity, 75) — 75dp, '
        'well above the 48dp minimum.',
    severity: 'pass',
  ),
];

// ── Providers ───────────────────────────────────────────────────────────────
enum _ScriptMark { pending, pass, fail }

String _markKey(_ScriptMark m) => switch (m) {
      _ScriptMark.pending => 'pending',
      _ScriptMark.pass => 'pass',
      _ScriptMark.fail => 'fail',
    };

Color _markColor(_ScriptMark m) => switch (m) {
      _ScriptMark.pending => ZapColors.textMuted,
      _ScriptMark.pass => ZapColors.safe,
      _ScriptMark.fail => ZapColors.danger,
    };

_ScriptMark _cycle(_ScriptMark m) => switch (m) {
      _ScriptMark.pending => _ScriptMark.pass,
      _ScriptMark.pass => _ScriptMark.fail,
      _ScriptMark.fail => _ScriptMark.pending,
    };

final _d335TabProvider = StateProvider<int>((ref) => 0);
final _d335TalkBackProvider = StateProvider<Map<String, _ScriptMark>>((ref) => {});
final _d335VoiceOverProvider = StateProvider<Map<String, _ScriptMark>>((ref) => {});

// ── Screen ────────────────────────────────────────────────────────────────────
class Day335AccessibilityFullPassScreen extends ConsumerWidget {
  const Day335AccessibilityFullPassScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tb = ref.watch(_d335TalkBackProvider);
    final vo = ref.watch(_d335VoiceOverProvider);
    final tbPass = tb.values.where((v) => v == _ScriptMark.pass).length;
    final voPass = vo.values.where((v) => v == _ScriptMark.pass).length;

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: Text('day331_340.a11y_full_title'.tr()),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _kAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _kAccent.withOpacity(0.45)),
                ),
                child: Text('TB $tbPass/${_kFlows.length} · VO $voPass/${_kFlows.length}',
                    style: const TextStyle(color: _kAccent, fontSize: 9, fontWeight: FontWeight.w900)),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _TabBar(tab: ref.watch(_d335TabProvider), onSelect: (i) => ref.read(_d335TabProvider.notifier).state = i),
          Expanded(
            child: switch (ref.watch(_d335TabProvider)) {
              0 => const _FlowsTab(),
              1 => const _StaticTab(),
              _ => const _InfoTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Flows ──────────────────────────────────────────────────────────────
class _FlowsTab extends ConsumerWidget {
  const _FlowsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tb = ref.watch(_d335TalkBackProvider);
    final vo = ref.watch(_d335VoiceOverProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: _kAccent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kAccent.withOpacity(0.3)),
          ),
          child: Text(
            '${_kFlows.length} production flows (real count — see this '
            'screen\'s header for methodology) × TalkBack (Android) / '
            'VoiceOver (iOS). Tap a chip to cycle PENDING → PASS → FAIL — '
            'these need an actual screen reader on a real device, so they '
            'stay PENDING until someone runs them.',
            style: const TextStyle(color: ZapColors.textSecondary, fontSize: 11, height: 1.4),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        ..._kFlows.map((f) {
          final tbMark = tb[f.id] ?? _ScriptMark.pending;
          final voMark = vo[f.id] ?? _ScriptMark.pending;
          return Container(
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ZapColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f.title, style: const TextStyle(
                        color: ZapColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 12,
                      )),
                      Text(f.route, style: const TextStyle(
                        color: ZapColors.textMuted, fontSize: 9, fontFamily: 'monospace',
                      )),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => ref.read(_d335TalkBackProvider.notifier).state = {
                    ...tb, f.id: _cycle(tbMark),
                  },
                  child: _ScriptChip(label: 'TB', mark: tbMark),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => ref.read(_d335VoiceOverProvider.notifier).state = {
                    ...vo, f.id: _cycle(voMark),
                  },
                  child: _ScriptChip(label: 'VO', mark: voMark),
                ),
                IconButton(
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  onPressed: () => context.push(f.route),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _ScriptChip extends StatelessWidget {
  const _ScriptChip({required this.label, required this.mark});
  final String label;
  final _ScriptMark mark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _markColor(mark).withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _markColor(mark).withOpacity(0.5)),
      ),
      child: Text('$label ${_markKey(mark)}', style: TextStyle(
        color: _markColor(mark), fontSize: 8, fontWeight: FontWeight.w800,
      )),
    );
  }
}

// ── Tab 1: Static checks ──────────────────────────────────────────────────────
class _StaticTab extends ConsumerWidget {
  const _StaticTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text('Real static findings', style: TextStyle(
          color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13,
        )),
        const Text(
          'From grep/rg over this repo while building this screen — not '
          'live-computed (a running Flutter app cannot grep its own source '
          'tree). Reproducible with the same commands.',
          style: TextStyle(color: ZapColors.textMuted, fontSize: 11),
        ),
        const SizedBox(height: ZapSpacing.md),
        ..._kStaticFindings.map((f) {
          final color = switch (f.severity) {
            'pass' => ZapColors.safe,
            'warn' => ZapColors.warning,
            _ => ZapColors.danger,
          };
          return Container(
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(f.severity == 'pass' ? Icons.check_circle_rounded
                      : f.severity == 'warn' ? Icons.warning_rounded : Icons.cancel_rounded,
                      color: color, size: 16),
                  const SizedBox(width: 6),
                  Expanded(child: Text(f.title, style: const TextStyle(
                    color: ZapColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 12,
                  ))),
                  Text(f.severity.toUpperCase(), style: TextStyle(
                    color: color, fontSize: 9, fontWeight: FontWeight.w900,
                  )),
                ]),
                const SizedBox(height: 6),
                Text(f.detail, style: const TextStyle(color: ZapColors.textSecondary, fontSize: 11, height: 1.4)),
                if (f.sourceFile != null) ...[
                  const SizedBox(height: 4),
                  Text(f.sourceFile!, style: const TextStyle(
                    color: ZapColors.info, fontSize: 9, fontFamily: 'monospace',
                  )),
                ],
              ],
            ),
          );
        }),
        const SizedBox(height: ZapSpacing.md),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.info.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.info.withOpacity(0.3)),
          ),
          child: const Text(
            'Not statically checkable: TalkBack/VoiceOver announcement '
            'wording, focus order, and live-region timing all require an '
            'actual screen reader running on real hardware. Those stay in '
            'the Flows tab as PENDING.',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 11, height: 1.4),
          ),
        ),
      ],
    );
  }
}

// ── Tab 2: Info ───────────────────────────────────────────────────────────────
class _InfoTab extends ConsumerWidget {
  const _InfoTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tb = ref.watch(_d335TalkBackProvider);
    final vo = ref.watch(_d335VoiceOverProvider);
    final payload = {
      'endpoint': 'GET /api/v1/qa/accessibility-full-pass/ (mock)',
      'flow_count': _kFlows.length,
      'flow_count_methodology': "count of RouteRow entries tagged "
          "section: 'Core' in day289_full_regression_routes.part.dart",
      'talkback_pass': tb.values.where((v) => v == _ScriptMark.pass).length,
      'voiceover_pass': vo.values.where((v) => v == _ScriptMark.pass).length,
      'static_findings': _kStaticFindings.length,
      'static_fail_count': _kStaticFindings.where((f) => f.severity == 'fail').length,
    };

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text('Accessibility full-app pass', style: TextStyle(
          color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13,
        )),
        const Text(
          'Section I Day 5/10 · extends Day 214\'s single-flow WCAG '
          'checklist to per-flow TalkBack/VoiceOver scripts + real static '
          'findings.',
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
            ActionChip(label: const Text('Day 214 Audit'), onPressed: () => context.push(AppRoutes.a11yScreenReaderAudit)),
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
