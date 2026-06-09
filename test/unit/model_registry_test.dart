import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/data/services/model_registry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('kZapsafeModels catalogue', () {
    test('declares all four expected slots', () {
      expect(kZapsafeModels.length, 4);
      expect(kZapsafeModels.map((m) => m.key).toList(),
          ['scream', 'motion', 'scene', 'fusion']);
    });

    test('every model has a unique key', () {
      final keys = kZapsafeModels.map((m) => m.key).toSet();
      expect(keys.length, kZapsafeModels.length);
    });

    test('every model has a unique asset path', () {
      final paths = kZapsafeModels.map((m) => m.assetPath).toSet();
      expect(paths.length, kZapsafeModels.length);
    });

    test('every asset path lives under assets/models/', () {
      for (final m in kZapsafeModels) {
        expect(m.assetPath, startsWith('assets/models/'));
        expect(m.assetPath, endsWith('.tflite'));
      }
    });

    test('every model has non-empty metadata', () {
      for (final m in kZapsafeModels) {
        expect(m.displayName, isNotEmpty);
        expect(m.purpose, isNotEmpty);
        expect(m.realModelEta, isNotEmpty);
        expect(m.realSizeMb, greaterThan(0));
      }
    });

    test('asset paths match the timeline-specified filenames', () {
      // The Day 31 timeline entry pins these exact names — the backend
      // training pipeline writes into these paths in Month 3.
      const expected = {
        'scream': 'assets/models/scream_classifier_v1.tflite',
        'motion': 'assets/models/motion_anomaly_v1.tflite',
        'scene':  'assets/models/scene_analyzer_v1.tflite',
        'fusion': 'assets/models/dcs_fusion_v1.tflite',
      };
      for (final m in kZapsafeModels) {
        expect(m.assetPath, expected[m.key],
            reason: 'key=${m.key} mismatched the timeline filename');
      }
    });
  });

  group('ModelRegistry.loadAll', () {
    test('loads every model from the asset bundle', () async {
      final registry = ModelRegistry();
      final statuses = await registry.loadAll();
      expect(statuses.length, kZapsafeModels.length);
      // Each status carries its definition.
      for (var i = 0; i < statuses.length; i++) {
        expect(statuses[i].definition.key, kZapsafeModels[i].key);
      }
    });

    test('correctly identifies placeholder vs real model files', () async {
      final registry = ModelRegistry();
      final statuses = await registry.loadAll();
      final byKey = {for (final s in statuses) s.definition.key: s};

      // scream (658 B) and fusion (257 B) are still text stubs.
      if ((byKey['scream']?.sizeBytes ?? 0) > 0) {
        expect(byKey['scream']?.isPlaceholder, isTrue,
            reason: 'scream_classifier_v1 is a 1 KB text placeholder');
      }
      if ((byKey['fusion']?.sizeBytes ?? 0) > 0) {
        expect(byKey['fusion']?.isPlaceholder, isTrue,
            reason: 'dcs_fusion_v1 is a 1 KB text placeholder');
      }

      // motion (194 KB) and scene (2.6 MB) are real binary TFLite files —
      // not placeholders, even though the mobile pipeline can't yet use them.
      if ((byKey['motion']?.sizeBytes ?? 0) > 0) {
        expect(byKey['motion']?.isPlaceholder, isFalse,
            reason: 'motion_anomaly_v1 is a real 194 KB TFLite binary');
      }
      if ((byKey['scene']?.sizeBytes ?? 0) > 0) {
        expect(byKey['scene']?.isPlaceholder, isFalse,
            reason: 'scene_analyzer_v1 is a real 2.6 MB MobileNetV2 binary');
      }
    });
  });
}
