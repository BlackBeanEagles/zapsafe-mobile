/// Day 47 — ML pipeline integration tests.
///
/// Covers end-to-end signal paths through the detection stack:
///   HeuristicDetector → InferenceResult → isConfident / severity
///   HeuristicDetectionEngine routing (tier × null-AI)
///   DetectionSettings ↔ engine mode
///   ModelBundleResult consistency with current asset state
///   Cross-modality: all 3 detectors produce coherent InferenceResult shapes
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/data/models/inference_result.dart';
import 'package:zapsafe_mobile/data/services/heuristic_detection_engine.dart';
import 'package:zapsafe_mobile/data/services/heuristic_motion_detector.dart';
import 'package:zapsafe_mobile/data/services/heuristic_scene_detector.dart';
import 'package:zapsafe_mobile/data/services/heuristic_scream_detector.dart';
import 'package:zapsafe_mobile/data/services/interpreter.dart';
import 'package:zapsafe_mobile/data/services/model_bundle_service.dart';
import 'package:zapsafe_mobile/data/services/phone_capability_detector.dart';
import 'package:zapsafe_mobile/domain/providers/detection_settings_provider.dart';

// ─── Fixture helpers ─────────────────────────────────────────────────────────

Float32List _screamFeatures() {
  // 15 floats: mfcc[0..12]=MFCC, [13]=ZCR, [14]=spectralCentroid
  // High-energy scream: mfcc0=-5 (loud), ZCR=0.35, centroid=4000 Hz
  final f = Float32List(15);
  f[0]  = -5.0;   // mfcc0 — high energy
  for (var i = 1; i < 13; i++) f[i] = 0.0;
  f[13] = 0.35;   // ZCR — above 0.15 threshold
  f[14] = 4000.0; // spectral centroid — above 2000 Hz threshold
  return f;
}

Float32List _safeAudioFeatures() {
  // Low energy, low ZCR, low centroid — all heuristic gates should be 0
  final f = Float32List(15);
  f[0]  = -60.0;  // very quiet
  f[13] = 0.02;   // almost no ZCR
  f[14] = 300.0;  // low centroid
  return f;
}

Float32List _impactMotionFeatures() {
  // 6 floats: [0]=accelX [1]=accelY [2]=accelZ [3]=gyroX [4]=gyroY [5]=gyroZ
  // Strong impact: peak = sqrt(30^2+0+0) ≈ 30, variance via single sample =0 (handled)
  final f = Float32List(6);
  f[0] = 30.0; // accelX — above 25 m/s² threshold
  f[1] = 2.0;
  f[2] = 2.0;
  f[3] = 4.0;  // gyroX — above 3.0 rad/s threshold
  return f;
}

Float32List _calmMotionFeatures() {
  final f = Float32List(6);
  f[0] = 0.2; f[1] = 9.8; f[2] = 0.1; // normal gravity, near rest
  f[3] = 0.0; f[4] = 0.0; f[5] = 0.0;
  return f;
}

Float32List _darkSceneFeatures() {
  // 8 floats: [0]=meanBrightness [1]=darkPixelRatio [2]=contrastStd
  //           [3]=edgeDensity [4]=saturationMean [5]=red [6]=green [7]=blue
  final f = Float32List(8);
  f[0] = 30.0;  // dark (< 60 threshold)
  f[1] = 0.70;  // dark pixel ratio > 0.50
  f[2] = 20.0;  // low contrast (< 35 → occlusion gate fires)
  return f;
}

