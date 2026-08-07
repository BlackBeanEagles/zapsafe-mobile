/// Day 321 — SOS Trigger Production Refactor.
///
/// Single entry point that consolidates every real SOS trigger surface —
/// manual, fall, DCS auto, and the LP3 duress-PIN cancel path — behind one
/// controller class.
///
/// This is an **extract-and-delegate wrapper** around the Day 39
/// `TriggerOrchestrator` + `AppStateNotifier`, not a second trigger path.
/// Every method below calls straight through to the exact same real
/// production methods `sos_trigger_button.dart` (Day 307,
/// `TriggerOrchestrator.dispatchManual`), the DCS/fall stream bootstrap
/// (`trigger_orchestrator_providers.dart`, `dispatchDcs`/`dispatchFall`),
/// and the PIN-cancel screens (`AppStateNotifier.onCancelWithRealPIN` /
/// `onCancelWithDuressPIN`) already use. No new escalation policy, PIN
/// comparison, or state-machine logic is introduced here — this class owns
/// nothing but call-forwarding + a small unified event log.
///
/// Honest scope note (read before assuming this replaced every call site):
/// `day39_state_wiring_screen.dart` and `day71_alert_pending_screen.dart`
/// were **not** rewritten to call through this controller — they are
/// stable, already-shipped, already-tested production/demo screens, and
/// rewriting them was out of scope for a single polish day without risking
/// the existing 706-test baseline. `sos_trigger_button.dart` (Day 307,
/// production dashboard) also still calls `TriggerOrchestrator` directly —
/// same reasoning. This controller is the new sanctioned single entry
/// point for *future* trigger surfaces; the Day 321 screen demonstrates all
/// four real paths funnelling through it side-by-side, and this doc records
/// the not-yet-done migration of the three existing call sites as a real,
/// tracked gap rather than a silently claimed one.
library;

import 'package:flutter/foundation.dart';

import '../../data/models/app_state.dart';
import '../../data/models/fall_event.dart';
import '../../data/models/trigger_event.dart';
import '../../data/services/pin_policy.dart';
import '../integration/trigger_orchestrator.dart';
import '../providers/app_state_provider.dart';

/// Outcome of [SosTriggerController.submitCancelPin]. LP3 requires the UI
/// to render [realCancel] and [duressCancel] identically — the caller is
/// responsible for that, this enum is the plumbing distinction only.
enum SosCancelOutcome { realCancel, duressCancel, wrongPin }

/// Which of the four real entry points produced a given [SosControllerEvent].
/// Informational only — `TriggerOrchestrator` itself stays policy/source
/// agnostic per its own class doc, and this enum does not change that.
enum SosTriggerSource { manual, fall, dcs, duressPinCancel }

/// One row in the controller's own unified event log — a merge of
/// `TriggerOrchestrator.history` (manual/fall/dcs) with PIN-cancel events
/// the orchestrator doesn't see at all (cancel is a notifier-only call).
@immutable
class SosControllerEvent {
  final SosTriggerSource source;
  final String detail;
  final AppState resultingState;
  final DateTime at;

  const SosControllerEvent({
    required this.source,
    required this.detail,
    required this.resultingState,
    required this.at,
  });

  @override
  String toString() =>
      '[${source.name}] $detail → ${resultingState.label}';
}

class SosTriggerController {
  /// Max events kept in the in-memory log — mirrors
  /// `TriggerOrchestrator.historyLimit`.
  static const int historyLimit = 32;

  SosTriggerController({
    required TriggerOrchestrator orchestrator,
    required AppStateNotifier notifier,
    PinPolicy? pinPolicy,
  })  : _orchestrator = orchestrator,
        _notifier = notifier,
        _pinPolicy = pinPolicy ?? PinPolicy();

  final TriggerOrchestrator _orchestrator;
  final AppStateNotifier _notifier;
  final PinPolicy _pinPolicy;

