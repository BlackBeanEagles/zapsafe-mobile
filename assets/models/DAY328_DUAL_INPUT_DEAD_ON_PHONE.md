# Day 328 — all four "UNVERIFIED" models are non-functional on a real phone

The gate has been printing `UNVERIFIED` for `i_vehicle_crash`,
`k_confinement_decorrelated`, `s_crowd_panic` and `m2_motion_b_retrain`
because it had no dual-input fixture. The plan was to build those fixtures.

**Building them would have been the wrong thing to do.** A fixture drawn
from each model's training domain reports a healthy number for all three
dual-input models — measured this session: **1.0000**, **0.9959** (Day 272's
own figure) and **1.0000**. All three are nonetheless incapable of producing
a usable detection on a phone. The fixture would have turned `UNVERIFIED`
into `ok` and closed the item with nothing fixed.

`UNVERIFIED` was not the problem. It was the honest label.

## Measured, per model

Reproduce with `tools/day328_dual_input_probe/`. Every number below is from
the **shipped asset** in `assets/models/`, real local datasets, no synthetic
probing.

### `s_crowd_panic` — the label is data provenance, not crowd panic

| regime | AUC | pos mean | neg mean |
|---|---|---|---|
| A  real panic mel + `synth_push_imu` **vs** zero mel + PAMAP2`[20:26]` | **1.0000** | 0.5226 | 0.2760 |
| B  real panic audio **vs** real calm audio, real acc+gyro held constant | **0.6062** | 0.5419 | 0.5371 |
| C  **mel held byte-identical**, synth IMU vs PAMAP2`[20:26]` | **1.0000** | 0.5430 | 0.2760 |

Regime C is the proof. With the audio input *bit-identical between classes*
the model still separates them perfectly, so the whole of regime A is the
IMU branch recognising **which dataset the window came from**. Two
independent shortcuts were built into the training set by
`day95_s_crowd_panic.py`:

1. **`load_pamap2_walk_neg` pairs every negative with digital silence** —
   `silent = audio_to_mel(np.zeros(int(DURATION * SR)))`. Verified: that mel
   is *exactly* all-zero, because `power_to_db(ref=np.max)` of a zero signal
   gives `-100 - (-100) = 0`. PAMAP2 is ~48% of the negative pool. "Is the
   mel all zeros" separates the classes and is not panic detection.
2. **`df.iloc[:, 20:26]` is not accelerometer + gyroscope.** PAMAP2's chest
   IMU block starts at column 20, so that slice is
   `[temperature, acc16g_x, acc16g_y, acc16g_z, acc6g_x, acc6g_y]`.
   Measured on `subject101.dat`:

   ```
   ch0 (col 20): mean=  35.345  std=1.394   <- chest skin temperature, degC
   ch1 (col 21): mean=   0.294  std=1.782
   ch2 (col 22): mean=   8.365  std=4.880
   ch3 (col 23): mean=  -2.473  std=4.076
   ch4 (col 24): mean=   0.139  std=1.771
   ch5 (col 25): mean=   8.375  std=4.846
   corr(ch1,ch4) = 0.97153      corr(ch2,ch5) = 0.96896
   ```

   One thermometer, three accelerometer axes, two of them duplicated
   (acc16g and acc6g measure the same axis). **Zero gyroscope channels** —
   the real chest gyro is at columns 27–29 and is never read.

   The synthetic positives (`synth_push_imu`) are `np.zeros` plus a
   sinusoid, so channel 0 is ~0 for positives and ~35 for negatives. That is
   a perfectly separating feature with no physical relationship to crowd
   panic, and it is why `s_crowd_panic_norm.json` carries
   `imu_mean[0] = 8.83` with `imu_std[0] = 15.9` — the signature of a
   bimodal mixture of ~0 and ~35, not a sensor statistic.

**On a phone** (`crowd_panic_pipeline.dart` feeds `[e.x, e.y, e.z, gx, gy,
gz]`, so channel 0 is accelerometer X at ~0) the score pins to ~0.54:

* separation between screaming and calm is **0.0048**
* `kDefaultThreshold = 0.5`, so `isPanic` is true for **100%** of panic
  windows and **97.5%** of calm windows — the label is noise
* the ceiling on realistic input is **0.5762**, below
  `InferenceResult.confidenceThreshold = 0.7`, so `_submit` never fires

Net: it runs a mel + an IMU inference on every window forever, mislabels
~98% of them "panic", and can never emit a detection event. The 0.7 gate is
the only reason a stream of false `crowd_panic` danger events is not already
reaching `POST /api/v1/ml/detection-events/`. That is luck, not design.

### `k_confinement_decorrelated` — same temperature channel, and dead

`day272_k_confinement_decorrelated.py:421` uses the **identical**
`df.iloc[:, 20:26]` slice, so channel 0 is skin temperature here too. Its
inlined `kImuMean[0] = 18.83` with `kImuStd[0] = 33.07` is the same bimodal
signature — and a *sustained* 18.8 m/s² (1.9 g) is physically impossible for
a carried phone, which is the tell.

With real acc+gyro held identical and only the light scalar varied:

| light | output mean | fires >= 0.5 |
|---|---|---|
| 0.00 | 0.0186 | 0/40 |
| 0.05 | 0.0186 | 0/40 |
| 0.20 | 0.0186 | 0/40 |
| 0.50 | 0.0186 | 0/40 |
| 0.85 | 0.0127 | 0/40 |

