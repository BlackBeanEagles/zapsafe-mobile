# Day 300 — PhysioNet, Internet Archive, AcademicTorrents, DAGsHub, BBC Sound Effects, SoundBible search for the 6 still-stuck models

Follow-up to Day 296 (HF/Zenodo/OpenSLR/PapersWithCode/GitHub), Day 298
(TUT Rare Sound Events NC-license rejection for `m_glass_breaking`), and
Day 299 (Mendeley/IEEE DataPort/OSF/Common Voice/Freesound — 0/6 new
usable). This session's job: search platforms genuinely not yet tried —
PhysioNet, Internet Archive, AcademicTorrents, DAGsHub, BBC Sound Effects
Library, SoundBible — for the same 6 confirmed-blocked models:
`m4/m5_vocal_stress`, `n_breathing_distress`, `m1_pocket_muffled`, `w1`
fusion, `m7_nlp_context_enhanced`, `h_aggressive_speech`.

Every candidate below was looked up via real web search and, where the
domain was directly fetchable, a real page fetch (`physionet.org`,
`crisisnlp.qcri.org`, `dl.acm.org` [blocked, 403], `sound-effects.bbcrewind.co.uk`
[license page fetch returned no body; verified via search instead]). No
dataset name, URL, or license below is fabricated.

**Headline: 0 of 6 have a genuinely new, verified-usable candidate on
these platforms either. All 6 remain confirmed-blocked after 6 total
real search rounds.**

## 1. `n_breathing_distress` — PhysioNet, primary focus — still confirmed blocked

