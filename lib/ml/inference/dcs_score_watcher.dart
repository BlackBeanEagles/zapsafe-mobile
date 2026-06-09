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
  /// Fusion-scream probability for a single window to count toward
  /// the alert vote.
  static const double alertThreshold = 0.75;

  /// Single-window threshold that bypasses the vote entirely.
  static const double autoSosThreshold = 0.85;

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
    final scream = score.fusion.classScores['scream'] ?? 0;
    _lastFusedScream = scream;

    if (scream >= autoSosThreshold) {
      _consecutive = 0;
      return TriggerEvent(
        kind: TriggerKind.autoSos,
        score: score,
        passive: true,
        consecutiveWindows: 0,
        timestampMs: score.timestampMs,
      );
    }

    if (scream >= alertThreshold) {
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
