# Day 310: h_aggressive_speech — real access-request checklist (GEMEP / K-EmoCon / EAV) + pipeline prep

Context: Day 309 (`assets/models/DAY309_SPECIFIC_CANDIDATES_CHECK.md`) identified two
real, content-relevant, access-gated leads for `h_aggressive_speech`'s calm-but-menacing
register gap — K-EmoCon and EAV, both Zenodo-restricted — plus the project owner
independently flagged GEMEP (unige.ch/cisa/gemep), which has an explicit **"cold anger"**
category distinct from "hot anger," a closer match to the "calm-threatening tone" target
than any acted-shouting corpus already tried. This session does **no new dataset search**.
It (1) verifies the exact, real, live access-request process for all three — visited
directly in-browser, not guessed — so the project owner can submit all three requests
today, and (2) prepares the actual `h_aggressive_speech` training script with
clearly-marked placeholder loaders so whoever picks this up after approval only has to
implement one real function per dataset, not rebuild the pipeline.

## PART 1 — Access-request checklist (submit-ready, verified live 2026-08-06)

### 1. GEMEP (unige.ch/cisa/gemep) — email + signed PDF form, NOT an online portal

Verified by loading `https://www.unige.ch/cisa/gemep` directly.

**What it is**: GEneva Multimodal Emotion Portrayals — 10 actors portraying **18
affective states** (audio+video), created by Klaus Scherer & Tanja Bänziger at CISA/UNIGE.
Confirmed via the corpus's own primary paper (Bänziger, Mortillaro, & Scherer, 2012,
*Emotion* 12(5), 1161-1179) and cross-referenced search results: the 18 states explicitly
include **both "hot anger" and "cold anger" (irritation) as separate categories** — cold
anger is the calm-controlled-tone register this project's `h_aggressive_speech` model has
never had real training data for (current positive class is all acted shouting/hot-affect:
RAVDESS/CREMA-D/EmoDB/IEMOCAP "angry", see Part 2 below).

**Real corpus facts** (from the corpus page + Bänziger et al. 2012):
- **145 audio-video files** in the "GEMEP Core Set" (the publicly-requestable subset).
- Verbal content per portrayal: **two standard (pseudo-linguistic/meaningless) sentences
  plus one sustained vowel** — not natural free speech; scripted portrayal, repeated per
  actor/emotion.
- 10 professional actors (5 male, 5 female per the corpus literature).

**Exact real access process** (no Google Form, no Zenodo-style button — a signed-PDF +
email process):
1. Download, print, and fill in the **general conditions of use** PDF:
   `https://www.unige.ch/cisa/download_file/view/608/247` (filename
   `GEMEP_generalConditions_2017.pdf`).
2. Mail the **original signed form** together with a **short description of your
   project** to: `CISA, Campus Biotech, 9 chemin des Mines, CH-1202 Genève`.
3. **For faster access**, instead email the signed form + project description to:
   **`ERI-cisa@unige.ch`**.
4. Wait for CISA to approve — they explicitly reserve the right to decline if your
   project duplicates a study already ongoing/planned at their center.
5. Optional context doc (not required for the request): the emotional scenarios given to
   actors (in French) — `https://www.unige.ch/cisa/download_file/view/150/247`
   (`GEMEP Scenarios.pdf`).

**Action for the project owner**: download the conditions-of-use PDF, sign it, write a
short project description (this project: mobile personal-safety app training a
calm-threatening-speech detector, `h_aggressive_speech`, needs real cold-anger audio —
one paragraph is enough), and email both to `ERI-cisa@unige.ch`.

### 2. K-EmoCon — Zenodo record 3931963, gated behind Zenodo request + a separate Google Form

