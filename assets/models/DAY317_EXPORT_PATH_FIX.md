# Day 317 — the int8 export path was shipping a dead gunshot detector

`assets/models/mg_gunshot_retrain.tflite` emitted a **constant 0.3633 for
every input** — real gunshots and real urban negatives alike. It could never
fire. This was found by running the shipped asset against 200 real
UrbanSound8K clips through a real TFLite interpreter, not by reading a report.

It shipped undetected because nothing could have caught it: `flutter test`
has no native TFLite interpreter, so no Dart test executes a model, and the
training report said `auc 0.8913, recall_gunshot 0.9958` — which was true of
the *trained model*, just not of the *exported file*.

## What was actually wrong

Not the weights. Both the working and the dead export have healthy weights
(std ≈ 40, range [-127, 127], zero constant tensors), and signal still flows
through 69 internal tensors. The failure is at the very last tensor:

```
[178] gunshot_1/MatMul   (the pre-sigmoid logit, n=1)
  kaggle export : scale=0.0172  zero_point=-123  → representable −0.086 … +4.30
  SHIPPED       : scale=0.0194  zero_point= -99  → representable −0.563 … +4.38
  observed in both: pinned at −128, the int8 floor
```

The logit's calibrated activation range has almost **no negative headroom**,
so real-world logits fall below the representable floor and clamp. Every
input then decodes to the same bucket (raw −35 → 0.3633). This is
**activation calibration failure**, which is why the float32 twin of the very
same training run scores AUC 0.89 on the same clips.

## What was measured, and what shipped

Rebuilt the day261 architecture, loaded the real `best.weights.h5`, and
confirmed the rebuild is faithful (max |keras − f32_tflite| = **0.000011**
over 40 real clips) before trusting any re-export. Then compared every
quantization strategy on **598 held-out real UrbanSound8K clips** (149 real
`gun_shot` vs 449 real urban negatives — a realistic ~1:3 imbalance, and
disjoint from the calibration set):

| export | size | AUC | best-F1 operating point |
|---|---|---|---|
| **shipped int8 (before)** | 2806.8 KB | **0.4989** | dead — constant |
| int8, re-calibrated on real audio | 2807.7 KB | 0.7312 | rec .631 / prec .553 |
| dynamic-range | 2608.1 KB | 0.8925 | rec .933 / prec .688 |
| **float16 — now shipped** | **4677.1 KB** | **0.9165** | rec .940 / prec .693 |
| float32 reference | 9294.8 KB | 0.9155 | rec .940 / prec .693 |

Re-calibrating int8 with a real, class-balanced representative set recovers a
lot (0.499 → 0.731) but full int8 still costs real accuracy on this
MobileNetV2 graph. **float16 matches float32 at half the size**, so that is
what ships. `tools/model_exports/mg_gunshot_retrain_dynrange.tflite` is kept as the
smaller option (deliberately **outside** `assets/models/`, since everything
under that path is bundled into the app and an unused 2.6 MB model is pure
bundle bloat) — it is *smaller than the dead file it replaces* and still
reaches AUC 0.89, worth taking if bundle size becomes the binding constraint.

## Threshold changed: 0.5 → 0.70

The old default came from the training report's own balanced split, which
overstated precision. Measured on realistic class balance:

| threshold | recall | precision |
|---|---|---|
| 0.50 | 1.000 | 0.265 |
| 0.70 | 0.960 | 0.603 |
| 0.78 | 0.940 | 0.693 |
| 0.90 | 0.747 | 0.700 |

At 0.5, ~74% of alerts would be false. 0.70 keeps this recall-heavy — a
missed gunshot is worse than a false alarm for a safety app — while cutting
false alerts to ~40%.

## Code changes

`gunshot_detector.dart` previously *required* int8 and threw otherwise. It
now detects the dtype: float32 input is fed straight through with no
quantization step, and the legacy int8 path is retained so an older asset
still loads. `isInt8` is exposed so callers can tell which export is active.

## The gap that let this ship — now closed

`tools/verify_shipped_models.py` runs every asset against **real recorded
data** and fails (exit 1) if a model's output is invariant.

It deliberately does **not** use random noise, because random probing gives
both false positives and false negatives — established the hard way here:
`m2_motion_b_retrain` looks dead under random input but is genuinely alive on
real SisFall IMU, while `motion_anomaly_v1` looks alive under random input
and is genuinely dead on real IMU. Models with no real fixture yet report
`UNVERIFIED` rather than a guessed verdict.

Current output:

```
mg_gunshot_retrain.tflite      4677.1KB  ok    range[0.5001, 0.9788] std=1.50e-01
m2_motion_b_retrain.tflite       58.9KB  ok    range[0.0000, 0.9727] std=3.39e-01
scene_analyzer_v1.tflite       1375.0KB  ok    range[0.1523, 0.3672]  (ref kernels)
motion_anomaly_v1.tflite        360.0KB  DEAD  range[0.0000, 0.0000] std=0.00e+00
dcs_fusion_v1.tflite              0.3KB  PLACEHOLDER
```

`scene_analyzer_v1` only failed to load under the desktop XNNPACK delegate
(`Node 121 failed to prepare`); with reference kernels it is fine, so the
script falls back rather than crying wolf.

## Still open after this change

- **`motion_anomaly_v1.tflite` is dead on real IMU** and still shipped. Not
  fixed here: unlike gunshot there is no known-good f32 twin to re-export
  from, so it needs its own source model or a retrain.
  `m2_motion_b_retrain` is alive and covers motion detection meanwhile.
- **`dcs_fusion_v1.tflite` is a 262-byte text placeholder**, not a model —
  it says so itself ("Real model lands Month 7–8, XGBoost on beta-user
  data"). DCS fusion does not exist yet.
- **8 models remain `UNVERIFIED`** — no real fixture for their input shapes
  yet (dual-input crash/crowd-panic models, the 38-dim prosodic models, the
  non-square m1 mel models). Adding fixtures for those is the obvious next
  step for this script.
- `test/fixtures/gunshot_quant_golden.json` now describes the **legacy int8**
  export, not the shipped float16 one. Its test still passes because it
  checks the quantization arithmetic against a static fixture, which remains
  correct for that legacy path.
- Not device-verified — no working Gradle toolchain in this sandbox. The
  model contract, preprocessing parity, and accuracy are grounded in real
  audio through a real interpreter; the on-device load itself is not.

## Reproducing this

`tools/model_exports/rebuild_and_requantize_gunshot.py` rebuilds the day261
architecture from `best.weights.h5`, asserts the rebuild matches the known-good
f32 export before trusting it, and re-exports. Run it with `../../.mlvenv`.
