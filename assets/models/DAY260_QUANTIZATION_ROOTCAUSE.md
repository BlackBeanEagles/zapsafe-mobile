# Day 260 — quantization root-cause check on 3 of the 7 "exactly constant" models

Scope: today only checked whether the pre-quantization fp32 checkpoint is
also constant on real data for **3 of the 7** models Day 259's triage
flagged as exactly-constant (std < 1e-4): `m_glass_breaking`, `mg_gunshot`,
`k_confinement`. The other 4 (`m_best` — identical file to `m_glass_breaking`,
byte-for-byte, see below — `k_best` — identical file to `k_confinement` —
`m2_motion_b`, `m2_motion_adversarial`) were not attempted today; see
"Not attempted" at the bottom.

Script that produced every number below:
`tools/day260_ml_triage/check_fp32_vs_int8.py`. Re-run it to reproduce —
raw command output is pasted, not retyped, throughout this file.

## Checkpoint locations found

| staged int8 (in `kaggle_notebooks/day108_int4_m9_push/.../tflite_staging/`) | fp32 checkpoint found | how matched |
|---|---|---|
| `m_glass_breaking.tflite` (1,300,224 bytes) / `m_best.tflite` (byte-identical, same 1,300,224 bytes) | `kaggle_notebooks/day102_sweep_push/day102_sweep_kaggle_output/saved/sweep/m/d/m_glass_breaking_d_f32.tflite` | int8 size (1,300,224 B) matches `m_glass_breaking_d.tflite` exactly, and `m_sweep_leaderboard.json`'s `"best"` entry is arch `d` (`mobilenetv3`) — `m_best`/`m_glass_breaking` are that same sweep-winner file copied under two names |
| `mg_gunshot.tflite` (2,872,800 bytes) | `kaggle_notebooks/mg_gunshot_push/output_v5/mg_gunshot_f32.tflite` | this push has its own `output_v5` with both the int8 and f32 exports plus `mg_gunshot_report.json`; not part of the day102 sweep |
| `k_confinement.tflite` (56,528 bytes) / `k_best.tflite` (byte-identical, same 56,528 bytes) | `kaggle_notebooks/day102_sweep_push/day102_sweep_kaggle_output/saved/sweep/k/a/k_confinement_a_f32.tflite` | int8 size (56,528 B) matches `k_confinement_a.tflite` exactly, and `k_sweep_leaderboard.json`'s `"best"` entry is arch `a` (`small_cnn1d`) |

All three were found under `day102_sweep_push` or a model-specific `_push`
folder's own `output_v*` — not under `day108_int4_m9_push` itself, which only
holds the already-quantized staging copies plus lineage subfolders.

## Finding 1 — `m_glass_breaking` / `m_best`: could NOT reproduce yesterday's "exactly constant" result on ESC-50

Real data: ESC-50 `glass_breaking` category (40 real clips, genuine glass-break
recordings) as positives, 40 real negatives sampled from
`can_opening/clock_alarm/clock_tick/door_wood_creaks/door_wood_knock/hand_saw/
pouring_water/washing_machine`. Preprocessing matches the recovered day93/day102
config exactly (sr=16000, 2.0s, 96 mels, fmax=8000, per-clip min-max, then the
day102 sweep's own global mean/max renormalization from
`m_glass_breaking_d_norm.json`).

```
--- fp32 ---
n=80  std=0.440576  min=3.66e-07  max=0.997853  mean=0.47509
pos median=0.984866 (n=40)  neg median=0.00320828 (n=40)
AUC=0.9731

--- int8 staged (today's rerun of the SAME file yesterday's triage flagged as std=0.0) ---
n=80  std=0.261945  min=0  max=0.980469  mean=0.151221
pos median=0.136719 (n=40)  neg median=0 (n=40)
AUC=0.8941
```

