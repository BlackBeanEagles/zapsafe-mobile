import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/models/inference_result.dart';
import '../../data/services/audio_feature_service.dart';
import '../../data/services/heuristic_scream_detector.dart';
import '../../domain/providers/platform_channel_providers.dart';
import '../../native/audio_features.dart';
import '../navigation/app_router.dart';
import '../widgets/zap_card.dart';

/// Day 49 — Audio Pipeline Validation Screen.
///
/// Route: /audio-pipeline
///
/// Real-device validation for the full audio stack:
///   microphone → PCM frames → AudioFeatures (MFCC + ZCR + centroid)
///   → HeuristicScreamDetector → InferenceResult → trigger check.
///
/// Shows live feature values, rolling inference stats, and a confidence
/// history bar so you can speak/scream and see the pipeline respond.
class Day49AudioPipelineScreen extends ConsumerStatefulWidget {
  const Day49AudioPipelineScreen({super.key});

  @override
  ConsumerState<Day49AudioPipelineScreen> createState() =>
      _Day49AudioPipelineScreenState();
}

class _Day49AudioPipelineScreenState
    extends ConsumerState<Day49AudioPipelineScreen> {
  // ── Service ───────────────────────────────────────────────────────────────
  AudioFeatureService? _svc;
  StreamSubscription<InferenceResult>? _resultSub;
  StreamSubscription<AudioFeatures>? _featureSub;

  // ── State ─────────────────────────────────────────────────────────────────
  bool _running = false;
  AudioFeatures? _latestFeatures;
  InferenceResult? _latestResult;

  // Rolling confidence history (last 20 readings for bar chart)
  final List<double> _confidenceHistory = [];
  static const int _historyLen = 20;

  // Stats mirrored from AudioFeatureService
  int    _framesIn     = 0;
  int    _triggersFired = 0;
  double _maxScore     = 0.0;
  int    _avgLatencyMs = 0;

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  void _start() {
    final featureStream = ref.read(audioChannelProvider).featureStream;
    final detector = const HeuristicScreamDetector();

    _svc = AudioFeatureService(
      interpreter:   detector,
      featureStream: featureStream,
    );
    _svc!.start();

    _featureSub = featureStream.listen((f) {
      if (mounted) setState(() => _latestFeatures = f);
    });

    _resultSub = _svc!.results.listen((r) {
      if (!mounted) return;
      setState(() {
        _latestResult = r;
        _framesIn      = _svc!.framesIn;
        _triggersFired = _svc!.triggersFired;
        _maxScore      = _svc!.maxScore;
        _avgLatencyMs  =
            _svc!.averageLatency.inMilliseconds;

        _confidenceHistory.add(r.score);
        if (_confidenceHistory.length > _historyLen) {
          _confidenceHistory.removeAt(0);
        }
      });
    });

    setState(() => _running = true);
  }

  Future<void> _stop() async {
    await _featureSub?.cancel();
    await _resultSub?.cancel();
    _featureSub = null;
    _resultSub  = null;
    await _svc?.dispose();
    _svc = null;
    if (mounted) setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: ZapColors.bgPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: ZapColors.textPrimary),
          onPressed: () => context.go(AppRoutes.home),
        ),
        title: Row(
          children: [
            const Text('Audio Pipeline',
                style: TextStyle(color: ZapColors.textPrimary)),
            const SizedBox(width: ZapSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: ZapSpacing.sm, vertical: 2),
              decoration: BoxDecoration(
                color: ZapColors.danger.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'DAY 49',
                style: ZapTypography.labelSmall.copyWith(
                  color: ZapColors.danger,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Start / stop ───────────────────────────────────────────────
            ZapCard(
              child: Row(
                children: [
                  Icon(
                    _running
                        ? Icons.mic_rounded
                        : Icons.mic_off_rounded,
                    color: _running ? ZapColors.danger : ZapColors.textMuted,
                    size: 22,
                  ),
                  const SizedBox(width: ZapSpacing.sm),
                  Expanded(
                    child: Text(
                      _running
                          ? 'Listening — speak or scream to test'
                          : 'Tap Start to open the microphone',
                      style: ZapTypography.bodySmall.copyWith(
                        color: _running
                            ? ZapColors.textPrimary
                            : ZapColors.textSecondary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _running ? _stop : _start,
                    child: Text(
                      _running ? 'Stop' : 'Start',
                      style: ZapTypography.labelSmall.copyWith(
                        color: _running
                            ? ZapColors.warning
                            : ZapColors.safe,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: ZapSpacing.xl),

            // ── Live inference result ──────────────────────────────────────
            _SectionLabel('LIVE DETECTION'),
            const SizedBox(height: ZapSpacing.sm),
            _LiveResultCard(result: _latestResult, running: _running),
            const SizedBox(height: ZapSpacing.xl),

            // ── Confidence history ─────────────────────────────────────────
            _SectionLabel('CONFIDENCE HISTORY  (last $_historyLen frames)'),
            const SizedBox(height: ZapSpacing.sm),
            _HistoryBarCard(history: _confidenceHistory),
            const SizedBox(height: ZapSpacing.xl),

            // ── Audio features ─────────────────────────────────────────────
            _SectionLabel('AUDIO FEATURES'),
            const SizedBox(height: ZapSpacing.sm),
            _AudioFeaturesCard(features: _latestFeatures, running: _running),
            const SizedBox(height: ZapSpacing.xl),

            // ── Pipeline stats ─────────────────────────────────────────────
            _SectionLabel('PIPELINE STATS'),
            const SizedBox(height: ZapSpacing.sm),
            _StatsCard(
              framesIn:      _framesIn,
              triggersFired: _triggersFired,
              maxScore:      _maxScore,
              avgLatencyMs:  _avgLatencyMs,
              running:       _running,
            ),
            const SizedBox(height: ZapSpacing.xxxl),
          ],
        ),
      ),
    );
  }
}

// ─── Live result card ─────────────────────────────────────────────────────────

class _LiveResultCard extends StatelessWidget {
  const _LiveResultCard({required this.result, required this.running});
  final InferenceResult? result;
  final bool running;

  Color get _color {
    if (result == null) return ZapColors.textMuted;
    switch (result!.severity) {
      case InferenceSeverity.high:   return ZapColors.danger;
      case InferenceSeverity.medium: return ZapColors.warning;
      case InferenceSeverity.low:    return ZapColors.info;
      case InferenceSeverity.none:   return ZapColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!running) {
      return ZapCard(
        child: Text('Pipeline not started.',
            style: ZapTypography.bodySmall
                .copyWith(color: ZapColors.textMuted)),
      );
    }
    if (result == null) {
      return ZapCard(
        child: Row(
          children: [
            const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: ZapColors.safe)),
            const SizedBox(width: ZapSpacing.sm),
            Text('Waiting for first frame…',
                style: ZapTypography.bodySmall
                    .copyWith(color: ZapColors.textSecondary)),
          ],
        ),
      );
    }

    final r = result!;
    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                r.isConfident
                    ? Icons.warning_rounded
                    : Icons.check_circle_rounded,
                color: _color,
                size: 20,
              ),
              const SizedBox(width: ZapSpacing.sm),
              Text(
                r.label.toUpperCase(),
                style: ZapTypography.labelLarge.copyWith(
                  color: _color,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${(r.score * 100).toStringAsFixed(1)}%',
                style: ZapTypography.labelLarge.copyWith(
                  color: _color,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'IBMPlexMono',
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.sm),
          // Confidence bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: r.score,
              backgroundColor: ZapColors.bgSurface,
              valueColor: AlwaysStoppedAnimation<Color>(_color),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: ZapSpacing.xs),
          Row(
            children: [
              Text(
                '${r.latencyMs} ms  ·  ${r.isConfident ? "TRIGGER" : "below threshold"}',
                style: ZapTypography.labelSmall.copyWith(
                  color: r.isConfident ? _color : ZapColors.textSecondary,
                  fontFamily: 'IBMPlexMono',
                ),
              ),
            ],
          ),
          // Per-class breakdown
          if (r.classScores.isNotEmpty) ...[
            const SizedBox(height: ZapSpacing.sm),
            ...r.classScores.entries.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 72,
                        child: Text(e.key,
                            style: ZapTypography.bodySmall.copyWith(
                                color: ZapColors.textSecondary)),
                      ),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: e.value.clamp(0.0, 1.0),
                          backgroundColor: ZapColors.bgSurface,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              ZapColors.textMuted),
                          minHeight: 4,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: ZapSpacing.xs),
                      Text(
                        '${(e.value * 100).toStringAsFixed(0)}%',
                        style: ZapTypography.labelSmall.copyWith(
                            color: ZapColors.textSecondary,
                            fontFamily: 'IBMPlexMono'),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

// ─── Confidence history bar chart ─────────────────────────────────────────────

class _HistoryBarCard extends StatelessWidget {
  const _HistoryBarCard({required this.history});
  final List<double> history;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return ZapCard(
        child: Text('No data yet.',
            style: ZapTypography.bodySmall
                .copyWith(color: ZapColors.textMuted)),
      );
    }
    return ZapCard(
      child: SizedBox(
        height: 60,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: history.map((v) {
            final frac = v.clamp(0.0, 1.0);
            final color = frac >= 0.7
                ? ZapColors.danger
                : frac >= 0.4
                    ? ZapColors.warning
                    : ZapColors.safe;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: FractionallySizedBox(
                  heightFactor: frac == 0 ? 0.04 : frac,
                  child: Container(
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─── Audio features card ──────────────────────────────────────────────────────

class _AudioFeaturesCard extends StatelessWidget {
  const _AudioFeaturesCard(
      {required this.features, required this.running});
  final AudioFeatures? features;
  final bool running;

  @override
  Widget build(BuildContext context) {
    if (!running || features == null) {
      return ZapCard(
        child: Text(
          running ? 'Waiting for audio frame…' : 'Pipeline not started.',
          style: ZapTypography.bodySmall
              .copyWith(color: ZapColors.textMuted),
        ),
      );
    }
    final f = features!;
    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MonoRow('mfcc[0]',
              f.mfcc.isNotEmpty
                  ? f.mfcc[0].toStringAsFixed(2)
                  : '—'),
          _MonoRow('zcr',
              f.zcr.toStringAsFixed(4)),
          _MonoRow('centroid',
              '${f.spectralCentroidHz.toStringAsFixed(0)} Hz'),
          _MonoRow('vector len',
              '${f.toFloat32Tensor().length}'),
        ],
      ),
    );
  }
}

// ─── Stats card ───────────────────────────────────────────────────────────────

class _StatsCard extends StatelessWidget {
  const _StatsCard({
    required this.framesIn,
    required this.triggersFired,
    required this.maxScore,
    required this.avgLatencyMs,
    required this.running,
  });

  final int    framesIn;
  final int    triggersFired;
  final double maxScore;
  final int    avgLatencyMs;
  final bool   running;

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MonoRow('frames in',    '$framesIn'),
          _MonoRow('triggers',     '$triggersFired'),
          _MonoRow('max score',
              '${(maxScore * 100).toStringAsFixed(1)}%'),
          _MonoRow('avg latency',  '${avgLatencyMs} ms'),
          _MonoRow('status',
              running ? 'RUNNING' : 'STOPPED'),
        ],
      ),
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: ZapTypography.labelSmall.copyWith(
          color: ZapColors.textSecondary,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w600,
        ),
      );
}

class _MonoRow extends StatelessWidget {
  const _MonoRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 90,
              child: Text(label,
                  style: ZapTypography.bodySmall
                      .copyWith(color: ZapColors.textSecondary)),
            ),
            Text(value,
                style: ZapTypography.bodySmall.copyWith(
                    color: ZapColors.textPrimary,
                    fontFamily: 'IBMPlexMono')),
          ],
        ),
      );
}
