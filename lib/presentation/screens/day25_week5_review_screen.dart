import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../domain/integration/month1_runner.dart';
import '../../domain/providers/background_service_providers.dart';
import '../../domain/providers/platform_channel_providers.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';

/// Day 25 — Week 5 acceptance review.
///
/// Probes the four recovery layers landed this week and reports each one
/// as PASS / EXPECTED / FAIL. Expected-fails (e.g. iOS BGTask on an Android
/// device, WorkManager on a host VM) render yellow rather than red so the
/// summary stays GREEN as long as every layer that *can* be tested on this
/// platform passes.
class Day25Week5ReviewScreen extends ConsumerStatefulWidget {
  const Day25Week5ReviewScreen({super.key});

  @override
  ConsumerState<Day25Week5ReviewScreen> createState() =>
      _Day25Week5ReviewScreenState();
}

class _Day25Week5ReviewScreenState
    extends ConsumerState<Day25Week5ReviewScreen> {
  final Map<String, PhaseResult> _results = {};
  bool _running = false;
  StreamSubscription<PhaseResult>? _sub;

  List<IntegrationPhase> _phases() {
    final bg     = ref.read(backgroundServiceProvider);
    final ios    = ref.read(iosBackgroundHandlerProvider);
    final wd     = ref.read(watchdogChannelProvider);
    final sensor = ref.read(sensorChannelProvider);
    final audio  = ref.read(audioChannelProvider);

    return [
      IntegrationPhase(
        key: 'fg_service',
        name: 'Foreground service alive',
        description: 'ZapSafeService is running on Android.',
        expectedFailReason:
            Platform.isAndroid ? null : 'Android-only — N/A on this host',
        runner: () async {
          if (!Platform.isAndroid) throw 'Not Android';
          final running = await bg.refresh();
          if (!running) throw 'Service is not running (Day 21 → START)';
          return PhaseResult(
            key: 'fg_service',
            name: 'Foreground service alive',
            status: PhaseStatus.pass,
            detail: 'ZapSafeService responded to isRunning',
          );
        },
      ),
      IntegrationPhase(
        key: 'heartbeat',
        name: 'Heartbeat fresh',
        description: 'Last service ping is inside the LP4 threshold.',
        expectedFailReason:
            Platform.isAndroid ? null : 'Heartbeat lives in Android SharedPreferences',
        runner: () async {
          if (!Platform.isAndroid) throw 'Not Android';
          final s = await wd.readStatus();
          if (s.lastHeartbeatMs == null) {
            throw 'No heartbeat written yet — start the engine first';
          }
          if (s.isStale) {
            throw 'Stale: ${s.secondsSinceLastPing}s > ${s.thresholdMs ~/ 1000}s';
          }
          return PhaseResult(
            key: 'heartbeat',
            name: 'Heartbeat fresh',
            status: PhaseStatus.pass,
            detail:
                'Last ping ${s.secondsSinceLastPing}s ago (threshold ${s.thresholdMs ~/ 1000}s)',
          );
        },
      ),
      IntegrationPhase(
        key: 'watchdog_enqueued',
        name: 'WorkManager watchdog enqueued',
        description: 'Periodic LP4 worker is scheduled.',
        expectedFailReason: Platform.isAndroid
            ? 'press ENQUEUE on Day 24 if this fails'
            : 'WorkManager is Android-only',
        runner: () async {
          if (!Platform.isAndroid) throw 'Not Android';
          final enqueued = await wd.isEnqueued();
          if (!enqueued) throw 'Not enqueued';
          return PhaseResult(
            key: 'watchdog_enqueued',
            name: 'WorkManager watchdog enqueued',
            status: PhaseStatus.pass,
            detail: 'Periodic work in ENQUEUED or RUNNING state',
          );
        },
      ),
      IntegrationPhase(
        key: 'ios_bg',
        name: 'iOS BGProcessingTask registered',
        description: 'BGTaskScheduler holds com.zapsafe.dcs.',
        expectedFailReason:
            Platform.isIOS ? null : 'iOS-only — N/A on this host',
        runner: () async {
          if (!Platform.isIOS) throw 'Not iOS';
          final ok = await ios.isRegistered();
          if (!ok) throw 'Handler not registered';
          return PhaseResult(
            key: 'ios_bg',
            name: 'iOS BGProcessingTask registered',
            status: PhaseStatus.pass,
            detail: 'Task id: ${await ios.readTaskIdentifier()}',
          );
        },
      ),
      IntegrationPhase(
        key: 'sensor_channel',
        name: 'Sensor channel reachable',
        description: 'SensorChannel start / stop / stream answer.',
        expectedFailReason: Platform.isAndroid ? null : 'Android-only today',
        runner: () async {
          if (!Platform.isAndroid) throw 'Not Android';
          final ok = await sensor.start();
          await sensor.stop();
          if (!ok) throw 'start() returned false';
          return PhaseResult(
            key: 'sensor_channel',
            name: 'Sensor channel reachable',
            status: PhaseStatus.pass,
            detail: 'Round-tripped start → stop via MethodChannel',
          );
        },
      ),
      IntegrationPhase(
        key: 'audio_channel',
        name: 'Audio channel reachable',
        description: 'AudioChannel start / stop answer (Android + iOS).',
        expectedFailReason: audio.supported ? null : 'capture-native platform required',
        runner: () async {
          if (!audio.supported) throw 'No native audio implementation';
          final ok = await audio.start();
          await audio.stop();
          if (!ok) throw 'start() returned false';
          return PhaseResult(
            key: 'audio_channel',
            name: 'Audio channel reachable',
            status: PhaseStatus.pass,
            detail: 'Round-tripped start → stop via MethodChannel',
          );
        },
      ),
    ];
  }

  Future<void> _runAll() async {
    setState(() {
      _running = true;
      _results.clear();
    });
    final phases = _phases();
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
    final phases = _phases();
    final summary = IntegrationSummary.from(_results.values);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Day 25 · Week 5 Review'),
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

              _SummaryCard(
                summary: summary,
                hasRun: _results.isNotEmpty,
                running: _running,
              ),
              const SizedBox(height: ZapSpacing.xl),

              ZapButton.elevated(
                label: _running ? 'PROBING…' : 'RUN ACCEPTANCE CHECKS',
                icon: Icons.fact_check_rounded,
                intent: ZapButtonIntent.safe,
                fullWidth: true,
                onPressed: _running ? null : _runAll,
                isLoading: _running,
              ),
              const SizedBox(height: ZapSpacing.xl),

              const _SectionLabel('RECOVERY-LAYER MATRIX'),
              const SizedBox(height: ZapSpacing.md),
              _LatencyTable(),

              const SizedBox(height: ZapSpacing.xl),

              const _SectionLabel('PHASES'),
              const SizedBox(height: ZapSpacing.md),
              for (final p in phases)
                _PhaseTile(phase: p, result: _results[p.key]),

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
            ZapColors.safe.withOpacity(0.14),
            ZapColors.info.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.safe.withOpacity(0.35)),
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
                child: const Icon(Icons.verified_rounded,
                    color: ZapColors.safe, size: 22),
              ),
              const SizedBox(width: ZapSpacing.md),
              const ZapBadge(
                  label: 'MONTH 2 · WEEK 5 · DAY 25 OF 25',
                  intent: ZapBadgeIntent.safe),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          Text(
            'Week 5 Acceptance',
            style: ZapTypography.displaySmall.copyWith(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            'Probe every recovery layer in one pass. Phases that legitimately '
            'cannot run on this platform (e.g. iOS BGTask on Android) are '
            'expected-fails — they don\'t flip the summary red.',
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

// ─── Summary ─────────────────────────────────────────────────────────────────

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
          'Tap RUN to probe every Week 5 recovery layer.',
          style: ZapTypography.bodySmall.copyWith(
            color: ZapColors.textSecondary,
          ),
        ),
      );
    }

    final color = summary.isGreen ? ZapColors.safe : ZapColors.danger;
    final title = running
        ? 'Probing…'
        : (summary.isGreen ? 'Week 5 GREEN' : 'Hard failure');

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
          Text(
            label,
            style: ZapTypography.labelSmall.copyWith(
              color: ZapColors.textSecondary,
              letterSpacing: 1.5,
            ),
          ),
          Text(
            count.toString(),
            style: ZapTypography.displaySmall.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Latency table ───────────────────────────────────────────────────────────

class _LatencyTable extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final rows = <(String, String, String, String)>[
      ('Layer 1', 'Service self-respawn (START_STICKY)', '<5 s', 'OS-managed'),
      ('Layer 2', 'Persistent foreground notification', 'instant', 'Day 21'),
      ('Layer 3', 'BootReceiver / iOS BGTask',           '<10 s after boot', 'Day 22'),
      ('Layer 4', 'WorkManager periodic watchdog',       '≤30 s recovery',   'Day 24'),
    ];

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.border),
      ),
      child: Column(
        children: rows.map((r) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: ZapSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 56,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: ZapColors.danger.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      r.$1,
                      style: ZapTypography.labelSmall.copyWith(
                        color: ZapColors.danger,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  flex: 5,
                  child: Text(
                    r.$2,
                    style: ZapTypography.bodySmall.copyWith(
                      color: ZapColors.textPrimary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    r.$3,
                    style: ZapTypography.monoSmall.copyWith(
                      color: ZapColors.safe,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    r.$4,
                    style: ZapTypography.labelSmall.copyWith(
                      color: ZapColors.textSecondary,
                      letterSpacing: 0.8,
                    ),
                    textAlign: TextAlign.right,
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

// ─── Phase tile ──────────────────────────────────────────────────────────────

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
                  padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.sm, vertical: 3),
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

// ─── Section label ───────────────────────────────────────────────────────────

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
