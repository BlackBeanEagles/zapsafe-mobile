# Day 333 — pitch on-device without reimplementing pyin's HMM

Day 332 costed the remaining vocal-stress gap at **+0.110 AUC**, reachable
only by reproducing `librosa.pyin` in Dart: a difference function, cumulative
mean normalisation, beta-distributed multi-threshold candidate generation,
and a **Viterbi pass over an HMM** of pitch states. Day 325 called that "a
large, high-risk job" and it is.

It turned out not to be necessary.

## The reframing

**The model does not need Dart to match librosa. It needs Dart to match
whatever the model was trained on.** So: implement plain YIN (Cheveigné &
Kawahara 2002, steps 1–5, no HMM), *retrain on its output*, and Dart only has
to match a 60-line module with no probabilistic machinery.

That is only worth doing if the simpler tracker keeps the AUC, so it was
measured before any Dart was written. Held-out speakers, 3 seeds each:

| feature set | English AUC |
|---|---|
| 28 — what the app computed before | 0.6949 ± 0.027 |
| 33 — + shimmer/hnr/rms (Day 332b) | 0.7469 ± 0.017 |
| 38 — `librosa.pyin` pitch | **0.8445** ± 0.014 |
| 38 — **plain YIN, this tracker** | **0.8336** ± 0.004 |

**The entire HMM is worth 0.011 AUC.** Plain YIN recovers the rest, and the
full step from what ships today is **0.6949 → 0.8336, +0.139**.

One oddity worth recording rather than hiding: `28 + yin_lite pitch` *without*
the cheap features scores **0.6191 ± 0.066** — worse than the 28 baseline and
with 4× the variance. The pitch features only help in combination with
shimmer/hnr/rms. That is not what a "features are additive" intuition
predicts, and it means the Day 332b work was a prerequisite for this, not an
independent win.

## Two bugs the process caught

**The FFT cross-correlation was wrong on the first attempt.** The Python side
accelerates the tau sweep with one FFT instead of a 246-iteration loop.
`selftest()` compares it against `_cmnd_naive`, the literal definition, and
reported **1.894e-01** instead of ~1e-12. Cause: `corr(tau) = Σ x[j]·f[j+tau]`
is a *cross-correlation*, so the first transform must be conjugated;
multiplying without the conjugate gives a *convolution*, whose result runs
**downward** from index `L-1` while the code read it upward. After
conjugating: **1.11e-15**.

This is the whole reason the naive reference exists. An optimisation nobody
checks is how this class of bug gets in, and the payoff is that **the Dart
side uses the literal form** — no FFT on device at all, and a direct
line-by-line correspondence with the training code.

**An alignment assumption that was false.** The first measurement recomputed
only features `[0..4]` and spliced them into the cached 38-vector, which
requires the re-collection to land in the cache's exact row order. It does
not — same 3,400 clips, different order — and the assertion caught it. Fixed
by making the measurement self-contained: compute all 38 fresh and carry `y`
and `spk` alongside, so no cross-file ordering assumption exists.

## What shipped

`lib/data/services/yin_pitch.dart` — `YinPitch.track()` and
`YinPitch.pitchFeatures()`, returning the five 38-vector features at indices
`[0..4]`. The Python reference is vendored at `tools/yin_lite/yin_lite.py` so
the contract lives beside the code that must honour it.

Parity fixtures extend `test/fixtures/m5_vocal_stress_golden.json` — the same
stored `samples` the mfcc and rms parity tests use, so the three cannot drift
apart. Ten tests, and the ones that matter are not the `closeTo` assertions:

* **per-frame** f0 and voiced flags for the first 8 frames, so a mismatch
  localises to the tracker rather than the aggregation
* white noise → **0.000** voiced; the fixture's tone → **0.995** voiced at
  **180.05 Hz**
* an independently synthesised 220 Hz sawtooth is tracked at 220 Hz, which
  guards against a golden generated from an already-broken reference
* silence returns unvoiced and finite rather than dividing by zero

### A tolerance note, because it looked like a failure twice

`pitch_features` returns `np.float32`, so **the golden is the rounded value
and Dart is the more precise one**. Two absolute tolerances failed on that
alone: `voiced_frac` off by 2.9e-8 (Dart gives exactly 187/188) and `f0_mean`
off by 5.3e-6 (float32 epsilon at 180 is ~1.5e-5). Neither was a disagreement
about what was computed. Tolerances are now **relative** at 1e-6, except
`jitter`, which stays tight and absolute at 1e-11 — it is the feature that
distinguishes "difference of periods" from "difference of frequencies", about
four orders of magnitude, and a loose bound there would pass on anything
returning roughly zero.

## Not done

**The 38-feature model is not retrained or shipped.** `VocalStressFeatures
.extract()` still returns 28 and `m5_vocal_stress_v2` still takes `[1,28]`.
Composing 28 + 5 (Day 332b) + 5 (here) into a 38-vector, retraining on
`yin_lite` pitch, and swapping the asset is now mechanical — every piece is
built and parity-checked — but it changes which language the shipped detector
targets (the measured gain is English; Mandarin sits at 0.52–0.59 on this
split), and that is a product decision rather than an engineering one.

813 tests pass, `flutter analyze` unchanged at 57 issues, 0 errors.
