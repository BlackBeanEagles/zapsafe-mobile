import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;

/// Day 258 — sample-rate conversion for the m1 mel pipeline.
///
/// `AudioCaptureService` asks Android for 22,050 Hz and usually gets it, but
/// [AudioRecord] is free to refuse; the fallback is 44,100 Hz. m1_scream_v2
/// was trained on 22,050 Hz librosa features and `MelSpectrogram` does not
/// resample, so a device that lands on the fallback needs the conversion
/// done here.
///
/// This is a deliberate port of **`scipy.signal.resample_poly`** rather than
/// a hand-rolled decimator, for one reason: it can be tested. Naive
/// decimation (take every other sample) aliases everything above 5,512 Hz
/// back down into the speech band, which for a scream — energy concentrated
/// high — corrupts exactly the part of the spectrum the model keys on. The
/// result still has the right length, the right range, and looks like audio.
/// Only elementwise comparison against scipy catches it.
///
/// Parity fixture: `test/fixtures/resample_golden.json`.
class AudioResampler {
  /// Kaiser beta scipy uses for `resample_poly`'s default window.
  static const double _kaiserBeta = 5.0;

  /// scipy uses `half_len = 10 * max(up, down)`, giving `2*half_len + 1` taps.
  static const int _halfLenPerRate = 10;

