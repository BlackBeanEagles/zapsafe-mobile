import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'mel_spectrogram.dart';
import 'vocal_stress_features.dart';
import 'yin_pitch.dart';

/// Day 352 — the 38-dim prosodic vector `h_aggressive_v6_38` was trained on.
///
/// ## Why this is a separate class from [VocalStressFeatures]
///
/// Both build a 38-float vector in the same slot order. They are **not**
/// interchangeable, because they analyse at different window sizes:
///
/// | | m4 / m5 ([VocalStressFeatures]) | h_aggressive v4 (this) |
/// |---|---|---|
/// | frame / n_fft | 512 | **2048** |
/// | hop | 256 | **512** |
/// | pitch | plain YIN | plain YIN |
/// | slot order | identical | identical |
///
/// Feeding one model the other's vector yields the right shape, plausible
/// values and a wrong answer — the failure this project has hit repeatedly
/// (`i_vehicle_crash` 0.5000 on unit-mismatched input;
/// `m4_vocal_stress_en_38` reporting DEAD at a constant 1.0 on the
/// `librosa.pyin` fixture). So the two paths are kept apart rather than
/// parameterised into one, and [YinPitch] takes the window as an argument
/// with m4/m5's values as the defaults.
///
/// ## Why 2048/512, measured rather than assumed
///
/// `h_aggressive` was trained by a Python extractor using `librosa.pyin` at
/// librosa's default framing. Day 351 retrained it in m4/m5's 512/256 space
/// so this class would not be needed, and it lost too much:
///
///     v2b  librosa.pyin  2048/512   acted 0.8096   natural 0.6661
///     v3   plain YIN      512/256   acted 0.7063   natural 0.5918
///     v4   plain YIN     2048/512   acted 0.7464   natural 0.6423
///
/// Moving only the window recovers **68% of the natural-speech gap**, which
/// is why v4 exists and why Day 351's "the native work is unavoidable" was
/// too strong. The residual 0.024 is the pyin HMM, independently measured at
/// 0.011 on m4 — not worth a Viterbi port for a detector at this stage.
/// See `assets/models/DAY352_H_AGGRESSIVE_V4_WIRED.md`.
///
/// ## Slot order (identical to [VocalStressFeatures.compose38])
///
/// | index | feature |
/// |---|---|
/// | `0..4` | voiced_frac, f0_mean, f0_std, f0_range, jitter |
/// | `5` | shimmer |
/// | `6` | hnr |
/// | `7..19` | mfcc_mean[0..12] |
/// | `20..32` | mfcc_std[0..12] |
/// | `33..35` | rms_mean, rms_std, rms_max |
/// | `36` | zero-crossing rate |
/// | `37` | spectral centroid / nyquist |
class AggressiveSpeechFeatures {
  static const int kSampleRate = 16000;

  /// 3.0 s at [kSampleRate]. Shorter is zero-padded, longer truncated —
  /// deterministically from the start, unlike the trainer's random crop,
  /// which is an augmentation rather than part of the input distribution.
  static const int kSamples = 48000;

  static const int kNMfcc = 13;

  /// **2048, not 512.** librosa's default, and the window v4 was trained on.
  static const int kNFft = 2048;

  /// **512, not 256.**
  static const int kHopLength = 512;

  static const int kNMels = 128;
  static const int kFeatureDim = 38;

  AggressiveSpeechFeatures({MelSpectrogram? mel})
      : _mel = mel ??
            MelSpectrogram(
              sampleRate: kSampleRate,
              nFft: kNFft,
              hopLength: kHopLength,
              nMels: kNMels,
              // librosa's melspectrogram default is fmax = sr/2.
              fmax: kSampleRate / 2,
            );

  final MelSpectrogram _mel;

  /// Raw mono PCM at [kSampleRate] -> the model's 38 floats, physical
  /// (un-standardised) values. The caller applies
  /// `assets/models/h_aggressive_v6_38_norm.json`; skipping that does not
  /// throw and does not change the shape, it just makes the model wrong —
  /// Day 318 measured exactly that at 0.844 -> 0.52.
  Float64List compose38(Float64List pcm) {
    final clip = fit(pcm);
    final out = Float64List(kFeatureDim);

    // [0..4] pitch, at THIS class's window, not YinPitch's defaults.
    final pitch = YinPitch.pitchFeatures(
      clip,
      frameLength: kNFft,
      hopLength: kHopLength,
    );
    for (var i = 0; i < 5; i++) {
      out[i] = pitch[i];
    }

    final rms = _rmsFrames(clip);
    out[5] = _meanAbsDiff(rms);           // shimmer
    out[6] = _harmonicsToNoise(clip);     // hnr

    final m = _mel.mfcc(clip, nMfcc: kNMfcc); // [13][frames]
    for (var k = 0; k < kNMfcc; k++) {
      final row = m[k];
      if (row.isEmpty) continue;
      var sum = 0.0;
      for (final v in row) {
        sum += v;
      }
      final mean = sum / row.length;
      var sq = 0.0;
      for (final v in row) {
        final d = v - mean;
        sq += d * d;
      }
      out[7 + k] = mean;
      // Population std (ddof=0) — numpy's default.
      out[20 + k] = math.sqrt(sq / row.length);
    }

    var sum = 0.0, max = 0.0;
    for (final v in rms) {
      sum += v;
      if (v > max) max = v;
    }
    final mean = rms.isEmpty ? 0.0 : sum / rms.length;
    var sq = 0.0;
    for (final v in rms) {
      final d = v - mean;
      sq += d * d;
    }
    out[33] = mean;
    out[34] = rms.isEmpty ? 0.0 : math.sqrt(sq / rms.length);
    out[35] = max;

    out[36] = _zeroCrossingRate(clip);
    out[37] = _spectralCentroidOverNyquist(clip);
    return out;
  }

