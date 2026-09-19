import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/data/services/vocal_stress_features.dart';

/// Day 332 — parity for the five non-pyin features of the day95 38-vector.
///
/// These are indices `[5]` shimmer, `[6]` hnr, `[33]` rms_mean, `[34]`
/// rms_std, `[35]` rms_max. Golden values were produced by real
/// librosa 0.10.2 in `test/fixtures/m5_vocal_stress_golden.json`, on the
/// **same stored `samples`** the existing 28-feature parity test uses, so
/// the two cannot drift apart.
///
/// Why these five and not all ten: measured on held-out speakers, these are
/// worth +0.052 AUC in English against +0.110 for the five `pyin` features,
/// and they need no new algorithms. See `assets/models/DAY332_M7_M3_PYIN.md`.
///
/// The failure this pins is the one this project keeps hitting — a
/// close-but-not-equal DSP implementation that returns the right shape and
/// plausible values. Specifically:
///   * `librosa.feature.rms` centre-pads by `frame_length ~/ 2` with zeros,
///     so a non-centred implementation is off by one frame and shifted;
///   * it is `sqrt(mean(x^2))`, not `mean(abs(x))`;
///   * hnr runs on the **unpadded** signal and excludes lag 0, which is
///     trivially the maximum — including it would return 1.0 always.
void main() {
  late Map<String, dynamic> golden;
  late VocalStressFeatures feats;

  setUpAll(() {
    golden = jsonDecode(
      File('test/fixtures/m5_vocal_stress_golden.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    feats = VocalStressFeatures();
  });

  Float64List samplesOf(String name) {
    final c = (golden['cases'] as Map<String, dynamic>)[name]
        as Map<String, dynamic>;
    return Float64List.fromList(
      (c['samples'] as List).map((e) => (e as num).toDouble()).toList(),
    );
  }

  Map<String, dynamic> caseOf(String name) =>
      (golden['cases'] as Map<String, dynamic>)[name] as Map<String, dynamic>;

  for (final name in ['noise', 'voiced']) {
    group('case "$name"', () {
      test('rmsFrames matches librosa framing exactly', () {
        final rms = VocalStressFeatures.rmsFrames(samplesOf(name));
        expect(rms.length, caseOf(name)['rms_frames'] as int,
            reason: 'librosa centre-pads, giving 1 + 48000 ~/ 256 = 188 '
                'frames; a non-centred loop yields a different count');
      });

      test('the five extended features match librosa', () {
        final c = caseOf(name);
        final f = feats.extendedFeatures(samplesOf(name));
        // 1e-6 rather than 1e-9: the golden rms comes from librosa's
        // float32 path while Dart accumulates in float64. Measured residual
        // when this was ported was 1.2e-8.
        expect(f[0], closeTo(c['shimmer'] as double, 1e-6), reason: 'shimmer');
        expect(f[1], closeTo(c['hnr'] as double, 1e-6), reason: 'hnr');
        expect(f[2], closeTo(c['rms_mean'] as double, 1e-6), reason: 'rms_mean');
        expect(f[3], closeTo(c['rms_std'] as double, 1e-6), reason: 'rms_std');
        expect(f[4], closeTo(c['rms_max'] as double, 1e-6), reason: 'rms_max');
      });
    });
  }

  test('hnr actually separates periodic from aperiodic audio', () {
    // The strongest single check here. If hnr were mis-implemented — lag 0
    // included, or normalised wrongly — both cases would collapse to the
    // same value and the closeTo assertions above could still pass on a
    // coincidence. These two differ by ~0.96 of the full [0,1] range.
    final noise = feats.extendedFeatures(samplesOf('noise'))[1];
    final voiced = feats.extendedFeatures(samplesOf('voiced'))[1];
    expect(noise, lessThan(0.1),
        reason: 'white noise has no periodicity; golden says 0.0108');
    expect(voiced, greaterThan(0.9),
        reason: 'a voiced signal is strongly periodic; golden says 0.9743');
    expect(voiced - noise, greaterThan(0.85));
  });

  test('extract() is untouched at 28, so the shipped model still fits', () {
    // m5_vocal_stress_v2 takes exactly [1,28]. Widening extract() would
    // silently break its input contract, which is why the new features live
    // in a separate method until a 33-feature model ships.
    expect(VocalStressFeatures.kFeatureDim, 28);
    expect(feats.extract(samplesOf('voiced')).length, 28);
    expect(feats.extendedFeatures(samplesOf('voiced')).length, 5);
  });

  test('short input is zero-padded, not rejected', () {
    final short = Float64List.fromList(List<double>.filled(1000, 0.01));
    final f = feats.extendedFeatures(short);
    expect(f.length, 5);
    for (final v in f) {
      expect(v.isFinite, isTrue);
    }
  });
}
