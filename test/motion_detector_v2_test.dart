import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/data/services/motion_detector_v2.dart';

/// Day 323 — motion_fall_v2 contract parity.
///
/// Rewritten from the Day 258 version, which pinned m2_motion_v2: a 6-channel
/// acc+gyro model loaded from `motion_anomaly_v1.tflite`. That asset was
/// verified DEAD (constant 0.0 for every input on real SisFall IMU) and has
/// been replaced by `motion_fall_v2.tflite`, retrained on UniMiB-SHAR at 3
/// accelerometer channels. Its golden fixture (`motion_golden.json`) came
/// from the old model against UCI-HAR 6-channel windows and no longer
/// describes anything that ships.
///
/// The old test's real purpose is kept: **normalisation is not optional.**
/// The constants are baked into the model's weights, not its graph. Skipping
/// them does not throw, does not change the tensor's shape, and does not
/// produce out-of-range output — it produces a detector that quietly never
/// fires. This file pins that gap open so nobody "simplifies" the constants
/// away.
///
/// What is NOT asserted here: real inference values. `flutter test` has no
/// native TFLite interpreter, so no Dart test in this repo can execute a
/// model. Real-data verification lives in `tools/verify_shipped_models.py`,
/// which runs the shipped asset against recorded audio/IMU and fails on both
/// dead (constant) and WEAK (AUC < 0.70) models. Run it before shipping.
void main() {
  late Map<String, dynamic> norm;

  setUpAll(() {
    // The same file the app ships, not a test-only copy — so a mismatch
    // between the model's real constants and the Dart ones fails here.
    norm = jsonDecode(
      File('assets/models/motion_fall_v2_norm.json').readAsStringSync(),
    ) as Map<String, dynamic>;
  });

  List<double> vec(String k) =>
      (norm[k] as List).cast<num>().map((e) => e.toDouble()).toList();

  group('constants match the shipped norm.json', () {
    test('kNormMean is bit-exact with motion_fall_v2_norm.json', () {
      final expected = vec('mean');
      expect(MotionDetectorV2.kNormMean.length, MotionDetectorV2.kChannels);
      expect(expected.length, MotionDetectorV2.kChannels);
      for (var i = 0; i < expected.length; i++) {
        expect(MotionDetectorV2.kNormMean[i], closeTo(expected[i], 1e-9),
            reason: 'channel $i mean drifted from the trained constants');
      }
    });

    test('kNormStd is bit-exact with motion_fall_v2_norm.json', () {
      final expected = vec('std');
      expect(MotionDetectorV2.kNormStd.length, MotionDetectorV2.kChannels);
      for (var i = 0; i < expected.length; i++) {
        expect(MotionDetectorV2.kNormStd[i], closeTo(expected[i], 1e-9),
            reason: 'channel $i std drifted from the trained constants');
      }
    });

    test('window, rate and channel count match the trained contract', () {
      expect(MotionDetectorV2.kChannels, 3, reason: 'accelerometer xyz only');
      expect(MotionDetectorV2.kWindow, 100);
      expect(MotionDetectorV2.kRateHz, 50);
      expect(MotionDetectorV2.kInputFloats, 300);
      expect(norm['channels'], MotionDetectorV2.kChannels);
      expect(norm['window'], MotionDetectorV2.kWindow);
      expect(norm['rate_hz'], MotionDetectorV2.kRateHz);
    });

    test('norm.json still declares gravity-inclusive m/s^2', () {
      // sensors_plus accelerometerEventStream() supplies this;
      // userAccelerometerEventStream() would not, and would silently shift
      // every sample by ~9.8 on one axis.
      expect(norm['units'].toString().toLowerCase(), contains('gravity'));
      expect(norm['channel_order'], ['acc_x', 'acc_y', 'acc_z']);
    });
  });

  group('normalisation is not optional', () {
    List<List<double>> window(double v) =>
        List.generate(MotionDetectorV2.kWindow,
            (_) => List.filled(MotionDetectorV2.kChannels, v));

    test('normalise() produces kInputFloats in row-major [t][c] order', () {
      final x = MotionDetectorV2.normalise(window(0.0));
      expect(x.length, MotionDetectorV2.kInputFloats);
      // Every timestep is identical, so channel c must repeat every kChannels.
      for (var t = 0; t < MotionDetectorV2.kWindow; t++) {
        for (var c = 0; c < MotionDetectorV2.kChannels; c++) {
          expect(x[t * MotionDetectorV2.kChannels + c],
              closeTo(x[c], 1e-6),
              reason: 'layout is not row-major [t][c]');
        }
      }
    });

    test('normalise() actually applies (x - mean) / std', () {
      const raw = 9.81; // a plausible resting m/s^2 reading
      final x = MotionDetectorV2.normalise(window(raw));
      for (var c = 0; c < MotionDetectorV2.kChannels; c++) {
        final want =
            (raw - MotionDetectorV2.kNormMean[c]) / MotionDetectorV2.kNormStd[c];
        expect(x[c], closeTo(want, 1e-5),
            reason: 'channel $c was not standardised');
      }
    });

    test('standardised output is far from the raw input', () {
      // The failure this guards: someone passes raw m/s^2 straight through.
      // It would be the right shape and the right range, and wrong.
      const raw = 9.81;
      final x = MotionDetectorV2.normalise(window(raw));
      expect((x[0] - raw).abs(), greaterThan(1.0),
          reason: 'raw and standardised values must not be interchangeable');
    });

    test('rejects a window of the wrong length', () {
      expect(
        () => MotionDetectorV2.normalise(window(0.0)..removeLast()),
        throwsArgumentError,
      );
    });

    test('rejects a row with the wrong channel count', () {
      final w = window(0.0);
      w[7] = List.filled(MotionDetectorV2.kChannels + 3, 0.0); // stale 6-ch row
      expect(() => MotionDetectorV2.normalise(w), throwsArgumentError,
          reason: 'a leftover 6-channel producer must fail loudly, not '
              'silently feed the model garbage');
    });
  });
}
