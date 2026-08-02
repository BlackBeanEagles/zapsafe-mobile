# Day 288 — real Kaggle public-catalog search for the 4 still-blocked models

Follow-up to `DAY268_UNTESTED_MODELS_EVAL.md` (established each model's real
tensor signature and exact blocker) and `DAY278_REMAINING_BLOCKED_RECHECK.md`
(re-checked those blockers against a fresh Google Drive listing and a narrow,
5-query whisper-only Kaggle search — Day 278 did **not** run a real Kaggle
public-catalog search for `m3`, `m8`, `m7`, or `h_aggressive_speech`
specifically; its Kaggle effort was scoped to `j_whisper_distress` only).
This session's job: actually run that search, with multiple real query
variants per model, using `kaggle datasets list -s "<query>"` (API confirmed
authenticated, same account as prior sessions) and inspecting real candidate
file listings / descriptions (`kaggle datasets metadata` / `kaggle datasets
files`), not just titles.

**Headline: 2 of 4 have a genuinely new, real, viable path for a future
session (`m3`, `m8_blink_liveness`). 2 of 4 remain confirmed-blocked after
this additional real check (`m7_nlp_context_enhanced`, `h_aggressive_speech`)
— every real candidate found for those two has the wrong label semantics,
not just an absent title.**

## 1. `m3` (staged `[1,160,160,3]` variant) — genuinely new real path found

**Exact blocker restated (from Day 268/278):** no locally-available or
Kaggle-account image dataset carries a real safe/unsafe scene label; `ADE20K`
(semantic segmentation) and `Places365` (scene category) are both present
but neither is labeled for the model's binary safe/unsafe target.

**Searched this session:** `"safe unsafe scene"`, `"violence scene
classification"`, `"crime scene image dataset"`, `"dangerous scene
detection"`, `"UCF crime dataset"`, `"anomaly detection surveillance"`,
`"normal vs abnormal scene"`.

**Real finding: `odins0n/ucf-crime-dataset`** ("UCF Crime Dataset", 11GB,
usability 0.875, 41,440 downloads, 280 votes — a long-established, heavily
used Kaggle mirror of the academic UCF-Crime anomaly-detection corpus).
Verified via `kaggle datasets files` that it is structured as `Train/<class>/`
and `Test/<class>/` folders of extracted video frames (confirmed real PNG
frames, e.g. `Test/Abuse/Abuse028_x264_0.png`). UCF-Crime's well-documented
class structure (13 anomaly categories — Abuse, Arrest, Arson, Assault,
Burglary, Explosion, Fighting, RoadAccidents, Robbery, Shooting, Shoplifting,
Stealing, Vandalism — **plus a `Normal` class** of non-incident surveillance
footage) means this dataset natively provides a real binary-usable proxy:
`Normal` frames as "safe," any anomaly-class frames as "unsafe" — both drawn
from the *same* surveillance-camera domain, which is a materially better
match than pairing `Places365`/`ADE20K` (generic scene photography) against
an invented label, because the "Normal vs incident" distinction here is the
dataset's own native annotation, not a hand-invented proxy.

Also found `simonphall/ucf-crime-images` (189 real hand-selected stills
across 8 crime categories with captions, usability 1.0) as a smaller,
higher-quality-curated positive-class supplement, though it has no matching
"safe" negative class of its own (would still need pairing with
`odins0n`'s `Normal` split or Places365 for negatives).

**Caveats for a future retrain session:** frames are CCTV/surveillance
imagery, not general everyday "safe vs unsafe environment" photography —
still a domain proxy relative to `m3`'s original unknown training intent,
though a much closer one (both classes from the same real-world camera
domain) than the previously-considered Places365/ADE20K pairing. Frame
resolution/aspect will need resizing to match the model's `160x160` input
(trivial preprocessing, not a blocker).

**Verdict: NEW REAL PATH FOUND**, ready for a future retrain/eval session —
not attempted here per this session's investigation-only scope.

## 2. `m8_blink_liveness` — genuinely new real path found

**Exact blocker restated (from Day 268/278):** needs a `[1,24,12]` float32
landmark-sequence (24 frames x 12 eye-region landmark coordinates); requires
either pre-extracted landmark sequences or a real *video* of a blinking eye
run through a face-landmark extractor (MediaPipe FaceMesh / dlib). Day 278
found `300w.zip` (300W) newly in the Drive listing but ruled it out
correctly — it's a static-image landmark dataset, wrong shape (no temporal
sequence).

