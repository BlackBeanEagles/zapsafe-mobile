import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/dcs_score.dart';
import '../models/inference_result.dart';
import 'violence_burst_detector.dart';

/// Day 337 — decides **when** a camera burst is justified, and holds the
/// result for the DCS scene slot.
///
/// ## Why a burst is not on a timer
///
/// One burst is 16 sequential `takePicture()` calls plus 16 encoder passes —
/// roughly 2.4 s of capture and a second of inference. Polling that would
/// drain the battery and, more importantly, would mean the app pointed a
/// camera at the user's surroundings continuously. Neither is acceptable for
/// a signal that is only ever **corroborating**.
///
/// ## The trigger
///
/// A burst fires when the fused DCS danger score sits in
/// `[kTriggerThreshold, alertThreshold)` — **suspicious, but not yet
/// alerting**. That band is exactly where more evidence changes the outcome:
///
/// * below it, nothing has happened and a capture is unjustified;
/// * above it the app is already escalating, and a burst that takes 3 s to
///   answer arrives too late to matter.
///
/// 0.45 is chosen because a confident scream alone produces `0.5 × 0.9 =
/// 0.45` — so a scream with no corroboration is precisely the situation that
/// should go looking for some. The burst's `violence` probability then feeds
/// back through [DCSInferenceEngine]'s scene slot (weight 0.2), which can
/// carry a genuine threat over the 0.75 alert line or leave a false alarm
/// below it.
///
/// ## What bounds it
///
/// * **Cooldown** ([kCooldownMs], 90 s) — without it, a sustained
///   above-threshold stretch would burst continuously.
/// * **Single-flight** — a burst in progress suppresses new triggers, since
///   captures take seconds and overlapping them would queue the camera.
/// * **Permission** — [CameraFrameService.ensureInitialized] returns false
///   without camera permission, so a user who has not granted it simply
///   never triggers a capture. That is the privacy gate, and it is the OS's,
///   not a flag of ours.
/// * **Staleness** — the engine independently discards any result older than
///   `kSceneMaxAgeMs` (30 s), so a stale burst cannot keep inflating the
///   score even if this class hands one over.
class ViolenceBurstCoordinator {
  /// Fused danger at or above which a burst is worth capturing.
  ///
  /// Deliberately below `DCSScoreWatcher.alertThreshold` (0.75): the point is
  /// to gather evidence *before* the decision, not after it.
  static const double kTriggerThreshold = 0.45;

  /// Minimum gap between bursts.
  static const int kCooldownMs = 90000;

  /// Captures [count] frames, or null if the camera is unavailable — in
  /// production `CameraFrameService.captureBurst`.
  ///
  /// Injected as a function rather than the service itself so the *decision*
  /// logic here can be tested without a camera or a native interpreter,
  /// neither of which `flutter test` has. That is not a testing convenience
  /// alone: "when is pointing a camera at the user justified" deserves to be
  /// verifiable independently of whether a camera happens to be attached.
  final Future<List<List<int>>?> Function({required int count}) captureBurst;

  /// Runs the two-stage model — in production
  /// `ViolenceBurstDetector.inferBurst`.
  final Future<InferenceResult> Function(
    List<List<int>> frames, {
    required int timestampMs,
  }) inferBurst;

  /// Injectable clock so the cooldown is testable without waiting 90 s.
  final int Function() _now;

  InferenceResult? _latest;
  int _lastBurstAtMs = -1 << 32;
  bool _inFlight = false;
  int _triggered = 0;
  int _suppressedCooldown = 0;
  int _suppressedInFlight = 0;
  int _failed = 0;

  ViolenceBurstCoordinator({
    required this.captureBurst,
    required this.inferBurst,
    int Function()? now,
  }) : _now = now ?? (() => DateTime.now().millisecondsSinceEpoch);

  /// Wires the coordinator to the real services.
  factory ViolenceBurstCoordinator.from({
    required CameraBurstSource camera,
    required ViolenceBurstDetector detector,
    int Function()? now,
  }) =>
      ViolenceBurstCoordinator(
        captureBurst: ({required int count}) =>
            camera.captureBurst(count: count),
        inferBurst: detector.inferBurst,
        now: now,
      );

  /// The most recent successful burst, or null. The DCS engine applies its
  /// own staleness bound to this, so callers do not need to.
  InferenceResult? get latestResult => _latest;

  int get triggered => _triggered;
  int get suppressedByCooldown => _suppressedCooldown;
  int get suppressedInFlight => _suppressedInFlight;
  int get failed => _failed;
  bool get isCapturing => _inFlight;

  /// True when [danger] and the current clock justify a capture.
  ///
  /// Split out from [observe] so the decision can be tested without a
  /// camera, and so the reason a burst did *not* fire stays inspectable.
  bool shouldTrigger(double danger, {required double alertThreshold}) {
    if (danger < kTriggerThreshold) return false;
    if (danger >= alertThreshold) return false;
    if (_inFlight) return false;
    return _now() - _lastBurstAtMs >= kCooldownMs;
  }

  /// Feeds one DCS score in. Returns the burst result if one was captured
  /// and completed, otherwise null — callers should read [latestResult]
  /// rather than relying on the return value, since a burst started here
  /// completes asynchronously.
  Future<InferenceResult?> observe(
    DCSScore score, {
    required double alertThreshold,
  }) async {
    final danger = score.fusion.classScores['danger'] ?? 0.0;

    if (danger >= kTriggerThreshold && danger < alertThreshold) {
      if (_inFlight) {
        _suppressedInFlight++;
      } else if (_now() - _lastBurstAtMs < kCooldownMs) {
        _suppressedCooldown++;
      }
    }
    if (!shouldTrigger(danger, alertThreshold: alertThreshold)) return null;

    _inFlight = true;
    _lastBurstAtMs = _now();
    _triggered++;
    try {
      final frames =
          await captureBurst(count: ViolenceBurstDetector.kFrames);
      if (frames == null) {
        _failed++;
        return null;
      }
      final result = await inferBurst(frames, timestampMs: _now());
      _latest = result;
      return result;
    } catch (e) {
      _failed++;
      if (kDebugMode) {
        debugPrint('[ViolenceBurstCoordinator] burst failed: $e');
      }
      return null;
    } finally {
      _inFlight = false;
    }
  }

  /// Drops the cached result. Call when a session ends so a burst cannot
  /// leak into an unrelated one.
  void reset() {
    _latest = null;
    _lastBurstAtMs = -1 << 32;
  }
}

/// The slice of `CameraFrameService` this coordinator needs.
///
/// Declared here so `ViolenceBurstCoordinator.from` has a type to accept
/// without importing the whole camera stack — and so a caller can substitute
/// a different frame source without touching this file.
abstract class CameraBurstSource {
  Future<List<List<int>>?> captureBurst({int count, Duration gap});
}
