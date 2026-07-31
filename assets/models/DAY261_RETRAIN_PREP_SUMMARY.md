# Day 261 -- retrain prep for 3 of the 5 confirmed-dead models

Follow-up to `WEEK_ML_TRIAGE_SUMMARY.md`, which flagged 5 models
**confirmed-dead / retrain needed** after this week's real-data
verification push. This session scoped and prepped retrain data/scripts
for **3 of those 5**: `m2_motion_b`/`m2_motion_adversarial`, `mg_gunshot`,
and `m_glass_breaking`/`m_best`. The other 2 (`k_confinement`/`k_best`,
`s_crowd_panic_a`/`s_best`) are separately scoped and were not touched.

**This session is PREP ONLY.** There is no local GPU. No actual training
was run for any of the 3 models. What was done: read each model's real
training script, found and fixed the real bugs documented this week (plus
one new bug found while reading `day89_mg_gunshot.py`), assembled real
local training data (verified counts, not estimates), wrote corrected
Kaggle-ready training scripts, and ran what CPU smoke-testing was feasible
to confirm each script's data pipeline actually runs on real data without
crashing.

All 3 push folders live under `kaggle_notebooks/day261_*_retrain_push/`,
which is a **separate, untracked directory** -- see "Where these commits
live" below.

## 1. `m2_motion_b` / `m2_motion_adversarial`

**Folder:** `kaggle_notebooks/day261_m2_motion_b_retrain_push/`

