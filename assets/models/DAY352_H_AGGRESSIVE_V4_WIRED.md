# Day 352 — h_aggressive Phase B is done, and Day 351's conclusion was wrong

Phase B sat open from Day 90 to Day 352. The last five days of it were
blocked by an estimate I got wrong, so the correction matters as much as the
wiring.

## 1. What shipped

```
v1   librosa.pyin 2048/512, RAVDESS only   acted 0.8442   natural 0.4780
v2b  librosa.pyin 2048/512, 5 corpora      acted 0.8096   natural 0.6661
v3   plain YIN     512/256, 5 corpora      acted 0.7063   natural 0.5918
v4   plain YIN    2048/512, 5 corpora      acted 0.7611   natural 0.6415
                                           natural CI [0.6171, 0.6656]
```

`h_aggressive_v4_38.tflite` (11.9 KB) + `_norm.json`, wired through
`AggressiveSpeechDetector` and `aggressiveSpeechDetectorProvider`. Trained
on CREMA-D + TESS + RAVDESS + SAVEE + MELD — 17,548 clips, speaker-disjoint
per corpus, corpus-balanced sample weights. ESD-free.

v1's asset and norm are **deleted**: unreferenced once the registry moved,
and 24 KB of dead weight otherwise.

## 2. The correction

Day 351 wrote: *"the native work is confirmed unavoidable, not assumed."*
That was too strong, and its own write-up contained the reason — v3 changed
**two variables at once**, the pitch algorithm *and* the analysis window,
and the conclusion was drawn as if only the algorithm had moved.

The archive already held the counter-evidence: m4's report records plain
YIN vs `librosa.pyin` at **0.8336 vs 0.8445 — the HMM is worth 0.011**. A
0.10 drop cannot come from a 0.011 component. I had measured that months
earlier and still reached for the wrong explanation.

Holding the algorithm fixed and moving only the window:

```
frame size recovers 53% of the acted gap, 67% of the natural gap
```

So **most of what was attributed to pyin was the window.** Phase B was a
parameter, not a port.

## 3. What Phase B actually required

Not a pyin implementation. Three things:

**`YinPitch` parameterised, not mutated.** `kFrameLength`/`kHopLength` are
now defaults with optional overrides. Changing the constants would have been
the obvious move and would have **silently corrupted m4 and m5**, which are
trained at 512/256 — the right-shape-wrong-answer failure this project keeps
hitting. `test/day333_yin_pitch_test.dart` still passes unchanged, which is
what proves m4/m5's path is untouched.

**`AggressiveSpeechFeatures`, a separate class.** It analyses at 2048/512 —
pitch, MFCC, RMS, ZCR and spectral centroid all move with the window, not
just pitch. Kept apart from `VocalStressFeatures` rather than parameterised
into it, so the two can never be confused at a call site.

**A golden fixture from the trainer itself.** `make_golden.py` generates it
with the *same* `features38()` that produced v4's training data, so a
mismatch is a Dart bug rather than a disagreement about the spec.
`test/day352_aggressive_speech_features_test.dart` pins all 38 slots across
four signals and asserts the two 38-vectors differ in **more than 20 of 38
slots** — if they ever stop differing, one model is being fed the other's
features.

## 4. Two things not to over-read

**The acted number straddles its own bar.** Two runs of the same seeded
script gave acted 0.7464 and 0.7611 against a 0.75 bar. Run-to-run variance
on this head is ~0.02, the same order as the margin. The exported artifact
is the 0.7611 one; the figure is not precise to two decimals and should not
be quoted as if it were.

**The gate reports v4 as UNVERIFIED, deliberately.** Neither existing `[1,38]`
fixture matches it — `real_prosodic_38_yin` is 512/256 and
`real_prosodic_38` is `librosa.pyin`. Handing it either would produce a
confident wrong number, which is exactly how m4 once read DEAD at a constant
1.0. Building a correct fixture needs ESD re-featurised at 2048/512, and ESD
is the corpus Day 350 flagged as Non-Commercial. UNVERIFIED is the honest
state; the Dart feature path is covered by the parity test instead.

## 5. Licence position

v4's corpora are ESD-free, but not clean: TESS is CC BY-NC 4.0, RAVDESS
CC BY-NC-SA 4.0, SAVEE research-use, MELD research-use and derived from
copyrighted broadcast. CREMA-D is ODbL. The gate now records this and flags
the model NC. See `DAY350_TRAINING_DATA_LICENCES.md`.

## 6. Status

| | |
|---|---|
| asset | `h_aggressive_v4_38.tflite`, 11.9 KB, **wired** |
| natural speech | **0.6415** (v1: 0.4780, chance) |
| acted, held-out speakers | 0.7611 (±~0.02 run variance) |
| threshold | 0.45 — fusion contributor, not an alert trigger |
| gate | UNVERIFIED by design; feature path covered by parity test |

859 tests pass; analyze unchanged at 57.

Reproduce: `work/h_aggressive_v4/{featurise_yin2048,train_v4,make_golden}.py`.

**This has not run on physical hardware.** `flutter test` cannot execute a
`.tflite`, so what is verified here is that Dart builds the right features —
not that the model behaves on a phone.
