# Day 309: Specific real-candidate verification (CPU-only, targeted, not blind search)

Context: 7 models remain confirmed blocked after 8 independent real search rounds
(Day 278, 279, 287, 288, 295, 296, 298, 299, 300, 307): `m4/m5_vocal_stress`,
`n_breathing_distress`, `m1_pocket_muffled`, `w1`-`w5` fusion,
`m7_nlp_context_enhanced`, `h_aggressive_speech`. (`m_glass_breaking` already
has a real usable 0.75 AUC and is lower priority — not re-checked this
session.) This session does **targeted verification** of 5 specific
project-owner-supplied candidates/tables, each opened and inspected live in
the browser (Kaggle, Figshare, Zenodo, GitHub, Nature Scientific Data), not
another blind platform sweep.

## 1. Kaggle: "Emotional Speech Audio Dataset(RAVDESS)" (deepathangadurai/voice-emotion-regconition)

**Real content verified live**: this is a straight re-upload of the RAVDESS
*speech-only* actor set — `Audio_Speech_Actors_01-24`, 1440 `.wav` files,
24 actors, emotions neutral/calm/happy/sad/angry/fearful/disgust/surprised.
License **MIT** (real, permissive).

**Verdict: REJECTED — not new data.** This exact corpus (RAVDESS proper
actor-speech, 1,440 clips) was already identified, attached via Kaggle
(`uwrfkaggler/ravdess-emotional-speech-audio`), and used in the Day 275
`m4`/`m5` vocal-stress retrain alongside TESS/SAVEE/ShEMO/CREMA-D/EmoDB/
IEMOCAP/MELD/VoxCeleb — see
`day303-zapsafe-mobile/assets/models/DAY275_VOCAL_STRESS_RETRAIN.md`. That
retrain's real result was **worse than the retired baseline** (m4: 0.629 →
0.5685; m5: 0.614 → 0.4862, below chance) and concluded the ceiling is
task-level (adversarial-noise mel spectrograms don't carry a learnable
stressed-vs-calm signal at this model capacity), not a missing-RAVDESS
problem. This Kaggle listing is a duplicate mirror of data already tried and
already falsified as a fix — re-downloading it would add nothing.

## 2. Figshare: DECEiVeR (23579862)

**Real content verified live** (page loaded after a delay; full metadata
read): DECEiVeR = "**DatasEt aCting Emotions Valence aRousal**" — NOT a
deception-detection corpus despite the name's surface reading. It is
**physiological recordings** (confirmed via the paper: ECG, EDA, respiration/
PZT, EMG, motion data — no audio channel at all) from 11 professional
theatre actors expressing 5 emotions (neutral, calm, tiredness, tension,
excitement), ~7 hours total. Single file `DECEiVeR_DATASET.zip` (541.38 MB).
**License: CC BY 4.0** (real, confirmed, permissive/commercial-OK).

**Verdict: REJECTED — wrong modality.** No audio channel exists in this
dataset (categories on the page itself: "Electronic sensors, Electronic
instrumentation, Digital electronic devices"). License is clean but
irrelevant since there is nothing to license for an audio model. Does carry
a real respiration (PZT) channel under emotional tension, same
tangential-relevance-but-wrong-modality pattern as WESAD below — noted, not
usable for any of the audio-input models.

## 3. Physiological/affect dataset table

- **K-EmoCon** (Zenodo `10.5281`, record 3931963) — **real audio confirmed**:
  file manifest includes `debate_audios.tar.gz` and `debate_recordings.tar.gz`
  alongside EEG/peripheral signals, from 16 sessions of ~10-min naturalistic
  paired debates, with real arousal-valence + 18 categorical emotion
  annotations from self/partner/external raters. **However, files are
  access-restricted** — Zenodo marks it "Dataset Restricted," requiring a
  separate Google Form user agreement plus manual review/approval by the
  original authors before any file can be downloaded (PII/audiovisual consent
  gate). **Verdict: content genuinely relevant to m4/m5/w1, but not
  obtainable within this session** — this is a real, actionable lead if the
  user wants to personally apply through the gate in a future session, not a
  license-blocker rejection like CC BY-NC.

- **"UAV" → confirmed to be EAV** (EEG-Audio-Video Dataset for Emotion
  Recognition in Conversational Contexts, GitHub `nubcico/EAV`, Zenodo
  `10.5281/zenodo.10205702`) — the table's "2024, cue-based conversation,
  audio+video, arousal/valence" description matches EAV exactly (the
  "UAV" label appears to be a typo/mislabel for EAV). **Real content
  confirmed** via the GitHub README: 42 participants, 5 emotions (neutral,
  anger, happiness, sadness, calmness), 100 real `.wav` audio files per
  participant (20s clips, speaking-only), synchronized with EEG/video, cue-
  based conversational elicitation (closer to naturalistic speech than
  acted screaming — anger here is conversational, not shouted). GitHub repo
  code is MIT-licensed, but the **actual data is gated on Zenodo** — "Dataset
  Restricted," requires filling a Google Form + review, same pattern as
  K-EmoCon. **Verdict: content genuinely relevant (real audio, real anger/
  calmness labels, potentially useful for `h_aggressive_speech`'s
  calm-vs-shouting register gap), but access-gated, not obtainable this
  session.**

