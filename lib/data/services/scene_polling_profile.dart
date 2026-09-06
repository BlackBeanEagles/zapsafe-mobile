import '../models/app_state.dart';

/// Day 316 — maps the 7-state [AppState] to a scene-capture cadence.
///
/// Mirrors [GpsPollingProfile]'s exact pattern (gps_polling_profile.dart) —
/// same state groupings, same "off in idle/postIncident" rule — since a
/// periodic camera capture is the same class of battery/privacy-sensitive
/// background activity as GPS polling, and this app already has an
/// established, reviewed answer for how that should scale with app state.
///
/// Camera capture is real hardware I/O (opening the camera, encoding a
/// JPEG, running a real TFLite frame through SceneDetectorV2) — meaningfully
/// more expensive per-tick than a GPS fix, so intervals are deliberately
/// slower than GPS's at every tier rather than reused verbatim: there is
/// real reason to poll location far more often than to be firing the
/// camera repeatedly while nothing is happening.
enum ScenePollingProfile {
  /// Don't capture at all. Used in IDLE / POST_INCIDENT — camera never
  /// opens unless the app is actually monitoring for something.
  off,

  /// Default protective sweep — infrequent, battery-conscious.
  monitoring,

  /// Heightened watch — suspicious signal, but not yet an alert.
  elevated,

  /// Live SOS / alert countdown / escalating — as fast as is reasonable
  /// for a still-image capture-and-classify cycle.
  sosTime;

  /// State → profile mapping. Identical grouping to
  /// [GpsPollingProfile.fromAppState] by design.
  static ScenePollingProfile fromAppState(AppState state) {
    switch (state) {
      case AppState.idle:
      case AppState.postIncident:
        return ScenePollingProfile.off;
      case AppState.monitoring:
        return ScenePollingProfile.monitoring;
      case AppState.elevated:
        return ScenePollingProfile.elevated;
      case AppState.alertPending:
      case AppState.sosActive:
      case AppState.escalating:
        return ScenePollingProfile.sosTime;
    }
  }

  /// Interval between captures. [Duration.zero] for [off] (no timer fires).
  Duration get interval => switch (this) {
        ScenePollingProfile.off        => Duration.zero,
        ScenePollingProfile.monitoring => const Duration(minutes: 5),
        ScenePollingProfile.elevated   => const Duration(seconds: 45),
        ScenePollingProfile.sosTime    => const Duration(seconds: 15),
      };

  /// Human-readable label for UI/debug surfaces.
  String get label => switch (this) {
        ScenePollingProfile.off        => 'OFF',
        ScenePollingProfile.monitoring => 'MONITORING',
        ScenePollingProfile.elevated   => 'ELEVATED',
        ScenePollingProfile.sosTime    => 'SOS-TIME',
      };
}
