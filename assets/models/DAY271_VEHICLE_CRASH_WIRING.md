# Day 271 — wiring `i_vehicle_crash` (ZapSafe's second two-input audio+IMU fusion model)

Follow-up to `DAY267_REMAINING_MODELS_TRIAGE.md`'s "1. `i_vehicle_crash` /
`i_vehicle_crash_f32` — reconciled, not dead" finding: this model had been
mistested by a harness that only fed the `audio_mel` input, leaving
`imu_window` as allocator garbage — the same bug class already found and
fixed for `k_confinement` and `s_crowd_panic`. With both real inputs
supplied (real ESC-50 crash-proxy audio + real UCI-HAR IMU run through the
model's own `inject_crash_spike()`), real AUC is 0.9622 (fp32) / 0.8733
(int8) — a genuinely strong result. This session wires it, following
`DAY265_CROWD_PANIC_WIRING.md`'s pattern (the first two-input fusion model)
and `DAY262_GUNSHOT_MOTIONB_WIRING.md`'s int8-quantization handling.

## 1. Real model file located and verified

Per `DAY267_REMAINING_MODELS_TRIAGE.md`'s "Where files were moved" section,
`i_vehicle_crash*` was left untouched in the canonical staging directory:
`kaggle_notebooks/day108_int4_m9_push/day108_kaggle_output/saved/int4_m9/
day108-int4-m9-kaggle-20260703-v5-production/tflite_staging/`. There are
dozens of stale duplicate copies scattered across `day108_int4_m9_push/`'s
various `_pull_*`/`_bench_work`/`prior_snapshot`/`tflite_staging_wrong`
working directories (confirmed by a filesystem-wide search) — this is the
one the Day 260+ triage scripts (`test_i_vehicle_crash.py`'s `STAGE`
constant, a sibling `_v10_pull` copy of the same bytes) treat as canonical.

Tensor shapes confirmed directly against the real file this session
(`interpreter.get_input_details()`/`get_output_details()`), **not** trusted
from the docs:

```
=== i_vehicle_crash.tflite (66,208 bytes)
 IN  serving_default_audio_mel:0 [1 64 64 3] int8  (scale=0.003921568859368563, zero=-128)
 IN  serving_default_imu_window:0 [1 128 6]  int8  (scale=0.003922347445040941, zero=47)
 OUT StatefulPartitionedCall_1:0  [1 1]      int8  (scale=0.00390625, zero=-128)
=== i_vehicle_crash_f32.tflite (196,724 bytes)
 IN  serving_default_audio_mel:0 [1 64 64 3] float32
 IN  serving_default_imu_window:0 [1 128 6]  float32
 OUT StatefulPartitionedCall_1:0  [1 1]      float32
```

**Unlike `s_crowd_panic` (float32, no quantization), this model's int8
export is a genuine int8-quantized model** — the same tensor-dtype
situation as `mg_gunshot_retrain`, not `MotionDetectorB`'s "int8 by file
size but float32 tensors" trap. Both inputs and the output require real
quantize/dequantize.

Copied into `assets/models/i_vehicle_crash.tflite` and
`i_vehicle_crash_f32.tflite`; md5 verified identical to the canonical
staged files (`840a3ced3ae068e25a4cb8e40751eb31` /
`67be55d2d72dd4a6e631f3fdd6ba33f3`). No `pubspec.yaml` change needed —
`assets/models/` is already declared as a whole-directory asset.

## 2. Preprocessing, from `day91_i_vehicle_crash.py`

**Audio side** (`audio_to_melspec`): `SR=16000`, `DURATION=2.0s` (32,000
samples), default librosa `n_fft=2048`/`hop_length=512`, `n_mels=64`,
`fmax=8000`, `librosa.power_to_db(mel, ref=np.max)`, **then a per-clip
min-max rescale to `[0,1]`** — unlike `s_crowd_panic`'s global mean/std,
this model uses the *same* per-clip min-max normalization as
`mg_gunshot`/`m1_scream_v2` (`MelSpectrogram.compute()`'s default,
`normalize: true`). A real 2.0s/16kHz clip yields **63 mel frames**
(`1 + 32000 // 512`), confirmed directly via a real librosa 0.11.0 run
this session. Then **`np.resize(mel_norm, (64, 64))`** — the same
wrap/tile (not image-resize) trap `GunshotDetectorV2` already solved for
`mg_gunshot`'s much larger `[128,94]->[128,128]` case. Because 63 is only
1 short of 64, this model's wrap repeats just the first mel column once at
the very end of the flattened image — confirmed against real
`numpy.resize` output (`test/fixtures/np_resize_vehicle_crash_golden.json`,
`np_resize_small_vehicle_crash_golden.json`). The normalized image is then
stacked into 3 identical channels (`np.stack([img, img, img], axis=-1)`),
same as `mg_gunshot`.

**IMU side**: raw `[128, 6]` window (acc xyz + gyro xyz).
`day91_i_vehicle_crash.py`'s `normalize_imu(w) = clip(w, -8, 8) / 8`
(`G_RANGE = 8.0`) is **bit-for-bit the same formula** as
`MotionDetectorB.normalise` — confirmed by reading both scripts. Because
the formula and window length (128 samples, 6 channels, same accel-xyz +
gyro-xyz channel order convention) are identical, `VehicleCrashDetector`
reuses `MotionWindowBufferB` for IMU windowing rather than a third
windowing implementation — verified, not assumed.

## 3. Code reused vs. new

- `lib/data/services/gunshot_detector.dart`'s `GunshotDetectorV2.wrapResizeSquare`
  is reused directly (the `@visibleForTesting` annotation was removed —
  this is now a real production dependency of a second detector, not a
  test-only helper). One shared implementation, not a third copy-paste of
  the exact same `np.resize` operation.
- `lib/data/services/motion_detector_b.dart`'s `MotionWindowBufferB` is
  reused directly for IMU windowing (verified identical formula/window
  length to `day91_i_vehicle_crash.py`'s IMU preprocessing, not assumed
  from matching window length alone).
- `lib/data/services/mel_spectrogram.dart`'s `MelSpectrogram.compute()`
  default path (`normalize: true`) matches this model's per-clip min-max
  exactly — no new mel normalization mode needed (unlike `s_crowd_panic`,
  which needed the `normalize: false` global-mean/std path added).
- New: `lib/data/services/vehicle_crash_detector.dart` (`VehicleCrashDetector`)
  — new class because the tensor names, int8 quantization, and preprocessing
  combination (per-clip min-max mel + np.resize + clip/8 IMU) are unique to
  this model.
- New: `lib/data/services/vehicle_crash_pipeline.dart`
  (`VehicleCrashFusionPipeline`) — structurally identical to
  `CrowdPanicFusionPipeline`'s concurrent-capture design (see below), copied
  and adapted rather than shared, since the two pipelines' detector types
  differ.

## 4. Concurrent-capture design — reused `CrowdPanicFusionPipeline`'s pattern unchanged

Same decision as `DAY265_CROWD_PANIC_WIRING.md`: cache the most recent
window from each side (native audio-PCM stream + accelerometer/gyroscope
stream via `MotionWindowBufferB`); fire a fused inference whenever either
side produces a fresh window, provided the other side's cached window is
within `maxStalenessMs` (default 2500ms, same default as crowd_panic — 2.0s
training window + ~1s audio hop) of now. If the other side has never fired,
or its last window is stale, **no inference runs** —
`windowsSkippedStale` counts this. No design changes were needed from the
crowd_panic template; the two-input fusion problem (independent async audio
+ IMU streams with no built-in synchrony point) is identical.

## 5. Backend schema change — genuinely a no-op this time

`zapsafe_backend/ml/models.py` — `EventType` gained
`VEHICLE_CRASH = "vehicle_crash"`. Unlike Day 265's `CROWD_PANIC`
(`"crowd_panic"`, 11 chars, needed the column widened from varchar(10) to
varchar(20)), `"vehicle_crash"` is **13 characters, which fits inside the
existing varchar(20) column** Day 265's migration already established — no
column-width change needed.

Django still generates a migration
(`ml/migrations/0010_alter_detectionevent_event_type.py`) because
`EventType.choices` changed (a new choice was added), even though no
column-level DDL is required. Confirmed for real via `sqlmigrate`:

```
$ docker compose exec web python manage.py makemigrations ml --check --dry-run
Migrations for 'ml':
  ml/migrations/0010_alter_detectionevent_event_type.py
    - Alter field event_type on detectionevent

$ docker compose exec web python manage.py sqlmigrate ml 0010
BEGIN;
--
-- Alter field event_type on detectionevent
--
-- (no-op)
COMMIT;
```

Applied for real against the already-running Postgres `db` service:

```
$ docker compose exec web python manage.py migrate ml
Operations to perform:
  Apply all migrations: ml
Running migrations:
  Applying ml.0010_alter_detectionevent_event_type... OK
```

`ml/serializers.py`'s `DetectionEventSerializer.validate_event_type`
validates dynamically against `EventType.values`, and `ml/views.py`'s
event-type filter is likewise dynamic — no hardcoded event-type lists to
update, same as Day 265's finding.

## 6. Mobile wiring

- `lib/data/services/detection_event_service.dart` — `DetectionEventType`
  gained `vehicleCrash` (wire value `vehicle_crash`).
- `lib/domain/providers/live_detection_providers.dart` — added
  `vehicleCrashDetectorProvider`/`vehicleCrashFusionPipelineProvider`, wired
  into `liveDetectionEventSubmitterProvider` alongside scream/motion/
  gunshot/motion_b/crowd_panic.
- `lib/presentation/screens/day55_detection_event_screen.dart` — the
  `DetectionEventType` switches (`_typeColor`/`_typeIcon`, 3 call sites
  each) were non-exhaustive after adding `vehicleCrash`; the Dart compiler
  caught this at `flutter analyze`/`flutter test` compile time and it was
  fixed (danger color, `Icons.car_crash_rounded`).

## 7. Real test results

### Backend (`zapsafe_backend`, run inside the real `web` Docker container
against the real Postgres `db` service, already running from prior
sessions this week)