Verified by loading `https://zenodo.org/records/3931963` directly (logged in as the
project owner's Zenodo account, "Hridya Jain").

**Real record**: "K-EmoCon, a multimodal sensor dataset for continuous emotion
recognition in naturalistic conversations," Park et al., Version 1.0.0, published
2020-07-07. **Status: Dataset Restricted.** DOI `10.5281/zenodo.3931963`. Companion paper:
Park, C.Y. et al. (2020), *Scientific Data* 7, 293,
`https://doi.org/10.1038/s41597-020-00630-y`.

**Real audio content confirmed**: `debate_audios.tar.gz` — 16 WAV recordings of ~10-minute
paired debates, one file per debate session (2 participants per session), filename
convention `p<X>.p<Y>.wav` where `<X>`/`<Y>` are the two participants' numeric IDs. A
second video-only archive `debate_recordings.tar.gz` holds 2nd-person POV MP4s per
participant (`p<X>_<T>.mp4`, `<T>` = clip length in seconds) — not needed for an
audio-only model. Labels: `emotion_annotations.tar.gz` contains `self_annotations/`,
`partner_annotations/`, `external_annotations/` (files `P<X>.R<Z>.csv`, `<Z>` = rater
number), and `aggregated_external_annotations/` (majority-voted across 5 raters) — each
row is one 5-second interval with **arousal + valence on Likert scales** plus categorical
BROMP-style tags (cheerful/happy/angry/nervous/sad, etc.). `metadata.tar.gz` holds
`subjects.csv` with each session's `startTime`/`endTime` (aligns audio to annotation rows).

**Exact real access process** — two separate steps, both required (this is stricter than
a single Zenodo click):
1. On the Zenodo record page, under **Files → Restricted → "Request access"**, submit a
   request message (Zenodo requires being logged in; the record's own "Request access"
   box states the specific condition: *"A user must fill out the following form to be
   granted access to the dataset:"* **`https://forms.gle/DUAERhHqf51kyt4Y9`**).
2. **Separately**, the record's "Notes" section (dataset authors' own instructions) points
   to what reads as a related but distinctly-URLed user-agreement form:
   **`https://forms.gle/qmK8TcEDtw56Nqev5`** — "please fill in the user agreement form as
   well... use the same email address/mention the user id that you used in your Zenodo
   request... answer in detail 'For what purpose do you intend to use this data?'... After
   filling in the user agreement form, please do not forget to submit your request on
   Zenodo."

   **Flagging a real discrepancy, not resolving it by guessing**: the record currently
   shows two different Google Form URLs in two different sections (Notes vs. the
   Zenodo-configured "Request access" condition box). They may have been consolidated to
   one canonical form since the Notes text was last updated, or both may still be live —
   submit the one Zenodo's own "Request access" gate names
   (`forms.gle/DUAERhHqf51kyt4Y9`) first since that is the condition Zenodo enforces
   before granting the file-level request, and additionally submit
   `forms.gle/qmK8TcEDtw56Nqev5` per the authors' Notes text since it explicitly says "as
   well" (implying both apply). If either form 404s, that confirms it's stale — use the
   other alone.
3. Use the **same email address** in the Zenodo request and the Google Form(s).
4. In the Zenodo request message, answer "For what purpose do you intend to use this
   data?" in detail (per the authors' explicit instruction) — for this project: training
   a real-audio calm/aggressive speech-register classifier for a personal-safety mobile
   app, non-commercial research/development use.
5. Wait for the authors to review and grant/deny.

### 3. EAV — Zenodo record 10205702, single Google Form gate

Verified by loading `https://zenodo.org/records/10205702` and the dataset's real GitHub
companion repo `https://github.com/nubcico/EAV` directly.

**Real record**: "EAV: EEG-Audio-Video Dataset for Emotion Recognition in Conversational
Contexts," Lee et al., Version 0.1.0, published 2023-11-25. **Status: Dataset
Restricted.** DOI `10.5281/zenodo.10205702`. Companion paper: Lee, M-H. et al. (2024),
*Scientific Data*, `https://doi.org/10.1038/s41597-024-03838-4`. Contact:
`minho.lee@nu.edu.kz`.

**Real content confirmed** (Zenodo record + GitHub README, `nubcico/EAV`, MIT-licensed
code, data itself gated): 42 participants, 30-channel EEG + audio + video, cue-based
conversation eliciting **5 emotions: neutral, anger, happiness, sadness, calmness**
(anger and calmness both present — directly usable as the aggressive/calm contrast pair).
200 interactions/participant (listen+speak), 8,400 total. Per-participant folder layout
(confirmed from the real `Dataload_audio.py` source in the repo):
- Root contains one folder per subject named `subject01` … `subject42` (zero-padded
  `subject{:02d}`, no separator/underscore before the number).
- Each `subject<NN>/Audio/` subfolder holds **100 `.wav` files**, each **20 seconds**,
  speaking-task only (video subfolder separately holds 200 clips covering both listening
  and speaking).
- Real filename convention (from the loader code, `i.split('_')[4]`): filenames are
  underscore-delimited with the **emotion name as the 5th underscore-separated field**
  (0-indexed position 4), e.g. a pattern like
  `subject01_Audio_speaking_<iteration>_Anger_<take>.wav` — exact surrounding fields
  should be read directly off the real filenames once downloaded (position 4 is confirmed
  by the real loader code; the other fields were not individually itemized in the
  README). Emotion label strings are capitalized: `Neutral`, `Sadness`, `Anger`,
  `Happiness`, `Calmness`.
- Class-iteration sequence per participant (from the GitHub README): pseudo-random
  ordering `[A, A, C, C, S, S, H, A, C, H, H, S, S, A, A, C, C, H, H, S]` (A=anger,
  C=calmness, S=sadness, H=happiness) repeated across listen/speak blocks.

**Exact real access process** (single gate, simpler than K-EmoCon):
1. On the Zenodo record page, under **Files → Restricted → "Request access"**, the one
   stated condition is: *"A user must fill out the following form to be granted access to
   the dataset:"* **`https://forms.gle/QvFY7EAwXgsnv9bcA`**.
2. Submit the Zenodo access request (logged in) with a justification message.
3. Wait for review by the EAV authors (contact `minho.lee@nu.edu.kz` if no response).

### Summary table (copy-paste ready)

| Dataset | Mechanism | Real URL(s) | Extra required info |
|---|---|---|---|
| GEMEP | Signed PDF + email | Form: `unige.ch/cisa/download_file/view/608/247` · Send to: `ERI-cisa@unige.ch` | Name, institution (implicit via signed form), short project description |
| K-EmoCon | Zenodo request + Google Form(s) | Zenodo: `zenodo.org/records/3931963` · Form: `forms.gle/DUAERhHqf51kyt4Y9` (+ possibly `forms.gle/qmK8TcEDtw56Nqev5`, see discrepancy note above) | Same email on both; detailed "intended use" answer |
| EAV | Zenodo request + Google Form | Zenodo: `zenodo.org/records/10205702` · Form: `forms.gle/QvFY7EAwXgsnv9bcA` | Justification message on the Zenodo request |

None of these three could be submitted on the user's behalf in this session (submitting
forms with personal/institutional details is the user's own action per this project's
standing rule) — this checklist exists so the user can complete all three in a few
minutes without re-searching.

