# Day 284 — m9_dcs_fusion retrain investigation (result: not attempted, real data does not exist)

## What m9_dcs_fusion is

M9 is the fusion layer that combines the three real-time detection
component scores — **D**etection signals from scream (M1), motion/fall
(M2), and scene (M3) analysis — into a single risk score ("DCS" = the
scream/motion/scene combination this model fuses; the practical shorthand
used throughout `M9_STATUS.md` and the day108 training script). It is not
a sensor model itself; it is a small (28-dim input) classifier meant to sit
on top of M1/M2/M3's outputs and decide, from their co-occurrence pattern,
whether a real emergency is happening.

## Why v0/v1 failed their gate — confirmed, specific reason

- `m9_dcs_fusion_v0` (Day 108, `kaggle_notebooks/day108_int4_m9_push/day108_kaggle_output/saved/int4_m9/day108_production/m9/m9_dcs_fusion_v0_report.json`):
  `n_samples: 60000`, `val_auc: 1.0`, `production_gate_auc: 0.85`,
  **`production_pass: false`**. The AUC number itself clears the 0.85 gate —
  the failure is that the 60,000 training samples were **synthetic**
  (`calibration: "synthetic_v0"` per the threshold file), so `val_auc: 1.0`
  measures fit to a hand-authored fusion rule, not real-world accuracy. The
  gate is effectively "trained on real/live data," and v0 never had any.
- `m9_dcs_fusion_v1` (Day 176/177, `models/M9_STATUS.md`): same pattern —
  `val_auc: 1.0`, `production_pass: true` in its own JSON, but trained on
  only `n_samples: 4000` of `calibrated_synthetic_from_real_component_metrics`
  — synthetic sessions shaped by the real M1/M2/M3 validation AUCs (0.9101,
  0.98, 0.90) rather than arbitrary constants, which is a genuine
  improvement over v0 in realism of the input distribution, but is still not
  real user telemetry. This is why `PREPROCESSING_SPEC.md` overrides the
  file's own `production_pass: true` and says "do NOT ship" — the gate that
  matters (real correlated detection data) was never met by either version,
  regardless of what the JSON self-reports.

So the real, specific blocking metric is not an AUC number at all — both
runs cleared the numeric AUC gate on their own synthetic eval sets. The
actual gate that failed is **data provenance**: no version has ever been
trained on real, correlated `DetectionEvent` co-occurrences.

## Data needed vs. what's available now

M9 needs real sessions where M1 (scream), M2 (motion), and M3 (scene) fire
**together** on the same real-world event, so the fusion layer can learn
real co-occurrence patterns. This is fundamentally different from this
week's other retrains:

- MobiAct, real AudioSet subsets, NIGENS, ESC-50/FSD50K are all raw
  single-sensor datasets (accelerometer traces, audio clips) usable to
  train M1/M2/M3 individually. None of them contain synchronized
  multi-modal sessions correlated with ZapSafe's own three component
  models' outputs — that correlation only exists once a real device runs
  M1+M2+M3 together during a real event.
- The intended real source is explicit in `M9_STATUS.md`: `GET
  /api/v1/ml/dcs-fusion-export/?export_format=csv`, which exports real
  `DetectionEvent` history from beta users. As of Day 176 (and unchanged
  now, Day 284) that endpoint "returns nothing until real users generate
  detections" — no beta users have produced overlapping scream+motion+scene
  detections yet.
- The doc's own fallback option — "(b) running the three real `.tflite`
  files over a shared dataset to generate real correlated features for
  supervised fusion training" — was checked and is also not available: it
  requires a dataset with synchronized audio+IMU+scene-image streams for
  the same real events (e.g. a real person screaming while falling while a
  camera captures the scene), which none of MobiAct/AudioSet/NIGENS/
  ESC-50/FSD50K/UCI-HAR provide (they are single-modality). No such
  multi-modal synchronized corpus was found on Kaggle.

## Conclusion — no retrain attempted this session

This matches the standing rule from `k_confinement`'s never-collected
`confinement_custom` dataset: the blocker is real device-collected/live
telemetry that was never gathered, not a solvable data-sourcing gap. No
from-scratch training run was started, because there is no real dataset to
train it on — running one now would only produce a v2 with the same
synthetic-data problem as v0/v1, restating the existing failure under a new
version number.

**No code, tflite, wiring, or backend files were touched.** This document
is the only change in this branch/worktree
(`day284-m9-dcs-fusion-retrain`). `kaggle_notebooks` (standalone repo) has
no changes to commit since no retrain script was run.

## What would actually unblock this

Real beta usage generating overlapping scream+motion+scene
`DetectionEvent` rows, then `GET /api/v1/ml/dcs-fusion-export/` pulled and
used to train `kaggle_notebooks/m9_dcs_fusion.ipynb` per the promotion
steps already documented in `models/M9_STATUS.md` ("How v1→v2 gets
promoted once real telemetry exists"). Until then, `m9_dcs_fusion` stays
unshipped, correctly.
