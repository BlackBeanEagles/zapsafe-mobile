import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/data/services/heuristic_detection_engine.dart';
import 'package:zapsafe_mobile/data/services/heuristic_motion_detector.dart';
import 'package:zapsafe_mobile/data/services/heuristic_scene_detector.dart';
import 'package:zapsafe_mobile/data/services/heuristic_scream_detector.dart';
import 'package:zapsafe_mobile/data/services/interpreter.dart';
import 'package:zapsafe_mobile/data/services/model_bundle_service.dart';
import 'package:zapsafe_mobile/data/services/phone_capability_detector.dart';

void main() {
  // ── ModelLoadStatus ────────────────────────────────────────────────────────
  group('ModelLoadStatus', () {
    test('covers all 4 cases', () {
      expect(ModelLoadStatus.values.length, 4);
      expect(ModelLoadStatus.values, containsAll([
        ModelLoadStatus.placeholder,
        ModelLoadStatus.realLoaded,
        ModelLoadStatus.realLoadFailed,
        ModelLoadStatus.skippedImageModel,
      ]));
    });
  });

  // ── ModelSlotResult ────────────────────────────────────────────────────────
  group('ModelSlotResult', () {
    ModelSlotResult _slot(ModelLoadStatus status, Interpreter interp) =>
        ModelSlotResult(
          key: 'test',
          displayName: 'Test Model',
          assetPath: 'assets/models/test.tflite',
          status: status,
          sizeBytes: 12345,
          activeInterpreter: interp,
        );

    test('realLoaded → usesAi true', () {
      final slot = _slot(
          ModelLoadStatus.realLoaded, const FixedStubInterpreter());
      expect(slot.usesAi, isTrue);
    });

    test('placeholder → usesAi false', () {
      final slot = _slot(
          ModelLoadStatus.placeholder, const HeuristicScreamDetector());
      expect(slot.usesAi, isFalse);
    });

    test('realLoadFailed → usesAi false', () {
      final slot = _slot(
          ModelLoadStatus.realLoadFailed, const HeuristicMotionDetector());
      expect(slot.usesAi, isFalse);
    });

    test('skippedImageModel → usesAi false', () {
      final slot = _slot(
          ModelLoadStatus.skippedImageModel, const HeuristicSceneDetector());
      expect(slot.usesAi, isFalse);
    });

    test('statusLabel contains expected text for each status', () {
      expect(
        _slot(ModelLoadStatus.realLoaded, const FixedStubInterpreter()).statusLabel,
        contains('TFLite'),
      );
      expect(
        _slot(ModelLoadStatus.placeholder, const HeuristicScreamDetector()).statusLabel,
        contains('Placeholder'),
      );
      expect(
        _slot(ModelLoadStatus.realLoadFailed, const HeuristicMotionDetector()).statusLabel,
        contains('heuristic'),
      );
      expect(
        _slot(ModelLoadStatus.skippedImageModel, const HeuristicSceneDetector()).statusLabel,
        contains('Image'),
      );
    });

    test('sizeMbLabel for large file contains MB', () {
      final slot = ModelSlotResult(
        key: 'x',
        displayName: 'X',
        assetPath: 'x.tflite',
        status: ModelLoadStatus.realLoaded,
        sizeBytes: 2674256,
        activeInterpreter: const FixedStubInterpreter(),
      );
      expect(slot.sizeMbLabel, contains('MB'));
    });

    test('sizeMbLabel for small file contains placeholder', () {
      final slot = ModelSlotResult(
        key: 'x',
        displayName: 'X',
        assetPath: 'x.tflite',
        status: ModelLoadStatus.placeholder,
        sizeBytes: 658,
        activeInterpreter: const HeuristicScreamDetector(),
      );
      expect(slot.sizeMbLabel, contains('placeholder'));
    });
  });

  // ── ModelBundleResult ──────────────────────────────────────────────────────
  group('ModelBundleResult', () {
    ModelBundleResult _bundle({
      int aiCount = 0,
      int heuristicCount = 3,
    }) {
      final slots = <ModelSlotResult>[];
      for (var i = 0; i < aiCount; i++) {
        slots.add(ModelSlotResult(
          key: 'ai$i',
          displayName: 'AI $i',
          assetPath: 'x.tflite',
          status: ModelLoadStatus.realLoaded,
          sizeBytes: 1000000,
          activeInterpreter: const FixedStubInterpreter(),
        ));
      }
      for (var i = 0; i < heuristicCount; i++) {
        slots.add(ModelSlotResult(
          key: 'h$i',
          displayName: 'Heuristic $i',
          assetPath: 'x.tflite',
          status: ModelLoadStatus.placeholder,
          sizeBytes: 500,
          activeInterpreter: const HeuristicScreamDetector(),
        ));
      }
      final engine = HeuristicDetectionEngine(
          tier: PhoneCapabilityTier.low);
      final total = slots.fold(0, (s, e) => s + e.sizeBytes);
      return ModelBundleResult(
          slots: slots, engine: engine, totalModelBytes: total);
    }

    test('loadedAiCount matches ai slots', () {
      expect(_bundle(aiCount: 2, heuristicCount: 1).loadedAiCount, 2);
    });

    test('heuristicCount matches heuristic slots', () {
      expect(_bundle(aiCount: 1, heuristicCount: 2).heuristicCount, 2);
    });

    test('totalSizeLabel contains MB', () {
      expect(_bundle().totalSizeLabel, contains('MB'));
    });

    test('engine is not null', () {
      expect(_bundle().engine, isNotNull);
    });
  });

  // ── HeuristicDetectionEngine routing (Day 44 integration) ─────────────────
  group('HeuristicDetectionEngine routing with bundle', () {
    test('low tier with no AI interpreters → all heuristic labels', () {
      final engine = HeuristicDetectionEngine(
        tier: PhoneCapabilityTier.low,
      );
      expect(engine.scream.modelLabel, 'heuristic-scream-v1');
      expect(engine.motion.modelLabel, 'heuristic-motion-v1');
      expect(engine.scene.modelLabel,  'heuristic-scene-v1');
    });

    test('high tier with null AI → falls back to heuristic', () {
      final engine = HeuristicDetectionEngine(
        tier: PhoneCapabilityTier.high,
        // all AI interpreters = null
      );
      expect(engine.scream.modelLabel, 'heuristic-scream-v1');
      expect(engine.motion.modelLabel, 'heuristic-motion-v1');
      expect(engine.scene.modelLabel,  'heuristic-scene-v1');
    });

    test('high tier with AI interpreters provided → uses AI labels', () {
      final fakeAi = const FixedStubInterpreter(modelLabel: 'real-scream-v1');
      final engine = HeuristicDetectionEngine(
        tier: PhoneCapabilityTier.high,
        aiScreamInterpreter: fakeAi,
      );
      expect(engine.scream.modelLabel, 'real-scream-v1');
    });
  });
}
