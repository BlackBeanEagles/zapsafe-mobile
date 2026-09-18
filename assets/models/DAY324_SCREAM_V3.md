# Day 324 — scream v3: a strictly better replacement, not a solved problem

`scream_classifier_v1.tflite` shipped as this app's flagship detector from
Day 31. Day 319 measured it against real audio and it fired on **5.6%** of
real AudioSet screams, while its model card claimed recall 0.9529. It fired
on RAVDESS *neutral* speech just as often as on real screaming.

Three versions later, on the same held-out protocol every time:

| version | real held-out AUC | recall @ its own threshold |
|---|---|---|
| v1 (Day 31, shipped until now) | 0.616 | 0.067 @ 0.50 |
| v2 (Day 322) | 0.759 | — no usable point |
| **v3 (this one)** | **0.823** | **0.667 @ 0.30** |

The gate scores the shipped artifact `AUC=0.839 rec@0.5=0.489` on its own
fixture sampling; the 0.823 above is the training run's held-out figure. Both
clear the 0.70 floor comfortably.

## What actually fixed it — the distribution, twice

**v1's failure was never architectural.** Its training set was dominated by
acted RAVDESS/CREMA-D **speech**, so it learned acted studio emotion. Its
0.9424/0.9529 card numbers were in-domain memorisation measured on a
held-out split of that same distribution — they never described real-world
behaviour and were never going to.

**v2 fixed half of it.** A scream is not speech, it is a *non-speech
vocalisation*. v2 trained on 1,991 real ASVP-ESD non-speech distress
vocalisations and deliberately demoted acted speech to a **negative**. AUC
went 0.616 → 0.759. But the operating curve stayed unusable: 91% recall cost
65% false alerts.

**v3 fixed the other half: hard negatives.** VocalAffectBench supplied 714
real screams *and* ~4,500 same-domain non-speech confusables — laughter,
cough, sneeze, sigh, sniff, throat-clearing, yawn. A cough and a scream are
both sharp non-speech vocalisations, and nothing before had ever taught the
model the difference. That is what moved precision:

    at equal recall (0.667):  v2 precision 0.386  ->  v3 precision 0.524

## Operating curve (held-out real AudioSet screams)

| threshold | recall | precision |
|---|---|---|
| 0.50 | 0.455 | 0.682 |
| 0.40 | 0.485 | 0.593 |
| **0.30 (shipped)** | **0.667** | **0.524** |
| 0.20 | 0.758 | 0.463 |
| 0.10 | 0.818 | 0.397 |

`kDefaultThreshold` is **0.30**, not 0.5. Missing a real scream is worse than
a false alert — up to the point where false alerts train the user to ignore
the app. Past 0.20 precision drops below half and it starts crying wolf.

At 0.30 v3 catches **0.667** where v1 caught **0.067** at its own threshold.

## What this is NOT

**Not a solved problem.** At the shipped threshold it misses one scream in
three, and roughly half of all alerts are false. This is a strictly better
replacement for something unshippable — not a detector to advertise.

**The binding constraint is now measurement, not training.** The held-out set
is **33 real screams**. Each clip moves recall by 3%, so 0.823 cannot be
distinguished from 0.78. More real scream audio is the single thing this
model needs next, for evaluation as much as for training.

## Also changed

- `scream_classifier_v1.tflite` retired to `reference_models/`. v3 is
  **205.8 KB vs 2,810.6 KB** — the model bundle drops 9.1 MB → 6.5 MB.
- Filename follows the repo's `_vN` convention, which
  `model_version_service.dart` parses, so the version string correctly
  resolves to `v3` instead of silently reporting `v1` for a different model.
- Input contract unchanged: `[1, 128, 131, 1]` float32, 22050 Hz, 3 s,
  128 mels, n_fft 2048, hop 512, `power_to_db(ref=max)` then per-clip
  min-max. `ScreamDetectorV2`'s preprocessing needed no change.
- float16 export, not int8 — Day 317 established that full int8 quantization
  clamps this family's final logit to a constant.

## Verify before trusting this doc

    python tools/verify_shipped_models.py

It runs the shipped artifact against real recorded audio and fails on both
dead (constant output) and WEAK (AUC < 0.70) models. As of this change the
whole bundle passes: *"No model was dead or below the AUC floor on real
data."*
