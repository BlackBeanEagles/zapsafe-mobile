import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/data/models/dcs_score.dart';
import 'package:zapsafe_mobile/data/models/inference_result.dart';
import 'package:zapsafe_mobile/data/models/trigger_event.dart';
import 'package:zapsafe_mobile/ml/inference/dcs_score_watcher.dart';

/// Builds a synthetic DCSScore whose fusion.classScores['scream'] equals
/// [screamProb]. The other slot values don't matter — the watcher only
/// reads the scream class probability.
DCSScore _scoreWith({required double screamProb, int ts = 0}) {
  final fusion = InferenceResult(
    label: 'scream',
    score: screamProb,
    classScores: {'scream': screamProb, 'normal': 1 - screamProb, 'shout': 0},
    latencyMs: 1,
    timestampMs: ts,
  );
  final neutral = InferenceResult(
    label: 'normal', score: 0.1, classScores: const {'normal': 0.1},
    latencyMs: 1, timestampMs: ts,
  );
  return DCSScore(
    timestampMs: ts,
    audio: neutral,
    motion: neutral,
    scene: neutral,
    fusion: fusion,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('thresholds', () {
    test('alert threshold is 0.75, auto-sos is 0.85, vote requires 3', () {
      expect(DCSScoreWatcher.alertThreshold, 0.75);
      expect(DCSScoreWatcher.autoSosThreshold, 0.85);
      expect(DCSScoreWatcher.requiredConsecutiveWindows, 3);
    });
  });

  group('vote progression', () {
    test('a single high window only increments the counter', () {
      final w = DCSScoreWatcher();
      final out = w.observe(_scoreWith(screamProb: 0.78));
      expect(out, isNull);
      expect(w.currentConsecutive, 1);
    });

    test('three consecutive high windows fire ALERT_PENDING', () {
      final w = DCSScoreWatcher();
      w.observe(_scoreWith(screamProb: 0.78, ts: 1));
      w.observe(_scoreWith(screamProb: 0.80, ts: 2));
      final out = w.observe(_scoreWith(screamProb: 0.76, ts: 3));
      expect(out, isNotNull);
      expect(out!.kind, TriggerKind.alertPending);
      expect(out.consecutiveWindows, 3);
      expect(out.passive, isTrue);
      expect(out.score.timestampMs, 3);
    });

    test('vote resets after firing — needs three fresh windows', () {
      final w = DCSScoreWatcher();
      w.observe(_scoreWith(screamProb: 0.8));
      w.observe(_scoreWith(screamProb: 0.8));
      w.observe(_scoreWith(screamProb: 0.8)); // fires
      expect(w.currentConsecutive, 0);
      // Next single high window should NOT immediately re-fire.
      final out = w.observe(_scoreWith(screamProb: 0.8));
      expect(out, isNull);
      expect(w.currentConsecutive, 1);
    });

    test('a below-threshold window resets the counter mid-vote', () {
      final w = DCSScoreWatcher();
      w.observe(_scoreWith(screamProb: 0.8));
      w.observe(_scoreWith(screamProb: 0.8));
      expect(w.currentConsecutive, 2);
      // Calm window resets.
      final calm = w.observe(_scoreWith(screamProb: 0.2));
      expect(calm, isNull);
      expect(w.currentConsecutive, 0);
    });

    test('exactly-at-threshold (0.75) counts toward the vote', () {
      final w = DCSScoreWatcher();
      w.observe(_scoreWith(screamProb: 0.75));
      w.observe(_scoreWith(screamProb: 0.75));
      final out = w.observe(_scoreWith(screamProb: 0.75));
      expect(out, isNotNull);
      expect(out!.kind, TriggerKind.alertPending);
    });

    test('just-below-threshold (0.749) does not advance the vote', () {
      final w = DCSScoreWatcher();
      w.observe(_scoreWith(screamProb: 0.749));
      w.observe(_scoreWith(screamProb: 0.749));
      w.observe(_scoreWith(screamProb: 0.749));
      expect(w.currentConsecutive, 0);
    });
  });

  group('auto-SOS bypass', () {
    test('a single 0.85 window fires AUTO_SOS immediately', () {
      final w = DCSScoreWatcher();
      final out = w.observe(_scoreWith(screamProb: 0.86, ts: 99));
      expect(out, isNotNull);
      expect(out!.kind, TriggerKind.autoSos);
      expect(out.consecutiveWindows, 0,
          reason: 'AUTO_SOS bypasses the vote entirely');
      expect(out.passive, isTrue);
      expect(out.score.timestampMs, 99);
    });

    test('AUTO_SOS clears the alert-vote counter', () {
      final w = DCSScoreWatcher();
      w.observe(_scoreWith(screamProb: 0.8));
      w.observe(_scoreWith(screamProb: 0.8));
      expect(w.currentConsecutive, 2);
      w.observe(_scoreWith(screamProb: 0.9)); // AUTO_SOS
      expect(w.currentConsecutive, 0);
    });

    test('exactly at 0.85 fires AUTO_SOS (inclusive)', () {
      final w = DCSScoreWatcher();
      final out = w.observe(_scoreWith(screamProb: 0.85));
      expect(out, isNotNull);
      expect(out!.kind, TriggerKind.autoSos);
    });
  });

  group('reset', () {
    test('reset clears the vote counter and last-fused', () {
      final w = DCSScoreWatcher();
      w.observe(_scoreWith(screamProb: 0.8));
      w.observe(_scoreWith(screamProb: 0.8));
      expect(w.currentConsecutive, 2);
      expect(w.lastFusedScream, closeTo(0.8, 1e-6));
      w.reset();
      expect(w.currentConsecutive, 0);
      expect(w.lastFusedScream, 0);
    });
  });

  group('watch() stream transform', () {
    test('produces a TriggerEvent for every threshold-crossing', () async {
      final w = DCSScoreWatcher();
      final source = Stream<DCSScore>.fromIterable([
        _scoreWith(screamProb: 0.2),  // none
        _scoreWith(screamProb: 0.8),  // vote 1
        _scoreWith(screamProb: 0.8),  // vote 2
        _scoreWith(screamProb: 0.8),  // ALERT
        _scoreWith(screamProb: 0.1),  // reset
        _scoreWith(screamProb: 0.9),  // AUTO_SOS
      ]);
      final events = await w.watch(source).toList();
      expect(events.length, 2);
      expect(events[0].kind, TriggerKind.alertPending);
      expect(events[1].kind, TriggerKind.autoSos);
    });
  });

  group('TriggerKind labels', () {
    test('every kind has a non-empty label + blurb', () {
      for (final k in TriggerKind.values) {
        expect(k.label, isNotEmpty);
        expect(k.blurb, isNotEmpty);
      }
    });

    test('label matches the backend-facing string', () {
      expect(TriggerKind.alertPending.label, 'ALERT_PENDING');
      expect(TriggerKind.autoSos.label, 'AUTO_SOS');
    });
  });
}
