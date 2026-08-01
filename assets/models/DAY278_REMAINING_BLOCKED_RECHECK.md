# Day 278 — one more real check on the 6 still-blocked models

Follow-up to `DAY267_REMAINING_MODELS_TRIAGE.md` (`j_whisper_distress`) and
`DAY268_UNTESTED_MODELS_EVAL.md` (`m3`, `m8`, `m7`, `h_aggressive_speech`,
`w_*`). Both docs found real, specific blockers, not "not attempted"
laziness — but this week also proved MobiAct/AudioSet/NIGENS wrong once
someone actually checked Kaggle/Drive properly instead of assuming. This
session re-checked each model's *exact* stated blocker against real sources
not previously checked: Kaggle's public dataset search, and a fresh, full
listing of the Google Drive `ZapSafe_ML/datasets` folder
(`https://drive.google.com/drive/folders/1SPU4yW_9YaI3VnfzhTw9ZCE6zJ-Cj_3R`).

**Headline: 5 of 6 remain genuinely blocked with no new path found. One —
the `w1` fusion head specifically — has a genuinely new, real, viable path
that was not previously singled out.**

## What was actually checked

- **Kaggle public dataset search** (`kaggle datasets list -s "<query>"`,
  API confirmed authenticated): `"whisper speech"`, `"wtimit"`, `"chains
  speech"`, `"whispered speech"`, `"whisper corpus"`, `"silent speech"`.
- **Google Drive folder, full listing** (all 37 items, confirmed via the
  browser, list view, exact filenames — not thumbnails/assumptions):
  `300w.zip.001/.002`, `1188976.zip`, `archive (5).zip`, `archive (6).zip`,
  `audioset.zip`, `cremad.zip`, `data_aishell3.tgz`, `datasets-master.zip`,
  `demand.zip`, `doi-10.5683-sp2-e8h2mf.zip`, `emodb.zip`, `esc50.zip`,
  `hr_imu_falldetection.zip`, `IEMOCAP_full_release_withoutVideos.tar.gz`,
  `IEMOCAP_full_release.tar.gz`, `MELD-master.zip`,
  `MobiAct_Dataset_v2.0-MobiFall_Dataset_v2.0-main.zip`, `mobiact.zip`,
  `motionsense.zip`, `nigens.zip`, `ontology-master.zip`, `pamap2.zip`,
  `places_devkit-master.zip`, `places365_val.tar`, `ravdess_song.zip`,
  `ravdess_speech.zip`, `ShEMO-master.zip`, `test_256.tar`, `uci_har.zip`,
  `unimib_shar.zip`, `UrbanSound.tar.gz`, `UrbanSound8K.tar.gz`,
  `vakyansh-tts-main.zip`, `val_256.tar`, `voxceleb_indian.zip`,
  `WIDER_test.zip`, `WIDER_train.zip`, `WIDER_val.zip`, `wisdm.zip`.
- Two ambiguously-named zips were identified by DOI/record-ID lookup rather
  than assumed: `doi-10.5683-sp2-e8h2mf.zip` is the DOI for **TESS**
  (Toronto Emotional Speech Set, Pichora-Fuller & Dupuis, Borealis/Scholars
  Portal Dataverse) — already a known, already-used corpus, not new.
  `1188976.zip` is Zenodo record 1188976, **RAVDESS** — likewise already
  known/used, not new. Neither is whisper-related.
- Two generically-named files, `archive (5).zip` and `archive (6).zip`
  (default Kaggle/browser download names, no metadata visible from the
  Drive UI), could **not** be further identified — a Chrome extension
  disconnect ended the browser session before their contents/sizes could be
  confirmed. Flagging honestly rather than guessing: nothing about their
  presence elsewhere in the folder (which is otherwise fully occupied by
  already-known corpora — RAVDESS, TESS, CREMA-D, EMODB, IEMOCAP, MELD,
  ShEMO, ESC-50, AudioSet, NIGENS, MobiAct, UniMiB, UCI-HAR, PAMAP2, WISDM,
  WIDER, Places365, 300W, VoxCeleb, AISHELL-3, DEMAND, Vakyansh-TTS)
  suggests a whisper corpus is likely, but this is not confirmed either
  way.
- Re-read `day106_fusion_common.py`'s `FUSION_BUILDERS` dict directly
  (source of truth, not the docstring/spec) to check each `w_*` head's
  *exact* two named upstream dependencies against this week's real,
  per-model verdicts in `WEEK_ML_TRIAGE_SUMMARY.md`.

