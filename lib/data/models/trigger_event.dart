import 'package:flutter/foundation.dart';

import 'dcs_score.dart';

/// Day 33 — kinds of automatic trigger the watcher can fire.
enum TriggerKind {
  /// `fusion-scream` ≥ 0.75 for 3 consecutive windows.
  ///
  /// Promotes the app to ALERT_PENDING — the user gets a countdown to
  /// cancel before full SOS escalation. This is the normal trigger path.
  alertPending,

  /// `fusion-scream` ≥ 0.85 in a *single* window.
  ///
  /// Bypasses the vote and fires SOS immediately. Reserved for signals
  /// so strong that waiting two more windows (~900 ms) costs the user.
  autoSos,
}

extension TriggerKindLabel on TriggerKind {
  String get label => switch (this) {
        TriggerKind.alertPending => 'ALERT_PENDING',
        TriggerKind.autoSos      => 'AUTO_SOS',
      };

  String get blurb => switch (this) {
        TriggerKind.alertPending =>
          '3 consecutive windows ≥ 0.75 · countdown begins',
        TriggerKind.autoSos =>
          'single window ≥ 0.85 · bypass vote · fire now',
      };
}

/// Day 33 — one trigger emission from [DCSScoreWatcher].
///
/// Carries the score that crossed the threshold plus the LP25 [passive]
/// flag — every DCS-driven trigger is passive (i.e. not user-initiated).
/// The backend dispatch path consumes [passive] to decide between
/// sequential vs parallel Tier-1/Tier-2 notification (true → parallel).
@immutable
class TriggerEvent {
  final TriggerKind kind;
  final DCSScore score;

  /// LP25 flag — `true` for every DCS-driven trigger (auto SOS / vote).
  /// Always set to true for now; the manual-trigger path that lands in
  /// the dashboard work (Month 4+) will create [TriggerEvent]s with
  /// `passive: false`.
  final bool passive;

  /// How many consecutive windows ≥ alert threshold preceded this
  /// trigger. 0 for AUTO_SOS (the vote was bypassed).
  final int consecutiveWindows;

  /// Capture-time millis of the source [score].
  final int timestampMs;

  const TriggerEvent({
    required this.kind,
    required this.score,
    required this.passive,
    required this.consecutiveWindows,
    required this.timestampMs,
  });

  /// Fusion-scream probability that triggered this event — the metric
  /// the watcher compares against thresholds. Defaults to 0 if missing.
  double get fusedScream => score.fusion.classScores['scream'] ?? 0;

  @override
  String toString() =>
      'TriggerEvent(${kind.label}, scream=${fusedScream.toStringAsFixed(3)}, '
      'consecutive=$consecutiveWindows, passive=$passive)';
}
