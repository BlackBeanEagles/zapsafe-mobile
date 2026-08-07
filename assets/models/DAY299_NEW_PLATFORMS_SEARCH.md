# Day 299 — new-platform dataset search (Mendeley Data, IEEE DataPort, Google Dataset Search, OSF, Common Voice ecosystem, Freesound) for the 6 still-stuck models

Follow-up to Day 279/287/288/295 (Kaggle-only passes) and Day 296 (Hugging
Face/Zenodo/OpenSLR/Papers With Code/GitHub — found 2 real usable
candidates for `m_glass_breaking` and `j_whisper_distress`, left 6 models
still blocked). This session's job: search platforms not yet tried by any
prior session — Mendeley Data, IEEE DataPort, Google Dataset Search, OSF,
Mozilla Common Voice's derivative ecosystem, and Freesound.org directly —
for the 6 models Day 296 left unresolved: `m4/m5_vocal_stress`,
`n_breathing_distress`, `m1_pocket_muffled`, `w1` fusion,
`m7_nlp_context_enhanced`, `h_aggressive_speech`.

Every real candidate below was actually looked up (via web search plus
direct page fetches where the domain was fetchable — `data.mendeley.com`
and `ieeexplore.ieee.org` blocked direct WebFetch in this environment, so
those were verified via search-result content instead; `ieee-dataport.org`
and other domains were fetched directly). No dataset name, URL, or license
below is fabricated — every one is a real record returned by a real
search or fetch this session. This was a shallow-but-real pass across all
6 models (2-3 queries each), matching the task's own budget guidance.

**Headline: 0 of 6 have a genuinely new, verified-usable candidate on
these new platforms. All 6 remain confirmed-blocked.** Several
real, on-topic-looking datasets surfaced, but every one failed on license
(non-commercial/EULA-gated), access (subscription/contact-required), or
content-domain match on inspection — the same "close title, wrong
substance" pattern the prior sessions ran into on Kaggle/HF/Zenodo.

## 1. `m4/m5_vocal_stress` — still confirmed blocked

Searched: Mendeley Data (`distress speech voice stress dataset`,
`calm menacing threatening voice tone dataset emotion`), Google/OSF
(`panic distress speech audio dataset`), general web (`CARES corpus`,
`STRESSID`).

