# Day 351 — the cheap route to h_aggressive Phase B does not work

`h_aggressive_speech` has been blocked on "Phase B wiring" since Day 90,
estimated at days of native work. This tested whether that estimate could be
avoided. It cannot. The answer is negative and worth recording so nobody
tries it again.

## 1. The idea

Dart already ships a 38-dim prosodic vector — just not h_aggressive's:

```
h_aggressive   librosa.pyin   frame 2048 / hop 512   no Dart path
m4 / m5        yin_lite YIN   frame  512 / hop 256   yin_pitch.dart +
                                                     compose38(), shipping
```

So rather than build a second native feature path to match the model,
**retrain the model to match the path that already exists.** If it worked,
Phase B would collapse to a detector class and a provider — the shape
`GlassBreakDetector` took in one session.

## 2. It does not work

Same five corpora as v2b (CREMA-D, TESS, RAVDESS, SAVEE, MELD — 17,693
clips), same speaker-disjoint split, same corpus-balanced weights, only the
feature space changed:

```
v1   librosa, RAVDESS only    acted 0.8442   natural 0.4780
v2b  librosa, 5 corpora       acted 0.8096   natural 0.6661
v3   YIN_LITE, 5 corpora      acted 0.7063   natural 0.5918
                              delta -0.1033          -0.0743
```

v3 misses both bars (acted >= 0.75, natural >= 0.60 with CI clear of
chance). Per corpus, held-out speakers:

```
ravdess 0.8473   tess 0.7651   crema 0.7507   savee 0.6360   meld 0.5768
```

**Phase B genuinely requires the native work.** The original estimate stands.

## 3. A limitation of this experiment, stated plainly

The two feature definitions differ in **two** ways at once — the pitch
algorithm (librosa.pyin's HMM/Viterbi vs plain YIN) **and** the analysis
frame (2048/512 vs 512/256), which also changes the 26 MFCC statistics, not
just the 5 pitch features.

So this shows the yin_lite vector as a whole is insufficient for
h_aggressive. It does **not** isolate which change is responsible. A cleaner
follow-up would run plain YIN at 2048/512, separating tracker from frame
size. That was not run, because the practical question — "can Dart's
existing `compose38()` serve h_aggressive?" — is already answered.

The likely mechanism, untested: aggression is a pitch-dynamics signal
(f0 std and jitter), and a 32 ms frame gives noisier per-frame f0 than a
128 ms one, so the derived statistics degrade. That would also explain why
m4/m5 are fine on yin_lite — their target is stressed vs calm
(angry/sad vs neutral/happy), a different and apparently less
pitch-dynamic-dependent contrast.

## 4. What this leaves

`h_aggressive` v2b remains the best model (acted 0.8096, natural 0.6661,
against v1's 0.8442/0.4780) and remains **unshipped**, blocked on the same
native work as before:

* the native layer emits 15 per-frame scalars
* the model needs `librosa.pyin` f0 mean/std/jitter, RMS-derived shimmer
  and HNR, and spectral rolloff at frame 2048 / hop 512

Nothing about the model is wrong. The gap is a second feature pipeline in
Dart, and it is genuinely a pipeline, not a constant.

Reproduce: `work/h_aggressive_v3/{featurise_yin,train_v3}.py`.

## 5. Also worth knowing

The v3 corpora are ESD-free, as v2b's were — the Day 348 ablation dropped
ESD for being actively harmful, which incidentally removes the
`cc-by-nc-4.0` exposure Day 350 flagged. The remaining corpora are still not
licence-clean: RAVDESS is CC BY-NC-SA 4.0, TESS CC BY-NC, MELD
research-use and derived from copyrighted broadcast. See
`DAY350_TRAINING_DATA_LICENCES.md`.
