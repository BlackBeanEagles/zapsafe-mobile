# Day 260B — hidden-second-input check on the rest of the `[1,128,6]` IMU family

Follow-up to `DAY260_QUANTIZATION_ROOTCAUSE.md`'s Finding 3
(`k_confinement`/`k_best` turned out to have an undocumented second input,
`light [1,32,1]`, and PREPROCESSING_SPEC.md's tensor-shape table never
mentioned it). That doc explicitly flagged that `m2_motion_b`,
`o_running_fleeing`, `s_crowd_panic_*` — all listed in the same
`[1,128,6]` row of the spec table — were **not checked** for the same
problem, and that Day 259's "exactly constant" / "wrong-direction" verdicts
on those models should not be trusted until they were.

Scope today: real `interpreter.get_input_details()` on every staged file in
that row, then a real-data re-test (not retrain, not re-export) for any
model that turns out to have a second input, using
`tools/day260_ml_triage/check_fp32_vs_int8.py` (extended today with
`run_o_running_fleeing()` and `run_s_crowd_panic()` — the file was reused,
not replaced). Raw command output is pasted below, not retyped.

## Step 1 — real input signatures

Script: `tools/day260_ml_triage/inspect_inputs.py` (new today). Full
command output:

```
======================================================================
m2_motion_b.tflite   size= 60016
INPUTS:
  name='serving_default_keras_tensor_19:0' shape=[1, 128, 6] dtype=<class 'numpy.float32'> quant=(0.0, 0)
OUTPUTS:
  name='StatefulPartitionedCall_1:0' shape=[1, 1] dtype=<class 'numpy.float32'> quant=(0.0, 0)

======================================================================
m2_motion_adversarial.tflite   size= 60016
INPUTS:
  name='serving_default_keras_tensor_19:0' shape=[1, 128, 6] dtype=<class 'numpy.float32'> quant=(0.0, 0)
OUTPUTS:
  name='StatefulPartitionedCall_1:0' shape=[1, 1] dtype=<class 'numpy.float32'> quant=(0.0, 0)

======================================================================
o_running_fleeing.tflite   size= 24320
INPUTS:
  name='serving_default_imu:0' shape=[1, 128, 6] dtype=<class 'numpy.float32'> quant=(0.0, 0)
OUTPUTS:
  name='StatefulPartitionedCall_1:0' shape=[1, 1] dtype=<class 'numpy.float32'> quant=(0.0, 0)

======================================================================
o_running_fleeing_f32.tflite   size= 59164
INPUTS:
  name='serving_default_imu:0' shape=[1, 128, 6] dtype=<class 'numpy.float32'> quant=(0.0, 0)
OUTPUTS:
  name='StatefulPartitionedCall_1:0' shape=[1, 1] dtype=<class 'numpy.float32'> quant=(0.0, 0)

======================================================================
s_crowd_panic_a.tflite   size= 20200
INPUTS:
  name='serving_default_imu:0' shape=[1, 128, 6] dtype=<class 'numpy.float32'> quant=(0.0, 0)
  name='serving_default_mel:0' shape=[1, 64, 64, 1] dtype=<class 'numpy.float32'> quant=(0.0, 0)
OUTPUTS:
  name='StatefulPartitionedCall_1:0' shape=[1, 1] dtype=<class 'numpy.float32'> quant=(0.0, 0)

======================================================================
s_crowd_panic_a_f32.tflite   size= 45120
INPUTS:
  name='serving_default_imu:0' shape=[1, 128, 6] dtype=<class 'numpy.float32'> quant=(0.0, 0)
  name='serving_default_mel:0' shape=[1, 64, 64, 1] dtype=<class 'numpy.float32'> quant=(0.0, 0)
OUTPUTS:
  name='StatefulPartitionedCall_1:0' shape=[1, 1] dtype=<class 'numpy.float32'> quant=(0.0, 0)

======================================================================
s_best.tflite   size= 20200
INPUTS:
  name='serving_default_imu:0' shape=[1, 128, 6] dtype=<class 'numpy.float32'> quant=(0.0, 0)
  name='serving_default_mel:0' shape=[1, 64, 64, 1] dtype=<class 'numpy.float32'> quant=(0.0, 0)
OUTPUTS:
  name='StatefulPartitionedCall_1:0' shape=[1, 1] dtype=<class 'numpy.float32'> quant=(0.0, 0)
```

`cmp` confirms `s_best.tflite` is byte-identical to `s_crowd_panic_a.tflite`
(20,200 bytes both), same pattern as `m_best`/`k_best` in the prior doc.

### Result