**Searched this session:** `"blink detection dataset"`, `"eye blink
video"`, `"liveness detection dataset"`, `"face anti-spoofing video"`, `"eye
state video sequence"` (no results), `"CASIA face anti-spoofing"` (no
results), `"replay attack liveness"`, `"NTHU drowsy driver"`, `"driver blink
dataset video"`.

**Ruled out with direct evidence:** `matjazmuc/frame-level-driver-
drowsiness-detection-fl3d` (FL3D) — read its full description: it is built
from NITYMED (a real academic blink/microsleep/yawning video corpus) but
FL3D's own construction method **explicitly removes all blink frames**
("Frames in which drivers blink are removed and not included in FL3D") —
confirmed via metadata, not assumed from the title. `dhuwxy/nthu-drowsy-
driver-dataset` — despite its name, `kaggle datasets files` shows it is
static PNG stills (`Drowsy/A0001.png` etc.), not the real NTHU-DDD video
corpus; low usability rating (0.25) is consistent with a mislabeled/
repackaged static set.

**Real finding: TrainingDataPro's face anti-spoofing / liveness video
family** — `trainingdatapro/real-vs-fake-anti-spoofing-video-classification`
("Real VS Fake - Liveness Detection Dataset", 3GB, usability 1.0, 2,918
downloads), plus sibling datasets `ibeta-level-1-liveness-detection-dataset-
part-1`, `asian-people-liveness-detection-video-dataset`,
`caucasian-people-liveness-detection-dataset`, `full-hd-webcam-live-attacks`
(all usability 1.0, hundreds–thousands of downloads each). Verified via
`kaggle datasets files` that the "Real VS Fake" dataset contains genuine
`.mp4` video files of continuous real human faces (e.g.
`test/attack/55.mp4`, 2MB–97MB range) — real, continuous video of people's
faces, the correct data *type* (video, not static images) this model needs.

**What this does and does not resolve:** these datasets are not
blink-annotated — they are liveness/anti-spoofing labeled (real vs.
replay-attack), not blink-labeled. But because they are continuous real
face video, natural eye blinks occur in them incidentally, and a
face-landmark extractor (MediaPipe FaceMesh, a standard public library, not
something needing to be built from scratch) run over these real videos
could produce genuine `[24,12]` eye-region landmark sequences, with blink
events locatable via a standard eye-aspect-ratio (EAR) threshold — a
well-established, non-exotic technique. This is a real, viable data
*source* for building the missing extraction pipeline described in Day 268
as absent; it does not eliminate the pipeline-building work itself (out of
scope this session).

**License caveat:** the flagship `real-vs-fake-anti-spoofing-video-
classification` dataset is licensed CC BY-NC-ND 4.0 (non-commercial, no
derivatives) — worth checking against ZapSafe's commercial-use needs before
committing to it in a future session; other TrainingDataPro siblings should
be checked individually for license terms.

**Verdict: NEW REAL PATH FOUND** (real video source + standard extraction
technique), ready for a future pipeline-building + retrain session — not
attempted here.

## 3. `m7_nlp_context_enhanced` — still confirmed blocked

**Exact blocker re-verified from source, not assumed:** read
`kaggle_notebooks/day105_cross_language_push/day105_m7_crosslang.py`
directly (`kaggle_notebooks/day105_cross_language_push/day105_cross_language_kaggle_output/.../day105_m7_crosslang.py`
and 4 other saved-output copies). Confirmed: **this model does not use a
standard/public tokenizer at all** — `build_tokenizer()` (line 680) builds a
custom `word2idx` vocabulary directly from the training corpus via
`Counter.most_common()`; there is no BERT/DistilBERT/SentencePiece
dependency of any kind, contrary to the task brief's hypothesis that the
missing file "might be a standard/public tokenizer." Day 268 already
confirmed the real, matching `m7_vocab_hi_ta_crosslang.json` word2idx file
exists on disk alongside the `.tflite` — so there is no tokenizer/vocab file
missing to search for on Kaggle; that blocker was resolved on Day 268 and
remains resolved. The actual remaining gap, read directly from
`build_dataset()`/`weak_label_transcript()` in the same script, is a
**labeled real text corpus** for the model's actual target: multilingual
(Hindi/Tamil/Telugu/Bengali/Marathi/Arabic/Spanish/French/Mandarin, mostly
Hinglish/romanized) distress-phrase-vs-benign-phrase classification — the
training script currently builds this via a hand-written keyword-regex
weak-labeler (`DISTRESS_KEYWORDS`/`COMEDY_NEG_PATTERNS`) over emotion/speech
corpora, not a real labeled distress-text dataset.

