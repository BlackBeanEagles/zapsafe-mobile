import 'package:flutter/foundation.dart';

import 'inference_result.dart';

/// Day 32 — composite output of one full pass through the DCS pipeline.
///
/// Holds the three component results (audio scream, motion anomaly, scene
/// context) and the final fused score. Day 33's score-watcher reads
/// [fusionScore] against the ALERT_PENDING threshold (0.75); the
/// individual components stay on the side for forensics + UI breakdown.
///
/// Naming note: "DCS" = Defensive Continuous Streaming. The pipeline runs
/// every 450 ms while in MONITORING mode, so a healthy session produces
/// hundreds of these per minute.
@immutable
class DCSScore {
  /// Native capture timestamp of the source audio frame.
  final int timestampMs;

  /// Output of M1 (scream classifier). Always present.
  final InferenceResult audio;

  /// Output of M2 (motion anomaly). Null when no motion features are
  /// available — older app versions, sensor permission denied, etc.
  final InferenceResult? motion;

  /// Output of M3 (scene analyzer). Null when scene context isn't
  /// computed for this window.
  final InferenceResult? scene;

  /// Output of M9 (DCS fusion). The single scalar Day 33's watcher
  /// thresholds against.
  final InferenceResult fusion;

  /// True when [fusion.score] crosses the configured trigger threshold.
  /// Today's threshold is [InferenceResult.confidenceThreshold] = 0.7
  /// (the same per-model threshold from Day 29). The Day 33 watcher
  /// upgrades this to a per-N-window vote and a separate 0.85 auto-SOS
  /// override.
  bool get triggerCandidate => fusion.isConfident;

  const DCSScore({
    required this.timestampMs,
    required this.audio,
    this.motion,
    this.scene,
    required this.fusion,
  });

  /// All four component scores in one list, ready for tabular UI.
  List<({String slot, InferenceResult? result})> get rows => [
        (slot: 'M1 audio',  result: audio),
        (slot: 'M2 motion', result: motion),
        (slot: 'M3 scene',  result: scene),
        (slot: 'M9 fusion', result: fusion),
      ];

  @override
  String toString() =>
      'DCSScore(t=$timestampMs, audio=${audio.score.toStringAsFixed(2)}, '
      'motion=${motion?.score.toStringAsFixed(2) ?? "—"}, '
      'fusion=${fusion.score.toStringAsFixed(2)})';
}