## PART 2 — h_aggressive_speech training pipeline, prepped for whenever data arrives

### Real current script located

The shipped `h_aggressive_speech_v1.tflite`'s architecture (38-dim hand-engineered
prosodic-feature MLP, confirmed via direct `interpreter.get_input_details()` inspection in
`assets/models/DAY268_UNTESTED_MODELS_EVAL.md`) traces to
`kaggle_notebooks/h_aggressive_speech_push/day90_h_aggressive_speech.py` (original, Day
90) and its most recent real retrain,
**`kaggle_notebooks/day106_fusion_crosslang_push/day106_h_crosslang_remain.py`** (Day 106,
output `h_aggressive_speech_bn_ur_ar_crosslang.tflite` — the exact staged filename named
in this task), which itself imports the feature-extraction/model-architecture core from
`day106_h_adversarial_core.py` (Day 104 adversarial version) and shared audio utilities
from `day106_audio_common.py`.

### Current data sources and positive-class definition — confirmed wrong register

Read `day106_h_crosslang_remain.py` + `day106_h_adversarial_core.py` +
`day106_indic_collectors.py` in full. Current positive ("aggressive") class across all
three loader functions is exclusively **acted, shouted/high-arousal emotional speech**:

- RAVDESS: emotion codes `05`(angry) `06`(fearful) `07`(disgust) → positive
- CREMA-D: `ANG`/`DIS`/`FEA` → positive
- EmoDB: codes `W`(anger) `E`(disgust) `A`(fear) → positive
- IEMOCAP: `{ang, sad, fru, fea, dis, exc}` → positive
- MELD: `{fear, sadness, disgust, anger}` → positive
- ShEMO (Persian, via `collect_shemo_aggressive_paths`) → positive

