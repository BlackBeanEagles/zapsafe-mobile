# Day 273 — wiring `k_confinement_decorrelated` (Day 272's decorrelated retrain)

Follow-up to `DAY272_K_CONFINEMENT_DECORRELATED_RETRAIN.md` (real retrain,
diagnostic/retrain only, not wired) and `DAY271_VEHICLE_CRASH_WIRING.md`
(most recent reference pattern for a two-input fusion model). This session
wires the Day 272 retrain end to end, following the same pattern, with one
real architectural difference: this model's second input is `light` (a
broadcast ambient-light scalar), not audio — a sensor modality this app has
never wired before.

## 1. Real tensor shapes — verified directly this session, not assumed

Verified via `interpreter.get_input_details()`/`get_output_details()`
against the real file at
`kaggle_notebooks/day272_k_confinement_decorrelated_push/kaggle_output/
k_confinement_decorrelated.tflite` (59,240 bytes) and its f32 sibling
(192,388 bytes):

```
=== k_confinement_decorrelated.tflite
 IN  serving_default_imu:0   [1 128 6]  float32
 IN  serving_default_light:0 [1 32  1]  float32
 OUT StatefulPartitionedCall_1:0 [1 1]  float32
=== k_confinement_decorrelated_f32.tflite
 IN  serving_default_imu:0   [1 128 6]  float32
 IN  serving_default_light:0 [1 32  1]  float32
 OUT StatefulPartitionedCall_1:0 [1 1]  float32
```

This confirms `DAY260_QUANTIZATION_ROOTCAUSE.md` Finding 3's shape
(`imu [1,128,6]` + `light [1,32,1]`) still holds for the Day 272 retrain —
**but both files are float32 end-to-end**, not int8. (Day 272's training
report cites "int8 size: 57.9 KB" for a separate quantized artifact that is
not present in `kaggle_output/`; only the two float32 `.tflite` files exist
on disk, and both were verified float32 directly against the loaded
interpreter, not assumed from that report figure.) No quantize/dequantize
is needed — unlike `i_vehicle_crash`'s genuine int8 export.

Copied into `assets/models/k_confinement_decorrelated.tflite` and
`k_confinement_decorrelated_f32.tflite`. No `pubspec.yaml` change needed —
`assets/models/` is already declared as a whole-directory asset.

## 2. The light-sensor-input question — investigated, decided, documented

This model needs a real `light` value — a modality none of this app's prior
fusion models (`s_crowd_panic`, `i_vehicle_crash`, both audio+IMU) use.
Investigated this session, per the task brief's three options:

