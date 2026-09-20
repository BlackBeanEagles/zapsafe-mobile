import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/data/services/vocal_stress_features.dart';
import 'package:zapsafe_mobile/data/services/yin_pitch.dart';

/// Day 336 — `compose38()` must emit the day95 order exactly.
///
/// This is the assembly step, and assembly is where an ordering bug hides
/// best: every individual feature is already parity-tested (mfcc/zcr/centroid
/// in `vocal_stress_features_test.dart`, shimmer/hnr/rms in
/// `day332_vocal_stress_extended_test.dart`, pitch in
/// `day333_yin_pitch_test.dart`), so a permutation here would produce a
/// vector of exactly the right length, made of exactly the right numbers, in
/// the wrong slots — and every component test would still pass.
///
/// `m4_vocal_stress_en_38` scores 0.8321 held-out-speaker against 0.6949 for
/// the 28 features alone, so there is real signal to lose.
void main() {
  late Map<String, dynamic> golden;
  late VocalStressFeatures feats;

  setUpAll(() {
    golden = jsonDecode(
      File('test/fixtures/m5_vocal_stress_golden.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    feats = VocalStressFeatures();
  });

  Map<String, dynamic> caseOf(String n) =>
      (golden['cases'] as Map<String, dynamic>)[n] as Map<String, dynamic>;

  Float64List samplesOf(String n) => Float64List.fromList(
        (caseOf(n)['samples'] as List).map((e) => (e as num).toDouble()).toList(),
      );

  test('the trained model agrees with this file about the order', () {
    // The training report carries its own feature_order. If these ever
    // disagree the model is being fed a permutation, so pin them together.
    final report = jsonDecode(
      File('test/fixtures/m4_en_38_golden.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final order = (report['feature_order'] as List).cast<String>();
    expect(order.length, VocalStressFeatures.kFullFeatureDim);
    expect(order.sublist(0, 7), [
      'voiced_frac', 'f0_mean', 'f0_std', 'f0_range', 'jitter',
      'shimmer', 'hnr',
    ]);
    expect(order[7], 'mfcc_mean_0');
    expect(order[19], 'mfcc_mean_12');
    expect(order[20], 'mfcc_std_0');
    expect(order[32], 'mfcc_std_12');
    expect(order.sublist(33), [
      'rms_mean', 'rms_std', 'rms_max', 'zcr',
      'spectral_centroid_over_nyquist',
    ]);
  });

  for (final name in ['noise', 'voiced']) {
    test('case "$name": every slot holds the value its source produced', () {
      final pcm = samplesOf(name);
      final full = feats.compose38(pcm);
      final base = feats.extract(pcm);
      final ext = feats.extendedFeatures(pcm);
      final pitch = YinPitch.pitchFeatures(pcm);

      expect(full.length, 38);

      // 0..4 pitch
      for (var i = 0; i < 5; i++) {
        expect(full[i], pitch[i], reason: 'slot $i must be pitch[$i]');
      }
      // 5,6 shimmer + hnr — NOT rms, which is the easy mistake given
      // extendedFeatures returns them adjacently
      expect(full[5], ext[0], reason: 'slot 5 is shimmer');
      expect(full[6], ext[1], reason: 'slot 6 is hnr');
      // 7..32 the 26 mfcc values, means then stds
      for (var i = 0; i < 26; i++) {
        expect(full[7 + i], base[i], reason: 'slot ${7 + i} is extract[$i]');
      }
      // 33..35 rms, which live at extendedFeatures[2..4]
      expect(full[33], ext[2], reason: 'slot 33 is rms_mean');
      expect(full[34], ext[3], reason: 'slot 34 is rms_std');
      expect(full[35], ext[4], reason: 'slot 35 is rms_max');
      // 36,37 zcr and centroid, the LAST two of extract, not the first two
      expect(full[36], base[26], reason: 'slot 36 is zcr');
      expect(full[37], base[27], reason: 'slot 37 is centroid/nyquist');
    });

    test('case "$name": matches the golden feature values directly', () {
      final full = feats.compose38(samplesOf(name));
      final c = caseOf(name);
      // Cross-checked against the values librosa produced for this same
      // audio, independently of which slot they came from.
      expect(full[5], closeTo(c['shimmer'] as double, 1e-6));
      expect(full[6], closeTo(c['hnr'] as double, 1e-6));
      expect(full[33], closeTo(c['rms_mean'] as double, 1e-6));
      expect(full[34], closeTo(c['rms_std'] as double, 1e-6));
      expect(full[35], closeTo(c['rms_max'] as double, 1e-6));
      expect(full[0], closeTo(c['yin_voiced_frac'] as double, 1e-6));
      final f0 = c['yin_f0_mean'] as double;
      expect(full[1], closeTo(f0, 1e-6 * (f0.abs() < 1 ? 1 : f0.abs())));
    });
  }

  test('a permuted vector would be caught — the slots are not interchangeable',
      () {
    // Sanity that the assertions above have teeth: pitch, mfcc and rms
    // occupy very different magnitude ranges, so a shuffle is detectable.
    final full = feats.compose38(samplesOf('voiced'));
    expect(full[1], greaterThan(50.0),
        reason: 'f0_mean is in Hz, order ~180');
    expect(full[33].abs(), lessThan(1.0),
        reason: 'rms_mean is a normalised amplitude, order 0.26');
    expect(full[7].abs(), greaterThan(1.0),
        reason: 'mfcc_mean_0 is a dB-scale coefficient, order -200');
    expect(full[36], inInclusiveRange(0.0, 1.0),
        reason: 'zcr is a rate in [0,1]');
    expect(full[37], inInclusiveRange(0.0, 1.0),
        reason: 'centroid is divided by nyquist, so it lands in [0,1]');
  });

  test('short and over-length audio are handled like extract()', () {
    expect(feats.compose38(Float64List.fromList(List.filled(1000, 0.01))).length,
        38);
    expect(
        feats
            .compose38(Float64List.fromList(List.filled(80000, 0.01)))
            .length,
        38);
  });
}