| model | real inputs | vs. spec table |
|---|---|---|
| `m2_motion_b`, `m2_motion_adversarial` | **single** input `[1,128,6]` float32 | spec table **correct** for these two — no hidden input |
| `o_running_fleeing` (+f32) | **single** input, `serving_default_imu:0 [1,128,6]` float32 | spec table **correct** — no hidden input |
| `s_crowd_panic_a` / `s_best` (+f32) | **two** inputs: `serving_default_imu:0 [1,128,6]` **and** `serving_default_mel:0 [1,64,64,1]` | spec table **wrong** — same undocumented-second-input problem as `k_confinement` |

Side note, not part of today's task but worth flagging: `m2_motion_b.tflite`
and `m2_motion_adversarial.tflite` are **not int8-quantised** — dtype is
`float32` with `quant=(0.0, 0)` for both input and (implicitly) output. This
contradicts `PREPROCESSING_SPEC.md`'s "Why so many are constant" section,
which lists these two among "all three exactly-constant IMU models
(`k_confinement`, `k_best`, `m2_motion_b`, `m2_motion_adversarial`) are
int8-quantised" as the proposed mechanism. Whatever is making them constant
(if they still are — not re-tested today, out of scope per the task), it is
not the int8-quantisation-collapse mechanism as written, at least not for
these two files. Flagged for whoever picks up the `m2_motion_b`/
`m2_motion_adversarial` retest.

## Step 2 — `m2_motion_b`, `m2_motion_adversarial`: no action needed today

Confirmed single-input, spec table correct for these two. Day 259's
"exactly constant" verdict was not measured with a missing second input —
whatever caused it (if reproducible; not re-checked here) is a separate
question from today's hidden-input hypothesis. **Not retested today** —
out of scope per the task (only the second-input question was in scope for
single-input models).

## Step 3 — `o_running_fleeing`: single input confirmed, but Day 259's verdict does NOT reproduce today

Since `o_running_fleeing` has only one real input, Day 259's "wrong
direction on fall-injected" finding cannot have been caused by a missing
second input — so this is not a hidden-input story like `k_confinement`.
Re-ran it anyway per the task's instruction to specifically recheck this
model's direction claim, using real UCI-HAR calm windows and the model's
own training-time augmentation function, `apply_panic_running()`, imported
directly from `kaggle_notebooks/o_running_fleeing_push/day94_o_running_fleeing.py`
(the exact function that script uses to turn real UCI-HAR/WISDM/PAMAP2
windows into RUNNING/panic positives — sudden-burst + cadence-jitter +
direction-change, not a fall specifically; "fall-injected" in Day 259's
wording is treated here as this model's own panic-injection method, since
`o_running_fleeing` detects panic running/fleeing, not falls).

Raw output (`run_o_running_fleeing()` in `check_fp32_vs_int8.py`):

```
real UCI-HAR calm windows: 60; same windows put through o_running's own apply_panic_running() augmentation: 60

--- fp32 -- calm (real UCI-HAR) ---
n=60  std=0.000431997  min=7.94049e-16  max=0.00337503  mean=5.7113e-05

--- fp32 -- panic-injected (real UCI-HAR + apply_panic_running) ---
n=60  std=0.276126  min=1.31018e-26  max=1  mean=0.0837392
fp32: calm mean=5.7113e-05  panic mean=0.0837392  delta=+0.0836821

--- int8 staged -- calm (real UCI-HAR) ---
n=60  std=0.000687385  min=9.47467e-16  max=0.00537011  mean=9.04553e-05

--- int8 staged -- panic-injected (real UCI-HAR + apply_panic_running) ---
n=60  std=0.27613  min=1.11488e-26  max=1  mean=0.0838061
int8 staged: calm mean=9.04553e-05  panic mean=0.0838061  delta=+0.0837157
```

Both fp32 and int8: calm windows score ~0.00006–0.00009 (essentially 0),
panic-injected windows score ~0.084 on average with real per-window std
0.276 (some windows reaching 1.0, per `max=1`). **The score moves UP when
panic is injected — the CORRECT direction** — for both fp32 and int8,
directly contradicting Day 259's "collapses to exactly 0 the instant a real
fall is injected — wrong-direction" verdict for the same staged files.

