import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/services.dart';

/// One ambient-light reading from the native `com.zapsafe/light` channel.
///
/// Raw lux, not the `k_confinement` model's `light` scalar — see
/// [luxToModelLight] for that mapping and why it's a documented heuristic,
/// not a calibrated transform.
class LightSensorReading {
  final int timestampMs;
  final double lux;

  const LightSensorReading({required this.timestampMs, required this.lux});

  /// Parses the `{t, lux}` map shipped by `LightChannelHandler.emitReading`.
  /// Throws [ArgumentError] on a malformed map rather than silently
  /// returning a zero/NaN reading, so a plumbing bug fails loudly.
  factory LightSensorReading.fromMap(Map<dynamic, dynamic> map) {
    final t = map['t'];
    final lux = map['lux'];
    if (t is! int && t is! double) {
      throw ArgumentError('LightSensorReading: missing/invalid "t" in $map');
    }
    if (lux is! num) {
      throw ArgumentError(
          'LightSensorReading: missing/invalid "lux" in $map');
    }
    return LightSensorReading(
      timestampMs: t is int ? t : (t as double).round(),
      lux: lux.toDouble(),
    );
  }

  @override
  String toString() => 'LightSensorReading(t=$timestampMs, lux=$lux)';
}

/// Maps a raw lux reading to `k_confinement`'s trained `light` scalar
/// (roughly `0.0` dark .. `0.9` lit — see `KConfinementDetector`'s doc
/// comment).
///
/// **This is a documented heuristic, not a calibrated transform.** The
/// model's training data (`day92_k_confinement.py` / `day272_k_confinement
/// _decorrelated.py`) never used real measured lux at all — its `light`
/// values (0.0-0.1 "dark", 0.15-0.9 "lit") are synthetic regime labels the
/// training scripts invented, and both scripts' own comments state "No
/// real ambient-light/lux dataset exists locally" (`DAY269_K_CONFINEMENT
/// _SCOPING.md`, `decorrelate_light()`'s docstring in the Day 272 script).
/// There is no ground-truth lux-to-`light` calibration to be faithful to.
///
/// This mapping uses a log-scale compression (lux spans several orders of
/// magnitude — <1 lux in true darkness, ~50-500 lux typical indoor, tens of
/// thousands outdoors) clamped into the model's trained range, using
/// standard photography/illuminance reference points:
/// - <= 1 lux (true darkness / pocket / bag / enclosed trunk-like space) -> 0.0
/// - ~50 lux (dim indoor) -> ~0.3
/// - ~500 lux (normal indoor) -> ~0.6
/// - >= 10 000 lux (daylight) -> 0.9 (clamped ceiling, matches the model's
///   trained lit ceiling — see `KConfinementFusionPipeline`'s doc comment)
///
/// If this mapping later proves miscalibrated against real device
/// behaviour, that is a real, separate follow-up — same posture as every
/// other "no real calibration data" gap this week.
double luxToModelLight(double lux) {
  const double darkLux = 1.0; // at/under this -> 0.0
  const double brightLux = 10000.0; // at/over this -> 0.9 ceiling
  const double outputCeiling = 0.9;

  if (lux <= darkLux) return 0.0;
  if (lux >= brightLux) return outputCeiling;

  // log-scale interpolation between darkLux and brightLux.
  final logLux = math.log(lux);
  final logDark = math.log(darkLux);
  final logBright = math.log(brightLux);
  final t = (logLux - logDark) / (logBright - logDark);
  return (t * outputCeiling).clamp(0.0, outputCeiling);
}

/// Thin wrapper around the native `com.zapsafe/light` platform channel.
///
/// Android-only in practice: [start] and [hasLightSensor] fail closed
/// (return `false`) on any platform where the channel doesn't exist —
/// including iOS, where Apple exposes no ambient-light API to third-party
/// apps at all (verified this session: no `AVCaptureDevice`/CoreMotion/
/// CoreLocation API surfaces lux; the only proxy is camera ISO/exposure
/// metadata, which requires an active camera-preview session this app does
/// not run in the background — same reasoning `KConfinementFusionPipeline`
/// already documented for rejecting a camera-exposure proxy). Callers
/// should not assume a non-Android platform will throw; they'll simply get
/// `false`/no readings and should fall back to the documented placeholder.
class AmbientLightChannel {
  AmbientLightChannel({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  })  : _method =
            methodChannel ?? const MethodChannel('com.zapsafe/light'),
        _events =
            eventChannel ?? const EventChannel('com.zapsafe/light.events');

  final MethodChannel _method;
  final EventChannel _events;

  Stream<LightSensorReading>? _readings;

  /// True only on Android with the platform channel registered *and* a
  /// physical light sensor present on this device. False (not a thrown
  /// error) on iOS, desktop, or an Android device/emulator lacking the
  /// sensor — all real, expected outcomes, not failures.
  Future<bool> hasLightSensor() async {
    if (!Platform.isAndroid) return false;
    try {
      final ok = await _method.invokeMethod<bool>('hasLightSensor');
      return ok ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> start() async {
    if (!Platform.isAndroid) return false;
    try {
      final ok = await _method.invokeMethod<bool>('start');
      return ok ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> stop() async {
    if (!Platform.isAndroid) return;
    try {
      await _method.invokeMethod('stop');
    } on MissingPluginException {
      // channel never started — nothing to stop.
    } on PlatformException {
      // best-effort stop; nothing useful to do with the error.
    }
  }

  /// Broadcast stream of raw lux readings. Callers on non-Android platforms
  /// will simply never receive an event on this stream (no native side to
  /// emit from) rather than an error.
  Stream<LightSensorReading> readings() {
    _readings ??= _events.receiveBroadcastStream().map(
          (event) =>
              LightSensorReading.fromMap(event as Map<dynamic, dynamic>),
        );
    return _readings!;
  }
}
