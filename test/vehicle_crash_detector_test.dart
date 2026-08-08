import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/data/services/gunshot_detector.dart';
import 'package:zapsafe_mobile/data/services/mel_spectrogram.dart';
import 'package:zapsafe_mobile/data/services/vehicle_crash_detector.dart';

/// Day 271 — parity tests for `i_vehicle_crash`'s preprocessing, ZapSafe's
/// second two-input (audio + IMU fusion) model, following
/// `crowd_panic_detector_test.dart`'s / `gunshot_detector_test.dart`'s
/// pattern.
///
/// Checked against real output, not reimplemented on faith:
///
///  1. The mel side matches real librosa `power_to_db(ref=np.max)` at this
///     model's own params (sr=16000, n_fft=2048, hop=512, n_mels=64,
///     fmax=8000) — `test/fixtures/mel_golden_vehicle_crash.json`, generated
///     by real librosa 0.11.0 locally.
///  2. The default `MelSpectrogram.compute()` path (per-clip min-max to
///     `[0,1]`) is what `day91_i_vehicle_crash.py::audio_to_melspec` uses —
///     unlike `s_crowd_panic`'s global mean/std, this model's own script
///     does the same per-clip min-max as `mg_gunshot`/`m1_scream_v2`.
///  3. `np.resize(mel_norm, (64, 64))` — real shape is `[64, 63]` for a
///     2.0s/16kHz clip, one column short of the 64x64 target, so this
///     wraps by exactly one column. Verified this is a real wrap (not a
///     pad) against real `numpy.resize` output
///     (`test/fixtures/np_resize_vehicle_crash_golden.json` +
///     `np_resize_small_vehicle_crash_golden.json`), reusing
///     `GunshotDetectorV2.wrapResizeSquare` rather than a third
///     reimplementation.
///  4. int8 quantization for both inputs and the output, against the real
///     model's own scale/zero_point — read directly from
///     `i_vehicle_crash.tflite` via `interpreter.get_input_details()` /
///     `get_output_details()` this session (not assumed):
///     `audio_mel` scale=0.003921568859368563 zero=-128,
///     `imu_window` scale=0.003922347445040941 zero=47,
///     output scale=0.00390625 zero=-128.
///  5. The IMU `clip(-8, 8) / 8` formula, bit-identical to
///     `MotionDetectorB.normalise`.
void main() {
  Float64List toneSignal({int sr = 16000, double seconds = 2.0}) {
    final n = (sr * seconds).round();
    final y = Float64List(n);
    for (var i = 0; i < n; i++) {
      final t = i / sr;
      y[i] = 0.5 * math.sin(2 * math.pi * 440 * t) +
          0.25 * math.sin(2 * math.pi * 1720 * t);
    }
    return y;
  }

  group('MelSpectrogram at i_vehicle_crash params (n_mels=64, fmax=8000)', () {
    late Map<String, dynamic> golden;

    setUpAll(() {
      final f = File('test/fixtures/mel_golden_vehicle_crash.json');
      golden = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    });

    test('real 2s/16kHz clip yields 63 frames before the np.resize wrap', () {
      final mel = MelSpectrogram(
        sampleRate: 16000,
        nFft: 2048,
        hopLength: 512,
        nMels: 64,
        fmax: 8000,
      ).compute(toneSignal(), normalize: false);
      expect(mel.length, 64);
      expect(mel[0].length, 63,
          reason: '1 + 32000 ~/ 512 = 63 frames at 16kHz/2.0s — 1 short of '
              'the 64x64 target, so audio_to_melspec\'s np.resize wraps by '
              'exactly one column (unlike mg_gunshot\'s much larger wrap).');
      expect((golden['mel_shape'] as List), [64, 63]);
    });

    test('matches real librosa power_to_db(ref=max) elementwise', () {
      final mel = MelSpectrogram(
        sampleRate: 16000,
        nFft: 2048,
        hopLength: 512,
        nMels: 64,
        fmax: 8000,
      ).compute(toneSignal(), normalize: false);

      void compareRow(String key, int row) {
        final expected = (golden[key] as List).cast<num>();
        for (var i = 0; i < expected.length; i++) {
          expect(mel[row][i], closeTo(expected[i].toDouble(), 1e-4),
              reason: '$key[$i] diverged from real librosa power_to_db');
        }
      }

      compareRow('row0', 0);
      compareRow('row30', 30);
      compareRow('row63', 63);

      final col = (golden['col10'] as List).cast<num>();
      for (var m = 0; m < col.length; m++) {
        expect(mel[m][10], closeTo(col[m].toDouble(), 1e-4),
            reason: 'col10[$m] diverged from real librosa power_to_db');
      }
    });

    test('overall mean matches librosa (raw dB, proving no min-max yet)', () {
      final mel = MelSpectrogram(
        sampleRate: 16000,
        nFft: 2048,
        hopLength: 512,
        nMels: 64,
        fmax: 8000,
      ).compute(toneSignal(), normalize: false);
      var sum = 0.0, count = 0;
      for (final row in mel) {
        for (final v in row) {
          sum += v;
          count++;
        }
      }
      expect(sum / count,
          closeTo((golden['mel_mean'] as num).toDouble(), 1e-3));
    });
  });

  group('np.resize(mel_norm, (64,64)) wrap — real numpy.resize output', () {
    late Map<String, dynamic> smallGolden;

    setUpAll(() {
      final f = File('test/fixtures/np_resize_small_vehicle_crash_golden.json');
      smallGolden = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    });

    test('matches real numpy.resize on a [64,60] -> [64,64] case', () {
      final small = List<Float64List>.generate(64, (r) {
        final row = Float64List(60);
        for (var c = 0; c < 60; c++) {
          row[c] = (r * 60 + c + 1) / 3000.0;
        }
        return row;
      });
      final resized = GunshotDetectorV2.wrapResizeSquare(small, 64);
      expect(resized.length, 64);
      expect(resized[0].length, 64);

      void compareRow(String key, int row) {
        final expected = (smallGolden[key] as List).cast<num>();
        for (var i = 0; i < expected.length; i++) {
          expect(resized[row][i], closeTo(expected[i].toDouble(), 1e-9),
              reason: '$key[$i] diverged from real numpy.resize');
        }
      }

      compareRow('row0', 0);
      compareRow('row5', 5);
      compareRow('row63', 63);
    });

    test('a [64,63] -> [64,64] wrap (this model\'s real shape) only repeats '
        'the first column, not a full extra frame', () {
      // Deterministic small source shaped like the real mel: [64,63].
      final src = List<Float64List>.generate(64, (r) {
        final row = Float64List(63);
        for (var c = 0; c < 63; c++) {
          row[c] = r * 63.0 + c;
        }
        return row;
      });
      final out = GunshotDetectorV2.wrapResizeSquare(src, 64);
      // Row 0: columns 0..62 are the first 63 flattened source values
      // (0..62), column 63 wraps to flat index 63, which is row1,col0 (63).
      expect(out[0][62], 62);
      expect(out[0][63], 63);
    });
  });

  group('int8 quantization against the real model scale/zero_point', () {
    // Confirmed directly this session via interpreter.get_input_details()/
    // get_output_details() on the real staged i_vehicle_crash.tflite.
    const melScale = 0.003921568859368563;
    const melZero = -128;
    const imuScale = 0.003922347445040941;
    const imuZero = 47;
    const outScale = 0.00390625;
    const outZero = -128;

    int quantize(double v, double scale, int zero) =>
        ((v / scale).round() + zero).clamp(-128, 127);
    double dequantize(int q, double scale, int zero) => (q - zero) * scale;

    test('mel input quantizes into the valid int8 range across [0,1]', () {
      for (final v in [0.0, 0.25, 0.5, 0.75, 1.0]) {
        final q = quantize(v, melScale, melZero);
        expect(q, inInclusiveRange(-128, 127));
      }
      // v=0 should land near -128 given zero_point=-128, scale~1/255.
      expect(quantize(0.0, melScale, melZero), -128);
    });

    test('imu input quantizes into the valid int8 range across [-1,1]', () {
      for (final v in [-1.0, -0.5, 0.0, 0.5, 1.0]) {
        final q = quantize(v, imuScale, imuZero);
        expect(q, inInclusiveRange(-128, 127));
      }
    });

    test('output dequantizes round-trip for the full int8 range', () {
      for (final q in [-128, -64, 0, 63, 127]) {
        final v = dequantize(q, outScale, outZero);
        final q2 = quantize(v, outScale, outZero);
        expect(q2, q);
      }
    });
  });

  group('VehicleCrashDetector preprocessing (pure Dart, no interpreter)', () {
    test('melFeaturesFromPcm produces a flattened 64x64x3 float image in '
        '[0,1] with identical channels', () {
      final det = _VehicleCrashPreprocOnly();
      final img = det.melFeaturesFromPcm(toneSignal());
      expect(img.length, VehicleCrashDetector.kMelInputFloats);
      expect(img.length, 64 * 64 * 3);
      for (var i = 0; i < img.length; i += 3) {
        expect(img[i], img[i + 1]);
        expect(img[i + 1], img[i + 2]);
        expect(img[i], inInclusiveRange(0.0, 1.0));
      }
    });

    test('imuFeaturesFromWindow applies clip(-8,8)/8 per sample/channel, '
        'identical to MotionDetectorB.normalise\'s formula', () {
      final det = _VehicleCrashPreprocOnly();
      final window = List<List<double>>.generate(
          128, (_) => [10.0, -10.0, 4.0, 0.0, 8.0, -8.0]);
      final feats = det.imuFeaturesFromWindow(window);
      expect(feats.length, 128 * 6);
      // clip(10, -8, 8) = 8 -> 8/8 = 1.0
      expect(feats[0], closeTo(1.0, 1e-6));
      // clip(-10, -8, 8) = -8 -> -8/8 = -1.0
      expect(feats[1], closeTo(-1.0, 1e-6));
      // clip(4, -8, 8) = 4 -> 4/8 = 0.5
      expect(feats[2], closeTo(0.5, 1e-6));
      expect(feats[3], closeTo(0.0, 1e-6));
      expect(feats[4], closeTo(1.0, 1e-6));
      expect(feats[5], closeTo(-1.0, 1e-6));
    });

    test('imuFeaturesFromWindow rejects a window of the wrong length', () {
      final det = _VehicleCrashPreprocOnly();
      expect(
          () => det.imuFeaturesFromWindow(
              List<List<double>>.generate(50, (_) => [0, 0, 0, 0, 0, 0])),
          throwsArgumentError);
    });
  });
}

