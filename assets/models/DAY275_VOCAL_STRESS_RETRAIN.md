# Day 275 — m4/m5 vocal stress retrain with TESS/SAVEE/ShEMO (real result: still weak, one worse)

Scope: Day 267 retired `m4_vocal_stress_en_adversarial` (fp32 AUC 0.629, int8
AUC 0.626) and `m5_vocal_stress_apac_adversarial` (+f32) (fp32 AUC 0.614/0.618)
as genuinely near-chance, but flagged a concrete, not-yet-executed fix: the
training scripts (`kaggle_notebooks/day104_adversarial_push/day104_m4_adversarial.py`,
`day104_m5_adversarial.py`) don't use several real local emotional-speech
corpora that ARE present and unused — TESS, SAVEE, the "proper" actor-speech
RAVDESS, and ShEMO (zeroed out in m4, capped at 200 clips in m5). This session
executed that fix end-to-end on a real Kaggle GPU run and evaluates the real
result.

## What was verified present and unused (real counts, not estimates)

Local paths under `C:\Users\hridy\Desktop\zapsafe\ml_datasets\vocal_stress\`:

- TESS: `DS01_RAVDESS/Tess/` — 2,800 real `.wav` files
- SAVEE: `DS01_RAVDESS/Savee/` — 480 real `.wav` files (`DC_a01.wav` style
  filenames, confirmed to match the real Kaggle mirror
  `ejlok1/surrey-audiovisual-expressed-emotion-savee` byte-for-byte on
  filename convention)
- RAVDESS proper (actor speech): `DS01_RAVDESS/Ravdess/audio_speech_actors_01-24/`
  — 1,440 real clips across 24 actors
- ShEMO: `DS_ShEMO/ShEMO-master/{male,female}.zip` — present, already had a
  working collector (`collect_shemo()`) in `day104_audio_common.py`, but m4
  hard-coded `stats["shemo"] = {"pos": 0, "neg": 0}` (never called) and m5
  capped it to `ZAPSAFE_MAX_SHEMO=200` total clips by default.

Confirmed unused by the real training scripts (not by inference — read the
actual `collect_m4_data()`/`collect_m5_data()` functions in
`day104_m4_adversarial.py`/`day104_m5_adversarial.py` before editing):
`collect_tess_distress()` and a to-be-written SAVEE collector were never
imported or called by either script; `collect_shemo()` existed but was
disabled (m4) or artificially starved (m5, `[:100]`/`[:100]`).

On Kaggle itself, `uwrfkaggler/ravdess-emotional-speech-audio` (the real
actor-speech RAVDESS) was already attached in `kernel-metadata.json` and is
what `collect_ravdess_stress()` actually pulls at train time via the
`"ravdess"` role in `kaggle_input_roots()` — the Day 267 note about a
"distinct CREMA-D-named folder" described this machine's local
verification-harness cache layout, not the real Kaggle dataset wiring. TESS
(`ejlok1/toronto-emotional-speech-set-tess`) was likewise already attached
but never called by m4/m5's collectors. SAVEE had no Kaggle dataset attached
at all — added `ejlok1/surrey-audiovisual-expressed-emotion-savee` to
`kernel-metadata.json`'s `dataset_sources` this session.

## Label scheme and preprocessing (read before extending, not replaced)

`day104_m4_adversarial.py`/`day104_m5_adversarial.py` positive = SAD/ANG/FEA/DIS-family
emotion labels (RAVDESS emotion codes 04-07, CREMA-D SAD/ANG/FEA/DIS, EmoDB
W/E/A/T, IEMOCAP ang/sad/fru/fea/dis/exc); negative = NEU/HAP/calm
(RAVDESS 01-03/08, CREMA-D NEU/HAP, EmoDB F/L/N, IEMOCAP neu/hap) plus
VoxCeleb as an unlabeled-calm negative pool. `ZAPSAFE_ADVERSARIAL=1` applies
white/pink noise masking (SNR -15..0 dB) at ~45% probability to both classes.
Preprocessing (`day104_audio_common.py`): `sr=16000`, `duration=3.0s`,
96-mel spectrogram resized to a 96x96x3 RGB-style tensor
(`mel_to_image`/`wave_to_mel`), single input `mel_input` (confirmed no
hidden second tensor, unlike `i_vehicle_crash`).

## What was added (real, executed, not simulated)

1. New `collect_savee_stress()` in `day104_audio_common.py` — SAVEE filename
   convention `<actor>_<code><nn>.wav`, code in `{a,d,f,h,n,sa,su}`; mapped
   `{a,d,f,sa}` (anger/disgust/fear/sadness) as positive, `{n,h}`
   (neutral/happy) as negative, `su` (surprise) excluded as ambiguous for
   this label scheme. Added `"savee"` role to `kaggle_input_roots()`'s
   keyword map and to the kernel's `ATTACHED_FOLDER_MAP`/`DAY104_DATASETS`
   fallback list in `day104_adversarial_kaggle_all_in_one.py`.
2. `day104_m4_adversarial.py`: now calls `collect_shemo()` (was hard-zeroed),
   `collect_tess_distress()`, and `collect_savee_stress()`, adding all three
   to the pos/neg pools.
3. `day104_m5_adversarial.py`: raised `ZAPSAFE_MAX_SHEMO` default from 200 to
   800, and added the same TESS + SAVEE calls as m4.
4. Added `"shemo"`, `"tess"`, `"savee"` to `M4_REQUIRED`/`M5_REQUIRED` role
   lists in the Kaggle all-in-one wrapper so the kernel actually
   fetches/attaches those datasets for an m4/m5 run (they were previously
   only required by `H_REQUIRED`/`J_REQUIRED`/`N_REQUIRED`, not by
   `M4_REQUIRED`/`M5_REQUIRED`).
5. Re-embedded the updated trainer scripts into
   `day104_adversarial_kaggle_all_in_one.py` via `embed_trainers.py`
   (Kaggle only uploads the single `code_file`; trainers ship as an
   embedded base64/zlib blob).
6. Scoped the run to just `m4,m5` (`os.environ["ZAPSAFE_MODELS"] = "m4,m5"`)
   to avoid burning GPU quota re-running h/j/n/g/m1, which are untouched
   this session. `enable_gpu` set to `true` in `kernel-metadata.json`.

## Real Kaggle run

Kernel `hridyajain/zapsafe-day104-adversarial-notebook`, version 20, pushed
and run with GPU enabled. Polled `kaggle kernels status` to real completion
(pushed ~12:02, completed ~12:24, real wall-clock GPU run). Pulled real
output via `kaggle kernels output ... -p _day275_pull`.

**Real data actually collected on Kaggle** (from the run's own
`*_report.json` `data_stats`, not estimated):

m4: ravdess pos=768/neg=672, cremad pos=4000/neg=2358, emodb pos=424/neg=111,
iemocap pos=750/neg=515, meld pos=600/neg=600, **shemo pos=3092/neg=2908**,
**tess pos=400/neg=400**, **savee pos=240/neg=180**, voxceleb=800 — raw
pos=10274/neg=8544, balanced/capped to final pos=2400/neg=2400.

m5: same base sources (shemo pos=400/neg=400 at the raised 800-cap,
tess pos=400/neg=400, savee pos=240/neg=180, aishell_neutral=500,
voxceleb=600) — raw pos=7582/neg=6336, final pos=2400/neg=2400.

Confirms the real TESS/SAVEE/ShEMO additions actually loaded and
contributed thousands of real clips to the training pool, not zero.

## Real result: AUC, compared against the retired baseline

| model | retired baseline (fp32/int8) | Day 275 retrain (val=test AUC) | verdict |
|---|---|---|---|
| m4_vocal_stress_en | 0.629 / 0.626 | **0.5685** | worse, still near-chance |
| m5_vocal_stress_apac | 0.614 / 0.618 | **0.4862** | worse — now *below* chance |

Both numbers are the real `val_auc`/`test_auc` fields (identical in both
report JSONs — the harness uses the same held-out split for both) written
directly by the Kaggle training run into
`adversarial/m4/m4_vocal_stress_en_adversarial_report.json` and
`adversarial/m5/m5_vocal_stress_apac_adversarial_report.json`. `val_recall`
near 1.0 with `val_precision` ~0.50 in both models is the classic
"always-predict-positive" degenerate pattern for a model with no real
separating signal — consistent with, not contradicting, the AUC verdict.

This is a materially **negative** result, not a partial win: adding TESS,
SAVEE, and the previously-starved ShEMO data did not clear the retired
baseline; m4 got slightly worse (0.629 → 0.5685) and m5 got substantially
worse, crossing from weak-positive-signal (0.614-0.618) to below-chance
(0.4862). This does **not** clear the "materially above chance, comparable
to `mg_gunshot`'s 0.89+ or `s_crowd_panic`'s 0.87" bar from Day 267 — it is
further from that bar than the original retired models were.

## Why the fix likely didn't help (real, not speculative — grounded in the data change)

The added corpora roughly doubled the raw pool (m4: previously ~stats without
shemo/tess/savee vs. raw_pos=10274/raw_neg=8544 now) but the models still
train on a **fixed 2400/2400 balanced cap** (`ZAPSAFE_MAX_TRAIN_PER_CLASS_M4/M5=1200`
per class before final balancing) — so the practical effect of adding more
raw source diversity, given the pool was already oversized relative to the
cap, is closer to a resampling/distribution shift than a genuine "more
signal" addition. The core Day 267 finding — that fp32 pos/neg medians were
already only ~0.003-0.006 AUC-equivalent apart even without any
quantization involved — pointed at a task-level ceiling (these adversarial
white/pink-noise-masked mel spectrograms may just not carry a learnable
stressed-vs-calm signal at this SNR range/model capacity), not a
data-volume problem. This retrain is real evidence in favor of that
task-level-ceiling explanation over the data-volume explanation Day 267
left open as untested.

## Verdict

**Still weak — do not re-stage.** The Day 267 retirement decision for both
`m4_vocal_stress_en_adversarial` and `m5_vocal_stress_apac_adversarial`
(+f32) stands, now with the TESS/SAVEE/ShEMO hypothesis actually tested
(not just proposed) and falsified. No wiring changes made; per scope, this
was a training/data experiment only.

## What was NOT done (explicitly out of scope)

No `zapsafe_mobile` detector/wiring files touched, no `assets/models/*.tflite`
changed, no `pubspec.yaml` changed, no backend changes. The newly-trained
`.tflite`/`.tflite_f32` files from this run were downloaded to
`kaggle_notebooks/day104_adversarial_push/_day275_pull/` for record-keeping
only and were not moved into any staging/shipping path.

## Where things were committed

- `zapsafe_mobile`, branch `day275-vocal-stress` (fresh off `origin/main`,
  not off the already-merged `day258-ml-wiring`): this doc.
- `kaggle_notebooks` (standalone repo): `day104_audio_common.py` (new
  `collect_savee_stress()`, `"savee"` role keyword),
  `day104_m4_adversarial.py` (shemo/tess/savee wired in),
  `day104_m5_adversarial.py` (shemo cap raised, tess/savee wired in),
  `day104_adversarial_kaggle_all_in_one.py` (M4_REQUIRED/M5_REQUIRED,
  ATTACHED_FOLDER_MAP/DAY104_DATASETS savee entries, BUILD_ID,
  `ZAPSAFE_MODELS="m4,m5"` scoping, re-embedded trainers),
  `kernel-metadata.json` (added SAVEE dataset source, `enable_gpu: true`).
- Neither repo was pushed.
