# Day 291 — M3 danger-classifier retrain, iteration 2 on real UCF-Crime

**Scope note:** same target as day289 — day84's `m3_lighting_augmented`
checkpoint (SAFE/NEUTRAL/RISKY, `224x224x3`, softmax `[1,3]`), NOT
day103's `m3_scene_adversarial`. Not wired into the app. No
detector/wiring/tflite-shipping/pubspec/backend files touched.

## What changed vs day289 (real diffs, not a repeat)

Read `kaggle_notebooks/day289_m3_ucf_crime_push/day289_m3_ucf_crime.py`
first. Day289's final run trained the frozen-base head only (0.5018 test
accuracy) after its fine-tune phase (unfreeze 50 MobileNetV3Small layers,
lr=1e-5, single `fit()` call) caused catastrophic forgetting: val_accuracy
collapsed 0.51 -> 0.25-0.37, loss exploded 0.70 -> 18.9, confusion matrix
`[[2943,57,0],[2043,80,0],[2965,35,0]]` (RISKY recall 0).

This session's script, `kaggle_notebooks/day291_m3_iteration2/day291_m3_ucf_crime_v2.py`:

1. **Much more conservative fine-tune**: unfreeze only the last **15**
   base layers (was 50), at `fine_tune_lr=3e-6` (was `1e-5`) — ~3x fewer
   layers, ~3x lower LR.
2. **BatchNorm frozen even within the unfrozen tail** — `base.trainable=True`
   flips BN layers trainable too by default; BN running-stat drift on a
   small fine-tune set is a plausible real contributor to day289's
   collapse, so BN layers inside the unfrozen slice are explicitly kept
   `trainable=False` regardless of the surrounding layer.
3. **Tight fine-tune-phase EarlyStopping** (patience=2, monitor
   `val_accuracy`, `restore_best_weights=True`) plus a real safety guard:
   after fine-tuning, `phase2_best_val_accuracy` is compared to
   `phase1_best_val_accuracy`; fine-tuned weights are kept only if not
   worse, else the script reverts to the saved frozen-base weights
   (`day291_phase1.weights.h5`) automatically.
4. **Larger real sample**: `max_frames_per_video` 40->60, `max_per_class`
   (per split) 3000->5500 — train frames 9,000->16,500 (1.8x), val
   13,504 frames, test 14,119 frames (day289: 8,016 val / 8,123 test).
5. **Class weighting**: kept (already present in day289, confirmed still
   needed — RISKY spans 9 on-disk folders vs. NEUTRAL's 4 and SAFE's
   single large `NormalVideos` folder). Per-class train counts came out
   exactly balanced by the `max_per_class` cap: 5,500/5,500/5,500
   (SAFE/NEUTRAL/RISKY) — the cap plus class_weight already neutralizes
   the raw folder-count imbalance, same finding as day289.

Same `DANGER_MAP` and video-level train/val/test split methodology as
day289 (unchanged — already verified correct there, not re-litigated).

## Real run

Kaggle kernel `hridyajain/zapsafe-day291-m3-iteration2`, version 1, T4/P100
GPU, `train_sec=404.9` (~6.7 min, vs day289's ~4.3 min — larger sample and
two fit() phases).

Phase 1 (frozen-base head, `day291_phase1_log.csv`): best val_accuracy
**0.5058** at epoch 0, then val_accuracy *declined* over the next 5 epochs
(0.4801 -> 0.4753 -> 0.4668 -> 0.4762 -> 0.4869) while train accuracy
climbed fast (0.49 -> 0.69) — EarlyStopping (patience 5) correctly stopped
at epoch 6 and restored epoch-0 weights. This is a real, different (worse)
overfitting curve than day289, where val_accuracy plateaued around
0.50-0.52 through epoch 13 before declining — day289's smaller sample
(3,000/class, 40 frames/video) generalized more steadily than this
iteration's larger one (5,500/class, 60 frames/video). Likely cause: more
frames per video (60 vs 40) adds more near-duplicate, not more distinct,
information — same number of source videos, more redundant samples per
video — which speeds up memorizing video-specific backgrounds rather than
improving generalization.

