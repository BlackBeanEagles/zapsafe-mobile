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
      expect(coord.shouldTrigger(0.65, alertThreshold: alert), isFalse,
          reason: 'quiet enough that a capture is unjustified');
    });

    test('fires at or above the v6 trigger (0.6535) raw scream', () {
      expect(coord.shouldTrigger(0.6535, alertThreshold: alert), isTrue);
      expect(coord.shouldTrigger(0.97, alertThreshold: alert), isTrue);
    });

    test('suppressed when the app is ALREADY escalating', () {
      // A capture takes ~3 s to answer, so once the fused score has crossed
      // the alert line the burst arrives too late to inform the decision.
      // Note this now compares the FUSED score, passed separately — the
      // trigger value is the scream probability and the two are no longer
      // the same quantity.
      expect(
          coord.shouldTrigger(0.95,
              alertThreshold: alert, fusedDanger: alert + 0.01),
          isFalse);
      expect(coord.shouldTrigger(0.95, alertThreshold: alert, fusedDanger: 0.0),
          isTrue);
    });

    test('the trigger is measured, not derived from fusion arithmetic', () {
      // It used to be 0.45 = audioWeight 0.5 x a confident scream 0.9.
      // Day 364D set audioWeight to 0, so that derivation is gone and a
      // scream no longer moves the fused score at all. 0.90 comes from the
      // measured per-window distribution on real media audio: it fires on
      // 3.2% of ambient windows against 12.5% of violent ones (3.97x),
      // where 0.80 would fire roughly every 18 s of ordinary television.
      // Day 368D (v6): 0.6535 matches v5's ambient firing rate (4.88% of
      // windows over all 800 XD-Violence test videos).
      expect(ViolenceBurstCoordinator.kTriggerThreshold, 0.6535);
    });

    test('a scream can still start an investigation after losing its vote',
        () {
      // The reachability point. The gate is now motion+scene; scene comes
      // from a burst; bursts came from audio. If audio could no longer
      // trigger a burst, scene would never populate and the gate would be
      // unreachable -- the Day 326 failure in a new shape.
      expect(coord.shouldTrigger(0.95, alertThreshold: alert), isTrue,
          reason: 'a weak detector can still be good enough to point the '
              'camera; a burst costs battery, not a false alarm');
    });
  });

  group('cooldown', () {
    test('a second burst is suppressed until the cooldown elapses', () async {
      expect(coord.shouldTrigger(0.95, alertThreshold: alert), isTrue);
      await coord.observe(_score(0.95), alertThreshold: alert);
      expect(coord.triggered, 1);

      // Immediately after, and just before the cooldown expires.
      expect(coord.shouldTrigger(0.95, alertThreshold: alert), isFalse);
      clock += ViolenceBurstCoordinator.kCooldownMs - 1;
      expect(coord.shouldTrigger(0.95, alertThreshold: alert), isFalse);

      clock += 1;
      expect(coord.shouldTrigger(0.95, alertThreshold: alert), isTrue);
    });

    test('suppressed triggers are counted, not silently dropped', () async {
      await coord.observe(_score(0.95), alertThreshold: alert);
      await coord.observe(_score(0.95), alertThreshold: alert);
      await coord.observe(_score(0.95), alertThreshold: alert);
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
      await coord.observe(_score(0.95), alertThreshold: alert);
      coord.reset();
      expect(coord.latestResult, isNull);
      expect(coord.shouldTrigger(0.95, alertThreshold: alert), isTrue,
          reason: 'reset ends the session, so the cooldown goes with it');
    });

    test('it reads the scream key from AUDIO — Day 364D moved the trigger',
        () async {
      // Until Day 364D this read `classScores['danger']` from the FUSION.
      // That was correct while scream carried weight 0.5 in the fusion; with
      // scream dropped to 0 the fused score no longer moves for audio at
      // all, so reading it there would mean the camera never investigates a
      // scream. The key-coercion hazard Day 335 found is unchanged: a
      // missing key silently reads 0 and nothing ever fires.
      await coord.observe(_score(0.95), alertThreshold: alert);
      expect(coord.triggered, 1);

      // An audio slot with no 'scream' key must NOT trigger — this is the
      // Day 335 bug shape, asserted against the new source of truth.
      final wrongKey = ViolenceBurstCoordinator(
        captureBurst: _noCamera, inferBurst: _neverCalled, now: () => clock);
      await wrongKey.observe(
        _scoreWithKeys({'safe': 0.05, 'danger': 0.95}),
        alertThreshold: alert,
      );
      expect(wrongKey.triggered, 0,
          reason: 'a high FUSED danger with no scream must not start a '
              'burst: the fused score is not the trigger any more, and by '
              'then the app is escalating anyway');
    });
  });
}

/// Day 364D: the burst now triggers on the RAW SCREAM probability, so the
/// driving value goes in the AUDIO slot. The fusion slot is left calm —
/// scream contributes 0 to it now, which is the whole point.
DCSScore _score(double screamProb) =>
    _scoreWithKeys({'safe': 1.0, 'danger': 0.0}, screamProb: screamProb);

DCSScore _scoreWithKeys(Map<String, double> classScores,
    {double screamProb = 0.0}) {
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
  final audio = InferenceResult(
    label: screamProb >= 0.5 ? 'scream' : 'calm',
    score: screamProb,
    classScores: {'scream': screamProb, 'calm': 1 - screamProb},
    latencyMs: 1,
    timestampMs: 0,
  );
  return DCSScore(
    timestampMs: 0,
    audio: audio,
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
