import 'dart:math' as math;
import 'dart:typed_data';

import '../models/inference_result.dart';

/// Day 29 — contract every classifier implementation must satisfy.
///
/// The Day 31 `TfliteInterpreter` will conform to this same shape so swapping
/// from stub to real is one provider override. All inference runs through
/// this seam, so the screen / service / tests don't change.
abstract interface class Interpreter {
  /// Human-readable model identifier, e.g. "scream_classifier_v1" or
  /// "stub-energy". Shown in the Day 29 screen for traceability.
  String get modelLabel;

  /// Number of float32 inputs the model expects. Today: 15 (13 MFCC + ZCR +
  /// spectral centroid). Used by callers to assert tensor shape before
  /// invoking [infer].
  int get expectedInputSize;

  /// Class labels in their canonical order. Stub implementations return a
  /// small fixed set; the real TFLite model reads them from its metadata.
  List<String> get classLabels;

  /// Runs inference on a single feature vector. Implementations are
  /// expected to be re-entrant — the audio service awaits each call in
  /// sequence, but the contract doesn't preclude parallel callers.
  ///
  /// [timestampMs] is the capture time of the source frame and gets
  /// echoed back in the [InferenceResult] for downstream correlation.
  Future<InferenceResult> infer(Float32List features, {required int timestampMs});

  /// Releases any native resources. The stub is a no-op; the real
  /// TFLite interpreter releases its native isolate.
  Future<void> dispose();
}

// ─── Stub implementations ────────────────────────────────────────────────────

/// Energy-based stub. Computes a deterministic-ish "scream" score from the
/// input feature vector itself — higher spectral centroid + ZCR → higher
/// score. Useful in dev because the score actually correlates with whatever
/// the mic is hearing, so the Day 29 screen feels live rather than random.
///
/// Layout assumption: `features[0..12]` = MFCC, `features[13]` = ZCR,
/// `features[14]` = spectral centroid in Hz.
class EnergyStubInterpreter implements Interpreter {
  @override
  String get modelLabel => 'stub-energy';

  @override
  int get expectedInputSize => 15;

  @override
  List<String> get classLabels => const ['normal', 'shout', 'scream'];

  @override
  Future<InferenceResult> infer(
    Float32List features, {
    required int timestampMs,
  }) async {
    final t0 = DateTime.now();
    if (features.length != expectedInputSize) {
      throw ArgumentError(
        'EnergyStubInterpreter expects $expectedInputSize floats, '
        'got ${features.length}',
      );
    }
    // Synthetic "loudness" proxy from the input feature vector itself.
    final mfcc0 = features[0];                 // ≈ log energy
    final zcr = features[13];                  // [0, 1]
    final centroid = features[14];             // 0 – 8000 Hz

    // Map each component to a [0, 1] band and combine. Hand-tuned to
    // produce useful-looking responses without ever pegging at 1.0.
    final logEnergyBand = ((mfcc0 + 80) / 80).clamp(0.0, 1.0);
    final zcrBand = (zcr * 5).clamp(0.0, 1.0);
    final centroidBand = (centroid / 4000).clamp(0.0, 1.0);

    final screamScore = (0.45 * logEnergyBand +
            0.30 * zcrBand +
            0.25 * centroidBand)
        .clamp(0.0, 0.95);

    // Shout sits between normal and scream — share of the residual.
    final shoutScore  = (screamScore * 0.6).clamp(0.0, 1.0);
    final normalScore = (1 - screamScore - shoutScore * 0.1).clamp(0.0, 1.0);

    final scores = _softmax({
      'normal': normalScore,
      'shout':  shoutScore,
      'scream': screamScore,
    });

    final top = scores.entries
        .reduce((a, b) => a.value > b.value ? a : b);
    final elapsed = DateTime.now().difference(t0).inMilliseconds;

    return InferenceResult(
      label: top.key,
      score: top.value,
      classScores: scores,
      latencyMs: elapsed,
      timestampMs: timestampMs,
    );
  }

