# Day 260D — `m2_motion_b` / `m2_motion_adversarial`: the last unresolved item

Follow-up to `DAY260_QUANTIZATION_ROOTCAUSE.md` and
`DAY260B_HIDDEN_INPUT_CHECK.md`. Day 259 flagged `m2_motion_b.tflite` and
`m2_motion_adversarial.tflite` as "exactly constant" (std < 1e-4). Day 260B
confirmed both have a single `[1,128,6]` float32 input (no hidden second
input like `k_confinement`) and confirmed both are **not int8-quantised** —
`quant=(0.0, 0)` for both — which undercuts the "int8 quantisation collapsed
marginal logits" theory `PREPROCESSING_SPEC.md` proposed for this model
pair specifically, since there is no quantisation step involved at all.
Neither doc re-ran the model against real data. This closes that gap.

Script that produced every number below:
`tools/day260_ml_triage/check_m2_motion_b.py`. Re-run it to reproduce — raw
command output is pasted, not retyped, throughout this file.

## Step 0 — confirm the two staged files are the same model

```
m2_motion_b.tflite size=60016  m2_motion_adversarial.tflite size=60016  byte-identical=True
```

Same pattern as `m_best`/`m_glass_breaking` and `k_best`/`k_confinement`:
one trained model, staged under two filenames. Traced to a real source —
`kaggle_notebooks/day107_hardmine_int4_push/day107_hardmine_m2.py`
(`day103` origin, hardened for Day 107's adversarial/int4 push) trains a
single `ZAPSAFE_SWEEP_ARCH` (env-selected; the report on disk records
`"arch": "b"`, `"architecture": "medium_cnn1d"`) and always writes its
output to a *fixed* filename, `m2_motion_adversarial.tflite`
(`CFG["output"]`, hardcoded regardless of arch — see the script, line 83).
`day108_int4_m9_push/build_tflite_bundle.py` then copies that one file into
the staging bundle under **two** names:

```
26:    ("hardmine_m2/m2_motion_b.tflite", ("**/m2_motion_b.tflite",)),
27:    ("hardmine_m2/m2_motion_adversarial.tflite", ("**/m2_motion_adversarial.tflite",)),
```

The report confirms it's the arch-`b` run: `test_auc: 0.9942`,
`test_recall: 0.8867`, `samples: 16000`, `passed_size_budget: true` — a
real training run, not a placeholder. From here on "the model" means this
one file under either name.

## Step 1 — is it actually constant on real data? Test A: real UCI-HAR, exactly as trained and as Day 259 likely tested it

`day107_hardmine_m2.py`'s own `load_uci_har()` uses UCI-HAR **only as a
negative source** (`m2_dataset_usage.json`: `uci_har: {pos: 0, neg: 4000}`)
— UCI-HAR has no real falls, so there is no real UCI-HAR positive class for
this model. This test therefore checks the thing that matters most: is the
score constant across real, varied, non-synthetic negative motion? Used
the training script's own `normalize()` (`clip(w, -8, 8) / 8`) on 150 real
UCI-HAR test-split windows.

```
======================================================================
TEST A: m2_motion_b on real UCI-HAR windows (training script's own normalize())
======================================================================
real UCI-HAR windows: 150  (raw per-window |acc| range: min=0.0000g max=1.1292g -- this is what normalize() divides by G_RANGE=8.0)

--- m2_motion_b.tflite on real UCI-HAR (normalized per training) ---
n=150  std=0  min=0  max=0  mean=0
```

**Confirmed: exactly constant (bit-identical 0.0) across all 150 real,
varied UCI-HAR windows (walking, sitting, standing, laying, upstairs,
downstairs, all six real activity classes).** Day 259's verdict for this
model reproduces cleanly on the real dataset used all week. Unlike
`m_glass_breaking` and `o_running_fleeing` in the prior two docs, this one
is not a discrepancy that needs reconciling — it holds up immediately.

## Step 2 — hypothesis 1: scale mismatch (G_RANGE normalization saturates on real UCI-HAR's already-small units)

Real UCI-HAR `body_acc` is gravity-removed and small (measured range above:
max |acc| 1.13 g across the 150 real windows tested). `normalize()` divides
by `G_RANGE=8.0`, shrinking that further to about ±0.14. Hypothesis: this
scale mismatch pins the input near zero and saturates a downstream
activation, independent of the model's real weights. Tested by removing
the `/G_RANGE` step entirely — same real windows, raw un-normalized units:

```
======================================================================
TEST A2: m2_motion_b on real UCI-HAR windows, RAW units (no /G_RANGE normalize -- hypothesis check)
======================================================================

--- m2_motion_b.tflite on real UCI-HAR RAW (un-normalized) ---
n=150  std=0  min=0  max=0  mean=0
```

**Hypothesis 1 REJECTED.** Removing the normalization step entirely makes
no difference — still bit-identical 0.0 across all 150 windows. Whatever is
happening is not a simple input-scale saturation issue.

## Step 3 — is the model dead everywhere, or only on UCI-HAR-shaped data? Test B: real PAMAP2, bug-for-bug as trained

`day107_hardmine_m2.py`'s **real, actually-used positive class** for this
model does not come from UCI-HAR at all — it comes from real PAMAP2 data,
via `load_pamap2()`: `FALL_IDS = {12, 13}` as positive, `NORM_IDS = {1, 2,
3, 4, 5, 6, 7, 9, 16, 17}` as negative, reading `df.iloc[:, 20:26]` as the
6-channel IMU tensor. Reused this function directly (imported from the
training script, `cache_roots()` monkeypatched to point at this machine's
real local PAMAP2 files — no other change) against the real local dataset
(`ml_datasets/motion/DS14_PAMAP2/PAMAP2_Dataset/{Protocol,Optional}`, 1.65
GB of real recordings across 9 subjects):

```
======================================================================
TEST B: m2_motion_b on real PAMAP2 data, bug-for-bug column slice exactly as day107_hardmine_m2.py trains it
======================================================================
real PAMAP2 windows via load_pamap2(): pos(act12/13 'stairs', trained as positive)=4277 neg(act in {1,2,3,4,5,6,7,9,16,17})=6000

--- m2_motion_b.tflite on real PAMAP2 (bug-for-bug, as trained) ---
n=160  std=0.393243  min=0  max=0.996094  mean=0.667041
pos median=0.996094 (n=80)  neg median=0.5 (n=80)
AUC=0.7946
```

**The model is NOT constant everywhere.** On real PAMAP2 data run through
the exact preprocessing it was trained on, it shows genuine variance (std
0.39, full output range 0–0.996) and real, non-trivial separation (AUC
0.79, clean median split 0.996 vs 0.5). The weights are not degenerate —
they encode a real, learned decision boundary for *something* in this data.
The "exactly constant" behavior from Step 1 is specific to feeding it real,
correctly-formatted UCI-HAR/phone-accelerometer-shaped data, not a global
property of the checkpoint.

## Step 4 — what is `FALL_IDS = {12, 13}` actually labeling? (real answer, not assumed)

PAMAP2's own documentation, extracted directly from the dataset's bundled
PDFs (`ml_datasets/motion/DS14_PAMAP2/PAMAP2_Dataset/readme.pdf`,
section "II.2. Activity IDs"):

```
1 lying          9 watching TV        16 vacuum cleaning
2 sitting        10 computer work     17 ironing
3 standing       11 car driving       18 folding laundry
4 walking        12 ascending stairs  19 house cleaning
5 running        13 descending stairs 20 playing soccer
6 cycling                              24 rope jumping
7 Nordic walking                       0 other (transient)
```

`activityID 12 = "ascending stairs"`, `13 = "descending stairs"`. **PAMAP2
has no fall activity at all** — confirmed against
`DescriptionOfActivities.pdf`'s full list of the 18 performed activities
(lying, sitting, standing, ironing, vacuuming, ascending/descending stairs,
walking, Nordic walking, cycling, running, rope jumping, watching TV,
computer work, car driving, folding laundry, house cleaning, playing
soccer — no fall, no impact, no equivalent). `day107_hardmine_m2.py`'s
`FALL_IDS = {12, 13}` comment-labels this class "fall" in its own code
(`MOBIACT_FALL`/`FALL_IDS` naming convention shared with the real fall
classes it pulls from MobiAct/UniMiB/PAMAP2-labeled sources elsewhere), but
for PAMAP2 specifically the ID mapping is wrong: it is training on
**stair-climbing motion**, not falls. This is a real, distinct, fixable
labeling bug in the training script — separate from Step 5's finding below
— not touched or fixed today per this week's verification-only scope.

## Step 5 — hypothesis 2: the PAMAP2 column slice is wrong, and the model learned a data-source artifact, not real motion

PAMAP2's column layout (confirmed directly from real files, see next
section) puts chest sensor data at columns 20–36 in a fixed 17-column
block: `20=temperature, 21-23=accel(±16g) xyz, 24-26=accel(±6g) xyz,
27-29=gyro xyz, 30-32=magnetometer xyz, 33-36=orientation(invalid)`.
`day107_hardmine_m2.py`'s `load_pamap2()` reads `df.iloc[:, 20:26]` —
columns 20–25 — which is **`[temperature, accel16_x, accel16_y, accel16_z,
accel6_x, accel6_y]`**, not `[acc_x, acc_y, acc_z, gyro_x, gyro_y, gyro_z]`
the way every other loader in this script (UCI-HAR, MotionSense, WISDM,
MobiAct, UniMiB) provides it and the way the model's `IMU_DIM=6` semantic
contract implies. **There is no gyroscope data anywhere in this slice**,
one accelerometer range is duplicated across two different scales, and the
first channel is real body temperature in °C, not motion.