**Searched this session:** `"distress text classification"`,
`"domestic violence text dataset"`, `"hate speech hindi dataset"`,
`"toxic comment hindi"`, `"SOS message dataset"` (no results), `"threat
detection text dataset"`, `"harassment text classification"`, `"911 call
transcript dataset"`, `"crisis text line dataset"`, `"emergency call
transcript"`, `"suicide risk text detection"`.

**Real candidates found and checked directly, all label-mismatched:**
- `sharduldhekane/code-mixed-hinglish-hate-speech-detection-dataset`,
  `wajidhassanmoosa/multilingual-hatespeech-dataset`,
  `sayankr007/multi-lingual-cyberbully-detection-15-languages` — real,
  usable Hinglish/multilingual text corpora, but labeled for **hate speech
  directed at others** (aggressor language), not **victim distress/SOS
  phrases** (the actual target class) — a different speaker perspective and
  a different label, the same "inventing a label" gap Day 268 already
  flagged for other models.
- `nehash0123gmailcom/silent-wounds-womens-trauma-response-dataset`
  ("Silent Wounds: Women's Trauma Response Dataset," India, GBV-focused) —
  checked in full via `kaggle datasets metadata`: this is the closest-sounding
  title, but its actual content is a **1,000-row structured survey**
  (categorical fields: "Emotions felt," "Sought help," physical symptoms),
  not free-text distress utterances — wrong data shape for a `[1,64]`
  tokenized-text model regardless of topical relevance. Also explicitly
  contains synthetic-augmented rows and has only 13 downloads/1 vote,
  low external validation.