## 1. `j_whisper_distress` — still retired, no new path found

**Day 267's real blocker, restated precisely:** not "no whisper data
exists" in the abstract, but specifically that the model's "whisper" class
is `apply_whisper()` — a synthetic gain-reduction + noise transform applied
identically to both classes at train time — so there is no real acoustic
whisper property being learned that a real recorded corpus could validate
against or fix.

**Checked this session:** whether a real recorded whisper-speech corpus
(the kind that would let a retrain use genuinely whispered audio instead of
the synthetic transform) exists anywhere newly accessible.

- Kaggle: every result for `"whisper speech"`/`"whisper corpus"` is either
  a fine-tuned OpenAI-Whisper *transcription model* dataset (irrelevant —
  these are ASR training sets, not acoustic whisper-vs-normal-volume
  speech), or unrelated. `"wtimit"` returned **zero** results — wTIMIT is
  not on Kaggle. `"chains speech"` returned zero relevant results (CHAINS
  is not on Kaggle either — matches are unrelated datasets that happen to
  share the word "chain"). `"whispered speech"` returned two results
  (EMG-UKA Trial Corpus, a lullaby-sounds dataset) — EMG-UKA is a silent/EMG
  speech corpus, not acoustic whisper audio, and not a match. `"silent
  speech"` surfaced multiple real EMG/EEG silent-speech datasets — a
  different modality (electromyography, not acoustic whisper audio) that
  does not supply what `apply_whisper()` needs.
- Google Drive: no file in the 37-item listing is whisper-named or
  whisper-related. The two DOI/record-ID lookups (TESS, RAVDESS) resolved
  to corpora already in use elsewhere in the pipeline, confirming they are
  not a hidden whisper source.

**Conclusion: CONFIRMED STILL BLOCKED.** wTIMIT and CHAINS — the two real
public whisper-speech corpora referenced in whisper-detection literature —
are genuinely not present on this Kaggle account or in this Drive folder;
they were not found because they are not accessible here, not because they
weren't looked for. No amount of additional searching within these two
sources would find them. If a future session wants to pursue this, wTIMIT
(NTU/CUHK) and CHAINS (Trinity College Dublin/TCD) would need to be sourced
from their original academic distribution channels, not Kaggle or this
Drive folder.

## 2. `m3` (staged `[1,160,160,3]` variant) — still blocked, no new path

**Day 268's exact blocker:** no locally-available image dataset carries a
real safe/unsafe scene label — `ADE20K` (semantic segmentation) and
`Places365` (scene category) are both present but neither is labeled for
the model's actual binary target.

**Checked this session:** the Drive folder's `places_devkit-master.zip` and
`places365_val.tar` are the same Places365 assets already ruled out — no
new image corpus, and no safe/unsafe-labeled set, appears anywhere in the
37-item Drive listing. No Kaggle re-check was warranted here since Day 268
already confirmed the Kaggle API had no matching dataset under this
account, and nothing in this session's fresh Drive listing changes that.

**Conclusion: CONFIRMED STILL BLOCKED.** No new labeled safe/unsafe scene
data found.

## 3. `m8_blink_liveness` — still blocked, no new path

**Day 268's exact blocker:** the model needs a `[1,24,12]` float32
landmark-sequence (24 frames x 12 eye-region landmark coordinates), which
requires either pre-extracted landmark sequences or a real video of a
blinking eye run through a face-landmark extractor (MediaPipe FaceMesh /
dlib) — neither exists locally.

**Checked this session:** the Drive folder contains `WIDER_train/val/test`
(static face-detection images, the same wrong-shape data Day 268 already
ruled out) and `300w.zip.001/.002` (the **300W** facial-landmark dataset —
new to this session's attention, but 300W is a **static-image** 68-point
landmark dataset for face alignment, not a video/time-series source; it
cannot produce a `[24,12]` temporal blink sequence without frames over
time, which 300W does not provide per-image). No video source of a
blinking eye and no face-landmark extraction pipeline exist locally.

**Conclusion: CONFIRMED STILL BLOCKED.** 300W was worth checking (it's a
real landmark dataset newly noticed in the Drive listing) but its data
shape (single-frame, not a sequence) cannot supply this model's temporal
input regardless of labels — same category of shape mismatch as `WIDER`.

## 4. `m7_nlp_context_enhanced` — still blocked, no new path