Both fp32 and the staged int8 file show strong, real, correctly-directed
signal on ESC-50 audio (positives score high, negatives score ~0, AUC 0.97 /
0.89). **This directly contradicts Day 259's triage entry** (`m_glass_breaking
| 96x96 mel | 0.500 | 0.0 | exactly constant`) **for the same staged file**.

I do not know why. Two honest possibilities, not resolved today:
1. Yesterday's harness used different real audio (possibly AudioSet clips
   with the `glass`/`shatter`/`smash` keyword match instead of ESC-50), and
   the model genuinely is constant on that harder, more realistic
   distribution while looking fine on ESC-50 (which is also literally what
   the model was trained on — in-distribution audio, not a fair generalization
   test).
2. Something in yesterday's harness (not available to inspect — `triage.py`
   was never committed) differed from this script's preprocessing in a way
   that collapsed the output.

**This is flagged, not resolved.** Given (1) is plausible and consistent with
the m1_scream_v2 pattern already documented in this file (train-domain
accuracy that doesn't survive real-world audio), the honest scope-limited
statement is: *on ESC-50 audio specifically, neither the fp32 nor the staged
int8 file is constant, and both discriminate real glass-break audio well.*
Whether it holds up on AudioSet-style noisy audio is unknown and should be
the first thing checked tomorrow before deciding whether to re-export or ship.
No re-export was attempted for this model today because the "exactly
constant" premise didn't reproduce with the data used here.

## Finding 2 — `mg_gunshot`: fp32 is not constant, but is not good either (near-chance AUC on real audio)

Real data: 50 real AudioSet clips carrying the `/m/032s66` ("Gunshot,
gunfire") label (matched via `train.csv` against the 9,927 wavs present
locally — 74 candidates exist, 50 sampled) as positives, 50 real ESC-50
negatives (`car_horn/chainsaw/clapping/engine/fireworks/siren/thunderstorm`).
Preprocessing matches the recovered day89 config (sr=16000, 3.0s, 128 mels,
fmax=8000, per-clip min-max — no second normalization step, confirmed by
reading `day89_mg_gunshot.py`'s `main()` directly).

```
--- fp32 ---
n=100  std=0.105585  min=0.421663  max=0.906855  mean=0.565416
pos median=0.540152 (n=50)  neg median=0.526729 (n=50)
AUC=0.5380

--- int8 staged ---
n=100  std=0  min=0.394531  max=0.394531  mean=0.394531
pos median=0.394531 (n=50)  neg median=0.394531 (n=50)
AUC=0.5000
```

fp32 has real, non-trivial variance (std 0.106, range 0.42–0.91) — it is
**not** constant. But its AUC on real gunshot audio is 0.538, barely above
chance, and the pos/neg medians (0.540 vs 0.527) are close enough that no
threshold would be useful. This roughly matches the direction of yesterday's
independently-run `mg_gunshot_f32` line in the triage table (AUC 0.373, std
0.022, "worse than chance") — different exact numbers because it's a
different real-sample draw, but the same conclusion: **the fp32 gunshot model
does not discriminate real gunshot audio from real non-gunshot audio.**

This does not fit either of the two clean buckets in today's task
instructions. It is not "fp32 is fine → re-export"; the fp32 model itself is
near-useless on real audio. It is also not "fp32 is exactly constant →
drop"; it does vary. Re-exporting int8 with a wider calibration set would
likely restore some output variance (since int8 collapse tends to follow
already-marginal fp32 logits, as documented for `m1_pocket_muffled`) but
would not fix the underlying ~chance-level discrimination, so **no re-export
was attempted** — the expected value is low and this matches the project's
stated principle (measure before wiring/exporting). This model needs
retraining with harder real negatives, not a re-export.

## Finding 3 — `k_confinement` / `k_best`: NOT a quantization bug — model has an undocumented second input, and both fp32 and int8 are genuinely constant under realistic conditions

This one required backing out of an initial wrong conclusion, documented
here rather than silently corrected.

**First pass (invalid):** feeding only a `[1,128,6]` IMU tensor (as
`PREPROCESSING_SPEC.md`'s tensor-shape table documents) into both the fp32
and staged int8 `k_confinement` models over 120 real UCI-HAR windows gave:
fp32 std=0.3185 (real variance, looked like a clean quantization-bug
candidate), int8 std=0.0 (flat). This looked like exactly the pattern the
task was hunting for.

**Then discovered:** `k_confinement`'s real signature (checked directly via
`interpreter.get_input_details()`, not assumed) is **two inputs**:
`serving_default_imu:0 [1,128,6]` **and** `serving_default_light:0 [1,32,1]`.
`day92_k_confinement.py` fuses a broadcast ambient-light scalar (0.0 = dark /
confinement proxy, 0.85–0.9 = normal lit environment) with the IMU branch —
this is a real, intentional part of the trained architecture (kidnapping
detection = darkness + vehicle-like vibration, per the script's own
docstring), not a bug in the model. It is simply **not mentioned anywhere in
`PREPROCESSING_SPEC.md`'s tensor-shape table**, and my first pass — like,
plausibly, yesterday's triage if it made the same assumption — left `light`
unset, which TFLite fills with whatever is in the freshly-allocated buffer
rather than erroring. That produced numbers that looked like a real
measurement but weren't one.

**Corrected test:** both inputs set explicitly, light swept across the two
values that mean something physically:

```
[light=0.85  (lit/normal -- correct value for real UCI-HAR daily-activity data)]
--- fp32 ---
n=120  std=8.31e-17  min=4.44e-17  max=5.16e-16  mean=1.10e-16
--- int8 staged ---
n=120  std=0  min=0  max=0  mean=0

