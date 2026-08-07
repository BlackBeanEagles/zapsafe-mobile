# Day 308 -- M3 danger classifier: source-balanced sampling retrain

## Context

Day 305 (`DAY305_M3_SECOND_DATASET.md`) combined UCF-Crime with XD-Violence
and regressed to 0.4950 test accuracy vs Day 293's 0.5944 UCF-Crime-only
baseline. Day 305's own diagnosis, re-verified by reading its training log
(`kaggle_notebooks/day305_m3_second_dataset/final/day305_m3_ucf_xdv_train.log`)
directly: the per-class frame cap (`max_per_class=5500`) was filled
**greedily**, processing all of UCF-Crime's categories before any of
XD-Violence's. For the SAFE class specifically:

| split | ucf frames | xdv frames | % xdv |
|---|---|---|---|
| train | 5500 | 0 | 0% |
| val | 1704 | 3796 | 69% |
| test | 1716 | 3784 | 69% |

The model trained on SAFE = 100% UCF-Crime fixed-CCTV footage, then was
evaluated on SAFE that was 69% XD-Violence movie/dashcam/UGC footage it had
never seen in training -- a real, self-inflicted train/test domain mismatch,
not evidence the combined data lacks signal. Result: SAFE recall collapsed
to 22.5% (1237/5500 true SAFE frames correctly classified), with 4074/5500
SAFE frames misclassified as RISKY.

## The fix: source-balanced allocation

`kaggle_notebooks/day308_m3_balanced_sampling/day308_m3_balanced_v6.py`
replaces the greedy fill with a proportional allocation computed
**identically for train/val/test**, so a class's source mix no longer
depends on which source happened to be processed first:

1. For every `(split, danger-class)` bucket with contributions from both
   sources, compute each source's **real** available frame budget:
   `avail = sum(min(max_frames_per_video, frames actually available))`
   over that bucket's videos. UCF-Crime's count is exact (frames are
   pre-extracted, just counted). XD-Violence's count is a real per-video
   `cv2.VideoCapture` header read (`CAP_PROP_FRAME_COUNT`, no decode) --
   not an assumption.
2. Allocate the shared `max_per_class=5500` cap proportionally to each
   source's share of total real availability, clipped to what each source
   can actually supply (shortfall handed back to the other source, still
   bounded by the cap). This is judgment-based, not a forced 50/50.
