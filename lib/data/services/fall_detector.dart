import '../models/fall_event.dart';

/// State of the [FallDetector] state machine.
enum FallDetectorState {
  /// No suspicious motion. Most of the time.
  idle,

  /// Just entered a low-g window. Waiting to see if it sustains for
  /// [FallDetector.freefallMinMs].
  possibleFreefall,

  /// Sustained freefall confirmed. Waiting for an impact spike within
  /// [FallDetector.impactWindowMs].
  awaitingImpact,

  /// Impact happened. Briefly latched so a UI can show the event before
  /// the detector returns to idle.
  impactDetected,
}

/// Day 36 — pure state-machine fall detector.
///
/// Pull from any source of accelerometer-magnitude samples (the live
/// `sensors_plus` stream in `ImuService`, or synthetic samples in tests).
/// Call [observe] once per sample with the magnitude (m/s²) and the
/// wall-clock timestamp; the detector mutates state and returns a
/// [FallEvent] when both phases — sustained low-g + impact spike — are
/// observed in sequence.
///
/// Tuning rationale (taken from the published fall-detection lit and
/// the timeline's `accel < 0.3G for >200ms + impact spike`):
///   • Earth gravity ≈ 9.81 m/s² → 0.3 g ≈ 2.94 m/s².
///   • Impact: 2.5 g ≈ 24.5 m/s². We use 25 to round.
///   • Freefall must hold for ≥ 200 ms — clears wrist flicks.
///   • Impact must follow within 1 000 ms — clears decoupled events.
///
/// Pure Dart — no platform channels. Trivially unit-testable.
class FallDetector {
  static const double freefallThreshold = 2.94; // 0.3 g · m/s²
  static const double impactThreshold = 25.0;   // ≈ 2.5 g · m/s²
  static const int freefallMinMs = 200;
  static const int impactWindowMs = 1000;
  static const int impactLatchMs = 2000;

  FallDetectorState _state = FallDetectorState.idle;
  int? _freefallStartMs;
  int? _freefallConfirmedMs;
  double _lastPeak = 0;

  /// Current state — surface so UI can render the live phase.
  FallDetectorState get state => _state;

  /// Most-recent peak magnitude seen during a confirmed impact.
  /// Resets to 0 when the detector returns to idle.
  double get lastPeak => _lastPeak;

  /// Feed one accelerometer-magnitude sample. Returns a [FallEvent] when
  /// the impact transition fires; otherwise null.
  FallEvent? observe(double magnitude, {required int timestampMs}) {
    switch (_state) {
      case FallDetectorState.idle:
        if (magnitude < freefallThreshold) {
          _state = FallDetectorState.possibleFreefall;
          _freefallStartMs = timestampMs;
        }
        return null;

      case FallDetectorState.possibleFreefall:
        // If we've now seen freefall hold for long enough, promote to
        // awaitingImpact.
        final start = _freefallStartMs!;
        final elapsed = timestampMs - start;

        // Recovery from low-g before the minimum hold time → false alarm.
        if (magnitude >= freefallThreshold && elapsed < freefallMinMs) {
          _reset();
          return null;
        }
        if (elapsed >= freefallMinMs) {
          _state = FallDetectorState.awaitingImpact;
          _freefallConfirmedMs = timestampMs;
        }
        return null;

      case FallDetectorState.awaitingImpact:
        if (magnitude >= impactThreshold) {
          final freefallDuration =
              _freefallConfirmedMs! - _freefallStartMs!;
          _lastPeak = magnitude;
          _state = FallDetectorState.impactDetected;
          // Don't clear _freefallStartMs yet — we use it to latch state.
          return FallEvent(
            timestampMs: timestampMs,
            peakAccelMagnitude: magnitude,
            freefallDurationMs: freefallDuration < 0 ? 0 : freefallDuration,
          );
        }
        // No impact in time → reset.
        final freefallEnd = _freefallConfirmedMs!;
        if (timestampMs - freefallEnd > impactWindowMs) {
          _reset();
        }
        return null;

      case FallDetectorState.impactDetected:
        // Latch the impact state for [impactLatchMs] so a UI can render
        // the event. After that, return to idle.
        if (timestampMs - _freefallStartMs! > impactLatchMs) {
          _reset();
        }
        return null;
    }
  }

  /// Force-reset the detector. Called when the app changes state in a
  /// way that invalidates the running detection (e.g. user manually
  /// cancels SOS, or the IMU service stops).
  void reset() => _reset();

  void _reset() {
    _state = FallDetectorState.idle;
    _freefallStartMs = null;
    _freefallConfirmedMs = null;
    _lastPeak = 0;
  }
}
