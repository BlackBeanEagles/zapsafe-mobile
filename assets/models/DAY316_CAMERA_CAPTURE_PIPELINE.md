# Day 316 — building the camera-capture pipeline M3 needed

Day 315 made `SceneDetectorV2` (the real UCF-Crime-trained M3 model) real,
loadable, and correctly callable given a real 224×224×3 frame — but its
own doc was explicit that nothing in the app actually produced one: no
`camera` package dependency, no `CameraController` usage anywhere in
`lib/`, confirmed by a real grep. This closes that gap.

## Design decisions, and why

**Periodic still capture (`takePicture()`), not a continuous image
stream.** `startImageStream()` hands back raw platform-native frames —
YUV_420_888 on Android, BGRA8888 on iOS — which need real, per-platform
colour-space conversion before they're usable RGB. A JPEG from
`takePicture()` is a portable format `package:image` decodes identically
on both platforms with zero platform branching. It also matches what this
actually is: a periodic *scene check* (minutes apart while calm, seconds
apart only during an active alert), not real-time video analysis — a
continuous stream would hold the camera open and drain battery for a use
case that needs one frame every 15s-5min at most. And it's a smaller,
more auditable privacy surface: a discrete capture that's decoded to a
tensor and immediately deleted, not an open continuous feed.

**Cadence follows [AppState] via a new [ScenePollingProfile], mirroring
[GpsPollingProfile]'s exact shape and state groupings** — same
off/monitoring/elevated/sosTime tiers, same "off entirely in idle/
postIncident" rule. This app already had a real, reviewed answer for how
a battery/privacy-sensitive background sensor loop should scale with app
state (GPS polling, Day 37); camera capture is the same category of
concern, so it gets the same answer rather than a second bespoke design.
Intervals are deliberately slower than GPS's at every tier (5min/45s/15s
vs. GPS's 5min/30s/10s) since a camera capture-and-classify cycle is real
hardware I/O, meaningfully more expensive per-tick than a GPS fix.

**`SceneCaptureScheduler` mirrors `GpsService`'s exact shape** —
`start()`/`stop()`/`setAppState()`/a broadcast results stream/attempted-
succeeded-failed counters — the same idiom, not a new one. Wired into
Riverpod via `sceneCaptureSchedulerProvider` (built once the real
detection engine resolves) + `appStateSceneCaptureBridgeProvider`
(mirrors `appStateGpsBridgeProvider` line for line).

**The scheduler only ever fires when the active interpreter can actually
accept a camera frame** (`expectedInputSize == 224*224*3`) — checked via
the interpreter's own declared contract, not a hardcoded class check, so
this keeps working if a future model version changes shape without
touching this file. If `HeuristicSceneDetector` (8-float input) is what's
active for this phone's tier, the scheduler correctly never opens the
camera at all rather than feeding it an incompatible tensor.

## A real bug this found before it shipped

`CameraFrameService.jpegBytesToSceneRgb`'s own test suite
(`test/camera_frame_service_test.dart`) found that `package:image`'s own
`decodeImage()` throws a raw `RangeError` — not a null return — on truly
empty input, because its format-sniffing code (`findDecoderForData` →
each decoder's `isValidFile`) indexes into the buffer without a length
guard first. This only fires for *empty* bytes specifically; garbage/
malformed-but-nonempty bytes already returned null correctly. Fixed by
wrapping the whole decode/resize/flatten path in try/catch so a camera
glitch producing an empty capture degrades to "no frame this tick"
instead of crashing the scheduler's loop. Found by testing the real
function against a real edge case, not assumed safe because the
happy-path tests passed.

## Verification

- `flutter analyze`: 65 issues (baseline unchanged, 0 errors).
- `flutter test`: 775 passed / 6 skipped (previous 767 + 8 new tests in
  `test/camera_frame_service_test.dart` — real geometry, real RGB channel
  fidelity through a real JPEG encode/decode/resize round-trip, a
  row-major-vs-transposed layout check via a real coordinate-encoding
  gradient image, and the empty-bytes crash fix above).
- `CameraController`/`takePicture()`/permission flow themselves need a
  real device and so are **not** exercised by `flutter test` — same class
  of limitation this project has hit for every hardware-backed detector
  (TFLite interpreters, `sensors_plus`, motion/scream models). The
  decode/resize/flatten preprocessing — the part most likely to hide a
  silent bug — is real, tested, and passing; the camera I/O itself is
  reviewed against `camera` package docs but not device-verified in this
  sandbox (no working Gradle toolchain, confirmed again this session).
- `android.permission.CAMERA` / `NSCameraUsageDescription` were already
  declared on both platforms (Day 82/evidence-capture era) — no manifest
  changes needed.
- `camera: ^0.11.0+2` and `image: ^4.9.2` added to `pubspec.yaml`; the
  `camera_android` plugin's own `minSdkVersion` (21) is well below this
  app's `minSdkVersion` (26) — no conflict.

## What this still does NOT close

This wires capture → preprocess → real inference, and starts/stops it on
the app's own real state machine. It does **not** feed the result into
DCS fusion (M9) — the live DCS scoring loop (`dcsStreamProvider`/
`DCSInferenceEngine`) still takes audio + motion only, no scene signal,
exactly as before. `SceneCaptureScheduler.results` is a real, live stream
of real `InferenceResult`s ready to be consumed — wiring it into the
fusion score itself is a separate, deliberate integration decision, not
silently done here.
