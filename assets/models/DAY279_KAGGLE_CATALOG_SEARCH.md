# Day 279 — full Kaggle public catalog search for the 3 stuck models (real result: no genuine match found for any)

Scope: `m_glass_breaking` (AUC 0.7485/recall 0.535 best, day262; architecture
change made it worse, day277), `m4/m5_vocal_stress` (retired ~AUC 0.61-0.63,
day267; adding TESS/SAVEE/ShEMO made it worse, day275), and
`n_breathing_distress` (retired; FSD50K `Breathing` gave weak AUC 0.582,
day276) have each failed two real attempts using datasets already known to
this project. This session searched Kaggle's full public dataset catalog
(`kaggle datasets list -s "<query>"`), not just datasets already attached to
this project, for purpose-built real datasets that might genuinely fix each
task. **Real result: no genuinely better dataset was found for any of the
three.** No retrain was attempted for any model — per the task's own
instructions, a retrain only happens if a real, confirmed-better dataset is
found first, and none was.

## 1. `m_glass_breaking` — no genuine match found

Search queries run (all via `kaggle datasets list -s "<query>"`, real
output, not paraphrased): `glass breaking sound`, `glass break detection`,
`glass shatter`, `impact sound classification`, `broken glass audio`,
`window break sound`, `glass breaking dataset`, `security sound event`,
`acoustic event detection audio`.

Findings: the overwhelming majority of hits are unrelated (car-damage
*image* datasets matching on the word "damage"/"crash", Spotify/TikTok
datasets matching on unrelated keywords, animal-disease datasets matching
"condition"). `broken glass audio` returned zero results.

One real audio candidate: `ammarjagadhita/crack-sound` (72MB). Inspected its
file listing directly (`kaggle datasets files`) — 14 raw Freesound-sourced
`.wav` files (`249548__fngersounds__glass_break1.wav`,
`653974__221296__smashing-glass-owi.wav`, etc.), several of which are ice
cracking/breaking rather than glass (`329744__humanoide9000__ice-break.wav`,
`677716__augustsandberg__breaking-icicles-2.wav`), one file duplicated
(`653974...owi.wav` appears twice, once with `(1)` suffix). No negative
class, no labels/metadata, 14 clips total. This is smaller and lower-quality
than what's already been exhausted (1,129 real positives already collected
from ESC-50+FSD50K+AudioSet+NIGENS per day263/day277) — not a genuine
improvement, would not be used even as a supplement.

**Verdict: no genuinely better dataset exists on Kaggle for this task.**
Day 262's model (AUC 0.7485, recall 0.535) remains the best real result.
Confirms day277's own conclusion that local data is exhausted, now extended
to the full public catalog, not just this project's existing sources. The
only real remaining lever flagged by day277 — a YouTube-download pipeline
for uncached AudioSet glass rows — is infrastructure work, not a dataset
search, and stays out of scope here.

## 2. `m4/m5_vocal_stress` — no genuine match found

Search queries run: `stress detection speech`, `duress speech`,
`panic speech`, `distress call audio`, `emergency call speech`,
`911 call audio dataset`, `speech under stress`, `call center emotion
audio`. `duress speech` returned zero results.

Two real candidates inspected in depth:

- **`thallaanusha/women-safety-distress-audio-dataset`** (8MB). Real
  description: "safe, warning, and danger speech categories with
  scenario-based annotations such as indirect distress, panic leakage,
  controlled fear, and casual conversation" — genuinely on-topic in
  concept. But usability rating 0.41, only 10 downloads/1 vote, and file
  listing shows a small, uniformly-sized (~100-170KB) set of `A0xx.wav`
  files with no visible label/category split in the file paths themselves
  (labels would require the un-downloaded annotation file, and total size
  is small enough — 8MB — that the realistic real-clip count is roughly
  50-70 short clips). Too small and too unverified to trust as a genuine
  fix after two real datasets already failed on this exact task.

- **`mohithjain04/threat-detection-audio-dataset`** (141MB, "Voice-Triggered
  Threat Detection for Public Safety" final-year project, Hindi/English/
  Kannada, categories: Road Rage, Harassment, Public Violence, Street Abuse,
  Help/Distress Calls). Downloaded and unzipped the full dataset (141MB,
  360 real `.wav` files) to inspect directly rather than trust the
  description. Real findings from the unzipped content:
  - Folder names are keyword/wake-phrases, not natural distress speech:
    `call police/`, `help me/`, `i need help/`, `madat karo/` (Hindi for
    "help"), `mujhe_bachao/`, `palice call martini/`, `Sendhelp/` — this is
    a keyword-spotting/wake-word dataset (short phrase utterances), not
    continuous emotional/prosodic speech matching the existing
    distress-vs-calm label scheme (SAD/ANG/FEA vs NEU/HAP/calm) that
    m4/m5's collectors use.
  - Heavy exact duplication: of 360 `.wav` files, only 180 are unique after
    stripping `" - Copy"`/`" - Copy (2)"` suffixes — literally the same
    "duplicate-oversampling" anti-pattern day277 flagged as a real
    overfitting risk in this project's own m_glass_breaking work, baked
    into the dataset itself.
  - **No negative/calm class at all** — every folder is a distress/threat
    phrase category; there is nothing to pair as the "calm" class this
    binary task requires.

