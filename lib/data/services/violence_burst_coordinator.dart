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
/// A burst fires when the **raw scream probability** is high while the app
/// is **not yet escalating**. That is exactly where more evidence changes
/// the outcome:
///
/// * below it, nothing has happened and a capture is unjustified;
/// * if the app is already escalating, a burst that takes 3 s to answer
///   arrives too late to matter.
///
/// ## Day 364D — this now reads the SCREAM score, not the fused score
///
/// It previously triggered on the fused DCS danger score, and 0.45 was
/// derived from `audioWeight 0.5 × a confident scream 0.9`. Day 364D
/// dropped scream from the fusion (weight 0), so a scream now moves the
/// fused score **not at all** — the old trigger would have meant the camera
/// never investigates a scream.
///
/// That would also have been a new reachability trap of exactly the Day 326
/// shape: the gate now needs `motion + scene`, scene comes from a burst, and
/// bursts came from audio. Audio evidence still has to be able to start an
/// investigation even though it no longer votes on escalation.
///
/// **This is the right use of a weak signal.** A burst costs battery, not a
/// false alarm to the user, so a detector too unreliable to escalate on can
/// still be good enough to say "point the camera". The burst's `violence`
/// probability then feeds [DCSInferenceEngine]'s scene slot (weight 0.48),
/// where the far stronger m3 detector decides.
///
/// 0.90 is chosen from the measured per-window distribution on real media
/// audio:
///
///     t       ambient windows   violent windows   ratio
///     0.80        8.1%              21.7%         2.68x
///     0.90        3.2%              12.5%         3.97x
///     0.95        1.2%               8.1%         6.88x
///
/// 0.80 would fire roughly every 18 s of ordinary television. 0.95 buys a
/// better ratio but catches too little. See DAY364D_SCREAM_DROPPED_FROM_GATE.md.
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
  /// **Raw scream probability** at or above which a burst is worth
  /// capturing. Not a fused score — see the class doc.
  ///
  /// The point is to gather evidence *before* the decision, not after it.
  ///
  /// Day 368D, branch scream-v6-swap: 0.6535 for `scream_classifier_v6`,
  /// chosen to fire on the SAME share of ambient windows as v5 at 0.90
  /// (4.88% over all 800 labelled XD-Violence test videos, 62,737 windows,
  /// both models scoring identical windows). At that matched cost v6 catches
  /// 9.24% of violent windows against v5's 14.38% (ratio 1.89x vs 2.95x).
  /// That is a REGRESSION for the one consumer whose output changes app
  /// behaviour, and why this branch is not merged by default.
  /// See DAY368D_SCREAM_V6_RECALIBRATION.md.
  static const double kTriggerThreshold = 0.6535;

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
  /// [screamProb] is the RAW scream probability, not the fused score.
  /// [fusedDanger] suppresses the burst when the app is already escalating;
  /// it defaults to 0 so a caller that only has an audio score still works.
  bool shouldTrigger(double screamProb,
      {required double alertThreshold, double fusedDanger = 0.0}) {
    if (screamProb < kTriggerThreshold) return false;
    if (fusedDanger >= alertThreshold) return false;
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
    // Day 364D: trigger on the RAW scream probability. The fused score no
    // longer carries any audio contribution, so reading it here would mean
    // the camera never investigates a scream. See the class doc.
    final screamProb = score.audio.classScores['scream'] ?? 0.0;
    final danger = score.fusion.classScores['danger'] ?? 0.0;

    if (screamProb >= kTriggerThreshold && danger < alertThreshold) {
      if (_inFlight) {
        _suppressedInFlight++;
      } else if (_now() - _lastBurstAtMs < kCooldownMs) {
        _suppressedCooldown++;
      }
    }
    if (!shouldTrigger(screamProb,
        alertThreshold: alertThreshold, fusedDanger: danger)) {
      return null;
    }

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
