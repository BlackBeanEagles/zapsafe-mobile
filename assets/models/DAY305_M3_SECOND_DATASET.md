# Day 305 -- M3 danger classifier: second real dataset (XD-Violence + UCF-Crime)

## Context

Day 301 (`DAY301_M3_ITERATION4.md`) concluded UCF-Crime alone had hit a real
ceiling: Day 293's 0.5944 test accuracy (iteration 3) was not beaten by more
UCF-Crime volume (iteration 2, 0.4786) or a bigger backbone (iteration 4).
Day 301 explicitly recommended a net-new data source. This iteration searches
for and tests one.

## Dataset search (real platforms, real queries)

| Candidate | Real? | License | Verdict |
|---|---|---|---|
| **XD-Violence** (Wu et al., ECCV 2020) -- https://roc-ng.github.io/XD-Violence/ | Yes -- 4,754 untrimmed videos, movies/dashcam/UGC, 217 hrs, 6 violent classes + Normal, weak (video-level) labels | MIT (per Kaggle mirror `bypktt/xd-violence`, "Single-Label Edition", 4,463 videos, single label/video, 76GB, usability 0.875) | **USED** -- genuinely different camera/scene/production diversity vs UCF-Crime's fixed-CCTV footage |
| ShanghaiTech Campus | Yes -- on Kaggle (`nikanvasei/shanghaitech-campus-dataset`, `ravikagglex/shanghaitech-anomaly-detection`) | dataset-specific, not checked further | **REJECTED** -- frame/pixel-level "anomaly vs normal" on pedestrian-walkway footage (bikes/carts on footpaths), not violence/danger-relevant content. Forcing this into SAFE/NEUTRAL/RISKY would be a bad mapping, same as day289's discipline against forcing incompatible labels. |
| CUHK Avenue | Yes -- widely mirrored on Kaggle | dataset-specific | **REJECTED** -- same issue as ShanghaiTech: low-res campus walkway anomalies (jaywalking, skateboards), not human-safety relevant |
| UCSD Ped1/Ped2 | Yes -- on Kaggle (`karthiknm1/ucsd-anomaly-detection-dataset`, `orvile/ucsd-anomaly-dataset`) | dataset-specific | **REJECTED** -- same issue: grayscale pedestrian-walkway anomaly footage, no danger/violence semantics |

XD-Violence Kaggle mirrors checked directly via `kaggle datasets list -s
xd-violence`: `bypktt/xd-violence` (76GB, 3013 downloads, usability 0.875,
MIT), plus several others (`magicearth25/xd-violence`,
`smmohiuddinkhanshiam/xd-violence`, `hihnguynth/xd-violence`, region-split
mirrors). Used `bypktt/xd-violence` -- Single-Label Edition, directory
structure `{train,test}/{Abuse,CarAccident,Explosion,Fighting,Normal,Riot,
Shooting}/*.mp4`, raw mp4 (not pre-extracted frames like the UCF-Crime
mount), so this iteration extracts frames with OpenCV at decode time.

## Label mapping (documented judgment call, same discipline as Day 289)

```
XD-Violence 'Normal'                                          -> SAFE (0)
Abuse / CarAccident / Explosion / Fighting / Riot / Shooting   -> RISKY (2)
```

XD-Violence has **no** category corresponding to UCF-Crime's NEUTRAL bucket
(Arrest/RoadAccidents/Shoplifting/Stealing -- ambiguous-but-not-violent).
Every XD-Violence non-Normal class is explicitly one of the dataset's own
"violent/anomalous" categories, so forcing e.g. CarAccident into NEUTRAL
would contradict the source's own framing. NEUTRAL therefore stayed
UCF-Crime-only this iteration -- a deliberate, documented omission, not an
oversight.

## Method

Combined dataset, video-level 70/15/15 split (seed=42) applied independently
to each source, then merged by class. Sampling strategy **unchanged from
Day 293** (the one that produced 0.5944): `max_frames_per_video=12`,
`max_per_class=5500`, same MobileNetV3Small architecture, same two-phase
fine-tune recipe (frozen-base head, then unfreeze last 15 base layers at
lr=3e-6 with BatchNorm frozen, EarlyStopping safety guard that reverts to
phase-1 weights if fine-tuning regresses val_accuracy).