**Verdict: no genuinely better dataset exists on Kaggle for this task.**
Neither candidate is a real fix: one is too small/unverified, the other is
wrong-format (keyword phrases, not natural stressed speech), duplicate-heavy,
and missing the negative class entirely. Day 275's conclusion stands: the
retired `m4_vocal_stress_en_adversarial`/`m5_vocal_stress_apac_adversarial`
models are not re-stageable with public data found so far.

## 3. `n_breathing_distress` — no genuine match found

Search queries run: `asthma breathing`, `respiratory distress audio`,
`COPD breathing sounds`, `abnormal breath sounds`, `labored breathing`,
`lung sound classification`, `breathing sound dataset`. `respiratory
distress audio` returned zero results.

Real hits are dominated by a specific, well-known family: `vbookshelf/
respiratory-sound-database` (the ICBHI Respiratory Sound Database),
`praveengovi/coronahack-respiratory-sound-dataset`, `arashnic/lung-dataset`,
`mohammedtawfikmusaed/asthma-detection-dataset-version-2`,
`yashanathaniel/asthma-respiratory-dataset`, `yasamantorabi/heart-and-lung-
sounds-dataset-hls-cmds`, `maulikgajera/cardiopulmonary-sound-signals-for-
deep-learning`. These are all real, clinically-labeled datasets — but every
one of them is **stethoscope-recorded lung auscultation audio** (a
diaphragm/microphone placed directly on the chest wall, capturing internal
crackles/wheezes/rhonchi), not phone-microphone-recorded ambient breathing.
This is a fundamentally different acoustic domain from what
`n_breathing_distress` needs: the deployed model listens to a phone's
built-in mic picking up a person's audible panting/gasping/labored breathing
in open air during a duress event, not internal chest sounds through a
stethoscope diaphragm. Training on stethoscope audio and deploying on phone-
mic audio would be a much larger domain-shift problem than day276's already-
diagnosed issue (FSD50K's generic `Breathing` label not being
distress-specific) — stethoscope crackle/wheeze acoustics simply do not
resemble open-air panting/gasping in frequency content or recording
characteristics, so this would very likely perform *worse* than the day276
FSD50K result (AUC 0.582), not better, and was not worth an actual retrain
to confirm.

**Verdict: no genuinely better dataset exists on Kaggle for this task.**
The clinical respiratory-audio datasets that dominate this search are real
and well-labeled, but for a different recording modality than this model
needs. Day 276's finding stands: `n_breathing_distress` stays retired: real,
modest, above-chance signal exists via FSD50K's Breathing/Gasp/Respiratory_
sounds/Sigh labels (AUC 0.582) but nothing found this session clears that or
provides a genuinely distress-specific, phone-mic-domain source.

## Summary

| model | genuinely better dataset found? | retrain done? | result |
|---|---|---|---|
| `m_glass_breaking` | No | No | No change — day262 (AUC 0.7485/recall 0.535) remains best |
| `m4/m5_vocal_stress` | No | No | No change — both stay retired per day267/day275 |
| `n_breathing_distress` | No | No | No change — stays retired per day276 |

This is a real, honest "no genuinely better dataset found" outcome for all
three models, reached by actually searching Kaggle's full public catalog
(9 search-query variants for glass, 8 for vocal stress, 7 for breathing),
inspecting real file listings and descriptions of the most plausible
candidates (including a full download+unzip of the threat-detection-audio
candidate), and rejecting each one on a specific, stated, verifiable
technical basis rather than a vague "didn't look right." No retrain was run
for any model because the task's own instructions gate a retrain on finding
a real, confirmed-better dataset first — that gate was never cleared.

## What was NOT done (explicitly out of scope, and not needed given the null result)

No `zapsafe_mobile` detector/wiring files touched, no `assets/models/*.tflite`
changed, no `pubspec.yaml` changed, no backend files touched. No Kaggle GPU
training runs were started for this session (no candidate dataset cleared
the bar to justify one). The downloaded `mohithjain04/threat-detection-
audio-dataset` zip/unzipped content used for inspection lives only in this
machine's local temp scratch space, not in either git repo.

## Where this was committed

- `zapsafe_mobile`, branch `day279-kaggle-catalog-search` (fresh off `main`
  at commit `58a84c7`, via a separate `git worktree add` so as not to touch
  other agents' concurrent uncommitted work in the main tree, e.g.
  `day274-light-sensor`/other in-progress branches): this doc only.
- `kaggle_notebooks` (standalone repo): no changes — no new training script
  was needed since no dataset cleared the bar for a retrain.
- Neither repo was pushed.
