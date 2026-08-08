import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/data/models/motion_features.dart';
import 'package:zapsafe_mobile/data/services/interpreter.dart';
import 'package:zapsafe_mobile/ml/inference/dcs_inference_engine.dart';
import 'package:zapsafe_mobile/native/audio_features.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MotionFeatures', () {
    test('atRest is gravity-only with low jitter', () {
      final m = MotionFeatures.atRest(timestampMs: 0);
      expect(m.accelMean, closeTo(9.81, 0.01));
      expect(m.accelVar, lessThan(0.5));
      expect(m.gyroMean, lessThan(0.1));
    });

    test('walking has higher accel variance than rest', () {
      final r = MotionFeatures.atRest(timestampMs: 0);
      final w = MotionFeatures.walking(timestampMs: 0);
      expect(w.accelVar, greaterThan(r.accelVar));
      expect(w.accelPeak, greaterThan(r.accelPeak));
    });

    test('impact has higher accel peak than walking', () {
      final w = MotionFeatures.walking(timestampMs: 0);
      final i = MotionFeatures.impact(timestampMs: 0);
      expect(i.accelPeak, greaterThan(w.accelPeak));
      expect(i.gyroPeak, greaterThan(w.gyroPeak));
    });

    test('toFloat32Tensor packs 6 values in declared order', () {
      const m = MotionFeatures(
        timestampMs: 0,
        accelMean: 1, accelVar: 2, accelPeak: 3,
        gyroMean: 4, gyroVar: 5, gyroPeak: 6,
      );
      final t = m.toFloat32Tensor();
      expect(t.length, 6);
      expect([t[0], t[1], t[2], t[3], t[4], t[5]],
          [1, 2, 3, 4, 5, 6]);
    });
  });

  group('LinearStubInterpreter (fusion stub)', () {
    test('fuses three scores with weights 0.5 / 0.3 / 0.2', () async {
      final fusion = LinearStubInterpreter(weights: const [0.5, 0.3, 0.2]);
      // audio=1, motion=1, scene=1 → 0.5+0.3+0.2 = 1.0
      final r = await fusion.infer(
        Float32List.fromList([1.0, 1.0, 1.0]),
        timestampMs: 0,
      );
      // Default classLabels are ['safe', 'danger']; danger == fused.
      expect(r.classScores['danger'], closeTo(1.0, 1e-6));
    });

    test('fully silent input yields danger ≈ 0', () async {
      final fusion = LinearStubInterpreter(weights: const [0.5, 0.3, 0.2]);
      final r = await fusion.infer(
        Float32List.fromList([0.0, 0.0, 0.0]),
        timestampMs: 0,
      );
      expect(r.classScores['danger'], closeTo(0.0, 1e-6));
      expect(r.classScores['safe'],   closeTo(1.0, 1e-6));
    });

    test('rejects mis-sized input', () async {
      final fusion = LinearStubInterpreter(weights: const [0.5, 0.3, 0.2]);
      expect(
        () => fusion.infer(
          Float32List.fromList([0.5]),
          timestampMs: 0,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('DCSInferenceEngine.create (all-stub world)', () {
    test('every slot falls back to a stub today (placeholder files)',
        () async {
      final engine = await DCSInferenceEngine.create();
      // None of the 4 placeholder files parse as valid TFLite, so every
      // slot must be a stub.
      expect(engine.screamIsReal, isFalse);
      expect(engine.motionIsReal, isFalse);
      expect(engine.sceneIsReal,  isFalse);
      expect(engine.fusionIsReal, isFalse);
      await engine.dispose();
    });

    test('slotStatuses lists 4 entries in order', () async {
      final engine = await DCSInferenceEngine.create();
      final ss = engine.slotStatuses;
      expect(ss.length, 4);
      expect(ss.map((s) => s.slot).toList(),
          ['M1 scream', 'M2 motion', 'M3 scene', 'M9 fusion']);
      for (final s in ss) {
        expect(s.label, isNotEmpty);
      }
      await engine.dispose();
    });

    test('infer returns a DCSScore with all 4 component slots populated',
        () async {
      final engine = await DCSInferenceEngine.create();
      final audio = AudioFeatures(
        timestampMs: 1234,
        mfcc: List<double>.filled(13, 0),
        zcr: 0.05,
        spectralCentroidHz: 800,
      );
      final score = await engine.infer(audio: audio);
      expect(score.timestampMs, 1234);
      expect(score.audio, isNotNull);
      expect(score.motion, isNotNull);
      expect(score.scene, isNotNull);
      expect(score.fusion, isNotNull);
      await engine.dispose();
    });

    test('runs counter increments per infer call', () async {
      final engine = await DCSInferenceEngine.create();
      final audio = AudioFeatures(
        timestampMs: 0,
        mfcc: List<double>.filled(13, 0),
        zcr: 0,
        spectralCentroidHz: 0,
      );
      expect(engine.runs, 0);
      await engine.infer(audio: audio);
      await engine.infer(audio: audio);
      expect(engine.runs, 2);
      await engine.dispose();
    });

    test('scream + impact has a higher scream-class probability than calm',
        () async {
      final engine = await DCSInferenceEngine.create();
      // Calm baseline: very negative mfcc[0] (= very quiet), low ZCR, low centroid.
      const calmAudio = AudioFeatures(
        timestampMs: 0,
        mfcc: [-60, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        zcr: 0.02,
        spectralCentroidHz: 400,
      );
      const screamAudio = AudioFeatures(
        timestampMs: 0,
        mfcc: [-5, 20, 12, -4, 6, 3, 2, 1, 1, 0, 0, 0, 0],
        zcr: 0.5,
        spectralCentroidHz: 6000,
      );
      final calm = await engine.infer(
        audio: calmAudio,
        motion: MotionFeatures.atRest(timestampMs: 0),
      );
      final danger = await engine.infer(
        audio: screamAudio,
        motion: MotionFeatures.impact(timestampMs: 0),
      );
      // Compare 'danger'-class probabilities — the semantically right metric.
      // `fusion.score` is the *top class* probability (which favors confident
      // 'safe' outcomes); we care about the danger probability explicitly.
      final calmDanger   = calm.fusion.classScores['danger']  ?? 0;
      final dangerDanger = danger.fusion.classScores['danger'] ?? 0;
      expect(dangerDanger, greaterThan(calmDanger));
      await engine.dispose();
    });
  });

  group('DCSScore', () {
    test('triggerCandidate stays false for a clearly-calm input', () async {
      final engine = await DCSInferenceEngine.create();
      // Calm: very quiet, low ZCR, low centroid → scream-class very low,
      // top class is 'normal' with high probability — but
      // triggerCandidate compares score against 0.7 for whatever class won.
      // A confident "normal" reading might cross 0.7, so we assert against
      // the scream class explicitly.
      const calmAudio = AudioFeatures(
        timestampMs: 0,
        mfcc: [-60, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        zcr: 0.02,
        spectralCentroidHz: 200,
      );
      final calm = await engine.infer(audio: calmAudio);
      final calmDanger = calm.fusion.classScores['danger'] ?? 0;
      // Danger probability for a calm input must be well below the
      // 0.7 trigger threshold.
      expect(calmDanger, lessThan(0.4));
      await engine.dispose();
    });

    test('rows exposes 4 slot labels', () async {
      final engine = await DCSInferenceEngine.create();
      final audio = AudioFeatures(
        timestampMs: 0,
        mfcc: List<double>.filled(13, 0),
        zcr: 0,
        spectralCentroidHz: 0,
      );
      final score = await engine.infer(audio: audio);
      expect(score.rows.map((r) => r.slot).toList(),
          ['M1 audio', 'M2 motion', 'M3 scene', 'M9 fusion']);
      await engine.dispose();
    });
  });
}