This does not fit the hidden-input explanation (there is only one input,
confirmed above) and is not resolved today. It is the same shape of
discrepancy as `DAY260_QUANTIZATION_ROOTCAUSE.md`'s Finding 1
(`m_glass_breaking` also failed to reproduce Day 259's verdict on real
data, for unknown reasons — either different real data/injection method
in Day 259's uncommitted harness, or a preprocessing difference). Two
honest possibilities, neither confirmed:
1. Day 259 used a genuinely different "fall" injection (real fall/impact
   data rather than `apply_panic_running`'s running-specific augmentation),
   and the model behaves differently under that stimulus.
2. Day 259's harness had a bug (unrelated to the hidden-input class of bug
   found in `k_confinement`) that this script's real-data-only, model's-own-
   augmentation approach does not share.

**Verdict for `o_running_fleeing`: OVERTURNED on the specific numbers
reproduced today** (score moves the correct direction, not the wrong one),
**but STILL UNCLEAR why it disagrees with Day 259**, since the hidden-input
hypothesis that resolved `k_confinement` and explains `s_crowd_panic` below
does not apply here. Do not treat this as "safe to ship" — treat it as "the
original do-not-ship reason (wrong-direction) is not reproducible with
today's real-data method," which is a narrower, more cautious claim.

## Step 4 — `s_crowd_panic_a` / `s_best` (+f32): hidden input confirmed, but wrong-direction verdict is CONFIRMED even with it fixed

Unlike `k_confinement`'s `light` (a broadcast scalar with one obvious
"physically correct" value), `s_crowd_panic`'s second input (`mel`) is a
full real audio mel-spectrogram — a genuine second modality, not a
constant. Per `kaggle_notebooks/s_crowd_panic_push/day95_s_crowd_panic.py`
(reused directly by `kaggle_notebooks/day102_sweep_push/day102_s_sweep.py`
via `day102_sweep_common.run_dual_sweep`, confirmed by reading — no
normalisation applied to either branch, consistent with the rest of the
o/k/s IMU family): the model is `[mel 64x64x1 spectrogram, imu 128x6 raw
window] -> panic score`, trained on real AudioSet panic-labelled audio +
either real MobiAct fall/bump IMU (run through the script's own
`apply_crush_imu()` overlay) or synthetic push IMU as positives, and real
ESC-50/UrbanSound calm audio + real UCI-HAR/WISDM/PAMAP2 calm IMU as
negatives.

Real MobiAct `.txt` files are not present in this machine's local dataset
cache (`ml_datasets/motion/` has UCI-HAR, MotionSense, SisFall, PAMAP2,
WISDM, UniMiB, HIFD — no MobiAct). Rather than fabricate a "physically
correct" IMU value, today's test uses the closest reproducible real-data
substitute and discloses it: real UCI-HAR walking windows as the IMU
baseline, run through `apply_crush_imu()` — the model's own real,
documented crush-overlay function — to build the "crush/positive" IMU
case, exactly as `day95_s_crowd_panic.py`'s `load_mobiact_fall_pos()` does
to its own real MobiAct input. The mel/audio side uses fully real audio
throughout: real ESC-50 clips from the `ESC_NEG` category set as calm
negatives, real AudioSet clips matched against `PANIC_MIDS` (the exact
label-ID set `day95_s_crowd_panic.py` uses) as panic positives — both
lists imported directly from the training script, not re-derived by guess.

Raw output (`run_s_crowd_panic()` in `check_fp32_vs_int8.py`):

```
real calm ESC-50 audio clips: 30  real AudioSet panic-labelled audio clips: 30

--- fp32 -- calm audio + calm IMU (true negative combo) ---
n=25  std=0.039595  min=0.826528  max=0.995206  mean=0.955075

--- fp32 -- panic audio + crush IMU (true positive combo) ---
n=25  std=0.0980897  min=0.481036  max=0.994648  mean=0.941939

--- fp32 -- panic audio + calm IMU (mixed) ---
n=25  std=0.095789  min=0.494121  max=0.994516  mean=0.940816

--- fp32 -- calm audio + crush IMU (mixed) ---
n=25  std=0.0376403  min=0.83574  max=0.995275  mean=0.956985
fp32: neg mean=0.955075  pos mean=0.941939  delta=-0.0131363

--- int8 staged (== s_best.tflite, byte-identical) -- calm audio + calm IMU (true negative combo) ---
n=25  std=0.0401921  min=0.825164  max=0.995528  mean=0.95435

--- int8 staged (== s_best.tflite, byte-identical) -- panic audio + crush IMU (true positive combo) ---
n=25  std=0.0981103  min=0.480964  max=0.994358  mean=0.941584

--- int8 staged (== s_best.tflite, byte-identical) -- panic audio + calm IMU (mixed) ---
n=25  std=0.0958538  min=0.494109  max=0.994546  mean=0.940182

--- int8 staged (== s_best.tflite, byte-identical) -- calm audio + crush IMU (mixed) ---
n=25  std=0.0378803  min=0.834137  max=0.995433  mean=0.956144
int8 staged (== s_best.tflite, byte-identical): neg mean=0.95435  pos mean=0.941584  delta=-0.0127659
```

With both inputs set to real, matched data:

