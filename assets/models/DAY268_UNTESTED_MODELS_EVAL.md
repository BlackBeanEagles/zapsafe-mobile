# Day 268 — investigating the 5 models `PREPROCESSING_SPEC.md` logged as "untested, not bad"

Follow-up to `PREPROCESSING_SPEC.md`'s Day 259 "Untested, not bad — logged
rather than debugged today" list and `WEEK_ML_TRIAGE_SUMMARY.md`'s Day
258–260D rollup. Those docs cover only the **audio/IMU** models
(`m1`/`m2`/`m_glass_breaking`/`mg_gunshot`/`k_confinement`/
`o_running_fleeing`/`s_crowd_panic`/`m2_motion_b`) — none of them are `m3`,
`m8`, `m7`, `h_aggressive_speech`, or `w_*`. This session's job was to
identify what those five actually are, get their real tensor signatures
directly from `interpreter.get_input_details()`/`get_output_details()` (not
filenames or stale docs), and determine whether real eval data now exists.

**Headline finding: none of the 5 are audio or IMU models at all.** They
span three modalities this week's harness (`tools/day260_ml_triage/`) was
never built for — image, face-landmark-sequence, and tokenized text — plus
one meta-model that consumes other models' *scores*, not raw sensor data.
This is not a gap in this session's effort; it's why `PREPROCESSING_SPEC.md`
logged them as "not attempted" rather than giving them a real/dead verdict
in the first place.

## `m3` — confirmed to be a DIFFERENT, un-shipped variant, not `m3_scene_analyzer.tflite`

Real files, both loaded and inspected directly with
`tf.lite.Interpreter(...).get_input_details()`:

| file | shape | dtype | output | source |
|---|---|---|---|---|
| `assets/models/scene_analyzer_v1.tflite` (shipped) | `[1,224,224,3]` | **uint8** (quant scale 0.0039, zero 0) | `[1,1]` uint8 | production m3 |
| `kaggle_notebooks/day103_adversarial_push/.../adversarial/m3/m3_scene_adversarial.tflite` (staged, untested) | `[1,160,160,3]` | **float32** | `[1,1]` float32, input name `serving_default_scene_input:0` | day103 adversarial push |

Confirmed different checkpoints: different input resolution (224×224 vs
160×160), different dtype (uint8 quantized vs float32), different input
tensor name. `PREPROCESSING_SPEC.md` line 274 additionally lists a second
staged variant, `m3_lighting_augmented`, as `[1,128,128,3]` f32 → `[1,3]`
(3-class) — a third, still different geometry from both of the above. So
there are at least three distinct `m3`-family checkpoints on this machine;
only `scene_analyzer_v1.tflite` is shipped.

Training script: `kaggle_notebooks/day103_adversarial_push/day103_m3_adversarial.py`
— an image scene classifier for "safe vs unsafe" real-world scenes
(adversarial/lighting-augmented variant of the day-earlier m3 scene model),
not audio or motion.

**Real eval data check**: `ml_datasets/scene_images/` locally contains
`ADE20K` and `Places365` — both real scene-image datasets, but neither is
labeled safe/unsafe (ADE20K is semantic-segmentation categories, Places365
is scene-category classification) — the same gap `PREPROCESSING_SPEC.md`
flagged ("no labelled real image dataset staged for safe/unsafe scenes").
No Kaggle dataset in `hridyajain/*` (checked `kaggle datasets list -m`,
Kaggle API confirmed authenticated and working — `access_token` and
`kaggle.json` both present under `~/.kaggle`) provides a safe/unsafe scene
label set either.

**Verdict: STILL-UNTESTABLE.** No labeled positive/negative real image data
for the actual target class (safe vs unsafe scene) exists locally or on
this account's Kaggle datasets. `ADE20K`/`Places365` could feed a *proxy*
label (e.g. "outdoor+dark" vs "indoor+lit") but that would be a
hand-invented label, not the model's real training target, and risks the
same kind of scope-mismatch `o_running_fleeing` hit this week — not
attempted for that reason.

## `m8` — `m8_blink_liveness`, a face-landmark-sequence liveness detector, real tensor confirmed

Real interpreter check on
`kaggle_notebooks/day108_int4_m9_push/_v10_pull/m8_liveness/m8_blink_liveness.tflite`:

```
INPUTS:  serving_default_landmark_sequence:0  [1, 24, 12]  float32
OUTPUTS: StatefulPartitionedCall_1:0          [1, 1]       float32
```

