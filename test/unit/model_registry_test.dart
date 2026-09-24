import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/data/services/model_registry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('kZapsafeModels catalogue', () {
    test('declares the expected slots in order', () {
      expect(kZapsafeModels.length, 6);
      // Day 325 added 'vocal_stress' (M5). The plan's roster
      // (zapsafeworking/ZAPSAFE_ML_TRAINING_STRATEGY.md) runs M1-M9, so this
      // list grows as slots get real models -- it is not capped at five.
      expect(kZapsafeModels.map((m) => m.key).toList(), [
        'scream',
        'motion',
        'scene',
        'fusion',
        'vocal_stress',
        'aggressive_speech',
      ]);
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
      //
      // Day 323: the motion slot moved off motion_anomaly_v1.tflite, which
      // was verified DEAD (constant 0.0 on real IMU), onto motion_fall_v2 —
      // retrained on UniMiB-SHAR, held-out-subject AUC 0.998. The Day 31
      // name is deliberately NOT preserved: keeping it would have meant
      // shipping a filename that no longer describes the model behind it.
      const expected = {
        'scream': 'assets/models/scream_classifier_v5.tflite',
        'motion': 'assets/models/motion_fall_v2.tflite',
        // Day 351: scene_analyzer_v1.tflite is DELETED. Day 335 moved
        // the DCS scene slot to m3_violence_temporal via
        // sceneResultOverride -- scene_analyzer's labels
        // (indoor/outdoor/transit) contain no danger class, and
        // SceneDetectorV2 was never constructed in lib/, so 1.4 MB
        // shipped to every user for nothing. The _v1 suffix is required:
        // localVersionFor() parses _vN from the filename and returned
        // 'unknown' without it.
        'scene':  'assets/models/m3_violence_temporal_v1.tflite',
        'fusion': 'assets/models/dcs_fusion_v1.tflite',
        // Day 350: _38, because the 28-feature variant measured 0.4865 --
        // chance -- on natural Mandarin. The suffix is load-bearing: the
        // gate routes [1,38] models by filename and three of them now share
        // that shape with two different feature definitions.
        'vocal_stress': 'assets/models/m5_vocal_stress_v2_38.tflite',
        // Day 352: Phase B wired, v1 -> v4. v1's 0.8442 was RAVDESS-only
        // and measured 0.4780 (chance) on natural speech; v4 reads
        // 0.6415 there. The _38 suffix matters -- the gate routes [1,38]
        // models by filename across two feature definitions.
        'aggressive_speech': 'assets/models/h_aggressive_v4_38.tflite',
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

      // Day 257 replaced a 658-byte text stub with a real binary, and this
      // guards that. If scream ever reads as a placeholder again the real
      // model has been reverted and the detector is silently running on the
      // heuristic fallback.
      //
      // Day 324: the >1 MB floor this used to assert is gone. It was a
      // proxy for "real binary, not a text stub", and it stopped being one:
      // scream_classifier_v5 is 206 KB (float16, smaller architecture) and
      // scores AUC 0.8284 on the 287-positive FSD50K eval set, where the
      // 2,811 KB v1 it replaced scored 0.616 on a far weaker fixture.
      // Size never measured quality. isPlaceholder
      // checks the thing actually worth checking, and
      // tools/verify_shipped_models.py checks whether it detects anything.
      if ((byKey['scream']?.sizeBytes ?? 0) > 0) {
        expect(byKey['scream']?.isPlaceholder, isFalse,
            reason: 'scream_classifier_v5 is a real TFLite binary');
        expect(byKey['scream']!.sizeBytes, greaterThan(10000),
            reason: 'the real scream model is ~206 KB float16');
      }
      // fusion (257 B) is still a text stub — m9 failed its gate and is
      // deliberately not shipped. See PREPROCESSING_SPEC.md.
      if ((byKey['fusion']?.sizeBytes ?? 0) > 0) {
        expect(byKey['fusion']?.isPlaceholder, isTrue,
            reason: 'dcs_fusion_v1 is a 1 KB text placeholder');
      }

      // motion (130 KB) and scene (670 KB) are real binary TFLite files.
      // The motion one is now also wired and verified: MotionDetectorV2
      // loads it and tools/verify_shipped_models.py scores it AUC 0.999 on
      // real held-out-subject UniMiB windows.
      if ((byKey['motion']?.sizeBytes ?? 0) > 0) {
        expect(byKey['motion']?.isPlaceholder, isFalse,
            reason: 'motion_fall_v2 is a real 130 KB TFLite binary');
      }
      if ((byKey['scene']?.sizeBytes ?? 0) > 0) {
        expect(byKey['scene']?.isPlaceholder, isFalse,
            reason: 'm3_violence_temporal_v1 is a real 670 KB binary');
      }
    });
  });
}