  /// Pad with zeros or truncate to exactly [kSamples].
  @visibleForTesting
  static Float64List fit(Float64List pcm) {
    if (pcm.length == kSamples) return pcm;
    final out = Float64List(kSamples);
    final n = pcm.length < kSamples ? pcm.length : kSamples;
    out.setRange(0, n, pcm.length < kSamples ? pcm : pcm.sublist(0, kSamples));
    return out;
  }

  /// `librosa.feature.rms(y, frame_length: 2048, hop_length: 512)`.
  ///
  /// librosa centre-pads by `frame_length ~/ 2`, so frame `i` is centred on
  /// sample `i * hop`. Getting the padding wrong shifts every frame and
  /// changes shimmer, which is why this mirrors it explicitly.
  Float64List _rmsFrames(Float64List y) {
    const half = kNFft ~/ 2;
    final padded = Float64List(y.length + 2 * half);
    padded.setRange(half, half + y.length, y);
    final frames = 1 + (y.length ~/ kHopLength);
    final out = Float64List(frames);
    for (var f = 0; f < frames; f++) {
      final start = f * kHopLength;
      if (start + kNFft > padded.length) break;
      var sq = 0.0;
      for (var i = 0; i < kNFft; i++) {
        final v = padded[start + i];
        sq += v * v;
      }
      out[f] = math.sqrt(sq / kNFft);
    }
    return out;
  }

  static double _meanAbsDiff(Float64List v) {
    if (v.length < 2) return 0.0;
    var sum = 0.0;
    for (var i = 1; i < v.length; i++) {
      sum += (v[i] - v[i - 1]).abs();
    }
    return sum / (v.length - 1);
  }

  /// Autocorrelation peak within a 20 ms lag, normalised by lag-0 energy and
  /// clipped to `[0, 1]` — the trainer's `np.correlate(y, y, 'full')` form.
  double _harmonicsToNoise(Float64List y) {
    if (y.isEmpty) return 0.0;
    var zero = 0.0;
    for (final v in y) {
      zero += v * v;
    }
    if (zero <= 0) return 0.0;
    final maxLag = math.min(y.length - 1, (kSampleRate * 0.02).floor());
    var best = 0.0;
    for (var lag = 1; lag <= maxLag; lag++) {
      var acc = 0.0;
      for (var i = 0; i + lag < y.length; i++) {
        acc += y[i] * y[i + lag];
      }
      if (acc > best) best = acc;
    }
    final r = best / (zero + 1e-8);
    return r.clamp(0.0, 1.0);
  }

  double _zeroCrossingRate(Float64List y) {
    const half = kNFft ~/ 2;
    final padded = Float64List(y.length + 2 * half);
    padded.setRange(half, half + y.length, y);
    final frames = 1 + (y.length ~/ kHopLength);
    var total = 0.0;
    var counted = 0;
    for (var f = 0; f < frames; f++) {
      final start = f * kHopLength;
      if (start + kNFft > padded.length) break;
      var crossings = 0;
      for (var i = 1; i < kNFft; i++) {
        final a = padded[start + i - 1];
        final b = padded[start + i];
        if ((a >= 0) != (b >= 0)) crossings++;
      }
      total += crossings / kNFft;
      counted++;
    }
    return counted == 0 ? 0.0 : total / counted;
  }

  /// Mirrors [VocalStressFeatures]'s centroid exactly, at this class's
  /// n_fft. The bin->frequency map depends on n_fft, so reusing the 512
  /// version here would mislabel every bin.
  double _spectralCentroidOverNyquist(Float64List y) {
    final power = _mel.stftPowerForCentroid(y); // [frames][bins]
    if (power.isEmpty) return 0.0;
    final bins = power[0].length;
    final freqs = Float64List(bins);
    for (var k = 0; k < bins; k++) {
      freqs[k] = k * kSampleRate / kNFft;
    }
    var sum = 0.0;
    var frames = 0;
    for (final spec in power) {
      var num = 0.0, den = 0.0;
      for (var k = 0; k < bins; k++) {
        final mag = math.sqrt(spec[k]); // power -> magnitude
        num += freqs[k] * mag;
        den += mag;
      }
      sum += den == 0.0 ? 0.0 : num / den;
      frames++;
    }
    final mean = frames == 0 ? 0.0 : sum / frames;
    return mean / (kSampleRate / 2);
  }
}