  /// Converts int16 little-endian PCM (as it arrives from the platform
  /// channel) to doubles in `[-1, 1)`.
  ///
  /// Divisor is 32768, not 32767: int16 is asymmetric (`[-32768, 32767]`) and
  /// librosa/soundfile both scale by 32768, so this matches how the training
  /// audio was read.
  static Float64List pcm16ToDouble(Uint8List bytes) {
    final n = bytes.length ~/ 2;
    final view = ByteData.sublistView(bytes);
    final out = Float64List(n);
    for (var i = 0; i < n; i++) {
      out[i] = view.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return out;
  }

  /// Resamples [x] from [fromRate] to [toRate].
  ///
  /// Returns [x] unchanged when the rates already match — the common case on
  /// devices that honour the 22,050 Hz request, and worth not paying for.
  static Float64List resample(Float64List x, int fromRate, int toRate) {
    if (fromRate == toRate || x.isEmpty) return x;
    final g = _gcd(fromRate, toRate);
    return resamplePoly(x, toRate ~/ g, fromRate ~/ g);
  }

  /// Port of `scipy.signal.resample_poly(x, up, down)` with the default
  /// `window=('kaiser', 5.0)`.
  ///
  /// The filter-padding dance below looks arbitrary; it is scipy's, and it
  /// exists so the output samples land centred rather than delayed by half
  /// the filter length. Deviating from it shifts the whole signal by a few
  /// samples — which changes every STFT frame downstream.
  static Float64List resamplePoly(Float64List x, int up, int down) {
    if (up == down) return x;

    final maxRate = math.max(up, down);
    final halfLenTaps = _halfLenPerRate * maxRate;
    final h = _firwinKaiser(2 * halfLenTaps + 1, 1.0 / maxRate, _kaiserBeta);
    // scipy scales the filter by `up` to preserve amplitude through the
    // zero-stuffing.
    for (var i = 0; i < h.length; i++) {
      h[i] *= up;
    }

    var nOut = x.length * up;
    nOut = nOut ~/ down + (nOut % down != 0 ? 1 : 0);

    final halfLen = h.length ~/ 2;
    final nPrePad = down - (halfLen % down);
    var nPostPad = 0;
    final nPreRemove = (halfLen + nPrePad) ~/ down;
    while (_outputLen(h.length + nPrePad + nPostPad, x.length, up, down) <
        nOut + nPreRemove) {
      nPostPad++;
    }

    final hPadded = Float64List(nPrePad + h.length + nPostPad);
    hPadded.setRange(nPrePad, nPrePad + h.length, h);

    final y = _upfirdn(hPadded, x, up, down);

    final out = Float64List(nOut);
    for (var i = 0; i < nOut; i++) {
      final src = nPreRemove + i;
      out[i] = src < y.length ? y[src] : 0.0;
    }
    return out;
  }

  /// `scipy.signal._upfirdn._output_len`.
  static int _outputLen(int lenH, int inLen, int up, int down) =>
      (((inLen - 1) * up + lenH) - 1) ~/ down + 1;

  /// `scipy.signal.upfirdn` — convolve [x] zero-stuffed by [up] with [h],
  /// then keep every [down]-th sample.
  static Float64List _upfirdn(Float64List h, Float64List x, int up, int down) {
    final yLen = _outputLen(h.length, x.length, up, down);
    final out = Float64List(yLen);
    for (var i = 0; i < yLen; i++) {
      final m = i * down;
      var acc = 0.0;
      // Only taps landing on a real (non-stuffed) sample contribute, so step
      // through those directly instead of testing every tap.
      final kStart = m % up;
      for (var k = kStart; k < h.length; k += up) {
        final j = m - k;
        if (j < 0) break;
        final xi = j ~/ up;
        if (xi < x.length) acc += h[k] * x[xi];
      }
      out[i] = acc;
    }
    return out;
  }

  /// `scipy.signal.firwin(numtaps, cutoff, window=('kaiser', beta))` for the
  /// single-band lowpass case, with scipy's `scale=True` DC normalisation.
  static Float64List _firwinKaiser(int numtaps, double cutoff, double beta) {
    final alpha = (numtaps - 1) / 2.0;
    final h = Float64List(numtaps);
    final win = _kaiser(numtaps, beta);
    for (var i = 0; i < numtaps; i++) {
      final m = i - alpha;
      h[i] = cutoff * _sinc(cutoff * m) * win[i];
    }
    // scale=True with pass_zero: normalise so the DC gain is exactly 1.
    var sum = 0.0;
    for (final v in h) {
      sum += v;
    }
    if (sum != 0) {
      for (var i = 0; i < numtaps; i++) {
        h[i] /= sum;
      }
    }
    return h;
  }

  /// `np.sinc` — the *normalised* sinc, `sin(pi x) / (pi x)`.
  static double _sinc(double x) {
    if (x == 0.0) return 1.0;
    final px = math.pi * x;
    return math.sin(px) / px;
  }

  /// `np.kaiser(m, beta)` — symmetric.
  static Float64List _kaiser(int m, double beta) {
    final w = Float64List(m);
    if (m == 1) {
      w[0] = 1.0;
      return w;
    }
    final denom = (m - 1) / 2.0;
    final i0Beta = _besselI0(beta);
    for (var n = 0; n < m; n++) {
      final r = (n - denom) / denom;
      final arg = 1.0 - r * r;
      w[n] = _besselI0(beta * math.sqrt(arg < 0 ? 0 : arg)) / i0Beta;
    }
    return w;
  }

  /// Modified Bessel function of the first kind, order 0, by its power
  /// series. Converges quickly for the arguments Kaiser needs (`<= beta`).
  static double _besselI0(double x) {
    final halfSq = (x / 2.0) * (x / 2.0);
    var term = 1.0;
    var sum = 1.0;
    for (var k = 1; k < 60; k++) {
      term *= halfSq / (k * k);
      sum += term;
      if (term < 1e-18 * sum) break;
    }
    return sum;
  }

  /// Test-only view of the filter design, so a tap-for-tap comparison
  /// against `scipy.signal.firwin` is possible without resampling anything.
  @visibleForTesting
  static Float64List debugFirwin(int numtaps, double cutoff, double beta) =>
      _firwinKaiser(numtaps, cutoff, beta);

  static int _gcd(int a, int b) {
    while (b != 0) {
      final t = b;
      b = a % b;
      a = t;
    }
    return a;
  }
}