- `jacopoferretti/police-emergency-calls-llm-synthetic` ("Emergency Call
  Triage - Synthetic 911 Transcripts") — real free-text emergency-call
  phrasing, but LLM-synthetic (not real recorded speech-to-text output) and
  English-only — does not cover the Hindi/Tamil/Telugu/Bengali/Marathi
  multilingual scope `m7` actually targets.

**Conclusion: CONFIRMED STILL BLOCKED.** The tokenizer question is fully
resolved (no standard-library tokenizer needed; the real custom vocab file
already exists). The real, remaining gap — a labeled real multilingual
distress-vs-benign text corpus — was searched for directly with 11 query
variants and found to have no genuine match on Kaggle: every real hit is
either the wrong speaker perspective (hate speech/aggressor language),
wrong data shape (categorical survey, not utterances), or wrong scope
(English-only synthetic transcripts, not the multilingual real-STT-style
text `m7` needs).

## 4. `h_aggressive_speech` — still confirmed blocked

**Exact blocker re-verified from source:** Day 268 read
`kaggle_notebooks/day104_adversarial_push/_kaggle_staging_latest/day104_h_adversarial.py`
directly and confirmed this model is a 38-dim prosodic-feature MLP
detecting **calm-but-threatening tone** — explicitly *distinct* from
`m1_scream_v2` (screaming/loud distress). The blocker is a real audio corpus
labeled specifically "calm-threatening vs calm-benign" prosody; general
emotion corpora (RAVDESS, CREMA-D, EmoDB, IEMOCAP, MELD, ShEMO) support
proxy emotion labels but not this specific calm/low-arousal-but-hostile
distinction.

**Searched this session:** `"aggressive speech dataset"`, `"threat
detection audio"`, `"hostile speech classification"`, `"verbal aggression
dataset"`, `"hate speech audio"`, `"intimidating voice dataset"` (no
results), `"menacing tone speech"` (no results).

**Real candidates found and checked directly, both wrong-arousal-level:**
- `mohithjain04/threat-detection-audio-dataset` ("Threat Detection Audio
  Dataset," Hindi/English/Kannada, road rage/harassment/public
  violence/street abuse/distress calls) — read full description and file
  listing via `kaggle datasets files`. Confirmed real recorded human voice,
  but every category (road rage, harassment, abuse, distress calls) is
  **loud/high-arousal** confrontational or victim-distress speech, the same
  domain `m1_scream_v2` already covers — not the calm-but-menacing register
  `h_aggressive_speech` needs. Also a low-usability (0.5625) small
  student-project dataset with heavy file duplication observed directly
  (each clip present 4x as `_mono.wav`, ` - Copy_mono.wav`, ` - Copy
  (2)_mono.wav` etc.), further reducing real usable sample count.
- `fangfangz/audio-based-violence-detection-dataset` ("Audio-based Violence
  Detection Dataset," YouTube-sourced, usability 0.71, 1,501 downloads) —
  description explicitly states its content is "shouts, screams, aggressive
  verbal confrontations... during heightened aggression" — again
  high-arousal/loud, the opposite register from "calm-but-threatening."

**Conclusion: CONFIRMED STILL BLOCKED.** Both real candidates found this
session are genuine, checked-in-detail audio datasets, but both capture
loud/overt aggression (shouting, confrontation, screaming) — precisely the
`m1_scream_v2` domain this model is defined to be distinct from — not the
low-arousal, prosody-only "calm-threatening" register `h_aggressive_speech`
targets. No Kaggle dataset found across 7 query variants supplies this
specific label.

## Summary table

| model | new real path found this session? | specifics |
|---|---|---|
| `m3` | **Yes** | `odins0n/ucf-crime-dataset` (11GB, usability 0.875, 41k downloads) — real `Normal` vs 13-anomaly-category surveillance frames, native safe/unsafe-style annotation from the same camera domain; `simonphall/ucf-crime-images` (189 curated stills) as a supplemental positive set |
| `m8_blink_liveness` | **Yes** | TrainingDataPro liveness/anti-spoofing video family (`real-vs-fake-anti-spoofing-video-classification` and siblings) — real continuous `.mp4` face video (confirmed via file listing), usable as input to a MediaPipe-FaceMesh + EAR-threshold extraction pipeline to produce real `[24,12]` blink sequences; pipeline itself still needs building. Check CC BY-NC-ND license before commercial use |
| `m7_nlp_context_enhanced` | No | Tokenizer blocker fully resolved (confirmed: custom word2idx, no external tokenizer needed). Real labeled multilingual distress-text corpus not found — every real Kaggle hit across 11 queries is hate-speech (wrong speaker perspective), a categorical survey (wrong shape), or English-only synthetic (wrong scope) |
| `h_aggressive_speech` | No | Real "threat"/"aggressive"/"violence" audio datasets found (`mohithjain04/threat-detection-audio-dataset`, `fangfangz/audio-based-violence-detection-dataset`) but both are loud/high-arousal confrontational speech — the `m1_scream_v2` domain, not the calm-but-threatening prosodic register this model needs |

## What this session did and did not do

Did: ran 25 real Kaggle public-catalog searches (multiple query variants
per model, listed above) via `kaggle datasets list -s`; inspected real
candidate file listings (`kaggle datasets files`) and full descriptions
(`kaggle datasets metadata`) for every dataset that looked plausible from
its title, not just the title text; re-read `day105_m7_crosslang.py`
directly to verify the exact tokenizer/vocab mechanism before searching
(confirmed no external tokenizer dependency exists, correcting the task
brief's initial hypothesis); ruled out two misleading-titled datasets
(`nthu-drowsy-driver-dataset`, `frame-level-driver-drowsiness-detection-
fl3d`) with direct evidence rather than assuming from their names.

Did not: retrain, download any dataset, run any inference/AUC evaluation,
or build any extraction pipeline (e.g. MediaPipe FaceMesh landmark
extraction for `m8`) — per this session's investigation-only scope. Did not
touch detector/wiring files, any `.tflite` file, `pubspec`, or backend code.

## Files touched this session

- `assets/models/DAY288_KAGGLE_SEARCH_BLOCKED4.md` (this file) — new, in
  `zapsafe_mobile`, on branch `day288-kaggle-search-blocked4` (worktree off
  `main`).
- No other files modified.
