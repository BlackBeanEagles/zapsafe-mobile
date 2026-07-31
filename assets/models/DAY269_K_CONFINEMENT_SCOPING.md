# Day 269 — `k_confinement` / `k_best` scoping: why does it gate so hard on `light`?

Follow-up to Day 260's Finding 3 (`DAY260_QUANTIZATION_ROOTCAUSE.md`), which
established that `k_confinement` is a real, non-degenerate model with a
second undocumented input (`light [1,32,1]`, a broadcast ambient-light
scalar) and that it collapses to ~0 for any real UCI-HAR IMU window when
`light` is set to the value that's actually true for that data (0.85,
"lit"), while showing real dynamic range (std 0.19–0.22) when `light=0.0`
("dark"). This doc is a SCOPING task only — investigation and options, no
retrain, nothing pushed to Kaggle.

## 1. Architecture (read `kaggle_notebooks/k_confinement_push/day92_k_confinement.py` end to end)

`build_model()` (lines 751–772):

```
imu_in  [1,128,6] -> Conv1D(32,5) -> MaxPool -> Conv1D(64,3) -> GlobalAveragePooling1D()   -> x  (64-dim)
light_in[1,32,1]  -> Dense(16, relu) -> Flatten()                                          -> l  (16*32=512-dim!)
h = Concatenate([x, l])   # 64 + 512 = 576-dim
h = Dense(64, relu) -> Dropout(0.3) -> Dense(32, relu) -> Dense(1, sigmoid)
```

This is late concatenation, not multiplicative gating or an explicit gate
mechanism — but note the light branch is `Dense(16)` applied per-timestep
to all 32 broadcast-identical light samples, then flattened to 512
dimensions, vs the IMU branch's pooled 64 dimensions. The light branch
enters the fusion layer with **8x more raw dimensions** than the IMU
branch, all of them carrying the exact same scalar value repeated 32 times
(since `make_light()` just broadcasts one number to length 32). This is a
real architectural amplification of the light signal's ability to dominate
the `Dense(64)` fusion layer's gradient, on top of whatever the data itself
teaches it. Loss is plain `binary_crossentropy`, no class weighting, no
per-branch regularization, no auxiliary IMU-only loss term.

## 2. Root cause: checked directly, confirmed — near-total light/label confound in training data construction

Traced every one of the 9 data-loading functions in `build_dataset()`
(lines 694–748) for what `light` value each assigns to label=1 vs label=0
windows:

| source | label=1 (confined) light | label=0 (normal) light |
|---|---|---|
| `load_wisdm_files` | **0.0** (run/jog) | 0.2 |
| `load_pamap2_imu` | **0.0** (stairs/rope, `slow_ids`) | 0.85 |
| `load_motionsense_imu` | **0.0** (dws/ups/jog) | 0.2 (pocket/bag) or 0.85 |
| `load_uci_har_csv`/`load_uci_har_inertial` | — (UCI-HAR is negatives-only) | 0.85, or 0.1/0.08 for LAYING |
| `load_mobiact_files` | — (negatives-only) | 0.3 |
| `load_esc50_quiet_imu_proxy` | — (negatives-only) | 0.9 |
| `load_audioset_quiet_imu_proxy` | — (negatives-only) | 0.75 |
| `load_custom_csv` (real trunk/confinement recordings) | variable, from real lux | variable, from real lux |
| `synth_pos_from_neg` (line 658–667) | **0.0**, hardcoded | n/a |
| `synth_fallback` positives (line 682–691) | **0.0**, hardcoded | n/a (negatives get 0.85) |

**Every single code path that produces a label=1 (confined) example sets
`light=0.0`, unconditionally.** There is no code path that ever generates a
positive example with any light value other than exactly 0.0. Conversely,
every negative-only path uses light values from 0.08 up to 0.9, and the one
path that could produce dark negatives (UCI-HAR LAYING → light=0.1/0.08)
is deliberately excluded from being an extreme case by
`windows_from_imu`'s own filter (line 127: `if label == 0 and light_val <
0.15 and std > 0.5: continue` — this suppresses high-vibration dark
negatives, not low-vibration ones, so a small number of low-motion dark
negatives near light=0.08–0.1 do exist, but they're rare and low-variance).

The only path that could break this confound is `load_custom_csv` (real
device recordings with real measured `lux`, hence real independent
light/label combinations) — but `k_confinement_norm.json`'s own
`"v1_note": "synthetic positives until custom_recordings/confinement/
uploaded"` and `"custom_recordings_pending": True` in the training config
confirm this data was never collected. **Checked directly**: no
`zapsafe-confinement-custom` / `confinement_custom` dataset exists anywhere
in `C:\Users\hridy\Desktop\zapsafe` (searched, zero matches) — so
`load_custom_csv()` returned empty in the actual training run that produced
the shipped `k_confinement_a_f32.tflite`. That means the one decorrelating
data source was 0 samples, not just underrepresented.

