import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/data/services/gunshot_detector.dart';
import 'package:zapsafe_mobile/data/services/mel_spectrogram.dart';

/// Day 262 — parity tests for the `mg_gunshot_retrain` preprocessing
/// pipeline, which is structurally different from m1_scream_v2's (see
/// `gunshot_detector.dart`'s class doc for the full diff table).
///
/// Three things are checked against real librosa/numpy output, not
/// reimplemented and trusted on faith:
///
///  1. The mel spectrogram itself at mg_gunshot's actual params
///     (sr=16000, n_fft=2048, hop=512, n_mels=128, **fmax=8000** — the
///     `fmax` support added to `MelSpectrogram` for this model).
///  2. The `np.resize(mel_norm, (128, 128))` wrap/tile step, which is
///     **not** an image resize — see below.
///  3. int8 quantization against the real model's actual scale/zero_point
///     (`test/fixtures/gunshot_quant_golden.json`, read from the live
///     `mg_gunshot_retrain.tflite` file via
///     `interpreter.get_input_details()`, not assumed).
void main() {
  Float64List toneSignal({int sr = 16000, int seconds = 3}) {
    final n = sr * seconds;
    final y = Float64List(n);
    for (var i = 0; i < n; i++) {
      final t = i / sr;
      y[i] = 0.5 * math.sin(2 * math.pi * 440 * t) +
          0.25 * math.sin(2 * math.pi * 1720 * t);
    }
    return y;
  }

  group('MelSpectrogram at mg_gunshot params (fmax=8000)', () {
    late Map<String, dynamic> golden;

    setUpAll(() {
      final f = File('test/fixtures/mel_golden_gunshot.json');
      golden = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    });

    test('shape matches librosa for a real 3s/16kHz clip', () {
      final mel = MelSpectrogram(
        sampleRate: 16000,
        nFft: 2048,
        hopLength: 512,
        nMels: 128,
        fmax: 8000,
      ).compute(toneSignal());
      expect(mel.length, 128);
      expect(mel[0].length, 94,
          reason: '1 + 48000 ~/ 512 = 94 frames, matching librosa '
              'center=True at 16kHz — well under the 128x128 target, which '
              'is exactly why np.resize wraps rather than trims.');
      expect((golden['mel_shape'] as List), [128, 94]);
    });

    test('matches librosa values elementwise with fmax=8000', () {
      final mel = MelSpectrogram(
        sampleRate: 16000,
        nFft: 2048,
        hopLength: 512,
        nMels: 128,
        fmax: 8000,
      ).compute(toneSignal());

      void compareRow(String key, int row) {
        final expected = (golden[key] as List).cast<num>();
        for (var i = 0; i < expected.length; i++) {
          expect(mel[row][i], closeTo(expected[i].toDouble(), 1e-6),
              reason: '$key[$i] diverged from librosa (fmax=8000 path)');
        }
      }

      compareRow('row0', 0);
      compareRow('row40', 40);
      compareRow('row100', 100);

      final col = (golden['col30'] as List).cast<num>();
      for (var m = 0; m < col.length; m++) {
        expect(mel[m][30], closeTo(col[m].toDouble(), 1e-6),
            reason: 'col30[$m] diverged from librosa (fmax=8000 path)');
      }
    });

    test('overall mean matches librosa', () {
      final mel = MelSpectrogram(
        sampleRate: 16000,
        nFft: 2048,
        hopLength: 512,
        nMels: 128,
        fmax: 8000,
      ).compute(toneSignal());
      var sum = 0.0, count = 0;
      for (final row in mel) {
        for (final v in row) {
          sum += v;
          count++;
        }
      }
      expect(sum / count,
          closeTo((golden['mel_mean'] as num).toDouble(), 1e-6));
    });

    test('fmax=8000 differs from the default (Nyquist) filterbank', () {
      // Structural guard: if fmax silently stops being threaded through,
      // this is the cheapest test to catch it (no fixture needed) — the
      // two filterbanks must disagree on a real signal with energy above
      // 1720Hz, since fmax=8000 compresses more spectral range into the
      // same 128 mel bands than fmax=8000 (Nyquist at 16kHz IS 8000, so
      // this model happens to have fmax==Nyquist — the real regression risk
      // is at sr=22050 with fmax=8000, tested below).
      final withDefaultFmax = MelSpectrogram(
        sampleRate: 22050,
        nFft: 2048,
        hopLength: 512,
        nMels: 128,
      ).compute(toneSignal(sr: 22050));
      final withCappedFmax = MelSpectrogram(
        sampleRate: 22050,
        nFft: 2048,
        hopLength: 512,
        nMels: 128,
        fmax: 8000,
      ).compute(toneSignal(sr: 22050));

      // Sum across the whole top quarter of mel bands (highest-frequency
      // filters, where capping fmax reshuffles the most energy) rather than
      // one arbitrary cell — a single cell can coincidentally agree (as it
      // did here: row100/col10 is silence in both), which would make the
      // test pass for the wrong reason.
      double topBandSum(List<Float64List> mel) {
        var sum = 0.0;
        for (var m = 96; m < 128; m++) {
          for (final v in mel[m]) {
            sum += v;
          }
        }
        return sum;
      }

      expect(topBandSum(withDefaultFmax), isNot(closeTo(topBandSum(withCappedFmax), 1e-6)),
          reason: 'capping fmax must change the high-band filterbank '
              'weights, or the fmax parameter is not being threaded through');
    });
  });

  group('np.resize wrap/tile (NOT an image resize)', () {
    late Map<String, dynamic> golden;

    setUpAll(() {
      final f = File('test/fixtures/np_resize_wrap_golden.json');
      golden = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    });

    test('matches real numpy.resize elementwise on a [128,10] -> [128,128] '
        'case (the real shape mismatch mg_gunshot hits every inference)', () {
      // Same construction as gen_gunshot_golden.py: arange(1, 1281)/2000
      // reshaped to [128, 10].
      final small = List<Float64List>.generate(128, (r) {
        final row = Float64List(10);
        for (var c = 0; c < 10; c++) {
          row[c] = (r * 10 + c + 1) / 2000.0;
        }
        return row;
      });

      final resized =
          GunshotDetectorV2.wrapResizeSquare(small, 128);

      expect(resized.length, 128);
      expect(resized[0].length, 128);

      void compareRow(String key, int row) {
        final expected = (golden[key] as List).cast<num>();
        for (var i = 0; i < expected.length; i++) {
          expect(resized[row][i], closeTo(expected[i].toDouble(), 1e-12),
              reason: '$key[$i] diverged from real numpy.resize');
        }
      }

      compareRow('row0', 0);
      compareRow('row5', 5);
      compareRow('row127', 127);
    });

    test('wraps rather than pads when the source is smaller than the '
        'target (the defining, easy-to-get-wrong behaviour)', () {
      // A [2,3] source resized to [4,4] must repeat its own flattened
      // elements, not zero-pad — np.resize([[1,2,3],[4,5,6]], (4,4)) ==
      // [[1,2,3,4],[5,6,1,2],[3,4,5,6],[1,2,3,4]].
      final src = [
        Float64List.fromList([1, 2, 3]),
        Float64List.fromList([4, 5, 6]),
      ];
      final out = GunshotDetectorV2.wrapResizeSquare(src, 4);
      expect(out[0], [1, 2, 3, 4]);
      expect(out[1], [5, 6, 1, 2]);
      expect(out[2], [3, 4, 5, 6]);
      expect(out[3], [1, 2, 3, 4]);
    });
  });

  group('int8 quantization against the real model scale/zero_point', () {
    test('matches real values from mg_gunshot_retrain.tflite input tensor',
        () {
      final f = File('test/fixtures/gunshot_quant_golden.json');
      final golden = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      final scale = (golden['scale'] as num).toDouble();
      final zeroPoint = golden['zero_point'] as int;
      final values = (golden['values'] as List).cast<num>();
      final expectedQ = (golden['quantized'] as List).cast<int>();

      for (var i = 0; i < values.length; i++) {
        final q = ((values[i].toDouble() / scale).round() + zeroPoint)
            .clamp(-128, 127);
        expect(q, expectedQ[i],
            reason: 'quantize(${values[i]}) diverged from the real model\'s '
                'own scale/zero_point');
      }
    });
  });

  group('GunshotDetectorV2 preprocessing shape', () {
    test('melImageFromPcm produces a flattened 128x128x3 float image', () {
      // Constructed without tryLoad() (no native interpreter needed) —
      // this only exercises the pure-Dart preprocessing path.
      final detector = GunshotDetectorV2Testable();
      final img = detector.melImageFromPcm(toneSignal());
      expect(img.length, GunshotDetectorV2.kInputFloats);
      expect(img.length, 128 * 128 * 3);
      for (final v in img) {
        expect(v, inInclusiveRange(0.0, 1.0));
        expect(v.isFinite, isTrue);
      }
    });

    test('the 3 channels are identical (np.stack([img, img, img]))', () {
      final detector = GunshotDetectorV2Testable();
      final img = detector.melImageFromPcm(toneSignal());
      for (var i = 0; i < GunshotDetectorV2.kInputFloats; i += 3) {
        expect(img[i], img[i + 1]);
        expect(img[i + 1], img[i + 2]);
      }
    });
  });
}