Direct check of that temperature column across 3 real subject files:

```
======================================================================
Direct check: PAMAP2 raw column 20 (chest temperature) value range across real files
======================================================================
  subject101.dat: col20 min=31.812 max=33.312 mean=32.709
  subject102.dat: col20 min=36.125 max=37.000 mean=36.720
  subject103.dat: col20 min=31.250 max=33.312 mean=32.531
combined: min=31.250 max=37.000 -- G_RANGE=8.0, so clip(temp,-8,8)/8 = [1.] for EVERY sample regardless of real motion
```

Real skin/chest temperature (31–37°C) is always far outside `normalize()`'s
`±G_RANGE=8` clip range, so channel 0 is **the constant 1.0 for every real
PAMAP2 window, positive and negative alike** — confirmed directly in Test D
below (`channel 0 real value before ablation: unique values = [1.]`). This
constant is present in **100% of the model's real positive-class training
data and 33% of its negative-class training data (PAMAP2's own 4,000
negatives)**, but **0% of the UCI-HAR/MotionSense-sourced negatives
(8,000 of the other 8,800 real negatives)**. This gives the model a
trivial, always-available shortcut: "does channel 0 read the clipped
constant 1.0" is a perfect proxy for "was this window sourced from
PAMAP2", which correlates with, but is not the same thing as, the model's
intended fall/anomaly distinction.