**Net effect: light and label are perfectly (or near-perfectly)
correlated in the actual training set.** `light == 0.0` implies label=1 in
100% of training examples; `light > ~0.15` implies label=0 in effectively
100% of training examples. A model minimizing binary cross-entropy has no
incentive to ever learn to read the IMU branch — reading `light` alone gets
it to ~0 training loss. This is the same category of bug as this week's
`m2_motion_b` column-index bug and `s_crowd_panic`'s wrong label IDs: **the
actual root cause is a simple, checkable data-construction bug (a
near-total feature/label shortcut), not something inherently wrong with the
combine-two-modalities architecture.** The architecture's disproportionate
light-branch width (512 vs 64 dims, section 1) is a secondary amplifier,
not the primary cause — even a narrower light branch would learn the same
shortcut given a perfectly correlated feature.

## 3. Diagnostic run today (real data, fp32 checkpoint, no retrain)

Extended Day 260's two-point light sweep (light=0.85 and light=0.0) to a
9-point sweep across realistic intermediate values, using the same real
100 UCI-HAR test-split IMU windows as Day 260, plus (for contrast) 20
synthetic high-vibration "confinement-like" IMU windows built from the
training script's own `synth_fallback()` positive-generation formula
(script: scratchpad `day269_light_sweep.py`, fp32 checkpoint
`kaggle_notebooks/day102_sweep_push/.../sweep/k/a/k_confinement_a_f32.tflite`):

```
light | real UCI-HAR IMU (ordinary daily activity)      | synthetic high-vibration "confinement" IMU
 0.00 | std=0.2240 mean=0.7403 min=0.44 max=0.999         | std=0.0155 mean=0.8746
 0.05 | std=0.3686 mean=0.3832 min=0.04 max=0.993         | std=0.0287 mean=0.2824
 0.10 | std=0.2131 mean=0.1285 min=0.003 max=0.893        | std=0.0030 mean=0.0216
 0.15 | std=0.0552 mean=0.0193 min=0.0003 max=0.317       | std=0.0002 mean=0.0013
 0.20 | std=0.0042 mean=0.0013 min=0.0000 max=0.025       | std=0.0000 mean=0.0001
 0.30 | std=0.0000 mean=0.0000                            | std=0.0000 mean=0.0000
 0.50–0.85 | std=0.0000 mean=0.0000                       | std=0.0000 mean=0.0000
```

Two findings from this:

1. **The transition is a sharp step, right where the training data's own
   light-value clustering says it should be.** Output collapses to exactly
   0 by light=0.3, with essentially all of the transition happening between
   0.10 and 0.20 — precisely the empty gap in the training data's light
   histogram (positives always exactly 0.0; negatives almost always ≥0.2,
   with a thin low-motion tail near 0.08–0.1). This is strong direct
   evidence for the shortcut hypothesis in section 2: the model built a
   step function on `light` with a decision boundary sitting exactly in the
   data's own light-value gap, not a smooth function that also depends on
   IMU content.
2. **At light=0 (dark), ordinary daily-activity IMU (real UCI-HAR walking
   etc.) scores just as high on average (mean 0.74) as synthetic
   high-vibration "confinement" IMU (mean 0.87)** — if the model were truly
   combining both signals, ordinary calm IMU at light=0 should score much
   lower than vibration-heavy IMU. It doesn't, decisively. The dynamic
   range Day 260 found at light=0 (std 0.19–0.22) is not "IMU signal coming
   through" in the sense of discriminating vibration levels — it's noise
   scattered around the light=0 regime (visible in how std actually peaks
   at light=0.05, off the exact confinement-proxy value, not at light=0.0
   itself). **This model has not been shown to have any real IMU-driven
   discrimination ability** — everything observed so far is consistent with
   "reads light, ignores IMU content."

## 4. Options for the project owner

### Option A — Decorrelate light from label in training data (data fix)
Add real dark-negative examples (person doing ordinary calm activity in a
dark room/pocket/bag, not confined) and real lit-positive examples
(genuine confinement scenario that happens to have some ambient light —
e.g., trunk with a gap, dim vehicle interior) so `light` stops perfectly
predicting the label on its own.
- **Effort**: Medium-high. Requires either (a) real device recordings
  (accelerometer/gyro + lux) covering both quadrants — this is exactly the
  `confinement_custom` dataset the original script anticipated
  (`custom_recordings_pending: True`) and that was never collected, or (b)
  synthetic dark-negative augmentation added to existing negative sources
  (e.g., take `load_uci_har_all()`'s ordinary-activity windows and re-tag a
  fraction of them with light values drawn from 0.0–0.3 instead of always
  ≥0.85, and take some existing vibration-heavy PAMAP2/MotionSense-style
  "activity" windows and pair them with light≥0.5 as lit-positives if any
  physically plausible ones exist).
