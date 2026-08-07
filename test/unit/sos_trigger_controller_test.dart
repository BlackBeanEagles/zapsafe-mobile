// Day 321 — SosTriggerController state-transition tests.
//
// All pure Dart — no Riverpod, no plugins. Mirrors the shape of
// test/unit/trigger_orchestrator_test.dart: construct a real
// AppStateNotifier + TriggerOrchestrator, wrap them in the controller,
// and assert on the real resulting AppState after each of the four entry
// points.

import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/data/models/app_state.dart';
import 'package:zapsafe_mobile/data/models/dcs_score.dart';
import 'package:zapsafe_mobile/data/models/fall_event.dart';
import 'package:zapsafe_mobile/data/models/inference_result.dart';
import 'package:zapsafe_mobile/data/models/trigger_event.dart';
import 'package:zapsafe_mobile/domain/integration/trigger_orchestrator.dart';
import 'package:zapsafe_mobile/domain/providers/app_state_provider.dart';
import 'package:zapsafe_mobile/domain/sos/sos_trigger_controller.dart';

TriggerEvent _dcsEvent(TriggerKind kind, {double scream = 0.8}) {
  final fusion = InferenceResult(
    label: scream >= 0.5 ? 'scream' : 'normal',
    score: scream,
    classScores: {'scream': scream, 'normal': 1 - scream},
    latencyMs: 1,
    timestampMs: 0,
  );
  return TriggerEvent(
    kind: kind,
    score: DCSScore(timestampMs: 0, audio: fusion, fusion: fusion),
    passive: true,
    consecutiveWindows: kind == TriggerKind.alertPending ? 3 : 0,
    timestampMs: 0,
  );
}

const _fall = FallEvent(
  timestampMs: 0,
  peakAccelMagnitude: 28.4,
  freefallDurationMs: 320,
);

SosTriggerController _build(AppStateNotifier n) {
  final orch = TriggerOrchestrator(notifier: n);
  return SosTriggerController(orchestrator: orch, notifier: n);
}

void main() {
  group('SosTriggerController · entry point 1 (manual)', () {
    test('triggerManual → monitoring → alertPending, counters + log update',
        () {
      final n = AppStateNotifier();
      final ctrl = _build(n);
      ctrl.triggerManual();
      expect(n.state, AppState.alertPending);
      expect(ctrl.manualCount, 1);
      expect(ctrl.log, hasLength(1));
      expect(ctrl.log.single.source, SosTriggerSource.manual);
      expect(ctrl.log.single.resultingState, AppState.alertPending);
    });
  });

  group('SosTriggerController · entry point 2 (fall)', () {
    test('triggerFall delegates to TriggerOrchestrator.dispatchFall', () {
      final n = AppStateNotifier();
      final ctrl = _build(n);
      ctrl.triggerFall(_fall);
      expect(n.state, AppState.alertPending);
      expect(ctrl.fallCount, 1);
      expect(ctrl.log.single.source, SosTriggerSource.fall);
      expect(ctrl.log.single.detail, contains('peak='));
    });
  });

  group('SosTriggerController · entry point 3 (DCS auto)', () {
    test('ALERT_PENDING event → alertPending', () {
      final n = AppStateNotifier();
      final ctrl = _build(n);
      ctrl.triggerDcs(_dcsEvent(TriggerKind.alertPending, scream: 0.78));
      expect(n.state, AppState.alertPending);
      expect(ctrl.dcsAlertCount, 1);
    });

    test('AUTO_SOS event → sosActive, skips countdown (LP25)', () {
      final n = AppStateNotifier();
      final ctrl = _build(n);
      ctrl.triggerDcs(_dcsEvent(TriggerKind.autoSos, scream: 0.92));
      expect(n.state, AppState.sosActive);
      expect(n.alertCountdownStartedAt, isNull);
      expect(ctrl.dcsAutoSosCount, 1);
    });
  });

  group('SosTriggerController · entry point 4 (duress PIN cancel · LP3)', () {
    test('real PIN cancel → monitoring, silentlyEscalating stays false', () {
      final n = AppStateNotifier();
      final ctrl = _build(n);
      ctrl.triggerDcs(_dcsEvent(TriggerKind.alertPending));
      expect(n.state, AppState.alertPending);

      final outcome = ctrl.submitCancelPin('1234');
      expect(outcome, SosCancelOutcome.realCancel);
      expect(n.state, AppState.monitoring);
      expect(ctrl.silentlyEscalating, isFalse);
      expect(ctrl.duressCancelCount, 1);
    });

    test('duress PIN cancel → visibly monitoring but silentlyEscalating=true',
        () {
      final n = AppStateNotifier();
      final ctrl = _build(n);
      ctrl.triggerDcs(_dcsEvent(TriggerKind.alertPending));

      final outcome = ctrl.submitCancelPin('9999');
      expect(outcome, SosCancelOutcome.duressCancel);
      // LP3 — UI-visible state is identical to the real-cancel path.
      expect(n.state, AppState.monitoring);
      expect(ctrl.silentlyEscalating, isTrue);
      expect(ctrl.duressCancelCount, 1);
    });

    test('wrong PIN → no state change, no log entry', () {
      final n = AppStateNotifier();
      final ctrl = _build(n);
      ctrl.triggerDcs(_dcsEvent(TriggerKind.alertPending));
      final before = n.state;

      final outcome = ctrl.submitCancelPin('0000');
      expect(outcome, SosCancelOutcome.wrongPin);
      expect(n.state, before);
      expect(ctrl.duressCancelCount, 0);
    });
  });

  group('SosTriggerController · combined flow', () {
    test('all four entry points funnel through the same real state machine',
        () {
      final n = AppStateNotifier();
      final ctrl = _build(n);

      ctrl.triggerManual();
      expect(n.state, AppState.alertPending);

      ctrl.submitCancelPin('1234'); // real cancel
      expect(n.state, AppState.monitoring);

      ctrl.triggerFall(_fall);
      expect(n.state, AppState.alertPending);

      ctrl.submitCancelPin('9999'); // duress cancel
      expect(n.state, AppState.monitoring);
      expect(ctrl.silentlyEscalating, isTrue);

      ctrl.triggerDcs(_dcsEvent(TriggerKind.autoSos, scream: 0.95));
      expect(n.state, AppState.sosActive);

      expect(ctrl.manualCount, 1);
      expect(ctrl.fallCount, 1);
      expect(ctrl.dcsAutoSosCount, 1);
      expect(ctrl.duressCancelCount, 2);
      expect(ctrl.log, hasLength(5));
    });

    test('log is bounded by historyLimit', () {
      final n = AppStateNotifier();
      final ctrl = _build(n);
      for (var i = 0; i < SosTriggerController.historyLimit + 5; i++) {
        ctrl.triggerManual();
        // Return to monitoring so the next manual trigger is a real
        // transition too (repeated triggers from alertPending are no-ops
        // in the underlying notifier).
        n.onCancelWithRealPIN();
      }
      expect(ctrl.log.length, SosTriggerController.historyLimit);
    });
  });
}
