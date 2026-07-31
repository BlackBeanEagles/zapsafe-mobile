# Day 266 — rollup: the 7 "exactly constant" models, and why "re-export with wider calibration" does not apply

Day 259's triage flagged 7 staged models as exactly constant on real data
(std < 1e-4): `m_glass_breaking`, `m_best`, `mg_gunshot`, `k_confinement`,
`k_best`, `m2_motion_b`, `m2_motion_adversarial`. The working theory at the
time — floated in `PREPROCESSING_SPEC.md`'s "why so many are constant"
section — was that int8 quantization was collapsing marginal fp32 logits to
a single bucket (the pattern already documented for `m1_pocket_muffled`),
and that re-exporting with a wider/more representative int8 calibration set
would fix all 7 at once. This document closes that question out: **the
batch re-export plan does not apply to any of the 7**, for reasons specific
to each model, established across `DAY260_QUANTIZATION_ROOTCAUSE.md`,
`DAY260B_HIDDEN_INPUT_CHECK.md`, and `DAY260D_M2_MOTION_B_CHECK.md`. See
`WEEK_ML_TRIAGE_SUMMARY.md` for the full-week rollup including the other
(non-constant-flagged) models touched this week; this document is scoped
to just these 7.

## Correcting the record: why "wider int8 calibration" was the wrong theory

Re-reading the three source docs directly (not just summarizing from
memory) confirms this plainly, model group by model group:

- **`m_glass_breaking` / `m_best`** (`DAY260_QUANTIZATION_ROOTCAUSE.md`
  Finding 1, reconciled in `DAY260C_HARNESS_RECONCILIATION.md` Test 1): on
  ESC-50 (in-distribution) audio, both fp32 (AUC 0.97) and int8 (AUC 0.89)
  discriminate real glass-break audio well — not constant at all in that
  regime. On real AudioSet glass/shatter/smash audio, both fp32 and int8
  collapse (AUC 0.37/0.47, int8 pos/neg medians bit-identical). Since fp32
  *itself* degrades on the harder real distribution, this is a
  generalization/training-data gap, not something int8 export settings
  caused — a wider calibration set only affects the int8 conversion step,
  and the fp32 checkpoint already fails before quantization enters the
  picture.
- **`mg_gunshot`** (Finding 2): fp32 AUC on real AudioSet gunshot audio is
  0.538 — barely above chance, with pos/neg medians (0.540 vs 0.527) too
  close for any threshold to be useful. The doc states this explicitly:
  "Re-exporting int8 with a wider calibration set would likely restore some
  output variance ... but would not fix the underlying ~chance-level
  discrimination, so no re-export was attempted." (Since resolved by
  retraining — see below — which is a separate, later fix from this
  rejected re-export theory.)
- **`k_confinement` / `k_best`** (Finding 3): the model has an undocumented
  second input (`light`). With `light` set to the physically-correct value
  for real UCI-HAR daylight data, **both fp32 and int8 collapse to ~0**
  (fp32 std 8.31e-17 — floating-point noise around exact zero). Because the
  fp32 checkpoint itself reproduces the collapse, the doc states directly:
  "No re-export was attempted — a wider int8 calibration set cannot fix an
  architectural property that reproduces identically in fp32." A concrete
  re-export attempt (arch `a`, 300 real UCI-HAR calibration windows) was
  actually started and then correctly abandoned once the two-input issue
  was found, since fixing the calibration generator would not have touched
  the underlying fp32 collapse.
