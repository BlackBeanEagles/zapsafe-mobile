# Day 336 — the 38-feature model trained and shipped, two dead models deleted

## 1. `m4_vocal_stress_en_38` — the model the Day 332b/333 Dart work was for

Every one of the 38 day95 features can now be computed on-device, so the
model was retrained on **plain YIN** pitch (what `YinPitch` produces) rather
than `librosa.pyin`.

```
held-out speakers ['0012','0016','0019']  train 2380 | test 1020
seeds 0.8294 / 0.8321 / 0.8394  -> median 0.8321 taken
separation +0.3813   span 0.9985     (Day 330 floors: 0.05 / 0.05)
t=0.5  recall 0.867  precision 0.677
t=0.8  recall 0.690  precision 0.793
```

**0.8321 against 0.6949** for the 28 features the app computed before — a
**+0.137** step on the same split. The median of three seeds is taken rather
than the best, because a single seed moves ~0.01 run to run on 1,020 rows and
picking the best is cherry-picking.

`VocalStressFeatures.compose38()` assembles the vector from the three
sources. The order is the contract and is spelled out index by index, because
this is the one place where every component can be individually correct and
the result still wrong:

| index | feature | source |
|---|---|---|
| `0..4` | voiced_frac, f0_mean, f0_std, f0_range, jitter | `YinPitch.pitchFeatures()` |
| `5`, `6` | shimmer, hnr | `extendedFeatures()[0..1]` |
| `7..32` | mfcc_mean[0..12], mfcc_std[0..12] | `extract()[0..25]` |
| `33..35` | rms_mean, rms_std, rms_max | `extendedFeatures()[2..4]` |
| `36`, `37` | zcr, centroid/nyquist | `extract()[26..27]` |

`day336_compose38_test.dart` checks each slot against the source that
produced it, cross-checks against the librosa goldens, and asserts the
training report's own `feature_order` agrees — a permutation would otherwise
pass every component parity test while feeding the model garbage.

### A fixture collision worth recording

Two shipped models are now `[1,38]` — `h_aggressive_speech_v1` and this one —
with **different feature definitions**. The gate routed the new model to the
existing `real_prosodic_38` fixture, which computes pitch with
`librosa.pyin`, and reported it **DEAD at a constant 1.0**. That was a domain
mismatch wearing a dead model's clothes.

`fixture_for` now takes the filename and routes `[1,38]` by name, with
`real_prosodic_38_yin` reading the same yin_lite features the model trained
on, restricted to its three held-out speakers. A second, quieter version of
the same problem: the norm file was named `..._float16_norm.json` against a
model called `..._float16.tflite`, so the gate's `stem + "_norm.json"` lookup
missed it and the unnormalised input drove the output to a constant 0.0 — the
exact failure its own comment warns about. The asset is renamed to
`m4_vocal_stress_en_38.tflite`, matching the `m5_vocal_stress_v2` convention.

In the gate now: **AUC 0.824, sep 0.3693, range [0.001, 0.999]**.

### Not done

**The shipped detector still loads `m5_vocal_stress_v2` (Mandarin, 28
features).** Swapping it changes which language the app's vocal-stress
detector targets — the +0.137 measured here is English, and Mandarin sits at
0.52–0.59 on this split. That is a product decision, so the model, its norm
and `compose38()` are shipped and tested while `VocalStressDetector` is
untouched.

## 2. `s_crowd_panic` and `m2_motion_b_retrain` deleted

Both were measured non-functional and neither can be retrained into
usefulness, so they are gone rather than disabled.

`s_crowd_panic` was a strictly worse duplicate of a detector already running
on every audio window. On the two AudioSet classes it targets that
`scream_classifier_v3` never trained on (Shout, Crowd), scream v3 scores
**0.8230** against `s_crowd_panic`'s **0.6062** on realistic phone input.
Nothing is lost by deleting it.

`m2_motion_b_retrain` returned **exactly 0.00000000** for every input across
15 probes spanning six orders of magnitude, and is superseded by
`motion_fall_v2` at 0.999. It was also still **live** — unlike the dual-input
models behind `kDualInputModelsDisabled` — so it ran inference on every
window to produce a constant.

Removed: 4 assets, 4 Dart classes, their providers and submitter blocks, one
test. `MotionWindowBufferB` was extracted to its own file first — ordinary
windowing logic with no dependency on the dead model, still used by the
confinement and crash pipelines.

`DetectionEventType.crowdPanic` and `.motionB` are **kept deliberately**:
they are backend wire values, and `day55_detection_event_screen` needs them
to render events a user may already have.

## 3. Two gate corrections on the Day 334 assets

`mobilenetv3small_encoder` reported **DEAD**. It is a feature extractor — its
output is a 576-dim embedding, so an AUC or span check says nothing about
whether it works, and calling it dead was wrong rather than unhelpful. It now
reports `ENCODER`, verified by parity against its Keras source and by the
end-to-end chain it feeds.

`m3_violence_temporal` reported **UNVERIFIED** because the generic `[1,T,C]`
IMU branch caught `[1,16,576]` first and returned None — UniMiB has 3
channels, not 576. With the embedding-sequence branch ordered ahead of it and
a fixture reading the training-time cached val features, it measures **AUC
0.908, sep 0.5057**, against 0.9176 end-to-end on raw video.

## Standing state

| detector | status |
|---|---|
| `motion_fall_v2` | 0.999 · shipped, wired |
| `m3_violence_temporal` | 0.908 gate / 0.9176 end-to-end · shipped, wired to DCS |
| `scream_classifier_v3` | 0.839 · shipped, wired |
| `m5_vocal_stress_v2` | 0.850 · shipped, wired (Mandarin, 28-feat) |
| `m4_vocal_stress_en_38` | 0.824 gate / 0.8321 trained · **shipped, not wired** |
| `mg_gunshot_retrain` | 0.89 · shipped |
| `h_aggressive_speech_v1` | alive · shipped |
| `i_vehicle_crash` | collapsed at source, no crash data exists |
| `k_confinement_decorrelated` | blocked on data collection |
| `dcs_fusion_v1` | placeholder, deferred to beta incidents |

The gate fails on exactly the two that are genuinely broken and unfixable
without data that does not exist. 830 tests pass, analyze unchanged at 57
issues, and **nothing has yet run on a physical device.**