- The output sits close to a constant ~0.94–0.96 regardless of class — this
  is a sigmoid output nowhere near a useful decision boundary either way.
- **The panic/positive combo scores LOWER than the calm/negative combo**
  (fp32: 0.9419 vs 0.9551, delta -0.0131; int8: 0.9416 vs 0.9544, delta
  -0.0128) — the same **wrong direction** Day 259 originally reported, now
  reproduced with the previously-missing `mel` input correctly populated
  with real, matched audio instead of left as allocator garbage.
- The "mixed" rows show the **audio branch, not the IMU branch, is driving
  almost all of the movement**: swapping only the audio (panic vs calm)
  while holding IMU fixed moves the score by about the same -0.013 to
  -0.015 either way; swapping only the IMU while holding audio fixed moves
  it by under 0.002. So the wrong-direction behavior traces mainly to the
  audio/mel branch scoring real panic audio *lower* than real calm audio,
  not to the IMU branch.
- Score variance is real (std 0.038–0.098 per condition) and noticeably
  higher than Day 259's originally reported "noise-floor variance,
  0.001–0.003" for the same staged file — consistent with Day 259 likely
  having measured this model with `mel` unset (same class of bug as
  `k_confinement`), which depressed the apparent variance as well as
  hiding the direction problem's true magnitude.

**Verdict for `s_crowd_panic_a` / `s_best` (+f32): CONFIRMED wrong-direction,
even after fixing the hidden-input bug.** The magnitude/std numbers Day 259
originally reported were measured incorrectly (real std is higher once
`mel` is set correctly), but the underlying safety-relevant conclusion —
this model scores real panic scenarios lower than real calm ones, the
opposite of what a panic detector must do — holds up under a corrected,
real, dual-input test. This is not a quantization artifact (fp32 shows the
same wrong direction) and is not an artifact of the missing-input bug
(reproduces with both inputs real and correctly matched). Do not ship. This
model needs retraining or retiring, not a re-export — same category as
`mg_gunshot` in the prior doc (architecture/training-data problem, not a
quantization problem).

## Spec correction (PREPROCESSING_SPEC.md)

`PREPROCESSING_SPEC.md` line 258 previously read:

```
| `m2_motion_b`, `k_confinement`, `o_running_fleeing`, `s_crowd_panic_*` | `[1,128,6]` | **128** IMU samples, not the 100 m2_motion_v2 uses |
```

This lumped four models with genuinely different signatures into one row.
Corrected in this commit to split `k_confinement`/`s_crowd_panic_*` out
into their own rows with their real second inputs, matching what
`interpreter.get_input_details()` actually reports (see also
`DAY260_QUANTIZATION_ROOTCAUSE.md` Finding 3 for `k_confinement`'s
correction, which was already flagged as pending there).

## Summary — Day 259 verdict status after today's check

| model | Day 259 verdict | hidden input? | today's verdict |
|---|---|---|---|
| `m2_motion_b`, `m2_motion_adversarial` | exactly constant (std 0.0) | **no** (confirmed single-input) | **STILL UNCLEAR** — not retested today (out of scope for the hidden-input question); also flagged: these files are fp32, not int8, contradicting the spec's proposed quantization-collapse mechanism for them |
| `o_running_fleeing` (+f32) | wrong-direction, collapses to 0 on fall-injected | **no** (confirmed single-input) | **OVERTURNED** on the numbers reproduced today (score moves the correct direction, up, on panic-injected real UCI-HAR data) — but the discrepancy with Day 259 is itself unexplained, so treat with caution, not as a clean "safe" result |
| `s_crowd_panic_a`, `s_best` (+f32) | noise-floor variance (0.001–0.003), wrong-direction on fall injection | **yes** — undocumented `mel [1,64,64,1]` second input | **CONFIRMED** wrong-direction with both inputs correctly populated with real, matched data; std corrected upward to 0.04–0.10 (real, not noise-floor); traced mainly to the audio/mel branch |

## Not attempted today

- Re-testing `m2_motion_b`/`m2_motion_adversarial`'s "exactly constant"
  verdict itself — out of scope (task only asked to check for a hidden
  input, and none exists for these two).
- Reconciling why `o_running_fleeing`'s direction disagrees with Day 259 —
  flagged, not resolved, same as the still-open `m_glass_breaking`
  discrepancy from the prior doc.
- Sourcing real MobiAct fall/bump recordings for `s_crowd_panic`'s IMU
  positive class (not present in the local dataset cache) — today's test
  used real UCI-HAR IMU + the training script's own real crush-overlay
  function as the closest disclosed substitute; if MobiAct data becomes
  available locally, this test should be re-run with it instead.
- No retrain, retire, or re-export was performed for any model — per the
  task, that decision comes after this verification step.
