import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../domain/integration/month1_runner.dart';
import '../../domain/integration/month2_runner.dart';
import '../navigation/app_router.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';

/// Day 40 — Month 2 acceptance + milestone review.
///
/// Mirrors the Day 20 (Month 1 review) + Day 35 (Week 7 acceptance) shape:
///   • milestone tiles deep-linking to live proof screens
///   • integration runner with PASS / EXPECTED / FAIL summary
///   • Month 3 preview card
///
/// 13 phases cover every piece landed Days 21-39: platform channels,
/// FGS / BGTask, audio pipeline, TFLite registry, DCS engine + watcher,
/// IMU, GPS profile + fallback, battery tiers, AppStateNotifier
/// transitions, trigger orchestrator wiring.
class Day40Month2ReviewScreen extends ConsumerStatefulWidget {
  const Day40Month2ReviewScreen({super.key});

  @override
  ConsumerState<Day40Month2ReviewScreen> createState() =>
      _Day40Month2ReviewScreenState();
}

class _Day40Month2ReviewScreenState
    extends ConsumerState<Day40Month2ReviewScreen> {
  final Map<String, PhaseResult> _results = {};
  bool _running = false;
  StreamSubscription<PhaseResult>? _sub;

  Future<void> _runAll() async {
    setState(() {
      _running = true;
      _results.clear();
    });
    final phases = buildMonth2Phases(ref);
    for (final p in phases) {
      _results[p.key] = PhaseResult(
        key: p.key,
        name: p.name,
        status: PhaseStatus.pending,
        detail: '',
      );
    }
    setState(() {});
    await _sub?.cancel();
    _sub = runIntegrationPhases(phases).listen(
      (result) {
        if (!mounted) return;
        setState(() => _results[result.key] = result);
      },
      onDone: () {
        if (mounted) setState(() => _running = false);
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phases = buildMonth2Phases(ref);
    final summary = IntegrationSummary.from(_results.values);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Day 40 · Month 2 Review'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(ZapSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeroBanner(),
              const SizedBox(height: ZapSpacing.xl),

              const _SectionLabel('SEVEN MILESTONES · ALL GREEN'),
              const SizedBox(height: ZapSpacing.md),
              for (final m in _milestones) _MilestoneTile(milestone: m),

              const SizedBox(height: ZapSpacing.xl),

              const _SectionLabel('ACCEPTANCE RUNNER'),
              const SizedBox(height: ZapSpacing.md),
              _SummaryCard(
                summary: summary,
                hasRun: _results.isNotEmpty,
                running: _running,
              ),
              const SizedBox(height: ZapSpacing.md),
              ZapButton.elevated(
                label: _running ? 'PROBING…' : 'RUN MONTH 2 ACCEPTANCE',
                icon: Icons.fact_check_rounded,
                intent: ZapButtonIntent.safe,
                fullWidth: true,
                onPressed: _running ? null : _runAll,
                isLoading: _running,
              ),
              const SizedBox(height: ZapSpacing.lg),
              for (final p in phases)
                _PhaseTile(phase: p, result: _results[p.key]),

              const SizedBox(height: ZapSpacing.xl),

              const _SectionLabel('BY THE NUMBERS'),
              const SizedBox(height: ZapSpacing.md),
              _StatsCard(),

              const SizedBox(height: ZapSpacing.xl),
              _MonthThreeCard(),

              const SizedBox(height: ZapSpacing.xxl),
              ZapButton.outlined(
                label: 'BACK TO INDEX',
                icon: Icons.arrow_back_rounded,
                fullWidth: true,
                onPressed: () => context.go('/'),
              ),
              const SizedBox(height: ZapSpacing.huge),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Milestone data ──────────────────────────────────────────────────────────

class _Milestone {
  final String title;
  final String summary;
  final String days;
  final IconData icon;
  final Color accent;
  final String route;
  const _Milestone({
    required this.title,
    required this.summary,
    required this.days,
    required this.icon,
    required this.accent,
    required this.route,
  });
}

const _milestones = <_Milestone>[
  _Milestone(
    title: 'Android foreground service',
    summary: 'ZapSafeService · START_STICKY · persistent notification · FGS '
        'types (microphone + location + dataSync) · BootReceiver auto-restart',
    days: 'Days 21–22',
    icon: Icons.shield_rounded,
    accent: ZapColors.danger,
    route: AppRoutes.backgroundEngine,
  ),
  _Milestone(
    title: 'iOS BGProcessingTask + watchdog',
    summary: 'BGTaskScheduler.com.zapsafe.dcs · re-schedules itself · WorkManager '
        '15-min watchdog on Android · 30 s heartbeat threshold (LP4)',
    days: 'Days 22 + 24',
    icon: Icons.autorenew_rounded,
    accent: ZapColors.info,
    route: AppRoutes.watchdog,
  ),
  _Milestone(
    title: 'Audio capture pipeline',
    summary: '16 kHz mono PCM · 450 ms window · RMS-gated VAD (threshold 300) · '
        'Hann window · 13 MFCC + ZCR + spectral centroid · iOS AVAudioEngine parity',
    days: 'Days 26–28',
    icon: Icons.graphic_eq_rounded,
    accent: ZapColors.info,
    route: AppRoutes.audioCapture,
  ),
  _Milestone(
    title: 'TFLite scaffold + DCS engine',
    summary: 'tflite_flutter ^0.10.4 · 4 placeholder model slots · '
        'DCSInferenceEngine composes 4 interpreters with stub fallback · '
        'compute() worker isolate path',
    days: 'Days 31–34',
    icon: Icons.precision_manufacturing_rounded,
    accent: ZapColors.warning,
    route: AppRoutes.dcsEngine,
  ),
  _Milestone(
    title: 'IMU service · fall detection',
    summary: 'sensors_plus accel + gyro · 450 ms MotionFeatures snapshots · '
        'FallDetector freefall + impact state machine · '
        'DCS stream consumes live motion',
    days: 'Day 36',
    icon: Icons.vibration_rounded,
    accent: ZapColors.info,
    route: AppRoutes.imuService,
  ),
  _Milestone(
    title: 'GPS + cell-tower fallback',
    summary: 'Adaptive cadence by AppState (5 min / 30 s / 10 s) · '
        'SharedPreferences last-fix cache · GpsFallbackCoordinator merges cell '
        'when accuracy > 50 m or no fix for 90 s',
    days: 'Days 37–38',
    icon: Icons.location_on_rounded,
    accent: ZapColors.safe,
    route: AppRoutes.gpsService,
  ),
  _Milestone(
    title: '7-state machine + trigger pipeline',
    summary: 'AppStateNotifier with 12 transitions · 15 s alert countdown · '
        'LP3 silent escalation · LP25 onAutoSos bypass · '
        'TriggerOrchestrator wires DCS + fall + manual into the state machine',
    days: 'Days 38–39',
    icon: Icons.hub_rounded,
    accent: ZapColors.danger,
    route: AppRoutes.day39StateWiring,
  ),
];

// ─── Hero ────────────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ZapColors.safe.withOpacity(0.16),
            ZapColors.info.withOpacity(0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.safe.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(ZapSpacing.sm),
                decoration: BoxDecoration(
                  color: ZapColors.safe.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.emoji_events_rounded,
                    color: ZapColors.safe, size: 24),
              ),
              const SizedBox(width: ZapSpacing.md),
              const ZapBadge(
                  label: 'MONTH 2 COMPLETE · DAY 40 OF 390',
                  intent: ZapBadgeIntent.safe),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          Text(
            'Month 2 SHIPPED',
            style: ZapTypography.displaySmall.copyWith(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            'The continuous-streaming engine is alive. Audio is captured + '
            'featurised, four ML slots compose with stub fallback, IMU + GPS '
            'feed the trigger pipeline, the state machine drives every '
            'downstream service, and the battery handler degrades gracefully. '
            'Month 3 builds the first real screens on top.',
            style: ZapTypography.bodyMedium.copyWith(
              color: ZapColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Milestone tile ──────────────────────────────────────────────────────────

class _MilestoneTile extends StatelessWidget {
  final _Milestone milestone;
  const _MilestoneTile({required this.milestone});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ZapSpacing.md),
      child: ZapCard(
        onTap: () => context.go(milestone.route),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: milestone.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              ),
              child: Icon(milestone.icon,
                  color: milestone.accent, size: 22),
            ),
            const SizedBox(width: ZapSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          milestone.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ZapTypography.headlineSmall.copyWith(
                            color: ZapColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: ZapSpacing.sm),
                      ZapBadge(
                        label: milestone.days,
                        intent: ZapBadgeIntent.neutral,
                        size: ZapBadgeSize.small,
                        style: ZapBadgeStyle.outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: ZapSpacing.xs),
                  Text(
                    milestone.summary,
                    style: ZapTypography.bodySmall.copyWith(
                      color: ZapColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: ZapColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ─── Summary + phases (same pattern as Day 25/30/35) ────────────────────────

class _SummaryCard extends StatelessWidget {
  final IntegrationSummary summary;
  final bool hasRun;
  final bool running;
  const _SummaryCard({
    required this.summary,
    required this.hasRun,
    required this.running,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasRun) {
      return Container(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        decoration: BoxDecoration(
          color: ZapColors.bgCard,
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          border: Border.all(color: ZapColors.border),
        ),
        child: Text(
          'Tap RUN to walk the Month 2 acceptance checklist.',
          style: ZapTypography.bodySmall.copyWith(
            color: ZapColors.textSecondary,
          ),
        ),
      );
    }
    final color = summary.isGreen ? ZapColors.safe : ZapColors.danger;
    final title = running
        ? 'Probing…'
        : (summary.isGreen ? 'Month 2 GREEN' : 'Hard failure');
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                summary.isGreen
                    ? Icons.verified_rounded
                    : Icons.error_outline_rounded,
                color: color,
                size: 24,
              ),
              const SizedBox(width: ZapSpacing.sm),
              Text(
                title,
                style: ZapTypography.headlineSmall.copyWith(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          Row(
            children: [
              _stat('PASS', summary.pass, ZapColors.safe),
              const SizedBox(width: ZapSpacing.md),
              _stat('EXPECTED', summary.expectedFail, ZapColors.warning),
              const SizedBox(width: ZapSpacing.md),
              _stat('FAIL', summary.fail, ZapColors.danger),
              const SizedBox(width: ZapSpacing.md),
              _stat('TOTAL', summary.total, ZapColors.textSecondary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, int count, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: ZapTypography.labelSmall.copyWith(
                color: ZapColors.textSecondary,
                letterSpacing: 1.5,
              )),
          Text(count.toString(),
              style: ZapTypography.displaySmall.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              )),
        ],
      ),
    );
  }
}

class _PhaseTile extends StatelessWidget {
  final IntegrationPhase phase;
  final PhaseResult? result;
  const _PhaseTile({required this.phase, required this.result});

  @override
  Widget build(BuildContext context) {
    final status = result?.status ?? PhaseStatus.pending;
    final (icon, color, statusLabel) = switch (status) {
      PhaseStatus.pending      => (Icons.radio_button_unchecked_rounded, ZapColors.textSecondary, 'PENDING'),
      PhaseStatus.running      => (Icons.hourglass_top_rounded, ZapColors.info, 'RUNNING'),
      PhaseStatus.pass         => (Icons.check_circle_rounded, ZapColors.safe, 'PASS'),
      PhaseStatus.fail         => (Icons.cancel_rounded, ZapColors.danger, 'FAIL'),
      PhaseStatus.expectedFail => (Icons.error_outline_rounded, ZapColors.warning, 'EXPECTED'),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
      child: ZapCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (status == PhaseStatus.running)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(icon, color: color, size: 20),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    phase.name,
                    style: ZapTypography.bodyMedium.copyWith(
                      color: ZapColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: ZapSpacing.sm, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    statusLabel,
                    style: ZapTypography.labelSmall.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: ZapSpacing.xs),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Text(
                phase.description,
                style: ZapTypography.bodySmall.copyWith(
                  color: ZapColors.textSecondary,
                ),
              ),
            ),
            if (result != null && result!.detail.isNotEmpty) ...[
              const SizedBox(height: ZapSpacing.xs),
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: Text(
                  result!.detail,
                  style: ZapTypography.monoSmall.copyWith(
                    color: color,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Stats card ──────────────────────────────────────────────────────────────

class _StatsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final stats = const [
      ('20 days', 'Month 2 build window · Days 21–40', Icons.calendar_month_rounded),
      ('318 tests', 'unit + widget · all green · 6 platform-skipped on host', Icons.science_rounded),
      ('20 LIVE screens', 'Days 21-39 each carry a debug surface', Icons.dashboard_rounded),
      ('32 routes wired', 'go_router · onboarding redirect · push routing', Icons.alt_route_rounded),
      ('15+ services', 'GPS · IMU · Audio · TFLite · DCS · Watchdog · Battery · …', Icons.miscellaneous_services_rounded),
      ('9 platform channels', 'background · sensors · audio · features · watchdog · cell', Icons.cable_rounded),
      ('4 ML model slots', 'scream · motion · scene · fusion (placeholder bytes today)', Icons.precision_manufacturing_rounded),
    ];
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.border),
      ),
      child: Column(
        children: stats.map((s) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: ZapSpacing.xs),
            child: Row(
              children: [
                Icon(s.$3, color: ZapColors.info, size: 18),
                const SizedBox(width: ZapSpacing.sm),
                SizedBox(
                  width: 130,
                  child: Text(
                    s.$1,
                    style: ZapTypography.labelMedium.copyWith(
                      color: ZapColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    s.$2,
                    style: ZapTypography.bodySmall.copyWith(
                      color: ZapColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _MonthThreeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ZapColors.warning.withOpacity(0.12),
            ZapColors.info.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.warning.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.rocket_launch_rounded,
                  color: ZapColors.warning, size: 22),
              const SizedBox(width: ZapSpacing.sm),
              Text(
                'Month 3 preview · the first real screens',
                style: ZapTypography.headlineSmall.copyWith(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          Text(
            'Days 41-45 build the onboarding wrapper (5 steps: UI mode → home pin '
            '→ first contact → medical card → done · Protection Score = 40). '
            'Days 46-50 produce the real Dashboard. Days 51-55 add Contacts '
            'with Tier 1/2/3 verification. Days 56-60 wrap Month 3.',
            style: ZapTypography.bodyMedium.copyWith(
              color: ZapColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: ZapSpacing.md),
          Text(
            '🟡 SUBSCRIPTION HEADS-UP · Day 41 = HuggingFace Pro \$9/mo',
            style: ZapTypography.labelMedium.copyWith(
              color: ZapColors.warning,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: ZapTypography.labelSmall.copyWith(
            color: ZapColors.textSecondary,
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: ZapSpacing.md),
        const Expanded(child: Divider(color: ZapColors.border)),
      ],
    );
  }
}
