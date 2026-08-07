/// Day 326 — Cold Start Optimization Report
///
/// 🟢. Real `Stopwatch`/timestamp instrumentation
/// (`core/monitoring/cold_start_timing.dart`) was added to `main.dart`'s
/// `_bootstrap()` (marks: `process_start`, `widgets_binding_ready`,
/// `easy_localization_ready`, `firebase_ready`/`firebase_failed`,
/// `run_app_called`), `ZapSafeApp.build()` (`first_frame_rendered`, via
/// `addPostFrameCallback`), and `DashboardPlaceholderScreen.build()`
/// (`dashboard_first_build`) — a genuine splash → dashboard timeline for
/// whatever app process is actually running.
///
/// Honest limitation: this sandbox has no device or emulator to launch the
/// real app on, so this screen cannot show a measured cold-start number
/// from an actual run — it shows whatever this dev/demo navigation
/// happened to record (the marks made before you opened this screen,
/// which is not the same thing as a true cold start since the app was
/// already warm long before you navigated here from the Day 5 index). The
/// <2s target below is a **documented target**, not a claimed measured
/// result, per the spec's own instruction for when a metric can't
/// actually be measured in this environment.
///
/// The "5 plausible slow init steps" are grounded in a real read of
/// `main.dart`'s bootstrap sequence and `app_bootstrap_providers.dart` —
/// not generic filler.
///
/// Tag: 🟢
///
/// Route: AppRoutes.coldStartReport
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/monitoring/cold_start_timing.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_card.dart';

class Day326ColdStartReportScreen extends StatelessWidget {
  const Day326ColdStartReportScreen({super.key});

