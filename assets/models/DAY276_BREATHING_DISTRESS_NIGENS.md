# Day 276 — n_breathing_distress: NIGENS re-check + real FSD50K retrain

Follow-up to `DAY267_REMAINING_MODELS_TRIAGE.md` #4, which retired
`n_breathing_distress` (+f32) on the belief that the one dataset genuinely
suited to fix the label problem — NIGENS's real breathing sounds — was not
locally available outside a live Kaggle session. That belief is only half
right: `hridyajain/zapsafe-nigens` IS a real, listable Kaggle dataset, but it
turns out not to be the fix. FSD50K (already locally cached and already used
for the Day 262 gunshot/glass-breaking fixes) is.

## 1. What the training script actually did (unchanged part of this check)

`kaggle_notebooks/day104_adversarial_push/day104_n_adversarial.py`
`collect_n_data()` built its positive class as:

```
pos = rav_pos + cremad_pos + iem_pos + shemo_pos + esc_breath_pos
```

`rav_pos`/`cremad_pos`/`iem_pos`/`shemo_pos` are RAVDESS/CREMA-D/IEMOCAP/
ShEMO **emotion-speech** clips labeled ANG/FEA/DIS/SAD ("distress" emotion
codes) — not recordings of anyone actually breathing hard. Only
`esc_breath_pos` (`collect_esc50(categories={"breathing", "snoring"})`, ESC-50's
`breathing`/`snoring` categories, ≤80 clips total) was real breathing audio.
`pos_aug="gasp"` then overlays a synthetic burst/gap gasping pattern on top
of all of it. This is why Day 267 called the positive class "mostly
emotion-proxy speech" — confirmed again here, straight from the script.

## 2. Real NIGENS investigation (the actual re-check this task asked for)

`kaggle datasets files hridyajain/zapsafe-nigens` confirms it's a real,
listable 2GB Kaggle dataset (not a broken/empty slug). Its 8-fold `.flist`
manifests were downloaded and read directly (not assumed from the dataset
name):

- Real category taxonomy (15 categories, confirmed by scanning all 8 fold
  files): `alarm, baby, crash, dog, engine, femaleScream, femaleSpeech, fire,
  footsteps, general, knock, maleScream, maleSpeech, phone, piano`.
- **No dedicated "Breathing" category exists.** Grepping all 1,010 listed
  filenames for `breath|pant|gasp|wheez|respir|inhale|exhale` found exactly
  **4 real hits**, all buried inside the generic `general`/`femaleScream`
  buckets: `general/HumanPanting+1016_37.wav`, `general/HumanBreath+6095_73.wav`,
  `general/HUMAN-GASP_GEN-HDF-15016.wav`,
  `femaleScream/242607__reitanna__gasp-oooh.wav`.

Conclusion: NIGENS is real and now genuinely checkable (Day 267 was correct
that it wasn't locally cached, but the underlying assumption that it "does
contain a real Breathing sound-event class" turns out to be wrong once
actually inspected — 4 clips out of 1,010 is not a usable class on its own).
**Not used as the fix.**

## 3. The real fix: FSD50K

`ml_datasets/audio_events/DS08_FSD50K/` is locally cached (40,966 dev-audio
files) and its `FSD50K.ground_truth/vocabulary.csv` / `dev.csv` have real,
dedicated AudioSet-derived labels for exactly this gap, confirmed by exact
label-match counts against `dev.csv`:

| label | real dev-split clip count |
|---|---|
| `Breathing` | 431 |
| `Respiratory_sounds` | 822 |
| `Gasp` | 58 |
| `Sigh` | 75 |
| `Cough` | 279 |
| `Sneeze` | 64 |
| `Wheeze` | 0 |
| `Pant` | 0 |

These are real recorded breathing/gasping/respiratory-sound clips, not an
emotion-speech proxy — a genuinely different and much larger real source
than ESC-50's 80-clip pool.

## 4. What was changed

- `kaggle_notebooks/day104_adversarial_push/day104_audio_common.py`: added
  `collect_fsd50k_breathing_paths()` — same CSV label-scan pattern as the
  existing `collect_fsd50k_gunshot_paths()` — matching FSD50K labels
  `breathing, gasp, respiratory_sounds, sigh, pant, wheeze`.
