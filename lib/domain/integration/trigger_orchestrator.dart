import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../../data/models/app_state.dart';
import '../../data/models/fall_event.dart';
import '../../data/models/trigger_event.dart';
import '../providers/app_state_provider.dart';

/// Day 39 — one row in the orchestrator's recent-events log.
@immutable
class OrchestratorEvent {
  final String source;
  final String label;
  final AppState resultingState;
  final DateTime at;

  const OrchestratorEvent({
    required this.source,
    required this.label,
    required this.resultingState,
    required this.at,
  });

  @override
  String toString() => '[$source] $label → ${resultingState.label}';
}

/// Day 39 — wires DCS [TriggerEvent]s and IMU [FallEvent]s into the
/// central [AppStateNotifier].
///
/// Routing table:
///
/// | Source              | Kind / shape           | AppStateNotifier method                          |
/// |---------------------|------------------------|--------------------------------------------------|
/// | DCSScoreWatcher     | alertPending           | `onDCSThresholdExceeded(cause: 'DCS vote × N')`  |
/// | DCSScoreWatcher     | autoSos                | `onAutoSos(cause: 'DCS scream …')` *(LP25)*      |
/// | FallDetector        | `FallEvent`            | `onManualTrigger(TriggerMethod.fall)`            |
/// | (manual surfaces)   | `dispatchManual()`     | `onManualTrigger(method)`                        |
///
/// The orchestrator is **policy-free** by design — it owns no thresholds
/// of its own; it just translates upstream events into method calls on
/// the notifier. That keeps the unit test surface tiny (input event →
/// output state).
class TriggerOrchestrator {
  /// Max events kept in the in-memory log.
  static const int historyLimit = 32;

  final AppStateNotifier _notifier;
  StreamSubscription<TriggerEvent>? _dcsSub;
  StreamSubscription<FallEvent>? _fallSub;

  TriggerOrchestrator({required AppStateNotifier notifier})
      : _notifier = notifier;

  int _dcsAlertCount = 0;
  int _dcsAutoSosCount = 0;
  int _fallCount = 0;
  int _manualCount = 0;
  bool _attached = false;

  int get dcsAlertCount    => _dcsAlertCount;
  int get dcsAutoSosCount  => _dcsAutoSosCount;
  int get fallCount        => _fallCount;
  int get manualCount      => _manualCount;
  bool get isAttached      => _attached;
  int get totalDispatched  =>
      _dcsAlertCount + _dcsAutoSosCount + _fallCount + _manualCount;

  final ListQueue<OrchestratorEvent> _history = ListQueue();
  List<OrchestratorEvent> get history => List.unmodifiable(_history);

  /// Subscribe to the upstream streams. Idempotent — calling twice is a
  /// no-op so hot reload doesn't double-subscribe.
  void attach({
    required Stream<TriggerEvent> dcsEvents,
    required Stream<FallEvent> fallEvents,
  }) {
    if (_attached) return;
    _attached = true;
    _dcsSub = dcsEvents.listen(dispatchDcs, onError: _onErr('dcs'));
    _fallSub = fallEvents.listen(dispatchFall, onError: _onErr('fall'));
  }

  /// Cancel the subscriptions. Counters + history survive.
  Future<void> detach() async {
    _attached = false;
    await _dcsSub?.cancel();
    await _fallSub?.cancel();
    _dcsSub = null;
    _fallSub = null;
  }

  Future<void> dispose() => detach();

  /// Manual trigger surface — used by SOS buttons / double-tap gestures.
  /// The orchestrator records it for parity with the auto-trigger paths.
  void dispatchManual(TriggerMethod method, {String? cause}) {
    _manualCount++;
    _notifier.onManualTrigger(method, cause: cause);
    _log('MANUAL', method.label);
  }

  // ─── Stream handlers (public so screens + tests can synth events) ─────

  /// Dispatch a single DCS trigger. Called by the stream subscription
  /// after [attach] and exposed for the Day 39 demo screen to inject
  /// synthetic events without manufacturing a full DCSScore pipeline.
  void dispatchDcs(TriggerEvent e) {
    switch (e.kind) {
      case TriggerKind.alertPending:
        _dcsAlertCount++;
        _notifier.onDCSThresholdExceeded(
            cause: 'DCS vote · scream=${e.fusedScream.toStringAsFixed(2)}');
        _log('DCS', e.kind.label);
        break;
      case TriggerKind.autoSos:
        _dcsAutoSosCount++;
        _notifier.onAutoSos(
            cause: 'AUTO_SOS · scream=${e.fusedScream.toStringAsFixed(2)}');
        _log('DCS', e.kind.label);
        break;
    }
  }

  /// Dispatch a single fall event. Called by the stream subscription
  /// after [attach] and exposed for the Day 39 demo screen + tests.
  void dispatchFall(FallEvent e) {
    _fallCount++;
    _notifier.onManualTrigger(
      TriggerMethod.fall,
      cause: 'fall · peak=${e.peakAccelMagnitude.toStringAsFixed(1)} m/s² · '
          'freefall=${e.freefallDurationMs}ms',
    );
    _log('IMU', 'FALL');
  }

  void _log(String source, String label) {
    _history.addLast(OrchestratorEvent(
      source: source,
      label: label,
      resultingState: _notifier.state,
      at: DateTime.now(),
    ));
    while (_history.length > historyLimit) {
      _history.removeFirst();
    }
  }

  void Function(Object) _onErr(String tag) => (Object e) {
        if (kDebugMode) debugPrint('[orchestrator/$tag] stream error: $e');
      };
}
