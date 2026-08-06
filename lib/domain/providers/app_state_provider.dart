import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/app_state.dart';
import 'gps_providers.dart';

/// Day 38 — input event for the central state machine.
///
/// Each transition method on [AppStateNotifier] records the trigger that
/// caused it so the dashboard + debug surfaces can render a transition
/// log without inferring intent from `prev → next` deltas.
enum TriggerMethod {
  dcs,
  manual,
  fall,
  doubleTap,
  voiceCue,
  external;

  String get label => switch (this) {
        TriggerMethod.dcs       => 'DCS_THRESHOLD',
        TriggerMethod.manual    => 'MANUAL',
        TriggerMethod.fall      => 'FALL_DETECTED',
        TriggerMethod.doubleTap => 'DOUBLE_TAP',
        TriggerMethod.voiceCue  => 'VOICE_CUE',
        TriggerMethod.external  => 'EXTERNAL',
      };
}

/// One row in the AppState transition log. Sorted oldest-first.
@immutable
class AppStateTransition {
  final AppState from;
  final AppState to;
  final String cause;
  final DateTime at;

  const AppStateTransition({
    required this.from,
    required this.to,
    required this.cause,
    required this.at,
  });

  @override
  String toString() => '${from.label} → ${to.label}  ($cause)';
}

/// Day 38 — the central 7-state app state machine.
///
/// All higher-level logic in the app eventually reduces to one of these
/// transitions. The notifier is intentionally **policy-only** — it does
/// no I/O of its own — so it is trivially unit-testable. Side effects
/// (GPS profile rotation, push channel switching, FGS power mode) are
/// wired by separate Riverpod listeners that watch [appStateProvider].
///
/// Transition matrix (`*` = unchanged):
///
/// ```
///                       monitoring elevated alertPending sosActive escalating postIncident idle
/// elevateSignal          elevated    *        *            *         *          *            *
/// elevateReset           *           monitor  *            *         *          *            *
/// dcsThresholdExceeded   alertPend   alertPend *           *         *          *            *
/// manualTrigger          alertPend   alertPend *           *         *          *            *
/// cancelWithRealPin      *           *        monitoring   monitor   monitor    monitor      *
/// cancelWithDuressPin    *           *        monitoring   monitor   monitor    monitor      *   (silentlyEscalating ← true)
/// alertPendingExpired    *           *        sosActive    *         *          *            *
/// tier1Acknowledged      *           *        *            escalat   *          *            *
/// sosResolved            *           *        *            postIncid postIncid  *            *
/// returnToMonitoring     *           monitor  monitor      *         *          monitoring   monitoring
/// powerOn                monitoring  *        *            *         *          *            monitoring
/// powerOff               idle        idle     idle         idle      idle       idle         *
/// ```
class AppStateNotifier extends StateNotifier<AppState> {
  /// LP15 — fixed 15 s grace window between [AppState.alertPending] and
  /// [AppState.sosActive] so the user can cancel a false trigger.
  static const Duration alertCountdown = Duration(seconds: 15);

  /// Max transitions kept in the in-memory log. The dashboard surfaces
  /// the most recent ones for forensic review.
  static const int historyLimit = 32;

  AppStateNotifier({AppState initial = AppState.monitoring})
      : super(initial);

  Timer? _alertTimer;
  bool _silentlyEscalating = false;
  bool _possibleUnconscious = false;
  final List<AppStateTransition> _history = [];

  /// True after a duress-PIN cancel (LP3). The UI reflects "MONITORING"
  /// but the backend dispatch pipeline keeps escalating silently.
  /// Day 38 surfaces the flag; Day 39 wires the real dispatch coupling.
  bool get silentlyEscalating => _silentlyEscalating;

  /// Day 94 Track P — scream then silence + still → unconscious victim messaging.
  bool get possibleUnconscious => _possibleUnconscious;

  /// Time the [AppState.alertPending] countdown was started, or null if
  /// no countdown is active. UIs read this to render a live timer.
  DateTime? _alertCountdownStartedAt;
  DateTime? get alertCountdownStartedAt => _alertCountdownStartedAt;

  /// Read-only list of recent transitions, oldest first.
  List<AppStateTransition> get history =>
      List.unmodifiable(_history);

  // ─── Transitions ───────────────────────────────────────────────────────

  void onElevatedSignal({String cause = 'sensor signal'}) {
    if (state == AppState.monitoring) _to(AppState.elevated, cause);
  }

  void onElevatedReset({String cause = 'signal cleared'}) {
    if (state == AppState.elevated) _to(AppState.monitoring, cause);
  }

  void onDCSThresholdExceeded({String cause = 'DCS vote'}) {
    if (state == AppState.monitoring || state == AppState.elevated) {
      _to(AppState.alertPending, cause);
      _startAlertCountdown();
    }
  }

  void onManualTrigger(TriggerMethod method, {String? cause}) {
    if (state == AppState.sosActive || state == AppState.escalating) return;
    _to(AppState.alertPending, cause ?? method.label);
    _startAlertCountdown();
  }

  void onCancelWithRealPIN({String cause = 'PIN cancel'}) {
    if (state == AppState.idle) return;
    _silentlyEscalating = false;
    _possibleUnconscious = false;
    _cancelAlertCountdown();
    _to(AppState.monitoring, cause);
  }

  /// LP3 — duress PIN. UI returns to MONITORING but the dispatch layer
  /// keeps escalating in the background. The flag survives until
  /// [onSosResolved] or [returnToMonitoring].
  void onCancelWithDuressPIN({String cause = 'duress PIN'}) {
    if (state == AppState.idle) return;
    _silentlyEscalating = true;
    _cancelAlertCountdown();
    _to(AppState.monitoring, '$cause (LP3 silent escalation)');
  }