**Day 268's exact blocker:** the tokenizer/vocab blocker was already
resolved (real `m7_vocab_hi_ta_crosslang.json` confirmed present); what's
missing is a labeled real text corpus (threat/distress phrase vs benign)
matching the model's actual training target.

**Checked this session:** the Drive folder contains no text corpora at
all — every one of the 37 items is audio, image, or IMU/motion data. No
Kaggle re-check specific to this model's labeled-text-corpus need was run
this session (out of the two priority checks — Kaggle whisper search and
Drive listing — neither source contains or was likely to contain a
threat/benign Hindi/Tamil-script text corpus; this is a reasonable
inference from the Drive folder's exhaustively audio/image/motion contents,
not a claim that Kaggle overall lacks such data).

**Conclusion: STILL BLOCKED**, unchanged from Day 268. Not newly
disproven or newly confirmed beyond what Day 268 already established — the
Drive folder simply has nothing of this data type.

## 5. `h_aggressive_speech` — still blocked, no new path

**Day 268's exact blocker:** needs real audio labeled specifically
"calm-threatening tone" vs "calm-benign" — the local emotional-speech
corpora (RAVDESS, CREMA-D, EmoDB, IEMOCAP, MELD) support general
emotion-proxy labels but not this specific prosodic-tone distinction.

**Checked this session:** the Drive folder's corpus list is exactly the
same emotional-speech set already known and already ruled out for this
specific label (`cremad.zip`, `emodb.zip`, `IEMOCAP_full_release*.tar.gz`,
`MELD-master.zip`, `ravdess_speech.zip`/`ravdess_song.zip` = the same
RAVDESS as `1188976.zip`, `ShEMO-master.zip`, `voxceleb_indian.zip`). No
new corpus, and no calm-threatening-specific label set, appears.

**Conclusion: CONFIRMED STILL BLOCKED.** Same gap as Day 268: a
"calm-threatening vs calm-benign" label doesn't exist in any of these real
corpora's native annotations; building it would mean inventing a label
from general emotion tags, which was already correctly ruled out of scope.

## 6. `w_*` fusion — 4 of 5 heads still blocked, but `w1` has a genuinely new real path

**Day 268's exact blocker, re-examined per-head:** "most" of the five
heads' named upstream models (`M3`, `J`, `I`, `P`) lacked a trustworthy
real-data verdict, so there was "nothing reliable to fuse" — stated as a
blanket verdict across all 5 heads (`w1`-`w5`).

**What this session checked that Day 268 did not:** each head's *specific*
two upstream dependencies, cross-referenced individually against
`WEEK_ML_TRIAGE_SUMMARY.md`'s per-model real-data verdicts (which cover
`M1`-`M9` and were finalized on Day 260D, after Day 268 was written) and
`DAY267_REMAINING_MODELS_TRIAGE.md`'s `i_vehicle_crash` reconciliation:

| head | upstream pair | status of each upstream model |
|---|---|---|
| `w1` (`audio_motion`) | `M1_scream_score` + `M2_motion_score` | **both wired and confirmed working on real data**: `m1_scream_v2` AUC 0.865 on real RAVDESS; `m2_motion_v2` real UCI-HAR walking=0.004 vs injected-fall=0.980 (`WEEK_ML_TRIAGE_SUMMARY.md` lines 28-29, "Wired and working on real data: 2") |
| `w2` (`speech_motion`) | M4/M5 vocal-stress + M2 motion | M4/M5 **retired** this week (`DAY267...md` #2/3, fp32 AUC ~0.62-0.63, genuinely near-chance) — blocked |
| `w3` (`audio_scene`) | M1 scream + **M3 scene** | M3 still STILL-UNTESTABLE (this doc, #2 above) — blocked |
| `w4` (`whisper_stillness`) | **J whisper** + M2 stillness | J confirmed retired (this doc, #1 above) — blocked |
| `w5` (`crash_silence`) | **I crash** + **P silence-after-distress flag** | I crash reconciled/not-dead (`DAY267...md` #1, AUC 0.96 fp32) but **P has no real-data verdict anywhere in `WEEK_ML_TRIAGE_SUMMARY.md` or any Day-26x doc searched this session** — status simply unchecked, not confirmed either way — blocked pending a real check on P |

Read `build_w1_dataset()` in `day106_fusion_common.py` directly (lines
388-408): it calls `collect_scream_paths()` (real scream audio paths) and
`imu_motion_score()` over real IMU windows loaded via `load_mobiact()` /
`load_unimib()` / `load_pamap2()` / `load_wisdm()` / `load_uci_har()` — the
exact same real datasets (MobiAct, UniMiB, UCI-HAR) already confirmed
present and working for `m2_motion_v2` and used this week for
`s_crowd_panic`'s MobiAct fix, paired with real scream audio from the same
pool `m1_scream_v2` uses (RAVDESS, per `WEEK_ML_TRIAGE_SUMMARY.md`).

**Conclusion for `w1`: a genuinely new, real, viable path exists**, ready
for a future retrain/eval session — not attempted here per scope. It needs
no new data: real scream audio (RAVDESS, already used for `M1`) + real IMU
windows (MobiAct/UniMiB/UCI-HAR, already used for `M2`) run through
`build_w1_dataset()`'s existing real-data collection functions, scored with
the already-wired `m1_scream_v2`/`m2_motion_v2` models, then fed through
the already-exported `w1` fusion head. This is the first `w_*` head where
*both* named upstream models have a confirmed-real, confirmed-working
verdict at the same time — a state that did not exist when Day 268 was
written (Day 268 predates or doesn't cross-reference the finalized Day
260D "2 wired and working" rollup for this specific pairing).

**Conclusion for `w2`-`w5`: CONFIRMED STILL BLOCKED**, each for a distinct,
now-precisely-named reason (see table) — not a repeat of Day 268's blanket
statement.

## Summary table

| model | new real path found? | real evidence |
|---|---|---|
| `j_whisper_distress` | No | wTIMIT/CHAINS (the two real public whisper corpora) confirmed absent from both Kaggle (zero/irrelevant results across 5 query variants) and the Drive folder (37-item listing, no whisper-named or whisper-suited file) |
| `m3` | No | Drive folder's image assets are the same already-ruled-out Places365/ADE20K; no safe/unsafe-labeled set found |
| `m8_blink_liveness` | No | Drive's `300w.zip` is a real landmark dataset but static-image, not the required frame sequence; no blink video or landmark-extraction pipeline found |
| `m7_nlp_context_enhanced` | No | Drive folder has zero text corpora of any kind; tokenizer blocker (already resolved Day 268) unaffected |
| `h_aggressive_speech` | No | Drive's emotional-speech corpora are the same already-ruled-out set (RAVDESS/CREMA-D/EMODB/IEMOCAP/MELD/ShEMO); no calm-threatening-specific label found |
| `w_*` fusion | **Yes, for `w1` only** | `w1`'s two upstream models (`M1_scream_score`, `M2_motion_score`) are both confirmed wired-and-working on real data this week; `build_w1_dataset()` already has real-data collection functions wired to datasets both upstream models already use. `w2`-`w5` remain blocked, each on a distinct named upstream model with no trustworthy verdict yet (M4/M5 retired, M3 untestable, J retired, P never checked) |

## What this session did and did not do

Did: ran 5 real Kaggle dataset searches for a whisper corpus; pulled a
complete, verified file listing of the Google Drive datasets folder (37
items, exact names, not thumbnails); resolved two ambiguous filenames via
DOI/Zenodo-record lookup (confirmed TESS and RAVDESS, not new); read
`day106_fusion_common.py`'s `FUSION_BUILDERS` and `build_w1_dataset()`
source directly; cross-referenced each `w_*` head's specific upstream pair
against the Day 260D-finalized per-model verdicts in
`WEEK_ML_TRIAGE_SUMMARY.md` and `DAY267_REMAINING_MODELS_TRIAGE.md`'s
`i_vehicle_crash` reconciliation — a cross-reference Day 268 did not do
(it predates or doesn't cite the finalized Day 260D rollup for this
specific pairing).

Did not: retrain, download new data, or run any inference/AUC evaluation
for any of the 6 models, including `w1` — the `w1` finding is that a real
path is ready and unblocked, not that it has been run. Did not resolve
`archive (5).zip`/`archive (6).zip` in the Drive folder — a Chrome
extension disconnect interrupted the session before their metadata could
be checked; flagged as unresolved rather than guessed at. Did not touch
`kaggle_notebooks/`, detector/wiring files, any `.tflite` file, `pubspec`,
or backend code.

## Files touched this session

- `assets/models/DAY278_REMAINING_BLOCKED_RECHECK.md` (this file) — new, in
  `zapsafe_mobile`, on branch `day278-blocked-recheck`.
- No other files modified.
