/// Day 37 — the 7-state app state machine. Each state drives behaviour
/// across multiple services (GPS polling cadence, push routing,
/// background-engine power profile, etc.).
///
/// Day 39's `AppStateNotifier` builds the formal transition rules. Day
/// 37 introduces only the enum so the GPS service can map state →
/// polling profile without waiting for the full state machine.
enum AppState {
  /// Service not started yet · permissions not granted · everything off.
  idle,

  /// Default running state · sensors active · low-power polling.
  monitoring,

  /// Suspicious signal observed · increase sampling rates · still no SOS.
  elevated,

  /// 3-window vote crossed (Day 33) · countdown to SOS · user can cancel.
  alertPending,

  /// SOS dispatched · everything at max · backend escalating.
  sosActive,

  /// Tier-1 contact responding · holding pattern.
  escalating,

  /// SOS resolved · brief debrief window before returning to monitoring.
  postIncident;

  /// Human-readable label for UI surfaces.
  String get label => switch (this) {
        AppState.idle          => 'IDLE',
        AppState.monitoring    => 'MONITORING',
        AppState.elevated      => 'ELEVATED',
        AppState.alertPending  => 'ALERT_PENDING',
        AppState.sosActive     => 'SOS_ACTIVE',
        AppState.escalating    => 'ESCALATING',
        AppState.postIncident  => 'POST_INCIDENT',
      };
}
