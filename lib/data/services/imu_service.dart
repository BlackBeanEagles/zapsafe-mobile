import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../models/fall_event.dart';
import '../models/motion_features.dart';
import 'fall_detector.dart';

/// Day 36 — wraps `sensors_plus` accelerometer + gyroscope streams and
/// produces:
///
///   • A periodic [MotionFeatures] snapshot (mean / variance / peak for
///     accel + gyro magnitudes over the most recent 450 ms — matches the
///     audio capture cadence so the DCS engine can align inputs).
///   • A [FallEvent] stream backed by [FallDetector].
///
/// The service is idle until [start] is called. Subscriptions stop on
/// [stop] or [dispose]. Safe to subscribe to either stream before
/// starting — the broadcast controllers buffer-free emit only after the
/// service is alive.
///
/// **Platform note**: `sensors_plus` is Android + iOS only. On other
/// platforms `accelerometerEventStream()` returns a stream that simply
/// never emits — we wrap it in try/catch on subscribe so the service
/// doesn't crash on a Windows host VM. [supported] tells callers if the
/// service can produce real data.
class ImuService {
  /// 450 ms × 100 Hz (typical sensor rate) ≈ 45 samples per window.
  static const int _windowSamples = 45;

  /// Emit one [MotionFeatures] per [emitIntervalMs] of wall-clock time.
  /// Matches the audio capture cadence so the DCS engine can pair an
  /// audio frame with a fresh motion snapshot.
  static const int emitIntervalMs = 450;

  final FallDetector _detector = FallDetector();

  // Sliding magnitude buffers for the 450 ms feature window.
  final List<double> _accelMags = <double>[];
  final List<double> _gyroMags = <double>[];

  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;

  final _featuresController =
      StreamController<MotionFeatures>.broadcast();
  final _fallController = StreamController<FallEvent>.broadcast();

  int _lastEmitMs = 0;

  /// Last sample seen — handy for UIs that want a live magnitude
  /// readout without subscribing to the full features stream.
  double _liveAccelMag = 0;
  double _liveGyroMag = 0;

  double get liveAccelMagnitude => _liveAccelMag;
  double get liveGyroMagnitude => _liveGyroMag;
  FallDetectorState get detectorState => _detector.state;

  bool _running = false;
  bool get isRunning => _running;

  /// Broadcast stream of feature snapshots, one per [emitIntervalMs].
  Stream<MotionFeatures> get features => _featuresController.stream;

  /// Broadcast stream of detected falls.
  Stream<FallEvent> get falls => _fallController.stream;

  /// Most recent feature snapshot, or null if none emitted yet. Used by
  /// the DCS stream provider to read motion synchronously per audio
  /// frame (no need to merge streams).
  MotionFeatures? _latestFeatures;
  MotionFeatures? get latestFeatures => _latestFeatures;

  /// Begins listening to the sensor streams. Idempotent — calling
  /// while already running is a no-op.
  ///
  /// Returns true if at least one stream subscribed. False indicates an
  /// unsupported platform or a sensor-plugin error; the service stays
  /// dormant and consumers get an empty stream.
  Future<bool> start() async {
    if (_running) return true;
    var subscribedAny = false;
    try {
      _accelSub = accelerometerEventStream().listen(
        _onAccel,
        onError: (Object e) {
          if (kDebugMode) debugPrint('[imu] accel stream error: $e');
        },
        cancelOnError: false,
      );
      subscribedAny = true;
    } catch (e) {
      if (kDebugMode) debugPrint('[imu] accel subscribe failed: $e');
    }
    try {
      _gyroSub = gyroscopeEventStream().listen(
        _onGyro,
        onError: (Object e) {
          if (kDebugMode) debugPrint('[imu] gyro stream error: $e');
        },
        cancelOnError: false,
      );
      subscribedAny = true;
    } catch (e) {
      if (kDebugMode) debugPrint('[imu] gyro subscribe failed: $e');
    }
    if (subscribedAny) _running = true;
    return _running;
  }

  /// Cancel sensor subscriptions and clear buffers. The features /
  /// falls streams stay open — callers don't need to re-subscribe to
  /// resume.
  Future<void> stop() async {
    await _accelSub?.cancel();
    await _gyroSub?.cancel();
    _accelSub = null;
    _gyroSub = null;
    _accelMags.clear();
    _gyroMags.clear();
    _running = false;
    _detector.reset();
  }

  /// Permanently release resources. The streams close — re-subscribing
  /// requires building a new [ImuService].
  Future<void> dispose() async {
    await stop();
    await _featuresController.close();
    await _fallController.close();
  }

  /// Day 36 — directly feed a synthetic acceleration sample. Used by
  /// the Day 36 screen to simulate a fall without dropping the phone,
  /// and by tests to drive the service deterministically.
  ///
  /// Production code on a device never calls this — the sensor streams
  /// flow through [_onAccel] instead.
  @visibleForTesting
  void injectAccel(double x, double y, double z, {int? timestampMs}) {
    _onAccel(
      AccelerometerEvent(x, y, z),
      overrideTimestampMs: timestampMs,
    );
  }

  void _onAccel(AccelerometerEvent e, {int? overrideTimestampMs}) {
    final mag = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
    _liveAccelMag = mag;
    _accelMags.add(mag);
    if (_accelMags.length > _windowSamples) {
      _accelMags.removeAt(0);
    }
    final ts = overrideTimestampMs ?? DateTime.now().millisecondsSinceEpoch;

    final fall = _detector.observe(mag, timestampMs: ts);
    if (fall != null && !_fallController.isClosed) {
      _fallController.add(fall);
    }

    _maybeEmitFeatures(ts);
  }

  void _onGyro(GyroscopeEvent e) {
    final mag = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
    _liveGyroMag = mag;
    _gyroMags.add(mag);
    if (_gyroMags.length > _windowSamples) {
      _gyroMags.removeAt(0);
    }
  }

  void _maybeEmitFeatures(int nowMs) {
    if (nowMs - _lastEmitMs < emitIntervalMs) return;
    if (_accelMags.isEmpty) return;
    _lastEmitMs = nowMs;
    final f = _buildFeatures(nowMs);
    _latestFeatures = f;
    if (!_featuresController.isClosed) {
      _featuresController.add(f);
    }
  }

  MotionFeatures _buildFeatures(int nowMs) {
    final accelStats = _stats(_accelMags);
    final gyroStats  = _stats(_gyroMags);
    return MotionFeatures(
      timestampMs: nowMs,
      accelMean: accelStats.mean,
      accelVar:  accelStats.variance,
      accelPeak: accelStats.peak,
      gyroMean:  gyroStats.mean,
      gyroVar:   gyroStats.variance,
      gyroPeak:  gyroStats.peak,
    );
  }

  _SignalStats _stats(List<double> samples) {
    if (samples.isEmpty) return const _SignalStats(0, 0, 0);
    final n = samples.length;
    var sum = 0.0;
    var peak = 0.0;
    for (final s in samples) {
      sum += s;
      if (s > peak) peak = s;
    }
    final mean = sum / n;
    var varSum = 0.0;
    for (final s in samples) {
      final d = s - mean;
      varSum += d * d;
    }
    return _SignalStats(mean, varSum / n, peak);
  }
}

class _SignalStats {
  final double mean;
  final double variance;
  final double peak;
  const _SignalStats(this.mean, this.variance, this.peak);
}