- `kaggle_notebooks/day104_adversarial_push/day104_n_adversarial.py`:
  `collect_n_data()` now also pulls `fsd_breath_pos =
  collect_fsd50k_breathing_paths()` into the positive class (alongside the
  existing ESC-50 breathing/snoring positives; the emotion-speech sources
  are left in place — this widens the real-audio slice of `pos` without
  changing the file's other behavior).
- New retrain: `kaggle_notebooks/day276_n_breathing_retrain_push/
  day276_n_breathing_retrain.py` — a standalone Kaggle push script (same
  self-contained pattern as `day261_mg_gunshot_retrain_push`), preprocessing
  copied unchanged from `day104_audio_common.py`'s own `CFG` (sr=16000,
  duration=3.0s, n_mels=96, hop=512, n_fft=2048, fmax=4000, 96x96 mel image,
  single-channel) and the `arch="c"` ("large_cnn": Conv2D(64)→pool→
  Conv2D(128)→pool→Conv2D(256)→GAP→Dense(256)→Dropout(0.4)→sigmoid) —
  **positives = real FSD50K Breathing/Gasp/Respiratory_sounds/Sigh clips +
  real ESC-50 breathing/snoring, negatives = real clean FSD50K Speech +
  ESC-50 generic-sound categories.** No emotion-speech proxy anywhere in
  this retrain's data.

## 5. Real retrain result (Kaggle, run to completion, `hridyajain/zapsafe-day276-n-breathing-retrain`, kernel version 1)

```
[FSD50K] loaded 866 positives (real Breathing/Gasp/Respiratory/Sigh), 1466 negatives (clean Speech)
[ESC-50] loaded 80 positives (breathing/snoring), 240 negatives
Real positives: 946  Real negatives: 1706
After balance: total=1892  (Train: 1324  Val: 284  Test: 284)
AUC: 0.5823
recall_breathing_distress: 0.3662
precision: 0.6341
f1_breathing_distress: 0.4643
```

## 6. Verdict

There is **no prior real AUC to beat** — the retired model's number was
measured on emotion-proxy speech, not real breathing audio, so it isn't a
meaningful baseline. The real question per this task's scope: does a model
trained on genuinely real breathing-distress-adjacent audio show any real
discriminative signal at all?

**Answer: weakly yes.** AUC 0.5823 is above chance (0.50) with real,
non-trivial precision (0.63) at low recall (0.37) — some real signal, not
noise-level. It is **not** a strong or production-ready result (compare
Day 262's `mg_gunshot` fix, which reached AUC 0.92 on an equivalent real-data
swap) — FSD50K's `Breathing` label covers ordinary/ambient human breathing
sounds broadly, not specifically *distressed* breathing (panting/gasping
under duress vs. calm audible breathing are not separated by the label
itself), which likely caps how separable "distress" specifically is from
this label alone.

**Decision: keep `n_breathing_distress` retired from the active
`tflite_staging` set.** AUC 0.58 does not clear a usable-threshold bar (no
`find_optimal_threshold`-style operating point was attempted given the weak
separation). This is recorded as a real, modest, above-chance finding for a
future session to potentially build on (e.g. narrowing FSD50K's `Breathing`
label to only clips that co-occur with `Gasp`/`Pant`-like distress cues, or
combining with the NIGENS 4-clip pool as extra hard positives), not as a
shipped fix. No files were moved in/out of `tflite_staging/retired/` this
session — the Day 267 retirement stands.

## What was committed where

- `zapsafe_mobile` (`day276-breathing-distress` branch, fresh off `main`):
  this doc only (`assets/models/DAY276_BREATHING_DISTRESS_NIGENS.md`).
- `kaggle_notebooks` (standalone repo, `master`): `day104_adversarial_push/
  day104_audio_common.py` (+`collect_fsd50k_breathing_paths`),
  `day104_adversarial_push/day104_n_adversarial.py` (wired the new
  collector into `collect_n_data()`), new
  `day276_n_breathing_retrain_push/` (script, `kernel-metadata.json`, and
  the real report/training-log outputs — `.tflite`/`.h5` checkpoint files
  stay gitignored per this repo's existing convention), and `.gitignore`
  updated to un-ignore those specific files.
- Neither repo was pushed.
