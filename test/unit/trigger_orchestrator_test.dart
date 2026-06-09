// Day 39 — TriggerOrchestrator wiring tests.
//
// All pure Dart — no Riverpod, no plugins. We construct an
// AppStateNotifier directly, build an orchestrator over it, and
// dispatch synthetic events through the public dispatch* surface.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/data/models/app_state.dart';
import 'package:zapsafe_mobile/data/models/dcs_score.dart';
import 'package:zapsafe_mobile/data/models/fall_event.dart';
import 'package:zapsafe_mobile/data/models/inference_result.dart';
import 'package:zapsafe_mobile/data/models/trigger_event.dart';
import 'package:zapsafe_mobile/data/services/pin_policy.dart';
import 'package:zapsafe_mobile/domain/integration/trigger_orchestrator.dart';
import 'package:zapsafe_mobile/domain/providers/app_state_provider.dart';

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
    score: DCSScore(
      timestampMs: 0,
      audio: fusion,
      fusion: fusion,
    ),
    passive: true,
    consecutiveWindows: kind == TriggerKind.alertPending ? 3 : 0,
    timestampMs: 0,
  );
}

FallEvent _fall() => const FallEvent(
      timestampMs: 0,
      peakAccelMagnitude: 28.4,
      freefallDurationMs: 320,
    );