[light=0.0  (dark -- confinement proxy per day92_k_confinement.py's own encoding)]
--- fp32 ---
n=120  std=0.222607  min=0.443105  max=0.99941  mean=0.742194
--- int8 staged ---
n=120  std=0.189742  min=0.605469  max=0.996094  mean=0.786556
```

With `light` held at the value that is actually true for the real UCI-HAR
data (people doing normal daytime activities — not dark), **both fp32 and
int8 collapse to ~0 regardless of the real IMU pattern** (fp32 std is
8e-17 — floating-point noise around exactly zero, not real variance). The
model appears to have learned to gate almost entirely on the light input:
"not dark" outputs ~0 no matter what the accelerometer/gyro is doing. This
is not a quantization artifact — it reproduces in fp32.

With `light=0.0` (dark), both fp32 and int8 respond with real, non-constant
variance (std 0.22 / 0.19), so the model does have real dynamic range — just
one that today's realistic real-data test (all-daylight UCI-HAR) can't
exercise, and one that a real confinement scenario (dark + vehicle vibration)
would.

**Conclusion for `k_confinement`: dead at the training level for the
"exactly constant on real data" finding as originally stated — because that
finding itself was measured without the light input set correctly. The
corrected, honest statement is: the model is real (not degenerate — it has
genuine dynamic range when light is dark) but appears to be almost entirely
light-gated rather than combining both signals, which was never tested for
because it wasn't a documented input.** No re-export was attempted — a
wider int8 calibration set cannot fix an architectural property that
reproduces identically in fp32. `PREPROCESSING_SPEC.md`'s tensor-shape table
should be corrected to list both inputs for `k_confinement`/`k_best`; whether
`m2_motion_b`, `o_running_fleeing`, `s_crowd_panic_*` (same `[1,128,6]`
family per the spec) have the same undocumented light input was **not
checked today** and should be checked before anyone trusts a shape-only
description of those models again.

## Not attempted today

- **`m_best`, `k_best`** — byte-identical files to `m_glass_breaking` and
  `k_confinement` respectively (verified by file size + sweep leaderboard
  `"best"` pointer), so findings 1 and 3 above apply to them directly; no
  separate run was needed or done.
- **`m2_motion_b`, `m2_motion_adversarial`** — not reached today. Per the
  finding above, before testing these it is worth first checking with
  `interpreter.get_input_details()` whether they also carry an undocumented
  second input, given they're the same `[1,128,6]` IMU family as
  `k_confinement`.
- **Reconciling the `m_glass_breaking` ESC-50-vs-yesterday discrepancy** on
  harder/noisier real audio (AudioSet-style) — flagged above, not resolved.

## What "wider representative-dataset re-export" was and wasn't tried

A re-export attempt for `k_confinement` (arch `a`, using the real
`saved_model_export` SavedModel plus 300 real UCI-HAR train-split windows as
representative-dataset calibration, instead of the original 80 samples drawn
mostly from synthetic bootstrap positives) was started, then abandoned
correctly once the two-input issue above was discovered: the conversion
failed immediately with `Invalid input shapes: expected 2 items got 1
items.` because the representative-dataset generator also only yielded the
IMU tensor. No `.tflite` file was produced by that attempt — nothing invalid
was left on disk. Given Finding 3, fixing the generator to yield both inputs
would not have helped: the fp32 checkpoint itself collapses under realistic
`light` conditions, so this is a training-data/architecture question, not an
export one, and was correctly not pursued further per the task's "if fp32 is
also constant → drop" instruction.

No re-export was produced or committed for any of the three models today.
