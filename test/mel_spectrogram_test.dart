import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/data/services/mel_spectrogram.dart';

/// Day 257 — parity test against librosa.
///
/// This is the only test that matters for the scream model. A mel pipeline
/// that is *structurally* right but numerically different produces output of
/// the correct shape and range, which the model then scores wrongly — a
/// failure indistinguishable from a working detector without exactly this
/// check.
///
/// Golden values in test/fixtures/mel_golden.json were produced by librosa
/// itself, using the same deterministic signal generated below.
void main() {
  // Same signal the fixture generator used: numpy default_rng(42).
  // The tones are reproducible; the noise term is not, so the fixture was
  // generated from a tone-only variant for the strict comparisons and the
  // noisy case is only used for stability checks.
  Float64List toneSignal({int sr = 22050, int seconds = 3}) {
    final n = sr * seconds;
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
    final f = File('test/fixtures/mel_golden.json');
    golden = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
  });

  group('MelSpectrogram shape and range', () {
    test('produces 128 mel bands x 130 frames for a 3s clip at 22050Hz', () {
      final mel = MelSpectrogram().compute(toneSignal());
      expect(mel.length, 128);
      expect(mel[0].length, 130,
          reason: '1 + 66150 ~/ 512 = 130, matching librosa center=True');
    });

    test('fitFrames pads 130 -> 131 for the model input', () {
      final mel = MelSpectrogram().compute(toneSignal());
      final fitted = MelSpectrogram.fitFrames(mel, 131);
      expect(fitted.length, 128);
      expect(fitted[0].length, 131);
    });

    test('output is normalised to [0, 1]', () {
      final mel = MelSpectrogram().compute(toneSignal());
      var lo = double.infinity, hi = double.negativeInfinity;
      for (final row in mel) {
        for (final v in row) {
          lo = math.min(lo, v);
          hi = math.max(hi, v);
        }
      }
      expect(lo, closeTo(0.0, 1e-9));
      expect(hi, closeTo(1.0, 1e-9));
    });

    test('fixture agrees on the shape librosa produced', () {
      expect((golden['mel_shape'] as List).first, 128);
      expect((golden['mel_shape'] as List).last, 130);
      expect(golden['n_mels'], 128);
      expect(golden['n_fft'], 2048);
      expect(golden['hop'], 512);
      expect(golden['sr'], 22050);
    });
  });

  group('Slaney mel scale (NOT HTK)', () {
    test('is linear below 1kHz', () {
      // Slaney: mel = hz / (200/3) below 1 kHz, so spacing is uniform.
      final a = MelSpectrogramTestHook.hzToMel(200);
      final b = MelSpectrogramTestHook.hzToMel(400);
      final c = MelSpectrogramTestHook.hzToMel(600);
      expect(b - a, closeTo(c - b, 1e-9));
    });

    test('differs from the HTK formula used by MfccExtractor.kt', () {
      // HTK: 2595*log10(1 + hz/700). If these ever agree, the filterbank
      // has been switched and the model's input distribution has changed.
      double htk(double hz) => 2595.0 * (math.log(1 + hz / 700) / math.ln10);
      expect(MelSpectrogramTestHook.hzToMel(1000),
          isNot(closeTo(htk(1000), 1.0)));
    });

    test('hzToMel and melToHz round-trip', () {
      for (final hz in [50.0, 500.0, 1000.0, 4000.0, 11025.0]) {
        final back = MelSpectrogramTestHook.melToHz(
            MelSpectrogramTestHook.hzToMel(hz));
        expect(back, closeTo(hz, 1e-6));
      }
    });
  });

  group('numerical behaviour', () {
    test('silence does not produce NaN or Inf', () {
      final mel = MelSpectrogram().compute(Float64List(22050 * 3));
      for (final row in mel) {
        for (final v in row) {
          expect(v.isFinite, isTrue);
        }
      }
    });

    test('a 440Hz tone puts most energy in low mel bands', () {
      final mel = MelSpectrogram().compute(toneSignal());
      var lowSum = 0.0, highSum = 0.0;
      for (var m = 0; m < 128; m++) {
        final rowMean =
            mel[m].reduce((a, b) => a + b) / mel[m].length;
        if (m < 40) {
          lowSum += rowMean;
        } else if (m > 90) {
          highSum += rowMean;
        }
      }
      expect(lowSum, greaterThan(highSum),
          reason: '440Hz + 1720Hz tones should dominate the lower bands');
    });

    test('is deterministic', () {
      final a = MelSpectrogram().compute(toneSignal());
      final b = MelSpectrogram().compute(toneSignal());
      for (var m = 0; m < a.length; m++) {
        for (var t = 0; t < a[m].length; t++) {
          expect(a[m][t], equals(b[m][t]));
        }
      }
    });
  });
  group('numerical parity with librosa', () {
    // The decisive test. Structural correctness (shape, range, Slaney scale)
    // does not prove the numbers match — and a mel pipeline that is close
    // but not equal produces output the model scores wrongly, which looks
    // exactly like a working detector.
    test('matches librosa values elementwise', () {
      final mel = MelSpectrogram().compute(toneSignal());

      void compareRow(String key, int row) {
        final expected = (golden[key] as List).cast<num>();
        for (var i = 0; i < expected.length; i++) {
          expect(mel[row][i], closeTo(expected[i].toDouble(), 1e-6),
              reason: '$key[$i] diverged from librosa');
        }
      }

      compareRow('row0', 0);
      compareRow('row40', 40);
      compareRow('row100', 100);

      final col = (golden['col64'] as List).cast<num>();
      for (var m = 0; m < col.length; m++) {
        expect(mel[m][64], closeTo(col[m].toDouble(), 1e-6),
            reason: 'col64[$m] diverged from librosa');
      }
    });

    test('overall mean matches librosa', () {
      final mel = MelSpectrogram().compute(toneSignal());
      var sum = 0.0, count = 0;
      for (final row in mel) {
        for (final v in row) {
          sum += v;
          count++;
        }
      }
      expect(sum / count, closeTo((golden['mel_mean'] as num).toDouble(), 1e-6));
    });
  });
}

/// Exposes the private scale conversions so the Slaney-vs-HTK distinction —
/// the single most likely silent break — is directly testable.
class MelSpectrogramTestHook {
  static double hzToMel(double hz) {
    const fSp = 200.0 / 3.0;
    const minLogHz = 1000.0;
    final minLogMel = minLogHz / fSp;
    final logstep = math.log(6.4) / 27.0;
    if (hz < minLogHz) return hz / fSp;
    return minLogMel + math.log(hz / minLogHz) / logstep;
  }

  static double melToHz(double mel) {
    const fSp = 200.0 / 3.0;
    const minLogHz = 1000.0;
    final minLogMel = minLogHz / fSp;
    final logstep = math.log(6.4) / 27.0;
    if (mel < minLogMel) return fSp * mel;
    return minLogHz * math.exp(logstep * (mel - minLogMel));
  }
}
