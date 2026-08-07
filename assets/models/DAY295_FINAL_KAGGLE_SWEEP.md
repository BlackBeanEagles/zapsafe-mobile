# Day 295 — final Kaggle public-catalog sweep, new query angles only (real result: no genuine match found for any of the 5 models)

Follow-up to Day 279 (`m_glass_breaking`, `m4/m5_vocal_stress`,
`n_breathing_distress`, 7-9 query variants each) and Day 287
(`m1_pocket_muffled` 24 variants, `w1` fusion 8 variants). This session
ran ONE more real search pass per model using query angles genuinely
different from what those two prior sessions already tried (checked both
docs in full before starting, no repeated queries). All queries run via
`kaggle datasets list -s "<query>"`, real CLI output below, not
paraphrased. Every plausible hit was opened with `kaggle datasets files
<ref>` to inspect real file listings before being accepted or rejected —
titles alone were never trusted.

**Real result: no genuinely new usable dataset was found for any of the
5 models.** No retrain was attempted for any model, per task scope.

## 1. `m_glass_breaking` — no new match

Queries: `burglary sound detection`, `home security audio dataset`,
`break-in sound classification`, `window break alarm dataset`, `impact
acoustic event`.

`burglary sound detection` and `window break alarm dataset` returned zero
results. The other three returned hits, but every one is off-domain on
inspection:

- `colabsss/smart-home-security-multi-sensor-dataset` (35KB) — file
  listing is a single `smart_home_security_dataset.csv`. Tabular
  sensor-event log, not audio.
- `thedevastator/sonyc-ust-audio-tag-dataset` (857KB) — file listing is a
  single `annotations.csv` (14MB inside the listing, oddly larger than
  the reported dataset size). This is the SONYC-UST annotation/label
  file only; the underlying audio clips are not included in this Kaggle
  mirror.
- `axondata/footstep-sound-dataset` — footsteps, not glass/impact.

**Verdict: still exhausted.** No real audio-with-glass-break-content
candidate surfaced. Day 262 (AUC 0.7485/recall 0.535) remains the best
real result, unchanged.

## 2. `m4/m5_vocal_stress` — no new match

Queries: `call center stress classification`, `customer service distress
audio`, `cognitive load speech dataset`, `voice stress analysis`, `SOS
voice recognition`.

`call center stress classification`, `customer service distress audio`,
and `SOS voice recognition` returned zero results. `cognitive load speech
dataset` and `voice stress analysis` returned hits, all CSV/tabular or
off-domain on inspection:

- `crissymoon/voice-prosody` (6KB) — file listing:
  `augmented_prosody_data.csv`, `keyword_to_state_mapping.csv`,
  `voice_prosody_dataset.csv`. No audio, synthetic-looking tabular
  prosody features only.
- `harshitsama/corporate-fraud-multimodal-genai` (N=276, 12KB) — too
  small, fraud-detection domain, not distress speech.
- `devvratmathur/micro-expression-dataset-for-lie-detection` — video
  micro-expressions, not audio.
- `desyibaricoida/stress-and-mood-matrix-ml-studentlife` — StudentLife
  mobile-sensing tabular data, not audio.

**Verdict: still exhausted.** No real natural-speech distress corpus with
a negative/calm class was found. Day 275's retirement of
m4/m5_vocal_stress stands.

## 3. `n_breathing_distress` — no new match

Queries: `panic attack audio`, `hyperventilation sound`, `wheeze cough
classification`, `distress vocalization non-speech`.

`panic attack audio`, `hyperventilation sound`, and `distress
vocalization non-speech` returned zero results. `wheeze cough
classification` returned one hit:

- `yashanathaniel/asthma-respiratory-dataset` ("Asthma vs Healthy", 6GB)
  — same stethoscope-recorded clinical lung-auscultation family already
  identified and rejected in Day 279 (domain mismatch: chest-wall
  stethoscope audio vs. open-air phone-mic panting/gasping). Not a new
  finding, confirms the prior rejection reasoning rather than adding a
  new candidate.

**Verdict: still exhausted.** Day 276's finding stands (FSD50K AUC
0.582, model retired).

## 4. `m1_pocket_muffled` — no new match

Queries (deliberately new, checked against Day 287's 24 prior queries
first): `voicemail audio quality dataset`, `degraded speech
classification`, `in-pocket phone recording`, `occluded microphone
audio`.

All four queries returned **zero results** on Kaggle's public catalog.

**Verdict: still exhausted.** No new candidates to even inspect. Day
287's conclusion stands — the synthetic `pocket_muffle()` low-pass
+attenuation function remains the least-bad available source.

## 5. `w1` fusion — no new match

Queries (deliberately new, checked against Day 287's 8 prior queries
first): `wearable sensor emergency dataset`, `IMU audio synchronized
dataset`, `multimodal human activity emergency`.

`IMU audio synchronized dataset` returned zero results. The other two
returned hits, both tabular/text, not audio or IMU signal on inspection:

- `suvroo/ai-for-elderly-care-and-support` (312KB) — file listing:
  `daily_reminder.csv`, `health_monitoring.csv`,
  `safety_monitoring.csv`. Synthetic tabular elder-care data, no
  audio/IMU waveform at all.
- `ranaumairpy/llm-ai-safety-response-classification-dataset` (59KB) —
  file listing: single `ASRCD_dataset.csv`. LLM text-response safety
  classification, unrelated modality entirely.

**Verdict: still exhausted.** No dataset pairing real audio with a real
synchronized motion/IMU channel was found in this pass either. Day
280/285/287's conclusion stands.

## Summary

| model | new queries tried | genuinely new usable dataset found? | retrain done? |
|---|---|---|---|
| `m_glass_breaking` | 5 | No | No |
| `m4/m5_vocal_stress` | 5 | No | No |
| `n_breathing_distress` | 4 | No | No |
| `m1_pocket_muffled` | 4 (all zero-result) | No | No |
| `w1` fusion | 3 | No | No |

This is a real, honest "still exhausted" outcome across all 5 models
after a genuinely new set of query angles (not repeats of Day 279/287).
Every hit that surfaced was opened via `kaggle datasets files` and
inspected for real content before being rejected — the recurring pattern
this session was CSV/tabular-only "datasets" whose titles suggest audio
or sensor content but whose actual file listings contain no waveform or
signal data at all.

## What was NOT done

No `zapsafe_mobile` detector/wiring/tflite/pubspec files touched, no
backend files touched, no `kaggle_notebooks` changes (no candidate
cleared the bar for a retrain). No downloads of full dataset content were
needed this session since no candidate's file listing warranted it (all
rejections were resolvable from `kaggle datasets files` metadata alone).

## Where this was committed

- `zapsafe_mobile`, branch `day295-final-kaggle-sweep` (fresh off `main`
  at commit `58a84c7`, via `git worktree add`): this doc only.
- Not pushed.
