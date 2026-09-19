import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../models/inference_result.dart';
import 'motion_detector_v2.dart';

/// Day 259 — joins real accelerometer hardware to the fall detector.
/// Day 323: gyroscope dropped; motion_fall_v2 is 3-channel accelerometer
/// only (m/s^2 including gravity), so the gyro stream was pure battery
/// cost. See MotionDetectorV2's doc for why padding gyro would be worse.
///
/// Uses `sensors_plus` directly rather than the custom
/// `com.zapsafe/sensors.events` native channel: `ImuService` already proves
/// that package reads real hardware in this app, and today's priority is a
/// working detector over a second implementation of the same thing.
/// `SensorChannelHandler.kt` was still fixed to emit real readings (it no
/// longer synthesizes a 10 Hz sine) for whatever else ends up consuming that
/// channel, but this pipeline does not depend on it.
///
/// Only the accelerometer is subscribed now. It arrives at a device-dependent
/// rate and paces the window directly — there is no second stream to fuse
/// with, since `MotionDetectorV2`'s fixed 50 Hz / 100-sample
/// window assumption only has to be approximately honoured: the model was
/// trained on window *shape*, not a hardware-exact sample clock.
class MotionAudioPipeline {
  final MotionDetectorV2 detector;
  final MotionWindowBuffer buffer;

  StreamSubscription<AccelerometerEvent>? _accelSub;
  final _results = StreamController<InferenceResult>.broadcast();

  bool _busy = false;

  int _samplesIn = 0;
  int _inferences = 0;
  int _droppedBusy = 0;
  double _maxFallScore = 0;
  InferenceResult? _latestResult;

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

  /// The most recent real inference, or null before the first full
  /// window. Day 327: `DCSInferenceEngine` consumes this instead of
  /// running its own motion inference, so the windowed model runs once
  /// per window rather than twice.
  InferenceResult? get latestResult => _latestResult;

  void start() {
    if (_accelSub != null) return;
    try {
      // Day 323: no gyroscope subscription. motion_fall_v2 takes 3
      // accelerometer channels, so listening to the gyro would burn battery
      // on a stream nothing reads.
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
    _accelSub = null;
    buffer.clear();
  }

  Future<void> dispose() async {
    await stop();
    await _results.close();
  }

  Future<void> _onAccel(AccelerometerEvent e) async {
    _samplesIn++;
    // Day 323: 3 channels. The model no longer takes gyro -- see
    // MotionDetectorV2's doc for why padding it would be worse than
    // dropping it.
    final window = buffer.add([e.x, e.y, e.z]);
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
      _latestResult = result;
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