void main() {
  group('AppStateNotifier.onAutoSos', () {
    test('jumps monitoring → sosActive and skips countdown', () {
      final n = AppStateNotifier();
      n.onAutoSos();
      expect(n.state, AppState.sosActive);
      expect(n.alertCountdownStartedAt, isNull);
    });

    test('cancels an in-flight alert countdown when invoked', () {
      final n = AppStateNotifier();
      n.onDCSThresholdExceeded();
      expect(n.alertCountdownStartedAt, isNotNull);
      n.onAutoSos();
      expect(n.state, AppState.sosActive);
      expect(n.alertCountdownStartedAt, isNull);
    });

    test('no-op when in IDLE — dispatch path is dormant', () {
      final n = AppStateNotifier();
      n.powerOff();
      n.onAutoSos();
      expect(n.state, AppState.idle);
    });

    test('no-op when already SOS_ACTIVE / ESCALATING', () {
      final n = AppStateNotifier();
      n.setRaw(AppState.escalating);
      final priorHistory = n.history.length;
      n.onAutoSos();
      expect(n.state, AppState.escalating);
      expect(n.history.length, priorHistory); // no transition logged
    });
  });

  group('TriggerOrchestrator · dispatch routing', () {
    test('ALERT_PENDING TriggerEvent → onDCSThresholdExceeded', () {
      final n = AppStateNotifier();
      final o = TriggerOrchestrator(notifier: n);
      o.dispatchDcs(_dcsEvent(TriggerKind.alertPending, scream: 0.78));
      expect(n.state, AppState.alertPending);
      expect(o.dcsAlertCount, 1);
      expect(o.history.last.source, 'DCS');
      expect(o.history.last.label, 'ALERT_PENDING');
    });

    test('AUTO_SOS TriggerEvent → onAutoSos (skips countdown · LP25)', () {
      final n = AppStateNotifier();
      final o = TriggerOrchestrator(notifier: n);
      o.dispatchDcs(_dcsEvent(TriggerKind.autoSos, scream: 0.92));
      expect(n.state, AppState.sosActive);
      expect(n.alertCountdownStartedAt, isNull);
      expect(o.dcsAutoSosCount, 1);
    });

    test('FallEvent → onManualTrigger(TriggerMethod.fall)', () {
      final n = AppStateNotifier();
      final o = TriggerOrchestrator(notifier: n);
      o.dispatchFall(_fall());
      expect(n.state, AppState.alertPending);
      expect(o.fallCount, 1);
      expect(n.history.last.cause, contains('fall'));
    });

    test('manual dispatch path increments manual counter', () {
      final n = AppStateNotifier();
      final o = TriggerOrchestrator(notifier: n);
      o.dispatchManual(TriggerMethod.manual);
      expect(o.manualCount, 1);
      expect(n.state, AppState.alertPending);
    });

    test('totalDispatched sums all four counters', () {
      final n = AppStateNotifier();
      final o = TriggerOrchestrator(notifier: n);
      o.dispatchDcs(_dcsEvent(TriggerKind.alertPending));
      o.dispatchDcs(_dcsEvent(TriggerKind.autoSos));
      o.dispatchFall(_fall());
      o.dispatchManual(TriggerMethod.manual);
      expect(o.totalDispatched, 4);
    });

    test('history bounded by historyLimit', () {
      final n = AppStateNotifier();
      final o = TriggerOrchestrator(notifier: n);
      for (var i = 0; i < TriggerOrchestrator.historyLimit + 8; i++) {
        o.dispatchManual(TriggerMethod.manual);
      }
      expect(o.history.length, TriggerOrchestrator.historyLimit);
    });

    test('AUTO_SOS during alertPending cancels timer + escalates', () {
      final n = AppStateNotifier();
      final o = TriggerOrchestrator(notifier: n);
      o.dispatchDcs(_dcsEvent(TriggerKind.alertPending));
      expect(n.alertCountdownStartedAt, isNotNull);
      o.dispatchDcs(_dcsEvent(TriggerKind.autoSos));
      expect(n.state, AppState.sosActive);
      expect(n.alertCountdownStartedAt, isNull);
    });
  });

  group('TriggerOrchestrator · attach() stream subscriptions', () {
    test('subscribes to both upstream streams idempotently', () async {
      final n = AppStateNotifier();
      final o = TriggerOrchestrator(notifier: n);
      final dcs  = StreamController<TriggerEvent>.broadcast();
      final fall = StreamController<FallEvent>.broadcast();
      addTearDown(() async {
        await o.dispose();
        await dcs.close();
        await fall.close();
      });

      o.attach(dcsEvents: dcs.stream, fallEvents: fall.stream);
      expect(o.isAttached, isTrue);

      o.attach(dcsEvents: dcs.stream, fallEvents: fall.stream); // 2nd call
      expect(o.isAttached, isTrue);

      dcs.add(_dcsEvent(TriggerKind.alertPending));
      fall.add(_fall());
      await Future<void>.delayed(Duration.zero);

      expect(o.dcsAlertCount, 1);
      expect(o.fallCount, 1);
    });

    test('detach() cancels subscriptions but preserves counters', () async {
      final n = AppStateNotifier();
      final o = TriggerOrchestrator(notifier: n);
      final dcs  = StreamController<TriggerEvent>.broadcast();
      final fall = StreamController<FallEvent>.broadcast();
      addTearDown(() async {
        await dcs.close();
        await fall.close();
      });
      o.attach(dcsEvents: dcs.stream, fallEvents: fall.stream);
      dcs.add(_dcsEvent(TriggerKind.alertPending));
      await Future<void>.delayed(Duration.zero);
      await o.detach();
      // Post-detach events must NOT advance the counters.
      dcs.add(_dcsEvent(TriggerKind.autoSos));
      await Future<void>.delayed(Duration.zero);
      expect(o.dcsAlertCount, 1);
      expect(o.dcsAutoSosCount, 0);
      expect(o.isAttached, isFalse);
    });
  });

  group('PinPolicy', () {
    test('classify returns real / duress / null', () {
      final p = PinPolicy();
      expect(p.classify('1234'), PinMatch.real);
      expect(p.classify('9999'), PinMatch.duress);
      expect(p.classify('0000'), isNull);
      expect(p.classify(''),     isNull);
    });

    test('is{Real,Duress}Pin helpers agree with classify', () {
      final p = PinPolicy();
      expect(p.isRealPin('1234'), isTrue);
      expect(p.isRealPin('9999'), isFalse);
      expect(p.isDuressPin('9999'), isTrue);
      expect(p.isDuressPin('1234'), isFalse);
    });

    test('PinMatch labels', () {
      expect(PinMatch.real.label,   'REAL_PIN');
      expect(PinMatch.duress.label, 'DURESS_PIN');
    });

    test('demo constants exposed for the screen', () {
      expect(PinPolicy.demoRealPin,   '1234');
      expect(PinPolicy.demoDuressPin, '9999');
    });
  });

  group('PIN cancel flow · AppStateNotifier integration', () {
    test('real PIN cancel clears countdown + silent flag', () {
      final n = AppStateNotifier();
      n.onDCSThresholdExceeded();
      // duress first, then real — real should clear the silent flag.
      n.onCancelWithDuressPIN();
      expect(n.silentlyEscalating, isTrue);
      n.onDCSThresholdExceeded();
      n.onCancelWithRealPIN();
      expect(n.silentlyEscalating, isFalse);
      expect(n.state, AppState.monitoring);
    });

    test('duress PIN sets LP3 flag and visibly returns to monitoring', () {
      final n = AppStateNotifier();
      n.onDCSThresholdExceeded();
      n.onCancelWithDuressPIN();
      expect(n.state, AppState.monitoring);
      expect(n.silentlyEscalating, isTrue);
    });
  });
}