```
$ docker compose exec web python manage.py test ml.test_day271_vehicle_crash_wiring ml.test_day264_crowd_panic_wiring ml.test_day262_gunshot_motion_b_wiring ml.test_day259_live_detection_wiring -v 2 --keepdb
...
Ran 20 tests in 5.950s

OK
```

5 new tests in `ml/test_day271_vehicle_crash_wiring.py` all pass real POST
requests through `/api/v1/ml/detection-events/` and assert real
`DetectionEvent` rows land in Postgres, including a test posting
`motion`/`crowd_panic`/`vehicle_crash` for the same device and asserting
all three persist as independent rows, and a bogus-event-type-still-
rejected test proving adding `VEHICLE_CRASH` to `EventType.choices` didn't
loosen validation. The pre-existing 15 tests (Day 259 + Day 262 + Day 265)
still pass unmodified.

### Mobile (`zapsafe_mobile`, `flutter test`)

```
$ flutter test test/vehicle_crash_detector_test.dart
...
00:00 +11: All tests passed!
```

All 11 parity tests pass: real librosa `power_to_db(ref=max)` values match
elementwise (`test/fixtures/mel_golden_vehicle_crash.json`, generated by
librosa 0.11.0 locally this session) for the raw (`normalize: false`) mel
path at this model's own params (n_mels=64, fmax=8000); the real
`np.resize` wrap behavior for both a generic `[64,60]->[64,64]` case and
the model's real `[64,63]->[64,64]` one-column-wrap case (verified against
real `numpy.resize` output, `test/fixtures/np_resize_vehicle_crash_golden.json`
+ `np_resize_small_vehicle_crash_golden.json`); int8 quantization range
checks against the real model's own scale/zero_point (read from the loaded
interpreter this session, not hardcoded); and the IMU `clip(-8,8)/8`
arithmetic matches `MotionDetectorB.normalise`'s formula exactly.

