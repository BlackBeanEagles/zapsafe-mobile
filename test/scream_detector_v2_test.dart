import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/data/services/mel_spectrogram.dart';
import 'package:zapsafe_mobile/data/services/scream_detector_v2.dart';

/// Day 257 — the tensor m1_scream_v2 actually receives.
///
/// `infer()` needs a native TFLite library and so can't run on the host VM,
/// but everything upstream of it can — and that is where this pipeline goes
/// wrong silently. These tests pin the input contract: exact length, exact
/// layout, exact range, and the 3-second fitting rule.
void main() {
  Float64List tone({int samples = ScreamDetectorV2.kSamples}) {
    final y = Float64List(samples);
    for (var i = 0; i < samples; i++) {
      final t = i / ScreamDetectorV2.kSampleRate;
      y[i] = 0.5 * math.sin(2 * math.pi * 440 * t) +
          0.25 * math.sin(2 * math.pi * 1720 * t);
    }
    return y;
  }

  // tryLoad() returns null on the host VM (no native TFLite), so build the
  // feature path through a detector-free helper with identical parameters.
  final mel = MelSpectrogram(
    sampleRate: ScreamDetectorV2.kSampleRate,
    nFft: 2048,
    hopLength: 512,
    nMels: ScreamDetectorV2.kMelBands,
  );

  Float32List melInput(Float64List pcm) {
    final fitted = Float64List(ScreamDetectorV2.kSamples);
    fitted.setRange(
        0,
        math.min(pcm.length, ScreamDetectorV2.kSamples),
        pcm.length > ScreamDetectorV2.kSamples
            ? pcm.sublist(0, ScreamDetectorV2.kSamples)
            : pcm);
    final m = MelSpectrogram.fitFrames(
        mel.compute(fitted), ScreamDetectorV2.kFrames);
    final out = Float32List(ScreamDetectorV2.kInputFloats);
    var i = 0;
    for (var b = 0; b < ScreamDetectorV2.kMelBands; b++) {
      for (var t = 0; t < ScreamDetectorV2.kFrames; t++) {
        out[i++] = m[b][t];
      }
    }
    return out;
  }

  group('input tensor contract', () {
    test('constants match the exported model signature', () {
      // Measured from scream_classifier_v1.tflite: [1,128,131,1] -> [1,1].
      expect(ScreamDetectorV2.kMelBands, 128);
      expect(ScreamDetectorV2.kFrames, 131);
      expect(ScreamDetectorV2.kInputFloats, 128 * 131);
      expect(ScreamDetectorV2.kSampleRate, 22050);
      expect(ScreamDetectorV2.kSamples, 66150,
          reason: '3 s at 22050 Hz, per PREPROCESSING_SPEC.md');
    });

    test('produces exactly kInputFloats values in [0, 1]', () {
      final x = melInput(tone());
      expect(x.length, ScreamDetectorV2.kInputFloats);
      for (final v in x) {
        expect(v.isFinite, isTrue);
        expect(v, inInclusiveRange(0.0, 1.0));
      }
    });

    test('is laid out [mel band][frame], not transposed', () {
      // A transposed tensor has the right length and range and would be
      // accepted by the interpreter without complaint, so assert the
      // layout directly against the 2-D mel it came from.
      final pcm = tone();
      final x = melInput(pcm);
      final m = MelSpectrogram.fitFrames(
          mel.compute(pcm), ScreamDetectorV2.kFrames);
      for (final b in [0, 1, 64, 127]) {
        for (final t in [0, 1, 65, 130]) {
          // 1e-6, not tighter: the tensor is Float32 and the mel is Float64,
          // so the downcast costs ~1e-7. Anything transposed is off by far
          // more than this.
          expect(x[b * ScreamDetectorV2.kFrames + t], closeTo(m[b][t], 1e-6),
              reason: 'band $b frame $t is not at the row-major offset');
        }
      }
    });

    test('the padded 131st frame is the zero column, not a repeat', () {
      final m = MelSpectrogram.fitFrames(
          mel.compute(tone()), ScreamDetectorV2.kFrames);
      expect(m[0].length, 131);
      for (var b = 0; b < ScreamDetectorV2.kMelBands; b++) {
        expect(m[b][130], 0.0);
      }
    });
  });

  group('3-second fitting', () {
    test('short audio is zero-padded to full length', () {
      final x = melInput(tone(samples: ScreamDetectorV2.kSampleRate)); // 1 s
      expect(x.length, ScreamDetectorV2.kInputFloats);
      for (final v in x) {
        expect(v.isFinite, isTrue);
      }
    });

    test('long audio is truncated, matching the first 3 s exactly', () {
      final long = tone(samples: ScreamDetectorV2.kSampleRate * 5);
      expect(melInput(long), melInput(tone()));
    });

    test('silence yields a finite tensor rather than NaN', () {
      final x = melInput(Float64List(ScreamDetectorV2.kSamples));
      for (final v in x) {
        expect(v.isFinite, isTrue);
      }
    });
  });

  group('loading', () {
    test('tryLoad returns null instead of throwing when TFLite is absent', () {
      // Host VM has no native TFLite library. The contract is a null return
      // so ModelBundleService falls back to the heuristic detector.
      expect(ScreamDetectorV2.tryLoad(), completion(isNull));
    });
  });
}
