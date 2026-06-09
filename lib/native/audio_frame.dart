import 'package:flutter/foundation.dart';

/// One captured + VAD-evaluated window worth of audio metadata.
///
/// The actual PCM samples never cross the platform-channel boundary —
/// Day 27's MFCC + ZCR + spectral-centroid extraction lives natively so we
/// only ship the cheap-to-serialize summary stats over the EventChannel.
@immutable
class AudioFrame {
  /// Wall-clock millis when the native side captured the window.
  final int timestampMs;

  /// Root-mean-square energy of the raw 16-bit PCM samples
  /// (range 0 – ~23170; gets ≥ ~300 on voiced speech).
  final double rmsEnergy;

  /// True when [rmsEnergy] cleared the VAD threshold for this build.
  final bool voiced;

  /// How many PCM samples this frame summarised.
  final int sampleCount;

  /// Window length in milliseconds — fixed at 450 today but shipped so the
  /// UI doesn't have to hard-code the cadence.
  final int windowMs;

  /// VAD threshold that was in force when this frame was produced.
  final double threshold;

  const AudioFrame({
    required this.timestampMs,
    required this.rmsEnergy,
    required this.voiced,
    required this.sampleCount,
    required this.windowMs,
    required this.threshold,
  });

  /// Defensive parser — missing fields default to safe zeros / falses so a
  /// malformed event from the native side never crashes the isolate.
  factory AudioFrame.fromMap(Map<dynamic, dynamic> map) {
    double n(String k) => (map[k] as num?)?.toDouble() ?? 0.0;
    int i(String k) => (map[k] as num?)?.toInt() ?? 0;
    return AudioFrame(
      timestampMs: i('t'),
      rmsEnergy:   n('rms'),
      voiced:      (map['voiced'] as bool?) ?? false,
      sampleCount: i('n'),
      windowMs:    i('window'),
      threshold:   n('thr'),
    );
  }

  /// Normalised energy reading in `[0, 1]` so UIs can drive a progress bar
  /// without knowing the absolute PCM range. Clamps above 4× threshold so
  /// the meter doesn't peg at 0.05 for every quiet voice.
  double get normalisedEnergy {
    if (threshold <= 0) return 0;
    return (rmsEnergy / (threshold * 4)).clamp(0.0, 1.0);
  }
}
