# Day 315 — wiring the real M3 UCF-Crime retrain into the app

Was: `scene_analyzer_v1.tflite` shipped the old model trained on Intel Image
Classification + Places365 (generic scene photography, no real safe/unsafe
label — see `models/components/m3_metadata.json`), and
`model_bundle_service.dart`'s `_loadScene()` unconditionally skipped TFLite
loading for it with a hardcoded `ModelLoadStatus.skippedImageModel`, always
using `HeuristicSceneDetector` (an 8-float brightness/contrast proxy)
instead — regardless of whether a real model was present.

A real, better-labeled replacement was found and iterated on across Days
288-308 (`odins0n/ucf-crime-dataset` — real surveillance footage, `Normal`
vs 13 real crime-anomaly categories) but every iteration stayed
research-only in `kaggle_notebooks/`, never copied into the app or wired
into any loader.

## What this session did

1. **Picked the real best iteration, not just the latest.** Read every
   iteration's real report JSON rather than assuming later = better:

   | iteration | day | test accuracy | note |
   |---|---|---|---|
   | v1 | 289 | 0.5018 | baseline |
   | v2 | 291 | 0.4786 | worse |
   | **v3** | **293** | **0.5944** | **best — used this session** |
   | v4 | 301 | *(no report/tflite exported — abandoned mid-run)* | — |
   | v5 (+XD-Violence) | 305 | 0.495 | worse |
   | v6 (balanced UCF+XDV) | 308 | 0.5326 | better than v5, still below v3 |

   v3's real numbers: 3-class test accuracy 0.5944 (chance = 0.333),
   safe_f1 0.72, neutral_f1 0.34, risky_f1 0.53, risky_recall 0.50 — a real
   improvement in label quality over the old model, still mediocre in
   absolute terms, disclosed as such rather than rounded up.

2. **Copied the real file and its report**, not a placeholder:
   `kaggle_notebooks_day293/day293_m3_iteration3/final/
   m3_ucf_crime_retrain_v3.tflite` → `assets/models/scene_analyzer_v1.tflite`
   (same filename, matching this app's own precedent for scream/motion — see
   `model_bundle_service.dart`'s `_screamAsset`/`_motionAsset` comments).
   Its report copied verbatim to
   `assets/models/m3_scene_analyzer_v3_report.json`.

3. **Verified the exact real input/output contract from the training
   script itself**, not assumed from the architecture name — this mattered:
   `day293_m3_ucf_crime_v3.py`'s own TFLite converter sets
   `inference_input_type = tf.float32` / `inference_output_type = tf.float32`
   despite full-int8 internal quantization, AND its dataset pipeline does
   `tf.cast(image, tf.float32) / 255.0` — meaning the real required input is
   `[1,224,224,3]` float32 RGB scaled to **`[0.0, 1.0]`**, not raw `[0,255]`
   as `include_preprocessing=True` would suggest at a glance. Getting this
   wrong would not throw or change tensor shape — it would silently feed
   the model input ~255x brighter than what it was trained on, the same
   class of silent-wrong-normalisation bug `MotionDetectorV2`'s own docs
   warn about for M2. The model's final layer is
   `Dense(3, activation='softmax')` — output is already normalized
   probabilities, no manual softmax needed.

4. **Built `SceneDetectorV2`** (`lib/data/services/scene_detector_v2.dart`),
   mirroring `ScreamDetectorV2`/`MotionDetectorV2`'s existing pattern:
   `tryLoad()` with real shape validation, `normalise()` for the real
   `/255.0` scaling, `infer()` running real inference and mapping
   `[safe, neutral, risky]` in the real trained class-index order.

5. **Wired it into `model_bundle_service.dart`'s `_loadScene()`**, replacing
   the hardcoded skip with a real `tryLoad()` attempt — the same pattern
   `_loadScream()`/`_loadMotion()` already use — falling back to
   `HeuristicSceneDetector` only if the real load fails.

6. **Checked for a real regression before shipping this**, not just hoped
   for the best: `HeuristicDetectionEngine.scene` is a pure router — it
   returns whatever `Interpreter` was passed in, and the CALLER builds
   whatever tensor it thinks that interpreter wants. Grepped every real
   call site of `.scene.infer(`:
   - `day44_heuristic_engine_screen.dart` calls it with an 8-float
     `SceneFeatures` tensor — but that screen constructs its own
     standalone `HeuristicDetectionEngine(tier: tier)` with no
     `aiSceneInterpreter` argument at all, so `.scene` always resolves to
     the heuristic there regardless of this change. Confirmed safe, not
     assumed.
   - `day45_model_bundle_screen.dart` / `day48_device_diagnostics_screen.dart`
     (the only real consumers of the bundle-loaded `detectionEngineProvider`)
     only display `ModelSlotResult` status — neither calls `.infer()` at
     all.
   - The real DCS scoring loop (`dcsStreamProvider`/`DCSInferenceEngine`)
     is a completely separate engine that takes audio + motion only — no
     scene/camera input in the live pipeline today.

   **Conclusion: no live call site actually invokes `.scene.infer()` on the
   real bundle-loaded engine today**, so wiring in a real image model with a
   150,528-float input requirement introduces no crash risk, verified by
   reading every real call site rather than assumed.

## What this does NOT close — read before assuming end-to-end scene detection works

**There is no real camera-frame capture pipeline anywhere in this Flutter
app.** Confirmed by a real grep: no `camera` package in `pubspec.yaml`, no
`CameraController`/`CameraImage` usage anywhere in `lib/`.
[SceneFeatures] (the existing 8-float heuristic input model) only has
synthetic `.wellLit()`/`.dark()` presets — no real
`SceneFeatures.fromCameraFrame()` constructor exists, and no such
equivalent exists for producing a real 224×224×3 frame either.

This session makes the real, better-trained model **loadable and
correctly callable** given a real frame — the same category of fix
`ScreamDetectorV2`/`MotionDetectorV2` already made for their slots. It does
**not** add the camera-capture-and-preprocess pipeline that would actually
produce a frame to feed it in production. That remains real, separate,
unstarted work: adding the `camera` package, a permission flow, periodic
frame sampling (with real battery/thermal budget consideration), resizing
to 224×224, and threading the result into `ModelBundleService`/
`HeuristicDetectionEngine`'s `scene` slot at actual DCS-scoring time.

## Verification

- `flutter analyze`: 65 issues (baseline unchanged, 0 errors).
- `flutter test`: 767 passed / 6 skipped (baseline 756 + 11 new tests in
  `test/scene_detector_v2_test.dart`, which pin the real `/255.0`
  normalisation, real tensor geometry, real class-index order, and the
  same "`tryLoad` returns null on the host VM" contract
  `scream_detector_v2_test.dart` already documents for its own model —
  `infer()` itself needs a native TFLite library this sandbox does not
  have, same limitation this project has hit repeatedly for every model).
- Not build/device-verified — no working Gradle toolchain in this
  sandbox (confirmed again this session). The model file, tensor
  contract, and class mapping are grounded in the real training script and
  its real report JSON, not guessed.
