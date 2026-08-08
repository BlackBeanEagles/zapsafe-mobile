import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/models/fall_event.dart';
import '../../data/models/motion_features.dart';
import '../../data/services/fall_detector.dart';
import '../../data/services/heuristic_motion_detector.dart';
import '../../domain/providers/imu_providers.dart';
import '../navigation/app_router.dart';
import '../widgets/zap_card.dart';

/// Day 50 — Motion & Fall Detection Validation Screen.
///
/// Route: /motion-validation
///
/// Real-device validation for the motion pipeline:
///   accelerometer + gyroscope → MotionFeatures → HeuristicMotionDetector
///   → InferenceResult  +  FallDetector state machine → FallEvent.
///
/// Lets you walk, shake, and simulate drops to verify both the ML and
/// rule-based fall detection paths are live.
class Day50MotionValidationScreen extends ConsumerStatefulWidget {
  const Day50MotionValidationScreen({super.key});

  @override
  ConsumerState<Day50MotionValidationScreen> createState() =>
      _Day50MotionValidationScreenState();
}

class _Day50MotionValidationScreenState
    extends ConsumerState<Day50MotionValidationScreen> {
  bool _running = false;

  // ── Live readings ──────────────────────────────────────────────────────
  MotionFeatures? _latestFeatures;
  double _liveAccel = 0;
  double _liveGyro  = 0;

  // ── Heuristic detector ─────────────────────────────────────────────────
  double  _threatScore    = 0;
  String  _threatLabel    = '—';
  bool    _triggerFired   = false;
  int     _triggersTotal  = 0;
  int     _latencyMs      = 0;

  // ── Fall detector ──────────────────────────────────────────────────────
  FallDetectorState _fallState  = FallDetectorState.idle;
  FallEvent?        _lastFall;
  int               _fallCount  = 0;

  // ── Accel magnitude history (last 30 for spark-line) ──────────────────
  final List<double> _accelHistory = [];
  static const int _historyLen = 30;

  StreamSubscription<MotionFeatures>? _featureSub;
  StreamSubscription<FallEvent>?      _fallSub;
  Timer? _liveTimer;

  @override
  void dispose() {
    _stopAll();
    super.dispose();
  }

  void _start() {
    final svc = ref.read(imuServiceProvider);
    svc.start();

    _featureSub = svc.features.listen(_onFeatures);
    _fallSub    = svc.falls.listen(_onFall);

    // Poll live magnitudes + fall-detector state at 10 Hz for the spark-line
    _liveTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      final s = ref.read(imuServiceProvider);
      setState(() {
        _liveAccel = s.liveAccelMagnitude;
        _liveGyro  = s.liveGyroMagnitude;
        _fallState = s.detectorState;
        _accelHistory.add(s.liveAccelMagnitude);
        if (_accelHistory.length > _historyLen) _accelHistory.removeAt(0);
      });
    });

    setState(() => _running = true);
  }

  void _stopAll() {
    _liveTimer?.cancel();
    _featureSub?.cancel();
    _fallSub?.cancel();
    _liveTimer = null;
    _featureSub = null;
    _fallSub = null;
    ref.read(imuServiceProvider).stop();
    if (mounted) setState(() => _running = false);
  }

  Future<void> _onFeatures(MotionFeatures f) async {
    if (!mounted) return;

    // Run heuristic motion detector
    final t0 = DateTime.now().millisecondsSinceEpoch;
    final result = await const HeuristicMotionDetector()
        .infer(f.toFloat32Tensor(), timestampMs: f.timestampMs);
    final latency = DateTime.now().millisecondsSinceEpoch - t0;

    if (!mounted) return;
    setState(() {
      _latestFeatures = f;
      _threatScore    = result.classScores['threat'] ?? 0.0;
      _threatLabel    = result.label;
      _triggerFired   = result.isConfident;
      _latencyMs      = latency;
      if (result.isConfident) _triggersTotal++;
    });
  }

  void _onFall(FallEvent event) {
    if (!mounted) return;
    setState(() {
      _lastFall  = event;
      _fallCount++;
    });
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
            const Text('Motion Validation',
                style: TextStyle(color: ZapColors.textPrimary)),
            const SizedBox(width: ZapSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: ZapSpacing.sm, vertical: 2),
              decoration: BoxDecoration(
                color: ZapColors.warning.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'DAY 50',
                style: ZapTypography.labelSmall.copyWith(
                  color: ZapColors.warning,
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
                    Icons.vibration_rounded,
                    color: _running ? ZapColors.warning : ZapColors.textMuted,
                    size: 22,
                  ),
                  const SizedBox(width: ZapSpacing.sm),
                  Expanded(
                    child: Text(
                      _running
                          ? 'IMU active — walk, shake, or drop to test'
                          : 'Tap Start to activate sensors',
                      style: ZapTypography.bodySmall.copyWith(
                        color: _running
                            ? ZapColors.textPrimary
                            : ZapColors.textSecondary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _running ? _stopAll : _start,
                    child: Text(
                      _running ? 'Stop' : 'Start',
                      style: ZapTypography.labelSmall.copyWith(
                        color: _running ? ZapColors.danger : ZapColors.safe,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: ZapSpacing.xl),

            // ── Live magnitudes + spark-line ───────────────────────────────
            const _SectionLabel('LIVE SENSOR MAGNITUDES'),
            const SizedBox(height: ZapSpacing.sm),
            _LiveMagnitudeCard(
              accel: _liveAccel,
              gyro: _liveGyro,
              history: _accelHistory,
              running: _running,
            ),
            const SizedBox(height: ZapSpacing.xl),

            // ── Heuristic motion detector ──────────────────────────────────
            const _SectionLabel('HEURISTIC MOTION DETECTOR'),
            const SizedBox(height: ZapSpacing.sm),
            _MotionDetectorCard(
              threatScore:   _threatScore,
              label:         _threatLabel,
              triggerFired:  _triggerFired,
              triggersTotal: _triggersTotal,
              latencyMs:     _latencyMs,
              running:       _running,
            ),
            const SizedBox(height: ZapSpacing.xl),

            // ── Motion features snapshot ───────────────────────────────────
            const _SectionLabel('MOTION FEATURES SNAPSHOT'),
            const SizedBox(height: ZapSpacing.sm),
            _FeaturesCard(features: _latestFeatures, running: _running),
            const SizedBox(height: ZapSpacing.xl),

            // ── Fall detector state machine ────────────────────────────────
            const _SectionLabel('FALL DETECTOR STATE MACHINE'),
            const SizedBox(height: ZapSpacing.sm),
            _FallDetectorCard(
              state:     _fallState,
              lastFall:  _lastFall,
              fallCount: _fallCount,
            ),
            const SizedBox(height: ZapSpacing.xxxl),
          ],
        ),
      ),
    );
  }
}

