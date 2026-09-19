# Day 326 — the DCS fusion has never fused anything

`dcs_fusion_v1.tflite` being a placeholder is the *least* of what is wrong
here, and the placeholder is the part that is correctly deferred.

## What the DCS score actually is today

`DCSInferenceEngine.create()` declares an `expectedInputSize` per slot and
passes it to `TfliteInterpreter.tryLoad`. That helper returns **null** when
the model's real input size differs, and the engine then substitutes a
constant-valued stub. Measured against the shipped assets:

| slot | asset | engine declares | model wants | result |
|---|---|---|---|---|
| scream | `scream_classifier_v3.tflite` | — (uses `ScreamDetectorV2`) | — | **real** |
| motion | `motion_fall_v2.tflite` | 6 | **300** | **stub, constant 0.15** |
| scene | `scene_analyzer_v1.tflite` | 8 | **150,528** | **stub, constant 0.25** |
| fusion | `dcs_fusion_v1.tflite` | 3 | *(text file)* | **stub, weights [0.5, 0.3, 0.2]** |

So the fused Danger Confidence Score reduces to:

```
0.5 × scream  +  0.3 × 0.15  +  0.2 × 0.25   =   0.5 × scream + 0.095
                      ↑              ↑
                   constant       constant
```

**The DCS score is the scream probability, halved, plus a fixed offset.**
Motion and scene contribute nothing but a constant. And this is not a lab
path: `app_bootstrap_providers.dart` wires `DCS + fall → state machine`, and
`AppStateNotifier.onDCSThresholdExceeded()` moves the app to `alertPending`
with `TriggerMethod.dcs`. It drives SOS escalation.

The most reliable detector in the app is one of the constants.
`motion_fall_v2` scores **AUC 0.999** on held-out-subject data — and the
fusion ignores it entirely.

## Why, and how long

This is not a regression from the Day 323/325 model work. The DCS engine was
designed in the Day 27–32 era around *instantaneous* feature vectors: a
6-float `MotionFeatures`, an 8-float scene vector. Both real models are
windowed or image-shaped and always have been:

* `motion_anomaly_v1` was `[1,100,6]` = **600** floats — also ≠ 6
* `scene_analyzer_v1` is `[1,224,224,3]` = **150,528** — also ≠ 8

So the motion and scene slots have been stubbed since the day real models
first landed in those slots. The fusion has never fused.

`month2_runner.dart` even documents the adjacent fragility — "indices 0-3 in
this exact order — DCSInferenceEngine addresses them" — because the engine
reads `kZapsafeModels[0..3]` positionally. Day 325 added `vocal_stress` at
index 4, which happened to be safe. Inserting anywhere below 4 would have
silently rewired every slot.

## Why this was invisible

Nothing failed. `tryLoad` returning null is the designed fallback so "the
rest of the app can compose against this safely", the stubs return
well-formed `InferenceResult`s in the right range, and the engine even
exposes `motionIsReal` / `sceneIsReal` flags for a UI chip. All 783 Dart
tests pass, because `flutter test` has no native TFLite interpreter and
cannot execute a model at all.

It is the same failure shape as every other ML incident in this project:
right types, plausible values, wrong answer, no error.

## What this change does

Adds a **DCS slot wiring check** to `tools/verify_shipped_models.py`. The
gate already loads every shipped model, so it is the only place that can
compare declared against actual input sizes. It now prints, every run:

```
DCS fusion slots (declared input size vs the shipped model):
  motion   motion_fall_v2.tflite      declares 6   model wants 300   STUBBED
  scene    scene_analyzer_v1.tflite   declares 8   model wants n/a   load fails
  fusion   dcs_fusion_v1.tflite       declares 3   model wants n/a   placeholder
  -> motion, scene silently fall(s) back to a CONSTANT-valued stub.
```

Deliberately **reported, not failed**: the run still exits 0. Turning this
into a hard failure is the right end state, but it should happen in the
change that fixes the wiring, not in the one that discovers it.

## What this change does NOT do

**No fix to the fusion wiring, and that is on purpose.** The correct fix is
architectural, not a declaration tweak: the DCS engine currently runs its own
motion inference from a 6-float vector, while `MotionAudioPipeline` already
runs the real windowed model on the same sensor stream. The engine should
*consume* `MotionDetectorV2`'s result rather than re-infer from a shape the
model has never accepted. Same for scene and `SceneDetectorV2`.

That touches SOS escalation logic. Changing how a safety app decides to
escalate deserves its own change, its own review, and a device test — not a
late addition to a session that has already rewritten five models.

**The weights are also unjustified, separately from the wiring.** `[0.5,
0.3, 0.2]` was guessed before any model had a measured number. Measured now:

| modality | held-out AUC | current weight | weight ∝ (AUC − 0.5) |
|---|---|---|---|
| motion | 0.999 | 0.3 | **0.54** |
| scream | 0.839 | 0.5 | 0.36 |
| scene (shipped frame-level) | 0.594 | 0.2 | 0.10 |

The ordering is inverted: the most reliable signal carries the least weight.
AUC-proportional weighting is a heuristic, not a trained fusion, so this is
recorded as evidence for the wiring fix rather than applied here — and
reweighting changes escalation thresholds, which is a product decision.

## The placeholder itself is correctly deferred

`ZAPSAFE_ML_TRAINING_STRATEGY.md` schedules M9 as "Kaggle (XGBoost —
trivial), < 1 hr, Month 7–8 (when beta data exists)". That is right. A
fusion model learns `P(danger | scream, motion, scene, context)`, which needs
labelled real events where the component scores *and* the ground-truth
outcome are both known. No public dataset pairs a real scream with a real
fall from the same incident. Training on synthetic combinations would teach
the model an invented correlation structure.

So the honest sequence is: **fix the wiring first** so the interim weighted
fusion actually sees its three inputs, collect real beta incidents, then
train M9 on them. Fixing the wiring is not blocked on beta data and is worth
far more than the placeholder.