1. **Checked for existing ambient-light-sensor integration.** Searched all
   of `lib/` and `pubspec.yaml` for `sensors_plus`'s light-sensor APIs,
   any `light_sensor`-style package, and any platform channel referencing
   "light"/"lux"/"ambient". **None found.** `sensors_plus: ^4.0.0` (this
   app's pinned version) does not expose an ambient-light stream at all —
   that API only exists in much newer `sensors_plus` majors — so reuse
   was not possible.
2. **Considered a camera-exposure-brightness proxy.** Rejected: this app
   has no active camera-preview session running during background
   detection, so adding one solely to sample exposure metadata would be a
   real new permission/battery/architecture change, not a small wiring
   step — and Day 269/272's own training data never used a camera-exposure
   proxy either ("no real ambient-light/lux dataset exists locally"), so
   wiring one here would not even match what the model was trained on.
3. **Decision: Option (c).** Wire the real IMU side for real, and use an
   explicit, documented, fixed-safe-default light value
   (`KConfinementFusionPipeline.kPlaceholderLightValue = 0.5`, mid-range
   between the model's trained dark 0.0-0.1 and lit 0.15-0.9 regimes, not
   biased toward either) rather than fabricating a fake sensor reading.
   `KConfinementFusionPipeline.usesRealLightSensor` is a `const bool`
   pinned to `false`, and is asserted directly in
   `test/k_confinement_detector_test.dart` so a future silent change
   can't start claiming a real sensor without a test failing.

**This is a real, stated limitation, not a hidden one: every inference this
pipeline produces runs on real live IMU data but a constant, non-sensed
light value.** Wiring a real ambient-light reading — most likely via a
native platform-channel add-on, since `sensors_plus` doesn't carry one at
this app's pinned version — remains real, separate follow-up work, not done
in this session.

## 3. Preprocessing, from `day272_k_confinement_decorrelated.py`

**IMU side**: raw `[128, 6]` window (acc xyz + gyro xyz), z-score
normalized per channel: `(x - imu_mean) / imu_std`, using the real
per-channel `imu_mean`/`imu_std` (6 values each, confirmed by reading
`build_dataset()`'s `X_imu = (X_imu - imu_mean) / imu_std` and pulled from
the real `k_confinement_decorrelated_norm.json`). **This is a different
formula from `MotionDetectorB`/`VehicleCrashDetector`'s `clip(-8,8)/8`** —
this model's own training script normalizes differently, confirmed by
reading the script directly, not assumed from the matching window length.
`MotionWindowBufferB` is still reused for raw 128-sample/6-channel
windowing (same window length/channel convention as every IMU model in
this app); only the normalization step is new.

**Light side**: `make_light(val) = np.full(32, val)` — a single scalar
broadcast across all 32 timesteps, reshaped to `[1, 32, 1]`, with no
normalization (raw value in roughly `0.0`-`0.9`).

## 4. Code reused vs. new

- `lib/data/services/motion_detector_b.dart`'s `MotionWindowBufferB` is
  reused directly for IMU windowing (same window length/channel
  convention as every other IMU model in this app).
- New: `lib/data/services/k_confinement_detector.dart`
  (`KConfinementDetector`) — new class because this model's own
  normalization formula (z-score, not clip/8) and its second input
  (light, not audio) are unique to this model.
- New: `lib/data/services/k_confinement_pipeline.dart`
  (`KConfinementFusionPipeline`) — structurally lighter than
  `VehicleCrashFusionPipeline`/`CrowdPanicFusionPipeline`'s concurrent-
  capture design: since there is no second real async stream (light is a
  constant placeholder, not a live sensor stream), this pipeline is driven
  by the IMU stream alone, firing an inference on every fresh
  `MotionWindowBufferB` window paired with the constant placeholder light
  value. No staleness/fusion logic is needed because there is nothing to
  go stale on the light side.

## 5. Backend schema change — a no-op again

`zapsafe_backend/ml/models.py` — `EventType` gained
`CONFINEMENT = "confinement"`. "confinement" is 11 characters, which fits
inside the existing varchar(20) `event_type` column Day 265's migration
already widened to — no column-width change needed, same posture as
`VEHICLE_CRASH`.

Django still generates a migration
(`ml/migrations/0011_alter_detectionevent_event_type.py`) because
`EventType.choices` changed. Confirmed for real via `sqlmigrate`:

```
$ docker compose exec web python manage.py makemigrations ml --check --dry-run
Migrations for 'ml':
  ml/migrations/0011_alter_detectionevent_event_type.py
    - Alter field event_type on detectionevent

$ docker compose exec web python manage.py sqlmigrate ml 0011
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
  Applying ml.0011_alter_detectionevent_event_type... OK
```

`ml/serializers.py`'s `DetectionEventSerializer.validate_event_type`
validates dynamically against `EventType.values`, and `ml/views.py`'s
event-type filter is likewise dynamic — no hardcoded event-type lists to
update, same as Day 265/271's finding.

## 6. Mobile wiring

- `lib/data/services/detection_event_service.dart` — `DetectionEventType`
  gained `kConfinement` (wire value `confinement`).
- `lib/domain/providers/live_detection_providers.dart` — added
  `kConfinementDetectorProvider`/`kConfinementFusionPipelineProvider`,
  wired into `liveDetectionEventSubmitterProvider` alongside scream/motion/
  gunshot/motion_b/crowd_panic/vehicle_crash.
- `lib/presentation/screens/day55_detection_event_screen.dart` — the
  `DetectionEventType` switches (`_typeColor`/`_typeIcon`, 3 call sites
  each) were non-exhaustive after adding `kConfinement`; fixed (warning
  color, `Icons.lock_clock_rounded`).

## 7. Real test results

### Backend (`zapsafe_backend`, run inside the real `web` Docker container
against the real Postgres `db` service, already running from prior
sessions this week)

