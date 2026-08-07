# Day 283 — m1_pocket_muffled retrain (real Kaggle run, verified)

## Status: constant-output bug fixed and verified; model is NOT shippable — weak real-world discrimination

The degenerate constant-1.0 collapse documented in `PREPROCESSING_SPEC.md`
is fixed and independently verified gone. But the retrained model's
real-world discrimination, measured on real audio outside the training
script's own eval split, is close to chance (AUC ~0.51-0.59). The
official in-script report claims AUC 0.8525; that number is real
(computed, not fabricated) but is inflated by the same train/test
leakage pattern already documented for `m1_scream_v2` in
`PREPROCESSING_SPEC.md`. Net result: **improved, not fixed** — do not
ship, do not wire.

## 1. Original script and task

`kaggle_notebooks/m1_pocket_muffled_push/day82_m1_pocket_muffled.py` —
MobileNetV3Small binary classifier meant to recognize screams/distress
speech that reaches the mic through cloth (phone in pocket/bag).

- Positives: RAVDESS emotion codes 05/06/07/08 (angry/fear/disgust/surprised).
- Negatives: RAVDESS calm/neutral (01-04) + ESC-50 ambient sound.
- Augmentation: `pocket_muffle()` = 800 Hz low-pass (Butterworth) +
  30-50% volume + Gaussian "rustling" noise, applied to **70% of
  positive clips only**. All negatives were left unmuffled.
- Originally reported: AUC 0.9759, pocket_recall 1.0.

## 2. Diagnosis (verified against real audio before touching training code)

Root cause: **label/artifact confound**, same failure class as the Day
272 `k_confinement` light/label confound. `pocket_muffle()` applied only
to positives makes "does this clip carry the muffling signature" a
perfect, trivial predictor of the label, so the CNN learns to detect the
artifact, not scream content.

Verified on both originally-shipped checkpoints with real RAVDESS clips
muffled via the model's own `pocket_muffle()` function:

- `m1_pocket_muffled_float32.tflite` (correct 128x87x3 architecture):
  real variance on clean audio (0.07-0.97), but **every single muffled
  clip, regardless of true label, returned exactly 1.0000** (20/20
  tested).