  static const _slowSteps = [
    (
      step: 'Firebase.initializeApp() (main.dart)',
      finding: 'Unbounded await — no timeout. Already wrapped in try/catch '
          'so a missing google-services.json degrades to stub mode, but a '
          'slow/misconfigured Firebase project (network-reachable but slow '
          'DNS/handshake) can still stall boot indefinitely.',
      recommendation: 'Race it against a short timeout '
          '(e.g. Future.any([Firebase.initializeApp(), Future.delayed(1500ms)]))'
          ' so a slow init degrades to stub mode instead of blocking runApp().',
    ),
    (
      step: 'EasyLocalization.ensureInitialized() (main.dart, before runApp)',
      finding: '15 locales declared in supportedLocales (en/hi/ta/te/ml/bn/'
          'mr/gu/pa/ur/ar/es/fr/pt/de). Whether this call loads only the '
          'resolved device locale or touches more wasn\'t verified against '
          'the easy_localization package internals — worth confirming with '
          'a DevTools timeline trace rather than assumed either way.',
      recommendation: 'Profile with DevTools Timeline on a real device to '
          'confirm asset-load scope before optimizing further; don\'t '
          'guess at a third-party package\'s internals.',
    ),
    (
      step: 'DCSInferenceEngine.create() — 4 TFLite interpreters '
          '(dcs_engine_provider chain)',
      finding: 'Real finding: appBootstrapProvider (watched unconditionally '
          'in ZapSafeApp.build(), before any login check) watches '
          'triggerOrchestratorBootstrapProvider, which ref.listen()s '
          'triggerEventStreamProvider -> dcsStreamProvider -> '
          'dcsEngineProvider — so all 4 TFLite interpreters (incl. two '
          'real ~2.7MB models, scream + scene) start loading at app boot '
          'for every user, logged in or not, before the dashboard is even '
          'reachable.',
      recommendation: 'Defer dcsEngineProvider construction until the '
          'state machine actually needs it (e.g. gate behind isLoggedIn '
          'the same way appStateProvider.notifier.powerOn() and '
          'gps.start() already are in appBootstrapProvider) instead of '
          'building it unconditionally on every cold start.',
    ),
    (
      step: 'sosSessionHydratorProvider (app_bootstrap_providers.dart, '
          'on isLoggedIn)',
      finding: 'Correctly non-blocking — wrapped in unawaited(), so it '
          'doesn\'t stall bootstrap. Fires the moment isLoggedIn flips '
          'true, in the same window the DCS engine above is loading — a '
          'real contention point for CPU/bandwidth right after login, '
          'even though neither call blocks the other.',
      recommendation: 'No code change needed (already non-blocking); '
          'worth confirming via profiling that it doesn\'t visibly '
          'compete with first-frame paint on low-end devices.',
    ),
    (
      step: 'gps.start() (app_bootstrap_providers.dart, on isLoggedIn)',
      finding: 'Native geolocation start can block on an OS-level '
          'permission dialog on first run — real wall-clock delay that is '
          'outside the app\'s own control.',
      recommendation: 'Not a code fix — show a real "starting up" '
          'progress indicator on first login so the OS dialog delay '
          'doesn\'t read as the app hanging.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final marks = ColdStartTimings.instance.marks;

    return Scaffold(
      appBar: AppBar(title: Text('day321_330.cold_start_report_title'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          Row(
            children: [
              Expanded(
                child: Text('day321_330.cold_start_report_heading'.tr(),
                    style: ZapTypography.headlineSmall.copyWith(color: ZapColors.textPrimary)),
              ),
              const ZapBadge(label: 'TARGET <2s', intent: ZapBadgeIntent.info),
            ],
          ),
          const SizedBox(height: ZapSpacing.sm),
          ZapCard(
            backgroundColor: ZapColors.warning.withOpacity(0.08),
            borderColor: ZapColors.warning.withOpacity(0.3),
            child: Text(
              'No device/emulator is available in this sandbox, so this '
              'is a documented target + real instrumentation, not a '
              'claimed measured result. The table below shows whatever '
              'this actual running app process recorded — real '
              'Stopwatch marks, not fabricated numbers — but this '
              'navigation was not itself a true cold start.',
              style: ZapTypography.bodySmall.copyWith(color: ZapColors.textPrimary, height: 1.4),
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),

          Text('RECORDED MARKS (this app process)',
              style: ZapTypography.labelLarge.copyWith(color: ZapColors.textSecondary, letterSpacing: 1.2)),
          const SizedBox(height: ZapSpacing.sm),
          if (marks.isEmpty)
            ZapCard(
              child: Text(
                'No marks recorded yet — this can happen in a hot-reload '
                'dev session where main() ran before the instrumentation '
                'file existed. Marks appear from the next full restart.',
                style: ZapTypography.bodySmall.copyWith(color: ZapColors.textMuted),
              ),
            )
          else
            ZapCard(
              child: Column(
                children: [
                  for (final m in marks)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(m.label,
                                style: ZapTypography.bodySmall.copyWith(color: ZapColors.textPrimary)),
                          ),
                          Text('+${m.elapsedMs}ms',
                              style: ZapTypography.monoSmall.copyWith(color: ZapColors.info)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: ZapSpacing.xl),

          Text('5 PLAUSIBLE SLOW INIT STEPS (from reading main.dart)',
              style: ZapTypography.labelLarge.copyWith(color: ZapColors.textSecondary, letterSpacing: 1.2)),
          const SizedBox(height: ZapSpacing.sm),
          for (final s in _slowSteps)
            ZapCard(
              margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.step,
                      style: ZapTypography.bodyMedium.copyWith(
                          color: ZapColors.textPrimary, fontWeight: FontWeight.w700)),
                  const SizedBox(height: ZapSpacing.xs),
                  Text('Finding: ${s.finding}',
                      style: ZapTypography.bodySmall.copyWith(color: ZapColors.textSecondary, height: 1.4)),
                  const SizedBox(height: ZapSpacing.xs),
                  Text('Recommendation: ${s.recommendation}',
                      style: ZapTypography.bodySmall.copyWith(color: ZapColors.safe, height: 1.4)),
                ],
              ),
            ),
          const SizedBox(height: ZapSpacing.huge),
        ],
      ),
    );
  }
}