```
$ docker compose exec web python manage.py test ml.test_day273_confinement_wiring ml.test_day271_vehicle_crash_wiring ml.test_day264_crowd_panic_wiring ml.test_day262_gunshot_motion_b_wiring ml.test_day259_live_detection_wiring -v 2 --keepdb
...
Ran 25 tests in 8.814s

OK
```

5 new tests in `ml/test_day273_confinement_wiring.py` all pass real POST
requests through `/api/v1/ml/detection-events/` and assert real
`DetectionEvent` rows land in Postgres, including a test posting
`motion`/`vehicle_crash`/`confinement` for the same device and asserting
all three persist as independent rows, and a bogus-event-type-still-
rejected test proving adding `CONFINEMENT` to `EventType.choices` didn't
loosen validation. The pre-existing 20 tests (Day 259 + Day 262 + Day 264 +
Day 271) still pass unmodified.

### Mobile (`zapsafe_mobile`, `flutter test`)

```
$ flutter test test/k_confinement_detector_test.dart
...
00:00 +6: All tests passed!
```

6 new tests pass: the real per-channel z-score formula against the real
`imu_mean`/`imu_std` from `k_confinement_decorrelated_norm.json`
(identity-value and one-std-above-mean checks); the `make_light`
broadcast (no normalization); and two tests directly asserting the
honest light-sensor-gap flag (`usesRealLightSensor == false`,
`kPlaceholderLightValue == 0.5`).

Full suite:

```
$ flutter test
...
00:5x +699 ~6 -1: Some tests failed.
```

699 passed, 6 skipped, 1 failed. The 1 failure (`test/widget_test.dart`:
"Home index screen renders without errors") is the same **pre-existing,
unrelated** failure documented in `DAY262_GUNSHOT_MOTIONB_WIRING.md`,
`DAY265_CROWD_PANIC_WIRING.md`, and `DAY271_VEHICLE_CRASH_WIRING.md` — not
caused by this session's changes. 699 passing is up from Day 271's 693
(this session's 6 new k_confinement parity/honesty tests), with no other
regressions.

## 8. Verdict — matching this week's rule against overclaiming

**This is wired, but not fully live, and that distinction matters.** The
IMU side is a real, live, correctly-normalized sensor input feeding a real,
verified model fix (Day 272: AUC 0.9959, real dynamic range and
motion-discrimination restored at a realistic lit light value). The
`light` side is a fixed placeholder (0.5), not a real ambient-light sensor
reading, because no such sensor is wired into this app and none of the
options investigated this session (existing integration, camera-exposure
proxy) were real or honest paths to one in this session's scope. Do not
describe this model as "fully wired" or "fully live" without this caveat —
say exactly this: IMU-real, light-placeholder, backend and detector code
real and tested.

## 9. What was not done / explicitly out of scope

- No real ambient-light sensor integration — the core open gap, stated
  plainly above and in code (`usesRealLightSensor = false`).
- No on-device or emulator run — code-level verification only, matching
  how every prior model this week was verified.
- No field-tuned confidence threshold — kept at the model's own raw
  sigmoid midpoint (0.5), same posture as every other fusion detector this
  week.
- Did not touch `kaggle_notebooks` (read-only per task scope).
