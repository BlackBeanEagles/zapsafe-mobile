# Day 282 — w2-w5 fusion investigation (same scrutiny applied to w1)

Follow-up to `DAY280_W1_FUSION.md`, which found `w1` (`w_audio_motion_fusion`,
M1 scream + M2 motion) has a circular-labeling problem: its training labels
are a hardcoded threshold rule applied to the same two scores the model
takes as input, so its reported 0.9568 AUC measures nothing but the
network's ability to approximate that rule. This session applied the exact
same scrutiny to the four sibling heads (`w_audio_scene_fusion`,
`w_crash_silence_fusion`, `w_speech_motion_fusion`,
`w_whisper_stillness_fusion`) rather than assuming w1's bug was unique.

## Source read

`kaggle_notebooks/day106_fusion_crosslang_push/day106_fusion_common.py`,
functions `build_w1_dataset()` through `build_w5_dataset()` (lines 388-519)
and the score-generating helpers they call (lines 58-124).

## Real head <-> build-function mapping

Cross-referenced against `DAY278_REMAINING_BLOCKED_RECHECK.md`'s table
(`w1`-`w5` = `audio_motion`, `speech_motion`, `audio_scene`,
`whisper_stillness`, `crash_silence`) and the day108 manifest
(`zapsafe_backend/ml/fixtures/day108_shipping_manifest.json`, which names
`w_crash_silence_fusion.tflite` explicitly at 2.95 KB, matching `w5_lite_int4`
at the same 2.95 KB):

| build fn | inputs (s1, s2) | real name |
|---|---|---|
| `build_w1_dataset` | scream, motion | `w_audio_motion_fusion` (w1, already evaluated Day 280) |
| `build_w2_dataset` | vocal stress, motion | `w_speech_motion_fusion` (w2) |
| `build_w3_dataset` | scream, quiet-scene | `w_audio_scene_fusion` (w3) |
| `build_w4_dataset` | whisper, stillness | `w_whisper_stillness_fusion` (w4) |
| `build_w5_dataset` | crash, silence-after | `w_crash_silence_fusion` (w5) |

## Finding 1 (critical, applies to all four): same circular-labeling bug as w1, and it's worse

Every one of `build_w2_dataset` through `build_w5_dataset` generates its
label with a hardcoded threshold rule applied directly to the same two
scalar scores (`s1`, `s2`) that `fusion_features(s1, s2)` turns into the
model's 4 input features (`[s1, s2, s1*s2, |s1-s2|]`, `FEAT_DIM = 4`,
identical to w1's feature scheme):

- w2 (line 443): `y.append(1 if s1 > 0.4 and s2 > 0.45 else 0)`
- w3 (line 468): `y.append(1 if s1 > 0.5 and s2 > 0.55 else 0)`
- w4 (line 486): `y.append(1 if s1 > 0.45 and s2 > 0.55 else 0)`
- w5 (line 509): `y.append(1 if s1 > 0.55 and s2 > 0.5 else 0)`

This is the exact w1 anti-pattern (label = AND-threshold on the same two
inputs the model receives), confirmed independently for each of the four —
not assumed from w1's precedent. **Any reported AUC for w2-w5 is a
measurement artifact of the same kind Day 280 found for w1: it would show
the network reproducing a 2-variable AND gate, not learning real combined-
risk discrimination.** No retrain or re-evaluation was run, because the
labeling bug alone already disqualifies the number regardless of what it
would read (same reasoning Day 280 used to conclude "retraining would not
fix this — the label source itself is the problem").

## Finding 2 (new, more severe than w1): the "upstream model" scores aren't model inference at all

Checked what `s1`/`s2` actually are for each head, since Day 278's blocker
table assumed real upstream `.tflite` models were being scored:

- `audio_scream_score`, `audio_vocal_stress_score`, `audio_whisper_score`,
  `audio_crash_score`, `audio_silence_after_score`, `scene_isolated_score`
  (lines 73-124) — none of these call `m1_scream_v2`, `m3_scene_analyzer`,
  `i_vehicle_crash`, `j_whisper_distress`, or any `.tflite` interpreter.
  They are hand-written signal heuristics computed directly from raw audio
  (RMS, mel-band energy, zero-crossing rate, `librosa.pyin` jitter, onset
  strength, post-half-clip RMS) or raw IMU (`imu_motion_score` /
  `imu_stillness_score` = `1 - motion*1.2`, std/jerk of accel magnitude).
- So for w2-w5, "fusing two models" is fiction at the training-data level:
  the pipeline never invokes the named upstream models at all, real or
  otherwise. It computes two cheap heuristic scores off the same raw
  clip/window, thresholds them into a label, and trains a small MLP to
  reproduce that threshold. This means the upstream-dependency status
  question (Finding 3 below) is moot for whether these numbers can be
  trusted — they were never wired to real upstream models to begin with,
  independent of whether those upstream models work.

## Finding 3: upstream dependency status (for completeness, per the task's ask)

Per `WEEK_ML_TRIAGE_SUMMARY.md` and `DAY278_REMAINING_BLOCKED_RECHECK.md`
(both already finalized this week, re-confirmed here, not re-derived):

- w2 (speech_motion): M4/M5 vocal-stress retired, fp32 AUC ~0.62-0.63 (near
  chance) — blocked.
- w3 (audio_scene): M3 scene analyzer still untestable, no safe/unsafe
  labeled real data exists locally or in Drive — blocked.
- w4 (whisper_stillness): J whisper_distress confirmed retired — its
  "whisper" class is a synthetic gain-reduction transform, not a real
  acoustic property, and no real whisper corpus (wTIMIT/CHAINS) exists in
  this Kaggle account or Drive folder — blocked, same root cause as `j`
  itself, matches the task's prediction.
- w5 (crash_silence): I vehicle-crash is real and shipped (AUC 0.96 fp32),
  but the fusion script's "silence-after" input is not a model at all (see
  Finding 2) — it's `audio_silence_after_score()`, RMS of the clip's second
  half. There is no "P" model being invoked, so I's real status doesn't
  make w5 trustworthy; the fusion labels are still circular per Finding 1.

