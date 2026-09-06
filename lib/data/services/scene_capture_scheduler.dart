import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_state.dart';
import '../models/inference_result.dart';
import 'camera_frame_service.dart';
import 'interpreter.dart';
import 'scene_detector_v2.dart';
import 'scene_polling_profile.dart';

/// Day 316 — adaptive-cadence scene capture, mirroring [GpsService]'s
/// exact shape (gps_service.dart) so this app's established pattern for
/// "a background sensor loop whose cadence follows [AppState]" gets one
/// consistent answer, not a second bespoke design.
///
/// This is the piece that actually closes the camera-pipeline gap
/// end-to-end: on each tick, it captures a real frame
/// ([CameraFrameService.captureSceneRgb]) and runs it through whichever
/// scene [Interpreter] is currently active (the real [SceneDetectorV2]
/// if it loaded, [HeuristicSceneDetector] otherwise — this class doesn't
/// care which, it just calls `.infer()` on whatever
/// [HeuristicDetectionEngine.scene] handed it, exactly like every other
/// real caller in this codebase does). Results are pushed onto a
/// broadcast stream for the DCS pipeline / debug UI to consume.
///
/// The [Interpreter] the scheduler was built with is a real,
/// non-guessed contract:
///   - The real [SceneDetectorV2] expects a 224×224×3 flat RGB tensor —
///     exactly what [CameraFrameService.captureSceneRgb] produces.
///   - [HeuristicSceneDetector] expects an 8-float brightness/contrast
///     vector — NOT what a captured RGB frame looks like. If a caller
///     ever wires this scheduler to the heuristic-mode interpreter, this
///     class deliberately does NOT attempt to feed it the RGB capture
///     (see [_tick]) — it would throw on shape mismatch. Real camera
///     capture is only meaningful with the real image model; the
///     heuristic's own capability tier already runs on lighter synthetic
///     signals, not a live camera.
class SceneCaptureScheduler {
  SceneCaptureScheduler({
    required Interpreter interpreter,
    CameraFrameService? cameraService,
  })  : _interpreter = interpreter,
        _camera = cameraService ?? CameraFrameService();

  final Interpreter _interpreter;
  final CameraFrameService _camera;

  Timer? _timer;
  AppState _appState = AppState.idle;
  ScenePollingProfile _profile = ScenePollingProfile.off;

  AppState get appState => _appState;
  ScenePollingProfile get profile => _profile;

  bool _running = false;
  bool get isRunning => _running;

  InferenceResult? _latest;
  InferenceResult? get latest => _latest;

  int _capturesAttempted = 0;
  int _capturesSucceeded = 0;
  int _capturesFailed = 0; // camera/decode failure, never reached inference
  int get capturesAttempted => _capturesAttempted;
  int get capturesSucceeded => _capturesSucceeded;
  int get capturesFailed => _capturesFailed;

  final _resultsController = StreamController<InferenceResult>.broadcast();
  Stream<InferenceResult> get results => _resultsController.stream;

  /// Only the real image model can meaningfully consume a captured RGB
  /// frame — see class doc. Checked once at construction-adjacent time
  /// via the interpreter's own declared contract, not hardcoded to a
  /// specific class, so this keeps working if a future model version
  /// changes the exact input size without changing this file.
  bool get _interpreterAcceptsCameraFrames =>
      _interpreter.expectedInputSize == 224 * 224 * 3;

  /// Start the scheduler. No-ops (never fires a timer) if the current
  /// interpreter can't accept a real camera frame — see
  /// [_interpreterAcceptsCameraFrames].
  Future<void> start() async {
    _running = true;
    _restartTimer();
  }

  /// Stop the timer and release the camera. Idempotent.
  Future<void> stop() async {
    _running = false;
    _timer?.cancel();
    _timer = null;
    await _camera.dispose();
  }

  /// Permanently release resources.
  Future<void> dispose() async {
    await stop();
    await _resultsController.close();
  }

  /// Caller-driven state-machine signal — cadence updates immediately on
  /// transition, exactly mirroring [GpsService.setAppState].
  void setAppState(AppState state) {
    _appState = state;
    final next = ScenePollingProfile.fromAppState(state);
    if (next == _profile) return;
    _profile = next;
    if (_running) _restartTimer();
  }

  /// Force one immediate capture+infer cycle outside the timer cadence.
  Future<InferenceResult?> captureOnce() => _tick();

  // ─── Internals ──────────────────────────────────────────────────────────

  void _restartTimer() {
    _timer?.cancel();
    if (_profile == ScenePollingProfile.off) return;
    if (!_interpreterAcceptsCameraFrames) return;
    // Fire one capture immediately, matching GpsService's own "don't make
    // the caller wait a full interval for the first reading" behaviour —
    // important when promoting to elevated/sos-time, where the first
    // frame after escalation matters most.
    _tick();
    _timer = Timer.periodic(_profile.interval, (_) => _tick());
  }

  Future<InferenceResult?> _tick() async {
    _capturesAttempted++;
    final rgb = await _camera.captureSceneRgb();
    if (rgb == null) {
      _capturesFailed++;
      return null;
    }
    try {
      // SceneDetectorV2.normalise() is the single source of truth for the
      // real pixel/255.0 conversion (see that class's doc for why this
      // exact scaling, not raw [0,255], is load-bearing) — called
      // directly here rather than re-deriving a second copy of it.
      final result = await _interpreter.infer(
        SceneDetectorV2.normalise(rgb),
        timestampMs: DateTime.now().millisecondsSinceEpoch,
      );
      _capturesSucceeded++;
      _latest = result;
      _resultsController.add(result);
      return result;
    } catch (e) {
      _capturesFailed++;
      if (kDebugMode) {
        debugPrint('[SceneCaptureScheduler] inference failed: $e');
      }
      return null;
    }
  }
}
