import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/dcs_score.dart';
import '../../data/models/trigger_event.dart';

/// Day 33 — turns a `Stream<DCSScore>` into a `Stream<TriggerEvent>`.
///
/// Implements two thresholds layered on top of the per-window
/// fusion-scream probability:
///
///   • [alertThreshold] (0.75) — must be cleared for
///     [requiredConsecutiveWindows] (3) windows in a row to fire
///     [TriggerKind.alertPending].
///   • [autoSosThreshold] (0.85) — clears a single window, bypasses the
///     vote, fires [TriggerKind.autoSos] immediately.
///
/// Why two layers: the per-window threshold from Day 29 alone is too
/// twitchy for the *system* trigger — a single noisy 450 ms window
/// could spike to 0.7 and call dispatch. The 3-window vote demands the
/// signal hold across 1.35 s, which clears almost all false positives
/// without adding meaningful latency. The 0.85 override exists because
/// for a truly unambiguous reading we don't want to wait.
///
/// The watcher is stateful: it counts consecutive ≥ alert windows
/// across observations. Below-threshold windows reset the counter.
/// Auto-SOS firings ALSO reset the counter so a subsequent alert vote
/// starts fresh.
class DCSScoreWatcher {
  /// Fused danger score for a single window to count toward the alert vote.
  ///
  /// **0.66 as of Day 364D, down from 0.75, because the scale changed.**
  /// The fusion no longer consumes the scream input — see
  /// [DCSInferenceEngine] — so the reachable maximum is now
  /// `0.52·motion + 0.48·scene = 1.0` and the numbers are not comparable to
  /// the old three-input scale.
  ///
  /// Chosen jointly with the weights against measured scenarios rather than
  /// picked: on 60 ambient and 60 violent XD-Violence videos, per window,
  /// under [requiredConsecutiveWindows]:
  ///
  ///     ambient audio, no motion      0.000   (must not alert)
  ///     ambient audio + sustained fall 0.267  (was 0.283)
  ///     violent audio + sustained fall 0.617  (was 0.600)
  ///
  /// Better on both axes than the three-input configuration it replaces,
  /// with a **0.14 margin** between the largest single weight (0.52) and
  /// this threshold, so no single modality can alert alone.
  /// See DAY364D_SCREAM_DROPPED_FROM_GATE.md.
  static const double alertThreshold = 0.66;

  /// Single-window score that bypasses the vote entirely.
  ///
  /// **0.90, and it went UP while [alertThreshold] went down.** That is not
  /// an inconsistency: with scream gone the fused score concentrates into
  /// two inputs, so 0.90 now means "motion and scene both near-maximal"
  /// rather than the looser combination 0.85 bought on the old scale.
  ///
  /// This skips the three-window vote and fires SOS automatically, so it
  /// was chosen for the false-bypass rate rather than for recall:
  ///
  ///     t      ambient+fall bypasses    violent+fall bypasses
  ///     0.85      10.0%                    20.0%
  ///     0.90       3.3%                     6.7%
  ///     0.95       1.7%                     1.7%   <- no discrimination left
  ///
  /// **The discrimination here is only ~2:1 at best**, which is weak for a
  /// control that skips confirmation. 0.90 is the least bad point on that
  /// curve, not a good one; raising it further buys nothing.
  static const double autoSosThreshold = 0.90;

  /// Windows-in-a-row required to fire ALERT_PENDING.
  static const int requiredConsecutiveWindows = 3;

  int _consecutive = 0;

  /// Most recent fused-scream value observed. Used by debug UIs.
  double _lastFusedScream = 0;

  /// Public view of the vote state — `[0, requiredConsecutiveWindows]`.
  /// Lets a UI render a progress dot per window.
  int get currentConsecutive => _consecutive;

  /// Most recent fused-scream probability the watcher saw.
  double get lastFusedScream => _lastFusedScream;

  /// Observes a single score. Returns a [TriggerEvent] when a trigger
  /// fires, otherwise null. State is mutated regardless of return value.
  ///
  /// Resetting semantics:
  ///   • Auto-SOS fires → counter resets to 0.
  ///   • Below-threshold window → counter resets to 0.
  ///   • Alert vote fires → counter resets to 0 (so re-firing requires
  ///     three fresh consecutive windows).
  TriggerEvent? observe(DCSScore score) {
    // Day 335 — this read `classScores['scream']`, a key the fusion has
    // never produced.
    //
    // `DCSInferenceEngine.create()` builds the fusion slot with
    // `classLabels: ['safe', 'danger']`, for both the stub and the real-model
    // branch, so `LinearStubInterpreter` emits exactly those two keys.
    // `['scream']` therefore resolved to null and was coerced to 0 on every
    // single window, which meant neither [autoSosThreshold] nor
    // [alertThreshold] could ever be crossed no matter what the sensors saw.
    //
    // This is the *second* independent break in the same escalation path.
    // Day 326/327 found the fused score capped at 0.50 against a 0.75
    // threshold because motion and scene stubbed out, and fixed the wiring so
    // the score could actually rise. The thing reading that score was still
    // looking at the wrong key, so escalation stayed dead — and nothing threw,
    // because `?? 0` is a perfectly well-formed default.
    //
    // `day335_dcs_scene_slot_test.dart` pins that a maximal-danger window
    // leaves `classScores['scream']` null while `['danger']` exceeds 0.49.
    final danger = score.fusion.classScores['danger'] ?? 0;
    _lastFusedScream = danger;

    if (danger >= autoSosThreshold) {
      _consecutive = 0;
      return TriggerEvent(
        kind: TriggerKind.autoSos,
        score: score,
        passive: true,
        consecutiveWindows: 0,
        timestampMs: score.timestampMs,
      );
    }

    if (danger >= alertThreshold) {
      _consecutive++;
      if (_consecutive >= requiredConsecutiveWindows) {
        final event = TriggerEvent(
          kind: TriggerKind.alertPending,
          score: score,
          passive: true,
          consecutiveWindows: _consecutive,
          timestampMs: score.timestampMs,
        );
        _consecutive = 0;
        return event;
      }
      return null;
    }

    // Below the alert threshold — reset the vote.
    _consecutive = 0;
    return null;
  }

  /// Re-arm the watcher (clear vote state). Useful when the app changes
  /// AppState (e.g. user cancels SOS — we don't want stale vote progress
  /// carrying into the next MONITORING window).
  void reset() {
    _consecutive = 0;
    _lastFusedScream = 0;
  }

  /// Transforms a [DCSScore] stream into a trigger-event stream. The
  /// watcher is single-subscription — each instance maintains its own
  /// counter, so create one watcher per stream consumer.
  Stream<TriggerEvent> watch(Stream<DCSScore> source) async* {
    await for (final score in source) {
      final event = observe(score);
      if (event != null) {
        if (kDebugMode) debugPrint('[DCSScoreWatcher] $event');
        yield event;
      }
    }
  }
}
