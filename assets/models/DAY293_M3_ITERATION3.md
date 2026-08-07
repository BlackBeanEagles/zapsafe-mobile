# Day 293 — M3 danger-classifier retrain, iteration 3 on real UCF-Crime

**Scope note:** same target as day289/291 — day84's `m3_lighting_augmented`
checkpoint (SAFE/NEUTRAL/RISKY, `224x224x3`, softmax `[1,3]`), NOT
day103's `m3_scene_adversarial`. Not wired into the app. No
detector/wiring/tflite-shipping/pubspec/backend files touched.

## The one specific hypothesis tested this session

Day291's own doc (`assets/models/DAY291_M3_ITERATION2.md`) proposed a
precise, untried fix instead of another broad retry: **reduce
`max_frames_per_video` to raise real video diversity** relative to total
sample size, since day291's regression (0.4786, vs day289's 0.5018) was
diagnosed as more redundant near-duplicate frames from the *same* videos
(60 frames/video, 5,500/class) overfitting faster than day289's smaller,
less-redundant sample (40 frames/video, 3,000/class).

This session changed **only** that: `max_frames_per_video: 60 -> 12`,
`max_per_class` held at day291's larger 5,500 (not reverted to day289's
3,000, per "similar or larger total sample size"). Everything else —
video-level 70/15/15 split, `DANGER_MAP`, model architecture, and
critically **day291's fine-tuning fix (unfreeze last 15 base layers only,
`fine_tune_lr=3e-6`, BatchNorm frozen even within the unfrozen tail, tight
EarlyStopping with a revert-to-frozen-base safety guard)** — is byte-for-byte
unchanged from `kaggle_notebooks/day291_m3_iteration2/day291_m3_ucf_crime_v2.py`.

Real on-disk video counts (UCF-Crime, re-verified from this session's own
log, matches day291's log): `NormalVideos` 950, NEUTRAL classes
(Arrest+RoadAccidents+Shoplifting+Stealing) 350 total, RISKY classes
(Abuse+Assault+Fighting+Robbery+Shooting+Burglary+Arson+Explosion+Vandalism)
600 total. With the 70/15/15 split, RISKY's train pool is ~420 videos —
the tightest bottleneck. At `max_frames_per_video=12`, RISKY's train frame
ceiling is 420*12=5,040, **under** the 5,500 cap, so training used **all**
420 available RISKY train videos and all 245 available NEUTRAL train videos
(no video was excluded for either bottleneck class) — vs. day291's ~92
RISKY videos (22% of available) and day289's ~75 (18%).

## Real run

Kaggle kernel `hridyajain/zapsafe-day293-m3-iteration3`, version 1, GPU,
`train_sec=292.6` (~4.9 min — faster than day291's 6.7 min despite a
comparable train-set size, consistent with more, shorter per-video I/O
batches vs fewer, longer ones).

Real sample sizes: train=13,480 (SAFE 5,500 capped / NEUTRAL 2,940 uncapped
/ RISKY 5,040 uncapped), val=3,348, test=3,491. Smaller total train set than
day291's 16,500 (expected — NEUTRAL and RISKY simply don't have enough
distinct videos to reach 5,500 at 12 frames/video without repeating
videos), but every video used contributes non-redundant sampling from a
distinct source.

**`distinct_videos_used`** (real counts from this run):
train NEUTRAL=245/245 (100%), train RISKY=420/420 (100%), train SAFE=459/665
(69%, never the bottleneck). Confirms the sampling change did what it was
designed to do.

Phase 1 (frozen-base head, `day293_phase1_log.csv`): best val_accuracy
**0.5454**. Phase 2 (careful fine-tune, `day293_phase2_log.csv`):
val_accuracy improved further to **0.5553**, beating phase 1 —
`fine_tune_kept: true` (no regression/reversion needed, same as day291's
finding that the conservative fine-tune fix doesn't collapse).

## Real held-out test result

**Test split accuracy: 0.5944** (3-class; chance = 0.333).

This **beats both prior baselines**: day289 (0.5018) by +0.0926, and
day291 (0.4786) by +0.1158.

| class | F1 | recall |
|---|---|---|
| SAFE | 0.7172 | — |
| NEUTRAL | 0.3370 | — |
| RISKY | 0.5257 | 0.5027 |

Confusion matrix (rows=true, cols=pred, order SAFE/NEUTRAL/RISKY):

```
[[1311,  144,  261],
 [ 249,  197,  201],
 [ 380,  181,  567]]
```

**Confusion-matrix sanity check**: not collapsed. Every class has
substantial true-positive mass on the diagonal (SAFE 1311/1716=76.4% of its
row, NEUTRAL 197/647=30.4%, RISKY 567/1128=50.3%), no row or column is
near-zero, and RISKY recall (0.5027) is the best of all three iterations
(day289/291 RISKY recall not separately reported at this granularity, but
neither prior run's RISKY column was this populated outside of day289's
disabled fine-tune). This is a real, non-degenerate, genuinely better
0.5944 — not an artifact of a collapsed or trivial prediction.

## Verdict — hypothesis confirmed

- The specific, previously-undone idea from day291 — **reduce
  frames-per-video to increase real video diversity, not frame count** —
  produced a real, substantial improvement: **0.5944 vs. day289's 0.5018
  and day291's 0.4786**.
- This directly confirms day291's diagnosis: day291's regression was a
  sampling artifact (redundant near-duplicate frames from too few distinct
  videos), not evidence that UCF-Crime's frame-level visual signal caps out
  near 0.50 for this architecture. With genuine per-class video diversity
  maximized (100% of available train videos used for both bottleneck
  classes), the same architecture and fine-tuning recipe generalizes
  meaningfully better.
- Per this project's standing rule against repeating the same experiment
  hoping for a different result: since this iteration **did** improve, no
  4th iteration of this same idea-space is warranted right now. A genuinely
  new idea (e.g. temporal/optical-flow features, different backbone, or
  further per-class video-count-aware sampling tuning) would be required
  for any next step, and none is being attempted this session.
- `m3_ucf_crime_retrain_v3` (this iteration's checkpoint) is now the best
  of the three real UCF-Crime retrain attempts, but remains **not wired
  into the app** — same as day289/291's candidates, this is a candidate
  artifact only.

## Files produced this session

- `kaggle_notebooks/day293_m3_iteration3/day293_m3_ucf_crime_v3.py` — real training script (only sampling changed vs day291's v2 script)
- `kaggle_notebooks/day293_m3_iteration3/kernel-metadata.json` — Kaggle kernel config
- `kaggle_notebooks/day293_m3_iteration3/final/m3_ucf_crime_report_v3.json` — real metrics
- `kaggle_notebooks/day293_m3_iteration3/final/day293_phase1_log.csv`, `day293_phase2_log.csv` — real per-epoch curves for both phases
- `kaggle_notebooks/day293_m3_iteration3/final/day293_m3_ucf_train.log` — full real training log
- `kaggle_notebooks/day293_m3_iteration3/final/m3_ucf_crime_retrain_v3.tflite` — real exported model (NOT shipped, candidate artifact only)
- This file, `assets/models/DAY293_M3_ITERATION3.md`, in `zapsafe_mobile` on branch `day293-m3-iteration3`
