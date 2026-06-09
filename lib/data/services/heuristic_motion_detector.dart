import 'dart:typed_data';

import '../models/inference_result.dart';
import 'interpreter.dart';

/// Day 44 — heuristic motion/fall detector for PhoneCapabilityTier.low devices.
///
/// Implements [Interpreter] so it is a drop-in replacement for the TFLite
/// motion_anomaly_v1 model in the DCS pipeline.
///
/// Input layout (6 floats — matches [MotionFeatures.toFloat32Tensor]):
///   [0] accelMean     — mean accelerometer magnitude, m/s²
///   [1] accelVar      — variance of accelerometer magnitude
///   [2] accelPeak     — peak accelerometer magnitude, m/s²
///   [3] gyroMean      — mean gyroscope magnitude, rad/s
///   [4] gyroVar       — variance of gyroscope magnitude
///   [5] gyroPeak      — peak gyroscope magnitude, rad/s
///
/// Detection logic — mirrors the two-phase fall detector from [FallDetector]
/// but expressed as a single-vector score for use in the Interpreter pipeline:
///
///   Phase A — impact gate:  accelPeak > [_impactThreshold] m/s²   (~2.5 g)
///   Phase B — freefall gate: accelVar > [_varianceThreshold]       (chaotic motion)
///   Phase C — spin gate:     gyroPeak > [_gyroThreshold] rad/s     (tumble)
///
/// Score = 0.5*impactGate + 0.3*varianceGate + 0.2*spinGate, clamped to 0.95.
/// Normal walking/sitting never trips the impact gate, so false-positive rate
/// is very low at the cost of slightly late detections vs the LSTM model.
class HeuristicMotionDetector implements Interpreter {
  const HeuristicMotionDetector({
    double impactThreshold   = 25.0,   // ≈ 2.5 g
    double varianceThreshold = 8.0,
    double gyroThreshold     = 3.0,    // rad/s
  })  : _impactThreshold    = impactThreshold,
        _varianceThreshold  = varianceThreshold,
        _gyroThreshold      = gyroThreshold;

  final double _impactThreshold;
  final double _varianceThreshold;
  final double _gyroThreshold;

  @override
  String get modelLabel => 'heuristic-motion-v1';

  @override
  int get expectedInputSize => 6;

  @override
  List<String> get classLabels => const ['normal', 'threat'];

  @override
  Future<InferenceResult> infer(
    Float32List features, {
    required int timestampMs,
  }) async {
    if (features.length != expectedInputSize) {
      throw ArgumentError(
        'HeuristicMotionDetector expects $expectedInputSize floats, '
        'got ${features.length}',
      );
    }

    final t0 = DateTime.now();

    final accelPeak = features[2].toDouble();
    final accelVar  = features[1].toDouble();
    final gyroPeak  = features[5].toDouble();

    final impactGate   = accelPeak > _impactThreshold   ? 1.0 : 0.0;
    final varianceGate = accelVar  > _varianceThreshold  ? 1.0 : 0.0;
    final spinGate     = gyroPeak  > _gyroThreshold      ? 1.0 : 0.0;

    final threatScore =
        (0.50 * impactGate + 0.30 * varianceGate + 0.20 * spinGate)
            .clamp(0.0, 0.95);

    final normalScore = (1.0 - threatScore).clamp(0.0, 1.0);

    final classScores = <String, double>{
      'threat': threatScore,
      'normal': normalScore,
    };

    final top = classScores.entries
        .reduce((a, b) => a.value > b.value ? a : b);

    return InferenceResult(
      label:       top.key,
      score:       top.value,
      classScores: classScores,
      latencyMs:   DateTime.now().difference(t0).inMilliseconds,
      timestampMs: timestampMs,
    );
  }

  @override
  Future<void> dispose() async {}

  HeuristicMotionDetector copyWith({
    double? impactThreshold,
    double? varianceThreshold,
    double? gyroThreshold,
  }) =>
      HeuristicMotionDetector(
        impactThreshold:   impactThreshold   ?? _impactThreshold,
        varianceThreshold: varianceThreshold ?? _varianceThreshold,
        gyroThreshold:     gyroThreshold     ?? _gyroThreshold,
      );
}
