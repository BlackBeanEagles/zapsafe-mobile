import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/data/services/yin_pitch.dart';

/// Day 333 — parity between [YinPitch] and `work/yin_lite/yin_lite.py`.
///
/// The reference here is deliberately **not** `librosa.pyin`. The model is
/// retrained on plain YIN, so the contract Dart must honour is the Python
/// module, and the HMM was measured to be worth only 0.011 AUC.
///
/// Goldens live in `test/fixtures/m5_vocal_stress_golden.json` on the same
/// stored `samples` as the mfcc and rms parity tests, so all three cannot
/// drift apart.
void main() {
  late Map<String, dynamic> golden;

  setUpAll(() {
    golden = jsonDecode(
      File('test/fixtures/m5_vocal_stress_golden.json').readAsStringSync(),
    ) as Map<String, dynamic>;
  });

  Map<String, dynamic> caseOf(String n) =>
      (golden['cases'] as Map<String, dynamic>)[n] as Map<String, dynamic>;

  Float64List samplesOf(String n) => Float64List.fromList(
        (caseOf(n)['samples'] as List).map((e) => (e as num).toDouble()).toList(),
      );

  group('search range matches the Python constants', () {
    test('tau bounds follow from fmin/fmax, not hardcoded', () {
      // floor(16000/2093.0045) = 7 and ceil(16000/65.40639)+1 = 246, capped
      // at frameLength/2 = 256. If someone retunes fmin/fmax without
      // rechecking these, the tracker silently searches the wrong periods.
      expect((YinPitch.kSampleRate / YinPitch.kFMax).floor(), 7);
      expect((YinPitch.kSampleRate / YinPitch.kFMin).ceil() + 1, 246);
      expect(246, lessThan(YinPitch.kFrameLength ~/ 2));
    });
  });

  for (final name in ['noise', 'voiced']) {
    group('case "$name"', () {
      test('frame count matches librosa-style centre padding', () {
        final t = YinPitch.track(samplesOf(name));
        expect(t.f0.length, caseOf(name)['yin_frames'] as int);
        expect(t.voiced.length, caseOf(name)['yin_frames'] as int);
      });

      test('per-frame f0 and voiced flags match for the first 8 frames', () {
        // Localises a mismatch to the tracker rather than the aggregation:
        // if these pass but the summary features fail, the bug is in
        // pitchFeatures, and vice versa.
        final t = YinPitch.track(samplesOf(name));
        final gf = caseOf(name)['yin_f0_first8'] as List;
        final gv = caseOf(name)['yin_voiced_first8'] as List;
        for (var i = 0; i < gf.length; i++) {
          expect(t.voiced[i], gv[i] as bool, reason: 'voiced[$i]');
          if (gf[i] == null) {
            expect(t.f0[i].isNaN, isTrue, reason: 'f0[$i] should be NaN');
          } else {
            expect(t.f0[i], closeTo((gf[i] as num).toDouble(), 1e-6),
                reason: 'f0[$i]');
          }
        }
      });

      test('the five pitch features match', () {
        final c = caseOf(name);
        final f = YinPitch.pitchFeatures(samplesOf(name));
        // Tolerances are RELATIVE, because `pitch_features` returns
        // np.float32 while Dart computes in float64 — so the golden is the
        // rounded one and the error scales with magnitude. float32 carries
        // ~1.2e-7 relative epsilon; 1e-6 relative is a safe bound and still
        // tight enough to catch a real algorithmic difference. An absolute
        // 1e-6 fails here purely because f0_mean is ~180 (observed gap
        // 5.3e-6) and voiced_frac is ~1.0 (observed gap 2.9e-8), neither of
        // which is a disagreement about what was computed.
        void expectRel(double actual, double want, String label) {
          final tol = 1e-6 * (want.abs() < 1.0 ? 1.0 : want.abs());
          expect(actual, closeTo(want, tol), reason: label);
        }

        expectRel(f[0], c['yin_voiced_frac'] as double, 'voiced_frac');
        expectRel(f[1], c['yin_f0_mean'] as double, 'f0_mean');
        expectRel(f[2], c['yin_f0_std'] as double, 'f0_std');
        expectRel(f[3], c['yin_f0_range'] as double, 'f0_range');
        // jitter is ~1e-5 in absolute terms, so a loose absolute tolerance
        // would pass on any implementation returning roughly zero. Keep it
        // tight and absolute: this is the feature that distinguishes
        // "difference of periods" from "difference of frequencies", which is
        // about four orders of magnitude.
        expect(f[4], closeTo(c['yin_jitter'] as double, 1e-11),
            reason: 'jitter — mean abs diff of PERIODS, not frequencies');
      });
    });
  }

  test('it actually discriminates periodic from aperiodic audio', () {
    // The behavioural check. Numeric closeTo assertions can pass on a
    // tracker that returns near-zero everywhere; these cannot.
    final noise = YinPitch.pitchFeatures(samplesOf('noise'));
    final voiced = YinPitch.pitchFeatures(samplesOf('voiced'));
    expect(noise[0], 0.0,
        reason: 'white noise has no period that clears the 0.1 threshold');
    expect(voiced[0], greaterThan(0.99),
        reason: 'a sustained tone should be voiced in almost every frame');
    expect(voiced[1], closeTo(180.05, 0.5),
        reason: 'and the detected f0 should be the real one');
  });

  test('a synthesised tone is tracked at its true frequency', () {
    // Independent of the fixture: build a 220 Hz sawtooth and check the
    // tracker finds it. Guards against a golden that was generated from an
    // already-broken reference.
    const sr = YinPitch.kSampleRate;
    final y = Float64List(sr * 3);
    for (var i = 0; i < y.length; i++) {
      final phase = (i * 220.0 / sr) % 1.0;
      y[i] = 2.0 * phase - 1.0;
    }
    final f = YinPitch.pitchFeatures(y);
    expect(f[0], greaterThan(0.95));
    expect(f[1], closeTo(220.0, 2.0),
        reason: 'detected f0 must be the frequency actually synthesised');
  });

  test('silence is unvoiced, not a division by zero', () {
    final f = YinPitch.pitchFeatures(Float64List(YinPitch.kSampleRate * 3));
    expect(f[0], 0.0);
    for (final v in f) {
      expect(v.isFinite, isTrue);
    }
  });
}
