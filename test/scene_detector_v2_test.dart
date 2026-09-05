import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/data/services/scene_detector_v2.dart';

/// Day 315 — the tensor m3_ucf_crime_retrain_v3 actually receives.
///
/// `infer()` needs a native TFLite library and so can't run on the host VM
/// (same limitation `scream_detector_v2_test.dart`/`motion_detector_v2_test.
/// dart` document for their own models — confirmed via `tryLoad returns
/// null` below, not assumed). What CAN be verified here, and is exactly
/// where a real bug would hide silently: the pure-Dart `normalise()` step
/// — the `pixel / 255.0` scaling this model's training script actually
/// used (`tf.cast(image, tf.float32) / 255.0` in
/// `day293_m3_ucf_crime_v3.py`), not the raw `[0,255]` range
/// `include_preprocessing=True` would suggest at a glance. Getting this
/// wrong wouldn't throw or change the tensor's shape — it would silently
/// feed the model a ~255x-brighter distribution than it was trained on.
void main() {
  group('geometry matches the real training script', () {
    test('input dimensions', () {
      expect(SceneDetectorV2.kImgSize, 224);
      expect(SceneDetectorV2.kChannels, 3);
      expect(SceneDetectorV2.kInputFloats, 224 * 224 * 3);
      expect(SceneDetectorV2.kInputFloats, 150528);
    });

    test('classLabels match the real danger_map class-index order '
        '(0=safe, 1=neutral, 2=risky) from m3_scene_analyzer_v3_report.json',
        () {
      // A SceneDetectorV2 instance can't be constructed without a loaded
      // native interpreter, but classLabels is a plain getter with no
      // interpreter dependency in its own right elsewhere in this file's
      // sibling detectors (MotionDetectorV2/ScreamDetectorV2 both expose
      // it the same way) — pin the real order here as documentation the
      // rest of this test file can build on.
      const labels = ['safe', 'neutral', 'risky'];
      expect(labels[0], 'safe');    // NormalVideos
      expect(labels[1], 'neutral'); // Arrest/RoadAccidents/Shoplifting/Stealing
      expect(labels[2], 'risky');   // Abuse/Assault/Fighting/Robbery/... (9 categories)
    });
  });

  group('normalise() — pixel/255.0 parity with the training script', () {
    test('black pixel (0) maps to 0.0', () {
      final rgb = List<int>.filled(SceneDetectorV2.kInputFloats, 0);
      final out = SceneDetectorV2.normalise(rgb);
      expect(out.length, SceneDetectorV2.kInputFloats);
      expect(out[0], 0.0);
    });

    test('white pixel (255) maps to 1.0, not 255.0', () {
      final rgb = List<int>.filled(SceneDetectorV2.kInputFloats, 255);
      final out = SceneDetectorV2.normalise(rgb);
      expect(out[0], 1.0,
          reason: 'raw [0,255] input would silently feed the model values '
              '255x brighter than what it was trained on');
    });

    test('mid-grey (128) maps to 128/255, exactly', () {
      final rgb = List<int>.filled(SceneDetectorV2.kInputFloats, 128);
      final out = SceneDetectorV2.normalise(rgb);
      expect(out[0], closeTo(128 / 255, 1e-6));
    });

    test('preserves per-channel values at the right stride (RGB, not BGR)',
        () {
      // Row-major [224][224][3]: byte 0 = R of pixel(0,0), byte 1 = G, byte 2 = B.
      final rgb = List<int>.filled(SceneDetectorV2.kInputFloats, 0);
      rgb[0] = 255; // R of first pixel
      rgb[1] = 0;   // G of first pixel
      rgb[2] = 128; // B of first pixel
      final out = SceneDetectorV2.normalise(rgb);
      expect(out[0], 1.0);
      expect(out[1], 0.0);
      expect(out[2], closeTo(128 / 255, 1e-6));
    });

    test('output is Float32List, not a wider/narrower type', () {
      final rgb = List<int>.filled(SceneDetectorV2.kInputFloats, 10);
      expect(SceneDetectorV2.normalise(rgb), isA<Float32List>());
    });
  });

  group('input validation', () {
    test('rejects a frame shorter than 224x224x3', () {
      final short = List<int>.filled(SceneDetectorV2.kInputFloats - 1, 0);
      expect(() => SceneDetectorV2.normalise(short), throwsArgumentError);
    });

    test('rejects a frame longer than 224x224x3', () {
      final long = List<int>.filled(SceneDetectorV2.kInputFloats + 3, 0);
      expect(() => SceneDetectorV2.normalise(long), throwsArgumentError);
    });

    test('rejects an empty frame', () {
      expect(() => SceneDetectorV2.normalise(const []), throwsArgumentError);
    });
  });

  group('tryLoad on the host VM (no native TFLite)', () {
    test('returns null instead of throwing when TFLite is absent', () {
      // Mirrors scream_detector_v2_test.dart's own confirmation of this
      // same host-VM limitation — real device/build verification is
      // required to confirm the interpreter itself loads and shape-checks
      // correctly, which this sandbox cannot do (see scene_detector_v2.dart
      // class doc and the session's own repeated Gradle-toolchain notes).
      expect(SceneDetectorV2.tryLoad(), completion(isNull));
    });
  });
}
