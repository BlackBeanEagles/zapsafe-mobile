import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../models/inference_result.dart';
import 'motion_detector_v2.dart';

/// Day 259 — joins real accelerometer + gyroscope hardware to m2_motion_v2.
///
/// Uses `sensors_plus` directly rather than the custom
/// `com.zapsafe/sensors.events` native channel: `ImuService` already proves
/// that package reads real hardware in this app, and today's priority is a
/// working detector over a second implementation of the same thing.
/// `SensorChannelHandler.kt` was still fixed to emit real readings (it no
/// longer synthesizes a 10 Hz sine) for whatever else ends up consuming that
/// channel, but this pipeline does not depend on it.
///
/// Accelerometer and gyroscope arrive as two independent streams at
/// different, device-dependent rates. Each sample is fused with the most
/// recently seen reading from the other sensor — the same approach
/// `SensorChannelHandler.kt` takes natively — and paced by the
/// accelerometer, since `MotionDetectorV2`'s fixed 50 Hz / 100-sample
/// window assumption only has to be approximately honoured: the model was
/// trained on window *shape*, not a hardware-exact sample clock.
class MotionAudioPipeline {
  final MotionDetectorV2 detector;
  final MotionWindowBuffer buffer;

  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  final _results = StreamController<InferenceResult>.broadcast();

  double _gx = 0, _gy = 0, _gz = 0;
  bool _busy = false;

  int _samplesIn = 0;
  int _inferences = 0;
  int _droppedBusy = 0;
  double _maxFallScore = 0;

  MotionAudioPipeline({
    required this.detector,
    int hopSamples = 25,
  }) : buffer = MotionWindowBuffer(hop: hopSamples);

  Stream<InferenceResult> get results => _results.stream;

  bool get isActive => _accelSub != null;

  int get samplesIn => _samplesIn;
  int get inferences => _inferences;
  int get droppedBusy => _droppedBusy;
  double get maxFallScore => _maxFallScore;

  void start() {
    if (_accelSub != null) return;
    try {
      _gyroSub = gyroscopeEventStream().listen((e) {
        _gx = e.x;
        _gy = e.y;
        _gz = e.z;
      }, onError: (Object e) {
        if (kDebugMode) debugPrint('[MotionAudioPipeline] gyro error: $e');
      });
      _accelSub = accelerometerEventStream().listen(_onAccel, onError: (Object e) {
        if (kDebugMode) debugPrint('[MotionAudioPipeline] accel error: $e');
      });
    } catch (e) {
      // No sensor support on this platform (e.g. desktop dev host).
      if (kDebugMode) debugPrint('[MotionAudioPipeline] start failed: $e');
    }
  }

  Future<void> stop() async {
    await _accelSub?.cancel();
    await _gyroSub?.cancel();
    _accelSub = null;
    _gyroSub = null;
    buffer.clear();
  }

  Future<void> dispose() async {
    await stop();
    await _results.close();
  }

  Future<void> _onAccel(AccelerometerEvent e) async {
    _samplesIn++;
    final window = buffer.add([e.x, e.y, e.z, _gx, _gy, _gz]);
    if (window == null || _busy) {
      if (window != null) _droppedBusy++;
      return;
    }

    _busy = true;
    try {
      final result = await detector.inferRaw(
        window,
        timestampMs: DateTime.now().millisecondsSinceEpoch,
      );
      _inferences++;
      final fall = result.classScores['fall'] ?? 0.0;
      if (fall > _maxFallScore) _maxFallScore = fall;
      if (!_results.isClosed) _results.add(result);
    } catch (e) {
      if (kDebugMode) debugPrint('[MotionAudioPipeline] inference failed: $e');
    } finally {
      _busy = false;
    }
  }
}
