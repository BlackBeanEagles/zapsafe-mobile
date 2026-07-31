import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../models/inference_result.dart';
import 'k_confinement_detector.dart';
import 'light_sensor_channel.dart';
import 'motion_detector_b.dart';

/// Day 273 — drives [KConfinementDetector] from the accelerometer/gyroscope
/// stream, following `MotionWindowBufferB`'s windowing pattern already used
/// by `MotionDetectorB`/`VehicleCrashFusionPipeline`.
///
/// ## The light-sensor gap — Day 273 (placeholder) / Day 274 (Android real,
/// ## iOS still placeholder)
///
/// `k_confinement`'s real model signature needs a `light` input (a broadcast
/// ambient-light scalar, `[1,32,1]`, see `KConfinementDetector`'s doc
/// comment) — an input modality none of this app's other fusion models use
/// (`i_vehicle_crash`/`s_crowd_panic` are audio+IMU only).
///
/// **Day 273** shipped this pipeline IMU-real / light-placeholder: no
/// ambient-light integration existed anywhere in this app, and
/// `sensors_plus: ^4.0.0` (this app's pinned version) doesn't expose one.
///
/// **Day 274** closed the gap on Android only, investigated per-platform:
///
/// 1. **Android**: [Sensor.TYPE_LIGHT] has been in the platform
///    `SensorManager` API since API level 1 — it needs no `sensors_plus`
///    upgrade at all. Added as a small native Kotlin platform channel
///    (`LightSensorService.kt` / `LightChannelHandler.kt`, channel
///    `com.zapsafe/light`), mirroring `AudioCaptureService.kt`'s existing
///    capture/channel split. This pipeline now uses a real lux reading via
///    [AmbientLightChannel] on Android, mapped through [luxToModelLight] —
///    see that function's doc comment for why the lux-to-model-scalar
///    mapping is a documented heuristic, not a calibrated transform (the
///    model itself was never trained against real measured lux — Day 269/
///    272 both state "no real ambient-light/lux dataset exists locally").
/// 2. **iOS**: confirmed this session — Apple does not expose a general
///    ambient-light sensor to third-party apps. The only proxy is
///    `AVCaptureDevice` ISO/exposure metadata, which requires an active
///    camera-preview session this app doesn't run in the background (same
///    reasoning Day 273 already used to reject a camera-exposure proxy on
///    any platform). iOS therefore **stays on the Day 273 fixed placeholder
///    ([kPlaceholderLightValue])** — this is a real platform-parity
///    constraint, not an oversight, and is not silently presented as
///    equivalent to Android's real-sensor path: see [usesRealLightSensor],
///    an instance getter (not a build-wide const) that reflects whether
///    *this running instance* actually acquired a live sensor stream.
///
/// `pubspec.yaml` targets both `android/` and `ios/` (both platform
/// directories exist and are maintained; nothing in this app's config makes
/// it Android-only), so this Android-real/iOS-placeholder split is a real,
/// stated asymmetry, not a scoping shortcut.
class KConfinementFusionPipeline {
  /// Mid-range placeholder between the model's trained dark (0.0-0.1) and
  /// lit (0.15-0.9) light regimes. Used on iOS (no OS light-sensor API) and
  /// as the Android fallback when no physical light sensor is present or
  /// the native channel fails to start. **Not a sensor reading** in either
  /// case — see the class doc comment above, and [usesRealLightSensor].
  static const double kPlaceholderLightValue = 0.5;

  /// True: this build wires a real Android native light-sensor platform
  /// channel (`com.zapsafe/light`, [Sensor.TYPE_LIGHT]) — a compile-time
  /// capability flag, not a runtime guarantee. Whether a *specific running
  /// instance* actually has a live reading depends on platform and device
  /// hardware; see the instance getter [usesRealLightSensor] for that.
  static const bool androidLightSensorChannelWired = true;

  final KConfinementDetector detector;