// ─── Live magnitude + spark-line card ────────────────────────────────────────

class _LiveMagnitudeCard extends StatelessWidget {
  const _LiveMagnitudeCard({
    required this.accel,
    required this.gyro,
    required this.history,
    required this.running,
  });

  final double accel;
  final double gyro;
  final List<double> history;
  final bool running;

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _BigStat(
                  value: accel.toStringAsFixed(2),
                  unit: 'm/s²',
                  label: 'accel',
                  color: accel > 25 ? ZapColors.danger : ZapColors.safe,
                ),
              ),
              Expanded(
                child: _BigStat(
                  value: gyro.toStringAsFixed(3),
                  unit: 'rad/s',
                  label: 'gyro',
                  color: gyro > 3.0 ? ZapColors.warning : ZapColors.safe,
                ),
              ),
            ],
          ),
          if (history.isNotEmpty) ...[
            const SizedBox(height: ZapSpacing.sm),
            SizedBox(
              height: 36,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: history.map((v) {
                  final frac = (v / 30.0).clamp(0.0, 1.0);
                  final color = v > 25
                      ? ZapColors.danger
                      : v > 15
                          ? ZapColors.warning
                          : ZapColors.safe;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 0.5),
                      child: FractionallySizedBox(
                        heightFactor: frac < 0.04 ? 0.04 : frac,
                        child: Container(
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.75),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '← 3 s  accel magnitude history  (red > 25 m/s²)',
                style: ZapTypography.labelSmall.copyWith(
                    color: ZapColors.textMuted, fontSize: 10),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BigStat extends StatelessWidget {
  const _BigStat({
    required this.value,
    required this.unit,
    required this.label,
    required this.color,
  });

  final String value;
  final String unit;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value,
                  style: ZapTypography.labelLarge.copyWith(
                      color: color,
                      fontFamily: 'IBMPlexMono',
                      fontWeight: FontWeight.w700)),
              const SizedBox(width: 3),
              Text(unit,
                  style: ZapTypography.labelSmall
                      .copyWith(color: ZapColors.textSecondary)),
            ],
          ),
          Text(label,
              style: ZapTypography.labelSmall
                  .copyWith(color: ZapColors.textMuted)),
        ],
      );
}

// ─── Heuristic motion detector card ──────────────────────────────────────────

class _MotionDetectorCard extends StatelessWidget {
  const _MotionDetectorCard({
    required this.threatScore,
    required this.label,
    required this.triggerFired,
    required this.triggersTotal,
    required this.latencyMs,
    required this.running,
  });

  final double threatScore;
  final String label;
  final bool   triggerFired;
  final int    triggersTotal;
  final int    latencyMs;
  final bool   running;