24 timesteps × 12 landmark features (almost certainly eye-region landmark
x/y coordinates over 24 frames, per the `landmark_sequence` input name) —
this is a face-liveness/blink-detection model, not audio or motion, and has
no relationship to any model in this week's triage.

**Real eval data check**: `ml_datasets/face_detection/` has `DS_LFW` and
`DS_WIDER` — both static face-detection/recognition image sets, not
landmark time-series. Producing a real `[24,12]` landmark sequence requires
a face-landmark extractor (e.g. MediaPipe FaceMesh or dlib 68-point) run
over a real video of an eye blinking, which is not present in this
repository and was not built this session — same gap
`PREPROCESSING_SPEC.md` already identified ("needs a face-landmark
extraction pipeline that doesn't exist").

**Verdict: STILL-UNTESTABLE.** No landmark-sequence data (real or
extractable in-scope) exists locally; `DS_LFW`/`DS_WIDER` are the wrong
data shape for this model's input regardless of labels.

## `m7` — `m7_nlp_context_enhanced`, a tokenized-text NLP model; vocab now confirmed present (spec's blocker was stale)

Real interpreter check on
`kaggle_notebooks/day105_cross_language_push/.../day105_production_20260701T122113Z/m7/m7_nlp_context_hi_ta_crosslang.tflite`:

```
INPUTS:  serving_default_text_input:0     [1, 64]  int32   (token IDs)
OUTPUTS: StatefulPartitionedCall_1:0      [1, 1]   float32
```

`PREPROCESSING_SPEC.md` said the tokenizer/vocab was "absent from the
staging dir." That is **stale for the specific production run checked
here** — `m7_vocab_hi_ta_crosslang.json` exists alongside every `m7/`
output directory this session found (13+ copies across different kernel
versions, including the same `day105_production_20260701T122113Z` folder
the `.tflite` came from), a real `word2idx` char/word mixed vocabulary
(Latin + Devanagari + Tamil + other Indic scripts visible in the first 30
entries). So the model *is* technically runnable with real, matched
tokenizer state — the spec's "unwireable regardless of accuracy" framing
needs updating, though that's a wiring question, not this session's scope.

**Real eval data check**: what's still missing is not the tokenizer but a
**labeled real text corpus** for whatever `m7`'s actual positive class is
(the training script name is `day105_m7_crosslang.py`, describing
"cross-language NLP context" — the specific classification target, e.g.
threat/distress phrase detection vs benign text, was not confirmed from the
docstring in the time available this session). `ml_datasets/apac_languages/`
contains `DS06_CMU_Wilderness` and `DS19_FLEURS` — both are speech corpora
(audio + transcript pairs for ASR), not labeled threat/benign text
sentence sets, so they don't directly supply this model's needed real eval
data either.

**Verdict: STILL-UNTESTABLE.** Vocab/tokenizer blocker is resolved (real
file confirmed present and readable), but a real, labeled text eval set
matching `m7`'s actual training target was not located on this machine or
in this account's Kaggle datasets, and was not built this session.

## `h_aggressive_speech` — the shipped 24KB file is a real int8 export of the SAME model family as the staged ones, not a placeholder

Real interpreter checks:

| file | shape | dtype | size |
|---|---|---|---|
| `assets/models/h_aggressive_speech_v1.tflite` (shipped) | `[1,38]` in / `[1,1]` out | **int8**, quant scale 0.0506 zero -26 (in), scale 0.0039 zero -128 (out) | 24,680 bytes |
| `kaggle_notebooks/day104_adversarial_push/.../adversarial/h/h_aggressive_speech_adversarial.tflite` (staged) | `[1,38]` in / `[1,1]` out | **float32** | 63,880 bytes |
| `kaggle_notebooks/day105_cross_language_push/.../h/h_aggressive_speech_hi_ta_crosslang.tflite` (staged) | `[1,38]` in / `[1,1]` out | **float32** | 63,880 bytes |

**Finding: the 24KB size is not evidence of a placeholder.** All three
files share the identical input tensor name
(`serving_default_prosodic_features:0`), identical shape `[1,38]`, and the
same 38-dim hand-engineered prosodic feature architecture documented in
`kaggle_notebooks/day104_adversarial_push/_kaggle_staging_latest/day104_h_adversarial.py`
(`FEAT_DIM = 38`, a small MLP over prosodic features — pitch/energy/rate
style features, not a spectrogram CNN). A 38-input MLP is expected to be
tens of KB, not the 2-3MB size of this week's mel-spectrogram CNN audio
models (`m_glass_breaking`, `mg_gunshot`, etc.) — those are large because
they ingest a `96x96x3` or `128x128x3` image-shaped mel spectrogram through
convolutional layers; `h_aggressive_speech` never had that architecture.
The size difference between the shipped 24KB and staged 62KB files is
consistent with int8 quantization (shipped) vs float32 (staged) of the same
small MLP, not a different, smaller, or fake model. No training script or
output directory produced a distinctly-named "real" large
`h_aggressive_speech` checkpoint anywhere searched in
`kaggle_notebooks/` or `outputs/` — every `h_aggressive_speech*` artifact
found (day104 adversarial, day105 cross-language `_hi_ta_crosslang`
variant) shares this same 38-dim prosodic architecture.

Training script: `day104_h_adversarial.py` — "H Aggressive Speech
adversarial (calm threatening tone + multi-noise)," prosodic MLP, arch `c`
from the Day 100 sweep default. Detects calm-but-threatening speech tone
via prosodic features (not lexical content), distinct from `m1_scream_v2`
(which detects screaming/loud distress).

**Real eval data check**: needs real audio labeled calm-threatening vs
calm-benign speech to extract the 38 prosodic features from and score.
`ml_datasets/vocal_stress/` and `ml_datasets/audio_events/` (RAVDESS,
IEMOCAP referenced in `day106_fusion_common.py`, EMODB, MELD per this
account's Kaggle datasets) contain real emotional-speech audio, but none of
them are labeled specifically for "calm-threatening tone" as a class — that
label is closer to a stress/anger prosody proxy, and building a defensible
positive/negative split from these general emotion corpora was not
attempted this session (same category of risk `o_running_fleeing` and `m3`
above flagged: inventing a label crosses into training-a-new-eval-set
territory, not evaluating the existing one).

**Verdict: STILL-UNTESTABLE for AUC purposes** (no real, correctly-labeled
"calm-threatening vs calm-benign" audio corpus identified), but the 24KB
placeholder concern is **resolved**: it is a real int8 quantization of the
same real 38-dim prosodic architecture as the staged float32 variants, not
a stub/fake file.

## `w_*` fusion — confirmed to fuse pairs of UPSTREAM MODEL SCORES, not raw sensor modalities, and not audio+IMU like `s_crowd_panic`

Read `kaggle_notebooks/day106_fusion_crosslang_push/.../day106_w_fusion.py`
and `day106_fusion_common.py` (`FUSION_BUILDERS` dict, `fusion_features()`)
directly. Confirmed: every `w_*` head takes **two scalar scores from two
other trained models** (each in `[0,1]`) and computes a 4-dim feature
vector `[s1, s2, s1*s2, |s1-s2|]` — matching `PREPROCESSING_SPEC.md`'s
`[1,4]` f32 input note exactly. This is a late-fusion meta-classifier over
other models' *outputs*, structurally different from `s_crowd_panic`'s
fusion (which takes two raw sensor tensors — `imu [1,128,6]` and
`mel [1,64,64,1]` — as its two inputs, not two upstream scores).

Real per-head modality pairs, read from `FUSION_BUILDERS`:

| head | slug | fuses (real docstring/dict values) |
|---|---|---|
| `w1` | `audio_motion` | M1 scream score + M2 motion score |
| `w2` | `speech_motion` | M4/M5 vocal-stress score + M2 motion score |
| `w3` | `audio_scene` | M1 scream score + M3 scene score |
| `w4` | `whisper_stillness` | J whisper score + M2 stillness flag |
| `w5` | `crash_silence` | I crash score + P silence-after-distress flag |

That is **5** heads (`w1`–`w5`), not the "6 heads" `PREPROCESSING_SPEC.md`
line 278/427 states — re-checked `FUSION_BUILDERS` directly and it defines
exactly 5 keys (`w1` through `w5`); no `w6` builder function or entry
exists anywhere in `day106_fusion_common.py`. Flagging this as a minor
correction to the spec, not a new model found.

None of the 5 heads combine audio+IMU raw sensor data the way
`s_crowd_panic` does — they combine one audio-family upstream score with
one motion/scene/audio-family upstream score, at the score level, after
each upstream model has already run.

**Real eval data / feasibility check**: `train_fusion_model()`'s own
`production_gate_auc: 0.88` and each builder's real-data path (e.g. `w1`
calls `collect_scream_paths()`, `load_mobiact()`, `load_unimib()`,
`imu_motion_score()`, `audio_scream_score()`) shows the training pipeline
itself is designed around real audio + real MobiAct/UniMiB IMU data (the
same MobiAct dataset this week's `DAY264_S_CROWD_PANIC_MOBIACT.md` fixed
the loader for). In principle a real eval is now more feasible than
`PREPROCESSING_SPEC.md`'s Day 259 framing ("not worth testing until
upstream models exist that are worth fusing") assumed, since `mg_gunshot`
and `s_crowd_panic` were retrained and shipped since then. But: `w1`–`w5`
each depend on a **different pair** of upstream models, several of which
(`M3_scene_score`, `J_whisper_score`, `I_crash_score`, `P_silence_after_flag`)
are themselves still confirmed-dead, untested (this doc's `m3` finding
above), or not wired — running a real fusion eval would require first
having trustworthy real scores from all of `M1`/`M2`/`M3`/`M4`/`M5`/`J`/`I`/`P`,
most of which are not currently in a "trustworthy" state per
`WEEK_ML_TRIAGE_SUMMARY.md` and this doc. Building that full chain was out
of scope for this session (it is effectively 5 separate multi-model
integration tests, not one model eval).

**Verdict: STILL-UNTESTABLE.** Blocker is precise: a real `w_*` eval needs
real, trustworthy scores from each head's two named upstream models
first — most of those upstream models (`M3` per this doc, `J`, `I`, `P`)
have no confirmed-real verdict of their own yet, so there is nothing
trustworthy to fuse. This is a prerequisite-chain gap, not a missing-data
gap in the traditional sense.

## Summary table

| model | what it actually is | verdict | why |
|---|---|---|---|
| `m3` (staged variant) | image scene classifier, `[1,160,160,3]` f32, day103 adversarial — confirmed different checkpoint from shipped `scene_analyzer_v1.tflite` (`[1,224,224,3]` uint8) | STILL-UNTESTABLE | no labeled real safe/unsafe scene image dataset locally or on Kaggle account |
| `m8_blink_liveness` | face-landmark-sequence liveness detector, `[1,24,12]` f32 | STILL-UNTESTABLE | no face-landmark extraction pipeline exists; only static face-detection image sets (`DS_LFW`, `DS_WIDER`) available, wrong data shape |
| `m7_nlp_context_enhanced` | tokenized-text NLP model, `[1,64]` int32 | STILL-UNTESTABLE | tokenizer/vocab blocker resolved (real vocab file confirmed present), but no labeled real text corpus for the model's actual target found |
| `h_aggressive_speech` | 38-dim prosodic-feature MLP, calm-threatening-tone speech detector | STILL-UNTESTABLE (AUC); 24KB-placeholder concern RESOLVED — real int8 export of the same real architecture, not a stub | no correctly-labeled "calm-threatening vs calm-benign" real audio corpus identified |
| `w_*` fusion (`w1`-`w5`, not 6) | late-fusion MLP over pairs of **upstream model scores** (not raw audio+IMU like `s_crowd_panic`) | STILL-UNTESTABLE | most named upstream models per head (`M3`, `J`, `I`, `P`) have no trustworthy real-data verdict yet — nothing reliable to fuse |

## What this session did and did not do

Did: recovered real, current tensor signatures for all 5 model families
directly via `interpreter.get_input_details()`/`get_output_details()` on
the actual staged files (not filenames, not stale docs); located and read
each one's real training script to confirm architecture and target;
resolved the `h_aggressive_speech_v1.tflite` 24KB question with direct
evidence; resolved the `w_*` fusion modality question by reading
`FUSION_BUILDERS` directly; confirmed the `m3` staged/shipped distinction
with a direct file comparison; checked `ml_datasets/` and Kaggle API
(`kaggle datasets list -m`, confirmed authenticated) for real eval data for
each.

Did not: retrain, download new Kaggle data, or run any inference/AUC
evaluation for any of the 5 — every one hit a real, stated data or
prerequisite-chain blocker before an eval could be run honestly. No numbers
in this document are fabricated; where a number could not be produced from
real data, the model is marked STILL-UNTESTABLE with the specific missing
input named.

## Files touched this session

- `assets/models/DAY268_UNTESTED_MODELS_EVAL.md` (this file) — new, in
  `zapsafe_mobile`.
- No `.tflite` files, detector code, wiring files, or backend code were
  touched, copied, or modified, per this session's scope.
- No `kaggle_notebooks/` files were modified — this was a read-only
  investigation of existing scripts and staged artifacts, so no commit was
  made in the standalone `kaggle_notebooks` repo.