The only concession to a calmer register is a **synthetic augmentation**,
`apply_calm_threat()` in `day106_audio_common.py` (lowers volume 32-55%, time-stretches
1.08-1.25x, light smoothing filter), applied to 70% of positive samples at training time
— i.e. the "calm-threatening" register is currently *simulated* by signal-processing a
shouted-anger clip, never learned from a real human who was actually recorded speaking in
a calm, controlled, threatening tone. This confirms the register gap already noted in
`DAY268_UNTESTED_MODELS_EVAL.md` ("no correctly-labeled 'calm-threatening vs
calm-benign' real audio corpus identified") is real and current as of Day 106 — GEMEP's
"cold anger" category and EAV/K-EmoCon's naturalistic anger/calm audio are exactly the
missing real-register data.

### Prepped script (not runnable — no real data downloaded yet)

Written to `kaggle_notebooks/day310_h_aggressive_prep/day310_h_new_corpora_prep.py`,
alongside unmodified copies of its two real dependencies (`day106_audio_common.py`,
`day106_h_adversarial_core.py`, `day106_indic_collectors.py`) carried over from
`day106_fusion_crosslang_push/`, following this project's existing per-day-push directory
convention (each day's Kaggle push directory is self-contained, e.g.
`day107_hardmine_int4_push/` also carries its own copy of `day106_fusion_common.py`).

The new script is Day 106's real training loop (`day106_h_crosslang_remain.py`) with three
new loader functions added to the positive/negative chunk-collection stage:

- `load_gemep_cold_anger()` — raises `NotImplementedError`; docstring documents the real
  145-file Core Set, cold-anger vs. calm/neutral category split, and that the actual
  internal archive layout must be inspected on arrival (CISA does not publish an exact
  file tree publicly ahead of a signed release).
- `load_kemocon_audio()` — raises `NotImplementedError`; docstring documents the real
  `p<X>.p<Y>.wav` session-audio naming, the `P<X>.R<Z>.csv` / aggregated-annotation label
  files, the 5-second annotation interval alignment via `subjects.csv` startTime/endTime,
  and notes this is session-level 2-speaker audio (needs diarization or accepting
  session-level weak labels) — real, not guessed, structure from the Scientific Data paper.
- `load_eav_audio()` — raises `NotImplementedError`; docstring documents the real
  `subject<NN>/Audio/*.wav` layout, 100 files/subject, 20s clips, emotion-in-filename at
  underscore-index 4, and the 5-class label set with Anger/Calmness as the directly
  relevant contrast pair.

Each raises immediately with a message pointing back to this doc
(`DAY310_H_AGGRESSIVE_ACCESS_AND_PREP.md`) so a future run fails loudly and specifically
instead of silently training on empty/fake data. The three loaders are wired into
`main()` exactly like the existing loaders (`_ravdess_samples`, `_cremad_samples`, etc.) —
each wrapped in the same `try/except` used for every other loader in this file, so the
script **will still run end-to-end on existing data alone** (skipping the new sources with
a logged warning) if executed today; it only trains on the new real registers once a real
loader replaces the `NotImplementedError` stub. This was verified by reading the control
flow, not executed — no real GEMEP/K-EmoCon/EAV data exists locally to run it on.

**Explicitly not done**: no fabricated/synthetic stand-in data for GEMEP/K-EmoCon/EAV, no
placeholder arrays, no pretend training run. The script is honestly incomplete until a
real loader is implemented.
