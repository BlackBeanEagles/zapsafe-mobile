import 'dart:math' as math;
import 'dart:typed_data';

/// Plain YIN pitch tracking — Cheveigné & Kawahara (2002), steps 1–5.
///
/// ## Why this and not `librosa.pyin`
///
/// The five pitch features (`voiced_frac`, `f0_mean`, `f0_std`, `f0_range`,
/// `jitter`) are worth **+0.110 AUC** in English vocal stress. Getting them
/// on-device originally meant reproducing `librosa.pyin`, which adds
/// beta-distributed multi-threshold candidate generation and a **Viterbi
/// pass over an HMM** of pitch states on top of the algorithm below. Every
/// one of those stages is a place for a silent parity bug.
///
/// The reframing that removed the HMM: the model does not need Dart to match
/// *librosa*. It needs Dart to match **whatever it was trained on**. So the
/// model is retrained on plain YIN, and this file only has to match
/// `work/yin_lite/yin_lite.py`.
///
/// That trade was measured before it was taken, on held-out speakers:
///
/// | feature set | English AUC |
/// |---|---|
/// | 28 — what the app computed before | 0.6949 |
/// | 33 — + shimmer/hnr/rms | 0.7469 |
/// | 38 — `librosa.pyin` pitch | 0.8445 |
/// | 38 — **this tracker** | **0.8336** |
///
/// The entire HMM is worth **0.011 AUC**. See
/// `assets/models/DAY333_YIN_WITHOUT_THE_HMM.md`.
///
/// ## Implementation note
///
/// [_cumulativeMeanNormalisedDifference] is the *literal* difference
/// function, not the FFT-accelerated form the Python side uses. That is
/// deliberate: `yin_lite.selftest()` asserts the FFT path reproduces the
/// literal definition to 1e-15, so the literal form is the shared reference
/// and Dart avoids needing an FFT at all. (The FFT version was wrong on its
/// first attempt — cross-correlation read upward from a convolution result
/// that runs downward — and the selftest is what caught it.)
///
/// Cost is ~246 lags × 256 samples × 188 frames ≈ 11.8 M multiply-adds per
/// 3 s window, which is acceptable for a window-rate detector and buys a
/// direct, auditable correspondence with the training code.
class YinPitch {
  static const int kSampleRate = 16000;
  static const int kFrameLength = 512;
  static const int kHopLength = 256;

  /// `librosa.note_to_hz("C2")` / `("C7")` — the day95 extractor's range.
  static const double kFMin = 65.40639132514966;
  static const double kFMax = 2093.004522404789;

  /// YIN's absolute threshold on the normalised difference.
  static const double kThreshold = 0.1;

  static int get _tauMin {
    final t = (kSampleRate / kFMax).floor();
    return t < 1 ? 1 : t;
  }

  static int get _tauMax {
    final t = (kSampleRate / kFMin).ceil() + 1;
    const half = kFrameLength ~/ 2;
    return t < half ? t : half;
  }