Phase 2 (careful fine-tune, `day291_phase2_log.csv`, 3 epochs before
EarlyStopping): val_accuracy 0.5070 (epoch 0) -> 0.4839 -> 0.4753, no
collapse (unlike day289's fine-tune, this stayed in the 0.47-0.51 band, no
loss explosion) — **the fine-tuning fix worked**: no catastrophic
forgetting this time. `phase2_best_val_accuracy=0.5070` edged out
`phase1_best_val_accuracy=0.5058` by 0.0012, so the safety-guard logic kept
the fine-tuned weights (`fine_tune_kept: true`) rather than reverting.

## Real held-out test result

**Test split accuracy: 0.4786** (3-class; chance = 0.333). **This is a
regression vs. day289's 0.5018**, not an improvement.

| class | F1 | recall |
|---|---|---|
| SAFE | 0.5630 | — |
| NEUTRAL | 0.3792 | — |
| RISKY | 0.4344 | 0.3625 |

Confusion matrix (rows=true, cols=pred, order SAFE/NEUTRAL/RISKY):

```
[[3525, 1057,  918],
 [1111, 1239,  769],
 [2386, 1120, 1994]]
```

**Confusion-matrix sanity check**: not collapsed — every class has
substantial true-positive mass and no column is near-zero (unlike day289's
broken fine-tune run, where the RISKY column was `[0,0,0]`). So this is a
real, non-degenerate 0.4786, genuinely worse than day289's real,
non-degenerate 0.5018 — not a "collapsed but looks higher" trap, just a
plain regression.

## Verdict — no real progress this iteration

- The fine-tuning fix (fewer unfrozen layers, lower LR, frozen BN, tight
  EarlyStopping + safety guard) **worked as intended**: no catastrophic
  forgetting, val_accuracy stayed in a stable 0.47-0.51 band through both
  phases. That specific hypothesis (day289's collapse was an
  LR/layer-count/BN-drift problem) is now supported by a real experiment
  that removed those factors and did not collapse.
- However, **the larger sample (60 frames/video, 5,500/class) made
  generalization worse, not better** — the head overfit within a single
  epoch instead of plateauing for ~8 epochs like day289. The hypothesis
  that "more real frames = better accuracy" was tested directly and came
  out **false** for this dataset/sampling scheme: more frames-per-video
  without more distinct videos increases redundancy, not diversity.
- Net result: **0.4786 test accuracy, below day289's 0.5018 baseline.**
  This iteration does not replace day289's checkpoint as the better
  candidate. Reporting this plainly per instructions — not every
  iteration improves on the last, and this one didn't.
- A real follow-up worth trying (not done this session, out of scope
  here): keep `max_frames_per_video` at day289's 40 (or lower, e.g. 20) to
  reduce redundancy while still capping at a similar or slightly larger
  `max_per_class`, i.e. increase video diversity rather than frames per
  video — the actual on-disk video counts (day289 doc: `NormalVideos` 950
  videos, most anomaly classes 50-150 videos) are the real bottleneck, not
  frame count.

## Files produced this session

- `kaggle_notebooks/day291_m3_iteration2/day291_m3_ucf_crime_v2.py` — real training script
- `kaggle_notebooks/day291_m3_iteration2/kernel-metadata.json` — Kaggle kernel config
- `kaggle_notebooks/day291_m3_iteration2/final/m3_ucf_crime_report_v2.json` — real metrics
- `kaggle_notebooks/day291_m3_iteration2/final/day291_phase1_log.csv`, `day291_phase2_log.csv` — real per-epoch curves for both phases
- `kaggle_notebooks/day291_m3_iteration2/final/day291_m3_ucf_train.log` — full real training log
- `kaggle_notebooks/day291_m3_iteration2/final/m3_ucf_crime_retrain_v2.tflite` — real exported model (NOT shipped, candidate artifact only, and not the better candidate anyway — day289's checkpoint remains the better of the two)
- This file, `assets/models/DAY291_M3_ITERATION2.md`, in `zapsafe_mobile` on branch `day291-m3-iteration2`
