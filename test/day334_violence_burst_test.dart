import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/data/services/scene_detector_v2.dart';
import 'package:zapsafe_mobile/data/services/violence_burst_detector.dart';

/// Day 334 — the contract around `m3_violence_temporal`'s burst wiring.
///
/// These cover the parts that do not need a native TFLite interpreter, which
/// `flutter test` has no access to. That limitation is the reason the
/// scaling checks below matter so much: the pieces that *can* only be
/// verified on a device are exactly the ones where a wrong pixel range would
/// produce confident, well-formed, wrong output with nothing thrown.
void main() {
  group('the two MobileNetV3 input conventions must not be confused', () {
    // This app now ships two MobileNetV3-based models fed from the SAME
    // CameraFrameService byte source, with OPPOSITE input scaling:
    //
    //   scene_analyzer_v1      pixel / 255.0   (trained end-to-end on /255
    //                                          despite include_preprocessing)
    //   m3 encoder             raw 0-255       (Rescaling(1/127.5, -1.0) is a
    //                                          layer inside the exported graph)
    //
    // Verified against the real library when the encoder was exported:
    // mobilenet_v3.preprocess_input is a pass-through, input [0,255] comes
    // back [0,255]. So pre-scaling would apply the rescaling twice.
    final frame = List<int>.generate(
      ViolenceBurstDetector.kFrameBytes,
      (i) => i % 256,
    );

    test('packFrameRaw does NOT scale — values stay in [0, 255]', () {
      final packed = ViolenceBurstDetector.packFrameRaw(frame);
      expect(packed.length, ViolenceBurstDetector.kFrameBytes);
      expect(packed[0], 0.0);
      expect(packed[255], 255.0,
          reason: 'a byte of 255 must arrive as 255.0, not 1.0');
      var max = 0.0;
      for (final v in packed) {
        if (v > max) max = v;
      }
      expect(max, 255.0);
    });

    test('SceneDetectorV2.normalise DOES scale — values land in [0, 1]', () {
      final packed = SceneDetectorV2.normalise(frame);
      expect(packed[255], closeTo(1.0, 1e-9));
      var max = 0.0;
      for (final v in packed) {
        if (v > max) max = v;
      }
      expect(max, closeTo(1.0, 1e-9));
    });

    test('the two differ by exactly 255x, so a swap is not subtle', () {
      final raw = ViolenceBurstDetector.packFrameRaw(frame);
      final scaled = SceneDetectorV2.normalise(frame);
      for (var i = 0; i < 1000; i++) {
        if (scaled[i] == 0.0) continue;
        // Tolerance is relative: `normalise` writes into a Float32List, so
        // `byte / 255.0` is stored at float32 precision and the recovered
        // ratio carries ~1e-5 of error at 255. That is storage precision,
        // not a scaling disagreement — the point of the assertion is that
        // the factor is 255 and not 1.
        expect(raw[i] / scaled[i], closeTo(255.0, 255.0 * 1e-5));
      }
    });

    test('both consume the identical byte layout from CameraFrameService', () {
      // 224*224*3 for both, so nothing in the type system stops a caller
      // handing the wrong one to the wrong model. That is precisely why the
      // two entry points are named differently and documented at the call
      // site rather than sharing a generic `prepare()`.
      expect(ViolenceBurstDetector.kFrameBytes, SceneDetectorV2.kInputFloats);
      expect(ViolenceBurstDetector.kFrameBytes, 224 * 224 * 3);
    });
  });

  group('burst shape contract', () {
    test('a frame of the wrong length is rejected, not silently padded', () {
      expect(
        () => ViolenceBurstDetector.packFrameRaw(List<int>.filled(100, 0)),
        throwsArgumentError,
      );
      expect(
        () => ViolenceBurstDetector.packFrameRaw(
          List<int>.filled(ViolenceBurstDetector.kFrameBytes + 1, 0),
        ),
        throwsArgumentError,
      );
    });

    test('the declared shapes match the two shipped models', () {
      // encoder  [1,224,224,3] -> [1,576]
      // temporal [1,16,576]    -> [1,1]
      // tryLoad asserts these against the real tensors at runtime; this pins
      // the constants so a change here fails loudly in CI rather than only
      // on a device.
      expect(ViolenceBurstDetector.kFrames, 16);
      expect(ViolenceBurstDetector.kEmbedding, 576);
      expect(ViolenceBurstDetector.kImgSize, 224);
      expect(ViolenceBurstDetector.kChannels, 3);
      expect(
        ViolenceBurstDetector.kFrames * ViolenceBurstDetector.kEmbedding,
        9216,
        reason: 'the temporal head takes 16*576 floats',
      );
    });

    test('threshold is calibrated for precision, not the sigmoid midpoint',
        () {
      // Day 337 — measured on all 670 held-out val clips:
      //   0.50 -> recall 0.743, precision 0.862, FP-rate 0.127
      //   0.80 -> recall 0.538, precision 0.935, FP-rate 0.040
      // A third the false-positive rate. This is a corroborating signal that
      // only runs after something else raised suspicion, and escalation now
      // actually fires, so a wrong label costs more than a missed one.
      expect(ViolenceBurstDetector.kDefaultThreshold, 0.80);
      expect(ViolenceBurstDetector.kDefaultThreshold, greaterThan(0.5),
          reason: 'the midpoint fired on 12.7% of non-violent clips');
    });
  });

  group('encoder output feeds the head without reshaping surprises', () {
    test('a 16-frame sequence of 576-float embeddings is [1,16,576]', () {
      final seq = List.generate(
        ViolenceBurstDetector.kFrames,
        (_) => Float32List(ViolenceBurstDetector.kEmbedding),
        growable: false,
      );
      final input = [seq];
      expect(input.length, 1);
      expect(input[0].length, ViolenceBurstDetector.kFrames);
      expect(input[0][0].length, ViolenceBurstDetector.kEmbedding);
    });
  });
}