  /// Per-frame f0 in Hz, with [double.nan] where no pitch was accepted, and
  /// a parallel voiced flag.
  ///
  /// Framing matches librosa's `center=true`, `pad_mode='constant'`: the
  /// signal is zero-padded by `frameLength ~/ 2` each side, giving
  /// `1 + samples ~/ hop` frames.
  static ({Float64List f0, List<bool> voiced}) track(Float64List y) {
    const half = kFrameLength ~/ 2;
    final padded = Float64List(y.length + 2 * half);
    padded.setRange(half, half + y.length, y);

    final tauMin = _tauMin;
    final tauMax = _tauMax;
    final nFrames = 1 + (y.length ~/ kHopLength);
    final f0 = Float64List(nFrames);
    final voiced = List<bool>.filled(nFrames, false);
    final frame = Float64List(kFrameLength);

    for (var i = 0; i < nFrames; i++) {
      f0[i] = double.nan;
      final start = i * kHopLength;
      if (start + kFrameLength > padded.length) continue;
      frame.setRange(0, kFrameLength, padded, start);

      final dp = _cumulativeMeanNormalisedDifference(frame, tauMax);

      // Step 4: first local minimum below the absolute threshold; if none
      // clears it, fall back to the global minimum of the search range and
      // mark the frame unvoiced.
      var tau = -1;
      var isVoiced = false;
      for (var t = tauMin; t < tauMax; t++) {
        if (dp[t] < kThreshold) {
          while (t + 1 < tauMax && dp[t + 1] < dp[t]) {
            t++;
          }
          tau = t;
          isVoiced = true;
          break;
        }
      }
      if (tau < 0) {
        var best = tauMin;
        for (var t = tauMin + 1; t < tauMax; t++) {
          if (dp[t] < dp[best]) best = t;
        }
        tau = best;
      }

      // Step 5: parabolic interpolation about the chosen dip.
      var shift = 0.0;
      if (tau > 0 && tau < tauMax - 1) {
        final a = dp[tau - 1], b = dp[tau], c = dp[tau + 1];
        final den = a - 2.0 * b + c;
        if (den.abs() > 1e-12) {
          shift = 0.5 * (a - c) / den;
          if (shift < -1.0) shift = -1.0;
          if (shift > 1.0) shift = 1.0;
        }
      }

      final period = tau + shift;
      if (period > 0) {
        final hz = kSampleRate / period;
        if (hz >= kFMin && hz <= kFMax) {
          f0[i] = hz;
          voiced[i] = isVoiced;
        }
      }
    }
    return (f0: f0, voiced: voiced);
  }

  /// `d'(tau)`, YIN steps 1–3.
  ///
  /// `d(tau) = sum_j (x[j] - x[j+tau])^2` over the first half of the frame,
  /// then divided by the running mean of `d(1..tau)`. `d'(0)` is 1 by
  /// definition, and a zero denominator (a silent frame) also yields 1, which
  /// keeps it above [kThreshold] so silence reads unvoiced rather than
  /// dividing by zero.
  static Float64List _cumulativeMeanNormalisedDifference(
    Float64List frame,
    int tauMax,
  ) {
    const w = kFrameLength ~/ 2;
    final d = Float64List(tauMax);
    for (var tau = 1; tau < tauMax; tau++) {
      var sum = 0.0;
      for (var j = 0; j < w; j++) {
        final diff = frame[j] - frame[j + tau];
        sum += diff * diff;
      }
      d[tau] = sum;
    }
    final dp = Float64List(tauMax);
    dp[0] = 1.0;
    var running = 0.0;
    for (var tau = 1; tau < tauMax; tau++) {
      running += d[tau];
      final denom = running / tau;
      dp[tau] = denom > 0 ? d[tau] / denom : 1.0;
    }
    return dp;
  }

  /// The five pitch features at indices `[0..4]` of the day95 38-vector:
  /// `[voiced_frac, f0_mean, f0_std, f0_range, jitter]`.
  ///
  /// `jitter` is the mean absolute difference of successive **periods**
  /// (`1/f0`), not of frequencies — a distinction worth ~4 orders of
  /// magnitude in the value. Everything zeroes when fewer than two voiced
  /// frames survive, matching the extractor.
  static Float64List pitchFeatures(Float64List y) {
    final t = track(y);
    final out = Float64List(5);
    if (t.voiced.isEmpty) return out;

    var nVoiced = 0;
    final vals = <double>[];
    for (var i = 0; i < t.voiced.length; i++) {
      if (t.voiced[i]) {
        nVoiced++;
        if (!t.f0[i].isNaN) vals.add(t.f0[i]);
      }
    }
    out[0] = nVoiced / t.voiced.length;
    if (vals.length <= 1) return out;

    var sum = 0.0, min = vals[0], max = vals[0];
    for (final v in vals) {
      sum += v;
      if (v < min) min = v;
      if (v > max) max = v;
    }
    final mean = sum / vals.length;
    var sq = 0.0;
    for (final v in vals) {
      final dv = v - mean;
      sq += dv * dv;
    }
    var jit = 0.0;
    for (var i = 1; i < vals.length; i++) {
      jit += (1.0 / (vals[i] + 1e-8) - 1.0 / (vals[i - 1] + 1e-8)).abs();
    }
    out[1] = mean;
    out[2] = math.sqrt(sq / vals.length);
    out[3] = max - min;
    out[4] = jit / (vals.length - 1);
    return out;
  }
}
