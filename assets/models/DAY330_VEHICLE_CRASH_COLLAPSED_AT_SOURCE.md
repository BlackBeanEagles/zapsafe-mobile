# Day 330 — `i_vehicle_crash`: float16 does not fix it, and neither do units

The task was to fix `i_vehicle_crash` by re-exporting it away from int8 and
reconciling its unit system. Measuring the float32 twin first shows that
**neither fix helps, because Day 328 blamed the wrong thing.**

## The correction

Day 328 recorded the defect as "int8 output collapsed to one quantization
step". That was wrong, and the error mattered: it implied a re-export would
fix the model, which is why this was scheduled as an export task.

There is no Keras or SavedModel artifact left anywhere on disk — only
TFLite — so a genuine float16 *conversion* was never available. But the f32
twin does survive, in 47 byte-identical copies, md5
`67be55d2d72dd4a6e631f3fdd6ba33f3`, matching the md5 Day 271 recorded. f32
carries no quantization loss at all, so it is a strictly better test than
float16 would have been.

Measured against both shipped twins, real UCI-HAR 6-axis and real ESC-50
audio:

| model | regime | AUC | pos mean | neg mean | separation | distinct outputs |
|---|---|---|---|---|---|---|
| int8 | IMU in **g** | 0.9590 | 0.5036 | 0.4999 | +0.0036 | **3** |
| int8 | IMU in **m/s²** | 0.5167 | 0.5005 | 0.5003 | +0.0001 | **2** |
| f32  | IMU in **g** | 0.9236 | 0.5024 | 0.5013 | **+0.0012** | 110 |
| f32  | IMU in **m/s²** | 0.5214 | 0.5078 | 0.5078 | +0.0000 | 116 |

The f32 row is the answer. It emits 110 *distinct* values, so it is not
quantization-limited in any way — and its class separation is **0.0012**,
three times smaller than the int8 twin's. The int8 export was not destroying
signal. It was faithfully encoding a parent that had already collapsed.

## The control that settles it

The table above varies only the IMU branch, with the mel held constant. The
missing control is the opposite: hold the IMU at one real calm window and
vary the audio across 80 unrelated real ESC-50 clips.

```
int8  AUC(crash-audio vs quiet-audio) = 0.4769   full output range [0.4961, 0.5039]
f32   AUC(crash-audio vs quiet-audio) = 0.4738   full output range [0.4945, 0.5040]
```

**The audio branch scores below chance, and the model's entire output range
across every input tried is 0.0095 wide, centred on 0.5.** Its final sigmoid
sits at logit ≈ 0 no matter what it is shown. This is a model that learned
nothing, in either branch, and says "maybe" to everything.

Day 271's "real AUC is 0.9622 (fp32) / 0.8733 (int8) — a genuinely strong
result" was measuring that. So was Day 328's 1.0000.

## Why every AUC in this project's history could hide this

`roc_auc_score` is rank-based and therefore **completely scale-invariant**. A
model returning 0.4999 for every negative and 0.5001 for every positive
scores a perfect 1.0. AUC answers "is the ordering right", never "is there
anything to threshold". Those come apart exactly when a model collapses, and
this project has now hit that four times: `mg_gunshot`, `m1`, `m2`, and here.

The gate could not catch it either. Its `DEAD` test was `std < 1e-9`; this
model's std is ~2e-3 — six orders of magnitude above the floor — so it would
have been reported as `ok  AUC=0.924`.

**This commit closes that hole.** `verify_shipped_models.py` gains two
thresholds and a `COLLAPSED` verdict that fails the run:

* `COLLAPSE_SPAN = 0.05` — `max(out) - min(out)` below this is not
  thresholdable; `kDefaultThreshold = 0.5` would sit inside the noise.
* `COLLAPSE_SEP = 0.05` — for labelled fixtures, `|mean(pos) - mean(neg)|`
  below this has no usable effect size regardless of AUC.

The shipped healthy models are nowhere near these floors, which is what makes
them safe to enforce:

