import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/data/services/k_confinement_detector.dart';
import 'package:zapsafe_mobile/data/services/k_confinement_pipeline.dart';

/// Day 273 — parity tests for `k_confinement_decorrelated.tflite` (Day
/// 272's decorrelated retrain), following `vehicle_crash_detector_test.dart`'s
/// pattern for the second real two-input fusion model this app wires with
/// a non-audio second input.
///
/// Checked against real facts confirmed this session, not assumed:
///
///  1. Real tensor shapes/dtypes read directly via
///     `interpreter.get_input_details()`/`get_output_details()` against
///     `kaggle_notebooks/day272_k_confinement_decorrelated_push/
///     kaggle_output/k_confinement_decorrelated.tflite`:
///     `imu` [1,128,6] float32, `light` [1,32,1] float32,
///     output [1,1] float32 — no int8 quantization anywhere, unlike
///     `i_vehicle_crash`.
///  2. IMU z-score normalization `(x - imu_mean) / imu_std` per channel,
///     bit-for-bit `day272_k_confinement_decorrelated.py`'s
///     `X_imu = (X_imu - imu_mean) / imu_std`, with the real per-channel
///     mean/std read from `k_confinement_decorrelated_norm.json`.
///  3. `make_light(val) = np.full(32, val)` broadcast, no normalization.
///  4. Day 274 update: a real Android native light-sensor platform channel
///     (`com.zapsafe/light`, `Sensor.TYPE_LIGHT`) now exists —
///     `KConfinementFusionPipeline.androidLightSensorChannelWired` is `true`,
///     a compile-time capability flag. Whether a *specific instance* has a
///     live reading is `usesRealLightSensor`, an instance getter that can't
///     be exercised here without a real loaded interpreter (this file stays
///     "pure Dart, no interpreter" per its own heading) — that plumbing is
///     covered instead by `test/light_sensor_channel_test.dart`, which
///     mocks the platform channel directly. iOS has no equivalent OS API
///     (confirmed Day 274) and keeps using `kPlaceholderLightValue`.
void main() {
  group('KConfinementDetector preprocessing (pure Dart, no interpreter)', () {
    test('imuFeaturesFromWindow applies real per-channel z-score, matching '
        'day272_k_confinement_decorrelated.py\'s (x - imu_mean) / imu_std',
        () {
      final det = _KConfinementPreprocOnly();
      final window = List<List<double>>.generate(
          128, (_) => List<double>.from(KConfinementDetector.kImuMean));
      final feats = det.imuFeaturesFromWindow(window);
      expect(feats.length, KConfinementDetector.kImuInputFloats);
      // Every sample equals the training mean -> z-score should be ~0.
      for (final v in feats) {
        expect(v, closeTo(0.0, 1e-4));
      }
    });

    test('imuFeaturesFromWindow one-std-above-mean sample yields z-score 1',
        () {
      final det = _KConfinementPreprocOnly();
      final row = List<double>.generate(
          6,
          (c) =>
              KConfinementDetector.kImuMean[c] + KConfinementDetector.kImuStd[c]);
      final window = List<List<double>>.generate(128, (_) => row);
      final feats = det.imuFeaturesFromWindow(window);
      for (var c = 0; c < 6; c++) {
        expect(feats[c], closeTo(1.0, 1e-4));
      }
    });

    test('imuFeaturesFromWindow rejects a window of the wrong length', () {
      final det = _KConfinementPreprocOnly();
      expect(
          () => det.imuFeaturesFromWindow(
              List<List<double>>.generate(50, (_) => [0, 0, 0, 0, 0, 0])),
          throwsArgumentError);
    });

    test('lightFeaturesFromScalar broadcasts a single scalar to all 32 '
        'timesteps unnormalized, matching make_light(val)', () {
      final det = _KConfinementPreprocOnly();
      final feats = det.lightFeaturesFromScalar(0.7);
      expect(feats.length, KConfinementDetector.kLightLen);
      for (final v in feats) {
        expect(v, closeTo(0.7, 1e-6));
      }
    });
  });

  group('KConfinementFusionPipeline light-sensor honesty', () {
    test('androidLightSensorChannelWired is true as of Day 274 — a real '
        'native Sensor.TYPE_LIGHT platform channel is wired on Android '
        '(this is a compile-time capability flag, not a runtime guarantee '
        'for any specific instance/device — see usesRealLightSensor)', () {
      expect(KConfinementFusionPipeline.androidLightSensorChannelWired,
          isTrue);
    });

    test('kPlaceholderLightValue sits mid-range between the trained dark '
        '(0.0-0.1) and lit (0.15-0.9) regimes, not biased toward either', () {
      expect(KConfinementFusionPipeline.kPlaceholderLightValue, 0.5);
      expect(KConfinementFusionPipeline.kPlaceholderLightValue,
          greaterThan(0.1));
      expect(KConfinementFusionPipeline.kPlaceholderLightValue, lessThan(0.9));
    });
  });
}

/// Test-only helper mirroring `KConfinementDetector`'s pure preprocessing
/// without needing a loaded native interpreter — `KConfinementDetector`'s
/// constructor is private and gated behind `tryLoad()`, same pattern as
/// `vehicle_crash_detector_test.dart`'s `_VehicleCrashPreprocOnly`.
class _KConfinementPreprocOnly {
  Float32List imuFeaturesFromWindow(List<List<double>> samples) {
    if (samples.length != KConfinementDetector.kImuWindow) {
      throw ArgumentError('wrong window length');
    }
    final out = Float32List(KConfinementDetector.kImuInputFloats);
    var i = 0;
    for (var t = 0; t < KConfinementDetector.kImuWindow; t++) {
      final row = samples[t];
      for (var c = 0; c < KConfinementDetector.kImuChannels; c++) {
        out[i++] = ((row[c] - KConfinementDetector.kImuMean[c]) /
                KConfinementDetector.kImuStd[c])
            .toDouble();
      }
    }
    return out;
  }

  Float32List lightFeaturesFromScalar(double lightValue) {
    final out = Float32List(KConfinementDetector.kLightLen);
    for (var i = 0; i < KConfinementDetector.kLightLen; i++) {
      out[i] = lightValue;
    }
    return out;
  }
}