Real candidates found and checked:
- **StressID** (https://project.inria.fr/stressid/) — real multimodal
  (audio+video+ECG/EDA/respiration) dataset, 65 participants, 11
  stress-inducing/neutral tasks, 385 minutes of real audio. **Rejected**:
  page states a custom non-commercial research-only license requiring a
  signed end-user license agreement emailed to the authors — an
  EULA-gated source, excluded per this project's open-license rule.
- **CARES corpus** (Canadian Adult Regular and Emergency Speech,
  Springer/IJST paper) — real simulated-emergency-dialogue speech from 40
  actors (ages 23-91), on-topic content (emergency vs. regular speech).
  **Rejected**: no public download link, Mendeley/IEEE DataPort/OSF
  listing, or open-license terms found anywhere — appears to be a private
  institutional research corpus with no accessible distribution channel,
  not a real integration candidate.
- **OSF Social Anxiety Disorder audio dataset**
  (https://osf.io/b8uyg/) — real audio of impromptu speeches under social
  anxiety, open on OSF. **Rejected on content**: social-anxiety public
  speaking stress, not danger/duress distress, and no calm-vs-distress
  contrast — same category of mismatch as prior sessions' stress-not-panic
  rejections.
- Mendeley `crissymoon`-style hits repeated (tabular prosody CSVs, no
  audio) — same as Day 295's finding, confirms rather than adds.

**Verdict: still exhausted.** No open-license natural-speech distress
corpus with a calm negative class found on these platforms either.

## 2. `n_breathing_distress` — still confirmed blocked

Searched: Mendeley Data (`breathing distress panic audio dataset`),
Google Dataset Search style query (`panicked breathing distress audio`).

All real hits are the same clinical/COVID-stethoscope family already
rejected twice (Day 279, Day 296): Mendeley's COVID breathing spectrogram
sets, `Cardiorespiratory DB`, chest-wall stethoscope lung-sound sets, and
the smarty4covid/Coswara/telephone-respiratory-distress corpora already
found and rejected in Day 296 (regular/deep breathing or clinical
labored-breathing content, not phone-mic panic/duress panting; several
also access-gated). No new phone-mic-plausible panicked-breathing corpus
surfaced.

**Verdict: still exhausted.** Day 276/296's finding stands.

## 3. `m1_pocket_muffled` — still confirmed blocked

Searched: Mendeley Data (`telephone bandwidth degraded speech muffled
dataset`), general web for pocket/fabric-attenuation corpora.

No dataset pairing clean speech with real pocket/fabric-muffling or
telephone-bandwidth degradation surfaced on Mendeley Data or in general
search — only patents and enhancement-method papers describing the
*problem* (300Hz-3.4kHz telephone bandwidth, VoIP packet-loss datasets
mentioned only inside papers, not as standalone downloadable corpora).
Freesound.org was not separately productive here either — it indexes
individual sound-effect clips, not paired clean/degraded speech corpora.

**Verdict: still exhausted.** Day 283/286/287/296's conclusion stands;
the synthetic `pocket_muffle()` function remains the least-bad source.

## 4. `w1` fusion — still confirmed blocked

Searched: Freesound.org directly (`scream fall impact recording`), OSF/
Google Dataset Search (`fall detection scream synchronized IMU
accelerometer audio`), IEEE DataPort (`fall-detection-imu-dataset-wearable-applications`,
fetched directly).

Real candidates checked and rejected:
- **Freesound clips** (`Robinhood76` "falling male scream.wav",
  `IENBA` "Female Falling Screams") — real individual CC-licensed sound
  effects of staged/foley falling screams, but single isolated audio
  clips with no synchronized motion/IMU channel at all — not a fusion
  dataset, just a scream sample.
- **IEEE DataPort "Fall Detection IMU Dataset for Wearable Applications"**
  (https://ieee-dataport.org/documents/fall-detection-imu-dataset-wearable-applications)
  — fetched directly: contains only tri-axial accelerometer/gyroscope
  data (`Fall_Dataset.csv`), no audio channel at all, and is gated behind
  an IEEE DataPort subscription regardless.
- **UR Fall Detection Dataset** (https://fenix.ur.edu.pl/~mkepski/ds/uf.html)
  — fetched directly: real, well-known fall dataset, but only depth/RGB
  camera + accelerometer, no audio; license is CC BY-NC-SA 4.0
  (non-commercial), which would exclude it even if audio were present.

**Verdict: still exhausted.** No dataset pairing a real scream/distress
vocalization with a real synchronized fall/impact/motion signal was found
on these platforms either. Day 280/285/287/295/296's conclusion stands.

## 5. `m7_nlp_context_enhanced` — still confirmed blocked

Searched: IEEE DataPort (`crisis text emergency chat multilingual
dataset`), Mendeley Data (`crisis text multilingual Hindi Arabic
emergency distress corpus`), general web (`HumSet`, `Emotion driven
Crisis Response... multilingual disaster`).

Real candidates checked and rejected:
- **"Emotion driven Crisis Response: A benchmark Setup for Multi-lingual
  Emotion Analysis in Disaster Situations"** (IEEE Xplore paper) — real,
  genuinely multilingual (English + Hindi disaster tweets), but this is a
  conference paper describing an annotation methodology; no confirmed
  standalone open-license public dataset download was located for it in
  this session (IEEE Xplore paper page was not directly fetchable in this
  environment; no separate IEEE DataPort/Mendeley record found for its
  underlying data).
- **"Emotional message-exchanges during 18 crisis events"** (IEEE
  DataPort, https://ieee-dataport.org/documents/emotional-message-exchanges-during-18-crisis-events,
  freely downloadable per search results, DOI 10.21227/yajb-6y77) — real
  and open-access, but content is anonymized Twitter user-ID interaction
  **networks** labeled with Plutchik emotions, not raw distress-labeled
  text, and English-only social-media data from 2017-18 crisis events —
  does not meet m7's multilingual, text-content requirement.
- **HumSet** (https://huggingface.co/datasets/nlp-thedeep/humset) — real,
  genuinely multilingual (English/French/Spanish) humanitarian document
  corpus, Apache 2.0 license claimed on GitHub, but access in practice
  requires emailing the maintainers, and — more importantly — its labels
  are humanitarian-response themes (shelter, food security, health,
  etc.), not personal distress/danger classification. Domain mismatch,
  same category as Day 296's Dreaddit rejection (real corpus, wrong label
  space/scope).
- **Arabic 911 dataset** (Mendeley Data,
  https://data.mendeley.com/datasets/8j268m8pr7/1) — real Arabic-language
  emergency-call dataset, but single-language (Arabic only, not the
  multilingual set m7 needs) and appears to be call-routing/audio-focused
  rather than a distress-labeled text corpus per its description.

**Verdict: still exhausted for the multilingual requirement.** No real
multilingual (Hindi/Tamil/Telugu/Bengali/Marathi/Arabic/Spanish/French/
Mandarin) distress-text classification corpus was found on these
platforms. Day 288/296's conclusion stands.

## 6. `h_aggressive_speech` — still confirmed blocked

Searched: IEEE DataPort (`threatening speech aggressive tone audio
dataset`), Mendeley Data (`calm menacing threatening voice tone dataset
emotion`).

Real hits found are all off-register: **IndoToxSpeech** (IEEE DataPort)
is toxic/confrontational Indonesian YouTube-scammer audio — loud,
escalating verbal conflict, the same "wrong register" (loud/shouting)
already rejected in Day 288/296, not calm-but-menacing. **RAVDESS**
(referenced via Mendeley-adjacent search) has a "calm" emotion category
but no "menacing"/"threatening" category paired with it — off-topic
mismatch. No dataset specifically labeling calm-but-threatening prosody
(as distinct from loud aggression) was found on Mendeley Data or IEEE
DataPort.

**Verdict: still confirmed blocked.** No real calm-menacing-tone speech
corpus was found on these platforms either.

## Summary table

| model | genuinely usable real dataset found this session? | reason if not |
|---|---|---|
| `m4/m5_vocal_stress` | No | StressID = EULA-gated; CARES = no accessible distribution; OSF social-anxiety = wrong content (anxiety, not danger distress) |
| `n_breathing_distress` | No | All real hits are the same clinical/COVID-stethoscope domain mismatch already rejected twice |
| `m1_pocket_muffled` | No | No pocket/telephone-degradation paired corpus found on any new platform |
| `w1` fusion | No | Freesound = isolated scream clips, no motion channel; IEEE DataPort/UR Fall = IMU/camera only, no audio, and license/access-gated anyway |
| `m7_nlp_context_enhanced` | No | Real multilingual crisis-text resources found (HumSet, Hindi disaster-tweet paper) but wrong label space (humanitarian themes, not distress) or no confirmed open dataset link |
| `h_aggressive_speech` | No | Real hits are loud/toxic confrontational speech (wrong register) or lack a menacing category at all |

This is a real, honest "still exhausted" outcome across all 6 models
after searching platforms genuinely new to this project (Mendeley Data,
IEEE DataPort, Google Dataset Search framing, OSF, Common Voice's
derivative ecosystem, Freesound.org directly). Unlike Day 296, this round
did not surface any candidate that both matched content and cleared the
open-license bar — every real, on-topic-looking hit here failed on
license (StressID's EULA, IEEE DataPort subscription paywalls, UR Fall's
NC-SA license) or content-domain mismatch (clinical breathing, network
graphs instead of text, wrong emotional register). That is a valid,
real result, not a failure to search harder — academic dataset
repositories skew toward gated/NC licensing for exactly the kind of
sensitive personal-audio content this project needs, more so than Kaggle
or Hugging Face did.

## What this session did NOT do

No retrain was attempted for any model — this was a research/discovery
task only, per the task's own scope. No `zapsafe_mobile`
detector/wiring/`.tflite`/`pubspec.yaml` files touched, no backend files
touched, no `kaggle_notebooks` files touched. No datasets were downloaded
in full this session; all verification was via real search-result content
and direct page fetches (where the domain was fetchable) of dataset
description/license pages.

## Where this was committed

- `zapsafe_mobile`, branch `day299-new-platforms-search` (fresh worktree
  off `main` at commit `58a84c7`, via `git worktree add`): this doc only.
- Not pushed.
