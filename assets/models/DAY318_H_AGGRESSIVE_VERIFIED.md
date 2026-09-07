# Day 318 — h_aggressive_speech: the model is fine, the wiring never happened

Day 317 fixed a genuinely dead gunshot export and predicted `h_aggressive_speech`
would need the same rebuild-and-re-export treatment, because its Day 100 sweep
int8 variants all collapsed to constants. That prediction was **wrong**, and
checking it properly is what this note records.

## What was actually measured

Real RAVDESS actor speech, day90 label scheme (aggressive = angry/fearful/
disgusted, calm = neutral/calm/happy), 80 vs 80 clips, day90 extractor with
training-time augmentation removed:

| export | features | AUC | rec@0.5 | best F1 |
|---|---|---|---|---|
| **shipped int8** | normalised | **0.8442** | 0.850 | rec .850 / prec .756 / f1 .800 |
| f32 twin | normalised | 0.8456 | 0.850 | rec .887 / prec .724 / f1 .798 |
| shipped int8 | **raw** | 0.5214 | 0.925 | — chance |
| f32 twin | **raw** | — | — | **constant 1.0, dead** |

Three things follow.

1. **The shipped asset is good** — AUC 0.844, slightly *better* than its own
   training report claimed (0.8021). `h_aggressive_speech_v1.tflite` md5-matches
   `kaggle_notebooks/h_aggressive_speech_push/output_v1/h_aggressive_speech.tflite`,
   so its provenance is confirmed, not assumed.
2. **int8 did not hurt this model** (0.8442 vs 0.8456 f32). Unlike the gunshot
   graph, quantization here is essentially free — so there is nothing to
   re-export and Day 317's predicted fix does not apply.
3. **Normalization is load-bearing.** With the real mean/std the model works;
   on raw features it drops to chance, and the f32 twin collapses to a constant
   1.0. That is a *silent wrong-answer* failure, not a crash — the same class of
   bug as Day 317's, reached from the opposite direction.

The earlier "all h int8 exports are dead" observation was about the **Day 100
sweep** variants, which are different models. Their own `*_norm.json` files
contain only metadata — no `mean`/`std` at all — so nothing could have fed them
correctly. That is a real defect in the sweep's export, separate from this asset.

## What changed here

- **Shipped `assets/models/h_aggressive_speech_v1_norm.json`** (real 38-dim
  mean/std, copied verbatim from the Day 90 training output). The model was
  shipped without it, which meant anyone wiring it up was guaranteed
  chance-level results. Naming follows the existing `s_crowd_panic_norm.json`
  convention: `<model stem>_norm.json`.
- **`tools/verify_shipped_models.py` now covers 38-dim prosodic models**, using
  real RAVDESS audio, and applies a model's own `*_norm.json` when one ships
  beside it. Without that the gate would have called this good model DEAD — the
  f32 twin really does emit a constant on raw input. `h_aggressive_speech_v1`
  now reports `ok  range[0.0039, 0.9883] (norm.json applied)`, and the
  UNVERIFIED count drops 8 → 7.
- **`model_registry.dart`** now records the verified numbers and the real
  blocker instead of a stale "Phase B (Day 100): inference wiring" note for
  work that never happened.

## Why Phase B (inference wiring) is still not done

Deliberately not attempted here rather than half-built. No Dart code loads or
runs this model today. Wiring it needs the day90 38-dim vector:

```
f0_mean, f0_std, jitter        <- librosa.pyin pitch tracking
shimmer, hnr                   <- frame RMS series
mfcc_mean[13], mfcc_std[13]    <- available per-frame natively
rms_mean, zcr                  <- zcr available natively
spectral_centroid              <- available natively
spectral_rolloff               <- not available
```

`lib/native/audio_features.dart` emits only 15 per-frame scalars (13 MFCC +
ZCR + spectral centroid). The pitch-derived features need a real **pyin**
implementation — probabilistic YIN, not a trivial autocorrelation — plus RMS
series and rolloff. Reimplementing pyin in Dart and getting it numerically
close enough to librosa is a substantial, high-risk job: get it subtly wrong
and you land exactly in the failure this document describes, a model that
loads, runs, returns confident-looking numbers, and is at chance.

That work should be its own task with its own parity fixtures against real
librosa output, in the style of `test/fixtures/np_resize_wrap_golden.json`.

## Related

Day 310 (`DAY310_H_AGGRESSIVE_ACCESS_AND_PREP.md`) identified this model's real
content gap — it has never seen a calm-but-menacing "cold anger" register, since
every positive it trained on is acted shouting. That is a data problem for a
future retrain and is unrelated to the wiring gap above; both are open.
