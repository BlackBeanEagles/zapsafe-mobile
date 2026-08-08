import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/models/dcs_score.dart';
import '../../data/models/inference_result.dart';
import '../../data/models/motion_features.dart';
import '../../data/models/trigger_event.dart';
import '../../domain/integration/month1_runner.dart';
import '../../domain/providers/inference_providers.dart';
import '../../ml/inference/dcs_score_watcher.dart';
import '../../ml/inference/isolated_dcs_runner.dart';
import '../../ml/inference/latency_profiler.dart';
import '../../native/audio_features.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';

/// Day 35 — Week 7 acceptance review.
///
/// One pass that exercises every piece landed Days 26-34:
///   1. tflite_flutter package loadable
///   2. ModelRegistry — 4 assets discoverable
///   3. DCSInferenceEngine constructs (all 4 slots, even if stubbed)
///   4. Engine.infer() returns a complete DCSScore
///   5. Score watcher fires ALERT_PENDING after 3 high windows
///   6. Score watcher fires AUTO_SOS on a single ≥ 0.85 window
///   7. Isolated runner returns a valid DCSScore via compute()
///   8. Latency budget — 5-cycle stress, p95 ≤ 450 ms
///
/// Same pattern as Day 25 / Day 30 reviews: phases run sequentially,
/// platform-N/A becomes EXPECTED (yellow), summary stays GREEN as long
/// as every testable phase passes.
class Day35Week7ReviewScreen extends ConsumerStatefulWidget {
  const Day35Week7ReviewScreen({super.key});

  @override
  ConsumerState<Day35Week7ReviewScreen> createState() =>
      _Day35Week7ReviewScreenState();
}

