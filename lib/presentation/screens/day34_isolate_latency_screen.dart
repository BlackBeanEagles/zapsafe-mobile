import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/models/motion_features.dart';
import '../../domain/providers/inference_providers.dart';
import '../../ml/inference/isolated_dcs_runner.dart';
import '../../ml/inference/latency_profiler.dart';
import '../../native/audio_features.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';
import '../widgets/zap_snackbar.dart';

/// Day 34 — measures the DCS cycle on the main isolate vs a worker
/// isolate via `compute()`. The screen runs 30 back-to-back cycles per
/// button press, computes percentile stats, and renders a histogram.
///
/// **A second, more visceral test**: the spinner at the top of the
/// "live UI" card keeps animating throughout the stress test. If the
/// worker isolate is doing its job, the spinner stays smooth (60 fps).
/// If you accidentally block the UI isolate, the spinner stutters or
/// freezes — instant visual proof that the isolate boundary matters.
class Day34IsolateLatencyScreen extends ConsumerStatefulWidget {
  const Day34IsolateLatencyScreen({super.key});

  @override
  ConsumerState<Day34IsolateLatencyScreen> createState() =>
      _Day34IsolateLatencyScreenState();
}

class _Day34IsolateLatencyScreenState
    extends ConsumerState<Day34IsolateLatencyScreen> {
  final _mainProfiler = LatencyProfiler();
  final _workerProfiler = LatencyProfiler();
  bool _running = false;
  String? _currentRun;
  static const int _stressIterations = 30;

  Future<void> _runMain() async {
    await _runStress(
      label: 'MAIN ISOLATE',
      profiler: _mainProfiler,
      onEach: (i) async {
        final engine = ref.read(dcsEngineProvider).valueOrNull;
        if (engine == null) return;
        await _mainProfiler.measure(() => engine.infer(
              audio: _syntheticAudio(i),
              motion: MotionFeatures.atRest(),
            ));
      },
    );
  }

  Future<void> _runWorker() async {
    await _runStress(
      label: 'WORKER ISOLATE',
      profiler: _workerProfiler,
      onEach: (i) async {
        final runner = ref.read(isolatedDcsRunnerProvider);
        await _workerProfiler.measure(() => runner.infer(
              IsolatedInferenceInput(
                audio: _syntheticAudio(i),
                motion: MotionFeatures.atRest(),
              ),
            ));
      },
    );
  }

  Future<void> _runStress({
    required String label,
    required LatencyProfiler profiler,
    required Future<void> Function(int i) onEach,
  }) async {
    setState(() {
      _running = true;
      _currentRun = label;
    });
    profiler.reset();
    for (var i = 0; i < _stressIterations; i++) {
      await onEach(i);
    }
    setState(() {
      _running = false;
      _currentRun = null;
    });
    if (!mounted) return;
    final s = profiler.stats;
    ZapSnackbar.info(
      context,
      '$label · ${s.count} runs · p50 ${s.p50Ms}ms · p95 ${s.p95Ms}ms',
    );
  }

  AudioFeatures _syntheticAudio(int i) {
    // Vary slightly per iteration so neither stub short-circuits.
    return AudioFeatures(
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      mfcc: List<double>.filled(13, (i % 3) * 0.1),
      zcr: 0.05 + (i % 5) * 0.01,
      spectralCentroidHz: 800.0 + (i % 10) * 50,
    );
  }

  void _resetAll() {
    setState(() {
      _mainProfiler.reset();
      _workerProfiler.reset();
    });
    ZapSnackbar.info(context, 'Profilers cleared');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Day 34 · Isolate Latency'),
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

              _LiveUiCard(
                running: _running,
                currentRun: _currentRun,
              ),

              const SizedBox(height: ZapSpacing.xl),

              const _SectionLabel('STRESS TEST · $_stressIterations CYCLES'),
              const SizedBox(height: ZapSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: ZapButton.outlined(
                      label: 'MAIN',
                      icon: Icons.flash_on_rounded,
                      intent: ZapButtonIntent.info,
                      onPressed: _running ? null : _runMain,
                    ),
                  ),
                  const SizedBox(width: ZapSpacing.sm),
                  Expanded(
                    child: ZapButton.elevated(
                      label: 'WORKER',
                      icon: Icons.memory_rounded,
                      intent: ZapButtonIntent.safe,
                      onPressed: _running ? null : _runWorker,
                    ),
                  ),
                  const SizedBox(width: ZapSpacing.sm),
                  ZapButton.text(
                    label: 'RESET',
                    icon: Icons.refresh_rounded,
                    onPressed: _running ? null : _resetAll,
                  ),
                ],
              ),

              const SizedBox(height: ZapSpacing.xl),

              const _SectionLabel('STATS'),
              const SizedBox(height: ZapSpacing.md),
              _StatsTable(
                mainStats: _mainProfiler.stats,
                workerStats: _workerProfiler.stats,
              ),

              const SizedBox(height: ZapSpacing.xl),

              const _SectionLabel('SAMPLE HISTOGRAM · MAIN'),
              const SizedBox(height: ZapSpacing.md),
              _Histogram(samples: _mainProfiler.samplesMs, label: 'main'),

              const SizedBox(height: ZapSpacing.lg),

              const _SectionLabel('SAMPLE HISTOGRAM · WORKER'),
              const SizedBox(height: ZapSpacing.md),
              _Histogram(samples: _workerProfiler.samplesMs, label: 'worker'),

              const SizedBox(height: ZapSpacing.xl),

              const _SectionLabel('REAL-TFLITE CAVEAT'),
              const SizedBox(height: ZapSpacing.md),
              _CaveatCard(),

              const SizedBox(height: ZapSpacing.xxl),

              ZapButton.outlined(
                label: 'OPEN DAY 33 · STREAM',
                icon: Icons.equalizer_rounded,
                fullWidth: true,
                onPressed: () => context.go('/dcs-stream'),
              ),
              const SizedBox(height: ZapSpacing.sm),
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
            ZapColors.safe.withOpacity(0.12),
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
                child: const Icon(Icons.memory_rounded,
                    color: ZapColors.safe, size: 22),
              ),
              const SizedBox(width: ZapSpacing.md),
              const ZapBadge(
                  label: 'MONTH 2 · WEEK 7 · DAY 34',
                  intent: ZapBadgeIntent.safe),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          Text(
            'Isolate Latency',
            style: ZapTypography.displaySmall.copyWith(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            'compute() spawns a worker isolate per inference so the audio + UI '
            'threads never block. Stress test asserts p95 < 450 ms — the '
            'capture cadence — so the pipeline keeps up with real-time.',
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

// ─── Live UI card ────────────────────────────────────────────────────────────

class _LiveUiCard extends StatelessWidget {
  final bool running;
  final String? currentRun;
  const _LiveUiCard({required this.running, required this.currentRun});

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Row(
        children: [
          const SizedBox(
            width: 36,
            height: 36,
            // Always animating — proves the UI thread is alive even
            // mid-stress-test (when running on a worker isolate).
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(width: ZapSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  running ? 'STRESS TEST IN PROGRESS' : 'UI ISOLATE IDLE',
                  style: ZapTypography.labelMedium.copyWith(
                    color: running ? ZapColors.warning : ZapColors.safe,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  running
                      ? 'Running: ${currentRun ?? "—"} · '
                          'spinner should stay smooth on WORKER, stutter on MAIN'
                      : 'Press a stress test button. Spinner keeps animating regardless.',
                  style: ZapTypography.bodySmall.copyWith(
                    color: ZapColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stats table ─────────────────────────────────────────────────────────────

class _StatsTable extends StatelessWidget {
  final LatencyStats mainStats;
  final LatencyStats workerStats;
  const _StatsTable({required this.mainStats, required this.workerStats});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(flex: 3, child: SizedBox.shrink()),
              Expanded(
                flex: 3,
                child: Text(
                  'MAIN',
                  textAlign: TextAlign.center,
                  style: ZapTypography.labelSmall.copyWith(
                    color: ZapColors.info,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'WORKER',
                  textAlign: TextAlign.center,
                  style: ZapTypography.labelSmall.copyWith(
                    color: ZapColors.safe,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const Divider(color: ZapColors.border),
          _row('count',  '${mainStats.count}',   '${workerStats.count}'),
          _row('min',    '${mainStats.minMs}ms', '${workerStats.minMs}ms'),
          _row('p50',    '${mainStats.p50Ms}ms', '${workerStats.p50Ms}ms'),
          _row('p95',    '${mainStats.p95Ms}ms', '${workerStats.p95Ms}ms'),
          _row('max',    '${mainStats.maxMs}ms', '${workerStats.maxMs}ms'),
          _row('mean',   '${mainStats.meanMs}ms','${workerStats.meanMs}ms'),
          const Divider(color: ZapColors.border),
          _budgetRow(mainStats, workerStats),
        ],
      ),
    );
  }

  Widget _row(String k, String a, String b) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ZapSpacing.xs),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              k,
              style: ZapTypography.labelSmall.copyWith(
                color: ZapColors.textSecondary,
                letterSpacing: 1.0,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(a,
                textAlign: TextAlign.center,
                style: ZapTypography.monoSmall.copyWith(
                  color: ZapColors.textPrimary,
                )),
          ),
          Expanded(
            flex: 3,
            child: Text(b,
                textAlign: TextAlign.center,
                style: ZapTypography.monoSmall.copyWith(
                  color: ZapColors.textPrimary,
                )),
          ),
        ],
      ),
    );
  }

  Widget _budgetRow(LatencyStats m, LatencyStats w) {
    Color chip(LatencyStats s) =>
        s.count == 0 ? ZapColors.textSecondary :
        s.isWithinBudget ? ZapColors.safe : ZapColors.danger;
    String label(LatencyStats s) =>
        s.count == 0 ? '—' : s.isWithinBudget ? 'WITHIN' : 'OVER';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ZapSpacing.xs),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              '≤ ${LatencyStats.budgetMs}ms',
              style: ZapTypography.labelSmall.copyWith(
                color: ZapColors.warning,
                letterSpacing: 1.0,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: ZapSpacing.sm, vertical: 3),
                decoration: BoxDecoration(
                  color: chip(m).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  label(m),
                  style: ZapTypography.labelSmall.copyWith(
                    color: chip(m),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: ZapSpacing.sm, vertical: 3),
                decoration: BoxDecoration(
                  color: chip(w).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  label(w),
                  style: ZapTypography.labelSmall.copyWith(
                    color: chip(w),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Histogram ───────────────────────────────────────────────────────────────

class _Histogram extends StatelessWidget {
  final List<int> samples;
  final String label;
  const _Histogram({required this.samples, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      padding: const EdgeInsets.all(ZapSpacing.sm),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.border),
      ),
      child: samples.isEmpty
          ? Center(
              child: Text(
                'No $label samples yet · press a stress button.',
                style: ZapTypography.bodySmall.copyWith(
                  color: ZapColors.textSecondary,
                ),
              ),
            )
          : CustomPaint(
              painter: _HistogramPainter(samples: samples),
              size: Size.infinite,
            ),
    );
  }
}

class _HistogramPainter extends CustomPainter {
  final List<int> samples;
  _HistogramPainter({required this.samples});

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty) return;
    final maxV = samples.reduce((a, b) => a > b ? a : b);
    if (maxV == 0) return;
    final stride = size.width / samples.length;
    for (var i = 0; i < samples.length; i++) {
      final v = samples[i];
      final h = size.height * (v / maxV);
      final color = v <= LatencyStats.budgetMs
          ? ZapColors.safe
          : ZapColors.danger;
      final paint = Paint()..color = color;
      final left = i * stride + 1;
      final right = left + stride - 2;
      canvas.drawRect(
        Rect.fromLTRB(left, size.height - h, right, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_HistogramPainter old) => old.samples != samples;
}

// ─── Caveat card ─────────────────────────────────────────────────────────────

class _CaveatCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.warning.withOpacity(0.08),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.warning.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: ZapColors.warning, size: 20),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'tflite_flutter cannot cross isolate boundaries',
                  style: ZapTypography.labelSmall.copyWith(
                    color: ZapColors.warning,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: ZapSpacing.xs),
                Text(
                  '`Interpreter` wraps a native FFI pointer that is not '
                  'serialisable. Day 34 worker path always uses the pure-Dart '
                  'stub engines — even when a real .tflite is loaded on the '
                  'main isolate. Month 3 upgrade: spawn a long-lived worker '
                  'isolate that owns its own `Interpreter`, communicate via '
                  'SendPort, keep the per-call spawn overhead off the hot path.',
                  style: ZapTypography.bodySmall.copyWith(
                    color: ZapColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section ────────────────────────────────────────────────────────────────

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
