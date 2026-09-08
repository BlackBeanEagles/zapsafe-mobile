# reference_models/ — kept in the repo, deliberately NOT shipped

`pubspec.yaml` bundles `assets/models/` wholesale, so **anything** in that
folder ships to every user whether or not a single line of Dart loads it.
These three files were loading nothing:

| file | size | why it is here and not in assets/models/ |
|---|---|---|
| `m1_gender_balanced.tflite` | 2.6 MB | Zero references in `lib/` or `test/`. Also **WEAK** on real data: AUC 0.494 — chance — with output range `[0.000, 0.012]`, so it never fires on anything. See `assets/models/DAY319_SCREAM_REALITY_CHECK.md`. |
| `i_vehicle_crash_f32.tflite` | 192 KB | float32 twin of the shipped int8 model; nothing loads it. |
| `k_confinement_decorrelated_f32.tflite` | 187 KB | float32 twin of the shipped int8 model; nothing loads it. |

That is **3.0 MB removed from the app bundle** (13 MB → 9.3 MB of models,
a 23% cut) with no code change, because nothing referenced them.

## Why moved and not deleted

The float32 twins are worth keeping. Day 317 fixed a shipped gunshot detector
that emitted a constant 0.3633 on real audio, and the thing that made the fix
possible was having `mg_gunshot_retrain_f32.tflite` to compare against — it
scored AUC 0.889 where the int8 export scored 0.499. An f32 twin is the
reference that tells you whether a broken int8 export is a bad model or a bad
quantization. Deleting these would throw away exactly that diagnostic.

`m1_gender_balanced.tflite` is kept for the same reason in reverse: it is
evidence for the Day 319 finding, and re-measuring it later should not
require re-downloading anything.

## If you need one of these in the app

Move it back into `assets/models/` and wire it in `lib/`. Then run
`python tools/verify_shipped_models.py` before shipping — it uses real
recorded data and fails on both dead (constant output) and WEAK
(AUC < 0.70) models. Do not re-add a model to the bundle without it passing.

## Verifying nothing referenced these

```
grep -rn "m1_gender_balanced" lib/ test/          # no matches
grep -rn "_f32" lib/ --include=*.dart             # only doc comments
```

The one `f32` hit in `day229_feature_regression_runner_screen.dart` is a
feature-row id (`id: 'f32'`, "Check-in timers"), not a model path.
