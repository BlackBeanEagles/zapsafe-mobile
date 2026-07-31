import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../models/inference_result.dart';
import 'k_confinement_detector.dart';
import 'motion_detector_b.dart';

/// Day 273 — drives [KConfinementDetector] from the accelerometer/gyroscope
/// stream, following `MotionWindowBufferB`'s windowing pattern already used
/// by `MotionDetectorB`/`VehicleCrashFusionPipeline`.
///
/// ## The light-sensor gap — read this before treating this pipeline as
/// ## "fully wired"
///
/// `k_confinement`'s real model signature needs a `light` input (a broadcast
/// ambient-light scalar, `[1,32,1]`, see `KConfinementDetector`'s doc
/// comment) — an input modality none of this app's other fusion models use
/// (`i_vehicle_crash`/`s_crowd_panic` are audio+IMU only). Investigated this
/// session:
///
/// 1. **No ambient-light-sensor integration exists anywhere in this app.**
///    Searched the whole `lib/` tree and `pubspec.yaml` for
///    `sensors_plus`'s `Light`/light-sensor APIs, `light_sensor`-style
///    packages, and any platform channel with "light"/"lux"/"ambient" in
///    its name — none found. `sensors_plus: ^4.0.0` (this app's pinned
///    version) does not expose an ambient-light stream at all (that API
///    only exists in much newer `sensors_plus` majors), so reusing an
///    existing integration is not possible.
/// 2. **No camera-exposure-brightness proxy is wired either** — this app
///    has no active camera-preview session running during background
///    detection (adding one solely to sample exposure metadata would be a
///    real new permission/battery/architecture change, not a small wiring
///    step, and photosensor Kaggle Day 269/272 docs never proposed this as
///    the intended input anyway — they explicitly say "no real ambient-
///    light/lux dataset exists locally", i.e. the training data itself
///    never used a camera-exposure proxy, so wiring one here would not even
///    match what the model was trained on).
/// 3. **Decision (Option (c) from this task's brief): ship the IMU side for
///    real, and use an explicit, documented, fixed-safe-default light
///    value for the light input rather than fabricating a fake "real"
///    sensor reading.** [kPlaceholderLightValue] (0.5) sits mid-range
///    between the model's trained dark (0.0-0.1) and lit (0.15-0.9) regimes
///    — deliberately not tuned to bias the model toward either the old
///    collapsed-output regime or a specific verdict. **This is a real,
///    stated limitation, not a hidden one**: [usesRealLightSensor] is
///    `false`, and every [InferenceResult] this pipeline produces is running
///    on real IMU data but a constant, non-sensed light value. Wiring a
///    real ambient-light reading (most likely via a native platform-channel
///    add-on, since `sensors_plus` doesn't carry one at this app's pinned
///    version) remains a real, separate follow-up — not done in this
///    session.
class KConfinementFusionPipeline {
  /// Mid-range placeholder between the model's trained dark (0.0-0.1) and
  /// lit (0.15-0.9) light regimes. **Not a sensor reading** — see the class
  /// doc comment above for why, and [usesRealLightSensor].
  static const double kPlaceholderLightValue = 0.5;

  /// Always `false` in this build: no real ambient-light sensor is wired.
  /// Exposed so callers/tests/UI can honestly surface "confinement
  /// detection is running on IMU-only + a placeholder light value" rather
  /// than silently presenting this as a fully-sensed two-input detector.
  static const bool usesRealLightSensor = false;

  final KConfinementDetector detector;
  final double lightValue;

  final MotionWindowBufferB _imuBuffer;

  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  final _results = StreamController<InferenceResult>.broadcast();

  double _gx = 0, _gy = 0, _gz = 0;
  bool _busy = false;

  int _imuWindowsIn = 0;
  int _inferences = 0;
  int _droppedBusy = 0;
  double _maxConfinedScore = 0;

  KConfinementFusionPipeline({
    required this.detector,
    this.lightValue = kPlaceholderLightValue,
    int imuHopSamples = 32,
  }) : _imuBuffer = MotionWindowBufferB(hop: imuHopSamples);

  Stream<InferenceResult> get results => _results.stream;

  bool get isActive => _accelSub != null;

  int get imuWindowsIn => _imuWindowsIn;
  int get inferences => _inferences;
  int get droppedBusy => _droppedBusy;
  double get maxConfinedScore => _maxConfinedScore;

  void start() {
    if (_accelSub != null) return;
    try {
      _gyroSub = gyroscopeEventStream().listen((e) {
        _gx = e.x;
        _gy = e.y;
        _gz = e.z;
      }, onError: (Object e) {
        if (kDebugMode) debugPrint('[KConfinementFusionPipeline] gyro error: $e');
      });
      _accelSub =
          accelerometerEventStream().listen(_onAccel, onError: (Object e) {
        if (kDebugMode) debugPrint('[KConfinementFusionPipeline] accel error: $e');
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[KConfinementFusionPipeline] start failed: $e');
    }
  }

  Future<void> stop() async {
    await _accelSub?.cancel();
    await _gyroSub?.cancel();
    _accelSub = null;
    _gyroSub = null;
    _imuBuffer.clear();
  }

  Future<void> dispose() async {
    await stop();
    await _results.close();
  }

  Future<void> _onAccel(AccelerometerEvent e) async {
    final window = _imuBuffer.add([e.x, e.y, e.z, _gx, _gy, _gz]);
    if (window == null) return;
    _imuWindowsIn++;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (_busy) {
      _droppedBusy++;
      return;
    }
    _busy = true;
    try {
      final result = await detector.inferFused(
        imuWindow: window,
        lightValue: lightValue,
        timestampMs: now,
      );
      _inferences++;
      final confined = result.classScores['confined'] ?? 0.0;
      if (confined > _maxConfinedScore) _maxConfinedScore = confined;
      if (!_results.isClosed) _results.add(result);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[KConfinementFusionPipeline] inference failed: $e\n$st');
      }
    } finally {
      _busy = false;
    }
  }
}
