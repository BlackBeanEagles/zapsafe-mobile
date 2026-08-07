/// Production Dashboard — route `/dashboard`.
///
/// Originally a pure [PlaceholderScaffold] stub (Day 5-46 era) describing
/// what the real Day 46-50 dashboard would eventually contain. Starting
/// Day 306 this file becomes the actual production dashboard scaffold —
/// each Section F polish day (306-308) wires one more real piece into it:
///   • Day 306 — the three-tier notification banner system (top of screen).
///   • Day 307 — the long-press SOS trigger button.
///   • Day 308 — the persistent status card.
///
/// `kProductionShell` (default `true`, `lib/core/constants/app_flags.dart`)
/// makes `/dashboard` the real post-onboarding home, so this genuinely is
/// "the production dashboard", not a demo screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/monitoring/cold_start_timing.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../data/models/app_state.dart';
import '../../../domain/providers/app_state_provider.dart';
import '../../navigation/app_router.dart';
import '../../widgets/journey_mode_card.dart';
import '../../widgets/notification_tier_banners.dart';
import '../../widgets/persistent_status_card.dart';
import '../../widgets/sos_trigger_button.dart';
import '../../widgets/zap_badge.dart';
import '../../widgets/zap_card.dart';

class DashboardPlaceholderScreen extends ConsumerWidget {
  const DashboardPlaceholderScreen({super.key});

  ZapBadgeIntent _modeIntent(AppState s) => switch (s) {
        AppState.idle => ZapBadgeIntent.neutral,
        AppState.monitoring => ZapBadgeIntent.safe,
        AppState.elevated => ZapBadgeIntent.warning,
        AppState.alertPending || AppState.sosActive || AppState.escalating =>
          ZapBadgeIntent.danger,
        AppState.postIncident => ZapBadgeIntent.info,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);

    // Day 326 — real "first dashboard build" mark for the cold-start
    // report (splash -> dashboard). markOnce() since build() reruns on
    // every appStateProvider change.
    ColdStartTimings.instance.markOnce('dashboard_first_build');

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: ZapColors.bgPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text('Dashboard',
            style: ZapTypography.headlineSmall.copyWith(color: ZapColors.textPrimary)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.lg),
            child: Center(
              child: ZapBadge(
                label: appState.label,
                intent: _modeIntent(appState),
                pulse: appState == AppState.sosActive || appState == AppState.escalating,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(ZapSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Day 306 — three-tier notification banners.
              const NotificationTierBannerStack(),
              const SizedBox(height: ZapSpacing.sm),

              // Day 308 — persistent status card (tap to expand only, no
              // drag-to-dismiss). Placed in normal document flow above the
              // SOS button with an explicit >=16dp gap below, so it can
              // never overlap the button regardless of screen size.
              const PersistentStatusCard(),
              const SizedBox(height: ZapSpacing.lg), // >= 16dp gap (Day 308 acceptance)

              // Day 307 — long-press SOS trigger.
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: ZapSpacing.xl),
                  child: Column(
                    children: [
                      SosTriggerButton(
                        onTriggered: () => context.go(AppRoutes.sosActive),
                      ),
                      const SizedBox(height: ZapSpacing.md),
                      Text(
                        'Hold 2s to trigger SOS',
                        style: ZapTypography.labelSmall.copyWith(
                          color: ZapColors.textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: ZapSpacing.sm),

              // Day 323 — journey mode card with a real locally-computed
              // 0-100 safety-confidence meter (heuristic, MOCK-NOW — see
              // journey_risk_heuristic.dart for why).
              JourneyModeCard(
                onTap: () => context.go(AppRoutes.journeyMlConfidence),
              ),
              const SizedBox(height: ZapSpacing.sm),

              ZapCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.shield_rounded, color: ZapColors.danger, size: 20),
                        const SizedBox(width: ZapSpacing.sm),
                        Text('PRODUCTION DASHBOARD',
                            style: ZapTypography.labelSmall.copyWith(
                              color: ZapColors.textSecondary,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w700,
                            )),
                      ],
                    ),
                    const SizedBox(height: ZapSpacing.sm),
                    Text(
                      'The home screen — shows the user their current safety mode, '
                      'Protection Score, and a giant SOS button. Adapts to all 7 '
                      'app states.',
                      style: ZapTypography.bodyMedium.copyWith(
                        color: ZapColors.textPrimary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: ZapSpacing.md),
                    const _StatusRow(
                      label: 'Notification tiers',
                      done: true,
                      note: 'Day 306 — critical/important/suggestion banners above',
                    ),
                    const _StatusRow(
                      label: 'SOS long-press trigger',
                      done: true,
                      note: 'Day 307 — 2s clockwise ring, haptic ramp, real dispatchManual()',
                    ),
                    const _StatusRow(
                      label: 'Persistent status card',
                      done: true,
                      note: 'Day 308 — collapsed/expanded, tap-only, real signals',
                    ),
                    const _StatusRow(
                      label: 'Journey mode confidence card',
                      done: true,
                      note: 'Day 323 — real local heuristic from GpsSample fields, MOCK-NOW (no live risk-score endpoint)',
                    ),
                    const _StatusRow(
                      label: 'Protection Score ring + Start Journey shortcut',
                      done: false,
                      note: 'still not wired — separate from the Day 323 journey confidence card above',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.done, required this.note});
  final String label;
  final bool done;
  final String note;

  @override
  Widget build(BuildContext context) {
    final color = done ? ZapColors.safe : ZapColors.textMuted;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              size: 16, color: color),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: ZapTypography.bodySmall.copyWith(color: ZapColors.textPrimary),
                children: [
                  TextSpan(text: '$label  '),
                  TextSpan(
                    text: note,
                    style: ZapTypography.bodySmall.copyWith(color: ZapColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