- **`m2_motion_b` / `m2_motion_adversarial`** (`DAY260B_HIDDEN_INPUT_CHECK.md`
  Step 1, `DAY260D_M2_MOTION_B_CHECK.md` throughout): Day 260B's
  `interpreter.get_input_details()` check found these two files have
  `quant=(0.0, 0)` and dtype float32 for both input and output — **they are
  not int8-quantized at all**. There is no quantization step in their
  pipeline for a wider calibration set to even apply to. Day 260D confirms
  this independently and traces the real cause to two training-script bugs:
  `load_pamap2()` reads the wrong column slice (`df.iloc[:, 20:26]`,
  which is temperature + duplicated/incomplete accelerometer channels, no
  gyroscope at all, and a permanently-clipped constant temperature channel
  that leaks train/test source identity), and `FALL_IDS = {12, 13}`
  mislabels PAMAP2's "ascending/descending stairs" activities as "fall" —
  PAMAP2 has no fall activity in its documentation at all. Correcting the
  column slice on the *existing* weights drops AUC from 0.79 to 0.47
  (worse than chance), confirming the checkpoint itself has no salvageable
  signal once the artifact is removed — again, nothing an export setting
  touches.

So across all three investigated failure modes — generalization gap,
architectural light-gating, and a mislabeled/miscolumned training set — the
common thread is that **the fp32 checkpoint itself is the point of
failure** in every case that was actually checked in fp32. None of the
"the int8 file looks constant" observations trace back to the int8
conversion step itself. The original batch-fix plan is confirmed wrong.

## Per-model status

**`m_glass_breaking` / `m_best`** — Original symptom: exactly constant
(std 0.0) on Day 259's harness. Real root cause
(`DAY260_QUANTIZATION_ROOTCAUSE.md` Finding 1, corrected by
`DAY260C_HARNESS_RECONCILIATION.md` Test 1): a genuine train/test
generalization gap — strong on in-distribution ESC-50 audio (AUC 0.97
fp32), weak on realistic AudioSet audio (AUC 0.37 fp32). Not quantization:
both fp32 and int8 degrade together on the harder distribution. Per
`WEEK_ML_TRIAGE_SUMMARY.md`, this was retrained this week and improved to
AUC 0.75, still below shippable. Status: **improved, not shippable**.
Re-export relevance: **no** — a re-quantization step is irrelevant to a
training-data/generalization problem; any further work is retraining, not
export settings.

**`mg_gunshot`** — Original symptom: exactly constant (std 0.0, AUC 0.500)
on Day 259's harness. Real root cause
(`DAY260_QUANTIZATION_ROOTCAUSE.md` Finding 2): fp32 itself is near-chance
(AUC 0.538) on real AudioSet gunshot audio — the int8 file's flatness is
downstream of an already-unusable fp32 model, not an artifact of the
int8 export. Per `WEEK_ML_TRIAGE_SUMMARY.md`, this was retrained this week
and is now shipped at AUC 0.9225. Status: **fixed and shipped**. Re-export
relevance: **no** — the fix was a retrain with harder real negatives, not
a recalibrated quantization pass; the doc explicitly rejects the
wider-calibration approach for this model before the retrain happened.