  @override
  Future<void> dispose() async {
    // No-op — stub holds no native resources.
  }

  Map<String, double> _softmax(Map<String, double> logits) {
    // Subtract max for numerical stability.
    final maxV = logits.values.reduce(math.max);
    final exps = <String, double>{
      for (final e in logits.entries) e.key: math.exp(e.value - maxV),
    };
    final sum = exps.values.reduce((a, b) => a + b);
    return {
      for (final e in exps.entries) e.key: e.value / sum,
    };
  }
}

/// Returns the same canned result for every input. Useful for tests where
/// the value of the result doesn't matter, only the wiring.
///
/// Day 32 — `expectedInputSize` and `classLabels` are configurable so this
/// stub can stand in for any of the 4 DCS interpreters (each has a
/// different input shape: scream=15, motion=6, scene=8, fusion=3).
class FixedStubInterpreter implements Interpreter {
  final String label;
  final double score;
  final int latencyMs;

  @override
  final String modelLabel;

  @override
  final int expectedInputSize;

  @override
  final List<String> classLabels;

  const FixedStubInterpreter({
    this.label = 'normal',
    this.score = 0.5,
    this.latencyMs = 1,
    this.modelLabel = 'stub-fixed',
    this.expectedInputSize = 15,
    this.classLabels = const ['normal', 'shout', 'scream'],
  });

  @override
  Future<InferenceResult> infer(
    Float32List features, {
    required int timestampMs,
  }) async {
    return InferenceResult(
      label: label,
      score: score,
      classScores: {label: score},
      latencyMs: latencyMs,
      timestampMs: timestampMs,
    );
  }

  @override
  Future<void> dispose() async {}
}

/// Day 32 — Linear stub for the DCS Fusion slot.
///
/// Takes N per-model scores (the M1/M2/M3 outputs) and produces a single
/// fused value via a weighted sum, then distributes probability across
/// [classLabels] from low-danger to high-danger order.
///
/// Default classLabels `['safe', 'danger']` match the real XGBoost fusion
/// binary classifier arriving in backend Month 7–8. Supply a different
/// list (e.g. 3-class) only when the target model is multi-class.
///
/// Stand-in until the real fusion model lands.
class LinearStubInterpreter implements Interpreter {
  /// Per-input weight. Length defines [expectedInputSize].
  final List<double> weights;

  @override
  final List<String> classLabels;

  @override
  final String modelLabel;

  LinearStubInterpreter({
    required this.weights,
    this.classLabels = const ['safe', 'danger'],
    this.modelLabel = 'stub-linear',
  });

  @override
  int get expectedInputSize => weights.length;

  @override
  Future<InferenceResult> infer(
    Float32List features, {
    required int timestampMs,
  }) async {
    final t0 = DateTime.now();
    if (features.length != expectedInputSize) {
      throw ArgumentError(
        'LinearStubInterpreter expects $expectedInputSize floats, '
        'got ${features.length}',
      );
    }
    var fused = 0.0;
    for (var i = 0; i < features.length; i++) {
      fused += features[i] * weights[i];
    }
    fused = fused.clamp(0.0, 1.0);

    // Distribute probability: classLabels.last = "most dangerous" class gets
    // `fused`; all other classes share `(1 - fused)` equally. For the
    // default binary ['safe', 'danger']: safe = 1-fused, danger = fused.
    final n = classLabels.length;
    final Map<String, double> classScores = {};
    final safeShare = n > 1 ? (1.0 - fused) / (n - 1) : 0.0;
    for (var i = 0; i < n - 1; i++) {
      classScores[classLabels[i]] = safeShare;
    }
    classScores[classLabels.last] = fused;

    final top = classScores.entries
        .reduce((a, b) => a.value > b.value ? a : b);

    return InferenceResult(
      label: top.key,
      score: top.value,
      classScores: classScores,
      latencyMs: DateTime.now().difference(t0).inMilliseconds,
      timestampMs: timestampMs,
    );
  }

  @override
  Future<void> dispose() async {}
}