Script: `kaggle_notebooks/day305_m3_second_dataset/day305_m3_ucf_xdv_v5.py`
Kernel: `hridyajain/zapsafe-day305-m3-second-dataset` (real Kaggle run,
GPU, dataset_sources: `odins0n/ucf-crime-dataset`, `bypktt/xd-violence`)

## Real result

| | Day 289 | Day 291 | **Day 293 (baseline)** | Day 301 | **Day 305 (this run)** |
|---|---|---|---|---|---|
| Test accuracy | 0.5018 | 0.4786 | **0.5944** | (no gain, per report) | **0.4950** |

Full metrics (from `m3_ucf_xdv_report_v5.json`):
- accuracy: 0.4950
- SAFE f1: 0.3234, NEUTRAL f1: 0.2551, RISKY f1: 0.6174
- RISKY recall: 0.8212
- fine_tune_kept: **false** (phase 2 val_accuracy 0.4571 < phase 1's 0.4995 --
  fine-tuning regressed and the safety guard correctly reverted to
  phase-1/frozen-base weights)
- train_sec: 1281.8

Confusion matrix (rows=true, cols=pred, SAFE/NEUTRAL/RISKY):
```
           pred SAFE  pred NEUTRAL  pred RISKY
true SAFE      1237        189         4074      (recall 22.5%)
true NEUTRAL    344        170          133      (recall 26.3%)
true RISKY      570        327         4119      (recall 82.1%, matches reported risky_recall)
```
Overall: (1237+170+4119)/11163 = 0.4950 -- matches reported accuracy.

## Diagnosis: XD-Violence did not beat the baseline, and there's a real, identifiable reason

Looking at `source_counts` in the report: for the SAFE class, **train got
zero XD-Violence frames** (`train_0_xdv` absent/0) because the sampling loop
processes UCF-Crime's `NormalVideos` first and it alone fills the
`max_per_class=5500` train cap before XD-Violence's `Normal` videos are ever
considered. But val/test SAFE frames are majority XD-Violence
(`val_0_xdv=3796` of 5500, `test_0_xdv=3784` of 5500 -- roughly 69% of each).

That means the model was trained on SAFE = 100% UCF-Crime CCTV footage, but
evaluated on SAFE = ~69% XD-Violence movie/dashcam footage it never saw
during training. This is a genuine train/test domain mismatch introduced by
the greedy per-class cap allocation order (UCF assigned before XDV in the
source loop), not a flaw in the video-diversity sampling philosophy itself.
It explains the pattern directly: SAFE recall collapsed to 22.5%, with most
SAFE frames misclassified as RISKY (4074 of 5500) -- consistent with an
out-of-distribution input defaulting toward the class the model is least
uncertain about. RISKY recall stayed high (82.1%) because RISKY's train set
did include XDV frames (`train_2_xdv=460`), so RISKY generalized reasonably;
SAFE's total exclusion from XDV training data is the specific, identifiable
cause of the regression.

This is a real, actionable failure mode, not a dead end on XD-Violence
itself: a source-balanced cap (reserve train quota per source before
capping per class, or interleave sources before applying `max_per_class`)
would need to be tried before concluding XD-Violence itself doesn't help.
That is a candidate for a future iteration; it was not attempted here to
keep this iteration a clean, single-variable test with Day 293's stated
"unchanged" sampling code path.

## Conclusion

XD-Violence is a real, licensed (MIT), accessible, and semantically
compatible second dataset for RISKY/SAFE (not NEUTRAL). Combining it with
UCF-Crime using Day 293's exact sampling code, unmodified, produced a real
regression to 0.4950 test accuracy (vs 0.5944 baseline) -- **not** because
the new data source lacks signal, but because of an identified,
reproducible artifact in how per-class frame caps were allocated across two
sources (UCF-Crime consumed the entire SAFE train quota before XD-Violence's
Normal videos were ever sampled). Day 293's 0.5944 UCF-Crime-only checkpoint
remains the best real result to date. A follow-up iteration with
source-balanced per-class caps is the concrete next step, not yet run.