  Color get _color {
    if (threatScore >= 0.7) return ZapColors.danger;
    if (threatScore >= 0.4) return ZapColors.warning;
    return ZapColors.safe;
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
    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                triggerFired
                    ? Icons.warning_rounded
                    : Icons.check_circle_rounded,
                color: _color,
                size: 20,
              ),
              const SizedBox(width: ZapSpacing.sm),
              Text(
                label.toUpperCase(),
                style: ZapTypography.labelLarge.copyWith(
                    color: _color, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                '${(threatScore * 100).toStringAsFixed(1)}%',
                style: ZapTypography.labelLarge.copyWith(
                    color: _color,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'IBMPlexMono'),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: threatScore.clamp(0.0, 1.0),
              backgroundColor: ZapColors.bgSurface,
              valueColor: AlwaysStoppedAnimation<Color>(_color),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: ZapSpacing.xs),
          Row(
            children: [
              Text(
                '$latencyMs ms  ·  triggers: $triggersTotal',
                style: ZapTypography.labelSmall.copyWith(
                    color: ZapColors.textSecondary,
                    fontFamily: 'IBMPlexMono'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Motion features snapshot card ───────────────────────────────────────────

class _FeaturesCard extends StatelessWidget {
  const _FeaturesCard({required this.features, required this.running});
  final MotionFeatures? features;
  final bool running;

  @override
  Widget build(BuildContext context) {
    if (!running || features == null) {
      return ZapCard(
        child: Text(
          running ? 'Waiting for first window…' : 'Pipeline not started.',
          style: ZapTypography.bodySmall.copyWith(color: ZapColors.textMuted),
        ),
      );
    }
    final f = features!;
    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MonoRow('accelMean',  '${f.accelMean.toStringAsFixed(2)} m/s²'),
          _MonoRow('accelVar',   f.accelVar.toStringAsFixed(3)),
          _MonoRow('accelPeak',  '${f.accelPeak.toStringAsFixed(2)} m/s²'),
          _MonoRow('gyroMean',   '${f.gyroMean.toStringAsFixed(3)} rad/s'),
          _MonoRow('gyroVar',    f.gyroVar.toStringAsFixed(4)),
          _MonoRow('gyroPeak',   '${f.gyroPeak.toStringAsFixed(3)} rad/s'),
          _MonoRow('vector len', '${f.toFloat32Tensor().length}'),
        ],
      ),
    );
  }
}

// ─── Fall detector state machine card ────────────────────────────────────────

class _FallDetectorCard extends StatelessWidget {
  const _FallDetectorCard({
    required this.state,
    required this.lastFall,
    required this.fallCount,
  });

  final FallDetectorState state;
  final FallEvent?        lastFall;
  final int               fallCount;

  Color get _stateColor {
    switch (state) {
      case FallDetectorState.idle:            return ZapColors.safe;
      case FallDetectorState.possibleFreefall: return ZapColors.info;
      case FallDetectorState.awaitingImpact:  return ZapColors.warning;
      case FallDetectorState.impactDetected:  return ZapColors.danger;
    }
  }

  IconData get _stateIcon {
    switch (state) {
      case FallDetectorState.idle:            return Icons.check_circle_rounded;
      case FallDetectorState.possibleFreefall: return Icons.arrow_downward_rounded;
      case FallDetectorState.awaitingImpact:  return Icons.hourglass_bottom_rounded;
      case FallDetectorState.impactDetected:  return Icons.crisis_alert_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_stateIcon, color: _stateColor, size: 20),
              const SizedBox(width: ZapSpacing.sm),
              Text(
                state.name.toUpperCase(),
                style: ZapTypography.labelMedium.copyWith(
                    color: _stateColor, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                'falls: $fallCount',
                style: ZapTypography.labelSmall.copyWith(
                    color: ZapColors.textSecondary,
                    fontFamily: 'IBMPlexMono'),
              ),
            ],
          ),
          if (lastFall != null) ...[
            const SizedBox(height: ZapSpacing.sm),
            _MonoRow('peak',     '${lastFall!.peakAccelMagnitude.toStringAsFixed(1)} m/s²'),
            _MonoRow('freefall', '${lastFall!.freefallDurationMs} ms'),
          ],
          const SizedBox(height: ZapSpacing.sm),
          // State machine progress bar
          Row(
            children: FallDetectorState.values.map((s) {
              final active = s == state;
              final passed = FallDetectorState.values.indexOf(s) <=
                  FallDetectorState.values.indexOf(state);
              return Expanded(
                child: Container(
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: active
                        ? _stateColor
                        : passed
                            ? _stateColor.withOpacity(0.35)
                            : ZapColors.bgSurface,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            'idle → freefall → awaitingImpact → impactDetected',
            style: ZapTypography.labelSmall.copyWith(
                color: ZapColors.textMuted, fontSize: 9),
          ),
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
              width: 80,
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
