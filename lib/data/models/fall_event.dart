import 'package:flutter/foundation.dart';

/// Day 36 — one detected fall.
///
/// Fired by [FallDetector] when the classic two-phase fall signature is
/// observed:
///   1. **Pre-impact freefall** — accel magnitude drops below 0.3 g for
///      at least 200 ms (the device approaches weightlessness in mid-air).
///   2. **Impact spike** — accel magnitude crosses 25 m/s² (≈ 2.5 g)
///      within 1 s of the freefall window ending.
///
/// The combined signature is far more specific than either alone — a
/// quick wrist flick can spike accel high, but only an actual fall has a
/// sustained low-g window first.
@immutable
class FallEvent {
  /// Wall-clock millis when the impact was detected.
  final int timestampMs;

  /// Peak acceleration magnitude (m/s²) at impact.
  final double peakAccelMagnitude;

  /// Sustained low-g duration before impact (ms).
  final int freefallDurationMs;

  const FallEvent({
    required this.timestampMs,
    required this.peakAccelMagnitude,
    required this.freefallDurationMs,
  });

  @override
  String toString() =>
      'FallEvent(t=$timestampMs, peak=${peakAccelMagnitude.toStringAsFixed(1)}m/s², '
      'freefall=${freefallDurationMs}ms)';
}
