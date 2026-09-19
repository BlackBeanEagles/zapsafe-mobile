import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/data/services/mel_spectrogram.dart';
import 'package:zapsafe_mobile/data/services/vocal_stress_features.dart';

/// Day 325 — librosa parity for the M5 28-dim prosodic vector.
///
/// Golden values in `test/fixtures/m5_vocal_stress_golden.json` were produced
/// by **real librosa 0.10.2**, not reimplemented here, and the fixture ships
/// the input samples so Dart computes from byte-identical audio.
///
/// This test exists because of the specific way this kind of code fails. A
/// mel/DCT pipeline that is close but not equal yields a tensor of exactly
/// the right shape, in exactly the right range, that the model scores
/// wrongly. Nothing throws. At runtime it is indistinguishable from a working
/// detector. Every incident this project has had in the ML layer is that
/// shape:
///
///  * `scream_classifier_v1` claimed recall 0.95 and fired on 5.6% of real
///    screams (trained on the wrong distribution);
///  * `mg_gunshot_retrain` emitted a constant 0.3633 for every input (int8
///    clamping) while all 775 Dart tests passed;
///  * `h_aggressive_speech` drops from AUC 0.844 to 0.52 on unnormalised
///    features.
///
/// None of those were catchable by a shape assertion, so this asserts
/// numbers.
void main() {
  late Map<String, dynamic> golden;
  late Map<String, dynamic> params;

  setUpAll(() {
    golden = jsonDecode(
      File('test/fixtures/m5_vocal_stress_golden.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    params = golden['params'] as Map<String, dynamic>;
  });

  Float64List samplesOf(String c) => Float64List.fromList(
      ((golden['cases'] as Map)[c]['samples'] as List)
          .cast<num>()
          .map((e) => e.toDouble())
          .toList());

  List<double> vec(String c, String k) =>
      ((golden['cases'] as Map)[c][k] as List)
          .cast<num>()
          .map((e) => e.toDouble())
          .toList();

  MelSpectrogram mel() => MelSpectrogram(
        sampleRate: params['sr'] as int,
        nFft: params['n_fft'] as int,
        hopLength: params['hop_length'] as int,
        nMels: 128,
        fmax: (params['sr'] as int) / 2,
      );

  test('the fixture describes the contract this code was written against', () {
    expect(params['sr'], VocalStressFeatures.kSampleRate);
    expect(params['n_fft'], VocalStressFeatures.kNFft);
    expect(params['hop_length'], VocalStressFeatures.kHopLength);
    expect(params['n_mfcc'], VocalStressFeatures.kNMfcc);
    expect(params['samples'], VocalStressFeatures.kSamples);
    expect((golden['feature_order'] as List).length,
        VocalStressFeatures.kFeatureDim);
  });

  group('MelSpectrogram.mfcc matches librosa.feature.mfcc', () {
    for (final c in ['noise', 'voiced']) {
      test('$c: every coefficient, every frame', () {
        final got = mel().mfcc(samplesOf(c), nMfcc: 13);
        final want = ((golden['cases'] as Map)[c]['mfcc'] as List)
            .map((r) => (r as List).cast<num>().map((e) => e.toDouble()).toList())
            .toList();

        expect(got.length, want.length, reason: 'coefficient count');
        expect(got[0].length, want[0].length, reason: 'frame count');

        var worst = 0.0;
        var worstAt = '';
        for (var k = 0; k < want.length; k++) {
          for (var t = 0; t < want[k].length; t++) {
            final d = (got[k][t] - want[k][t]).abs();
            if (d > worst) {
              worst = d;
              worstAt = 'mfcc[$k] frame $t: got ${got[k][t]} want ${want[k][t]}';
            }
          }
        }
        // MFCCs here span roughly -600..+50, so 1e-6 is tight relative
        // tolerance and catches any real formulation error (wrong DCT
        // normalisation, wrong reference, wrong filterbank).
        expect(worst, lessThan(1e-6), reason: 'worst mismatch — $worstAt');
      });
    }
  });

  group('the ref=1.0 trap is real, not theoretical', () {
    test('compute() uses ref=max and would corrupt mfcc[0]', () {
      // Proves why mfcc() needed its own dB path. If someone "simplifies"
      // mfcc() to reuse compute(), mfcc[0] silently shifts by tens of dB
      // while mfcc[1..12] stay correct — the hardest kind of bug to notice.
      const c = 'voiced';
      final offset =
          ((golden['cases'] as Map)[c]['ref_offset_db'] as num).toDouble();
      expect(offset.abs(), greaterThan(1.0),
          reason: 'the two references must differ measurably for this to matter');

      final ref1 = vec(c, 'mel_db_ref1_first_frame');
      final refMax = vec(c, 'mel_db_refmax_first_frame');
      final dbFromCompute = mel().compute(samplesOf(c), normalize: false);
      for (var i = 0; i < refMax.length; i++) {
        expect(dbFromCompute[i][0], closeTo(refMax[i], 1e-6),
            reason: 'compute() is the ref=max path');
      }
      // And the two really are different data, band by band.
      var maxDelta = 0.0;
      for (var i = 0; i < ref1.length; i++) {
        final d = (ref1[i] - refMax[i]).abs();
        if (d > maxDelta) maxDelta = d;
      }
      expect(maxDelta, greaterThan(1.0));
    });
  });

  group('the full 28-dim vector', () {
    for (final c in ['noise', 'voiced']) {
      test('$c: mfcc means and stds match librosa', () {
        final got = VocalStressFeatures(mel: mel()).extract(samplesOf(c));
        final want = vec(c, 'feature28');
        expect(got.length, VocalStressFeatures.kFeatureDim);
        for (var i = 0; i < 26; i++) {
          expect(got[i], closeTo(want[i], 1e-5),
              reason: '${(golden['feature_order'] as List)[i]} mismatch');
        }
      });

      test('$c: zcr and spectral centroid match librosa', () {
        final got = VocalStressFeatures(mel: mel()).extract(samplesOf(c));
        final wantZcr =
            ((golden['cases'] as Map)[c]['zcr_mean'] as num).toDouble();
        final wantCen = ((golden['cases'] as Map)[c]
                ['spectral_centroid_over_nyquist'] as num)
            .toDouble();
        // Looser than the MFCC bound: librosa's framing/padding for these two
        // is reimplemented rather than derived from the shared STFT, so small
        // edge-frame differences are expected. 0.02 absolute on values that
        // live in [0, 1] still catches any structural error — a power-vs-
        // magnitude centroid or a missing /(sr/2) would be off by far more.
        expect(got[26], closeTo(wantZcr, 0.02), reason: 'zcr');
        expect(got[27], closeTo(wantCen, 0.02), reason: 'centroid/nyquist');
      });
    }
  });

  group('input handling', () {
    test('short audio is zero-padded to exactly 3 s', () {
      final short = Float64List(1000);
      final got = VocalStressFeatures(mel: mel()).extract(short);
      expect(got.length, VocalStressFeatures.kFeatureDim);
      expect(got.every((v) => v.isFinite), isTrue,
          reason: 'silence must not produce NaN or infinity');
    });

    test('over-length audio is truncated, not rejected', () {
      final long = Float64List(VocalStressFeatures.kSamples * 2);
      for (var i = 0; i < long.length; i++) {
        long[i] = (i % 97) / 97.0 - 0.5;
      }
      final got = VocalStressFeatures(mel: mel()).extract(long);
      expect(got.every((v) => v.isFinite), isTrue);
    });
  });
}
