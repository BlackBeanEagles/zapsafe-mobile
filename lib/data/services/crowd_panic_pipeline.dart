import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../native/pcm_window.dart';
import '../models/inference_result.dart';
import 'crowd_panic_detector.dart';
import 'motion_detector_b.dart';

/// Day 265 — joins the native rolling-PCM audio stream *and* the
/// accelerometer/gyroscope stream to `CrowdPanicDetector`, ZapSafe's first
/// two-input (audio + IMU fusion) detection pipeline.
///
/// ## Concurrent-capture design decision
///
/// Unlike every other detector wired so far, this model needs **two
/// independent, asynchronous hardware streams to agree on a single
/// inference call**: the audio stream ships a window roughly once a second
/// (`AudioCaptureService`'s 1 s hop), the IMU stream ships an accelerometer
/// sample roughly every ~10-20 ms and a new [MotionWindowBufferB] window
/// every `hop` samples. These arrive on independent timers with no built-in
/// synchronisation, so "wait for both to arrive at exactly the same
/// instant" is not achievable, and blocking one stream on the other would
/// add latency and coupling the individual streams don't have anywhere
/// else in this app.
///
/// **Design decision: cache the most recent window from each side and fire
/// an inference whenever *either* side produces a fresh window, as long as
/// the *other* side's cached window is still within [maxStalenessMs] of
/// "now".** Concretely:
///
///  * A new audio window arrives -> cache it -> if the cached IMU window is
///    fresher than [maxStalenessMs], run inference immediately.
///  * A new IMU window arrives -> cache it -> if the cached audio window is
///    fresher than [maxStalenessMs], run inference immediately.
///  * If the other side has never produced a window yet, or its last
///    window is older than [maxStalenessMs], **no inference runs** — this
///    pipeline never feeds the model a stale or fabricated stand-in for a
///    missing stream. `windowsSkippedStale` counts these so it's visible in
///    telemetry rather than silently degrading to a single-input mode that
///    was never trained.
///
/// [maxStalenessMs] defaults to 2500 ms — comfortably wider than the 2.0 s
/// audio window used by `CrowdPanicDetector`'s own training duration and the
/// audio stream's ~1 s hop, but tight enough that a "crush at time T, panic
/// audio landing 10s later" pairing (which would misrepresent the model's
/// trained assumption of a roughly-simultaneous event) does not fire.
///
/// This trades perfect synchrony (impossible without blocking one sensor on
/// the other) for "never infer on data either side would call stale" — the
/// same posture `MotionDetectorB`'s "second, independent detector" decision
/// took for a different problem (avoid silently changing verified
/// behaviour); here it's "avoid silently inventing simultaneity between two
/// streams that were never guaranteed to align".
class CrowdPanicFusionPipeline {
  /// Same silence gate as `GunshotAudioPipeline`/`ScreamAudioPipeline` — a
  /// crowd-panic audio signature is loud; a near-silent window isn't worth
  /// caching, let alone paying for a fused inference.
  static const double kSilenceRms = 0.005;

  final CrowdPanicDetector detector;
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
  double _maxPanicScore = 0;

  CrowdPanicFusionPipeline({
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
  double get maxPanicScore => _maxPanicScore;

  void start() {
    if (_audioSub != null) return;
    _audioSub = audioWindows.listen(_onAudioWindow, onError: (Object e) {
      if (kDebugMode) debugPrint('[CrowdPanicFusionPipeline] audio error: $e');
    });
    try {
      _gyroSub = gyroscopeEventStream().listen((e) {
        _gx = e.x;
        _gy = e.y;
        _gz = e.z;
      }, onError: (Object e) {
        if (kDebugMode) debugPrint('[CrowdPanicFusionPipeline] gyro error: $e');
      });
      _accelSub =
          accelerometerEventStream().listen(_onAccel, onError: (Object e) {
        if (kDebugMode) debugPrint('[CrowdPanicFusionPipeline] accel error: $e');
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[CrowdPanicFusionPipeline] start failed: $e');
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
    final pcm = window.samples(targetRateHz: CrowdPanicDetector.kSampleRate);
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
      final panic = result.classScores['panic'] ?? 0.0;
      if (panic > _maxPanicScore) _maxPanicScore = panic;
      if (!_results.isClosed) _results.add(result);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[CrowdPanicFusionPipeline] inference failed: $e\n$st');
      }
    } finally {
      _busy = false;
    }
  }
}
