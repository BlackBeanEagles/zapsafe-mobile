# Day 270 — `k_confinement` Option C: IMU-only probe (real data, no retrain)

Follow-up to `DAY269_K_CONFINEMENT_SCOPING.md`. Project owner approved
proceeding with **Option C** (cheap IMU-only diagnostic probe, no retrain of
the shipped model). This doc reports the real result.

## Question being answered

With `light` dropped entirely, is there real separable signal in IMU alone
between the activity classes `day92_k_confinement.py` treats as
"confinement-like vibration" (positive) vs "calm/normal" (negative)? This is
a prerequisite check before investing in Option A (real data collection to
decorrelate light from label).

## Method

Standalone script (not committed — run from scratchpad, no dependency on the
shipped model or its checkpoint): `day270_imu_probe.py`. Uses the exact same
activity-class definitions as `day92_k_confinement.py`'s loaders, applied to
the same local real datasets used all week (`ml_datasets/motion/`), with
`light` never constructed or used as a feature at all:

| source | positive class (label=1) | negative class (label=0) |
|---|---|---|
| WISDM (`DS15_WISDM`, raw phone accel+gyro) | jogging (activity code `B`, per `activity_key.txt`) | walking (`A`), sitting (`D`), standing (`E`) |
| PAMAP2 (`DS14_PAMAP2`, Protocol/*.dat, chest IMU cols 20–26) | `slow_ids={12,13,24}` — ascending stairs, descending stairs, rope jumping | `norm_ids={1,2,3,4,5}` — lying, sitting, standing, walking, running (same id sets as `load_pamap2_imu`) |
| MotionSense (`DS12_MotionSense`, `A_DeviceMotion_data.zip`) | `dws`, `ups`, `jog` folders | `wlk`, `std`, `sit` folders |

Windowing matches `windows_from_imu()`: 128-sample windows, 64-sample hop,
positive windows dropped if `std(accel_xyz) < 0.2` (same vibration-amplitude
gate the shipped model's training data used). The light-dependent negative
filter (`light_val < 0.15 and std > 0.5`) was dropped since this probe has no
light input at all.

Each window reduced to 39 hand-crafted features (per-axis mean/std/min/max/
RMS/mean-abs-jerk over 6 IMU channels, plus accel-magnitude mean/std/max) —
appropriate for a fast diagnostic, not the shipped model's raw-window CNN
path. Two classifiers trained on an 80/20 stratified real train/test split
(`random_state=42`, no synthetic data anywhere): plain `LogisticRegression`
and a 200-tree `RandomForestClassifier`.

## Real data volumes

| source | pos windows | neg windows |
|---|---|---|
| WISDM | 4,103 | 12,465 |
| PAMAP2 | 4,653 | 7,013 |
| MotionSense | 5,912 | 15,212 |
| **Total** | **14,668** | **34,690** |

Train: 39,486 windows. Test (held out, real, stratified): 9,872 windows,
29.7% positive.

## Real results

| model | AUC | Accuracy |
|---|---|---|
| Logistic Regression | **0.9424** | 0.8698 |
| Random Forest | **0.9928** | 0.9614 |

Both real numbers, computed via `sklearn.metrics.roc_auc_score` /
`accuracy_score` on the held-out real test split. No fabricated or
placeholder values.

## Interpretation

This is a strong, decisive result — well above the `>0.75` threshold the
scoping doc set as "meaningfully above chance." Even a plain linear
classifier on simple summary statistics separates "vibration-like" activity
(jogging, stairs, rope jumping, dws/ups/jog) from "calm" activity (walking,
sitting, standing, lying) almost perfectly from IMU alone — the RandomForest
result (AUC 0.993) shows the classes are close to linearly-plus-trivially
separable once light is out of the picture.

**This directly answers the Day 269 prerequisite question**: the underlying
"vibration vs calm" concept, as currently defined by this project's own
activity-class choices, **is** learnable from IMU alone. The premise itself
("confinement = vehicle-like vibration") is not the problem — the shipped
model's failure to use IMU is a data-construction bug (the light/label
confound documented in Day 269), not evidence the physical concept is
unlearnable.

Caveat: this measures separability between the *proxy activity classes* the
project has been using (jogging/stairs/rope-jump vs walking/sitting/
standing), not real confinement vs non-confinement in a vehicle. It confirms
the IMU signal exists for the proxy task the shipped model was trained on —
it does not by itself validate that "jogging-like vibration" is a good stand-in
for "vehicle trunk vibration" (that's a separate, orthogonal question not in
scope for Option C).

## Recommendation

**Option A (real data collection to decorrelate light from label) is worth
pursuing.** The IMU-only signal is real and strong (AUC 0.94–0.99), so a
retrain with light decorrelated from label has a clear real signal to
recover — this was the prerequisite Option C was meant to check, and it
passes decisively. Option B (shrinking the light branch's fusion-layer
footprint) remains a reasonable complementary code change but, per Day 269,
should be paired with A rather than substituted for it.

## Scope notes

- No retrain of the shipped `k_confinement` model. No Kaggle push — ran
  entirely locally on CPU in under 2 minutes.
- Did not touch `day92_k_confinement.py`, the shipped `.tflite` checkpoints,
  detector/wiring files, or the backend.
- Probe script and raw JSON results kept in scratchpad (not committed) since
  they were a one-off local diagnostic, not a project artifact; the real
  numbers are transcribed verbatim above.