3. NEUTRAL (UCF-Crime's Arrest/RoadAccidents/Shoplifting/Stealing) stays
   UCF-Crime-only, exactly as Day 305 documented and decided -- XD-Violence
   has no category that maps to NEUTRAL without contradicting its own
   "anomaly" framing. Not a bug, a deliberate carry-over.

Everything else is unchanged from Day 293/305's proven setup:
`max_frames_per_video=12`, video-level 70/15/15 split (seed=42, no frame
leakage), MobileNetV3Small, frozen-base head then careful fine-tune
(unfreeze last 15 base layers, lr=3e-6, BatchNorm frozen within that
slice), EarlyStopping + revert-to-phase1 safety guard.

Script: `kaggle_notebooks/day308_m3_balanced_sampling/day308_m3_balanced_v6.py`
Kernel: `hridyajain/zapsafe-day308-m3-balanced-sampling` (real Kaggle run,
GPU, dataset_sources: `odins0n/ucf-crime-dataset`, `bypktt/xd-violence`)

## Real balanced-sampling split used (from the real run's `source_allocation`)

| bucket | avail ucf | avail xdv | alloc ucf | alloc xdv | % xdv |
|---|---|---|---|---|---|
| SAFE train | 7,980 | 19,716 | 1,585 | 3,915 | 71.2% |
| SAFE val | 1,704 | 4,224 | 1,581 | 3,919 | 71.3% |
| SAFE test | 1,716 | 4,236 | 1,586 | 3,914 | 71.2% |
| NEUTRAL train/val/test | 2,940 / 612 / 647 | 0 | 2,940 / 612 / 647 | 0 | 0% (UCF-only, unchanged) |
| RISKY train | 5,040 | 17,724 | 1,218 | 4,282 | 77.9% |
| RISKY val | 1,032 | 3,768 | 1,032 (all avail) | 3,768 (all avail) | 78.5% |
| RISKY test | 1,128 | 3,888 | 1,128 (all avail) | 3,888 (all avail) | 77.5% |

SAFE now lands on a consistent ~29% UCF / 71% XDV mix in **every** split
(vs Day 305's 100%/0% train against 31%/69% val/test). RISKY lands on a
consistent ~22% UCF / 78% XDV mix in every split (vs Day 305's 92%/8% train
against ~20%/80% val/test). RISKY val/test didn't hit the 5,500 cap because
real availability there (15% video-split slices) is smaller than the cap --
same real-data constraint Day 305 hit, now applied consistently to train
too instead of being train-specific by accident.

## Real result

| | Day 289 | Day 291 | **Day 293 (best)** | Day 305 (unbalanced combo) | **Day 308 (this run)** |
|---|---|---|---|---|---|
| Test accuracy | 0.5018 | 0.4786 | **0.5944** | 0.4950 | **0.5326** |

Full metrics (from `kaggle_notebooks/day308_m3_balanced_sampling/final/m3_balanced_report_v6.json`):
- accuracy: **0.5326** (+0.0376 over Day 305, -0.0618 vs Day 293's 0.5944)
- SAFE f1: 0.6196, **SAFE recall: 0.6447**
- NEUTRAL f1: 0.3560, NEUTRAL recall: 0.8269 (535/647)
- RISKY f1: 0.4735, RISKY recall: 0.3716
- phase1_best_val_accuracy: 0.5341, phase2_best_val_accuracy: 0.5470
- fine_tune_kept: **true** (phase 2 improved on phase 1, no revert needed)
- train_sec: 2057.4 (kernel wall-clock was longer -- ~68 min end to end --
  due to the real per-video XD-Violence header-read pass across ~4,464
  distinct videos for accurate availability accounting, on top of Day 305's
  own frame-extraction cost)

Confusion matrix (rows=true, cols=pred, SAFE/NEUTRAL/RISKY):
```
           pred SAFE  pred NEUTRAL  pred RISKY
true SAFE      3546        987          967      (recall 64.5%)
true NEUTRAL     85        535           27      (recall 82.7%)
true RISKY     2315        837         1864      (recall 37.2%)
```
Overall: (3546+535+1864)/11163 = 0.5326 -- matches reported accuracy.

## SAFE-recall diagnostic check (the specific thing that collapsed before)

Day 305: SAFE recall 22.5% (1237/5500) -- collapsed because train's SAFE
frames were 100% UCF-Crime CCTV footage while val/test SAFE was 69%
unseen XD-Violence footage. Most SAFE frames defaulted to RISKY.

Day 308 (this run): **SAFE recall 64.5% (3546/5500)** -- a 2.9x recovery.
Train's SAFE frames are now ~71% XD-Violence, matching val/test's ~71%
XD-Violence almost exactly (71.2% / 71.3% / 71.2% across train/val/test).
The domain-mismatch bug is fixed: SAFE recall is no longer anomalously low
relative to its training composition. This confirms Day 305's diagnosis was
correct and the fix addresses the real root cause, not a symptom.

## What changed instead: RISKY recall

RISKY recall dropped from Day 305's 82.1% to this run's 37.2%. This is a
real, explainable trade-off, not a new bug: Day 305's high RISKY recall was
partly an artifact of the same bug -- with SAFE essentially unrecognizable
to the model (100% train/eval domain mismatch), the model defaulted to
predicting RISKY for a lot of ambiguous/out-of-distribution input, which
inflated RISKY recall at SAFE's expense (SAFE's confusion-matrix row shows
4074/5500 misclassified as RISKY in Day 305). Once SAFE is properly
represented and learnable, the model no longer over-predicts RISKY as a
fallback, and genuinely difficult RISKY frames (XD-Violence violent content
is more visually diverse -- movies, dashcam, UGC -- than UCF-Crime's
fixed-CCTV violent categories) are harder to classify correctly. NEUTRAL
recall improved sharply too (26.3% to 82.7%), consistent with the model's
decision boundaries becoming less RISKY-biased overall.

## Conclusion

The source-balanced sampling fix works exactly as diagnosed: it eliminates
the train/test domain-mismatch artifact (SAFE recall 22.5% to 64.5%,
consistent source ratios across all splits) and recovers real accuracy from
Day 305's regression (0.4950 to 0.5326, +0.0376). It does **not** beat Day
293's 0.5944 UCF-Crime-only baseline -- Day 293 remains the best real m3
checkpoint to date. After 5 total iterations on this model (Day 289, 291,
293, 301, 305) plus this one, the honest read is: UCF-Crime alone (Day 293)
still generalizes better on this held-out test distribution than the
combined UCF-Crime + XD-Violence dataset does, even with the allocation bug
fixed. This is a legitimate accuracy ceiling for the current
architecture/data combination, not a remaining implementation bug -- the
specific, predicted failure mode (anomalous SAFE-recall collapse from a
sampling artifact) was confirmed and fixed, and the result is still below
baseline. Day 293's checkpoint stays the shipped m3 model.