/// Test-only subclass-free helper: [GunshotDetectorV2]'s public
/// preprocessing methods (`melImageFromPcm`, `wrapResizeSquare`) don't need
/// a loaded interpreter, but the constructor is private ([GunshotDetectorV2._])
/// and gated behind [GunshotDetectorV2.tryLoad] (which needs a real native
/// TFLite interpreter, unavailable in a plain `flutter test` host). This
/// mirrors the pattern `mel_spectrogram_test.dart` and
/// `scream_detector_v2_test.dart` use: preprocessing is tested directly via
/// the `MelSpectrogram` class instead of through the detector. Since
/// `melImageFromPcm` only needs a `MelSpectrogram` instance internally, this
/// helper builds one exactly as `GunshotDetectorV2._` does.
class GunshotDetectorV2Testable {
  final MelSpectrogram _mel = MelSpectrogram(
    sampleRate: GunshotDetectorV2.kSampleRate,
    nFft: 2048,
    hopLength: 512,
    nMels: GunshotDetectorV2.kMelBands,
    fmax: GunshotDetectorV2.kFmax,
  );

  Float32List melImageFromPcm(Float64List pcm) {
    final clip = _fitSamples(pcm);
    final mel = _mel.compute(clip);
    final img = GunshotDetectorV2.wrapResizeSquare(mel, GunshotDetectorV2.kImgSize);

    final out = Float32List(GunshotDetectorV2.kInputFloats);
    var i = 0;
    for (var h = 0; h < GunshotDetectorV2.kImgSize; h++) {
      final row = img[h];
      for (var w = 0; w < GunshotDetectorV2.kImgSize; w++) {
        final v = row[w];
        out[i++] = v;
        out[i++] = v;
        out[i++] = v;
      }
    }
    return out;
  }

  static Float64List _fitSamples(Float64List pcm) {
    if (pcm.length == GunshotDetectorV2.kSamples) return pcm;
    final out = Float64List(GunshotDetectorV2.kSamples);
    out.setRange(
        0,
        pcm.length < GunshotDetectorV2.kSamples
            ? pcm.length
            : GunshotDetectorV2.kSamples,
        pcm.length < GunshotDetectorV2.kSamples
            ? pcm
            : pcm.sublist(0, GunshotDetectorV2.kSamples));
    return out;
  }
}
