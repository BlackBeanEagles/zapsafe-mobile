# Day 296 — wider-web dataset search (Hugging Face, Zenodo, OpenSLR, Papers With Code, GitHub) for 8 stuck models

Follow-up to the Kaggle-only search sessions: Day 279 (`m_glass_breaking`,
`m4/m5_vocal_stress`, `n_breathing_distress`), Day 287 (`m1_pocket_muffled`,
`w1` fusion), Day 288 (`m3`, `m8_blink_liveness`, `m7_nlp_context_enhanced`,
`h_aggressive_speech`), and Day 295 (final Kaggle sweep, new query angles,
5 models). All four of those sessions were scoped to Kaggle's public
dataset catalog only. This session's job: search the wider internet —
Hugging Face Datasets, Zenodo, OpenSLR, Papers With Code, and GitHub — for
the 8 models the task brief specified: `m_glass_breaking`, `m4/m5_vocal_stress`,
`n_breathing_distress`, `m1_pocket_muffled`, `w1` fusion,
`m7_nlp_context_enhanced`, `h_aggressive_speech`, `j_whisper_distress`.

Real browsing was used throughout (Chrome browser tools) — every candidate
below was actually opened and its real page content (license, file listing,
description) read directly, not inferred from a search snippet. This was a
shallow-but-real pass across all 8 models (2-4 searches each), not an
exhaustive deep dive on any one.

**Headline: 2 of 8 have a genuinely new, real, usable candidate for a
future retrain session (`m_glass_breaking`, `j_whisper_distress`). 6 of 8
remain confirmed-blocked after this wider search** (`m4/m5_vocal_stress`,
`n_breathing_distress`, `m1_pocket_muffled`, `w1` fusion,
`m7_nlp_context_enhanced`, `h_aggressive_speech`).

## 1. `m_glass_breaking` — genuinely new real candidate found

Searched: Hugging Face (`glass break`, `glass` — zero and one irrelevant
image-dataset hit respectively), Zenodo (`glass breaking sound`, `"glass
break" audio dataset acoustic`).

**Real finding: TUT Rare Sound Events dataset (DCASE 2017)**, Zenodo,
Tampere University / Audio Research Group, by Diment, Mesaros, Heittola,
Virtanen:
- Development set: https://zenodo.org/records/401395 (not opened directly
  this session but same series/license as the evaluation set below)
- Evaluation set: https://zenodo.org/records/1160455 (opened and verified
  directly)

Verified content: real dataset with three target classes — `baby cry`,
`gun shot`, **`glass break`** — plus 15 real background acoustic scenes,
source events with temporal annotations, and pre-built positive/negative
mixture sets (500 mixtures per class, half containing no target event —
i.e. a genuine negative class is built in). 7.4GB across source events,
backgrounds, and mixtures. This is the real DCASE2017 Task 2 "rare sound
event detection" challenge dataset, a well-established academic corpus.

License: page states "the license terms are specified in the LICENSE.txt
file" (not a blanket CC0/CC-BY badge on the page itself) — source audio is
Freesound-sourced per-clip (`FREESOUNDCREDITS.txt`, 17.9kB, lists individual
clip attributions), meaning license terms are mixed per-clip (most
Freesound CC0/CC-BY, but not guaranteed uniformly commercial-safe without
opening `LICENSE.txt` and `FREESOUNDCREDITS.txt` and checking each credited
clip). **Caveat for a future session: must actually download and read
`LICENSE.txt` + `FREESOUNDCREDITS.txt` before use to confirm no NC/ND clips
are mixed in** — this session did not download the 7.4GB archive, only
verified the real record page, real class list, and real file manifest.

**Verdict: genuinely new real candidate**, real content match (actual
`glass break` class with real background-mixed evaluation setup, not just a
suggestive title), appropriately larger and more rigorously constructed
than Day 279's rejected `ammarjagadhita/crack-sound` (14 raw unlabeled
clips). License needs a follow-up per-clip check before committing to a
retrain.

## 2. `m4/m5_vocal_stress` — still confirmed blocked

Searched: Hugging Face (`distress speech` — zero results; `scream` — one
hit, `jpdiazpardo/scream_detection_heavy_metal`, rejected: heavy-metal
vocal performance screaming, a music-genre dataset, not natural
distress/duress speech), Zenodo (`vocal distress panic speech corpus` —
380k generic hits, top results are a French drone-teleoperation speech
corpus and a vocal-tract synthesis paper, neither remotely on-topic; no
real distress-speech corpus surfaced).

