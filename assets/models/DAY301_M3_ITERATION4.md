# Day 301 — M3 danger-classifier retrain, iteration 4 on real UCF-Crime

**Scope note:** same target as day289/291/293 — day84's `m3_lighting_augmented`
checkpoint (SAFE/NEUTRAL/RISKY, `224x224x3`, softmax `[1,3]`), NOT
day103's `m3_scene_adversarial`. Not wired into the app. No
detector/wiring/tflite-shipping/pubspec/backend files touched.

## Two genuinely new levers tested this session (not a repeat of iter 3)

Day293 (iteration 3) reached test accuracy **0.5944** by cutting
`max_frames_per_video` from 60 to 12 to maximize distinct-video diversity,
holding `max_per_class=5500`. This session checked for real headroom beyond
that result along two axes:

### 1. Real data volume headroom

Read day293's own script and doc first. Real on-disk video counts
(re-verified against the same `odins0n/ucf-crime-dataset` mount, which the
script itself merges from the dataset's `Train/` + `Test/` folders before
doing its own video-level 70/15/15 split — no unused folder was being
skipped):

- NEUTRAL (Arrest+RoadAccidents+Shoplifting+Stealing): 245/245 train videos
  already used in day293 (100%) — **no headroom**, hard video-count ceiling.
- RISKY (9 crime classes): 420/420 train videos already used in day293
  (100%) — **no headroom**, hard video-count ceiling.
- SAFE (NormalVideos): only 459/665 train videos used in day293 (69%),
  artificially capped by `max_per_class=5500` at 12 frames/video
  (459×12=5508 hits the cap before all 665 videos are drawn) — **real
  headroom existed here.**