  void onAlertPendingExpired({String cause = 'countdown expired'}) {
    if (state != AppState.alertPending) return;
    _cancelAlertCountdown();
    _to(AppState.sosActive, cause);
  }

  /// Day 39 — LP25 immediate SOS path.
  ///
  /// Used by AUTO_SOS triggers (DCS fusion-scream ≥ 0.85 single window)
  /// and any future "panic chord" gestures that should bypass the 15 s
  /// alert countdown. Cancels any in-flight countdown and jumps the
  /// state machine straight to [AppState.sosActive] regardless of the
  /// current state — except [AppState.idle] which means the service is
  /// off and the dispatch path can't fire anyway.
  void onAutoSos({String cause = 'AUTO_SOS · single window ≥ 0.85'}) {
    if (state == AppState.idle) return;
    _cancelAlertCountdown();
    if (state == AppState.sosActive || state == AppState.escalating) {
      return; // already firing
    }
    _to(AppState.sosActive, cause);
  }

  /// Day 94 Track P — silence-after-distress escalation (CRITICAL SOS path).
  void onSilenceAfterDistressEscalation({
    String cause = 'CRITICAL: Possible unconscious victim',
  }) {
    if (state == AppState.idle) return;
    _possibleUnconscious = true;
    _cancelAlertCountdown();
    if (state == AppState.sosActive || state == AppState.escalating) {
      return;
    }
    _to(AppState.sosActive, cause);
  }

  void onTier1Acknowledged({String cause = 'tier-1 ack'}) {
    if (state == AppState.sosActive) _to(AppState.escalating, cause);
  }

  void onSosResolved({String cause = 'sos resolved'}) {
    if (state == AppState.sosActive || state == AppState.escalating) {
      _silentlyEscalating = false;
      _possibleUnconscious = false;
      _to(AppState.postIncident, cause);
    }
  }

  void returnToMonitoring({String cause = 'return to monitoring'}) {
    if (state == AppState.idle) return;
    _silentlyEscalating = false;
    _possibleUnconscious = false;
    _cancelAlertCountdown();
    if (state != AppState.monitoring) _to(AppState.monitoring, cause);
  }

  void powerOn({String cause = 'service start'}) {
    if (state == AppState.idle) _to(AppState.monitoring, cause);
  }

  void powerOff({String cause = 'service stop'}) {
    if (state != AppState.idle) {
      _cancelAlertCountdown();
      _silentlyEscalating = false;
      _possibleUnconscious = false;
      _to(AppState.idle, cause);
    }
  }

  /// Cold-start restore when GET /api/v1/sos/active/ returns a live event.
  void restoreActiveSos({String cause = 'hydrated active SOS'}) {
    _cancelAlertCountdown();
    _silentlyEscalating = false;
    _possibleUnconscious = false;
    if (state != AppState.sosActive && state != AppState.escalating) {
      _to(AppState.sosActive, cause);
    }
  }

  /// Direct setter used by debug screens (Day 37/38). Cancels any in-flight
  /// alert countdown so the screen state stays consistent. Production code
  /// should use the named transition methods, not this.
  @visibleForTesting
  void setRaw(AppState next, {String cause = 'manual override'}) {
    _cancelAlertCountdown();
    if (next != AppState.alertPending) _silentlyEscalating = false;
    _to(next, cause);
  }

  /// @visibleForTesting hook so unit tests can confirm the countdown
  /// fires the expected transition without sleeping for 15 s.
  @visibleForTesting
  Future<void> debugFireAlertCountdown() async {
    _cancelAlertCountdown();
    onAlertPendingExpired(cause: 'test countdown fire');
  }

  // ─── Internals ─────────────────────────────────────────────────────────

  void _startAlertCountdown() {
    _cancelAlertCountdown();
    _alertCountdownStartedAt = DateTime.now();
    _alertTimer = Timer(alertCountdown, onAlertPendingExpired);
  }

  void _cancelAlertCountdown() {
    _alertTimer?.cancel();
    _alertTimer = null;
    _alertCountdownStartedAt = null;
  }

  void _to(AppState next, String cause) {
    if (next == state) return;
    _history.add(AppStateTransition(
      from: state,
      to: next,
      cause: cause,
      at: DateTime.now(),
    ));
    if (_history.length > historyLimit) {
      _history.removeRange(0, _history.length - historyLimit);
    }
    state = next;
  }

  @override
  void dispose() {
    _cancelAlertCountdown();
    super.dispose();
  }
}

/// Day 38 — the single source of truth for the app's lifecycle state.
final appStateProvider =
    StateNotifierProvider<AppStateNotifier, AppState>(
        (_) => AppStateNotifier());

/// Day 38 — side-effect bridge. Wires [appStateProvider] to the GPS
/// service's polling profile so the cadence rotates automatically when
/// the state machine transitions, and mirrors the value into the
/// legacy [gpsAppStateProvider] so screens predating the refactor stay
/// in sync. Kept alive by being read from the Day 38 screen on mount.
final appStateGpsBridgeProvider = Provider<void>((ref) {
  final gps = ref.read(gpsServiceProvider);
  ref.listen<AppState>(
    appStateProvider,
    (prev, next) {
      if (prev == next) return;
      gps.setAppState(next);
      // Keep the legacy StateProvider in lockstep without forcing every
      // caller to migrate today. New callers should consume
      // [appStateProvider] directly.
      ref.read(gpsAppStateProvider.notifier).state = next;
    },
    fireImmediately: true,
  );
});