**Real bugs fixed** (both documented in `DAY260D_M2_MOTION_B_CHECK.md`,
not fixed there -- verification-only per that day's scope):
1. `load_pamap2()` read PAMAP2 columns `20:26` expecting
   `[acc_x,y,z, gyro_x,y,z]`; real columns are
   `[temperature, accel16_x,y,z, accel6_x,y]` -- no gyro at all, and the
   temperature channel (31-37 degC) was clipped to a constant `1.0` by
   `normalize()`. Fixed: columns `24:30` (real accel6+gyro).
2. `FALL_IDS = {12, 13}` labeled PAMAP2 activity IDs 12/13 ("ascending/
   descending stairs" per PAMAP2's own docs -- PAMAP2 has no fall activity)
   as the positive "fall" class. Fixed: PAMAP2 now contributes negatives
   only; real fall positives now come from **DS13_SisFall**
   (`train_3`+`val_3` splits, `test_3` held out).

**Real local data:** 917 real SisFall fall-impact positives (696 train +
221 val), 20,865 real PAMAP2 negative windows (corrected columns, 16 real
activity classes across 14 real subject files), plus unchanged UCI-HAR/
WISDM/MotionSense/UniMiB negatives.

**Smoke test:** full pipeline (real data load -> `model.fit()` -> INT8
TFLite export) ran to completion on CPU with a 390-window/1-epoch
configuration. No crash. Real log: `DONE b auc=0.4228 kb=59.6` (not a
quality signal at this scale -- confirms the script runs, nothing more).

**Status: ready to run on Kaggle now**, modulo one real gap below.

## 2. `mg_gunshot`

**Folder:** `kaggle_notebooks/day261_mg_gunshot_retrain_push/`

**Real bugs fixed:**
1. **New finding this session**, not previously documented:
   `load_esc50()` filtered by numeric `target` id `POS_CLASSES = {24}`
   commented `# gun_shot`. Checked against the real local `esc50.csv`:
   target 24 is actually **"coughing"**, and ESC-50 has no gunshot category
   at all. The original script, run for real, would have trained ~40 real
   coughing clips as gunshot positives. Fixed: ESC-50 now used for
   negatives only (fireworks, thunderstorm, engine, chainsaw, hand_saw --
   real category names, not numeric ids).
2. `DAY260_QUANTIZATION_ROOTCAUSE.md` Finding 2's fp32 AUC 0.538 already
   showed near-chance performance even before this ESC-50 bug was found;
   this is an independent, additional contributor.

**Real local data:** UrbanSound8K's real `gun_shot` class (374 clips --
largest real local positive source, already correctly wired in the
original script) + FSD50K `Gunshot_and_gunfire` (348 real clips) + new
real AudioSet `/m/032s66` positives (74 clips -- day89 never had an
AudioSet loader before). Total: **796 real positives, 5,661 real
negatives**, all counts from this session's actual script output.

**Status: ready to run on Kaggle now.**

## 3. `m_glass_breaking` / `m_best`

**Folder:** `kaggle_notebooks/day261_m_glass_breaking_retrain_push/`

**Real problem:** not a data-mislabeling bug like the other two -- the
model genuinely discriminates real ESC-50 glass audio well (AUC 0.97) but
overfits to it (AUC 0.37 on real AudioSet glass/shatter/smash per
`DAY260C_HARNESS_RECONCILIATION.md` Test 1). Fix is data diversity.

**Real bug fixed (harmless but real, new finding):** `ESC_NEG_CATS`
included `"dishes"` and `"washing"`, neither a real ESC-50 category name
(real name is `"washing_machine"`; no dish category exists) -- silently
matched 0 rows every run. Fixed.

**Real local data added:** FSD50K `Glass`+`Shatter` (974 real clips, ~24x
ESC-50's 40) + real hard negatives (`Dishes_and_pots_and_pans` 330,
`Chink_and_clink` 265, `Crushing` 190, `Wood`/`Knock`/`Slam`
285/270/351). AudioSet 106/5090 positive/hard-negative split reproduces
`DAY260C`'s exact real numbers, confirming the matching logic is
unchanged. Total: **1,120 real positives, 10,909 real negatives**.

**Status: ready to run on Kaggle now**, modulo the same-category gap
below.

## What's still blocked / not resolved (stated plainly, not forced)

- **No FSD50K label literally named "ceramic" or "metal impact"** exists
  in the real vocabulary (checked directly against
  `FSD50K.ground_truth/vocabulary.csv`). `Chink_and_clink` and `Crushing`
  are used as the closest real substitutes for the glass-breaking
  hard-negative set -- flagged as an approximation, not a real match.
- **No literal "car backfire" label** exists in any local dataset's real
  taxonomy for the gunshot hard-negative set either; `Engine`/
  `engine_idling` used as the closest real substitute.
- **MobiAct** (another real fall-labeled source for `m2_motion_b`) has no
  local copy on this machine -- Drive-only, not fetched per this task's
  scope.
- **SisFall has no existing Kaggle dataset slug anywhere in this
  project** -- `day261_m2_motion_b_retrain_push/kernel-metadata.json`
  ships a placeholder (`REPLACE_ME_sisfall_dataset_slug`) that must be
  filled in with a real Kaggle SisFall mirror before pushing.
- **`hr_imu` (DS_HIFD)** is real `.mat` data locally but the original
  loader only reads `.csv` -- confirmed it silently produced zero real
  samples even before this retrain. Not fixed (out of scope for this
  bug-fix-focused retrain, not one of the 2 documented bugs for this
  model).
- **`load_wisdm()`/`load_motionsense()` returned 0/0 real samples** in
  this session's local smoke test against the real local WISDM/
  MotionSense folders. This is unchanged, pre-existing loader behavior
  (not one of the 2 confirmed `m2_motion_b` bugs), not investigated
  further -- flagged for whoever picks this up next.
- **FSD50K eval-split audio is not present locally** (0 files found) for
  either audio model -- only the dev split (40,966 real clips) was
  searched.
- **nigens.zip (Drive-only, not fetched)**: per this task's scope, this
  Drive folder (https://drive.google.com/drive/folders/1SPU4yW_9YaI3VnfzhTw9ZCE6zJ-Cj_3R)
  was not downloaded. If fetched later, it would add general real audio
  event clips useful as additional hard negatives for both `mg_gunshot`
  (non-gunshot impulsive sounds) and `m_glass_breaking` (non-glass impact
  sounds) -- it was NOT used to source any of the counts above, and
  nothing in this prep depends on it.

## Where these commits live

`kaggle_notebooks/` is **not inside any git repository on this machine** --
confirmed directly (`git rev-parse --show-toplevel` fails both from
`kaggle_notebooks/` itself and its `day261_*_retrain_push/` subfolders; the
only two `.git` directories found under `letsstartbuilding/` belong to
`zapsafe_backend` and `zapsafe_mobile`). This means the 6 new files per
model (training script, `README.md`, `kernel-metadata.json`, plus
`build_manifest_local.py`/`data_manifest_*.json` for the two audio models)
**cannot be committed to any existing repo** -- there is nothing to commit
them to. This doc itself, and the `day261_*` commits referenced in
`zapsafe_mobile`'s git log, only cover files that actually live inside
`zapsafe_mobile` (this doc + `tools/day260_ml_triage/` cross-references).
The backend repo (`zapsafe_backend`) was not touched, per this task's
constraints.