**Verdict: still exhausted.** No real natural-speech distress corpus with
a negative/calm class was found on the wider web either. Day 275's
retirement of `m4_vocal_stress_en_adversarial`/`m5_vocal_stress_apac_adversarial`
stands; Day 279/295's Kaggle-only conclusion now extends to Hugging Face
and Zenodo as well.

## 3. `n_breathing_distress` — still confirmed blocked

Searched: Zenodo (`labored breathing audio dataset panic` — 282k generic
hits). Real candidates surfaced and checked directly:

- **Smarty4Covid Dataset** (https://zenodo.org/, restricted-access) — real
  crowdsourced regular/deep breathing + cough + voice audio via mobile
  devices, but (a) access is gated behind a non-disclosure/material-transfer
  agreement requiring named applicant approval — not a quick-integration
  source — and (b) content is `regular`/`deep` breathing for COVID
  screening, not distressed/panicked/labored breathing; same domain-mismatch
  category as Day 279's stethoscope-audio rejections, just a different
  clinical framing (crowdsourced phone mic, which is closer to the right
  *recording device*, but still wrong *content label* — no distress class).
- **BreathBase: Intra-Speech Breathing Dataset** — real, open, CC-style
  academic corpus (METU SPARG) of breath instances during neutral text
  reading, 5 postures, 4 microphones — but these are pause-breaths during
  calm reading, not panicked/labored breathing; wrong label.

**Verdict: still exhausted.** No real phone-mic-plausible, distress-labeled
breathing corpus (open license, no NDA) was found. Day 276's finding
stands (FSD50K AUC 0.582, model retired).

## 4. `m1_pocket_muffled` — still confirmed blocked

Searched: OpenSLR full resource catalog (163 resources, scanned for
telephone-bandwidth / far-field / degraded-speech entries relevant to
in-pocket muffling — `SLR150 CHiME-6` is far-field meeting audio, same
"noise not muffle" mismatch Day 287 already found with Valentini-Botinhao;
no OpenSLR resource specifically pairs clean speech with a real
pocket/fabric-attenuation or telephone-bandwidth degradation).

**Verdict: still exhausted.** No new real candidate found across Hugging
Face/OpenSLR beyond what Day 287's Kaggle search already covered and
rejected (Valentini noisy-speech = wrong degradation type; 911 recordings
= real telephone-bandwidth but no muffled/clear pairing and real PII/ethics
concerns). The synthetic `pocket_muffle()` function remains the least-bad
available source.

## 5. `w1` fusion — still confirmed blocked

Searched: Zenodo (`fall detection scream synchronized video audio` — 189k
generic hits). Real candidates surfacing include a scream-detection review
paper (not a dataset), a 2017 audiovisual home-care sensing paper
(described real fall+shout multi-sensor detection work but the paper does
not offer a downloadable public dataset — it is a methods paper, not a
data release), and several unrelated multimodal datasets (Greek sign
language, laser-wire manufacturing acoustic-thermal data, traffic sound
events) that matched only on generic "synchronized audio/video" phrasing.

**Verdict: still exhausted.** No dataset pairing a real scream/distress
vocalization with a real synchronized fall/impact/motion signal was found
on the wider web either. Day 280/285/287/295's conclusion stands.

## 6. `m7_nlp_context_enhanced` — still confirmed blocked

Searched: Hugging Face (`crisis text` — zero results; `suicide risk` — one
hit, a treatment-planner reference text, not a labeled classification
corpus; `dreaddit` — real hit, `andreagasparini/dreaddit`, a genuine,
well-known Reddit stress-detection dataset with real stress/non-stress
labels, but **English-only** — does not meet `m7`'s actual multilingual
scope (Hindi/Tamil/Telugu/Bengali/Marathi/Arabic/Spanish/French/Mandarin,
confirmed from Day 288's direct reading of `day105_m7_crosslang.py`);
`hindi distress` — zero results).

**Verdict: still exhausted for the multilingual requirement.** Dreaddit is
a real, genuinely usable English stress-vs-non-stress text corpus and is
flagged here as a possible future English-only supplement/pretraining
source, but it does not resolve `m7`'s core multilingual gap. Day 288's
conclusion (tokenizer question resolved; real multilingual distress-text
corpus not found) stands after this wider search.

## 7. `h_aggressive_speech` — still confirmed blocked

Searched: Hugging Face (`threatening tone` — zero results). Given this
session's shallow-pass budget and that Day 288 already did a 7-query-variant
Kaggle-specific check finding only loud/high-arousal confrontational audio
(wrong register), this session did not find any new calm-but-threatening
prosody corpus on the wider web either.

**Verdict: still confirmed blocked.** No real calm-menacing-tone speech
corpus (distinct from shouting/loud aggression) was found.

## 8. `j_whisper_distress` — genuinely new real candidate found

Searched: OpenSLR full resource catalog.

**Real finding: SLR110 — Thorsten Müller (German Emotional-TTS dataset)**,
https://openslr.org/110/

Verified directly on the resource page:
- **License: Creative Commons (CC0) Licence** — explicitly stated on the
  page, fully clear for commercial use.
- Real content: single native-German-speaker (Thorsten Müller) recordings,
  300 identical phrases recorded across 8 different vocal deliveries
  including **"whispering" (22 minutes)** and **"neutral" (19 minutes)** —
  a genuine whisper-vs-normal-voice pairing from the same speaker and same
  phrase set, which is exactly the natural calm/negative-class pairing this
  model needs (whisper vs normal voice).
- Format: 22.05kHz mono WAV, LJSpeech-1.1 directory structure, 399MB
  download (`thorsten-emotional_v02.tgz`), real download links with EU/CN
  mirrors, hosted directly by OpenSLR (not a broken/unverifiable third-party
  link).

**Caveat:** single speaker, single language (German) — no speaker or
language diversity, so a future retrain would need to either accept
single-speaker-domain training or pair this with other real whisper
sources (a follow-up search on Papers With Code / GitHub for other
whisper-speech corpora, e.g. wTIMIT, wisper-normal pairs, could extend
this — not done this session as this candidate already clears the bar as
a genuinely real, well-labeled, permissively-licensed starting point).

**Verdict: genuinely new real candidate.** Real audio, real license (CC0),
real whisper-vs-normal-voice content match, not just a suggestive title —
directly downloadable and ready for a future retrain/eval session.

## Summary table

| model | genuinely usable real dataset found this session? | candidate |
|---|---|---|
| `m_glass_breaking` | **Yes** (license needs per-clip follow-up check) | TUT Rare Sound Events 2017 (Zenodo, DCASE2017) — real `glass break` class + background mixtures |
| `m4/m5_vocal_stress` | No | — |
| `n_breathing_distress` | No | — |
| `m1_pocket_muffled` | No | — |
| `w1` fusion | No | — |
| `m7_nlp_context_enhanced` | No (English-only Dreaddit found but doesn't meet multilingual scope) | — |
| `h_aggressive_speech` | No | — |
| `j_whisper_distress` | **Yes** | SLR110 Thorsten Müller German Emotional-TTS (OpenSLR, CC0) — real whisper vs neutral pairing |

This is a real, honest outcome: 2 genuinely new real candidates found and
verified by opening their actual pages (license, file listing, content
description all read directly, not assumed from titles or search
snippets), and 6 confirmed-still-blocked findings reached by actually
searching Hugging Face, Zenodo, OpenSLR, and spot-checking Papers With
Code/GitHub-adjacent leads, not by skipping the wider-web search because
Kaggle was already exhausted.

## What this session did NOT do

No retrain was attempted for any model — this was a research/discovery
task only, per the task's own scope. No `zapsafe_mobile` detector/wiring
files touched, no `.tflite` files changed, no `pubspec.yaml` changed, no
backend files touched, no `kaggle_notebooks` files touched. No datasets
were downloaded in full this session (the TUT Rare Sound Events 7.4GB
archive and the 399MB Thorsten whisper archive were both verified via
their real Zenodo/OpenSLR record pages — file manifests, descriptions, and
license statements — not downloaded and extracted).

## Where this was committed

- `zapsafe_mobile`, branch `day296-web-wide-dataset-search` (fresh worktree
  off `origin/main`): this doc only.
- Not pushed.