- **WESAD** — confirmed real, freely hosted on UCI ML Repository, RespiBAN
  chest device provides a real raw respiration (RESP) channel at 700Hz plus
  ECG/EDA/EMG/TEMP/ACC, with real stress/no-stress labels from the TSST
  protocol. **No audio channel exists.** Per the task's own framing, this is
  tangentially informative (confirms real breathing-under-stress signal
  exists and is learnable in principle) but **not usable** for
  `n_breathing_distress`, which needs actual audio input, not a wearable
  respiration-belt signal. Noted plainly as a modality mismatch, not deep-
  dived further.

- **DEAP, DECAF, ASCERTAIN, DREAMER, AMIGOS, Emognition, FACED** — checked
  via real search of their primary papers/descriptions. All confirmed
  **EEG/ECG/EDA/MEG-centric with no participant-generated audio**: DEAP
  (32-ch EEG + 8-ch peripheral while watching music videos), DECAF (MEG),
  ASCERTAIN/AMIGOS (EEG/ECG/EDA + face video of participants watching
  stimuli, not speaking), DREAMER (ECG/EEG during audio-visual stimuli
  *viewing*, not participant speech), FACED (32-ch EEG, 123 subjects
  watching 28 emotion video clips, no audio recorded from subjects),
  Emognition (physiological + facial, discrete positive-emotion focus). None
  have raw usable audio. **Not deep-dived further per task instruction.**

- **EmoWork** (Nature Scientific Data, `10.1038/s41597-025-06531-2`,
  released via Zenodo) — this one looked the most promising on paper: call-
  center agents in real-time voice interactions with professional actors
  playing dissatisfied customers, three conditions explicitly including
  **C3 "expressive stimulation"** — demeaning/negative language with
  customers *instructed to avoid shouting/prosodic escalation* — a close
  match to this project's own defined `h_aggressive_speech` gap ("calm-but-
  menacing," distinct from shouting). Real audio was genuinely recorded
  (44.1kHz `.wav`, separate customer/worker channels). **However, the paper
  states explicitly: "Because of privacy concerns, audio files are not
  released to the public. Instead, we extracted well-known [prosodic]
  features... No raw audio is included in the public release."** Only
  derived MFCC/F0/ZCR/spectral feature vectors are shared, plus the archive
  is under a controlled-access Data Usage Agreement (DUA) requiring a Zenodo
  request. **Verdict: REJECTED — no raw audio in the public release** (fatal
  for a project that trains from raw waveform/mel-spectrogram, not
  precomputed feature vectors), compounded by gated DUA access. This is the
  closest content-match found this session but is unusable as released.

## 4. Kaggle notebook: "StressScan - Human Stress Detection with NLP" (nasruddinaz)

**Real notebook inspected via its Input tab** (not guessed from the title):
runs entirely on one attached dataset, **"Mental Health Corpus"**
(`reihanenamdari/mental-health-corpus`). Verified that dataset's own page
directly: 27,972 labeled English-language text comments (Reddit-style,
binary label = mental-health-distress/"poisonous" vs. not), **License: CC BY
4.0** (real, permissive). Sample rows confirmed genuinely distress-adjacent
content (self-harm/suicidal-ideation language, anxiety, abuse disclosure).

