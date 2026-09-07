# Day 319 — the scream detector does not detect real screams

`scream_classifier_v1.tflite` is the flagship detector of a personal-safety
app and was sitting at UNVERIFIED. Day 317's gate only asked "does the output
vary?", which this model passes easily — its scores span 0.000 to 0.996. It
looked fine. It is not fine.

## What was measured

Contract read from the model's real training script
(`zapsafe_backend/m1_train_v2.py`): `SR=22050, DURATION=3, N_MELS=128,
N_FFT=2048, HOP=512`, `power_to_db(ref=max)` then per-clip min-max, `H x W x 1`.
That matches `ScreamDetectorV2`'s Dart constants exactly, so the preprocessing
here is the app's own, not an approximation.

Positives and negatives use the training script's **own** label scheme
(`AUDIOSET_POS_IDS` / `AUDIOSET_NEG_IDS`, RAVDESS emotion codes).

| positive source | n | mean score | median | fires at 0.5 |
|---|---|---|---|---|
| **real AudioSet scream / yell / shout** | 90 | 0.058 | **0.000** | **5.6%** |
| real AudioSet cry / whimper / wail | 90 | 0.092 | 0.000 | 7.8% |
| RAVDESS fear / disgust / surprise | 90 | 0.320 | 0.062 | 31.1% |
| RAVDESS neutral / happy — a **negative** | 90 | 0.099 | 0.000 | 7.8% |
| real AudioSet speech / laughter / cheering | 90 | 0.005 | 0.000 | 0.0% |
| ESC-50 ambient | 90 | 0.000 | 0.000 | 0.0% |

**Real screams vs clean negatives: AUC 0.6208, recall 5.6% at the shipped
0.5 threshold.**

## What that means

1. **It misses ~94% of real screams** at the threshold it ships with.
2. **It fires on RAVDESS *neutral* speech (7.8%) as often as on real screams
   (5.6%).** Whatever it learned, "screaming" is not it.
3. It scores acted studio emotion ~6x higher than real screaming (31.1% vs
   5.6%), which is the whole story: RAVDESS/CREMA-D acted speech dominates
   its training set, so it learned that distribution and not the target.
4. **The model card's 0.9424 precision / 0.9529 recall are in-domain
   memorisation**, measured on a held-out split of that same acted-speech
   distribution. They do not survive contact with real audio. Those numbers
   were quoted verbatim in `scream_detector_v2.dart`; that comment has been
   corrected rather than left to mislead the next reader.
5. **This is not a threshold problem.** At 0.02 only 13.3% of real screams
   fire. Recalibration cannot rescue it; it needs retraining on real
   screaming audio.

`m1_gender_balanced.tflite` (shipped, unwired) is worse on the same fixture:
**AUC 0.494 — chance — with output range [0.000, 0.012]**, so it never fires
on anything at any sane threshold.

## The gate gap this exposed, and the fix

Day 317's gate would have passed this model as `ok`. Liveness is necessary
but nowhere near sufficient: **an alive-but-useless detector is more dangerous
than a dead one, because it looks like it works.** A dead model is caught the
first time someone tests it; this one returns plausible, varying, confident
numbers forever.

`tools/verify_shipped_models.py` now:

- carries **labelled** real fixtures where the data allows, and measures
  **discrimination (AUC)**, not just output variance;
- reports `WEAK` below `WEAK_AUC = 0.70` and **fails the run**, so a weak
  safety detector blocks the same way a dead one does;
- deliberately **excludes RAVDESS from the scream positive set**, because it
  is this model's own training distribution and including it inflates the
  measured AUC from 0.62 to 0.77 — the exact error that let the model card's
  numbers look credible in the first place.

Current gate output for the scream family:

```
m1_gender_balanced.tflite    WEAK  n=135 AUC=0.494 rec@0.5=0.000 range[0.000, 0.012]
scream_classifier_v1.tflite  WEAK  n=135 AUC=0.616 rec@0.5=0.067 range[0.000, 0.891]
```

## What this does NOT do

No retrain, and no threshold change. Lowering the threshold to buy recall
would trade a detector that misses screams for one that fires on everything —
at 0.02 it is still only catching 13.3% of real screams while its false-positive
rate climbs. The honest position is that this model is not fit for the job and
the app should not present it as a working scream detector until it is
retrained on real screaming audio.

Real screaming data available locally today is thin: 44 usable AudioSet
`/m/03qc9zr` clips with wavs on disk. `E:\zapsafe\` (the ~200GB pulled in
September) has no scream corpus either. **Sourcing real scream audio is the
blocker for fixing this**, not GPU time or training code.