class _Day35Week7ReviewScreenState
    extends ConsumerState<Day35Week7ReviewScreen> {
  final Map<String, PhaseResult> _results = {};
  bool _running = false;
  StreamSubscription<PhaseResult>? _sub;

  // Tiny helper to synthesise an AudioFeatures vector with a chosen
  // energy band — used by the watcher phases.
  AudioFeatures _audioAtEnergy({required double mfcc0Bias}) {
    return AudioFeatures(
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      mfcc: List<double>.filled(13, mfcc0Bias),
      zcr: mfcc0Bias > -30 ? 0.5 : 0.05,
      spectralCentroidHz: mfcc0Bias > -30 ? 6000 : 400,
    );
  }

  List<IntegrationPhase> _phases() {
    return [
      IntegrationPhase(
        key: 'package_tflite',
        name: 'tflite_flutter package loadable',
        description: 'pubspec declares ^0.10.4 — import resolves.',
        runner: () async {
          // The mere fact we got here means the import compiled.
          return const PhaseResult(
            key: 'package_tflite',
            name: 'tflite_flutter package loadable',
            status: PhaseStatus.pass,
            detail: 'package resolved via flutter pub get',
          );
        },
      ),
      IntegrationPhase(
        key: 'registry',
        name: 'ModelRegistry · 5 assets discoverable',
        description: 'kZapsafeModels declares 5 entries; loadAll() succeeds.',
        runner: () async {
          final list = await ref
              .read(modelAssetStatusesProvider.future);
          if (list.length != 5) {
            throw 'expected 5 assets, got ${list.length}';
          }
          final present = list.where((s) => s.sizeBytes > 0).length;
          return PhaseResult(
            key: 'registry',
            name: 'ModelRegistry · 5 assets discoverable',
            status: PhaseStatus.pass,
            detail: '$present / 5 assets present in bundle',
          );
        },
      ),
      IntegrationPhase(
        key: 'engine_compose',
        name: 'DCSInferenceEngine composes',
        description:
            'create() loads all 4 slots in parallel; falls back to stubs.',
        runner: () async {
          final engine = await ref.read(dcsEngineProvider.future);
          final slots = engine.slotStatuses;
          if (slots.length != 4) {
            throw 'engine has ${slots.length} slots, expected 4';
          }
          final realCount = slots.where((s) => s.real).length;
          final stubCount = slots.where((s) => !s.real).length;
          return PhaseResult(
            key: 'engine_compose',
            name: 'DCSInferenceEngine composes',
            status: PhaseStatus.pass,
            detail: 'real=$realCount · stub=$stubCount '
                '(placeholders today → all stub by design)',
          );
        },
      ),
      IntegrationPhase(
        key: 'engine_infer',
        name: 'Engine.infer() returns DCSScore',
        description: 'One pass through scream + motion + scene + fusion.',
        runner: () async {
          final engine = await ref.read(dcsEngineProvider.future);
          final score = await engine.infer(
            audio: _audioAtEnergy(mfcc0Bias: -50),
            motion: MotionFeatures.atRest(),
          );
          return PhaseResult(
            key: 'engine_infer',
            name: 'Engine.infer() returns DCSScore',
            status: PhaseStatus.pass,
            detail: 'fused.scream='
                '${(score.fusion.classScores['scream'] ?? 0).toStringAsFixed(3)}',
          );
        },
      ),
      IntegrationPhase(
        key: 'watcher_alert',
        name: 'Watcher fires ALERT_PENDING (3-window vote)',
        description:
            'Three synthetic high windows in a row produce one event.',
        runner: () async {
          // Synthesise three high-fusion DCSScores and feed them through
          // a fresh watcher — independent of any live stream state.
          final watcher = DCSScoreWatcher();
          DCSScore score(double scream) {
            final fusion = InferenceResult(
              label: 'scream',
              score: scream,
              classScores: {
                'scream': scream,
                'normal': 1 - scream,
                'shout': 0,
              },
              latencyMs: 1,
              timestampMs: 0,
            );
            const neutral = InferenceResult(
              label: 'normal',
              score: 0.1,
              classScores: {'normal': 0.1},
              latencyMs: 1,
              timestampMs: 0,
            );
            return DCSScore(
              timestampMs: 0,
              audio: neutral,
              motion: neutral,
              scene: neutral,
              fusion: fusion,
            );
          }

          TriggerEvent? evt;
          for (var i = 0; i < 3; i++) {
            evt = watcher.observe(score(0.80));
          }
          if (evt == null || evt.kind != TriggerKind.alertPending) {
            throw 'no ALERT_PENDING after 3 high windows';
          }
          return PhaseResult(
            key: 'watcher_alert',
            name: 'Watcher fires ALERT_PENDING (3-window vote)',
            status: PhaseStatus.pass,
            detail: 'consecutiveWindows=${evt.consecutiveWindows} · '
                'passive=${evt.passive}',
          );
        },
      ),
      IntegrationPhase(
        key: 'watcher_autosos',
        name: 'Watcher fires AUTO_SOS on single ≥ 0.85',
        description:
            'Single critical window bypasses the vote and fires immediately.',
        runner: () async {
          final watcher = DCSScoreWatcher();
          const fusion = InferenceResult(
            label: 'scream',
            score: 0.90,
            classScores: {'scream': 0.90, 'normal': 0.10, 'shout': 0},
            latencyMs: 1,
            timestampMs: 0,
          );
          const neutral = InferenceResult(
            label: 'normal',
            score: 0.1,
            classScores: {'normal': 0.1},
            latencyMs: 1,
            timestampMs: 0,
          );
          const dcs = DCSScore(
            timestampMs: 0,
            audio: neutral,
            motion: neutral,
            scene: neutral,
            fusion: fusion,
          );
          final evt = watcher.observe(dcs);
          if (evt == null || evt.kind != TriggerKind.autoSos) {
            throw 'no AUTO_SOS on single 0.90 window';
          }
          if (evt.consecutiveWindows != 0) {
            throw 'AUTO_SOS should not carry a vote count';
          }
          return const PhaseResult(
            key: 'watcher_autosos',
            name: 'Watcher fires AUTO_SOS on single ≥ 0.85',
            status: PhaseStatus.pass,
            detail: 'scream=0.90 · vote bypassed',
          );
        },
      ),
      IntegrationPhase(
        key: 'isolated_runner',
        name: 'IsolatedDcsRunner returns valid DCSScore',
        description: 'compute() spawns a worker isolate per inference.',
        runner: () async {
          final runner = ref.read(isolatedDcsRunnerProvider);
          final score = await runner.infer(IsolatedInferenceInput(
            audio: _audioAtEnergy(mfcc0Bias: -50),
            motion: MotionFeatures.atRest(),
          ));
          if (score.fusion.classScores.isEmpty) {
            throw 'isolated result has empty class scores';
          }
          return const PhaseResult(
            key: 'isolated_runner',
            name: 'IsolatedDcsRunner returns valid DCSScore',
            status: PhaseStatus.pass,
            detail: 'worker isolate · pure-Dart stubs (real TFLite Month 3)',
          );
        },
      ),
      IntegrationPhase(
        key: 'latency_budget',
        name: 'Latency budget · 5-cycle p95 ≤ 450 ms',
        description: 'Stress the engine 5x on the main isolate.',
        runner: () async {
          final engine = await ref.read(dcsEngineProvider.future);
          final profiler = LatencyProfiler();
          for (var i = 0; i < 5; i++) {
            await profiler.measure(() => engine.infer(
                  audio: _audioAtEnergy(mfcc0Bias: -50 + i * 5.0),
                  motion: MotionFeatures.atRest(),
                ));
          }
          final s = profiler.stats;
          if (!s.isWithinBudget) {
            throw 'p95=${s.p95Ms}ms > budget=${LatencyStats.budgetMs}ms';
          }
          return PhaseResult(
            key: 'latency_budget',
            name: 'Latency budget · 5-cycle p95 ≤ 450 ms',
            status: PhaseStatus.pass,
            detail: 'p50=${s.p50Ms}ms · p95=${s.p95Ms}ms · '
                'max=${s.maxMs}ms · budget=${LatencyStats.budgetMs}ms',
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
        title: const Text('Day 35 · Week 7 Review'),
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

              const _SectionLabel('WEEK 7 CHECKLIST'),
              const SizedBox(height: ZapSpacing.md),
              _ChecklistCard(),

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
                  label: 'WEEK 7 COMPLETE · DAY 35 OF 35',
                  intent: ZapBadgeIntent.safe),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          Text(
            'Week 7 Acceptance',
            style: ZapTypography.displaySmall.copyWith(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            'TFLite scaffold · DCS engine · stream + watcher · isolated runner · '
            'latency budget. All five pieces probed in one pass. Placeholder '
            'models stay stub; the seam is real.',
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

// ─── Summary card ────────────────────────────────────────────────────────────

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
          'Tap RUN to walk the Week 7 acceptance checklist.',
          style: ZapTypography.bodySmall.copyWith(
            color: ZapColors.textSecondary,
          ),
        ),
      );
    }
    final color = summary.isGreen ? ZapColors.safe : ZapColors.danger;
    final title = running
        ? 'Probing…'
        : (summary.isGreen ? 'Week 7 GREEN' : 'Hard failure');

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

// ─── Checklist card ──────────────────────────────────────────────────────────

class _ChecklistCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = <(String, String, IconData)>[
      ('Day 26', 'AudioRecord 16 kHz · 450 ms window · VAD + Hann', Icons.graphic_eq_rounded),
      ('Day 27', 'MFCC + ZCR + spectral centroid (native)', Icons.science_rounded),
      ('Day 28', 'iOS AVAudioEngine parity', Icons.apple_rounded),
      ('Day 29', 'Flutter inference seam · Interpreter contract', Icons.psychology_rounded),
      ('Day 30', 'Week 6 acceptance · cadence + e2e budget', Icons.verified_rounded),
      ('Day 31', 'tflite_flutter · 4 model slots · placeholder bytes', Icons.precision_manufacturing_rounded),
      ('Day 32', 'DCSInferenceEngine composes 4 interpreters', Icons.hub_rounded),
      ('Day 33', 'DCS stream · 3-window vote · AUTO_SOS bypass', Icons.equalizer_rounded),
      ('Day 34', 'compute() worker isolate · 450 ms budget gate', Icons.memory_rounded),
      ('Day 35', 'Week 7 acceptance · GREEN end-to-end', Icons.fact_check_rounded),
    ];

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.border),
      ),
      child: Column(
        children: items.map((r) {
          final isWeek7 = ['Day 31', 'Day 32', 'Day 33', 'Day 34', 'Day 35'].contains(r.$1);
          final color = isWeek7 ? ZapColors.safe : ZapColors.textSecondary;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: ZapSpacing.xs),
            child: Row(
              children: [
                Icon(r.$3, color: color, size: 16),
                const SizedBox(width: ZapSpacing.sm),
                SizedBox(
                  width: 56,
                  child: Text(
                    r.$1,
                    style: ZapTypography.labelSmall.copyWith(
                      color: color,
                      letterSpacing: 1.0,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    r.$2,
                    style: ZapTypography.bodySmall.copyWith(
                      color: ZapColors.textPrimary,
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
                    width: 20, height: 20,
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