* `AUC(phone-real IMU vs training-slice IMU) = 0.0063` at light 0.0 and
  `0.0044` at 0.85. Near-zero AUC is near-*perfect separation, inverted*:
  the model scores temperature-contaminated windows high and realistic phone
  windows at floor. Direct confirmation it keys on channel 0.
* `AUC(dark vs lit, same real IMU) = 0.5875` — the light input, the thing
  Day 272 existed to fix, barely matters.

On a phone it outputs ~0.019 and **never fires at any light level**. Day
272's 0.9959 is the same provenance artifact.

Separately, and still unfixed: `synth_pos_from_neg` (600 positives, all
`make_light(0.0)`) is called at line **796**, *after* all three
`decorrelate_light()` calls at lines 752/760/764. It is never decorrelated,
so the exact light/label confound the retrain was written to remove survives
in those samples whenever the real-positive count falls under 100.

### `i_vehicle_crash` — clean design, killed by units and int8

Its training script is **structurally sound** and worth saying so:
`load_uci_har` reads real 6-axis UCI-HAR (`total_acc_*` *and*
`body_gyro_*`), and lines 346–347 derive both classes from the *same* real
window — `neg = normalize_imu(w)`, `pos = inject_crash_spike(w)`. There is
no provenance shortcut. Two other things kill it.

**1. The output has collapsed — and Day 330 corrects the cause below.**

> **Correction (Day 330).** This section blamed int8 quantization. That was
> wrong. The f32 twin was measured afterwards and is *also* flat: over 80
> unrelated real audio clips its entire output range is **[0.4945, 0.5040]**,
> and its audio branch scores **AUC 0.4738** — below chance. int8 faithfully
> encodes a parent that had already collapsed, so re-exporting fixes nothing.
> The model needs a retrain. See
> `DAY330_VEHICLE_CRASH_COLLAPSED_AT_SOURCE.md`.

| regime | AUC | pos mean | neg mean | separation |
|---|---|---|---|---|
| A  UCI-HAR in **g** (training units) | **1.0000** | 0.5039 | 0.5000 | **0.0039** |
| B  same windows in **m/s²** (app units) | **0.5000** | 0.5001 | 0.5001 | 0.0000 |

The output quantization scale is `0.00390625`. Regime A's separation is
`0.5039 - 0.5000 = 0.0039` — **exactly one LSB**. The AUC of 1.0000 is not
strength, it is a consistent 1-LSB ordering; the model emits two adjacent
int8 values. This is the same int8 collapse already found in `mg_gunshot`,
`m1` and `m2`, and it is why Day 271's "0.8733 int8" should not have been
read as usable.

**2. `g` versus `m/s²`.** UCI-HAR inertial signals are in standard gravity
units; `vehicle_crash_pipeline.dart:149` feeds raw `sensors_plus` values,
which are m/s². `normalize_imu` is `clip(w, -8, 8) / 8`, so the same motion
arrives **8x larger and clipped**:

```
g (training)   |value| == 1.0 (saturated) in   0.0% of the 768 floats; mean|v| = 0.0353
m/s^2 (app)    |value| == 1.0 (saturated) in  16.7% of the 768 floats; mean|v| = 0.3099
```

Training never saw a saturated accelerometer channel. The app saturates one
sixth of every window before the model sees it, and regime B shows the
result: AUC 0.5000, no discrimination whatsoever.

### `m2_motion_b_retrain` — the same unit bug, by shared code

`vehicle_crash_detector.dart` documents its own normalisation as
"bit-for-bit the same formula as `MotionDetectorB.normalise`", and
`day91_i_vehicle_crash.py`'s `normalize_imu` is the function both use. So
`m2_motion_b_retrain` inherits the `g`-versus-`m/s²` mismatch above. This is
independent confirmation of the concern already recorded against it — that
its SisFall training domain sits far outside real phone units — and it is
why no honest fixture existed for it. `UNVERIFIED` remains correct; the
reason is now known rather than suspected.

## What changed in this commit

1. **The three pipelines are disabled** in `live_detection_providers.dart`
   behind `kDualInputModelsDisabled`, with this document cited at the call
   site. They cost a continuous mel + IMU inference each and cannot emit a
   detection, so disabling them is a pure win: battery back, no misleading
   `isPanic`/`isConfined`/`isCrash` labels, and no risk that a future
   threshold change turns the 97.5%-false `panic` label into submitted
   events. The detector and pipeline classes, their tests and their wiring
   are left intact so a retrained asset drops straight back in.
2. **The gate fails instead of shrugging.** `verify_shipped_models.py` grows
   a `KNOWN_BROKEN` table carrying the measured evidence, and these four now
   report `BROKEN` and exit non-zero rather than `UNVERIFIED`.
3. **`tools/day328_dual_input_probe/`** holds the three probes so every
   number here is reproducible rather than asserted.

## What this does NOT do

**No retraining.** Fixing `s_crowd_panic` and `k_confinement` needs the
training data rebuilt, not the model re-fit: negatives must stop being
paired with digital silence, PAMAP2 must be read at columns 21–23 and 27–29
for real acc+gyro, and positives must come from the same distribution as
negatives. `i_vehicle_crash` needs a float16 export (int8 has now cost this
project five models) and its input contract fixed to one unit system —
either divide the sensor stream by 9.80665 in the pipeline or retrain in
m/s². Both are real work with a real dataset question behind them (no public
dataset pairs a real crowd crush with synchronized phone IMU), and neither
belongs in the change that discovered the problem.

**The honest launch position is that ZapSafe has three working detectors —
`motion_fall_v2` (0.999), `scream_classifier_v3` (0.839) and
`m5_vocal_stress_v2` (0.850) — not seven.**