Full suite:

```
$ flutter test
...
00:23 +693 ~6 -1: Some tests failed.
```

693 passed, 6 skipped, 1 failed. The 1 failure (`test/widget_test.dart`:
"Home index screen renders without errors") is the same **pre-existing,
unrelated** failure documented in `DAY262_GUNSHOT_MOTIONB_WIRING.md` and
`DAY265_CROWD_PANIC_WIRING.md` — not caused by this session's changes.
693 passing is up from Day 265's 682 (this session's 11 new vehicle-crash
parity tests), with no other regressions.

## 8. What was not done / explicitly out of scope

- No on-device or emulator run — code-level verification only, matching
  how every prior model this week was verified.
- No field-tuned confidence threshold for `VehicleCrashDetector` — kept at
  the model's own raw sigmoid midpoint (0.5), same posture as
  `CrowdPanicDetector.kDefaultThreshold`. The real evidence (AUC 0.8733
  int8 on real matched ESC-50 crash-proxy audio + real UCI-HAR
  crash-injected IMU, per `DAY267_REMAINING_MODELS_TRIAGE.md`) supports
  this being a usable detector, but no field-tuned operating point exists
  yet.
- `maxStalenessMs=2500` in `VehicleCrashFusionPipeline` is the same
  reasoned default `CrowdPanicFusionPipeline` uses, not independently
  tuned for vehicle-crash-specific latency characteristics (a real crash's
  audio and IMU signatures are likely tighter-coupled in time than a crowd
  panic's, but there is no field telemetry yet to justify a different
  value).
- Did not touch `k_confinement` or any of its retrain-data work — another
  agent was working on that in parallel this session; only
  `MotionWindowBufferB` (shared, pre-existing, `motion_detector_b.dart`)
  was read and reused, not modified.