**Verdict: REJECTED for m7_nlp_context_enhanced — English-only, no
multilingual coverage.** Every sample row inspected is English (informal
Reddit register). There is no evidence anywhere on the dataset page of any
non-English content, language tags, or translations. This fails the
project's specific requirement for a **multilingual** distress-text corpus
for `m7_nlp_context_enhanced` — real, clean, permissively-licensed data, but
single-language mismatch, same category of rejection as prior
register/domain mismatches.

## 5. YouTube-8M (research.google.com/youtube8m)

**Real license verified on the actual download page**: "The dataset is made
available by Google LLC. under a **Creative Commons Attribution 4.0
International (CC BY 4.0) license**" — explicitly stated, permissive,
commercial-use-compatible. No hidden redistribution restriction found beyond
standard CC BY attribution.

**Real content/format verified**: 6.1M video IDs, 3,862 classes, but the
**only downloadable form is precomputed 8-bit-quantized feature embeddings**
— 1024-dim visual + **128-dim audio (VGGish-style) embeddings, one vector
per second**, delivered as TFRecord shards. There is **no raw audio or raw
video file download offered at all** (frame-level features are 1.53TB of
quantized embeddings, not media files). This is incompatible with this
project's training pipeline, which needs raw waveform to compute its own
mel-spectrograms — precomputed third-party embeddings can't be fed into the
existing `wave_to_mel`/`mel_to_image` preprocessing.

**Label vocabulary checked**: the visible top-level vocabulary (Games, Car,
Football, Food, Performance art, Animal, Basketball, etc., 24 top-level
verticals) is generic topical/entity content — no danger, incident, assault,
crash, or distress-adjacent classes surfaced. No genuinely relevant labeled
subset for `w1`-`w5` fusion or any danger-adjacent need was found.

**Verdict: REJECTED — real permissive license, but wrong data form
(precomputed embeddings, not raw audio/video) and no relevant label
subset identified.** Not attempted to use "wholesale" per the task's own
guidance, since neither the modality nor the vocabulary clears the bar.

## Retrain

**No retrain attempted this session.** Every one of the 9 real candidates
checked (RAVDESS reupload, DECEiVeR, K-EmoCon, EAV, WESAD, the 7
EEG/ECG-centric datasets, EmoWork, Mental Health Corpus, YouTube-8M) failed
on a concrete, verified reason: duplicate-of-already-used-data, wrong
modality (no audio), access-gated (real content but requires external
author approval this session can't complete), features-only (no raw audio
despite audio having been recorded), English-only vs. multilingual need, or
precomputed-embeddings-not-raw-media. None cleared the bar of "real,
downloadable now, license-clear, content-matching" needed to justify a
Kaggle CPU retrain. Forcing a retrain with none of these would only
reproduce a previously falsified or previously out-of-scope result.

## Bottom line

- **0 of 5 candidate items/tables produced an immediately usable dataset.**
- **2 real, content-relevant leads exist but are access-gated, not
  license-blocked**: K-EmoCon (Zenodo, real audio + arousal/valence, debate
  conversations) and EAV (Zenodo, real audio + anger/calmness, cue-based
  conversation) both require the user to personally submit a Google Form
  application and wait for author review/approval — this is a genuinely
  different category from the CC BY-NC-SA license dead-ends found in prior
  rounds, since approval is possible, just not completable inside this
  session. If the user wants to pursue either, next step is applying via
  the linked forms themselves (K-EmoCon: `forms.gle/DUAERhHqf51kyt4Y9`; EAV:
  `forms.gle/QvFY7EAwXgsnv9bcA`) — outside this session's scope to submit on
  the user's behalf.
- **EmoWork was the closest content match found across all 9 candidates**
  for `h_aggressive_speech`'s calm-but-menacing gap (real actors, real
  calm-demeaning-language condition, real recorded audio) but its public
  release explicitly strips the raw audio, shipping only derived prosodic
  features — a hard blocker for this project's raw-waveform pipeline.
- **All 7 remaining models stay genuinely blocked** after this 9th
  independent real search/verification round. The pattern from prior rounds
  holds: real, verifiable hits keep surfacing, but each fails on a specific,
  documented, non-fabricated reason (duplicate data, wrong modality, gated
  access, features-only release, wrong language, or wrong data form) — not
  on search effort.
