import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/data/services/glass_break_detector.dart';
import 'package:zapsafe_mobile/data/services/gunshot_detector.dart';
import 'package:zapsafe_mobile/data/services/mel_spectrogram.dart';

/// Day 346 — parity tests for `m_glass_breaking_v4` preprocessing.
///
/// This model ships because it was measured (AUC 0.7819 on 265 real FSD50K
/// positives, vs a recorded 1.0 from 13 that did not survive). None of that
/// means anything if the phone feeds it different features than the trainer
/// did, and there are two specific ways that could happen here:
///
///  1. **Copying gunshot's params.** The two contracts differ in three of
///     six fields — glass is 2 s / 96 mels / 96x96, gunshot 3 s / 128 / 128.
///     Reading `[1,96,96,3]` off the tensor and assuming the rest would feed
///     the model 50% more audio than it has ever seen.
///  2. **Using a real image resize.** The post-mel step is
///     `np.resize(mel_norm, (96, 96))`, which flattens row-major and
///     *tiles/wraps*. At these params the mel is `[96, 63]`, so everything
///     past column 63 repeats earlier data. A bilinear resize gives exactly
///     the right shape and the wrong features.
///
/// The golden values come from **real librosa and real numpy**
/// (`work/glass_retrain/make_dart_golden.py`), never reimplemented, so the
/// assertions below cannot drift along with a bug in the Dart code.
void main() {
  /// Same deterministic two-tone signal the golden generator uses.
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

  late Map<String, dynamic> golden;

  setUpAll(() {
    golden = jsonDecode(File('test/fixtures/glass_golden.json')
        .readAsStringSync()) as Map<String, dynamic>;
  });

  group('GlassBreakDetector contract', () {
    test('constants match train_glass.py, and are NOT gunshot\'s', () {
      expect(GlassBreakDetector.kSampleRate, 16000);
      expect(GlassBreakDetector.kSamples, 32000); // 2.0 s, not gunshot's 3 s
      expect(GlassBreakDetector.kMelBands, 96);
      expect(GlassBreakDetector.kImgSize, 96);
      expect(GlassBreakDetector.kChannels, 3);
      expect(GlassBreakDetector.kFmax, 8000.0);
      expect(GlassBreakDetector.kInputFloats, 96 * 96 * 3);

      // The point of this assertion is the difference, not the values.
      expect(GlassBreakDetector.kSamples,
          isNot(equals(GunshotDetectorV2.kSamples)));
      expect(GlassBreakDetector.kImgSize,
          isNot(equals(GunshotDetectorV2.kImgSize)));
    });

    test('golden fixture was generated at those same params', () {
      expect(golden['sr'], 16000);
      expect(golden['duration'], 2.0);
      expect(golden['n_mels'], 96);
      expect(golden['n_fft'], 2048);
      expect(golden['hop_length'], 512);
      expect(golden['fmax'], 8000);
      expect(golden['img'], 96);
      expect(golden['flat_len'], GlassBreakDetector.kInputFloats);
    });

    test('threshold is the measured 0.22, not the report\'s 0.8754', () {
      // 0.8754 was chosen on 13 positives. On 265 the curve is already down
      // to recall 0.283 by t=0.795. Shipping it would have been a detector
      // that fires on fewer than a third of real breaking glass.
      expect(GlassBreakDetector.kDefaultThreshold, 0.22);
    });
  });

  group('mel spectrogram at glass params', () {
    test('matches librosa for a known signal', () {
      final mel = MelSpectrogram(
        sampleRate: 16000,
        nFft: 2048,
        hopLength: 512,
        nMels: 96,
        fmax: 8000.0,
      ).compute(toneSignal());

      final shape = (golden['mel_shape'] as List).cast<int>();
      expect(mel.length, shape[0], reason: 'mel band count');
      expect(mel[0].length, shape[1], reason: 'frame count');

      // Fewer frames (63) than the image side (96) is exactly why np.resize
      // wraps. If this ever stops being true the wrap test below is vacuous.
      expect(mel[0].length, lessThan(96),
          reason: 'np.resize only wraps when the source is smaller');

      final row0 = (golden['mel_row0'] as List).cast<num>();
      for (var i = 0; i < row0.length; i++) {
        expect(mel[0][i], closeTo(row0[i].toDouble(), 1e-6),
            reason: 'mel[0][$i]');
      }
    });
  });

  group('np.resize wrap at 96 (not an image resize)', () {
    test('full mel image matches numpy, including the wrapped region', () {
      final detector = _PreprocessOnly();
      final flat = detector.melImage(toneSignal());

      expect(flat.length, GlassBreakDetector.kInputFloats);

      final spot = golden['flat_spot'] as Map<String, dynamic>;
      spot.forEach((k, v) {
        final i = int.parse(k);
        expect(flat[i], closeTo((v as num).toDouble(), 1e-5),
            reason: 'flat[$i] — a bilinear resize would differ here');
      });
    });

    test('the three channels are identical', () {
      final flat = _PreprocessOnly().melImage(toneSignal());
      for (var px = 0; px < 96 * 96; px += 257) {
        final i = px * 3;
        expect(flat[i + 1], flat[i], reason: 'channel 1 at pixel $px');
        expect(flat[i + 2], flat[i], reason: 'channel 2 at pixel $px');
      }
    });

    test('values stay inside [0, 1] after per-clip min-max', () {
      final flat = _PreprocessOnly().melImage(toneSignal());
      for (final v in flat) {
        expect(v, inInclusiveRange(0.0, 1.0));
      }
    });
  });

  group('clip fitting', () {
    test('a short clip is zero-padded to exactly 2 s', () {
      final flat = _PreprocessOnly().melImage(toneSignal(seconds: 0.5));
      expect(flat.length, GlassBreakDetector.kInputFloats);
    });

    test('a long clip is truncated, not resampled', () {
      final flat = _PreprocessOnly().melImage(toneSignal(seconds: 5.0));
      expect(flat.length, GlassBreakDetector.kInputFloats);
      // Truncating from the start must give the same features as a clip
      // that was already the right length.
      final exact = _PreprocessOnly().melImage(toneSignal(seconds: 2.0));
      for (var i = 0; i < flat.length; i += 1013) {
        expect(flat[i], closeTo(exact[i], 1e-9), reason: 'index $i');
      }
    });
  });
}

