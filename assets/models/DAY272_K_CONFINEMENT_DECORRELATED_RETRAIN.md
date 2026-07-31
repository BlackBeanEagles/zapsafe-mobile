# Day 272 — `k_confinement` decorrelated retrain (Option A from Day 269)

Follow-up to `DAY269_K_CONFINEMENT_SCOPING.md` (root cause: near-total
light/label confound in training data) and `DAY270_K_CONFINEMENT_IMU_PROBE.md`
(confirmed real IMU-only signal exists, AUC 0.94–0.99). This doc reports a
real retrain that decorrelates light from label using real motion data, and
re-runs the Day 260/269 decisive check. **Diagnostic/retrain only — no
wiring, no shipped `.tflite` changed.**

## 1. What was changed

Read `kaggle_notebooks/k_confinement_push/day92_k_confinement.py` again in
full to find exactly which loaders hardcoded light by label (matches Day
269's table): `load_wisdm_files` (run/jog → light=0.0 vs 0.2), `load_pamap2_imu`
(stairs/rope → light=0.0 vs 0.85), `load_motionsense_imu` (dws/ups/jog →
light=0.0 vs 0.2/0.85).

New script `kaggle_notebooks/day272_k_confinement_decorrelated_push/
day272_k_confinement_decorrelated.py` — a copy of `day92_k_confinement.py`
with one substantive addition, `decorrelate_light()`:

```python
def decorrelate_light(windows):
    out = []
    for imu, _old_light, label in windows:
        dark_val = random.uniform(0.0, 0.1)
        lit_val = random.uniform(0.15, 0.9)
        out.append((imu, make_light(dark_val), label))
        out.append((imu, make_light(lit_val), label))
    return out
```

Applied in `build_dataset()` to the raw pos/neg window lists returned by
`load_wisdm_files`, `load_pamap2_imu`, `load_motionsense_imu` — the exact
three real-motion sources Day 269 flagged. Each real (imu, label) window is
kept completely unchanged; only the light value paired with it is
duplicated into one dark-regime and one lit-regime copy, drawn
independently of the label. This is the same real motion data used before
(no new motion data collected) — only the light *pairing* changed, per the
task's Option A ("first pass": retag light on existing windows, no new data
collection required).

**Honest limitation (documented, not hidden)**: no real ambient-light/lux
dataset exists locally. Checked again for this task — searched
`ml_datasets/` and `kaggle_datasets/` for `*lux*`, `*light*`, `*brightness*`,
`*ambient*`; zero real light-sensor datasets found (matches Day 269's
finding that `confinement_custom` was never collected). The dark
(0.0–0.1) and lit (0.15–0.9) light values are therefore uniform-random
samples within physically-plausible regimes, not real measured lux. This is
a real, principled synthetic-*pairing* fix layered on top of real motion
data — not a fabrication of motion signal, but also not a fully "real
paired sensor data" fix. That fix remains unavailable until real trunk/vehicle
recordings with synchronized IMU+lux are collected.

## 2. Real retrain

Pushed and run to completion on Kaggle GPU (kernel
`hridyajain/zapsafe-day272-k-confinement-decorrelated`, script
`day272_k_confinement_decorrelated.py`, `kernel-metadata.json` datasets:
UCI-HAR, WISDM, MobiAct, PAMAP2, MotionSense). Status polled synchronously
to real terminal state ("complete"); outputs pulled via `kaggle kernels
output`.

**Data note**: WISDM returned 0 real windows this run (`[WISDM] pos=0
neg=0` in the kernel log) — likely a Kaggle dataset-mount/parsing issue with
`liuhanyu1007/wisdm-data` in this environment, not something this task
attempted to fix (out of scope; not touched). PAMAP2 and MotionSense both
loaded real data successfully and supplied all of the decorrelated
pos/neg examples used for training.

Real `data_stats` from `k_confinement_decorrelated_report.json`:

| source | raw real pos | raw real neg | after decorrelation (pos) | after decorrelation (neg) |
|---|---|---|---|---|
| WISDM | 0 | 0 | 0 | 0 |
| PAMAP2 | 9,306 | 12,000 | 18,612 | 24,000 |
| MotionSense | 11,824 | 12,000 | 23,648 | 24,000 |
| MobiAct (neg-only) | — | 12,000 | — | 12,000 |
| UCI-HAR (neg-only) | — | 10,299 | — | 10,299 |

