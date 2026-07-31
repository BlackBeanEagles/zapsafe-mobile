import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/data/services/motion_detector_v2.dart';

/// Day 258 — m2_motion_v2 preprocessing parity.
///
/// Golden values in test/fixtures/motion_golden.json come from the real
/// m2_motion_v2 model run against a real UCI-HAR accelerometer + gyroscope
/// window (`train/Inertial Signals`, window 0).
///
/// The fixture also records what the model returns when the normalisation is
/// **skipped**: 0.0 for a window that scores 0.98 when normalised correctly.
/// That is the whole reason this test exists. Forgetting the standardisation
/// does not throw, does not change the tensor's shape, and does not produce
/// out-of-range output — it produces a detector that never fires. The
/// `normalisation is not optional` group below pins that gap open so nobody
/// "simplifies" the constants away.
void main() {
  late Map<String, dynamic> golden;

  setUpAll(() {
    golden = jsonDecode(
      File('test/fixtures/motion_golden.json').readAsStringSync(),
    ) as Map<String, dynamic>;
  });

  List<List<double>> matrix(String key) => (golden[key] as List)
      .map((r) => (r as List).cast<num>().map((e) => e.toDouble()).toList())
      .toList();

  List<double> vector(String key) =>
      (golden[key] as List).cast<num>().map((e) => e.toDouble()).toList();

  group('constants match the model report', () {
    // These are baked into the model's weights, not its graph. A typo here
    // is undetectable at runtime.
    test('kNormMean is bit-exact with m2_motion_v2_report.json', () {
      final expected = vector('norm_mean');
      expect(MotionDetectorV2.kNormMean.length, 6);
      for (var i = 0; i < 6; i++) {
        expect(MotionDetectorV2.kNormMean[i], expected[i],
            reason: 'channel $i mean must be exactly equal, not close');
      }
    });

    test('kNormStd is bit-exact with m2_motion_v2_report.json', () {
      final expected = vector('norm_std');
      expect(MotionDetectorV2.kNormStd.length, 6);
      for (var i = 0; i < 6; i++) {
        expect(MotionDetectorV2.kNormStd[i], expected[i],
            reason: 'channel $i std must be exactly equal, not close');
      }
    });

    test('window geometry matches the training script', () {
      expect(MotionDetectorV2.kWindow, 100);
      expect(MotionDetectorV2.kChannels, 6);
      expect(MotionDetectorV2.kRateHz, 50);
      expect(MotionDetectorV2.kInputFloats, 600);
      // 100 samples at 50 Hz = the 2 s window day83_m2_motion_v2.py used.
      expect(MotionDetectorV2.kWindow / MotionDetectorV2.kRateHz, 2.0);
    });
  });

  group('normalisation parity with Python', () {
    test('matches numpy (x - mean) / std elementwise', () {
      final win = matrix('window');
      final x = MotionDetectorV2.normalise(win);
      expect(x.length, 600);

      final head = matrix('normalised_head'); // first 3 samples
      for (var t = 0; t < head.length; t++) {
        for (var c = 0; c < 6; c++) {
          expect(x[t * 6 + c], closeTo(head[t][c], 1e-6),
              reason: 'sample $t channel $c diverged from numpy');
        }
      }
    });

    test('sum and peak match numpy', () {
      final x = MotionDetectorV2.normalise(matrix('window'));
      var sum = 0.0, absmax = 0.0;
      for (final v in x) {
        sum += v;
        if (v.abs() > absmax) absmax = v.abs();
      }
      expect(sum, closeTo((golden['normalised_sum'] as num).toDouble(), 1e-3));
      expect(absmax,
          closeTo((golden['normalised_absmax'] as num).toDouble(), 1e-6));
    });

    test('is laid out [sample][channel], not transposed', () {
      // A transposed 100x6 tensor is still 600 floats in range. Assert the
      // channel stride directly.
      final win = matrix('window');
      final x = MotionDetectorV2.normalise(win);
      for (final t in [0, 1, 50, 99]) {
        for (var c = 0; c < 6; c++) {
          final want =
              (win[t][c] - MotionDetectorV2.kNormMean[c]) /
                  MotionDetectorV2.kNormStd[c];
          expect(x[t * 6 + c], closeTo(want, 1e-6),
              reason: 'sample $t channel $c is not at stride 6');
        }
      }
    });
  });

  group('normalisation is not optional', () {
    test('the fixture records a real fall the model only sees when normalised',
        () {
      // Recorded from the actual model: same window, two preprocessings.
      final normalised =
          (golden['model_score_fall'] as num).toDouble();
      final unnormalised =
          (golden['model_score_unnormalised'] as num).toDouble();
      expect(normalised, greaterThan(0.9),
          reason: 'injected fall must be detected when preprocessed right');
      expect(unnormalised, lessThan(0.01),
          reason: 'raw m/s^2 input scores ~0 — the detector silently never '
              'fires, which is why the constants above are load-bearing');
    });

    test('normalising visibly changes the tensor', () {
      final win = matrix('window');
      final x = MotionDetectorV2.normalise(win);
      // Channel 1 has mean 7.61 subtracted; the normalised values must not
      // still look like raw readings.
      var rawSum = 0.0, normSum = 0.0;
      for (var t = 0; t < 100; t++) {
        rawSum += win[t][1];
        normSum += x[t * 6 + 1];
      }
      expect((rawSum - normSum).abs(), greaterThan(1.0),
          reason: 'normalise() appears to be a no-op on channel 1');
    });
  });

  group('input validation', () {
    test('rejects a window of the wrong length', () {
      final short = List.generate(99, (_) => List.filled(6, 0.0));
      expect(() => MotionDetectorV2.normalise(short), throwsArgumentError);
    });

    test('rejects a sample with the wrong channel count', () {
      final bad = List.generate(100, (i) => List.filled(i == 50 ? 3 : 6, 0.0));
      expect(() => MotionDetectorV2.normalise(bad), throwsArgumentError);
    });
  });

  group('MotionWindowBuffer', () {
    List<double> s(double v) => [v, v, v, v, v, v];

    test('emits nothing until 100 samples have arrived', () {
      final b = MotionWindowBuffer();
      for (var i = 0; i < 99; i++) {
        expect(b.add(s(i.toDouble())), isNull);
      }
      expect(b.isWarm, isFalse);
      expect(b.add(s(99)), isNotNull);
      expect(b.isWarm, isTrue);
    });

    test('emits a full 100x6 window', () {
      final b = MotionWindowBuffer();
      List<List<double>>? w;
      for (var i = 0; i < 100; i++) {
        w = b.add(s(i.toDouble())) ?? w;
      }
      expect(w, isNotNull);
      expect(w!.length, 100);
      expect(w[0].length, 6);
      // Oldest sample first.
      expect(w[0][0], 0.0);
      expect(w[99][0], 99.0);
    });

    test('overlapping hop re-emits every 25 samples, not every 100', () {
      final b = MotionWindowBuffer(hop: 25);
      var emits = 0;
      for (var i = 0; i < 200; i++) {
        if (b.add(s(i.toDouble())) != null) emits++;
      }
      // Warm at 100, then every 25: 100, 125, 150, 175, 200 -> 5 windows.
      expect(emits, 5,
          reason: 'a sub-second fall must not fall between two windows');
    });

    test('slides rather than growing without bound', () {
      final b = MotionWindowBuffer(hop: 1);
      for (var i = 0; i < 1000; i++) {
        b.add(s(i.toDouble()));
      }
      expect(b.buffered, 100);
    });

    test('rejects a malformed sample', () {
      final b = MotionWindowBuffer();
      expect(() => b.add([1, 2, 3]), throwsArgumentError);
    });
  });
}
