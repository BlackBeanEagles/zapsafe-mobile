import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/data/models/dcs_score.dart';
import 'package:zapsafe_mobile/data/models/inference_result.dart';
import 'package:zapsafe_mobile/data/services/violence_burst_coordinator.dart';
import 'package:zapsafe_mobile/ml/inference/dcs_score_watcher.dart';

/// Day 337 — when a camera burst is and is not justified.
///
/// The decision logic is tested through [ViolenceBurstCoordinator
/// .shouldTrigger], which is deliberately separated from `observe()` so it
/// can be exercised without a camera. A burst points a lens at the user's
/// surroundings and costs seconds of capture, so "when" deserves tests of
/// its own rather than being an implicit consequence of the wiring.
void main() {
  late int clock;
  late ViolenceBurstCoordinator coord;

  const alert = DCSScoreWatcher.alertThreshold;

  setUp(() {
    clock = 10000000;
    coord = ViolenceBurstCoordinator(
      captureBurst: _noCamera,
      inferBurst: _neverCalled,
      now: () => clock,
    );
  });

  group('the trigger band', () {
    test('nothing below the threshold', () {
      expect(coord.shouldTrigger(0.0, alertThreshold: alert), isFalse);
      expect(coord.shouldTrigger(0.44, alertThreshold: alert), isFalse,
          reason: 'quiet enough that a capture is unjustified');
    });

    test('fires inside [0.45, alertThreshold)', () {
      expect(coord.shouldTrigger(0.45, alertThreshold: alert), isTrue);
      expect(coord.shouldTrigger(0.60, alertThreshold: alert), isTrue);
      expect(coord.shouldTrigger(0.749, alertThreshold: alert), isTrue);
    });

    test('NOT above the alert threshold — a burst would arrive too late', () {
      // Above 0.75 the app is already escalating. A capture that takes ~3 s
      // to answer cannot inform that decision, so spending the camera and
      // the battery on it is pure cost.
      expect(coord.shouldTrigger(0.75, alertThreshold: alert), isFalse);
      expect(coord.shouldTrigger(0.95, alertThreshold: alert), isFalse);
    });

    test('0.45 is where an uncorroborated scream lands', () {
      // audioWeight 0.5 x a confident scream 0.9 = 0.45, with motion and
      // scene silent. That is precisely the case that should go looking for
      // more evidence, which is why the threshold sits there and not higher.
      const screamAlone = 0.5 * 0.9;
      expect(screamAlone, closeTo(ViolenceBurstCoordinator.kTriggerThreshold,
          1e-9));
      expect(coord.shouldTrigger(screamAlone, alertThreshold: alert), isTrue);
    });

    test('the band sits strictly below the alert threshold', () {
      expect(ViolenceBurstCoordinator.kTriggerThreshold, lessThan(alert));
    });
  });

  group('cooldown', () {
    test('a second burst is suppressed until the cooldown elapses', () async {
      expect(coord.shouldTrigger(0.6, alertThreshold: alert), isTrue);
      await coord.observe(_score(0.6), alertThreshold: alert);
      expect(coord.triggered, 1);

      // Immediately after, and just before the cooldown expires.
      expect(coord.shouldTrigger(0.6, alertThreshold: alert), isFalse);
      clock += ViolenceBurstCoordinator.kCooldownMs - 1;
      expect(coord.shouldTrigger(0.6, alertThreshold: alert), isFalse);

      clock += 1;
      expect(coord.shouldTrigger(0.6, alertThreshold: alert), isTrue);
    });

    test('suppressed triggers are counted, not silently dropped', () async {
      await coord.observe(_score(0.6), alertThreshold: alert);
      await coord.observe(_score(0.6), alertThreshold: alert);
      await coord.observe(_score(0.6), alertThreshold: alert);
      expect(coord.triggered, 1);
      expect(coord.suppressedByCooldown, 2,
          reason: 'a sustained above-threshold stretch must not burst '
              'continuously, and the fact that it tried should be visible');
    });

    test('a below-band score does not count as suppressed', () async {
      await coord.observe(_score(0.1), alertThreshold: alert);
      expect(coord.triggered, 0);
      expect(coord.suppressedByCooldown, 0);
      expect(coord.suppressedInFlight, 0);
    });
  });

  group('result handling', () {
    test('latestResult is null until a burst completes', () {
      expect(coord.latestResult, isNull);
    });

    test('reset clears the cached burst and the cooldown', () async {
      await coord.observe(_score(0.6), alertThreshold: alert);
      coord.reset();
      expect(coord.latestResult, isNull);
      expect(coord.shouldTrigger(0.6, alertThreshold: alert), isTrue,
          reason: 'reset ends the session, so the cooldown goes with it');
    });

    test('it reads the danger key, matching the Day 335 fusion fix', () async {
      // The fusion emits {'safe', 'danger'}. Reading 'scream' here would
      // reproduce exactly the bug Day 335 found in DCSScoreWatcher, where a
      // nonexistent key coerced to 0 and nothing ever fired.
      await coord.observe(_score(0.6), alertThreshold: alert);
      expect(coord.triggered, 1);

      final wrongKey = ViolenceBurstCoordinator(
        captureBurst: _noCamera, inferBurst: _neverCalled, now: () => clock);
      await wrongKey.observe(
        _scoreWithKeys({'safe': 0.4, 'scream': 0.6}),
        alertThreshold: alert,
      );
      expect(wrongKey.triggered, 0,
          reason: 'no danger key means no danger — this asserts the '
              'coordinator is reading the key the fusion actually emits');
    });
  });
}

DCSScore _score(double danger) =>
    _scoreWithKeys({'safe': 1 - danger, 'danger': danger});

DCSScore _scoreWithKeys(Map<String, double> classScores) {
  final fusion = InferenceResult(
    label: 'danger',
    score: classScores.values.reduce((a, b) => a > b ? a : b),
    classScores: classScores,
    latencyMs: 1,
    timestampMs: 0,
  );
  const neutral = InferenceResult(
    label: 'normal',
    score: 0.1,
    classScores: {'normal': 0.1},
    latencyMs: 1,
    timestampMs: 0,
  );
  return DCSScore(
    timestampMs: 0,
    audio: neutral,
    motion: neutral,
    scene: neutral,
    fusion: fusion,
  );
}

/// The capture path needs a real camera and a native interpreter, neither of
/// which `flutter test` has. These stand in so the *decision* logic — which
/// is what this file is about — can be exercised.
///
/// `captureBurst` returning null is also a real production case (permission
/// not granted, no camera present), so this doubles as the failure path:
/// the coordinator must still consume the trigger and start its cooldown
/// rather than retrying every window against a camera that will not answer.
Future<List<List<int>>?> _noCamera({required int count}) async => null;

Future<InferenceResult> _neverCalled(List<List<int>> frames,
        {required int timestampMs}) async =>
    throw StateError('not reached: captureBurst returns null');