- **Data availability**: dark negatives are cheap to synthesize from
  existing negative sources (just retag light on existing calm windows —
  no new data collection needed for a first pass). Lit-positives are
  harder — real confinement scenarios are almost definitionally dark, so
  finding physically real "lit confinement" positives may require
  redefining what counts as a positive, or accepting a smaller synthetic
  set. Real custom trunk/vehicle recordings (accelerometer + gyro + lux,
  varied lighting) would be the highest-quality fix but require actual
  data collection, not just re-labeling existing sources.
- **Risk**: Requires a retrain to validate — cannot be checked without one.

### Option B — Architectural: shrink/normalize the light branch's influence
Change `Dense(16)(light_in)` + `Flatten()` (512-dim) to something that
doesn't give light 8x the fusion-layer footprint of the pooled IMU branch
— e.g., `GlobalAveragePooling1D()` the light branch down to a single
scalar (or small vector) before concatenation, matching its true
information content (it's one broadcast number, not 32 independent
samples), or L2-normalize/scale both branches before concatenation.
- **Effort**: Low to implement (small code change to `build_model()`), but
  the diagnosis in section 2 says the primary cause is the data confound,
  not branch width — this alone probably would not fix the underlying
  shortcut-learning if light and label remain near-perfectly correlated in
  training data. Best paired with Option A, not a substitute for it.
- **Data availability**: n/a (code-only change), but still requires a
  retrain + real-data eval to confirm it changes anything.
- **Risk**: Could reduce the light branch's legitimate contribution too
  much if not paired with real light/label decorrelation — light IS a
  real, load-bearing physical feature for actual confinement (dark is
  genuinely part of the detection concept, per the model's own docstring),
  so the goal isn't to remove light's influence, just make it not be a
  100%-sufficient shortcut.

### Option C — Test IMU-alone signal via a fresh probe classifier (cheap, diagnostic-only, no retrain of the shipped model)
Train a small separate probe (e.g., a plain sklearn/logistic-regression or
tiny 1D-CNN) on IMU-only features, using the *same* pos/neg windows
`day92_k_confinement.py` would build, with light dropped entirely, to
directly measure whether the IMU branch alone carries any separable signal
for the "confined" concept as currently defined (i.e., "vehicle-like
vibration" vs "calm"). This answers whether the underlying IMU concept is
learnable at all, independent of the light shortcut.
- **Effort**: Low — a few hours, uses existing loader functions from
  `day92_k_confinement.py` (`load_wisdm_files`, `load_pamap2_imu`, etc.)
  directly, no Kaggle push needed, can run locally or in a notebook.
- **Data availability**: Full — all data sources `day92_k_confinement.py`
  already uses are locally cached per Day 260's dataset table.
- **Risk**: none — this is pure measurement, doesn't touch the shipped
  model. Should probably be done **before** committing effort to Option A,
  since it answers a prerequisite question: is "vehicle-vibration vs calm"
  actually separable from IMU alone at all (the positive class's own
  vibration threshold, `std >= 0.2` in `windows_from_imu`, is somewhat
  low and may itself overlap with vigorous ordinary activity like
  jogging/stairs — worth checking if IMU-only separability is even good in
  principle before investing in a data-collection fix).

## 5. Decision needed from project owner

Three real options, not mutually exclusive — B and C in particular are
cheap enough to combine with A:

1. **Option A (decorrelate training data)** — the option that fixes the
   confirmed root cause directly. Medium-high effort; a first pass (retag
   existing negatives with dark light values) needs no new data collection,
   but a fully convincing fix likely needs real trunk/vehicle recordings
   that don't currently exist (`confinement_custom` dataset was never
   collected). Requires a retrain to validate.
2. **Option B (shrink light branch's fusion-layer footprint)** — cheap
   code change, but per section 2/3 the primary cause is the data confound,
   not branch width, so B alone is unlikely to fix this; best done
   alongside A, not instead of it.
3. **Option C (cheap IMU-only probe, no retrain of the shipped model)** —
   lowest effort, pure measurement, answers whether the underlying
   "vibration vs calm" concept is learnable from IMU at all before
   investing further. Recommended as the immediate next step regardless of
   which of A/B gets chosen, since it's cheap and de-risks the rest.

No retrain and no Kaggle push were performed for this task, per scope.
