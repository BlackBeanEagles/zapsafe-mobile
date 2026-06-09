import 'package:flutter/foundation.dart';

/// Day 29 — one inference pass from the scream / stress classifier.
///
/// The shape is general enough for any 1-of-N classifier:
///   • [label] is the top-scoring class
///   • [score] is its softmax probability in `[0, 1]`
///   • [classScores] is the full softmax distribution for ranked display
///   • [latencyMs] is how long the interpreter took (typical TFLite calls are
///                 1-15 ms on mid-range hardware)
///   • [timestampMs] is when the source feature frame was captured
@immutable
class InferenceResult {
  /// Top class name, e.g. "scream", "shout", "normal".
  final String label;

  /// Top class probability, in `[0, 1]`.
  final double score;

  /// All class scores keyed by label.
  final Map<String, double> classScores;

  /// Inference latency in milliseconds (wall-clock).
  final int latencyMs;

  /// Capture time of the source feature frame (millis since epoch).
  final int timestampMs;

  const InferenceResult({
    required this.label,
    required this.score,
    required this.classScores,
    required this.latencyMs,
    required this.timestampMs,
  });

  /// True when this result crosses the threshold for "this is a real signal,
  /// upstream code should act on it". Tunable — the real cutoff comes out
  /// of the Day 31 calibration pass on labelled data.
  bool get isConfident => score >= confidenceThreshold;

  /// Default trigger threshold. Conservative for now — false-positives
  /// against the LP9 cancel-freeze loophole are expensive.
  static const double confidenceThreshold = 0.7;

  /// Severity tier for UI rendering — drives the badge colour on screens
  /// that show a stream of these.
  InferenceSeverity get severity {
    if (score >= 0.85) return InferenceSeverity.high;
    if (score >= confidenceThreshold) return InferenceSeverity.medium;
    if (score >= 0.4) return InferenceSeverity.low;
    return InferenceSeverity.none;
  }

  @override
  String toString() =>
      'InferenceResult($label=${score.toStringAsFixed(3)}, '
      '${latencyMs}ms, t=$timestampMs)';
}

enum InferenceSeverity { none, low, medium, high }