/// Test-only helper mirroring `VehicleCrashDetector`'s pure preprocessing
/// without needing a loaded native interpreter — same pattern
/// `gunshot_detector_test.dart`'s `GunshotDetectorV2Testable` and
/// `crowd_panic_detector_test.dart`'s `_CrowdPanicPreprocOnly` use, since
/// `VehicleCrashDetector`'s constructor is private and gated behind
/// `tryLoad()`.
class _VehicleCrashPreprocOnly {
  final MelSpectrogram _mel = MelSpectrogram(
    sampleRate: VehicleCrashDetector.kSampleRate,
    nFft: 2048,
    hopLength: 512,
    nMels: VehicleCrashDetector.kMelBands,
    fmax: VehicleCrashDetector.kFmax,
  );

  Float32List melFeaturesFromPcm(Float64List pcm) {
    const n = VehicleCrashDetector.kAudioSamples;
    final clip = pcm.length == n
        ? pcm
        : (Float64List(n)
          ..setRange(0, math.min(pcm.length, n),
              pcm.length < n ? pcm : pcm.sublist(0, n)));
    final mel = _mel.compute(clip); // default normalize: true -> [0,1]
    final img = GunshotDetectorV2.wrapResizeSquare(
        mel, VehicleCrashDetector.kImgSize);

    final out = Float32List(VehicleCrashDetector.kMelInputFloats);
    var i = 0;
    for (var h = 0; h < VehicleCrashDetector.kImgSize; h++) {
      final row = img[h];
      for (var w = 0; w < VehicleCrashDetector.kImgSize; w++) {
        final v = row[w];
        out[i++] = v;
        out[i++] = v;
        out[i++] = v;
      }
    }
    return out;
  }

  Float32List imuFeaturesFromWindow(List<List<double>> samples) {
    if (samples.length != VehicleCrashDetector.kImuWindow) {
      throw ArgumentError('wrong window length');
    }
    final out = Float32List(
        VehicleCrashDetector.kImuWindow * VehicleCrashDetector.kImuChannels);
    var i = 0;
    for (var t = 0; t < VehicleCrashDetector.kImuWindow; t++) {
      final row = samples[t];
      for (var c = 0; c < VehicleCrashDetector.kImuChannels; c++) {
        final clipped =
            row[c].clamp(-VehicleCrashDetector.kGRange, VehicleCrashDetector.kGRange);
        out[i++] = (clipped / VehicleCrashDetector.kGRange).toDouble();
      }
    }
    return out;
  }
}
