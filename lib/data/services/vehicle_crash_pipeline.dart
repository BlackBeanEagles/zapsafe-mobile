import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../native/pcm_window.dart';
import '../models/inference_result.dart';
import 'motion_detector_b.dart';
import 'vehicle_crash_detector.dart';

/// Day 271 — joins the native rolling-PCM audio stream *and* the
/// accelerometer/gyroscope stream to [VehicleCrashDetector], following
/// `CrowdPanicFusionPipeline`'s (`DAY265_CROWD_PANIC_WIRING.md`)
/// concurrent-capture design for ZapSafe's second two-input fusion model.
///
/// ## Concurrent-capture design — same posture as `CrowdPanicFusionPipeline`
///
/// The audio stream ships a window roughly once a second
/// (`AudioCaptureService`'s 1s hop); the IMU stream ships an accelerometer
/// sample roughly every ~10-20ms and a new [MotionWindowBufferB] window
/// every `hop` samples. There is no built-in instant where both are
/// simultaneously fresh, and blocking one stream on the other would add
/// latency no other pipeline in this app pays.
///
/// **Decision (identical to `CrowdPanicFusionPipeline`): cache the most
/// recent window from each side; fire a fused inference whenever either
/// side produces a fresh window, provided the other side's cached window is
/// within [maxStalenessMs] of now.** If the other side has never fired, or
/// its last window is older than [maxStalenessMs], **no inference runs** —
/// [windowsSkippedStale] counts this. This pipeline never fabricates a
/// missing side's data.
///
/// [maxStalenessMs] defaults to 2500ms, the same default
/// `CrowdPanicFusionPipeline` uses and for the same reason: comfortably
/// wider than the 2.0s audio window `VehicleCrashDetector` was trained on
/// and the audio stream's ~1s hop, tight enough that an audio window and an
/// IMU window from genuinely different physical moments don't get paired
/// as if simultaneous.
class VehicleCrashFusionPipeline {
  /// Same silence gate convention as `GunshotAudioPipeline`/
  /// `CrowdPanicFusionPipeline` — a vehicle-crash audio signature (impact,
  /// glass, metal) is loud; a near-silent window isn't worth a fused
  /// inference.
  static const double kSilenceRms = 0.005;

  final VehicleCrashDetector detector;
  final Stream<PcmWindow> audioWindows;
  final int maxStalenessMs;
  final bool gateOnSilence;

  final MotionWindowBufferB _imuBuffer;

  StreamSubscription<PcmWindow>? _audioSub;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  final _results = StreamController<InferenceResult>.broadcast();

  double _gx = 0, _gy = 0, _gz = 0;
  bool _busy = false;

  Float64List? _lastPcm;
  int _lastPcmAtMs = 0;
  List<List<double>>? _lastImuWindow;
  int _lastImuAtMs = 0;

  int _audioWindowsIn = 0;
  int _imuWindowsIn = 0;
  int _inferences = 0;
  int _windowsSkippedStale = 0;
  int _droppedBusy = 0;
  int _droppedSilent = 0;
  double _maxCrashScore = 0;

  VehicleCrashFusionPipeline({
    required this.detector,
    required this.audioWindows,
    this.maxStalenessMs = 2500,
    this.gateOnSilence = true,
    int imuHopSamples = 32,
  }) : _imuBuffer = MotionWindowBufferB(hop: imuHopSamples);

  Stream<InferenceResult> get results => _results.stream;

  bool get isActive => _audioSub != null;

  int get audioWindowsIn => _audioWindowsIn;
  int get imuWindowsIn => _imuWindowsIn;
  int get inferences => _inferences;
  int get windowsSkippedStale => _windowsSkippedStale;
  int get droppedBusy => _droppedBusy;
  int get droppedSilent => _droppedSilent;
  double get maxCrashScore => _maxCrashScore;

  void start() {
    if (_audioSub != null) return;
    _audioSub = audioWindows.listen(_onAudioWindow, onError: (Object e) {
      if (kDebugMode) debugPrint('[VehicleCrashFusionPipeline] audio error: $e');
    });
    try {
      _gyroSub = gyroscopeEventStream().listen((e) {
        _gx = e.x;
        _gy = e.y;
        _gz = e.z;
      }, onError: (Object e) {
        if (kDebugMode) debugPrint('[VehicleCrashFusionPipeline] gyro error: $e');
      });
      _accelSub =
          accelerometerEventStream().listen(_onAccel, onError: (Object e) {
        if (kDebugMode) debugPrint('[VehicleCrashFusionPipeline] accel error: $e');
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[VehicleCrashFusionPipeline] start failed: $e');
    }
  }

  Future<void> stop() async {
    await _audioSub?.cancel();
    await _accelSub?.cancel();
    await _gyroSub?.cancel();
    _audioSub = null;
    _accelSub = null;
    _gyroSub = null;
    _imuBuffer.clear();
    _lastPcm = null;
    _lastImuWindow = null;
  }

  Future<void> dispose() async {
    await stop();
    await _results.close();
  }

  Future<void> _onAudioWindow(PcmWindow window) async {
    _audioWindowsIn++;
    if (!window.isUsable) return;
    if (gateOnSilence && window.rms < kSilenceRms) {
      _droppedSilent++;
      return;
    }
    final pcm = window.samples(targetRateHz: VehicleCrashDetector.kSampleRate);
    if (pcm.isEmpty) return;

    _lastPcm = pcm;
    _lastPcmAtMs = window.timestampMs;
    await _maybeInfer(nowMs: window.timestampMs);
  }

  Future<void> _onAccel(AccelerometerEvent e) async {
    final window = _imuBuffer.add([e.x, e.y, e.z, _gx, _gy, _gz]);
    if (window == null) return;
    _imuWindowsIn++;
    final now = DateTime.now().millisecondsSinceEpoch;
    _lastImuWindow = window;
    _lastImuAtMs = now;
    await _maybeInfer(nowMs: now);
  }

  Future<void> _maybeInfer({required int nowMs}) async {
    final pcm = _lastPcm;
    final imu = _lastImuWindow;
    if (pcm == null || imu == null) return; // one side has never fired yet

    final pcmAge = nowMs - _lastPcmAtMs;
    final imuAge = nowMs - _lastImuAtMs;
    if (pcmAge > maxStalenessMs || imuAge > maxStalenessMs) {
      _windowsSkippedStale++;
      return;
    }
    if (_busy) {
      _droppedBusy++;
      return;
    }

    _busy = true;
    try {
      final result = await detector.inferFused(
        pcm: pcm,
        imuWindow: imu,
        timestampMs: nowMs,
      );
      _inferences++;
      final crash = result.classScores['crash'] ?? 0.0;
      if (crash > _maxCrashScore) _maxCrashScore = crash;
      if (!_results.isClosed) _results.add(result);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[VehicleCrashFusionPipeline] inference failed: $e\n$st');
      }
    } finally {
      _busy = false;
    }
  }
}
