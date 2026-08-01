# Day 287 — Kaggle public-catalog search for m1_pocket_muffled and w1 fusion

## Status: search completed, real candidates inspected, no genuinely usable dataset found for either. No retrain performed. Both models remain unshipped/unwired, unchanged from Day 286/285.

Follow-up to Day 279's catalog search, which covered `m_glass_breaking`,
`m4-m5_vocal_stress`, and `n_breathing_distress` but explicitly did not
cover `m1_pocket_muffled` or `w1`. This session ran that search using
`kaggle datasets list -s "<terms>"` with real query variants, then
inspected real file listings (`kaggle datasets files <ref>`) and metadata
for every plausible candidate, not just titles.

## 1. m1_pocket_muffled — queries run

`"phone in pocket audio"`, `"muffled speech dataset"`, `"telephone
bandwidth speech"`, `"lo-fi speech recognition"`, `"far-field speech
recording"`, `"smartphone pocket audio"`, `"low pass filtered speech"`,
`"distorted speech dataset"`, `"noisy speech corpus"`, `"reverberant
speech"`, `"phone call recording emotion"`, `"VOiCES dataset"`, `"CHiME
speech"`, `"8khz speech corpus"`, `"microphone distance speech"`,
`"speech in noise emotion"`, `"occluded speech"`, `"narrowband speech"`,
`"GSM speech codec"`, `"call center audio distress"`, `"911 call audio"`,
`"voice under stress"`, `"speech through fabric"`, `"attenuated audio
speech"` — 24 queries total.

### Real candidates inspected in depth (not just title)

- **`anuvagoyal/speech-emotion-recognition-for-emergency-calls`**
  ("Speech Emotion Recognition for Emergency Calls", 112MB). File listing
  (`CUSTOM_DATASET/Speaker1/01_01_01_01_01.wav` etc.) uses the exact
  RAVDESS filename-code convention, not real phone-call audio despite the
  title — this is a synthetic/relabeled RAVDESS-style corpus, not genuine
  telephone-bandwidth emergency-call recordings. Rejected: misleading
  title, not real phone audio.
- **`muhmagdy/valentini-noisy`** (Valentini-Botinhao Noisy Speech
  Database, 15GB). Real clean/noisy paired speech-enhancement corpus —
  but the degradation is additive background noise (cafeteria, traffic,
  etc.), not low-pass/fabric-attenuation muffling, and it isn't
  telephone-bandwidth either. Doesn't match the pocket-muffle problem
  (attenuation + high-frequency loss), would just be another noise
  augmentation source. Rejected: wrong degradation type for this task.
- **`louisteitelbaum/911-recordings-first-6-seconds`** and
  **`louisteitelbaum/911-recordings`** (real 911 call audio, 318MB/4GB,
  with `911_metadata.csv`). This is genuinely real telephone-bandwidth
  speech — the closest real match found. But: no muffled-vs-clear
  pairing, no distress-intensity or "clean speech baseline" labels (most
  calls are calm factual reporting, not screaming/high-arousal distress),
  and it's real personally-identifiable emergency-call audio of real
  people's real crises, not something to fold into a training pipeline
  without a much more careful case (labeling effort, consent/ethics
  review) than this session's scope. Rejected: no usable labels for this
  task and real ethical/PII concerns beyond what a quick integration
  should touch.
- **`antonygarciag/fall-audio-detection-dataset`** (SAFE fall-audio, seen
  while searching for w1 but audio-only) — floor-impact sounds only, no
  speech, not relevant to m1.

No dataset combining (a) real audio, (b) a genuine muffled/telephone/
low-pass-attenuated vs. clear pairing or label, and (c) distress-relevant
content was found. The synthetic `pocket_muffle()` low-pass+attenuation
function remains, after this search, the least-bad available source of
muffled positives — not because it's good, but because nothing better
exists in Kaggle's public catalog as of this session.

## 2. w1 fusion — queries run

`"fall detection video audio"`, `"elderly fall vocalization"`,
`"security incident audio video dataset"`, `"scream fall combined"`,
`"emergency incident dataset multimodal"`, `"fall detection scream"`,
`"elderly emergency dataset"`, `"surveillance audio incident"` — 8
queries total.

### Real candidate inspected

- **`antonygarciag/fall-audio-detection-dataset`** ("SAFE: Sound Analysis
  for Fall Event detection", 201MB). Real audio-only impact-sound
  recordings of falls (file listing confirms `.wav` files, no
  video/IMU/motion channel present). No vocalization/scream component,
  no synchronized motion signal of any kind. Rejected: audio-only, no
  motion channel, so it can't supply the missing "audio+motion pair"
  that w1 needs, and it doesn't contain scream/distress vocalization
  either.

All other queries returned zero results. No dataset pairing a real
scream/distress vocalization with a real synchronized fall or motion
signal (video, IMU, or otherwise) exists in Kaggle's public catalog under
any of these query variants. This confirms, rather than merely repeats,
Day 280's and Day 285's conclusion — this is now a second independent
session (with new, real, 279-non-overlapping queries) failing to find
one.

## 3. Conclusion

**No genuinely better dataset was found for either model.** This is a
real, confirmed wall, in the same category as Day 279's finding for
`m_glass_breaking`/`m4-m5`/`n_breathing_distress` — not a failure to
search hard enough. Queries were varied across phrasing (24 for m1, 8 for
w1, all real, run via `kaggle datasets list -s`), and every plausibly
relevant hit was opened and its real file listing inspected, not just
its title.

**No retrain was performed.** Both `m1_pocket_muffled` (independent AUC
0.50–0.56, Day 286) and `w1` fusion (independent AUC 0.578, Day 285)
remain exactly as they were left — unshipped, unwired, no `.tflite`,
detector, backend, or pubspec changes. No new Kaggle kernel was pushed
this session since there was nothing new to train on.

## Files touched this session

- This file only (`assets/models/DAY287_KAGGLE_SEARCH_POCKET_W1.md`),
  worktree `zapsafe_mobile_day287`, branch
  `day287-kaggle-search-pocket-w1`, off `main`.
- No changes to `kaggle_notebooks` beyond this same doc being mirrored
  there (worktree `kaggle_notebooks_day287`, same branch name, off
  `master`) for record-keeping — no script/kernel-metadata changes since
  no retrain occurred.