### Test C — hypothesis check: correct the column slice, keep the real weights, same real windows

Rebuilt the same real PAMAP2 windows (same files, same activity-ID split)
using the **correct** chest 6-channel block — `df.iloc[:, 24:30]` =
`accel6[x,y,z] + gyro[x,y,z]`, a real accel+gyro tensor with no temperature
channel — and ran them through the **same, unmodified, already-trained**
`m2_motion_b.tflite` weights (this is a hypothesis test on the existing
checkpoint, not a retrain):

```
======================================================================
TEST C: m2_motion_b on real PAMAP2 data, CORRECTED columns (chest acc6[x,y,z]+gyro[x,y,z] = cols 24:30, hypothesis check)
======================================================================
real PAMAP2 windows with CORRECTED chest acc6+gyro slice: pos=4277 neg=13613

--- m2_motion_b.tflite on real PAMAP2, CORRECTED columns (hypothesis check, same weights) ---
n=160  std=0.40252  min=0  max=0.996094  mean=0.237573
pos median=0 (n=80)  neg median=0 (n=80)
AUC=0.4702
```

With the column-selection bug corrected — real accel+gyro data, no
temperature artifact — the same weights that scored **AUC 0.79** on the
bugged slice (Test B) drop to **AUC 0.47, worse than chance**, and both
class medians collapse to 0. **Hypothesis 2 CONFIRMED**: the model's
apparent real signal in Test B was not learned motion semantics — it was
substantially reliant on the PAMAP2 column-slicing artifact (principally
the always-1.0 temperature channel acting as a "this window is PAMAP2,
therefore in-training-distribution" flag). Once that artifact is removed,
the checkpoint has essentially nothing left.

### Test D — ablation: isolate the temperature channel's individual contribution

To separate "the temperature channel specifically" from "the column slice
being wrong in general" (Test C changes 5 of 6 channels at once), the same
real bug-for-bug PAMAP2 windows from Test B were kept as-is except channel
0 was overwritten with uniform random noise in [-1, 1] (a stand-in for
"not always exactly 1.0"), leaving the other five (still-mismatched)
channels untouched:

```
======================================================================
TEST D: ablation -- same real bug-for-bug PAMAP2 windows, channel 0 (temp, normally clipped to a constant) replaced with noise
======================================================================
channel 0 (temp) real value before ablation: unique values = [1.] (should all be the clipped constant, 1.0, if the hypothesis is right)

--- m2_motion_b.tflite, real PAMAP2 windows w/ channel0 noise-ablated ---
n=160  std=0.484225  min=0  max=0.996094  mean=0.482275
pos median=0.996094 (n=80)  neg median=0 (n=80)
AUC=0.6615
```

AUC drops from 0.79 (Test B, real constant channel) to 0.66 (channel 0
noised) but does not collapse to chance the way Test C's full correction
does. **The temperature channel is a real, measurable contributor
(accounts for part of the gap between 0.79 and 0.47) but not the sole
cause** — the other five channels (accel16 x/y/z + accel6 x/y, still
missing gyro entirely and still mixing two accelerometer ranges) also carry
some of the spurious, source-identifying signal. Both problems — the
constant temperature channel and the wrong/incomplete accel+gyro slice —
contribute independently to the same underlying issue: the model learned
to recognize "is this a PAMAP2-shaped window" more than it learned "is this
an anomalous motion".

## Conclusion

**`m2_motion_b` / `m2_motion_adversarial` are genuinely, reproducibly
constant (bit-exact 0.0) on real UCI-HAR / phone-accelerometer-shaped data
— the domain this model would actually see at inference time — and this is
NOT a quantization artifact** (confirmed unquantised in Day 260B; confirmed
again here that removing the input normalization step, i.e. ruling out a
scale-saturation theory, changes nothing). It is also **not simply "dead
weights"** — the same checkpoint shows real, substantial dynamic range and
AUC 0.79 on real PAMAP2 data fed through its own (buggy) training
preprocessing.

The real cause, established with real data through two independent tests
(Test C's full correction and Test D's isolated ablation), is a **training-
data/preprocessing bug**, not a model-architecture or export problem:

1. `load_pamap2()`'s column slice (`df.iloc[:, 20:26]`) does not match the
   `[acc_x,y,z, gyro_x,y,z]` semantic contract the rest of the pipeline and
   the model's other real data sources use — it is
   `[temperature, accel16_x,y,z, accel6_x,y]`, with real chest temperature
   (31–37°C) permanently clipped to a constant 1.0 by `normalize()`'s
   `±8` range, and **no gyroscope data anywhere in it**.
2. `FALL_IDS = {12, 13}` labels PAMAP2 activity IDs 12/13 as the model's
   positive ("fall") class; per PAMAP2's own bundled documentation these
   IDs are **"ascending stairs"** and **"descending stairs"** — PAMAP2 has
   no fall activity at all. The model's positive class was never falls.
3. Given (1) and (2) together, and Test C/D's real-data confirmation that
   correcting the column slice collapses the checkpoint's apparent
   performance to chance, the most honest characterization is: **this
   checkpoint mostly learned to distinguish "PAMAP2-sourced data" from
   "UCI-HAR/MotionSense-sourced data" via a preprocessing artifact, not to
   distinguish falls (or even stairs, reliably) from normal activity.**
   Its "exactly constant" behavior on real UCI-HAR data is the direct,
   expected consequence: real UCI-HAR windows never carry the PAMAP2
   artifact, so the model's learned shortcut always says "not PAMAP2" →
   score saturates to 0, regardless of the actual accelerometer/gyro
   content.

**Verdict: confirmed dead for real-world use, same category as
`mg_gunshot` and `s_crowd_panic_a`/`s_best` — a training-data/preprocessing
problem, not a quantization or export problem, and not fixable by
re-exporting.** Fixing it for real would require, at minimum: (a)
correcting `load_pamap2()`'s column slice to real chest accel+gyro
(`df.iloc[:, 24:30]`, verified above to still not be enough on its own —
Test C's AUC is 0.47, worse than chance, meaning the current weights have
no salvageable signal once the artifact is gone), and (b) sourcing real
fall-labeled data (MobiAct/UniMiB/SisFall — SisFall is already confirmed
locally available per `DAY260C_HARNESS_RECONCILIATION.md`'s Test 2) instead
of PAMAP2's stairs activities for the positive class. **No re-export,
retrain, or preprocessing fix was performed today — verification only, per
this week's established pattern.**

## Not attempted / open

- MotionSense- and WISDM-sourced negatives (also part of the real training
  recipe) were not separately re-tested — PAMAP2 (positive-class source)
  and UCI-HAR (largest negative-class source, and the dataset used all week
  for every other model) were judged sufficient to answer the "is it
  constant, and why" question the task asked.
- No retrain or corrected re-export was produced. Test C's finding (AUC
  0.47 with corrected columns, on the *existing* weights) means a column
  fix alone, without also fixing the PAMAP2 stairs-as-fall mislabeling and
  likely adding real fall data, would not be expected to produce a useful
  model — this is flagged for whoever scopes a retrain, not resolved here.
