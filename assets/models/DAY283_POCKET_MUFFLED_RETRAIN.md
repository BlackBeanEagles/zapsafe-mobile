# Day 283 — m1_pocket_muffled retrain attempt (diagnosis + fix implemented, retrain NOT executed)

## Status: diagnosis confirmed with real data, fix implemented, actual Kaggle retrain not run this session

Do not treat this as "fixed." No new checkpoint exists. This document
records a verified root-cause diagnosis and a code fix, ready to run on
Kaggle, but the multi-hour GPU training run itself was not executed or
completed in this session. Reporting this honestly rather than
fabricating a retrain result.

## 1. Original script and task

`kaggle_notebooks/m1_pocket_muffled_push/day82_m1_pocket_muffled.py` —
MobileNetV3Small binary classifier meant to recognize screams/distress
speech that reaches the mic through cloth (phone in pocket/bag), so a
scream detector doesn't go silent just because the phone is pocketed.

- Positives: RAVDESS emotion codes 05/06/07/08 (angry/fear/disgust/surprised).
- Negatives: RAVDESS calm/neutral (01-04) + ESC-50 ambient sound.
- Augmentation: `pocket_muffle()` = 800 Hz low-pass (Butterworth) +
  30-50% volume + Gaussian "rustling" noise, applied to **70% of
  positive clips only**. The other 30% of positives and **all**
  negatives are left unmuffled.
- Reported: AUC 0.9759, pocket_recall 1.0 (both on the script's own
  held-out splits).

## 2. Diagnosis, verified against real audio (not guessed)

Root cause: **label/artifact confound**, same failure class as the Day
272 `k_confinement` light/label confound. `pocket_muffle()` is applied
only to the positive class, so "does this clip have the muffling
signature (rolled-off highs, quiet, faint noise floor)" becomes a
perfect, trivial predictor of the label in the training distribution.
A CNN takes the easy shortcut instead of learning scream content.

Verified directly on both shipped checkpoints using real RAVDESS clips
(neutral speech, fear/distress speech, silence), muffled with the
model's own `pocket_muffle()` function so the test matches training
exactly:

- `m1_pocket_muffled_float32.tflite` (matches the trained architecture,
  128x87x3 input): on **clean** audio it has real variance (min 0.07,
  max 0.97, correlated loosely with fear vs. neutral) — it is not
  globally degenerate. But **every single muffled clip, regardless of
  true label** (`neutral_muffled` and `fear_muffled` alike, 20/20
  samples) **returns exactly 1.0000**. This is the exact mechanism:
  the model isn't reading content once the muffling artifact appears,
  it's reading the artifact itself.
- `m1_pocket_muffled.tflite` (the file shipped under the "INT8" name):
  a separate, unrelated finding — its actual input tensor is
  `[1,128,131,3]` float32, not the `[1,128,87,3]` int8 tensor the
  training script produces. This file does not match the documented
  architecture at all (131 is `m1_scream_v2`'s frame count, not this
  model's 87) and returns a **constant 0.0** on every input tested.
  It looks like a build/export mixup rather than a trained checkpoint
  for this task — a second, independent reason this file must not
  ship, on top of the confound above.

This confirms the `PREPROCESSING_SPEC.md` finding (constant 1.000,
AUC 0.500 on pocket-muffled audio) and explains *why*: it is not
random collapse, it is the model correctly learning the training
distribution's dominant (spurious) signal.

Verification script: kept in this worktree's temp scratch, logic
reproduced inline above; re-run against
`C:\Users\hridy\Desktop\zapsafe\ml_datasets\vocal_stress\DS01_RAVDESS`
(real RAVDESS, 1440 files, present locally) to reproduce.

## 3. Fix implemented (not yet trained)

`day283_m1_pocket_muffled_retrain.py` (copy of the Day 82 script with
two changes):

1. `build_dataset()`: negatives are now split by the same
   `muffle_ratio` (70%) and the muffled fraction gets
   `pocket_muffle()` applied before mel extraction — identical
   treatment to positives. This breaks the artifact/label correlation;
   the model can no longer solve the task by detecting muffling alone.
2. `build_pocket_test_set()`: now includes muffled negatives (not just
   muffled positives), so pocket_recall can no longer read 1.0 from a
   constant-yes model — a constant-yes model would now score ~0.5 on
   this set, same logic as the `k_confinement` decorrelation fix.

## 4. What was NOT done

The actual Kaggle GPU retrain (~3-4 hours per the original script's own
estimate) was not launched/monitored to completion in this session.
No new `.tflite`, no new report, no new AUC/variance numbers exist.
Do not infer a result from the fix being "implemented" — until a real
run completes and is checked for the same constant-output failure mode
on real held-out audio (silence, clean neutral, clean fear, muffled
neutral, muffled fear; std < 1e-4 = still broken), this remains an
unresolved model, exactly as `PREPROCESSING_SPEC.md` already states.
`m1_pocket_muffled` stays unshipped and unwired.

## Next step (follow-up, not done here)

Run `day283_m1_pocket_muffled_retrain.py` on Kaggle (RAVDESS + ESC-50
datasets, T4 GPU), then re-run the muffled/unmuffled x pos/neg
verification above against the new checkpoint before considering this
fixed.
