# Week ML triage summary (Day 258–260D)

Single rollup of every model touched during this week's real-data
verification push, so the whole week's outcome can be read in one place
without opening `DAY260_QUANTIZATION_ROOTCAUSE.md`,
`DAY260B_HIDDEN_INPUT_CHECK.md`, `DAY260C_HARNESS_RECONCILIATION.md`, and
`DAY260D_M2_MOTION_B_CHECK.md` separately. Every "status" below is backed by
a real-data test in one of those docs (or `PREPROCESSING_SPEC.md`'s Day
258/259 sections for the two already-wired baselines) — none is asserted
without a doc reference.

Status definitions used below:

- **wired** — actually integrated into the app and shown to work on real
  data (not just "exists as a `.tflite` file").
- **confirmed-dead / retrain needed** — real data shows the model does not
  produce a usable signal, and the cause is a training-data, labeling, or
  architecture problem that re-exporting cannot fix.
- **confirmed-dead / scope mismatch, not a bug** — real data shows the
  model behaves correctly for what it was actually trained to detect; the
  original "broken" framing came from testing it against a different real
  physical event than its training target.
- **unresolved** — real testing this week could not settle the question one
  way or the other.

| model | status | one-line real evidence | doc reference |
|---|---|---|---|
| `m1_scream_v2` | wired | AUC 0.865 / 41.7% recall @ 0% FPR on real RAVDESS (clean acted speech is its real operating domain); AUC drops to 0.569 on noisier real AudioSet | `PREPROCESSING_SPEC.md` "READ THIS FIRST" table |
| `m2_motion_v2` | wired | real UCI-HAR: walking scores 0.004, injected fall scores 0.980 | `PREPROCESSING_SPEC.md` "READ THIS FIRST" table |
| `m_glass_breaking` / `m_best` | confirmed-dead / retrain needed | AUC 0.97 (fp32)/0.89 (int8) on ESC-50 (in-training-distribution) but AUC 0.37/0.47 with int8 pos/neg medians bit-identical on real AudioSet glass/shatter/smash audio — fails on realistic audio | `DAY260_QUANTIZATION_ROOTCAUSE.md` Finding 1; reconciled in `DAY260C_HARNESS_RECONCILIATION.md` Test 1 |
| `mg_gunshot` | confirmed-dead / retrain needed | fp32 AUC 0.538 (int8 AUC 0.500, exactly constant) on real AudioSet gunshot vs ESC-50 negatives — not quantization, fp32 itself is near-chance | `DAY260_QUANTIZATION_ROOTCAUSE.md` Finding 2 |
| `k_confinement` / `k_best` | confirmed-dead / retrain needed | has an undocumented 2nd input (`light`); with it set to the real value for daylight UCI-HAR data both fp32 and int8 collapse to ~0 (fp32 std 8e-17) regardless of real IMU pattern — near-total light-gating, real dynamic range only exists in the dark-confinement regime | `DAY260_QUANTIZATION_ROOTCAUSE.md` Finding 3; hidden input found in `DAY260B_HIDDEN_INPUT_CHECK.md` Step 1 |
| `o_running_fleeing` (+f32) | confirmed-dead / scope mismatch, not a bug | moves UP correctly (mean 0.084) on real UCI-HAR run through its own `apply_panic_running()`, but collapses to ~1.8e-8 on real SisFall fall-impact data — both real and reproducible; the model detects panic running, not falls, so near-zero on real falls is in-spec for what it was trained on, not a defect (product-intent question, not a measurement one) | `DAY260B_HIDDEN_INPUT_CHECK.md` Step 3; reconciled in `DAY260C_HARNESS_RECONCILIATION.md` Test 2 |
| `s_crowd_panic_a` / `s_best` (+f32) | confirmed-dead / retrain needed | has an undocumented 2nd input (`mel` audio spectrogram); with both real inputs correctly matched, real panic audio scores LOWER (mean 0.942) than real calm audio (mean 0.955) — wrong direction, confirmed even after fixing the missing-input bug, traced mainly to the audio branch | `DAY260B_HIDDEN_INPUT_CHECK.md` Step 4 |
| `m2_motion_b` / `m2_motion_adversarial` | confirmed-dead / retrain needed | bit-exact 0.0 on 150 real, varied UCI-HAR windows (not a quantization artifact — both files are unquantised float32); the same weights score AUC 0.79 on real PAMAP2 data via the training script's own buggy column slice, but AUC drops to 0.47 (chance) once the slice is corrected to real accel+gyro — the model mostly learned a PAMAP2-vs-not-PAMAP2 data-source artifact (a permanently-clipped chest-temperature channel plus a wrong/incomplete column slice with no gyro), not real motion; separately, its "fall" positive class (PAMAP2 activity IDs 12/13) is actually "ascending/descending stairs" per PAMAP2's own documentation — PAMAP2 has no fall activity at all | `DAY260D_M2_MOTION_B_CHECK.md` |

## Week totals (from the table above)

- **Wired and working on real data: 2** — `m1_scream_v2`, `m2_motion_v2`
  (both already shipped before this week's push; re-confirmed, not newly
  wired).
- **Confirmed dead, retrain needed: 5** — `m_glass_breaking`/`m_best`,
  `mg_gunshot`, `k_confinement`/`k_best`, `s_crowd_panic_a`/`s_best`,
  `m2_motion_b`/`m2_motion_adversarial`. All five fail on real data for
  reasons that trace to training data, labeling, or architecture (light-
  gating, wrong audio branch, wrong PAMAP2 columns/labels) — none are
  quantization or export bugs, so re-exporting would not fix any of them.
- **Confirmed dead as originally framed, but scope-mismatch not a defect: 1**
  — `o_running_fleeing`. Its "wrong-direction, collapses to 0" framing
  doesn't hold once tested against the physical event it was actually
  trained to detect (panic running, not falls); whether the product needs
  it to also cover falls is a decision for whoever owns the confinement/
  panic feature set, not a measurement this week resolved.
- **Unresolved: 0.** Every model that had an open question at the start of
  this week (`m_glass_breaking`, `o_running_fleeing`'s Day 259-vs-260
  discrepancies, `m2_motion_b`/`m2_motion_adversarial`'s never-retested
  "constant" flag) was closed out with real data by the end of Day 260D.

## What this week established about Day 259's harness

`DAY260C_HARNESS_RECONCILIATION.md`'s blast-radius assessment: the two
models that initially looked like they contradicted Day 259
(`m_glass_breaking`, `o_running_fleeing`) turned out to reproduce Day 259's
numbers closely once tested against harder/more-realistic real data
(AudioSet instead of ESC-50; real SisFall falls instead of the model's own
panic-running augmentation) — the opposite of what a systematically broken
harness would produce. Two separate, narrower bugs were found and fixed
along the way (`k_confinement`/`s_crowd_panic`'s undocumented second
input, left unset by both Day 259 and this week's first-pass tests until
`interpreter.get_input_details()` was checked directly). **Day 259's other
verdicts, including the 13 models not individually re-touched this week,
should be treated as likely trustworthy — not as needing another pass —
unless new evidence surfaces.**
