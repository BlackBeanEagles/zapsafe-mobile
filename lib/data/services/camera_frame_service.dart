import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';

import 'scene_detector_v2.dart';

/// Day 316 — the real camera-capture pipeline this app never had.
///
/// Was: `SceneDetectorV2` (Day 315) made the real UCF-Crime-trained model
/// loadable and callable given a real 224×224×3 frame, but nothing in the
/// app actually produced one — no `camera` package dependency, no
/// `CameraController` usage anywhere, confirmed by grep both when
/// `SceneDetectorV2` was built and independently again here. This class
/// closes that specific gap: capture a real frame from the device camera,
/// preprocess it into exactly the tensor [SceneDetectorV2.infer] expects.
///
/// Deliberately uses periodic still-image capture (`takePicture()`), not a
/// continuous `startImageStream()`. Three real reasons, not just
/// convenience:
///   1. `startImageStream()` hands back raw platform-native frames —
///      YUV_420_888 on Android, BGRA8888 on iOS — which need real,
///      platform-specific colour-space conversion before they're usable
///      RGB. A JPEG from `takePicture()` is a real, standard, portable
///      format `package:image` already decodes correctly on both
///      platforms with no per-platform branching.
///   2. This is a periodic *scene check* (matching [ScenePollingProfile]'s
///      cadence — minutes apart while monitoring, seconds apart only
///      during an active alert/SOS), not real-time video analysis. A
///      continuous stream would hold the camera hardware open and drain
///      battery for a use case that only needs one frame every 15s-5min.
///   3. Privacy: a discrete, on-demand still capture (immediately decoded
///      to a tensor and discarded — see [captureSceneRgb]) is a smaller,
///      more auditable surface than an open continuous video feed for a
///      background safety process.
class CameraFrameService {
  CameraController? _controller;
  bool _initializing = false;

  /// True once a controller is initialized and ready to capture.
  bool get isReady => _controller?.value.isInitialized ?? false;

  /// Ensures a [CameraController] is initialized on the rear camera
  /// (environment-facing — this is for scene/context awareness, not a
  /// selfie). Idempotent: safe to call before every capture.
  ///
  /// Returns false without throwing if camera permission isn't granted,
  /// or if no camera is available (e.g. this host VM, emulators without
  /// a virtual camera configured) — callers fall back to whatever they'd
  /// do if a frame simply wasn't available.
  Future<bool> ensureInitialized() async {
    if (isReady) return true;
    if (_initializing) return false; // a concurrent call is already on it
    _initializing = true;
    try {
      final status = await Permission.camera.status;
      if (!status.isGranted) return false;

      final cameras = await availableCameras();
      if (cameras.isEmpty) return false;

      final rear = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        rear,
        ResolutionPreset.low, // real frame gets downscaled to 224x224 anyway
        enableAudio: false, // this is a still-image scene check, not video
      );
      await controller.initialize();
      _controller = controller;
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CameraFrameService] ensureInitialized failed: $e');
      }
      await _controller?.dispose();
      _controller = null;
      return false;
    } finally {
      _initializing = false;
    }
  }

  /// Captures one real frame and returns it preprocessed exactly to
  /// [SceneDetectorV2]'s real contract — a flat `224*224*3` RGB byte list,
  /// row-major, ready for [SceneDetectorV2.normalise]/[SceneDetectorV2.
  /// inferRaw]. Returns null on any real failure (no permission, no
  /// camera, capture error, decode error) rather than throwing — a
  /// missing scene frame should never crash whatever polling loop is
  /// driving this.
  Future<List<int>?> captureSceneRgb() async {
    if (!await ensureInitialized()) return null;
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return null;

    XFile? file;
    try {
      file = await controller.takePicture();
      final jpegBytes = await File(file.path).readAsBytes();
      return jpegBytesToSceneRgb(jpegBytes);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CameraFrameService] captureSceneRgb failed: $e');
      }
      return null;
    } finally {
      // Discrete capture, immediately decoded above — delete the temp JPEG
      // rather than let it accumulate on disk. This is a scene-context
      // check, not evidence capture (that's a separate, deliberate flow
      // elsewhere in the app with its own retention policy).
      if (file != null) {
        try {
          await File(file.path).delete();
        } catch (_) {
          // Best-effort cleanup — a leftover temp file is not worth
          // failing the capture over.
        }
      }
    }
  }

  /// The real, pure-Dart preprocessing step: JPEG bytes → resized 224×224
  /// RGB → flat byte list, [SceneDetectorV2.kInputFloats] long.
  ///
  /// Split out as a static, camera-independent function specifically so
  /// it's unit-testable without a real camera or device — feed it real
  /// JPEG bytes (from `package:image`'s own encoder, or a real captured
  /// photo) and it exercises the exact decode/resize/flatten path
  /// production uses. This is where a real bug (wrong channel order,
  /// wrong resize interpolation silently distorting the frame, an
  /// off-by-one in the row-major flatten) would hide — exactly the class
  /// of bug this session has repeatedly found by checking real contracts
  /// instead of assuming a library "just works" the expected way.
  ///
  /// Returns null if the bytes don't decode as an image at all (corrupt
  /// capture, unexpected format, or truly empty input).
  ///
  /// Wrapped in try/catch, not just a null check — a real test against
  /// empty bytes found that `package:image`'s own format-sniffing code
  /// (`decodeImage` → `findDecoderForData` → each decoder's
  /// `isValidFile`) indexes into the input buffer without a length guard
  /// first, so a truly empty (not just malformed) input throws a raw
  /// `RangeError` instead of returning null like the rest of the corrupt/
  /// unrecognised-format cases do. A camera glitch producing an empty
  /// capture must not crash whatever loop is calling this.
  static List<int>? jpegBytesToSceneRgb(Uint8List jpegBytes) {
    try {
      final decoded = img.decodeImage(jpegBytes);
      if (decoded == null) return null;

      final resized = img.copyResize(
        decoded,
        width: SceneDetectorV2.kImgSize,
        height: SceneDetectorV2.kImgSize,
        interpolation: img.Interpolation.linear,
      );

      final out = List<int>.filled(SceneDetectorV2.kInputFloats, 0);
      var i = 0;
      for (var y = 0; y < SceneDetectorV2.kImgSize; y++) {
        for (var x = 0; x < SceneDetectorV2.kImgSize; x++) {
          final pixel = resized.getPixel(x, y);
          out[i++] = pixel.r.toInt();
          out[i++] = pixel.g.toInt();
          out[i++] = pixel.b.toInt();
        }
      }
      return out;
    } catch (_) {
      return null;
    }
  }

  /// Releases the camera hardware. Call when scene capture stops (app
  /// backgrounded, AppState returns to idle) — holding the camera open
  /// indefinitely is both a battery drain and, on most platforms, shows
  /// the user an active-camera indicator that would be confusing outside
  /// an actual capture.
  Future<void> dispose() async {
    final controller = _controller;
    _controller = null;
    try {
      await controller?.dispose();
    } catch (_) {}
  }
}
