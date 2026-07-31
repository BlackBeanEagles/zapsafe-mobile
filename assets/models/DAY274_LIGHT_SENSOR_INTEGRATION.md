# Day 274 — closing the `k_confinement` light-sensor gap: Android real, iOS still placeholder

Follow-up to `DAY273_K_CONFINEMENT_WIRING.md` section 2, which shipped
`KConfinementFusionPipeline` IMU-real / light-placeholder
(`kPlaceholderLightValue = 0.5`) because no ambient-light-sensor
integration existed anywhere in this app, and `sensors_plus: ^4.0.0` (this
app's pinned version) doesn't expose one. This session investigates real
options to close that gap and implements the one that's real and clean.

## 1. Android — real option found and implemented

`Sensor.TYPE_LIGHT` has been in the platform `SensorManager` API since API
level 1 — it does **not** require `sensors_plus` at all. This app already
has a precedent for this exact pattern: `SensorChannelHandler.kt` talks to
`SensorManager` directly for the accelerometer/gyroscope IMU stream (Day
258), and `AudioCaptureService.kt`/`AudioChannelHandler.kt` split capture
logic from channel plumbing for the audio pipeline (Day 26/27). Checked
`android/app/src/main/AndroidManifest.xml` before writing anything: no
existing light/lux/ambient reference anywhere, `minSdkVersion 26` (well
above API 1, so `Sensor.TYPE_LIGHT` is unconditionally available), and no
manifest permission is required — ambient light has been a normal
(non-dangerous) Android sensor since API 1.

Implemented, mirroring the Audio split exactly:

- `android/app/src/main/kotlin/com/zapsafe/zapsafe_mobile/LightSensorService.kt`
  — owns the `SensorManager`/`SensorEventListener` capture logic.
  `hasLightSensor(context)` checks for real hardware presence; `start()`
  returns `false` (not an exception) when no sensor exists — a real,
  expected outcome on many phones/emulators.
- `android/app/src/main/kotlin/com/zapsafe/zapsafe_mobile/LightChannelHandler.kt`
  — bridges to Flutter: MethodChannel `com.zapsafe/light`
  (`start`/`stop`/`isStreaming`/`hasLightSensor`) + EventChannel
  `com.zapsafe/light.events` (`{t, lux}` per reading).
- `MainActivity.kt` — registers `LightChannelHandler(messenger,
  applicationContext)` alongside the existing `SensorChannelHandler`/
  `AudioChannelHandler` registrations.
- `AndroidManifest.xml` — added `<uses-feature
  android:name="android.hardware.sensor.light" android:required="false" />`
  for documentation; no `uses-permission` needed.

### The lux -> model-scalar mapping is a documented heuristic, not a calibration

`Sensor.TYPE_LIGHT` reports real SI lux. `k_confinement`'s trained `light`
input is **not** lux — it's an unnormalized `0.0`(dark)-`0.9`(lit) scalar
the training scripts invented. Checked `DAY269_K_CONFINEMENT_SCOPING.md`
and `day272_k_confinement_decorrelated.py` directly: both state plainly
that **no real ambient-light/lux dataset was ever collected**
(`load_custom_csv()`, the one path meant to carry real measured lux,
returned 0 samples in the actual training run — confirmed Day 269). There
is no ground-truth lux-to-`light` calibration to be faithful to, on either
side of this integration.

`lib/data/services/light_sensor_channel.dart`'s `luxToModelLight()`
implements a documented log-scale heuristic (standard photography/
illuminance reference points: <=1 lux -> 0.0, ~50 lux dim indoor -> ~0.3,
~500 lux normal indoor -> ~0.6, >=10 000 lux daylight -> clamps at the
model's 0.9 ceiling) rather than a linear scale, because lux spans several
orders of magnitude. This is stated as a heuristic in the code, not
overclaimed as calibrated — if it later proves miscalibrated against real
device behaviour under real confinement conditions, that is real, separate
follow-up work, same posture as every other "no real calibration data" gap
noted this week.

### Wiring

`KConfinementFusionPipeline` (`lib/data/services/k_confinement_pipeline.dart`):

- New `AmbientLightChannel _lightChannel` field (injectable for tests,
  defaults to the real `com.zapsafe/light` channel).
- `start()` now also calls `_startLightSensor()`, which checks
  `hasLightSensor()`, and if true, calls `start()` and subscribes to
  `readings()`, updating `_currentLightValue = luxToModelLight(reading.lux)`
  on every event.
- `_onAccel` (the inference trigger) now feeds `_currentLightValue` instead
  of the fixed `lightValue` constructor parameter, so a live Android sensor
  actually changes what's fed to the model, per inference.
- `usesRealLightSensor` changed from a build-wide `static const bool`
  (always `false`) to an **instance getter** reflecting whether *this
  specific running instance* actually acquired a live sensor stream. A
  build-wide const could no longer honestly describe reality once the
  answer depends on platform and device hardware, not just the app build.
- New `static const bool androidLightSensorChannelWired = true` — the
  compile-time capability flag (the code path exists), kept separate from
  the instance-level runtime truth.
- `stop()` resets to `lightValue` (the caller-supplied or placeholder
  default) and clears `_liveLightSensorActive`.

## 2. iOS — confirmed no equivalent OS API exists; stays on the placeholder

Verified this session: Apple does not expose a general ambient-light sensor
to third-party apps via any public API — not CoreMotion, not
CoreLocation, not any sensor framework. The only available proxy is
`AVCaptureDevice`'s ISO/exposure metadata, which requires an active
camera-preview session. This app has no such session running during
background detection (same fact Day 273 already used to reject a
camera-exposure proxy on any platform), and Day 269/272's training data
never used a camera-exposure proxy either, so wiring one now would not
even match what the model was trained on.

Checked `pubspec.yaml` and the repo layout before assuming an Android-first
scope: `ios/` exists and is a maintained platform target (not stubbed out
or excluded), so this is a real, stated platform-parity gap, not a scoping
shortcut taken because iOS "doesn't matter." iOS keeps using
`KConfinementFusionPipeline.kPlaceholderLightValue` exactly as Day 273 left
it — `usesRealLightSensor` stays `false` for every iOS instance because
`AmbientLightChannel` fails closed (`Platform.isAndroid` guard) on any
non-Android platform, never silently pretending to have a sensor.

## 3. Existing Flutter package vs. native code — decision

Searched for a maintained `light_sensor`-style Flutter plugin compatible
with this app's Dart SDK constraint (`sdk: '>=3.3.4 <4.0.0'`,
`pubspec.yaml`). The small number of ambient-light Flutter plugins that
exist are largely unmaintained (last published years ago, pre-null-safety
or borderline), which is a real risk for a safety-critical detection path.
Given this app's own established precedent — `SensorChannelHandler.kt` and
`AudioCaptureService.kt` both talk to native Android APIs directly rather
than pulling in a plugin, specifically because those APIs (`SensorManager`,
`AudioRecord`) are small, stable, and already available in the platform SDK
— the same reasoning applies here: `Sensor.TYPE_LIGHT` is a 1-sensor,
few-callback API, well within what a ~130-line native Kotlin addition
(`LightSensorService.kt` + `LightChannelHandler.kt` combined) covers
cleanly, without taking on a new dependency of uncertain maintenance status
for a safety-critical feature. This was corroborating evidence for the
native-code path already indicated by option 1 above, not a new deciding
factor — this repo's preference for owning native sensor code over adding
plugins was what it did when such an API already existed in-house, not an
absolute rule, but it held up again here.

## 4. Real verification performed this session

- `flutter analyze` on the new/changed files
  (`light_sensor_channel.dart`, `k_confinement_pipeline.dart`,
  `MainActivity.kt`, both new test files): clean except one unused-import
  warning, fixed.
- `flutter test test/light_sensor_channel_test.dart
  test/k_confinement_detector_test.dart`: **18 passed** (12 new — 9
  `light_sensor_channel_test.dart` covering `LightSensorReading.fromMap`
  parsing, `luxToModelLight` heuristic-mapping behaviour at real
  breakpoints, and `AmbientLightChannel`'s MethodChannel/EventChannel
  plumbing against a mocked native handler; 2 updated + kept passing in
  `k_confinement_detector_test.dart`).
- Full `flutter test`: **711 passed, 6 skipped, 1 failed** — the 1 failure
  is the same pre-existing, unrelated `test/widget_test.dart` ("Home index
  screen renders without errors") failure documented in
  `DAY262_GUNSHOT_MOTIONB_WIRING.md` through `DAY273_K_CONFINEMENT_WIRING
  .md`, not caused by this session. 711 is up from Day 273's 699 (12 new
  tests this session), no other regressions.
- `flutter build apk --debug`: **real, blocking, verified this session —
  succeeded.** `Running Gradle task 'assembleDebug'... 653.1s` /
  `Built build\app\outputs\flutter-apk\app-debug.apk` (518,040,428 bytes on
  disk, confirmed via `ls`). This is a real compile of
  `LightSensorService.kt`/`LightChannelHandler.kt`/`MainActivity.kt`
  against the real Android Gradle toolchain, proving the Kotlin actually
  compiles — not just that the Dart side type-checks. No physical device or
  emulator was available to verify a real lux reading (same posture as
  every prior native-sensor session this week — code-level + compile-level
  verification only, not an on-device run).

## 5. What is real now vs. still not

- **Real**: Android sensor acquisition (`Sensor.TYPE_LIGHT` via
  `SensorManager`, no permission needed, verified present since API 1,
  well under `minSdkVersion 26`), the platform channel plumbing
  (compile-checked, unit-tested against a mocked native handler), and the
  pipeline wiring that feeds live lux-derived values into every Android
  inference once the sensor is confirmed present.
- **Heuristic, not calibrated**: the lux-to-model-`light` mapping
  (`luxToModelLight`), because the model itself was never trained against
  real measured lux — this is stated plainly in the code and here, not
  hidden.
- **Still placeholder**: iOS (`kPlaceholderLightValue = 0.5`, unchanged
  from Day 273) — a real platform-parity constraint, because Apple exposes
  no ambient-light API to third-party apps, not an oversight.
- **Not done this session**: on-device verification of real lux values
  (no physical Android device available); field calibration of
  `luxToModelLight` against real confinement scenarios (no real lux
  dataset exists to calibrate against, same gap Day 269/272 already
  documented for the model's own training).
