import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/data/services/audio_resampler.dart';

/// Day 258 — scipy parity for the 44,100 -> 22,050 Hz fallback path.
///
/// Golden values in test/fixtures/resample_golden.json come from
/// `scipy.signal.resample_poly(x, 1, 2)` and `scipy.signal.firwin(41, 0.5,
/// window=('kaiser', 5.0))` on scipy 1.14.1.
///
/// The failure this guards against is aliasing. Naive decimation produces an
/// array of the right length, the right amplitude range, and a plausible
/// waveform — but folds everything above 5,512 Hz down into the speech band.
/// For a scream, whose energy sits high, that corrupts precisely the region
/// the model discriminates on. No structural assertion can see it; the
/// `aliasing` group below is the test that can.
void main() {
  late Map<String, dynamic> golden;

  setUpAll(() {
    golden = jsonDecode(
      File('test/fixtures/resample_golden.json').readAsStringSync(),
    ) as Map<String, dynamic>;
  });

  List<double> nums(String key) =>
      (golden[key] as List).cast<num>().map((e) => e.toDouble()).toList();

  // The exact signal the fixture was generated from: 440 Hz + 3 kHz + 17 kHz
  // at 44.1 kHz. The 17 kHz term is above the 22.05 kHz output's Nyquist and
  // must be filtered away, not folded down.
  Float64List source() {
    const sr = 44100;
    const n = sr ~/ 2;
    final x = Float64List(n);
    for (var i = 0; i < n; i++) {
      final t = i / sr;
      x[i] = 0.4 * math.sin(2 * math.pi * 440 * t) +
          0.3 * math.sin(2 * math.pi * 3000 * t) +
          0.3 * math.sin(2 * math.pi * 17000 * t);
    }
    return x;
  }

  group('filter design matches scipy.signal.firwin', () {
    test('41-tap Kaiser(5.0) lowpass at 0.5 is elementwise equal', () {
      final expected = nums('firwin_41_kaiser5');
      final h = AudioResampler.debugFirwin(41, 0.5, 5.0);
      expect(h.length, expected.length);
      for (var i = 0; i < expected.length; i++) {
        expect(h[i], closeTo(expected[i], 1e-12), reason: 'tap $i');
      }
    });

    test('has unity DC gain, as scipy scale=True guarantees', () {
      final h = AudioResampler.debugFirwin(41, 0.5, 5.0);
      expect(h.reduce((a, b) => a + b), closeTo(1.0, 1e-12));
    });
  });

  group('resample_poly parity', () {
    test('output length matches scipy', () {
      final y = AudioResampler.resample(source(), 44100, 22050);
      expect(y.length, golden['y_len']);
    });

    test('head, middle and tail match scipy elementwise', () {
      final y = AudioResampler.resample(source(), 44100, 22050);
      void cmp(String key, int offset) {
        final e = nums(key);
        for (var i = 0; i < e.length; i++) {
          expect(y[offset + i], closeTo(e[i], 1e-9),
              reason: '$key[$i] diverged from scipy.resample_poly');
        }
      }

      cmp('y_head', 0);
      cmp('y_mid', 11000);
      cmp('y_tail', y.length - 32);
    });

    test('sum and peak match scipy', () {
      final y = AudioResampler.resample(source(), 44100, 22050);
      var sum = 0.0, absmax = 0.0;
      for (final v in y) {
        sum += v;
        absmax = math.max(absmax, v.abs());
      }
      expect(sum, closeTo((golden['y_sum'] as num).toDouble(), 1e-6));
      expect(absmax, closeTo((golden['y_absmax'] as num).toDouble(), 1e-9));
    });
  });

  group('aliasing', () {
    // The decisive behavioural test, independent of the fixture.
    test('suppresses a 17kHz tone instead of folding it to 5kHz', () {
      const sr = 44100;
      const n = sr ~/ 2;
      final x = Float64List(n);
      for (var i = 0; i < n; i++) {
        x[i] = math.sin(2 * math.pi * 17000 * (i / sr));
      }
      final y = AudioResampler.resample(x, sr, 22050);

      // 17 kHz sampled at 22.05 kHz would alias to |17000 - 22050| = 5050 Hz.
      // A correct anti-alias filter leaves almost nothing behind.
      var energy = 0.0;
      for (final v in y) {
        energy += v * v;
      }
      final rms = math.sqrt(energy / y.length);
      expect(rms, lessThan(0.02),
          reason: 'a 17kHz tone survived the decimation — it has aliased '
              'down to ~5kHz, straight into the scream band');
    });

    test('passes a 440Hz tone through essentially untouched', () {
      const sr = 44100;
      const n = sr ~/ 2;
      final x = Float64List(n);
      for (var i = 0; i < n; i++) {
        x[i] = math.sin(2 * math.pi * 440 * (i / sr));
      }
      final y = AudioResampler.resample(x, sr, 22050);
      // Ignore the filter's transient at each end.
      var energy = 0.0;
      var count = 0;
      for (var i = 100; i < y.length - 100; i++) {
        energy += y[i] * y[i];
        count++;
      }
      expect(math.sqrt(energy / count), closeTo(math.sqrt(0.5), 0.02));
    });
  });

  group('pass-through and int16 conversion', () {
    test('identical rates return the input untouched', () {
      final x = source();
      expect(AudioResampler.resample(x, 22050, 22050), same(x));
    });

    test('int16 LE bytes decode to [-1, 1) using a 32768 divisor', () {
      // 0, 1, -1, 32767, -32768 as little-endian int16.
      final bytes = Uint8List.fromList([
        0x00, 0x00, //      0
        0x01, 0x00, //      1
        0xFF, 0xFF, //     -1
        0xFF, 0x7F, //  32767
        0x00, 0x80, // -32768
      ]);
      final d = AudioResampler.pcm16ToDouble(bytes);
      expect(d.length, 5);
      expect(d[0], 0.0);
      expect(d[1], closeTo(1 / 32768, 1e-15));
      expect(d[2], closeTo(-1 / 32768, 1e-15));
      expect(d[3], closeTo(32767 / 32768, 1e-15));
      expect(d[4], -1.0, reason: 'int16 is asymmetric; -32768 maps to -1.0');
    });
  });
}