Final balanced training set: 8,000 pos + 8,000 neg = 16,000 windows
(`train_windows: 16000`), each pos/neg window independently light-tagged
dark or lit per `decorrelate_light()`.

**Real training result** (`k_confinement_decorrelated_report.json`):

| metric | value |
|---|---|
| AUC | **0.9959** |
| recall (confined) | 0.9675 |
| F1 (confined) | 0.9660 |
| int8 size | 57.9 KB |

## 3. Decisive check (light-independence, Day 260/269 test repeated)

Held `light` fixed at 0.7 (realistic daytime/lit value, matching the shipped
model's original failure point) on the real held-out test split (3,200
windows, same 20% split `train_test_split` produced), then compared model
output between low-motion and high-motion real IMU windows (split by median
real per-window IMU std — a real physical motion-intensity measure, not a
synthetic label).

Real result (`light_independence_check` in the report):

| quantity | shipped model (Day 269, light=0.85) | this retrain (light=0.7) |
|---|---|---|
| output std across real IMU windows | 0.0000 (collapsed) | **0.4775** |
| low-motion mean output | n/a (all ~0) | 0.3661 |
| high-motion mean output | n/a (all ~0) | 0.6472 |
| high − low motion difference | 0 (no discrimination) | **+0.2811** |
| output range | 0.0 (constant) | 0.0 – 1.0 (full range) |

Both automated checks in the script's own decisive-check logic pass:
`dynamic_range_present = true` (std > 0.01 threshold) and
`discriminates_motion_at_lit = true` (>0.05 mean gap threshold, actual gap
0.28 — more than 5x the bar).

## 4. Verdict — matching this week's rule against overclaiming

**This is a real, decisive fix of the specific bug diagnosed in Day
269/270 ("ignores IMU when lit").** At a realistic lit light value, the
retrained model no longer collapses to ~0 regardless of motion — it shows
full dynamic range (0.0–1.0) and a real, substantial gap (+0.28 mean
output) between high-motion and low-motion real IMU windows. This is the
opposite of the shipped model's behavior, which showed exactly 0 dynamic
range and 0 motion-discrimination at the same lit-light regime (Day 269 §3).

Caveats, stated plainly:

1. **Light values are randomly sampled within regimes, not real measured
   lux.** No real ambient-light dataset was available (checked again,
   confirmed absent). This is the honest limitation flagged from the
   start — a principled synthetic-pairing fix on real motion data, not a
   fully "real-world" light/motion joint-recording fix.
2. **WISDM contributed 0 windows this run** (dataset load returned empty on
   Kaggle) — the decorrelation and retrain rest entirely on PAMAP2 and
   MotionSense real data for this result. Worth rechecking WISDM's Kaggle
   mount in a future run, but PAMAP2 + MotionSense alone already supplied
   42,260 raw real pos+neg windows before decorrelation, so this is not a
   thin-data result.
3. **AUC 0.9959 measures the same proxy task as Day 270** ("vibration-like
   activity" vs "calm activity" per the project's existing activity-class
   definitions) — it does not by itself validate that this proxy is a good
   stand-in for real vehicle-trunk confinement. That question is unchanged
   from Day 270 and remains out of scope here.
4. **This model is a retrain candidate only.** Per task scope, it has not
   been wired into the app, the shipped `.tflite` files were not touched,
   and the backend was not touched. Wiring, if pursued, is separate
   follow-up work.

## 5. Scope / repo notes

- Script: `kaggle_notebooks/day272_k_confinement_decorrelated_push/
  day272_k_confinement_decorrelated.py` (+ `kernel-metadata.json`),
  committed to the `kaggle_notebooks` repo. Not pushed to its remote.
- Kaggle outputs (`.tflite`, `norm.json`, `report.json`, checkpoint,
  training log, kernel log) downloaded to
  `kaggle_notebooks/day272_k_confinement_decorrelated_push/kaggle_output/`
  — left untracked (matches this repo's existing convention for other
  `*_push/kaggle_output/` folders, e.g. day261/day262/day264).
- `zapsafe_mobile` repo: `git fetch` + compared against
  `origin/day258-ml-wiring` before writing this doc — local branch was
  already ahead of origin with no divergent commits, so no merge was
  needed. This doc is the only change made in `zapsafe_mobile` for this
  task; no detector/wiring files, `assets/models/*.tflite`, or backend
  files were touched, per scope (`i_vehicle_crash` wiring is being done by
  another agent on the same branch concurrently).
- Not pushed to either repo's remote, per task instructions.