Float32List _brightSceneFeatures() {
  final f = Float32List(8);
  f[0] = 180.0; // well-lit
  f[1] = 0.05;  // very few dark pixels
  f[2] = 80.0;  // high contrast
  return f;
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  // ── 1. Scream detector: end-to-end signal path ────────────────────────────
  group('Scream detector end-to-end', () {
    const detector = HeuristicScreamDetector();

    test('threat audio → InferenceResult has label + scores + latency', () async {
      final result = await detector.infer(_screamFeatures(), timestampMs: 1000);
      expect(result, isA<InferenceResult>());
      expect(result.label, isNotEmpty);
      expect(result.score, inInclusiveRange(0.0, 1.0));
      expect(result.latencyMs, greaterThanOrEqualTo(0));
      expect(result.timestampMs, equals(1000));
    });

    test('threat audio → score > 0.5 (at least one gate fires)', () async {
      final result = await detector.infer(_screamFeatures(), timestampMs: 0);
      expect(result.score, greaterThan(0.5));
    });

    test('threat audio → classScores contains all 3 classes', () async {
      final result = await detector.infer(_screamFeatures(), timestampMs: 0);
      expect(result.classScores.keys, containsAll(['normal', 'shout', 'scream']));
    });

    test('threat audio → isConfident true (score ≥ 0.7)', () async {
      final result = await detector.infer(_screamFeatures(), timestampMs: 0);
      expect(result.isConfident, isTrue);
    });

    test('threat audio → severity is medium or high', () async {
      final result = await detector.infer(_screamFeatures(), timestampMs: 0);
      expect(
        result.severity,
        anyOf(InferenceSeverity.medium, InferenceSeverity.high),
      );
    });

    test('safe audio → scream classScore < 0.7', () async {
      final result = await detector.infer(_safeAudioFeatures(), timestampMs: 0);
      expect(result.classScores['scream'] ?? 0.0, lessThan(0.7));
    });

    test('safe audio → scream threat score is 0 (all gates off)', () async {
      final result = await detector.infer(_safeAudioFeatures(), timestampMs: 0);
      // All 3 gates are off → screamScore=0 → 'normal' wins with high score.
      // We verify the threat signal itself is absent.
      expect(result.classScores['scream'] ?? 0.0, lessThan(0.1));
      expect(result.label, equals('normal'));
    });

    test('timestampMs is echoed through to result', () async {
      const ts = 987654321;
      final result = await detector.infer(_screamFeatures(), timestampMs: ts);
      expect(result.timestampMs, equals(ts));
    });
  });

  // ── 2. Motion detector: end-to-end signal path ───────────────────────────
  group('Motion detector end-to-end', () {
    const detector = HeuristicMotionDetector();

    test('impact features → InferenceResult well-formed', () async {
      final result = await detector.infer(_impactMotionFeatures(), timestampMs: 500);
      expect(result.label, isNotEmpty);
      expect(result.score, inInclusiveRange(0.0, 1.0));
      expect(result.latencyMs, greaterThanOrEqualTo(0));
      expect(result.timestampMs, equals(500));
    });

    test('impact features → score > 0.5', () async {
      final result = await detector.infer(_impactMotionFeatures(), timestampMs: 0);
      expect(result.score, greaterThan(0.5));
    });

    test('calm motion → threat classScore < 0.5', () async {
      final result = await detector.infer(_calmMotionFeatures(), timestampMs: 0);
      // 'normal' wins; check the threat signal specifically.
      expect(result.classScores['threat'] ?? 0.0, lessThan(0.5));
    });

    test('expectedInputSize = 6', () {
      expect(detector.expectedInputSize, equals(6));
    });

    test('classLabels includes normal and threat', () {
      expect(detector.classLabels, containsAll(['normal', 'threat']));
    });
  });

  // ── 3. Scene detector: end-to-end signal path ────────────────────────────
  group('Scene detector end-to-end', () {
    const detector = HeuristicSceneDetector();

    test('dark scene → InferenceResult well-formed', () async {
      final result = await detector.infer(_darkSceneFeatures(), timestampMs: 200);
      expect(result.label, isNotEmpty);
      expect(result.score, inInclusiveRange(0.0, 1.0));
      expect(result.timestampMs, equals(200));
    });

    test('dark scene → score > 0.5', () async {
      final result = await detector.infer(_darkSceneFeatures(), timestampMs: 0);
      expect(result.score, greaterThan(0.5));
    });

    test('bright scene → threat classScore is 0 (all gates off)', () async {
      final result = await detector.infer(_brightSceneFeatures(), timestampMs: 0);
      // All gates off → threat=0, 'safe' wins with score=1.0.
      expect(result.classScores['threat'] ?? 0.0, equals(0.0));
      expect(result.label, equals('safe'));
    });

    test('expectedInputSize = 8', () {
      expect(detector.expectedInputSize, equals(8));
    });
  });

  // ── 4. Cross-modality interface consistency ───────────────────────────────
  group('Cross-modality interface consistency', () {
    test('all 3 detectors implement Interpreter', () {
      expect(const HeuristicScreamDetector(), isA<Interpreter>());
      expect(const HeuristicMotionDetector(), isA<Interpreter>());
      expect(const HeuristicSceneDetector(),  isA<Interpreter>());
    });

    test('modelLabels are distinct', () {
      final labels = [
        const HeuristicScreamDetector().modelLabel,
        const HeuristicMotionDetector().modelLabel,
        const HeuristicSceneDetector().modelLabel,
      ];
      expect(labels.toSet().length, equals(3));
    });

    test('all detectors return non-null InferenceResult', () async {
      final scream = await const HeuristicScreamDetector()
          .infer(_screamFeatures(), timestampMs: 0);
      final motion = await const HeuristicMotionDetector()
          .infer(_impactMotionFeatures(), timestampMs: 0);
      final scene  = await const HeuristicSceneDetector()
          .infer(_darkSceneFeatures(), timestampMs: 0);
      expect(scream, isNotNull);
      expect(motion, isNotNull);
      expect(scene,  isNotNull);
    });

    test('dispose is safe to call on all 3', () async {
      await const HeuristicScreamDetector().dispose();
      await const HeuristicMotionDetector().dispose();
      await const HeuristicSceneDetector().dispose();
      // If no exception is thrown, the test passes.
    });
  });

  // ── 5. HeuristicDetectionEngine routing integration ───────────────────────
  group('HeuristicDetectionEngine full routing integration', () {
    test('low tier → all heuristic, engine.isAiMode false', () {
      final engine = HeuristicDetectionEngine(tier: PhoneCapabilityTier.low);
      expect(engine.isAiMode, isFalse);
      expect(engine.scream.modelLabel, contains('heuristic'));
      expect(engine.motion.modelLabel, contains('heuristic'));
      expect(engine.scene.modelLabel,  contains('heuristic'));
    });

    test('high tier + no AI interpreters → heuristic fallback', () {
      final engine = HeuristicDetectionEngine(tier: PhoneCapabilityTier.high);
      expect(engine.scream.modelLabel, contains('heuristic'));
    });

    test('high tier + AI scream → scream uses AI, motion/scene stay heuristic', () {
      final fakeAi = const FixedStubInterpreter(
        modelLabel: 'scream-ai-v1',
        expectedInputSize: 15,
      );
      final engine = HeuristicDetectionEngine(
        tier: PhoneCapabilityTier.high,
        aiScreamInterpreter: fakeAi,
      );
      expect(engine.scream.modelLabel, equals('scream-ai-v1'));
      expect(engine.motion.modelLabel, contains('heuristic'));
      expect(engine.scene.modelLabel,  contains('heuristic'));
    });

    test('medium tier + all AI → uses all AI', () {
      final screamAi = const FixedStubInterpreter(
          modelLabel: 'scream-ai', expectedInputSize: 15);
      final motionAi = const FixedStubInterpreter(
          modelLabel: 'motion-ai', expectedInputSize: 6);
      final sceneAi  = const FixedStubInterpreter(
          modelLabel: 'scene-ai',  expectedInputSize: 8);
      final engine = HeuristicDetectionEngine(
        tier: PhoneCapabilityTier.medium,
        aiScreamInterpreter: screamAi,
        aiMotionInterpreter: motionAi,
        aiSceneInterpreter:  sceneAi,
      );
      expect(engine.scream.modelLabel, equals('scream-ai'));
      expect(engine.motion.modelLabel, equals('motion-ai'));
      expect(engine.scene.modelLabel,  equals('scene-ai'));
      expect(engine.isAiMode, isTrue);
    });

    test('engine can run inference via scream slot end-to-end', () async {
      final engine = HeuristicDetectionEngine(tier: PhoneCapabilityTier.low);
      final result = await engine.scream.infer(
        _screamFeatures(), timestampMs: 1234,
      );
      expect(result.timestampMs, equals(1234));
      expect(result.score, inInclusiveRange(0.0, 1.0));
    });
  });

  // ── 6. DetectionSettings × engine mode ───────────────────────────────────
  group('DetectionSettings controls engine mode', () {
    test('aiEnabled=true → engine uses AI when interpreters provided', () {
      const settings = DetectionSettings(aiEnabled: true);
      final fakeAi = const FixedStubInterpreter(
          modelLabel: 'real-scream', expectedInputSize: 15);
      final engine = HeuristicDetectionEngine(
        tier: PhoneCapabilityTier.high,
        aiScreamInterpreter: settings.aiEnabled ? fakeAi : null,
      );
      expect(engine.scream.modelLabel, equals('real-scream'));
    });

    test('aiEnabled=false → engine receives null AI → heuristic fallback', () {
      const settings = DetectionSettings(aiEnabled: false);
      final fakeAi = const FixedStubInterpreter(
          modelLabel: 'real-scream', expectedInputSize: 15);
      final engine = HeuristicDetectionEngine(
        tier: PhoneCapabilityTier.high,
        aiScreamInterpreter: settings.aiEnabled ? fakeAi : null,
      );
      expect(engine.scream.modelLabel, contains('heuristic'));
    });

    test('screamEnabled=false → caller should use heuristic label', () {
      const settings = DetectionSettings(screamEnabled: false);
      expect(settings.screamEnabled, isFalse);
      // The engine itself doesn't read settings — the caller gates the
      // AI interpreter. Verify caller can select heuristic via null.
      final engine = HeuristicDetectionEngine(
        tier: PhoneCapabilityTier.high,
        aiScreamInterpreter: settings.screamEnabled
            ? const FixedStubInterpreter(modelLabel: 'ai')
            : null,
      );
      expect(engine.scream.modelLabel, contains('heuristic'));
    });
  });

  // ── 7. ModelBundleResult integrity (current asset state) ─────────────────
  group('ModelBundleResult integrity', () {
    ModelBundleResult _makeBundle() {
      // Mirror current asset reality:
      //   scream → placeholder (658 B)
      //   motion → realLoadFailed (194 KB, pipeline mismatch)
      //   scene  → skippedImageModel (2.6 MB)
      final slots = [
        ModelSlotResult(
          key: 'scream',
          displayName: 'Scream Classifier v1',
          assetPath: 'assets/models/scream_classifier_v1.tflite',
          status: ModelLoadStatus.placeholder,
          sizeBytes: 658,
          activeInterpreter: const HeuristicScreamDetector(),
        ),
        ModelSlotResult(
          key: 'motion',
          displayName: 'Motion Anomaly v1',
          assetPath: 'assets/models/motion_anomaly_v1.tflite',
          status: ModelLoadStatus.realLoadFailed,
          sizeBytes: 194848,
          activeInterpreter: const HeuristicMotionDetector(),
        ),
        ModelSlotResult(
          key: 'scene',
          displayName: 'Scene Analyzer v1',
          assetPath: 'assets/models/scene_analyzer_v1.tflite',
          status: ModelLoadStatus.skippedImageModel,
          sizeBytes: 2674256,
          activeInterpreter: const HeuristicSceneDetector(),
        ),
      ];
      final engine = HeuristicDetectionEngine(tier: PhoneCapabilityTier.low);
      final total = slots.fold(0, (s, e) => s + e.sizeBytes);
      return ModelBundleResult(slots: slots, engine: engine, totalModelBytes: total);
    }

    test('current state: 0 AI slots, 3 heuristic slots', () {
      final b = _makeBundle();
      expect(b.loadedAiCount, equals(0));
      expect(b.heuristicCount, equals(3));
    });

    test('total size is sum of all slot sizes', () {
      final b = _makeBundle();
      expect(b.totalModelBytes, equals(658 + 194848 + 2674256));
    });

    test('totalSizeLabel contains MB', () {
      expect(_makeBundle().totalSizeLabel, contains('MB'));
    });

    test('engine on bundle is not null and routes to heuristic', () {
      final b = _makeBundle();
      expect(b.engine, isNotNull);
      expect(b.engine.scream.modelLabel, contains('heuristic'));
    });

    test('all active interpreters are heuristic implementations', () {
      final b = _makeBundle();
      for (final slot in b.slots) {
        expect(slot.usesAi, isFalse);
        expect(slot.activeInterpreter.modelLabel, contains('heuristic'));
      }
    });

    test('end-to-end: run inference through each active slot interpreter', () async {
      final b = _makeBundle();
      final screamSlot = b.slots.firstWhere((s) => s.key == 'scream');
      final motionSlot = b.slots.firstWhere((s) => s.key == 'motion');
      final sceneSlot  = b.slots.firstWhere((s) => s.key == 'scene');

      final r1 = await screamSlot.activeInterpreter
          .infer(_screamFeatures(), timestampMs: 100);
      final r2 = await motionSlot.activeInterpreter
          .infer(_impactMotionFeatures(), timestampMs: 200);
      final r3 = await sceneSlot.activeInterpreter
          .infer(_darkSceneFeatures(), timestampMs: 300);

      expect(r1.timestampMs, equals(100));
      expect(r2.timestampMs, equals(200));
      expect(r3.timestampMs, equals(300));
      expect(r1.score, inInclusiveRange(0.0, 1.0));
      expect(r2.score, inInclusiveRange(0.0, 1.0));
      expect(r3.score, inInclusiveRange(0.0, 1.0));
    });
  });

  // ── 8. InferenceResult severity ladder ───────────────────────────────────
  group('InferenceResult severity ladder', () {
    InferenceResult _result(double score) => InferenceResult(
          label: 'scream',
          score: score,
          classScores: {'scream': score, 'normal': 1 - score},
          latencyMs: 1,
          timestampMs: 0,
        );

    test('score=0.90 → high severity', () {
      expect(_result(0.90).severity, InferenceSeverity.high);
    });

    test('score=0.75 → medium severity', () {
      expect(_result(0.75).severity, InferenceSeverity.medium);
    });

    test('score=0.50 → low severity', () {
      expect(_result(0.50).severity, InferenceSeverity.low);
    });

    test('score=0.20 → none severity', () {
      expect(_result(0.20).severity, InferenceSeverity.none);
    });

    test('score=0.70 → isConfident true (boundary)', () {
      expect(_result(0.70).isConfident, isTrue);
    });

    test('score=0.69 → isConfident false (just below boundary)', () {
      expect(_result(0.69).isConfident, isFalse);
    });
  });
}