**`k_confinement` / `k_best`** — Original symptom: exactly constant on
Day 259's harness. Real root cause
(`DAY260_QUANTIZATION_ROOTCAUSE.md` Finding 3): not a quantization bug at
all — the model has an undocumented second input (`light`, a broadcast
ambient-light scalar) that `PREPROCESSING_SPEC.md`'s tensor-shape table
never listed. With `light` set to the real, physically-correct value for
daylight UCI-HAR data, the model genuinely gates almost entirely on that
input and collapses to ~0 in both fp32 and int8; it only shows real
dynamic range in the dark/confinement regime the daylight test data can't
exercise. Status: **architecturally blocked** — this is a real property of
the trained model (near-total light-gating), not a bug to fix by
re-exporting. Re-export relevance: **no**, explicitly stated in the source
doc ("a wider int8 calibration set cannot fix an architectural property
that reproduces identically in fp32"); a concrete re-export attempt was
started and abandoned for exactly this reason once the two-input issue was
understood.

**`m2_motion_b` / `m2_motion_adversarial`** — Original symptom: exactly
constant (std < 1e-4) on Day 259's harness. Real root cause
(`DAY260B_HIDDEN_INPUT_CHECK.md` Step 1 + `DAY260D_M2_MOTION_B_CHECK.md`):
confirmed these files are plain float32 (`quant=(0.0, 0)`), not
int8-quantized — there is no quantization step for a wider calibration set
to act on in the first place. The real cause is a training-script bug: an
incorrect PAMAP2 column slice (missing gyroscope data entirely, and a
permanently-clipped chest-temperature channel that leaks which dataset a
window came from) plus a mislabeled positive class (PAMAP2 activity IDs
12/13 are "ascending/descending stairs" per PAMAP2's own documentation,
not falls — PAMAP2 has no fall activity at all). Per
`WEEK_ML_TRIAGE_SUMMARY.md`, this was retrained this week and shipped as
`motion_b`. Status: **fixed and shipped** (as the retrained `motion_b`,
distinct from the original checkpoint diagnosed here). Re-export relevance:
**no** — confirmed not a quantization artifact at all; the fix required
correcting the training script's column slice and label mapping plus
sourcing real fall-labeled data, not touching export/calibration settings.

## Gap: `m2_motion_adversarial` was never independently run through inference

`DAY260D_M2_MOTION_B_CHECK.md`'s Step 0 establishes that
`m2_motion_b.tflite` and `m2_motion_adversarial.tflite` are byte-identical
(both 60,016 bytes, `byte-identical=True`) — one trained model
(`day107_hardmine_m2.py`'s fixed-filename output) staged under two names
by `build_tflite_bundle.py`. That byte-identity check is real and was
performed directly (not assumed). However, every real-data test in that
document (Tests A, A2, B, C, D) loads and runs inference only against the
literal filename `m2_motion_b.tflite`; `m2_motion_adversarial.tflite` is
never separately loaded into a TFLite interpreter and run through the real
UCI-HAR or PAMAP2 windows. Likewise, `DAY260B_HIDDEN_INPUT_CHECK.md` Step 1
does call `interpreter.get_input_details()` on both filenames
independently and confirms identical single-input signatures for both —
but that is a metadata check, not an inference run.

Given the confirmed byte-identity, running `m2_motion_b.tflite` through a
TFLite interpreter necessarily produces bit-identical output to running
`m2_motion_adversarial.tflite` through the same interpreter, so this is a
low-risk gap in practice, not a live open question about the model's
behavior. But it is accurate to say: **`m2_motion_adversarial.tflite` was
never itself loaded and run through inference this week — its "tested"
status rests entirely on the file-identity check, not on an independent
run.** If anyone later replaces one of the two staged files without
updating the other (breaking the byte-identity assumption silently), this
gap would become a real one. Flagging it here rather than asserting both
were independently verified.

No other gaps were found: all 7 models (`m_glass_breaking`, `m_best`,
`mg_gunshot`, `k_confinement`, `k_best`, `m2_motion_b`,
`m2_motion_adversarial`) have a documented real-data root-cause
investigation on record, per the citations above. `m_best` and `k_best`
were not separately inference-tested either, but for the same
byte-identity reason confirmed directly via file size + sweep-leaderboard
`"best"` pointer matching in `DAY260_QUANTIZATION_ROOTCAUSE.md`'s
checkpoint-location table — the same category of gap as
`m2_motion_adversarial`, not a new one.

## Bottom line

None of the 7 models flagged "exactly constant" this week are fixable by
the originally planned batch re-export with wider int8 calibration. Two
(`mg_gunshot`, `m2_motion_b`/`m2_motion_adversarial`) are fixed and shipped
via retraining. One (`m_glass_breaking`/`m_best`) is improved but not yet
shippable, also via retraining, not export changes. One
(`k_confinement`/`k_best`) is architecturally blocked — a real, intentional
light-gating behavior, not a bug — and needs a product decision, not an
export pass. The `m2_motion_b`/`m2_motion_adversarial` pair rests on a
verified-but-not-independently-run byte-identity assumption for the
`_adversarial` filename specifically; treat that as a known, low-risk gap
rather than a fully closed item.
