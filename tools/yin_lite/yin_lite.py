"""YIN without the HMM — a pitch tracker simple enough to port to Dart safely.

WHY NOT librosa.pyin
====================
The five pitch features (`voiced_frac`, `f0_mean`, `f0_std`, `f0_range`,
`jitter`) are worth +0.110 AUC in English. Getting them in the app means
reproducing `librosa.pyin` in Dart, which is a difference function, cumulative
mean normalisation, *beta-distributed multi-threshold candidate generation*,
and a **Viterbi pass over an HMM** of pitch states. Every one of those is a
place for a silent parity bug of the exact kind this project keeps finding.

The reframing: the model does not need Dart to match *librosa*. It needs Dart
to match **whatever the model was trained on**. So implement plain YIN
(Cheveigné & Kawahara 2002, steps 1-5, no HMM), retrain on its output, and
Dart only has to match *this* file — 60 lines with no probabilistic machinery.

That is only worth doing if the simpler tracker keeps the AUC. This module
exists to measure that before any Dart is written.

PARAMETERS match the day95 extractor's pyin call: sr=16000, frame_length=512,
hop_length=256, fmin=C2=65.41 Hz, fmax=C7=2093.00 Hz.
"""
from __future__ import annotations

import numpy as np

SR = 16000
FRAME = 512
HOP = 256
FMIN = 65.40639132514966      # librosa.note_to_hz("C2")
FMAX = 2093.004522404789      # librosa.note_to_hz("C7")
THRESHOLD = 0.1               # YIN's absolute threshold


def _frames(y: np.ndarray) -> np.ndarray:
    """Centre-padded frames, matching librosa's center=True/pad_mode='constant'."""
    half = FRAME // 2
    padded = np.pad(y, (half, half), mode="constant")
    n = 1 + len(y) // HOP
    out = np.empty((n, FRAME), dtype=np.float64)
    for i in range(n):
        s = i * HOP
        out[i] = padded[s:s + FRAME]
    return out


def _cmnd(frame: np.ndarray, tau_max: int) -> np.ndarray:
    """Cumulative mean normalised difference function, YIN steps 1-3.

    d(tau) = sum_j (x[j] - x[j+tau])^2 over the usable window, then
    d'(tau) = d(tau) / ((1/tau) * sum_{k=1..tau} d(k)),  with d'(0) = 1.

    Expanded as d(tau) = P0 + Ptau - 2*corr(tau) so the whole tau sweep is one
    FFT instead of a loop. `_cmnd_naive` below is the literal definition, and
    `selftest()` asserts the two agree -- the fast path is an optimisation, and
    an unverified optimisation is how this class of bug gets in.
    """
    w = FRAME // 2
    x = frame[:w]
    f = frame[:tau_max + w]
    n = 1
    while n < len(f) + w:
        n <<= 1
    # corr(tau) = sum_j x[j] * f[j+tau] is a cross-correlation, so conjugate
    # the FIRST transform. (Multiplying without the conjugate gives a
    # convolution, whose result runs *downward* from index L-1 -- reading it
    # upward is what the first version of this did, and selftest() caught it
    # at 1.9e-01 instead of 1e-12.)
    corr = np.fft.irfft(np.conj(np.fft.rfft(x, n)) * np.fft.rfft(f, n), n)[:tau_max]

    sq = np.concatenate([[0.0], np.cumsum(frame.astype(np.float64) ** 2)])
    p0 = float(np.dot(x, x))
    taus = np.arange(tau_max)
    ptau = sq[taus + w] - sq[taus]

    d = p0 + ptau - 2.0 * corr
    d[0] = 0.0
    d = np.maximum(d, 0.0)

    cum = np.cumsum(d[1:])
    dp = np.ones(tau_max, dtype=np.float64)
    idx = np.arange(1, tau_max, dtype=np.float64)
    denom = cum / idx
    with np.errstate(divide="ignore", invalid="ignore"):
        dp[1:] = np.where(denom > 0, d[1:] / denom, 1.0)
    return dp