  final List<SosControllerEvent> _log = [];
  List<SosControllerEvent> get log => List.unmodifiable(_log);

  /// Read-through to the real state machine — never cached/shadowed.
  AppState get state => _notifier.state;
  bool get silentlyEscalating => _notifier.silentlyEscalating;

  /// Read-through to the orchestrator's own counters, so the Day 321
  /// screen can show one dashboard without re-deriving anything.
  int get manualCount => _orchestrator.manualCount;
  int get fallCount => _orchestrator.fallCount;
  int get dcsAlertCount => _orchestrator.dcsAlertCount;
  int get dcsAutoSosCount => _orchestrator.dcsAutoSosCount;
  int get duressCancelCount =>
      _log.where((e) => e.source == SosTriggerSource.duressPinCancel).length;

  // ─── Entry point 1 — manual ────────────────────────────────────────────

  /// Manual trigger surface (SOS long-press button, any future manual
  /// button). Delegates verbatim to `TriggerOrchestrator.dispatchManual` —
  /// the exact call `sos_trigger_button.dart` already makes.
  void triggerManual({String? cause}) {
    final c = cause ?? 'Manual trigger';
    _orchestrator.dispatchManual(TriggerMethod.manual, cause: c);
    _record(SosTriggerSource.manual, c);
  }

  // ─── Entry point 2 — fall ──────────────────────────────────────────────

  /// Fall detector surface. Delegates verbatim to
  /// `TriggerOrchestrator.dispatchFall` — the same method the IMU fall
  /// stream feeds via `triggerOrchestratorBootstrapProvider.attach()`.
  void triggerFall(FallEvent event) {
    _orchestrator.dispatchFall(event);
    _record(
      SosTriggerSource.fall,
      'peak=${event.peakAccelMagnitude.toStringAsFixed(1)} m/s² · '
      'freefall=${event.freefallDurationMs}ms',
    );
  }

  // ─── Entry point 3 — DCS auto ──────────────────────────────────────────

  /// DCS auto-trigger surface. Delegates verbatim to
  /// `TriggerOrchestrator.dispatchDcs` — the same method the
  /// `DCSScoreWatcher` stream feeds via the same bootstrap provider.
  void triggerDcs(TriggerEvent event) {
    _orchestrator.dispatchDcs(event);
    _record(SosTriggerSource.dcs, event.kind.label);
  }

  // ─── Entry point 4 — duress PIN cancel (LP3) ───────────────────────────

  /// Duress-PIN cancel-time classification (LP3). Not an escalate-upward
  /// "trigger" — it fires while an alert/SOS is ALREADY active, when the
  /// user is asked to cancel. Delegates to the exact same
  /// `AppStateNotifier.onCancelWithRealPIN` / `onCancelWithDuressPIN` calls
  /// `day39_state_wiring_screen.dart` and `day71_alert_pending_screen.dart`
  /// already make, via the same `PinPolicy` — no new comparison logic.
  SosCancelOutcome submitCancelPin(String pin, {String? cause}) {
    final match = _pinPolicy.classify(pin);
    if (match == PinMatch.real) {
      _notifier.onCancelWithRealPIN(cause: cause ?? 'PIN cancel (real)');
      _record(SosTriggerSource.duressPinCancel, 'real PIN cancel');
      return SosCancelOutcome.realCancel;
    }
    if (match == PinMatch.duress) {
      _notifier.onCancelWithDuressPIN(cause: cause ?? 'PIN cancel (duress)');
      _record(SosTriggerSource.duressPinCancel, 'duress PIN cancel (LP3)');
      return SosCancelOutcome.duressCancel;
    }
    return SosCancelOutcome.wrongPin;
  }

  void _record(SosTriggerSource source, String detail) {
    _log.add(SosControllerEvent(
      source: source,
      detail: detail,
      resultingState: _notifier.state,
      at: DateTime.now(),
    ));
    while (_log.length > historyLimit) {
      _log.removeAt(0);
    }
  }
}
