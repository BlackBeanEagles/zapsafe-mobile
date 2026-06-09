import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/data/models/inference_result.dart';
import 'package:zapsafe_mobile/data/models/motion_features.dart';
import 'package:zapsafe_mobile/data/models/scene_features.dart';
import 'package:zapsafe_mobile/data/services/heuristic_detection_engine.dart';
import 'package:zapsafe_mobile/data/services/heuristic_motion_detector.dart';
import 'package:zapsafe_mobile/data/services/heuristic_scene_detector.dart';
import 'package:zapsafe_mobile/data/services/heuristic_scream_detector.dart';
import 'package:zapsafe_mobile/data/services/phone_capability_detector.dart';
import 'package:zapsafe_mobile/native/audio_features.dart';

void main() {
  // ── HeuristicScreamDetector ────────────────────────────────────────────────
  group('HeuristicScreamDetector', () {
    const detector = HeuristicScreamDetector();
    final ts = DateTime.now().millisecondsSinceEpoch;

    test('modelLabel is heuristic-scream-v1', () {
      expect(detector.modelLabel, 'heuristic-scream-v1');
    });

    test('expectedInputSize is 15', () {
      expect(detector.expectedInputSize, 15);
    });

    test('classLabels contains normal, shout, scream', () {
      expect(detector.classLabels, containsAll(['normal', 'shout', 'scream']));
    });

    test('safe audio → normal label, scream score low', () async {
      final feat = AudioFeatures(
        timestampMs: ts,
        mfcc: List.generate(13, (i) => i == 0 ? -45.0 : 0.0),
        zcr: 0.05,
        spectralCentroidHz: 800.0,
      );
      final result = await detector.infer(feat.toFloat32Tensor(), timestampMs: ts);
      expect(result.label, 'normal');
      expect((result.classScores['scream'] ?? 0.0),
          lessThan(InferenceResult.confidenceThreshold));
    });

    test('scream audio (high energy + zcr + centroid) → scream label, high score', () async {
      final feat = AudioFeatures(
        timestampMs: ts,
        mfcc: List.generate(13, (i) => i == 0 ? -10.0 : 0.0),
        zcr: 0.25,
        spectralCentroidHz: 3200.0,
      );
      final result = await detector.infer(feat.toFloat32Tensor(), timestampMs: ts);
      expect(result.label, 'scream');
      expect(result.score, greaterThanOrEqualTo(0.85));
      expect(result.isConfident, isTrue);
    });

    test('missing input throws ArgumentError', () {
      expect(
        () => detector.infer(
          Float32List(5),
          timestampMs: ts,
        ),
        throwsArgumentError,
      );
    });

    test('copyWith changes threshold', () {
      final tuned = detector.copyWith(centroidThreshold: 5000.0);
      expect(tuned.expectedInputSize, 15);
    });

    test('dispose completes without error', () async {
      await expectLater(detector.dispose(), completes);
    });
  });

  // ── HeuristicMotionDetector ────────────────────────────────────────────────
  group('HeuristicMotionDetector', () {
    const detector = HeuristicMotionDetector();

    test('modelLabel is heuristic-motion-v1', () {
      expect(detector.modelLabel, 'heuristic-motion-v1');
    });

    test('expectedInputSize is 6', () {
      expect(detector.expectedInputSize, 6);
    });

    test('at-rest features → normal label', () async {
      final feat = MotionFeatures.atRest();
      final result = await detector.infer(
        feat.toFloat32Tensor(),
        timestampMs: feat.timestampMs,
      );
      expect(result.label, 'normal');
      expect((result.classScores['threat'] ?? 0.0),
          lessThan(InferenceResult.confidenceThreshold));
    });

    test('impact features → threat, isConfident true', () async {
      final feat = MotionFeatures.impact();
      final result = await detector.infer(
        feat.toFloat32Tensor(),
        timestampMs: feat.timestampMs,
      );
      expect(result.label, 'threat');
      expect(result.isConfident, isTrue);
    });

    test('walking features → normal label', () async {
      final feat = MotionFeatures.walking();
      final result = await detector.infer(
        feat.toFloat32Tensor(),
        timestampMs: feat.timestampMs,
      );
      expect(result.label, 'normal');
    });

    test('score is in [0, 0.95]', () async {
      final feat = MotionFeatures.impact();
      final result = await detector.infer(
        feat.toFloat32Tensor(),
        timestampMs: feat.timestampMs,
      );
      expect(result.score, lessThanOrEqualTo(0.95));
      expect(result.score, greaterThanOrEqualTo(0.0));
    });

    test('missing input throws ArgumentError', () {
      expect(
        () => detector.infer(Float32List(3), timestampMs: 0),
        throwsArgumentError,
      );
    });
  });

  // ── HeuristicSceneDetector ─────────────────────────────────────────────────
  group('HeuristicSceneDetector', () {
    const detector = HeuristicSceneDetector();

    test('modelLabel is heuristic-scene-v1', () {
      expect(detector.modelLabel, 'heuristic-scene-v1');
    });

    test('expectedInputSize is 8', () {
      expect(detector.expectedInputSize, 8);
    });

    test('well-lit scene → safe label, low threat score', () async {
      final feat = SceneFeatures.wellLit();
      final result = await detector.infer(
        feat.toFloat32Tensor(),
        timestampMs: feat.timestampMs,
      );
      expect(result.label, 'safe');
      // classScores['threat'] must be below confident threshold
      expect((result.classScores['threat'] ?? 0.0),
          lessThan(InferenceResult.confidenceThreshold));
    });

    test('dark scene → threat, isConfident true', () async {
      final feat = SceneFeatures.dark();
      final result = await detector.infer(
        feat.toFloat32Tensor(),
        timestampMs: feat.timestampMs,
      );
      expect(result.label, 'threat');
      expect(result.isConfident, isTrue);
    });

    test('score is in [0, 0.95]', () async {
      final feat = SceneFeatures.dark();
      final result = await detector.infer(
        feat.toFloat32Tensor(),
        timestampMs: feat.timestampMs,
      );
      expect(result.score, lessThanOrEqualTo(0.95));
    });

    test('missing input throws ArgumentError', () {
      expect(
        () => detector.infer(Float32List(4), timestampMs: 0),
        throwsArgumentError,
      );
    });
  });

  // ── HeuristicDetectionEngine ───────────────────────────────────────────────
  group('HeuristicDetectionEngine', () {
    test('low tier → isAiMode false', () {
      final engine = HeuristicDetectionEngine(tier: PhoneCapabilityTier.low);
      expect(engine.isAiMode, isFalse);
    });

    test('medium tier → isAiMode true', () {
      final engine = HeuristicDetectionEngine(tier: PhoneCapabilityTier.medium);
      expect(engine.isAiMode, isTrue);
    });

    test('high tier → isAiMode true', () {
      final engine = HeuristicDetectionEngine(tier: PhoneCapabilityTier.high);
      expect(engine.isAiMode, isTrue);
    });

    test('low tier scream → heuristic-scream-v1', () {
      final engine = HeuristicDetectionEngine(tier: PhoneCapabilityTier.low);
      expect(engine.scream.modelLabel, 'heuristic-scream-v1');
    });

    test('low tier motion → heuristic-motion-v1', () {
      final engine = HeuristicDetectionEngine(tier: PhoneCapabilityTier.low);
      expect(engine.motion.modelLabel, 'heuristic-motion-v1');
    });

    test('low tier scene → heuristic-scene-v1', () {
      final engine = HeuristicDetectionEngine(tier: PhoneCapabilityTier.low);
      expect(engine.scene.modelLabel, 'heuristic-scene-v1');
    });

    test('high tier with no AI interpreters falls back to heuristic', () {
      final engine = HeuristicDetectionEngine(
        tier: PhoneCapabilityTier.high,
        // aiScreamInterpreter = null → should fall back
      );
      expect(engine.scream.modelLabel, 'heuristic-scream-v1');
    });

    test('modeLabel for low tier contains Heuristic', () {
      final engine = HeuristicDetectionEngine(tier: PhoneCapabilityTier.low);
      expect(engine.modeLabel, contains('Heuristic'));
    });

    test('modeLabel for high tier contains AI', () {
      final engine = HeuristicDetectionEngine(tier: PhoneCapabilityTier.high);
      expect(engine.modeLabel, contains('AI'));
    });

    test('withTier rebuilds engine with new tier', () {
      final low  = HeuristicDetectionEngine(tier: PhoneCapabilityTier.low);
      final high = low.withTier(PhoneCapabilityTier.high);
      expect(high.tier, PhoneCapabilityTier.high);
      expect(high.isAiMode, isTrue);
    });

    test('dispose completes without error', () async {
      final engine = HeuristicDetectionEngine(tier: PhoneCapabilityTier.low);
      await expectLater(engine.dispose(), completes);
    });

    test('low tier end-to-end: impact motion → threat result', () async {
      final engine = HeuristicDetectionEngine(tier: PhoneCapabilityTier.low);
      final feat   = MotionFeatures.impact();
      final result = await engine.motion.infer(
        feat.toFloat32Tensor(),
        timestampMs: feat.timestampMs,
      );
      expect(result.label, 'threat');
      expect(result.isConfident, isTrue);
    });

    test('low tier end-to-end: dark scene → threat result', () async {
      final engine = HeuristicDetectionEngine(tier: PhoneCapabilityTier.low);
      final feat   = SceneFeatures.dark();
      final result = await engine.scene.infer(
        feat.toFloat32Tensor(),
        timestampMs: feat.timestampMs,
      );
      expect(result.label, 'threat');
      expect(result.isConfident, isTrue);
    });
  });
}
