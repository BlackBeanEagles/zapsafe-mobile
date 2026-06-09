import 'package:geolocator/geolocator.dart';

import '../models/app_state.dart';

/// Day 37 — maps the 7-state [AppState] to a GPS polling cadence +
/// accuracy. Pure data, no I/O — trivially unit-testable.
///
/// Cadence tuning per the timeline:
///   • MONITORING  — every 5 min, low accuracy   · saves battery
///   • ELEVATED    — every 30 s, high accuracy   · suspicious signal
///   • SOS-time    — every 10 s, best accuracy   · live tracking
enum GpsPollingProfile {
  /// Don't poll at all. Used in IDLE / POST_INCIDENT.
  off,

  /// Default protective sweep — 5-minute cadence, low accuracy.
  monitoring,

  /// Heightened watch — 30 s, high accuracy.
  elevated,

  /// Live SOS — 10 s, best accuracy.
  sosTime;

  /// State → profile mapping.
  static GpsPollingProfile fromAppState(AppState state) {
    switch (state) {
      case AppState.idle:
      case AppState.postIncident:
        return GpsPollingProfile.off;
      case AppState.monitoring:
        return GpsPollingProfile.monitoring;
      case AppState.elevated:
        return GpsPollingProfile.elevated;
      case AppState.alertPending:
      case AppState.sosActive:
      case AppState.escalating:
        return GpsPollingProfile.sosTime;
    }
  }

  /// Interval between polls. [Duration.zero] for [off] (no timer fires).
  Duration get interval => switch (this) {
        GpsPollingProfile.off        => Duration.zero,
        GpsPollingProfile.monitoring => const Duration(minutes: 5),
        GpsPollingProfile.elevated   => const Duration(seconds: 30),
        GpsPollingProfile.sosTime    => const Duration(seconds: 10),
      };

  /// Native location-accuracy hint passed to `geolocator`.
  LocationAccuracy get accuracy => switch (this) {
        GpsPollingProfile.off        => LocationAccuracy.low,
        GpsPollingProfile.monitoring => LocationAccuracy.low,
        GpsPollingProfile.elevated   => LocationAccuracy.high,
        GpsPollingProfile.sosTime    => LocationAccuracy.best,
      };

  /// Human-readable label.
  String get label => switch (this) {
        GpsPollingProfile.off        => 'OFF',
        GpsPollingProfile.monitoring => 'MONITORING',
        GpsPollingProfile.elevated   => 'ELEVATED',
        GpsPollingProfile.sosTime    => 'SOS-TIME',
      };
}
