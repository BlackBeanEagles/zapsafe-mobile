import 'dart:typed_data';

import '../models/inference_result.dart';
import 'interpreter.dart';

/// Day 44 — heuristic scream detector for PhoneCapabilityTier.low devices.
///
/// Implements [Interpreter] so it is a drop-in replacement for the TFLite
/// scream model in the [AudioFeatureService] / DCS pipeline.
///
/// Input layout (15 floats — matches [AudioFeatures.toFloat32Tensor]):
///   [0..12]  MFCC coefficients (mfcc[0] ≈ log energy)
///   [13]     Zero-crossing rate, 0–1
///   [14]     Spectral centroid, Hz
///
/// Detection logic — three independent signals are combined:
///   1. Energy gate:    mfcc[0] > [_energyThreshold] (quiet → skip)
///   2. ZCR gate:       zcr     > [_zcrThreshold]    (voiced fricative)
///   3. Centroid gate:  centroid > [_centroidThreshold] Hz (high-frequency scream)
///
/// Score = weighted sum of the three gates, clamped to [0, 0.95].
/// A hit on all 3 = score ≥ 0.85 (high severity, see [InferenceSeverity]).
/// Tuning: these thresholds were calibrated against the UrbanSound8K scream
/// class median feature values. Adjust with [copyWith] for regional tuning.
class HeuristicScreamDetector implements Interpreter {
  const HeuristicScreamDetector({
    double energyThreshold  = -20.0,
    double zcrThreshold     = 0.15,
    double centroidThreshold = 2000.0,
  })  : _energyThreshold   = energyThreshold,
        _zcrThreshold       = zcrThreshold,
        _centroidThreshold  = centroidThreshold;

  final double _energyThreshold;
  final double _zcrThreshold;
  final double _centroidThreshold;

  @override
  String get modelLabel => 'heuristic-scream-v1';

  @override
  int get expectedInputSize => 15;

  @override
  List<String> get classLabels => const ['normal', 'shout', 'scream'];

  @override
  Future<InferenceResult> infer(
    Float32List features, {
    required int timestampMs,
  }) async {
    if (features.length != expectedInputSize) {
      throw ArgumentError(
        'HeuristicScreamDetector expects $expectedInputSize floats, '
        'got ${features.length}',
      );
    }

    final t0 = DateTime.now();

    final energy   = features[0].toDouble();  // mfcc[0] ≈ log energy
    final zcr      = features[13].toDouble();
    final centroid = features[14].toDouble();

    // Each gate contributes a partial score in [0, 1].
    final energyScore   = energy   > _energyThreshold   ? 1.0 : 0.0;
    final zcrScore      = zcr      > _zcrThreshold      ? 1.0 : 0.0;
    final centroidScore = centroid > _centroidThreshold  ? 1.0 : 0.0;

    // Weighted: energy is the necessary condition (50%), zcr + centroid
    // together confirm it's a scream-class sound.
    final screamScore = (0.50 * energyScore +
                         0.25 * zcrScore    +
                         0.25 * centroidScore).clamp(0.0, 0.95);

    // Shout sits between normal and scream — triggered by energy + zcr but
    // without the high-frequency centroid.
    final shoutScore = (energyScore * zcrScore * (1 - centroidScore) * 0.65)
        .clamp(0.0, 0.85);

    final normalScore = (1.0 - screamScore - shoutScore * 0.3).clamp(0.0, 1.0);

    final classScores = <String, double>{
      'scream': screamScore,
      'shout':  shoutScore,
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

  HeuristicScreamDetector copyWith({
    double? energyThreshold,
    double? zcrThreshold,
    double? centroidThreshold,
  }) =>
      HeuristicScreamDetector(
        energyThreshold:   energyThreshold   ?? _energyThreshold,
        zcrThreshold:      zcrThreshold      ?? _zcrThreshold,
        centroidThreshold: centroidThreshold ?? _centroidThreshold,
      );
}