## Finding 4: no real evaluation was run for w2-w5

Per the task's own instruction ("for any w2-w5 model where labels are
genuinely independent... AND upstream models are real, evaluate against
real data") — none qualify. All four have circular labels (Finding 1) and
none of the four actually invoke real upstream models (Finding 2), so there
is no case here where a real-data AUC would be informative. Consistent with
w1's Day 280 conclusion: fixing this would require rebuilding
`build_w2_dataset()`-`build_w5_dataset()` from scratch with (a) real
upstream `.tflite` inference instead of heuristic proxies, and (b) an
independent label source (real annotated combined-event recordings), which
does not exist in this project's Kaggle account or Drive folder per Day
278's exhaustive check.

## Finding 5: the 3 mystery `*_lite_int4.tflite` files

Read `kaggle_notebooks/day108_int4_m9_push/day108_int4_batch2.py` (Day 108
INT4/Lite-tier quantize batch 2), which explicitly defines these three as
outputs, not new models:

```python
TARGETS = {
    ...
    "o": ("o_running_fleeing", "o_running_fleeing_adversarial"),
    "w4": ("w_whisper_stillness_fusion",),
    "w5": ("w_crash_silence_fusion",),
}
```
Output naming: `dst = OUT / f"{key}_lite_int4.tflite"` (line 269) — so:

- `o_lite_int4.tflite` = lite export of `o_running_fleeing.tflite`.
- `w4_lite_int4.tflite` = lite export of `w_whisper_stillness_fusion.tflite`.
- `w5_lite_int4.tflite` = lite export of `w_crash_silence_fusion.tflite`
  (confirmed independently: the day108 shipping manifest lists
  `w_crash_silence_fusion.tflite` at 2.95 KB and `w5_lite_int4.tflite` at
  the identical 2.95 KB).

Critically, `export_lite_variant()` (lines 205-241) only applies real
`tf.lite` DEFAULT quantization when a `saved_model_export/` directory sits
next to the source file; otherwise it falls back to `mode =
"copy_int8_fallback"` and writes `out_bytes = src.read_bytes()` — a
byte-identical copy under a new filename. None of `o_running_fleeing`,
`w_whisper_stillness_fusion`, or `w_crash_silence_fusion` have a
`saved_model_export/` sibling anywhere found in this repo, and the matching
2.95 KB size for w5/`w_crash_silence_fusion` confirms the fallback path was
taken for at least that one. **All three `*_lite_int4` files are not new
models and not genuinely int4-quantized** — they are renamed duplicate
copies of `o_running_fleeing.tflite`, `w_whisper_stillness_fusion.tflite`,
and `w_crash_silence_fusion.tflite` respectively, produced by Day 108's
batch-2 "lite" export step falling back to a plain copy.

## Conclusion

- w2, w3, w4, w5 all have the same circular-labeling defect as w1 (label =
  hardcoded AND-threshold on the model's own two input scores) — confirmed
  individually for each, not assumed. Worse than w1: none of the four
  actually score real upstream models during training (they use raw-signal
  heuristics), so "fusion of two models" doesn't describe what was trained
  even before the labeling problem is considered.
- No real evaluation was run because no case satisfies the task's own
  qualifying condition (independent labels + real upstream models) — none
  of w2-w5 qualifies on either count.
- The 3 mystery `*_lite_int4.tflite` files are confirmed-by-code renamed
  copies of already-known models (`o_running_fleeing`,
  `w_whisper_stillness_fusion`, `w_crash_silence_fusion`), not new
  artifacts.
- **None of w1-w5 should be wired.** No backend, detector, or wiring files
  touched this session — read-only investigation plus this doc.

## Files touched this session

- `assets/models/DAY282_W2_W5_FUSION_INVESTIGATION.md` (this file) — new,
  in `zapsafe_mobile`, branch `day282-w2-w5-fusion` (worktree at
  `zapsafe_mobile_day282`, off `main`).
- No other files modified. `kaggle_notebooks/` not touched (read-only).
  No `.tflite`, `pubspec`, detector/wiring files, or backend code touched.
