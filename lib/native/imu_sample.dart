import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// One sample from the IMU stream — combined accelerometer + gyroscope read.
///
/// The native side packs the six axes + timestamp into a `Map<String, dynamic>`
/// so we can ride a single EventChannel for both sensors (one less channel to
/// manage; native is responsible for time-aligning the two readouts).
@immutable
class ImuSample {
  /// Native wall-clock when the sample was captured (milliseconds since epoch).
  final int timestampMs;

  /// Accelerometer in m/s² (gravity removed if available, raw otherwise).
  final double ax;
  final double ay;
  final double az;

  /// Gyroscope in rad/s.
  final double gx;
  final double gy;
  final double gz;

  const ImuSample({
    required this.timestampMs,
    required this.ax,
    required this.ay,
    required this.az,
    required this.gx,
    required this.gy,
    required this.gz,
  });

  /// Builds a sample from a raw EventChannel event. Defaults zero on any
  /// missing field so a malformed frame never throws — the worst case is a
  /// dropped reading, not a crashed isolate.
  factory ImuSample.fromMap(Map<dynamic, dynamic> map) {
    double n(String k) => (map[k] as num?)?.toDouble() ?? 0.0;
    return ImuSample(
      timestampMs: (map['t'] as num?)?.toInt() ?? 0,
      ax: n('ax'), ay: n('ay'), az: n('az'),
      gx: n('gx'), gy: n('gy'), gz: n('gz'),
    );
  }

  /// Magnitude of the acceleration vector. Useful for impact-detection
  /// thresholds and quick UI sparklines.
  double get accelMagnitude => math.sqrt(ax * ax + ay * ay + az * az);

  /// Magnitude of the rotation vector.
  double get gyroMagnitude => math.sqrt(gx * gx + gy * gy + gz * gz);
}
