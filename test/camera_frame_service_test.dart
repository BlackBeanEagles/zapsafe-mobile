import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:zapsafe_mobile/data/services/camera_frame_service.dart';
import 'package:zapsafe_mobile/data/services/scene_detector_v2.dart';

/// Day 316 — the real decode/resize/flatten path a captured frame goes
/// through before it ever reaches SceneDetectorV2.
///
/// `captureSceneRgb()`/`ensureInitialized()` need a real camera and so
/// can't run on the host VM (same class of limitation this project has
/// hit for every hardware-backed detector — TFLite, motion, scream).
/// `jpegBytesToSceneRgb()` is deliberately split out as a static,
/// camera-independent function specifically so THIS part — the part most
/// likely to hide a real bug (wrong channel order, resize distorting the
/// frame, an off-by-one in the row-major flatten) — is fully testable
/// with real JPEG bytes from `package:image`'s own encoder.
void main() {
  Uint8List solidColorJpeg(int width, int height, int r, int g, int b) {
    final image = img.Image(width: width, height: height);
    img.fill(image, color: img.ColorRgb8(r, g, b));
    return Uint8List.fromList(img.encodeJpg(image));
  }

  group('geometry', () {
    test('output is always exactly 224x224x3, regardless of input size', () {
      final jpeg = solidColorJpeg(400, 200, 100, 150, 200); // non-square, non-224 input
      final out = CameraFrameService.jpegBytesToSceneRgb(jpeg);
      expect(out, isNotNull);
      expect(out!.length, SceneDetectorV2.kInputFloats);
      expect(out.length, 224 * 224 * 3);
    });

    test('a tiny input still resizes up to 224x224x3', () {
      final jpeg = solidColorJpeg(8, 8, 50, 60, 70);
      final out = CameraFrameService.jpegBytesToSceneRgb(jpeg);
      expect(out, isNotNull);
      expect(out!.length, SceneDetectorV2.kInputFloats);
    });
  });

  group('colour fidelity — RGB channel order preserved through resize', () {
    test('solid red survives decode+resize with real, not swapped, channels', () {
      final jpeg = solidColorJpeg(64, 64, 220, 10, 10);
      final out = CameraFrameService.jpegBytesToSceneRgb(jpeg)!;
      // Sample the center pixel — safely away from any resize-edge
      // interpolation artifacts.
      const centerPixel = (112 * 224 + 112) * 3;
      expect(out[centerPixel], closeTo(220, 20),
          reason: 'R channel should stay high — JPEG is lossy, so allow '
              'real compression tolerance, not exact equality');
      expect(out[centerPixel + 1], closeTo(10, 20),
          reason: 'G channel should stay low');
      expect(out[centerPixel + 2], closeTo(10, 20),
          reason: 'B channel should stay low');
    });

    test('solid blue is not misread as red or green (catches a swapped-channel bug)',
        () {
      final jpeg = solidColorJpeg(64, 64, 10, 10, 220);
      final out = CameraFrameService.jpegBytesToSceneRgb(jpeg)!;
      const centerPixel = (112 * 224 + 112) * 3;
      expect(out[centerPixel], closeTo(10, 20));     // R low
      expect(out[centerPixel + 1], closeTo(10, 20)); // G low
      expect(out[centerPixel + 2], closeTo(220, 20)); // B high — the real signal
    });
  });

  group('row-major flatten layout', () {
    test('pixel at (x, y) lands at exactly (y*224 + x)*3, not transposed', () {
      // A horizontal gradient (varies by X, constant by Y) — if the
      // flatten were accidentally transposed (column-major), sampling
      // along what should be a single row would show variation instead
      // of the flat value a true row-major layout produces.
      final image = img.Image(width: 224, height: 224);
      for (var y = 0; y < 224; y++) {
        for (var x = 0; x < 224; x++) {
          image.setPixelRgb(x, y, x, 0, 0); // R channel encodes the real x coordinate
        }
      }
      final jpeg = Uint8List.fromList(img.encodeJpg(image, quality: 100));
      final out = CameraFrameService.jpegBytesToSceneRgb(jpeg)!;

      // Row 100, columns 10 and 200 should differ by roughly (200-10),
      // proving X varies along a row as row-major layout predicts.
      final left = out[(100 * 224 + 10) * 3];
      final right = out[(100 * 224 + 200) * 3];
      expect(right - left, closeTo(190, 30),
          reason: 'R channel should track the real X coordinate within a row');
    });
  });

  group('failure handling', () {
    test('garbage bytes that are not a real image return null, not a crash', () {
      final garbage = Uint8List.fromList(List.filled(50, 0xFF));
      expect(CameraFrameService.jpegBytesToSceneRgb(garbage), isNull);
    });

    test('empty bytes return null', () {
      expect(CameraFrameService.jpegBytesToSceneRgb(Uint8List(0)), isNull);
    });
  });

  group('output feeds directly into SceneDetectorV2.normalise()', () {
    test('a real decoded frame round-trips through the real /255.0 scaling', () {
      final jpeg = solidColorJpeg(64, 64, 255, 0, 0);
      final rgb = CameraFrameService.jpegBytesToSceneRgb(jpeg)!;
      final tensor = SceneDetectorV2.normalise(rgb);
      expect(tensor.length, SceneDetectorV2.kInputFloats);
      const centerPixel = (112 * 224 + 112) * 3;
      expect(tensor[centerPixel], closeTo(1.0, 0.1),
          reason: 'a near-255 red pixel should scale to near-1.0, the real '
              'contract SceneDetectorV2 was trained on');
    });
  });
}