- `m1_pocket_muffled.tflite` (shipped under the "INT8" name): a
  separate, unrelated defect — input tensor `[1,128,131,3]`, which
  doesn't match this task's trained architecture at all (131 is
  `m1_scream_v2`'s frame count). Constant 0.0 on everything tested —
  looks like a build/export mixup, not a trained checkpoint for this
  task.

## 3. Fix implemented

`kaggle_notebooks/m1_pocket_muffled_push` (worktree
`kaggle_notebooks_day283`, branch `day283-pocket-muffled-retrain`) —
`day283_m1_pocket_muffled_retrain.py`:

1. `build_dataset()`: negatives now get the same 70/30 muffle split as
   positives, `pocket_muffle()` applied to the muffled fraction. This
   removes the artifact/label correlation.
2. `build_pocket_test_set()`: now includes muffled negatives, not just
   muffled positives, so `pocket_recall` can no longer read 1.0 from a
   constant-yes model.
3. `find_input_dir()`: made recursive (this Kaggle account's dataset
   mount was nested this run, `/kaggle/input/datasets/<owner>/...`
   instead of flat `/kaggle/input/<slug>/...`; the original single-level
   `iterdir()` scan couldn't see it).
4. `kernel-metadata.json`: fixed the ESC-50 dataset slug
   (`mmoreaux/environmental-sound-classification-50`, the one
   referenced in the Day 82 script no longer resolves) and set
   `enable_internet: true` (needed to download ImageNet weights for
   MobileNetV3Small; the original kernel had internet off and this
   TF/Keras version does not vendor the weights).
5. `export_tflite()`: `model.save(dir_without_extension)` no longer
   works on this environment's Keras 3 / TF 2.20 (raises "Invalid
   filepath extension"); replaced with `model.export(dir)`, the Keras 3
   API for writing a SavedModel. Unrelated to the confound fix — a
   library-version issue the Day 82 script predates.

## 4. Real Kaggle run — what actually happened

Kernel `hridyajain/day283-m1-pocket-muffled-retrain`, pushed and polled
to completion this session (`kaggle kernels status`, real terminal
states, not simulated):

- v1: failed at 5 min mount timeout — `find_input_dir` couldn't see the
  nested dataset mount. Fixed (item 3 above).
- v2: failed at "RAVDESS not found" origin — needed rebuild after fix;
  also discovered ESC-50 slug was invalid. Fixed metadata.
- v3: got through feature extraction and full training (both phases
  complete, ~1055s), but crashed in `export_tflite()` on
  `model.save()` (Keras 3 API break, item 5). Training itself and
  evaluation succeeded and wrote a real report at this point:
  AUC 0.8637, pocket_recall 0.80 (200-sample balanced pocket set).
- v4: fixed export, full run completed end-to-end (`status: complete`),
  ~19 min wall clock (mount+build+train+export), real `.tflite` and
  `_float32.tflite` files produced.

**Final official report** (`m1_pocket_muffled_report.json`, from the
kernel's own held-out split, train_test_split(stratify, random_state=42)
on 3800 total augmented samples from 1440 RAVDESS source clips +
negatives):

```
auc: 0.8525
accuracy: 0.7513
precision_scream: 0.5611
recall_scream: 0.8212  (target 0.82 -- met)
pocket_recall: 0.815 (target 0.85 -- not met; 200-sample balanced
                       muffled pos+neg set, so this is a real,
                       non-gameable number this time)
support_positive: 1152, support_negative: 2652
```

## 5. Independent output-variance + AUC verification (the check that matters)

Re-ran the exact real-RAVDESS muffled/clean x pos/neg test that caught
the original constant-1.0 bug, against the NEW checkpoints. First pass
n=40 (10 actors/class), then expanded to n=161 (40 actors/class, less
cherry-picked) for a more reliable AUC estimate.

**Degenerate-constant check — PASSED, bug is fixed:**

| checkpoint | overall std | min | max |
|---|---|---|---|
| `m1_pocket_muffled.tflite` | 0.198 | 0.078 | 0.977 |
| `m1_pocket_muffled_float32.tflite` | 0.144 | 0.064 | 0.979 |

Both well above the 1e-4 "still constant" threshold. No muffled clip
returns exactly 1.0000 or exactly 0.0000 anymore, and — critically —
predictions no longer cluster by "was pocket_muffle() applied," they
vary within both the muffled and clean groups. The confound is gone.

**Real-world discrimination check — FAILED, near chance:**

On the n=161 independent set (different, broader RAVDESS sample than
what any training/eval split saw as a whole set, though not a strict
actor-level holdout):

| checkpoint | overall AUC | clean-only AUC | muffled-only AUC |
|---|---|---|---|
| `m1_pocket_muffled.tflite` (int8-target) | 0.510 | 0.503 | 0.523 |
| `m1_pocket_muffled_float32.tflite` | 0.588 | 0.688 | 0.446 |

These are close to or at chance (0.5), starkly below the official
0.8525. This is the same pattern already on record for `m1_scream_v2`
in `PREPROCESSING_SPEC.md`: `build_dataset()` generates multiple
augmented variants (pitch/time/SNR/muffle variants) from each source
clip and only THEN does `train_test_split` at the sample level — so
near-duplicate variants of the same underlying clip land in both train
and test, inflating the reported metric. The official pocket_recall
0.815 is a real, non-gameable number in the sense that it's no longer
fooled by a constant-yes shortcut, but it still likely benefits from
this same leakage.

## 6. Honest conclusion

**Improved, not fixed.** The specific degenerate bug this task set out
to fix — constant 1.0 output on muffled audio regardless of content —
is confirmed fixed by real-data testing (real variance, no more forced
constants, muffling no longer perfectly predicts the model's output).
That part of the diagnosis and fix is validated.

But the retrained model does not clear the bar for a real detector: an
independent, broader real-audio check puts it at or near chance
(AUC 0.51-0.59), not the 0.85 its own held-out split reports. The task
itself (recognizing screams under heavy low-pass + attenuation from a
single 1-second mel-spectrogram frame, using RAVDESS acted speech as the
only positive source) may also be a genuinely hard, thin-signal problem
that a leakage-free evaluation would expose as not working well — this
retrain doesn't disambiguate "the confound was the whole problem" from
"the confound was one problem among several." `m1_pocket_muffled`
remains unshipped and unwired.

## 7. Artifacts from this run

- `kaggle_notebooks_day283/m1_pocket_muffled_push/day283_m1_pocket_muffled_retrain.py`
  (the fixed training script, committed to `kaggle_notebooks` on branch
  `day283-pocket-muffled-retrain`)
- `kaggle_notebooks_day283/m1_pocket_muffled_push/kernel-metadata.json`
  (fixed dataset slug + internet enabled)
- `kaggle_notebooks_day283/m1_pocket_muffled_push/output_final/` (local,
  not committed: `m1_pocket_muffled.tflite`, `_float32.tflite`,
  `m1_pocket_muffled_report.json`, training log, checkpoints,
  SavedModel dirs) — kept for reference, NOT copied into
  `zapsafe_mobile/assets/models/` per this task's explicit instruction
  not to touch shipped `.tflite` files.

## Next step (not done here, would require actual leakage fix)

Re-split at the RAVDESS-actor level (not sample level) before any
augmentation, so no variant of a given actor's clip appears in both
train and test, then re-measure. Only then would an AUC number here be
trustworthy enough to consider wiring.