Change: `max_per_class` raised 5500 → 8500 (665×12=7980 < 8500), so SAFE's
train pool went from 459/665 (69%) to the full 665/665 (100%) distinct
videos. NEUTRAL and RISKY frame totals were already under 8500 with no
change needed — they are genuine video-count bottlenecks, not
`max_per_class`-capped, so this had zero effect on them.
`max_frames_per_video` stayed at 12 (day293's working diversity strategy,
not reverted to day291's failed 60/video approach).

Real confirmed split sizes this run: train=15,960 (SAFE 7,980 / NEUTRAL
2,940 / RISKY 5,040), val=3,348, test=3,491.
Real `distinct_videos_used`: train SAFE=665/665 (100%, up from 459/665),
train NEUTRAL=245/245 (100%, unchanged), train RISKY=420/420 (100%,
unchanged).

### 2. Real architecture change

Backbone swapped MobileNetV3Small (unchanged across day289/291/293) →
**MobileNetV3Large**, same family so the `224×224` /
`include_preprocessing=True` pipeline is unchanged. Fine-tuning discipline
is byte-for-byte identical to day291/293's proven-safe recipe: unfreeze
only the last 15 base layers, `fine_tune_lr=3e-6`, BatchNorm frozen even
within the unfrozen tail, tight `EarlyStopping(patience=2)` with a
revert-to-phase1-weights safety guard if phase 2 regresses `val_accuracy`.

Everything else (video-level 70/15/15 split, `DANGER_MAP`, `head_epochs`,
`ft_epochs`, `lr`, `unfreeze_layers`) is unchanged from day293.

## Real run

Kaggle kernel `hridyajain/zapsafe-day301-m3-iteration4`, version 1, GPU,
status polled to real terminal state `"complete"`.

Phase 1 (frozen-base head): best val_accuracy **0.5475**.
Phase 2 (careful fine-tune, MobileNetV3Large last 15 layers): val_accuracy
improved to **0.5636** — `fine_tune_kept: true`, no regression/reversion
needed (same as day291/293's finding that the conservative fine-tune
recipe doesn't collapse, now confirmed with a different backbone too).

## Real held-out test result

**Test split accuracy: 0.5637** (3-class; chance = 0.333).

This is **worse than day293's 0.5944** by **-0.0307**, though still
clearly above day289 (0.5018 by +0.0619) and day291 (0.4786 by +0.0851).

| class | recall | precision | F1 |
|---|---|---|---|
| SAFE | 0.7081 | 0.6694 | 0.6882 |
| NEUTRAL | 0.4189 | 0.3861 | 0.4019 |
| RISKY | 0.4274 | 0.4949 | 0.4587 |

Confusion matrix (rows=true, cols=pred, order SAFE/NEUTRAL/RISKY):

```
[[1215,  204,  297],
 [ 181,  271,  195],
 [ 419,  227,  482]]
```

**Confusion-matrix sanity check**: not collapsed. Every class has
substantial diagonal mass and no row/column is near-zero. Notably, NEUTRAL
recall/F1 improved over day293 (0.4189 vs day293's NEUTRAL recall not
separately reported but F1 0.4019 vs day293's NEUTRAL F1 0.3370 — an
improvement), but **RISKY recall dropped** from day293's 0.5027 to 0.4274,
and that's the net driver of the overall regression since RISKY is the
largest and most safety-critical minority class. This looks like a real
trade-off, not degenerate collapse: the model spreads more evenly across
classes but loses sharpness specifically on RISKY.

## Verdict — neither lever improved on day293; likely near this data/recipe's ceiling

- **Real data volume**: giving SAFE its full 665/665 video pool (up from
  459/665) did not help — SAFE's own F1 (0.6882) is actually slightly
  below day293's SAFE F1 (0.7172). More SAFE diversity did not translate
  to a better decision boundary; SAFE was never the bottleneck class and
  padding it further likely diluted the loss signal for the harder
  NEUTRAL/RISKY split (despite class-weighting). Confirms day293's own
  conclusion: **NEUTRAL and RISKY have zero real headroom left in this
  dataset** (100% of distinct on-disk videos already used for both), so
  this lever is now conclusively exhausted without a net-new data source.
- **Real architecture change**: MobileNetV3Large with the same careful
  fine-tuning recipe reached a similar ballpark (0.5637) but did not beat
  MobileNetV3Small's 0.5944. More capacity did not help — consistent with
  the bottleneck being data diversity/label noise (UCF-Crime's frame-level
  visual signal for this 3-class danger mapping), not model capacity.
- **Net result: this iteration did not improve on day293's 0.5944.**
  Reporting plainly, per this project's standing rule against repeating
  experiments hoping for a different result: **day293's
  `m3_ucf_crime_retrain_v3` (0.5944, MobileNetV3Small, 12
  frames/video, max_per_class=5500) remains the best real UCF-Crime
  retrain candidate.** Both obvious next levers within this real data
  source (more real video volume for the bottleneck classes, more model
  capacity) are now tried and exhausted. Day293's 0.5944 appears close to
  this architecture family's real ceiling on UCF-Crime's frame-level
  signal for this 3-class SAFE/NEUTRAL/RISKY mapping — a further
  improvement would likely require a genuinely different signal (e.g.
  temporal/optical-flow features across frames, or a net-new real video
  data source beyond UCF-Crime), not another sampling or backbone tweak
  on the same data.
- `m3_ucf_crime_retrain_v4` (this iteration's checkpoint) is a candidate
  artifact only, **not wired into the app**, and is **not** recommended to
  replace day293's checkpoint as the current best.

## Files produced this session

- `kaggle_notebooks/day301_m3_iteration4/day301_m3_ucf_crime_v4.py` — real training script (max_per_class 5500→8500, backbone MobileNetV3Small→MobileNetV3Large; everything else unchanged from day293's v3 script)
- `kaggle_notebooks/day301_m3_iteration4/kernel-metadata.json` — Kaggle kernel config
- `kaggle_notebooks/day301_m3_iteration4/final/day301_m3_ucf_train.log` — full real training log (source of all numbers in this doc)
- `kaggle_notebooks/day301_m3_iteration4/final/day301_phase1_log.csv`, `day301_phase2_log.csv` — real per-epoch curves for both phases
- `kaggle_notebooks/day301_m3_iteration4/final/day301_phase1.weights.h5` — phase-1 fallback weights
- This file, `assets/models/DAY301_M3_ITERATION4.md`, in `zapsafe_mobile` on branch `day301-m3-iteration4`