def _cmnd_naive(frame: np.ndarray, tau_max: int) -> np.ndarray:
    """The literal definition. Reference for selftest() only -- too slow to use."""
    w = FRAME // 2
    d = np.empty(tau_max, dtype=np.float64)
    d[0] = 0.0
    for tau in range(1, tau_max):
        diff = frame[:w] - frame[tau:tau + w]
        d[tau] = np.dot(diff, diff)
    cum = np.cumsum(d[1:])
    dp = np.ones(tau_max, dtype=np.float64)
    idx = np.arange(1, tau_max, dtype=np.float64)
    denom = cum / idx
    with np.errstate(divide="ignore", invalid="ignore"):
        dp[1:] = np.where(denom > 0, d[1:] / denom, 1.0)
    return dp


def selftest(n=12, seed=0):
    """Assert the FFT path reproduces the literal difference function."""
    rng = np.random.RandomState(seed)
    worst = 0.0
    for _ in range(n):
        fr = rng.randn(FRAME)
        a = _cmnd(fr, 246)
        b = _cmnd_naive(fr, 246)
        worst = max(worst, float(np.abs(a - b).max()))
    return worst


def track(y: np.ndarray):
    """-> (f0 array with NaN where unvoiced, voiced boolean array)."""
    tau_min = max(1, int(np.floor(SR / FMAX)))
    tau_max = min(FRAME // 2, int(np.ceil(SR / FMIN)) + 1)
    fr = _frames(np.asarray(y, dtype=np.float64))
    n = len(fr)
    f0 = np.full(n, np.nan, dtype=np.float64)
    voiced = np.zeros(n, dtype=bool)

    for i in range(n):
        dp = _cmnd(fr[i], tau_max)
        window = dp[tau_min:tau_max]
        if len(window) == 0:
            continue
        # YIN step 4: first local minimum below the absolute threshold,
        # else fall back to the global minimum of the search range.
        below = np.where(window < THRESHOLD)[0]
        if len(below):
            t = int(below[0])
            while t + 1 < len(window) and window[t + 1] < window[t]:
                t += 1
            tau = tau_min + t
            is_voiced = True
        else:
            tau = tau_min + int(np.argmin(window))
            is_voiced = False
        # YIN step 5: parabolic interpolation around the chosen dip.
        if 0 < tau < tau_max - 1:
            a, b, c = dp[tau - 1], dp[tau], dp[tau + 1]
            den = a - 2.0 * b + c
            shift = 0.5 * (a - c) / den if abs(den) > 1e-12 else 0.0
            shift = float(np.clip(shift, -1.0, 1.0))
        else:
            shift = 0.0
        period = tau + shift
        if period > 0:
            hz = SR / period
            if FMIN <= hz <= FMAX:
                f0[i] = hz
                voiced[i] = is_voiced
    return f0, voiced


def pitch_features(y: np.ndarray) -> np.ndarray:
    """The five 38-vector pitch features, indices [0..4], in order.

    Mirrors the day95 extractor exactly: it takes f0 where the voiced flag is
    set, drops NaN, and zeroes everything when fewer than 2 frames survive.
    `jitter` is the mean absolute difference of successive *periods*, not of
    frequencies.
    """
    f0, vf = track(y)
    voiced_frac = float(vf.mean()) if len(vf) else 0.0
    f0v = f0[vf]
    f0v = f0v[~np.isnan(f0v)]
    if len(f0v) > 1:
        f0_mean = float(f0v.mean())
        f0_std = float(f0v.std())
        f0_range = float(f0v.max() - f0v.min())
        per = 1.0 / (f0v + 1e-8)
        jitter = float(np.mean(np.abs(np.diff(per))))
    else:
        f0_mean = f0_std = f0_range = jitter = 0.0
    return np.array([voiced_frac, f0_mean, f0_std, f0_range, jitter],
                    dtype=np.float32)