  /// Fallback/initial light value before (or absent) a real sensor reading.
  /// On Android with a working sensor this is overwritten by real lux-
  /// derived readings once [start] acquires the stream; on iOS, or if the
  /// Android sensor never comes up, this constant value is used for every
  /// inference — see [usesRealLightSensor].
  final double lightValue;

  final AmbientLightChannel _lightChannel;
  final MotionWindowBufferB _imuBuffer;

  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  StreamSubscription<LightSensorReading>? _lightSub;
  final _results = StreamController<InferenceResult>.broadcast();

  double _gx = 0, _gy = 0, _gz = 0;
  bool _busy = false;

  double _currentLightValue = kPlaceholderLightValue;
  bool _liveLightSensorActive = false;
  double? _lastRawLux;

  int _imuWindowsIn = 0;
  int _inferences = 0;
  int _droppedBusy = 0;
  double _maxConfinedScore = 0;

  KConfinementFusionPipeline({
    required this.detector,
    this.lightValue = kPlaceholderLightValue,
    int imuHopSamples = 32,
    AmbientLightChannel? lightChannel,
  })  : _imuBuffer = MotionWindowBufferB(hop: imuHopSamples),
        _lightChannel = lightChannel ?? AmbientLightChannel(),
        _currentLightValue = lightValue;

  Stream<InferenceResult> get results => _results.stream;

  bool get isActive => _accelSub != null;

  int get imuWindowsIn => _imuWindowsIn;
  int get inferences => _inferences;
  int get droppedBusy => _droppedBusy;
  double get maxConfinedScore => _maxConfinedScore;

  /// True only while THIS instance is actually receiving live lux readings
  /// from the native Android sensor (started successfully, hardware
  /// present). False on iOS, false on Android devices/emulators without a
  /// light sensor, and false before [start] has had a chance to confirm the
  /// sensor came up — in all of those cases every inference this instance
  /// produces runs on [kPlaceholderLightValue] (or the caller-supplied
  /// [lightValue]) instead. This is the honest per-instance counterpart to
  /// [androidLightSensorChannelWired] (which only says the *code path*
  /// exists, not that it's live right now).
  bool get usesRealLightSensor => _liveLightSensorActive;

  /// Most recent raw lux reading from the native sensor, if any has arrived
  /// this session. Null on iOS and on Android before the first reading (or
  /// if no sensor is present). Exposed for diagnostics/UI, not used
  /// internally beyond feeding [luxToModelLight].
  double? get lastRawLux => _lastRawLux;

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
    unawaited(_startLightSensor());
  }

  /// Attempts to start the real Android light sensor. On iOS, or any
  /// platform/device where the native channel reports no sensor, this
  /// simply leaves [_liveLightSensorActive] false and every inference keeps
  /// using [lightValue] — a real, expected fallback, not an error.
  Future<void> _startLightSensor() async {
    try {
      final hasSensor = await _lightChannel.hasLightSensor();
      if (!hasSensor) {
        if (kDebugMode) {
          debugPrint('[KConfinementFusionPipeline] no live light sensor '
              '(iOS, or Android device without one) — using placeholder '
              '$lightValue');
        }
        return;
      }
      final started = await _lightChannel.start();
      if (!started) return;
      _liveLightSensorActive = true;
      _lightSub = _lightChannel.readings().listen((reading) {
        _lastRawLux = reading.lux;
        _currentLightValue = luxToModelLight(reading.lux);
      }, onError: (Object e) {
        if (kDebugMode) {
          debugPrint('[KConfinementFusionPipeline] light stream error: $e');
        }
        _liveLightSensorActive = false;
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[KConfinementFusionPipeline] light sensor start failed: $e');
      }
    }
  }

  Future<void> stop() async {
    await _accelSub?.cancel();
    await _gyroSub?.cancel();
    await _lightSub?.cancel();
    await _lightChannel.stop();
    _accelSub = null;
    _gyroSub = null;
    _lightSub = null;
    _liveLightSensorActive = false;
    _currentLightValue = lightValue;
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
        lightValue: _currentLightValue,
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
