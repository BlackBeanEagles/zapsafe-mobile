# Day 267 — triage of the 6 remaining flagged-weak staged models

Scope: the 6 models this week's real-data triage flagged as below-chance or
unusably weak but had not yet gotten a retrain/retire decision:
`m4_vocal_stress_adversarial`, `m5_vocal_stress_adversarial`,
`n_breathing_distress` (+f32), `j_whisper_distress`, `i_vehicle_crash`
(+f32), `mg_gunshot_f32`. Per-model training scripts read from
`kaggle_notebooks/` (this machine's standalone repo, not tracked from
`zapsafe_mobile`); real local datasets used for verification live under
`C:\Users\hridy\Desktop\zapsafe\ml_datasets\`. Scripts that produced every
number below: `tools/day260_ml_triage/test_i_vehicle_crash.py` and
`tools/day260_ml_triage/test_m4_m5.py` (new today, same pattern as Day
260's `check_fp32_vs_int8.py`).

## Decisions at a glance

| model | decision | real evidence |
|---|---|---|
| `i_vehicle_crash` / `i_vehicle_crash_f32` | **NOT retired — harness bug found, reconciled** | dual-input model, undocumented `imu_window` second input; AUC recovers to 0.96 (fp32) / 0.87 (int8) with both real inputs supplied |
| `m4_vocal_stress_en_adversarial` | retired | fp32 AUC 0.629 ≈ int8 AUC 0.626, medians ~0.003 apart — genuine fp32-level near-chance, not quantization |
| `m5_vocal_stress_apac_adversarial` (+f32) | retired | fp32 AUC 0.614 ≈ int8 AUC 0.618, medians ~0.005 apart — same as m4 |
| `n_breathing_distress` (+f32) | retired | positive class is emotion-proxy speech, not real breathing audio; no unused local real breathing-distress data found |
| `j_whisper_distress` (crosslang base + adversarial_f32) | retired | whisper class is a synthetic gain/noise augmentation of the same speech corpora already used everywhere; no real recorded whisper-distress dataset available locally |
| `mg_gunshot_f32` | retired | confirmed stale leftover from the pre-fix (day89/day104-era) export — distinct file from the shipped `mg_gunshot.tflite` (AUC 0.9225, from `day262`'s retrain) |

---

## 1. `i_vehicle_crash` / `i_vehicle_crash_f32` — reconciled, not dead

**Training script:** `kaggle_notebooks/i_vehicle_crash_push/day91_i_vehicle_crash.py`
(later hard-mined/re-exported under `day107_hardmine_int4_push`, same
architecture). Dual-input fusion: `audio_mel` [1,64,64,3] (mel-spectrogram)
+ `imu_window` [1,128,6] (raw accel+gyro). Positive/negative audio and IMU
are collected **independently** (FSD50K/AudioSet crash-proxy audio vs.
UrbanSound8K/ESC-50 vehicle audio for the audio branch; UCI-HAR/MobiAct
windows vs. the same windows run through the script's own
`inject_crash_spike()` for the IMU branch) and then **randomly paired by
label** (`build_paired()`, "modalities unpaired in data" per the script's
own comment) — so the model can key on either branch.

**Hypothesis (matching this week's established pattern):** Day 259's
64x64-mel-family harness tested this model the same way it tested the
single-input image models — feeding only `audio_mel` and leaving
`imu_window` unset. `interpreter.get_input_details()` confirms this model
has a second real input, exactly the bug class already found and fixed for
`k_confinement` (`light`) and `s_crowd_panic_*` (`mel`) in
`DAY260B_HIDDEN_INPUT_CHECK.md`.

**Test:** real ESC-50 `glass_breaking`+`thunderstorm` clips as a crash-audio
proxy (no dedicated crash class exists in local ESC-50) vs. real
`car_horn`/`engine`/`train` clips as vehicle-audio negatives, paired with
real UCI-HAR IMU windows — negatives left unmodified, positives run through
the model's own `inject_crash_spike()`. Compared against a Day-259-style
replica where `imu_window` is left at zeros instead of the real matched
value.

```
int8 staged -- BOTH real inputs matched: AUC=0.8733 (pos median 0.5039, neg median 0.5000)
int8 staged -- audio real, imu=zeros (Day259-style):  AUC=0.7800
fp32 staged -- BOTH real inputs matched: AUC=0.9622 (pos median 0.5051, neg median 0.5006)
fp32 staged -- audio real, imu=zeros (Day259-style):  AUC=0.8200
```

**Conclusion:** setting the real second input recovers real, usable
separation (AUC 0.96 fp32 / 0.87 int8) — a meaningfully different, better
result than the constant-zero replica of Day 259's harness. This is a
harness/wiring bug, not a training-data problem, and matches the
`k_confinement`/`s_crowd_panic` pattern exactly. **Not retired.** Flagging
for whoever eventually wires this model: it must be fed both
`audio_mel` and `imu_window` real tensors, matched to the same physical
event, or its output is meaningless (same lesson as the other two
dual-input IMU models). No files moved for this model; it remains in the
active `tflite_staging` directory.

---

## 2/3. `m4_vocal_stress_en_adversarial` and `m5_vocal_stress_apac_adversarial` (+f32) — retired

**Training scripts:** `kaggle_notebooks/day104_adversarial_push/day104_m4_adversarial.py`
/ `day104_m5_adversarial.py`, forked from `day101_sweep_push`'s original
recipe. Positives = RAVDESS(stress codes)/CREMA-D(SAD,ANG,FEA,DIS)/EmoDB/
IEMOCAP/MELD "stressed" emotion labels; negatives = calm/neutral/happy from
the same corpora + VoxCeleb. `ZAPSAFE_ADVERSARIAL=1` mode applies heavy
white/pink noise masking (SNR -15..0 dB, 85% noise probability) to both
classes. Both are single-input mel models — confirmed via
`interpreter.get_input_details()` (`mel_input` only, no hidden second
tensor), so this is not the `i_vehicle_crash`-style bug.

**Hypothesis tested:** Day 259 diagnosed `m4`/`m5` as "pos/neg medians
identical — quantisation noise, not signal" (AUC 0.667 for both). Checked
whether the pre-quantization fp32 checkpoint shows real separation that
int8 export collapsed (the `m1_pocket_muffled` pattern) or whether fp32
itself is already this weak (the `mg_gunshot`/`m_glass_breaking` pattern).

**Test:** real CREMA-D audio (7,442 real clips available locally at
`ml_datasets/vocal_stress/DS01_RAVDESS/Crema`), labelled with the training
script's own `collect_cremad` filter (SAD/ANG/FEA/DIS positive,
NEU/HAP negative), n=40/40, run through both the staged int8 files and the
fp32 checkpoints (`m4`: `day104_adversarial_push/day104_adversarial_kaggle_output/saved/adversarial/day104_production/m4/m4_vocal_stress_en_adversarial_f32.tflite`;
`m5`: the f32 file already in `tflite_staging`).

```
m4 int8 staged:  AUC=0.6262  pos median=0.5078 (n=40)  neg median=0.5039 (n=40)
m4 fp32 (day104_production): AUC=0.6288  pos median=0.5069  neg median=0.5037
m5 int8 staged:  AUC=0.6175  pos median=0.5059  neg median=0.5000
m5 fp32 staged:  AUC=0.6144  pos median=0.5054  neg median=0.5007
```

**Conclusion:** fp32 and int8 are within ~0.003 AUC of each other for both
models, and the pos/neg medians are only ~0.003–0.006 apart in fp32 too —
confirms this is **not** a quantization collapse; the fp32 checkpoint is
itself already barely separable. Day 259's "quantisation noise" framing was
imprecise (same correction direction as `DAY266_SEVEN_CONSTANT_MODELS_ROLLUP.md`
made for `mg_gunshot`/`m_glass_breaking`), but the practical verdict
(unusable) stands either way.

**Real candidate fix found but NOT executed this session:** `day104_m4/m5_adversarial.py`
do not use several real emotional-speech corpora that ARE present locally
and unused by these specific scripts — TESS (2,800 real clips,
`ml_datasets/vocal_stress/DS01_RAVDESS/Tess`), SAVEE (480 real clips,
same root, `Savee/`), the proper RAVDESS actor-speech set (1,440 real
clips, `Ravdess/audio_speech_actors_01-24`, distinct from the CREMA-D-named
folder these scripts currently draw from), and ShEMO (real
`male.zip`/`female.zip` present at `ml_datasets/vocal_stress/DS_ShEMO/ShEMO-master/`,
but explicitly zeroed out in `day104_m4_adversarial.py`:
`stats["shemo"] = {"pos": 0, "neg": 0}`, unlike the Day 101 predecessor
which did use it). Checked `DS_MSP_IMPROV` too — that one actually has no
local data (empty directory), so it is not a real option. Adding the three
genuinely-present-but-unused sources (TESS/SAVEE/RAVDESS-proper) plus
re-enabling ShEMO is a concrete, locally-available fix path, structurally
the same kind of fix as `mg_gunshot`'s "add real hard-negative categories."
It was **not executed this session** — actually running it requires a full
Kaggle GPU retrain cycle (comparable in scope to the `day261`/`day262`
`mg_gunshot`/`m_glass_breaking` pushes, each of which took its own
dedicated session), which this pass did not have room for. Per the standing
rule ("don't force a retrain without completing and verifying it"), this is
retired now rather than claimed fixed on the strength of an untested plan.
**Flagging as a real, well-scoped follow-up for a future session**, not a
dead end like `n_breathing_distress`/`j_whisper_distress` below.

Files moved to `retired/`: `m4_vocal_stress_en_adversarial.tflite`,
`m5_vocal_stress_apac_adversarial.tflite`,
`m5_vocal_stress_apac_adversarial_f32.tflite`.

---

## 4. `n_breathing_distress` (+f32) — retired

**Training script:** `kaggle_notebooks/day104_adversarial_push/day104_n_adversarial.py`.
Positives = RAVDESS/CREMA-D(ANG,FEA,DIS,SAD)/IEMOCAP/ShEMO "distress"
emotion-speech labels **plus** real ESC-50 `breathing`/`snoring` category
clips (`collect_esc50(categories={"breathing", "snoring"})`); negatives =
calm speech + VoxCeleb + UrbanSound8K hard classes. `pos_aug="gasp"`
overlays a synthetic burst/gap gasping pattern on top.

**Hypothesis:** like `m_glass_breaking`'s original diagnosis (thin real
positive class — the model mostly trains on emotional-speech-as-proxy, not
real distressed-breathing recordings), this model's real positive class is
dominated by generic emotional speech, with only a small slice of genuine
breathing audio from ESC-50's `breathing`/`snoring` categories (2 ESC-50
categories, 40 clips each at most).

**What was checked for a real local fix:** searched
`C:\Users\hridy\Desktop\zapsafe\ml_datasets\` for any dedicated real
breathing/gasping/respiratory-distress dataset not already in use — found
none. NIGENS (which does contain a real "Breathing" sound-event class) is
listed in the ML dataset day plan as **reserved for Day 84+, not
downloaded locally** (`kaggle_input_roots()`'s `nigens` role only resolves
on Kaggle's sidebar, not on this machine). `m_glass_breaking`'s Day 262 fix
used real NIGENS data — but that was pulled from Kaggle's sidebar mount
during a live Kaggle run, not from a local cache; this machine has no local
NIGENS copy to test or retrain against.

**Conclusion:** this matches `m_glass_breaking`'s "readily available real
data exhausted" pattern exactly — every real local audio-emotion corpus is
already in use for the positive class, and the one dataset genuinely suited
to fix the underlying label problem (NIGENS's real breathing sounds) is not
locally available for this machine to use outside a live Kaggle session.
Not chasing a retrain without a concrete, checkable-today data source.
**Retired.**

Files moved to `retired/`: `n_breathing_distress.tflite`,
`n_breathing_distress_f32.tflite`.

---

## 5. `j_whisper_distress` — retired (both `bn_ur_ar_crosslang` and `adversarial_f32`)

**Training script:** `kaggle_notebooks/day104_adversarial_push/day104_j_adversarial.py`
(cross-lingual variant staged as `j_whisper_distress_bn_ur_ar_crosslang`;
adversarial noise variant staged as `j_whisper_distress_adversarial`/`_f32`).
Positives/negatives = the same RAVDESS/CREMA-D/EmoDB/IEMOCAP/MELD
emotion-speech pool used by `m4`/`n`, but with `apply_whisper()` — a purely
synthetic gain-reduction (10%) + low-level noise transform — applied to
**both** classes, so the model is trained to discriminate distress-vs-calm
strictly inside whispered/quiet audio it never actually heard recorded as
whispered speech.

**Day 259 evidence:** `j_whisper_distress_bn_ur_ar_crosslang` AUC 0.613,
"recall 64% costs FPR 52% — no usable threshold";
`j_whisper_distress_adversarial_f32` AUC 0.437, "worse than chance."

**What was checked for a real local fix:** no real recorded whisper/quiet-
distress-speech dataset exists locally or is referenced anywhere in
`kaggle_notebooks/` — the "whisper" class is entirely synthetic
post-processing of ordinary-volume emotional speech, applied identically at
train and (implicitly) test time. Unlike `m4`/`m5`, there is no unused real
corpus that would change the fundamental issue: `apply_whisper()`'s gain
reduction is not an acoustically faithful whisper simulation, and no amount
of additional ordinary-volume emotional speech fixes that gap.

**Conclusion:** the positive/negative distinction this model is trained on
does not correspond to any distinguishable real acoustic property once
passed through the same synthetic whisper transform on both sides — this
is a training-methodology problem, not a data-volume problem, and no local
data addition resolves it. **Retired**, both variants.

Files moved to `retired/`: `j_whisper_distress_adversarial.tflite`,
`j_whisper_distress_adversarial_f32.tflite`,
`j_whisper_distress_bn_ur_ar_crosslang.tflite`,
`j_whisper_distress_bn_ur_ar_crosslang_f32.tflite`.

---

## 6. `mg_gunshot_f32` — retired (stale leftover, distinct from the shipped fix)

Verified directly, not assumed: the shipped, fixed `mg_gunshot.tflite`
(int8, AUC 0.9225, per `DAY262B_AUDIOSET_RERUN.md` /
`DAY262C_GUNSHOT_MODEL_UPGRADE.md`) comes from
`kaggle_notebooks/day262_m_glass_breaking_retrain_push/` and
`day261_mg_gunshot_retrain_push/kaggle_output/mg_gunshot_retrain_report.json`
(AUC progression 0.8913 → 0.9225 documented there). The `mg_gunshot_f32.tflite`
sitting in `tflite_staging/` is a **different, older file** (9,516,432
bytes) — the pre-fix fp32 export, from before the day261/262 retrain,
already shown to be near-chance in `DAY260_QUANTIZATION_ROOTCAUSE.md`
Finding 2 (fp32 AUC 0.538 on real AudioSet gunshot audio). It was never
updated after the retrain and has no reason to remain in the active
triage/staging path next to the now-correct `mg_gunshot.tflite`. **Retired**
as a stale leftover — not a new finding, just cleanup.

Files moved to `retired/`: `mg_gunshot_f32.tflite`.

---

## Where files were moved

All retirements above moved `.tflite` files (no `.tflite` files were
deleted) from
`kaggle_notebooks/day108_int4_m9_push/day108_kaggle_output/saved/int4_m9/day108-int4-m9-kaggle-20260703-v5-production/tflite_staging/`
into a new `retired/` subfolder at that same path — the canonical staging
directory this week's Day 260 scripts (`check_fp32_vs_int8.py`'s `STAGE`
constant) already point to. This directory (like the rest of
`day108_int4_m9_push/`'s generated output trees) is untracked/gitignored in
the `kaggle_notebooks` repo, so the move itself produces no git diff there
— confirmed via `git status` before and after, both clean. `i_vehicle_crash*`
and the now-correct `mg_gunshot.tflite` were left in place, untouched.

## What was committed where

- `zapsafe_mobile` (`day258-ml-wiring` branch): this doc
  (`assets/models/DAY267_REMAINING_MODELS_TRIAGE.md`) plus the two new
  reproduction scripts and a rollup note under
  `tools/day260_ml_triage/` (`test_i_vehicle_crash.py`, `test_m4_m5.py`,
  `check_day267_remaining.py`).
- `kaggle_notebooks` (standalone repo): no commit — the only filesystem
  change (moving 10 stale `.tflite` files into `retired/`) landed in an
  already-untracked/gitignored directory tree, confirmed via `git status`
  showing no changes before or after the move.
- Neither repo was pushed.
