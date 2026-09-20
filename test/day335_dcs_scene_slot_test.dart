import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/data/models/inference_result.dart';
import 'package:zapsafe_mobile/data/services/interpreter.dart';
import 'package:zapsafe_mobile/ml/inference/dcs_inference_engine.dart';
import 'package:zapsafe_mobile/native/audio_features.dart';

/// Day 335 — `m3_violence_temporal` feeding the DCS scene slot.
///
/// These run the **real** [DCSInferenceEngine.infer] path, not arithmetic
/// mirrored in the test, because `fromInterpreters` accepts stubs and needs
/// no native TFLite. So the staleness rule and the override plumbing are
/// genuinely exercised here rather than described.
AudioFeatures _audio(int ts) => AudioFeatures(
      timestampMs: ts,
      mfcc: const [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      zcr: 0.1,
      spectralCentroidHz: 1500,
    );

InferenceResult _burst(double violence, int ts) => InferenceResult(
      label: violence >= 0.5 ? 'violence' : 'no_violence',
      score: violence >= 0.5 ? violence : 1.0 - violence,
      classScores: {'violence': violence, 'no_violence': 1.0 - violence},
      latencyMs: 1,
      timestampMs: ts,
    );

DCSInferenceEngine _engine() => DCSInferenceEngine.fromInterpreters(
      scream: const FixedStubInterpreter(
        modelLabel: 'stub-scream',
        expectedInputSize: 15,
        classLabels: ['normal', 'scream'],
        label: 'normal',
        score: 0.1,
      ),
      motion: const FixedStubInterpreter(
        modelLabel: 'stub-motion',
        expectedInputSize: 6,
        classLabels: ['normal', 'unusual', 'fall'],
        label: 'normal',
        score: 0.15,
      ),
      scene: const FixedStubInterpreter(
        modelLabel: 'stub-scene',
        expectedInputSize: 8,
        classLabels: ['indoor', 'outdoor', 'transit'],
        label: 'indoor',
        score: 0.25,
      ),
      fusion: LinearStubInterpreter(
        weights: const [0.5, 0.3, 0.2],
        classLabels: const ['safe', 'danger'],
      ),
    );

void main() {
  group('the scene slot now carries a real danger probability', () {
    test('a fresh burst reaches the fused score', () async {
      final engine = _engine();
      const ts = 1000000;
      final withBurst = await engine.infer(
        audio: _audio(ts),
        sceneResultOverride: _burst(1.0, ts),
      );
      final without = await engine.infer(audio: _audio(ts));

      // sceneWeight is 0.2, so a saturated burst adds exactly that.
      expect(withBurst.fusion.classScores['danger']! - without.fusion.classScores['danger']!,
          closeTo(0.2, 1e-6),
          reason: 'before Day 335 this difference was 0 — the slot stubbed '
              'out and contributed nothing no matter what happened');
    });

    test('the burst probability is read, not the thresholded label', () async {
      // M3 fires on 13% of NonFight clips at its 0.5 midpoint. Reading the
      // label would make every one of those a full-weight danger signal;
      // reading the probability scales the contribution instead.
      final engine = _engine();
      const ts = 1000000;
      final base = (await engine.infer(audio: _audio(ts)))
          .fusion
          .classScores['danger']!;
      for (final p in [0.0, 0.25, 0.5, 0.75, 1.0]) {
        final r = await engine.infer(
          audio: _audio(ts),
          sceneResultOverride: _burst(p, ts),
        );
        expect(r.fusion.classScores['danger']! - base, closeTo(0.2 * p, 1e-6),
            reason: 'violence=$p must contribute 0.2*$p, not all-or-nothing');
      }
    });
  });

  group('staleness — the rule that keeps an old burst from escalating', () {
    test('a burst inside the window counts', () async {
      final engine = _engine();
      const ts = 1000000;
      final r = await engine.infer(
        audio: _audio(ts),
        sceneResultOverride:
            _burst(1.0, ts - DCSInferenceEngine.kSceneMaxAgeMs + 1),
      );
      final base = (await engine.infer(audio: _audio(ts)))
          .fusion
          .classScores['danger']!;
      expect(r.fusion.classScores['danger']! - base, closeTo(0.2, 1e-6));
    });

    test('a burst past the window is discarded, not merely decayed', () async {
      // The important property: an old violence reading contributes exactly
      // nothing, rather than a reduced amount. Without this, one burst would
      // keep inflating the DCS score for as long as the app stayed up.
      final engine = _engine();
      const ts = 1000000;
      final stale = await engine.infer(
        audio: _audio(ts),
        sceneResultOverride:
            _burst(1.0, ts - DCSInferenceEngine.kSceneMaxAgeMs - 1),
      );
      final base = (await engine.infer(audio: _audio(ts)))
          .fusion
          .classScores['danger']!;
      expect(stale.fusion.classScores['danger']!, closeTo(base, 1e-9),
          reason: 'a stale burst must fall back to the stub, contributing 0');
    });

    test('a burst from the future is bounded too', () async {
      // Clock skew between the audio timestamp and the burst timestamp can
      // go either way, so the check is on absolute difference. A burst
      // dated far ahead is as untrustworthy as one far behind.
      final engine = _engine();
      const ts = 1000000;
      final future = await engine.infer(
        audio: _audio(ts),
        sceneResultOverride:
            _burst(1.0, ts + DCSInferenceEngine.kSceneMaxAgeMs + 1),
      );
      final base = (await engine.infer(audio: _audio(ts)))
          .fusion
          .classScores['danger']!;
      expect(future.fusion.classScores['danger']!, closeTo(base, 1e-9));
    });

    test('the window is 30 s, long enough to outlive a burst', () {
      // A burst is ~2.4 s of capture plus 16 encoder passes. The window has
      // to cover that and the audio windows around it without letting a
      // reading persist into an unrelated situation.
      expect(DCSInferenceEngine.kSceneMaxAgeMs, 30000);
    });
  });

  group("'outdoor' is gone as a danger class", () {
    test('a confident indoor/outdoor reading contributes nothing', () async {
      // scene_analyzer_v1's labels are indoor/outdoor/transit. None is a
      // danger class — being outdoors is not evidence of danger — and
      // treating 'outdoor' as one would have let an ordinary walk outside
      // push the fused score up. That slot stubbed to 0 in practice, so
      // nothing regresses by dropping it.
      final engine = _engine();
      const ts = 1000000;
      final r = await engine.infer(
        audio: _audio(ts),
        sceneResultOverride: const InferenceResult(
          label: 'outdoor',
          score: 0.99,
          classScores: {'indoor': 0.005, 'outdoor': 0.99, 'transit': 0.005},
          latencyMs: 1,
          timestampMs: ts,
        ),
      );
      final base = (await engine.infer(audio: _audio(ts)))
          .fusion
          .classScores['danger']!;
      expect(r.fusion.classScores['danger']!, closeTo(base, 1e-9),
          reason: "only 'violence' counts now");
    });
  });

  group('Day 335 — the watcher reads a key the fusion never produces', () {
    test('fusion classScores are safe/danger, with no "scream" key', () async {
      // DCSScoreWatcher.observe() does:
      //     final scream = score.fusion.classScores['scream'] ?? 0;
      // but DCSInferenceEngine.create() builds the fusion stub with
      // classLabels ['safe', 'danger'], so that lookup is ALWAYS null -> 0,
      // and neither alertThreshold (0.75) nor autoSosThreshold (0.85) can
      // ever be crossed.
      //
      // Day 327 made the fused score reachable by wiring motion. This is a
      // second, independent break in the same escalation path: the score is
      // now reachable and the thing reading it is looking at the wrong key.
      final engine = _engine();
      const ts = 1000000;
      final r = await engine.infer(
        audio: _audio(ts),
        sceneResultOverride: _burst(1.0, ts),
      );
      expect(r.fusion.classScores.keys.toSet(), {'safe', 'danger'});
      expect(r.fusion.classScores['scream'], isNull,
          reason: 'this null is what DCSScoreWatcher coerces to 0');
    });

    test('a maximal danger reading still leaves the watcher key at 0',
        () async {
      final engine = _engine();
      const ts = 1000000;
      // Saturate every modality the stubs allow.
      final r = await engine.infer(
        audio: _audio(ts),
        motionResultOverride: const InferenceResult(
          label: 'fall',
          score: 1.0,
          classScores: {'fall': 1.0, 'normal': 0.0},
          latencyMs: 1,
          timestampMs: ts,
        ),
        sceneResultOverride: _burst(1.0, ts),
      );
      // Danger is genuinely high...
      expect(r.fusion.classScores['danger'], greaterThan(0.49));
      // ...and the value the watcher actually reads is still zero.
      expect(r.fusion.classScores['scream'] ?? 0, 0,
          reason: 'escalation cannot fire while the watcher reads this key');
    });
  });
}