Checked the live PhysioNet database index (https://www.physionet.org/about/database/)
and PhysioNet's respiration-topic index (https://physionet.org/content/?topic=respiration)
plus targeted searches for exertion/panting/non-clinical breathing audio.

Real candidates found and checked:
- **ICBHI 2017 Respiratory Sound Database** — the dominant PhysioNet-adjacent
  respiratory-audio result; confirmed to be stethoscope/clinical-microphone
  auscultation recordings of URTI/COPD/asthma/pneumonia patients — the same
  clinical-domain mismatch already rejected in Day 279/296/299.
- **CPAP breathing pressure/flow/thoraco-abdominal-circumference dataset**
  (referenced in PhysioNet search results, includes "panting/short and
  deep/long breath patterns") — real, but it is **pressure and circumference
  sensor data, not microphone audio at all** — cannot train an audio
  classifier on it. Rejected on modality, not license.
- **Stress Recognition in Automobile Drivers** (https://physionet.org/content/drivedb/)
  — fetched directly. Real, open (**Open Data Commons Attribution License
  v1.0**, no credentialing required), but signals are ECG/EMG/GSR/respiration
  (a respiration *belt* trace, not audio), and the page itself states
  "stress ratings from the study are not available" (no labels). No audio
  channel at all — rejected on modality.
- **TAME Pain** (https://physionet.org/content/tame-pain/) — fetched
  directly. Real audio (7,044 recordings, cold-pressor pain speech with
  breath sounds noted in annotations) but **credentialed-access only**
  under the "PhysioNet Restricted Health Data License 1.5.0" — requires
  signing a data use agreement. Rejected on access gating.
- **Bridge2AI-Voice** (https://physionet.org/content/b2ai-voice/) — fetched
  directly. Explicitly states "This PhysioNet project does not contain raw
  audios" (only derived features), and is credentialed-access regardless
  (Bridge2AI Voice Registered Access License). Rejected on both content
  (no raw audio) and access.
- **"An Emotional Respiration Speech Dataset"** (ICMI 2022 companion
  paper, dl.acm.org/doi/10.1145/3536220.3558803) — real paper pairing
  emotional speech with piezoelectric respiration-belt ground truth (20
  subjects, happy/sad/annoying/calm). Page returned HTTP 403 (ACM
  paywall) when fetched directly this session, and no PhysioNet, Zenodo,
  or open-repository mirror was found in search results — appears to be a
  paywalled ACM paper with no confirmed open distribution channel.
  Rejected: not verifiably open-access.

**Verdict: still exhausted.** PhysioNet has real breathing-adjacent data,
but every real hit is either clinical-stethoscope audio (domain mismatch,
already rejected), non-audio sensor data (pressure/ECG/respiration-belt,
wrong modality), or audio that is credentialed-access/paywalled. Day
276/296/299's conclusion stands, now cross-checked against a proper
physiological-signal archive and still empty.

## 2. `m4/m5_vocal_stress` — still confirmed blocked

Checked PhysioNet stress/voice/emotion databases directly, plus
AcademicTorrents and DAGsHub search.

- PhysioNet's own database list surfaced no new distress-speech database
  beyond TAME Pain (credentialed, see above) and Bridge2AI-Voice
  (no raw audio, credentialed).
- AcademicTorrents: searched for stress/emotion speech torrents; the only
  real speech-audio dataset surfaced was **AVSpeech**
  (https://academictorrents.com/details/b078815ca447a3e4d17e8a2a34f13183ec5dec41)
  — real, large-scale, but general talking-head speech with no
  stress/distress/calm-vs-panic label at all. Off-topic, not a candidate.
- DAGsHub: general search surfaced no DAGsHub-hosted vocal-stress dataset;
  results were dominated by the same CREMA-D/Coswara/DAIC corpora already
  known from prior rounds (DAIC is clinical-depression interview content,
  already off-topic per project's prior domain-mismatch reasoning).

**Verdict: still exhausted.** No new open-license natural-speech distress
corpus found on these platforms.

## 3. `m1_pocket_muffled` — still confirmed blocked

Searched Internet Archive and AcademicTorrents for telephone-bandwidth or
fabric/pocket-muffled speech corpora specifically.

No dataset pairing clean speech with real pocket/fabric-muffling or
telephone-degradation was found on either platform — Internet Archive's
audio collections are sound-effects/media libraries, not paired
clean/degraded speech corpora, and AcademicTorrents search returned only
general ASR/TTS corpora with no muffling-specific variant.

**Verdict: still exhausted.** The synthetic `pocket_muffle()` function
remains the least-bad source, per Day 283/286/287/296/299.

## 4. `w1` fusion — still confirmed blocked

Searched Internet Archive directly for scream/distress vocalization audio.

- Internet Archive's **USC Sound Effects Library**
  (https://archive.org/details/SSE_Library_VOICES) and **"scream sounds"**
  collection (https://archive.org/details/ScreamSounds) are real and
  contain scream/vocal-distress clips (e.g. "Man screams as he falls off
  cliff," "Woman screams in dismay"). These are isolated foley/sound-effect
  clips with **no synchronized motion/IMU/accelerometer channel** — same
  structural gap as the Freesound clips already rejected in Day 296/299.
  Not a fusion-dataset candidate regardless of license.
- No AcademicTorrents or DAGsHub hit paired scream audio with motion
  sensor data either.

**Verdict: still exhausted.** No dataset pairing a real distress
vocalization with a real synchronized fall/impact/motion signal was found
on these platforms. Day 280/285/287/295/296/299's conclusion stands.

## 5. `m7_nlp_context_enhanced` — still confirmed blocked

Checked AcademicTorrents and CrisisNLP (https://crisisnlp.qcri.org/,
fetched directly) for multilingual crisis-text corpora.

Real candidates found and checked:
- **GeoCoV19** and **TBCOV** (via CrisisNLP) — real, genuinely multilingual
  (62 languages / 800+ keyword multilingual collection respectively,
  billions of tweets) — but both are COVID-19 pandemic tweet corpora
  (health-crisis/public-health discourse), not personal danger/distress
  text. Same domain mismatch as Day 296/299's disaster-logistics
  rejections.
- **IDRISI-RA** (via CrisisNLP, GitHub-hosted) — real Arabic disaster-tweet
  location-mention dataset, but content is disaster-response location
  extraction, not distress classification, and single-language (Arabic),
  not the multilingual set m7 needs.
- AcademicTorrents search for crisis/disaster text corpora surfaced no
  additional multilingual personal-distress-text dataset beyond the
  CrisisLex/CrisisNLP family already checked.

**Verdict: still exhausted for the multilingual requirement.** No real
multilingual personal-distress-text classification corpus found. Day
288/296/299's conclusion stands.

## 6. `h_aggressive_speech` — still confirmed blocked

Searched PhysioNet, AcademicTorrents, and DAGsHub for calm-but-menacing /
threatening-tone speech corpora; also checked BBC Sound Effects and
SoundBible for any usable negative/ambient audio relevant to this model's
needs.

- No PhysioNet, AcademicTorrents, or DAGsHub hit surfaced a
  calm-menacing-tone speech corpus distinct from loud/toxic aggression —
  same gap as Day 288/296/299.
- **BBC Sound Effects Library** (https://sound-effects.bbcrewind.co.uk/) —
  real, 16,000 clips under the **RemArc Licence**. Verified via search:
  RemArc explicitly permits only personal/educational/research use, bars
  commercial use, political/campaigning/fundraising use, and states that
  **AI/text-and-data-mining use requires separate permission and possibly
  a fee**. Confirmed **not usable** for this commercial app under any
  reading of the license — correctly excluded per this project's
  open-license rule, matching the pre-emptive caution flagged in the task.
- **SoundBible.com** — real, glass-breaking/general sound-effect clips
  exist (mixed public-domain and attribution-required per clip), but no
  speech/vocal-tone content relevant to `h_aggressive_speech` at all;
  SoundBible is a sound-effects site, not a speech corpus source.

**Verdict: still confirmed blocked.** No real calm-but-menacing speech
corpus found on these platforms; BBC's RemArc license is confirmed
unusable (AI use requires paid permission), closing off that lead
cleanly rather than leaving it open.

## Summary table

| model | genuinely usable real dataset found this session? | reason if not |
|---|---|---|
| `m4/m5_vocal_stress` | No | PhysioNet hits are credentialed or feature-only; AcademicTorrents/DAGsHub hits are off-topic (no stress label) or already-rejected clinical corpora |
| `n_breathing_distress` | No | PhysioNet has real breathing-adjacent data but every hit is clinical-stethoscope (domain mismatch), non-audio sensor data (wrong modality), or credentialed/paywalled audio |
| `m1_pocket_muffled` | No | No pocket/telephone-degradation paired corpus on Internet Archive or AcademicTorrents |
| `w1` fusion | No | Internet Archive has real scream clips but no synchronized motion/IMU channel, same structural gap as before |
| `m7_nlp_context_enhanced` | No | CrisisNLP's multilingual sets are COVID/disaster-logistics content, not personal distress text; IDRISI-RA is single-language |
| `h_aggressive_speech` | No | No calm-menacing corpus found; BBC Sound Effects confirmed license-blocked (RemArc bars commercial/AI use without paid permission) |

This is a real, honest "still exhausted" outcome across all 6 models
after a 6th full search round. PhysioNet in particular was a genuinely
promising new angle for `n_breathing_distress` (a real physiological-audio
archive, unlike the general-purpose platforms tried before) and it still
surfaced only clinical, non-audio, or gated content — a meaningfully
different failure mode than prior rounds' "wrong domain" pattern, but the
same practical outcome.

## Is this platform set worth returning to?

**No — this represents a real dead end for the remaining 6 models, not a
budget-exhaustion artifact.** Reasoning:

- PhysioNet is a comprehensive, well-indexed archive of physiological
  data; its full database list and topic index were checked directly, and
  the exertion/panting-audio gap is structural (PhysioNet's audio
  holdings are voice-pathology and clinical-auscultation focused, not
  ambient/mobile-mic distress audio) rather than a search-depth issue.
- Internet Archive and AcademicTorrents are broad-but-shallow for this
  project's specific need (paired/labeled distress audio with clean
  negatives) — they surfaced real content but only single-purpose,
  unlabeled, or unpaired clips, consistent with every general-audio
  platform tried since Day 279.
- BBC Sound Effects was the one platform with a specific, checkable
  licensing question going in, and it resolved cleanly to "blocked" —
  removing ambiguity rather than leaving a lead open.
- SoundBible and DAGsHub added no new real candidates at all for any of
  the 6 models.

Six independent real search rounds (Kaggle x3, HF/Zenodo/OpenSLR/PWC/
GitHub, Mendeley/IEEE DataPort/OSF/Common Voice/Freesound, and now
PhysioNet/Internet Archive/AcademicTorrents/DAGsHub/BBC/SoundBible) have
now covered essentially every major open dataset distribution channel for
these 6 models with a consistent result. Further rounds against
general-purpose dataset platforms are unlikely to be productive; if these
6 models are to improve, the more promising paths are (a) synthetic data
augmentation of existing real data (as already used for
`m1_pocket_muffled`), or (b) first-party data collection, not further web
search.

## What this session did NOT do

No retrain was attempted for any model — this was a research/discovery
task only. No `zapsafe_mobile` detector/wiring/`.tflite`/`pubspec.yaml`
files touched, no backend files touched, no `kaggle_notebooks` files
touched. No datasets were downloaded in full; all verification was via
real search-result content and direct page fetches (where the domain was
fetchable) of dataset description/license pages.

## Where this was committed

- `zapsafe_mobile`, branch `day300-physionet-archive-search` (fresh
  worktree off `origin/main`, via `git worktree add`): this doc only.
- Not pushed.