```
motion_fall_v2       AUC=0.999  sep=0.9414   range[0.000, 1.000]
scream_classifier_v3 AUC=0.839  sep=0.3729   range[0.000, 0.996]
m5_vocal_stress_v2   AUC=0.850  sep=0.2013   range[0.000, 0.986]
h_aggressive_speech             std=3.99e-01 range[0.0039, 0.9883]
mg_gunshot_retrain              std=1.50e-01 range[0.5001, 0.9788]
```

Every gate line for a labelled fixture now prints `sep=` next to the AUC, so
the effect size is visible on every run rather than only when something
fails.

## The units finding still stands, and still does not rescue it

Independently of the collapse: UCI-HAR inertial signals are in **g**;
`vehicle_crash_pipeline.dart:149` feeds raw `sensors_plus` values, which are
**m/s²**. Through `normalize_imu = clip(w, -8, 8) / 8` the same motion arrives
8x larger, saturating 16.7% of every window against 0.0% in training. The
gyroscope channels are already consistent (rad/s on both sides), so the exact
fix is to divide only the three accelerometer channels by 9.80665.

That is a one-line change and it is *correct*. It is not being made, because
applying it to a model whose output range is 0.0095 changes nothing
measurable — both unit regimes are already inside the noise. It belongs in
the retrain, against a model that responds to its inputs at all.

## Can it be retrained honestly? No — same answer as Day 329

`i_vehicle_crash`'s training design is genuinely sound, and that was worth
saying on Day 328: `load_uci_har` reads real 6-axis UCI-HAR, and both classes
derive from the *same* real window (`neg = normalize_imu(w)`,
`pos = inject_crash_spike(w)`), so there is no provenance shortcut of the
kind that killed `s_crowd_panic`.

But the positive class is `inject_crash_spike` — a hand-written linear ramp
subtracted from accelerometer x over 10 of 128 samples. Searched every
attached drive for real crash data (`*crash*`, `*collision*`, `*accident*`,
`*impact*`, `*airbag*`, `*telematic*`, `*harsh*brak*` across `ml_datasets/`,
`kaggle_datasets/`, `dsfolder/`, `D:`, `E:` and `F:`, including the ~955 GB
of recently added datasets): **zero matches.**

So a retrain would produce a detector for a synthetic ramp someone invented.
That is the same standard applied to `s_crowd_panic` and `k_confinement` on
Day 329, and it has to apply here too.

## Recommendation: replace the model with a threshold, not another model

Unlike crowd panic, a vehicle crash has a **known, simple physical
signature**: a large deceleration over a few tens of milliseconds. When the
target is that well characterised a priori, a neural network trained on
invented positives is strictly worse than a deterministic rule — the rule is
interpretable, unit-testable against synthetic *and* real traces, tunable
against a published threshold (automotive literature puts airbag deployment
near 20 g), and carries no training-data risk at all.

Concretely: replace `VehicleCrashDetector` with a check on
`sqrt(ax² + ay² + az²)` in m/s² exceeding a calibrated threshold, sustained
over a minimum sample count, with a gyroscope corroboration term for
rollover. This is a small amount of ordinary code with no `.tflite` and no
dataset dependency.

That is a product decision, so it is recommended here and not implemented.
What this commit does is remove the false belief that a re-export was all
that stood between this model and working.

## Status

`i_vehicle_crash` stays disabled via `kDualInputModelsDisabled` and stays in
the gate's `KNOWN_BROKEN` table, with its entry corrected to name the real
cause.

### `m2_motion_b_retrain` — measured while here, and it is worse

It shares `normalize_imu` with `i_vehicle_crash`, so it was expected to share
the unit half of this. It does, and the point is moot:

```
real UCI-HAR window, input scale swept x0.001 -> x1000
  (spans g, m/s^2, SisFall ~0.24 and UniMiB gravity scales)   -> 0.00000000
all-zeros / all-ones / randn*5 / pure 9.81 on z               -> 0.00000000
  distinct outputs across all 15 probes: 1
```

**It returns exactly 0.0 for every input.** Its tensors are float32, so
quantization is not involved, and the swept scales rule out a units
explanation — there is no magnitude at which it responds. Day 262 recorded
this model as "test AUC 0.9808 on held-out real SisFall falls, up from
bit-exact 0.0". The shipped asset is bit-exact 0.0 again.

Its `KNOWN_BROKEN` entry is corrected accordingly: the unit mismatch is real
but is not why this one fails.
