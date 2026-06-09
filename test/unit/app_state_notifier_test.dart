// Day 38 — AppStateNotifier transition matrix.
//
// Pure policy class — runs on the host VM without any plugin.

import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/data/models/app_state.dart';
import 'package:zapsafe_mobile/domain/providers/app_state_provider.dart';

void main() {
  group('AppStateNotifier · transitions', () {
    test('starts in MONITORING by default', () {
      final n = AppStateNotifier();
      expect(n.state, AppState.monitoring);
      expect(n.silentlyEscalating, isFalse);
      expect(n.history, isEmpty);
    });

    test('onDCSThresholdExceeded promotes monitoring → alertPending', () {
      final n = AppStateNotifier();
      n.onDCSThresholdExceeded();
      expect(n.state, AppState.alertPending);
      expect(n.alertCountdownStartedAt, isNotNull);
      expect(n.history.last.from, AppState.monitoring);
      expect(n.history.last.to,   AppState.alertPending);
    });

    test('onDCSThresholdExceeded also promotes elevated → alertPending', () {
      final n = AppStateNotifier();
      n.onElevatedSignal();
      expect(n.state, AppState.elevated);
      n.onDCSThresholdExceeded();
      expect(n.state, AppState.alertPending);
    });

    test('onManualTrigger fires from monitoring regardless of method', () {
      final n = AppStateNotifier();
      n.onManualTrigger(TriggerMethod.doubleTap);
      expect(n.state, AppState.alertPending);
      expect(n.history.last.cause, contains('DOUBLE_TAP'));
    });

    test('onManualTrigger is a no-op once already in SOS_ACTIVE', () {
      final n = AppStateNotifier();
      n.setRaw(AppState.sosActive);
      n.onManualTrigger(TriggerMethod.manual);
      expect(n.state, AppState.sosActive);
    });

    test('onCancelWithRealPIN clears countdown and returns to MONITORING', () {
      final n = AppStateNotifier();
      n.onDCSThresholdExceeded();
      expect(n.alertCountdownStartedAt, isNotNull);
      n.onCancelWithRealPIN();
      expect(n.state, AppState.monitoring);
      expect(n.alertCountdownStartedAt, isNull);
      expect(n.silentlyEscalating, isFalse);
    });

    test('onCancelWithDuressPIN flips silent flag (LP3)', () {
      final n = AppStateNotifier();
      n.onDCSThresholdExceeded();
      n.onCancelWithDuressPIN();
      // UI surface returns to monitoring…
      expect(n.state, AppState.monitoring);
      // …but the silent-escalation flag stays on for the dispatch layer.
      expect(n.silentlyEscalating, isTrue);
      expect(n.history.last.cause, contains('LP3'));
    });

    test('onAlertPendingExpired escalates alertPending → sosActive', () {
      final n = AppStateNotifier();
      n.setRaw(AppState.alertPending);
      n.onAlertPendingExpired();
      expect(n.state, AppState.sosActive);
    });

    test('onAlertPendingExpired is a no-op from monitoring', () {
      final n = AppStateNotifier();
      n.onAlertPendingExpired();
      expect(n.state, AppState.monitoring);
    });

    test('onTier1Acknowledged transitions sosActive → escalating only', () {
      final n = AppStateNotifier();
      // No-op from monitoring.
      n.onTier1Acknowledged();
      expect(n.state, AppState.monitoring);
      n.setRaw(AppState.sosActive);
      n.onTier1Acknowledged();
      expect(n.state, AppState.escalating);
    });

    test('onSosResolved → postIncident and clears silent flag', () {
      final n = AppStateNotifier();
      n.onDCSThresholdExceeded();
      n.onCancelWithDuressPIN();
      expect(n.silentlyEscalating, isTrue);
      n.setRaw(AppState.sosActive);
      n.onSosResolved();
      expect(n.state, AppState.postIncident);
      expect(n.silentlyEscalating, isFalse);
    });

    test('powerOff goes to IDLE from any non-idle state', () {
      final n = AppStateNotifier();
      n.setRaw(AppState.escalating);
      n.powerOff();
      expect(n.state, AppState.idle);
      // powerOn returns to monitoring.
      n.powerOn();
      expect(n.state, AppState.monitoring);
    });

    test('returnToMonitoring restores from postIncident → monitoring', () {
      final n = AppStateNotifier();
      n.setRaw(AppState.postIncident);
      n.returnToMonitoring();
      expect(n.state, AppState.monitoring);
    });

    test('debugFireAlertCountdown moves alertPending → sosActive', () async {
      final n = AppStateNotifier();
      n.onDCSThresholdExceeded();
      expect(n.state, AppState.alertPending);
      await n.debugFireAlertCountdown();
      expect(n.state, AppState.sosActive);
    });

    test('history records every transition with cause', () {
      final n = AppStateNotifier();
      n.onElevatedSignal();
      n.onDCSThresholdExceeded();
      n.onCancelWithRealPIN();
      expect(n.history, hasLength(3));
      expect(n.history.map((t) => t.to).toList(), [
        AppState.elevated,
        AppState.alertPending,
        AppState.monitoring,
      ]);
    });

    test('history bounded by AppStateNotifier.historyLimit', () {
      final n = AppStateNotifier();
      for (var i = 0; i < AppStateNotifier.historyLimit + 5; i++) {
        // toggle elevated <-> monitoring rapidly
        n.onElevatedSignal();
        n.onElevatedReset();
      }
      expect(n.history.length, AppStateNotifier.historyLimit);
    });

    test('TriggerMethod label coverage', () {
      expect(TriggerMethod.dcs.label,        'DCS_THRESHOLD');
      expect(TriggerMethod.manual.label,     'MANUAL');
      expect(TriggerMethod.fall.label,       'FALL_DETECTED');
      expect(TriggerMethod.doubleTap.label,  'DOUBLE_TAP');
      expect(TriggerMethod.voiceCue.label,   'VOICE_CUE');
      expect(TriggerMethod.external.label,   'EXTERNAL');
    });

    test('alertCountdown constant matches LP15 grace window', () {
      expect(AppStateNotifier.alertCountdown, const Duration(seconds: 15));
    });
  });
}
