import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// Day 32 — 6-DOF motion-feature vector consumed by the M2 motion-anomaly
/// model.
///
/// Today this is a placeholder shape; the real IMU service that fills these
/// fields from `SensorManager` (Android) / `CMMotionManager` (iOS) lands in
/// Week 8 (~Day 36). Until then, callers build a synthetic instance via
/// [MotionFeatures.atRest] or the testing constructor.
///
/// Layout (6 floats, matches MobiAct's preprocessed cycle):
///   • accel magnitude mean
///   • accel magnitude variance
///   • accel magnitude peak
///   • gyro magnitude mean
///   • gyro magnitude variance
///   • gyro magnitude peak
@immutable
class MotionFeatures {
  final int timestampMs;
  final double accelMean;
  final double accelVar;
  final double accelPeak;
  final double gyroMean;
  final double gyroVar;
  final double gyroPeak;

  const MotionFeatures({
    required this.timestampMs,
    required this.accelMean,
    required this.accelVar,
    required this.accelPeak,
    required this.gyroMean,
    required this.gyroVar,
    required this.gyroPeak,
  });

  /// Phone sitting on a desk — gravity only, no rotation.
  /// Useful default when motion isn't observed.
  factory MotionFeatures.atRest({int? timestampMs}) => MotionFeatures(
        timestampMs: timestampMs ??
            DateTime.now().millisecondsSinceEpoch,
        accelMean: 9.81,
        accelVar: 0.02,
        accelPeak: 9.85,
        gyroMean: 0.005,
        gyroVar: 0.0,
        gyroPeak: 0.01,
      );

  /// Walking gait — typical accelerometer values for a person at 1.4 m/s.
  factory MotionFeatures.walking({int? timestampMs}) => MotionFeatures(
        timestampMs: timestampMs ??
            DateTime.now().millisecondsSinceEpoch,
        accelMean: 10.6,
        accelVar: 1.5,
        accelPeak: 13.2,
        gyroMean: 0.4,
        gyroVar: 0.18,
        gyroPeak: 1.2,
      );

  /// Impact / fall signature — heavy accel spike + spin.
  factory MotionFeatures.impact({int? timestampMs}) => MotionFeatures(
        timestampMs: timestampMs ??
            DateTime.now().millisecondsSinceEpoch,
        accelMean: 18.4,
        accelVar: 12.0,
        accelPeak: 35.0,
        gyroMean: 2.5,
        gyroVar: 4.0,
        gyroPeak: 8.0,
      );

  /// Pack into the Float32 layout the M2 interpreter expects.
  /// Order matches the field declaration.
  Float32List toFloat32Tensor() {
    final out = Float32List(6);
    out[0] = accelMean;
    out[1] = accelVar;
    out[2] = accelPeak;
    out[3] = gyroMean;
    out[4] = gyroVar;
    out[5] = gyroPeak;
    return out;
  }

  int get dimension => 6;
}