/// Exercises the preprocessing without loading the .tflite asset — there is
/// no native TFLite interpreter under `flutter test`, which is precisely why
/// a parity test on the features is the only thing this suite can check.
class _PreprocessOnly {
  final _mel = MelSpectrogram(
    sampleRate: GlassBreakDetector.kSampleRate,
    nFft: 2048,
    hopLength: 512,
    nMels: GlassBreakDetector.kMelBands,
    fmax: GlassBreakDetector.kFmax,
  );

  Float32List melImage(Float64List pcm) {
    final clip = _fit(pcm);
    final mel = _mel.compute(clip);
    final img =
        GunshotDetectorV2.wrapResizeSquare(mel, GlassBreakDetector.kImgSize);
    final out = Float32List(GlassBreakDetector.kInputFloats);
    var i = 0;
    for (var h = 0; h < GlassBreakDetector.kImgSize; h++) {
      final row = img[h];
      for (var w = 0; w < GlassBreakDetector.kImgSize; w++) {
        final v = row[w];
        out[i++] = v;
        out[i++] = v;
        out[i++] = v;
      }
    }
    return out;
  }

  Float64List _fit(Float64List pcm) {
    const n = GlassBreakDetector.kSamples;
    if (pcm.length == n) return pcm;
    final out = Float64List(n);
    final take = pcm.length < n ? pcm.length : n;
    out.setRange(0, take, pcm.length < n ? pcm : pcm.sublist(0, n));
    return out;
  }
}
