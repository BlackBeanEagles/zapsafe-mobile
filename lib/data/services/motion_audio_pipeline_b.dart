import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../models/inference_result.dart';
import 'motion_detector_b.dart';

/// Day 262 — joins real accelerometer + gyroscope hardware to
/// `m2_motion_b_retrain` (`MotionDetectorB`).
///
/// A second, independent pipeline running alongside `MotionAudioPipeline`
/// (m2_motion_v2) — see `motion_detector_b.dart`'s class doc for why this
/// is a distinct detector rather than a replacement or an ensemble fusion.
/// Structurally identical to `MotionAudioPipeline`: same dual
/// accelerometer/gyroscope stream fusion approach, different window size
/// (128 samples via [MotionWindowBufferB] vs 100).
class MotionAudioPipelineB {
  final MotionDetectorB detector;
  final MotionWindowBufferB buffer;

  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  final _results = StreamController<InferenceResult>.broadcast();

  double _gx = 0, _gy = 0, _gz = 0;
  bool _busy = false;

  int _samplesIn = 0;
  int _inferences = 0;
  int _droppedBusy = 0;
  double _maxFallScore = 0;

  MotionAudioPipelineB({
    required this.detector,
    int hopSamples = 32,
  }) : buffer = MotionWindowBufferB(hop: hopSamples);

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
        if (kDebugMode) debugPrint('[MotionAudioPipelineB] gyro error: $e');
      });
      _accelSub = accelerometerEventStream().listen(_onAccel, onError: (Object e) {
        if (kDebugMode) debugPrint('[MotionAudioPipelineB] accel error: $e');
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[MotionAudioPipelineB] start failed: $e');
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
      if (kDebugMode) debugPrint('[MotionAudioPipelineB] inference failed: $e');
    } finally {
      _busy = false;
    }
  }
}
