# ZapSafe Mobile — Frontend Handoff

> **⚠️ CURRENT STATUS — Day 390/390 build complete (2026-08-07). Read this
> box first; everything below it is a historical snapshot frozen at Day 45
> and is stale for anything past that point (still useful as an early
> project-history record, not as current status).**
>
> **Build status:** all 90 days of the Days 301-390 plan are real, wired,
> and independently verified — `flutter analyze` 0 errors, `flutter test`
> 756 passed / 6 skipped / 0 failed, all 90 `day3{01..90}_*_screen.dart`
> routes registered and nav-tiled. 25 languages complete (Day 341-350).
> Days 1-390 exist as real screens; the project's own numbering treats
> Day 390 as "build complete," a statement about the frontend codebase,
> not about being live.
>
> **🔴 NOT launch-ready — real, currently-open blockers, found by this
> project's own audits, not yet fixed:**
> - No certificate pinning; `FLAG_SECURE` unset; the release Android build
>   is signed with **debug keys**, not a real release signing config
>   (Day 336 security execution).
> - The SOS trigger button hardcodes English text + LTR direction in its
>   screen-reader announcements during countdown/cancel/activation — the
>   app's single most safety-critical flow breaks for RTL/non-English
>   screen-reader users (Day 344 RTL regression).
> - Tamil and Telugu translations are missing the entire onboarding
>   namespace — falls back to English there (Day 347 Indic copy review).
> - Real DPDP compliance gaps: third-party sharing disclosure has no
>   backend route anywhere; several `/api/v1/account/*` endpoints are
>   real-but-unwired on the frontend (Day 337/383/384).
> - Day 361's Final QA War Room — the project's own go/no-go gate —
>   defaults to 5 open P0s and stays that way until each is genuinely
>   fixed and checked off, not just built-around.
>
> **The app has never actually launched.** No app store submission has
> happened (Day 362/363 are unexecuted checklists), no real users exist,
> and every "post-launch"/"live"/"rollout"/"hotfix" screen in Days 361-390
> is real, working tooling for when that becomes true — not a record of
> something that already happened. See `day390_project_complete_milestone_screen.dart`
> and `day361_final_qa_war_room_screen.dart` for the live, computed state.
>
> **Next step for launch:** fix the real P0s above, then execute (not
> just build) Days 361-365 for real.
>
> --- *original Day-45 snapshot below, kept for history* ---

# ZapSafe Mobile — Frontend Handoff (snapshot at end of Day 45)

> **Purpose of this doc:** drop this file into a new Claude / Cursor chat
> session and the assistant will be fully aligned with where the frontend
> stands. Mirrors the backend's `HANDOFF.md` style.
>
> **Last updated:** Day 90 ML milestone — 2026-05-24
> **Status:** 🚀 **MONTH 3 IN PROGRESS** — 402 tests passing (+6 platform-only
> skipped on host) · 0 known bugs · onboarding Steps 1-5 complete · backend sync pending

---

## ML milestones — H Aggressive Speech (scheduled)

| Phase | Day | Status | Scope |
|-------|-----|--------|-------|
| **A** | **90** | ✅ Done | `assets/models/h_aggressive_speech_v1.tflite` + `kZapsafeModels` (`aggressive_speech`). No DCS/SOS pipeline changes. |
| **B** | **100** | ⏳ **Scheduled** | Inference wiring: 38-dim prosodic features, `norm.json`, interpreter load, SOS/DCS integration, tests. |

**Phase B spec (canonical):** `kaggle_notebooks/h_aggressive_speech_push/DAY90_KAGGLE_TRAIN.md` → *Mobile integration — Phase A vs Phase B*.

**Training reference:** `day90_h_aggressive_speech.py` · norm: `output_v1/h_aggressive_speech_norm.json`.

**Do not start Phase B before Day 100** — Days 91–99 are Stripe premium (backend) + continued GPU training sweeps.

---

## 1. Project at a glance

**ZapSafe Mobile** is a Flutter 3.19.6 / Dart 3.3.4 cross-platform safety app.
It pairs with the Django/DRF backend at
`C:\Users\hridy\Desktop\zapsafe\letsstartbuilding\zapsafe_backend`.

### Working folder
`C:\Users\hridy\Desktop\zapsafe\letsstartbuilding\zapsafe_mobile`

### Timelines being followed
- **Frontend timeline:** `C:\Users\hridy\Desktop\zapsafeworking\ZAPSAFE_FRONTEND_TIMELINE.md`
- **Master timeline:** `C:\Users\hridy\Desktop\zapsafeworking\ZAPSAFE_MASTER_TIMELINE.md`
- **Days completed:** 1–40 (Month 1 + Month 2 BOTH SHIPPED = 40/390)
- **Day 41 = NEXT** — Month 3 begins. Onboarding wrapper (5-step flow: choose UI mode → home pin on OSM map → first contact → medical card → done · Protection Score starts at 40). Also kicks off **ML training subscription window** — full strategy in `C:\Users\hridy\Desktop\zapsafeworking\ZAPSAFE_ML_TRAINING_STRATEGY.md`.
- **🟡 Paid subs · DAY 41 (TOMORROW)**: **HuggingFace Pro $9/mo** kicks in. See the ML training strategy doc above for the rationale.

### Stack & key packages
- Flutter 3.19.6, Dart 3.3.4 (constraint `>=3.3.4 <4.0.0`)
- `flutter_riverpod ^2.4.0` — state management
- `go_router ^12.0.0` — navigation
- `dio ^5.3.0` — HTTP client (Dio interceptors for auth + logging)
- `flutter_secure_storage ^9.0.0` — JWT storage (Android Keystore / iOS Keychain)
- `shared_preferences ^2.2.0` — non-secret caches (device tier)
- `permission_handler ^11.0.0` + `device_info_plus ^9.0.0` — Day 11/13
- `firebase_core ^2.24.2` + `firebase_messaging ^14.7.10` + `flutter_local_notifications ^16.3.2` — Day 16
- Design-system fonts: ClashDisplay (headings), Syne (body), IBM Plex Mono (mono)

### Hard rules (from project memory)
- **From Day 35 onwards, every screen ever built must have a tile on the
  navigation index** (`day5_navigation_index_screen.dart`). The user does
  a visual regression pass on the emulator at Day 35, and any screen
  without a tile is invisible during that test.
- All custom button finders in widget tests use `ZapButton` (not
  `ElevatedButton`) — `ZapButton` is a `Material` + `InkWell` widget.

---

## 2. Folder layout (relevant subset)

```
zapsafe_mobile/
├── android/app/src/main/AndroidManifest.xml   # 6 permission declarations
├── lib/
│   ├── core/
│   │   ├── constants/         # api_config, countries
│   │   ├── theme/             # app_theme, colors, typography, spacing, high_contrast_theme
│   │   └── utils/jwt_utils.dart
│   ├── data/
│   │   ├── models/            # auth_models, country
│   │   └── services/
│   │       ├── api_client.dart        # Dio + JWT interceptor + proactive refresh
│   │       ├── auth_service.dart      # OTP request/verify, refresh, logout
│   │       ├── device_tier_service.dart  # Tier A/B/C + SharedPreferences cache
│   │       ├── permission_service.dart   # 5 permissions + requestOne + device info
│   │       └── token_storage.dart        # Secure storage wrapper
│   ├── domain/
│   │   ├── providers/
│   │   │   ├── auth_providers.dart        # AuthNotifier (hydrate, requestOtp, verifyOtp...)
│   │   │   ├── device_providers.dart      # deviceTierServiceProvider, deviceTierProvider
│   │   │   └── feature_flags_provider.dart  # featureFlagsProvider (depends on tier)
│   │   └── state/auth_state.dart
│   ├── presentation/
│   │   ├── navigation/app_router.dart      # 14 routes wired
│   │   ├── screens/
│   │   │   ├── auth/                       # phone_entry, otp_verify, otp_verify_placeholder
│   │   │   ├── onboarding/                 # permissions_screen (Day 12, user-facing)
│   │   │   ├── placeholder/                # 6 stub screens for not-yet-built features
│   │   │   ├── day2_design_system_screen.dart
│   │   │   ├── day3_theme_test_screen.dart
│   │   │   ├── day4_widgets_showcase_screen.dart
│   │   │   ├── day5_navigation_index_screen.dart   # ★ HOME — the index
│   │   │   ├── day6_auth_foundation_screen.dart
│   │   │   ├── day11_permissions_screen.dart       # Debug surface for permissions
│   │   │   ├── day13_device_tier_screen.dart
│   │   │   ├── day14_feature_flags_screen.dart
│   │   │   └── day15_week3_review_screen.dart      # ★ Week 3 milestone
│   │   └── widgets/           # zap_button, zap_card, zap_chip, zap_dialog,
│   │                          # zap_snackbar, zap_badge, zap_text_field,
│   │                          # phone_input, country_picker, protection_score_ring
│   └── main.dart
├── test/
│   ├── unit/
│   │   ├── feature_flags_test.dart    # 6 tests (Day 14)
│   │   └── jwt_utils_test.dart        # 22 tests (Day 10)
│   ├── widget/
│   │   ├── otp_verify_screen_test.dart    # 10 tests
│   │   └── phone_entry_screen_test.dart   # 7 tests
│   └── widget_test.dart           # 1 smoke test
└── pubspec.yaml
```

---

## 3. Daily progress · Days 1-15

### ✅ Week 1 (Days 1-5) — Foundation & Design System
| Day | Deliverable |
|---|---|
| 1 | Flutter scaffold, package list, folder structure |
| 2 | Design system — 22 colors, 14 type styles, 4dp grid, OLED dark theme |
| 3 | `ThemeData` + High Contrast Mode (WCAG AAA 21:1) |
| 4 | Components — `ZapButton`, `ZapCard`, `ZapTextField`, `ZapBadge`, `ProtectionScoreRing` |
| 5 | `ZapSnackbar`, `ZapDialog`, `ZapChip` + `go_router` with 7 routes |

### ✅ Week 2 (Days 6-10) — Auth Flow
| Day | Deliverable |
|---|---|
| 6 | `AuthService`, `TokenStorage`, `ApiClient`, Riverpod providers, `Day6AuthFoundationScreen` |
| 7 | `PhoneEntryScreen` — country picker, OTP request, validation, accessibility |
| 8 | `OtpVerifyScreen` — 6-digit boxes, auto-focus, paste, resend timer |
| 9 | `JwtUtils` (decode/exp/expiring-soon), proactive refresh in Dio interceptor, cold-start hydration |
| 10 | 40 tests — unit (JWT 22) + widget (phone entry 7 + OTP 10) + smoke (1) |

### ✅ Week 3 (Days 11-15) — Permissions + Device Tier + Feature Flags
| Day | Deliverable |
|---|---|
| 11 | `PermissionService` — 5 permissions (mic, location-always, camera, notifications, activity), `PermissionsResult`, `PermissionOutcome`, `requestOne()`. AndroidManifest declarations. Debug screen at `/permissions`. |
| 12 | `OnboardingPermissionsScreen` (`/onboarding/permissions`) — user-facing flow; per-permission card with expandable "Why we need this", impact-if-denied text, one-at-a-time request, progress bar |
| 13 | `DeviceTierService` — Tier A (Android 12+ / iOS 16+) / Tier B (Android 7-11 / iOS 13-15) / Tier C (older). `loadOrDetect()` with SharedPreferences cache, enabled/disabled feature lists per tier. Screen at `/device-tier` |
| 14 | `FeatureFlags` — 12 features × 3 tiers, `canUse()`, `isLocked()`, `lockedReason`. `featureFlagsProvider` watches `deviceTierProvider`. Screen at `/feature-flags` shows enabled + locked with "UPGRADE" badge + tooltip. 6 unit tests. |
| 15 | `Day15Week3ReviewScreen` (`/week3-review`) — milestone consolidation; checks permissions + tier + flags ready, shows green/yellow summary card. Smoke test updated. |

### ✅ Week 4 (Days 16-18 — Days 19-20 next) — FCM + Local Notifications + Routing + Drills
| Day | Deliverable |
|---|---|
| 16 | `PushService` — Firebase init w/ stub-mode fallback, FCM token retrieval, `flutter_local_notifications` w/ 2 Android channels (default + SOS bypass-DND), 4 `PushCategory` values (sosAlert / contactAck / batteryWarning / checkInReminder), foreground+background+terminated handlers, `registerWithBackend()` calling `PATCH /api/v1/push/register/`. `Day16PushNotificationsScreen` (`/push`) — token display, copy/refresh, per-category "simulate" tiles, register-with-backend button. `main.dart` initialises Firebase in try/catch. 5 new unit tests. |
| 17 | **Push routing matrix** — `PushCategoryMeta.destinationRoute` (sos/ack/battery → /sos-active, check-in → /dashboard). **iOS UNNotificationCategory** `ZAPSAFE_SOS_ALERT` with two foreground actions: `ZAPSAFE_RESPONDING` ("I'm Responding") + `ZAPSAFE_CALL_112` ("Call 112", destructive). **Android action buttons** mirror the iOS pair on SOS pushes. **`PushNavIntent` stream** — broadcast stream of nav intents (tap / action / cold-start), wired to GoRouter via `pushNavigationListenerProvider`. **Quiet hours** — `QuietHoursConfig` model (wrapping windows supported), `quietHoursProvider`, suppression for `CHECK_IN_REMINDER` only — SOS always fires. **Cold-start routing** — `emitColdStartIntentIfAny()` runs after listener attaches in `ZapSafeApp.build`. `Day17PushRoutingScreen` (`/push-routing`) — routing matrix tiles, action button cards, quiet-hours editor (toggle + hour pickers), last-intent debug card. 10 new unit tests covering window wrap-around, suppression matrix, route resolution. |
| 18 | **Scheduled notifications** — `PushService.scheduleNotification(payload, when)` using `tz.TZDateTime` (timezone DB initialised in `init()`); `cancelScheduled(id)` / `cancelAllScheduled()`; `listScheduled()` exposing the OS's `pendingNotificationRequests`. Stable ID generator via category+time hash so re-scheduling is idempotent. **Silent channel** — `zapsafe_silent` (importance LOW, no sound/vibration/lights); `showSilent({title, body})` helper. **Drill mode** — `fireDrill({scenario})` reuses the SOS channel + iOS/Android action buttons + `/sos-active` route but prefixes `[DRILL] ` to title/body and stamps `data.drill = true` so the backend dispatch path short-circuits. `Day18DrillsAndScheduleScreen` (`/drills-schedule`) — three panels: schedule (5 s / 1 min / tomorrow 9 am), live pending list with cancel buttons + cancel-all, silent post button, drill SOS with confirm dialog. 7 new unit tests covering drill payload contract + action-ID constants. |
| 19 | **Month 1 integration runner** — `lib/domain/integration/month1_runner.dart` (extracted, fully unit-tested): `IntegrationPhase` (key, name, description, runner, expectedFailReason), `PhaseResult` w/ `PhaseStatus { pending, running, pass, fail, expectedFail }`, `runMonth1Integration(phases) → Stream<PhaseResult>` that emits running + terminal for each phase **without short-circuiting on failure**, `IntegrationSummary.from(results)` w/ `isGreen` getter. **9 wired phases** cover phone validation, token storage round-trip, JWT decode + expiry, AuthNotifier hydration, permissions snapshot, device tier detect, feature flags resolve, FCM token, and FCM backend register (the last marked `expectedFailReason: "route not live yet (backend Week 4)"`). `Day19Month1IntegrationScreen` (`/month1-integration`) — RUN INTEGRATION button, live per-phase status cards w/ duration, summary card (PASS / EXPECTED / FAIL / TOTAL counters with isGreen evaluation). 11 new unit tests covering streaming order, no-short-circuit, expected-fail mapping, duration recording, summary counting. |
| 20 | **Permission flow widget tests** — extracted `permissionServiceProvider` so `OnboardingPermissionsScreen` is now overridable. `test/widget/onboarding_permissions_screen_test.dart` (NEW) with 8 tests: renders all 5 rows + hero, progress copy "0 of 5 granted", CONTINUE disabled until 5/5, "Why we need this" expand toggle, hero badge "WEEK 3 · DAY 12", ALLOW tap invokes `requestOne` w/ correct id, deniedForever swaps ALLOW → OPEN SETTINGS, all-granted shows "You're all set" hero + enables CONTINUE. **Month 1 milestone review screen** — `Day20Month1ReviewScreen` (`/month1-review`): hero "Month 1 Complete" with trophy badge, six milestone tiles each deep-linking to a live proof screen (design system → /, auth → /phone-entry, permissions → /onboarding/permissions, tier → /device-tier, FCM → /push-routing, navigation → /), stats card (20 days, 82+ tests, 15 live screens, 14 routes wired, 7 services, 4 push categories), Month 2 preview card. Smoke-test hero updated to "Month 1 Complete". |

**Total Month 1 tests: 83/83 passing.**

### Month 2 — Background Engine + Audio + TFLite Skeleton (in progress)
| Day | Deliverable |
|---|---|
| 21 | **Native Android foreground service** — `android/app/src/main/kotlin/.../ZapSafeService.kt` (Kotlin Service · START_STICKY · persistent notification on `zapsafe_foreground` channel at importance LOW · DCS pipeline placeholder, full impl Days 22-30). `MainActivity.kt` registers `com.zapsafe/background_service` MethodChannel w/ `start` / `stop` / `isRunning` handlers; `isServiceRunning()` uses ActivityManager. AndroidManifest declares FGS permissions (base + microphone + location + dataSync for Android 14+ per-type) + `RECEIVE_BOOT_COMPLETED` + `<service foregroundServiceType="microphone\|location\|dataSync" />`. **Dart façade** — `BackgroundService` w/ `start()` / `stop()` / `refresh()` / `supported` / cached `isRunning`; gracefully degrades off-Android (returns `false` without throwing). `backgroundServiceProvider` Riverpod singleton + `backgroundServiceRunningProvider` FutureProvider. `Day21BackgroundServiceScreen` (`/background-engine`) — status card w/ live state pill + START / STOP / refresh, 4-row architecture explainer, persistent-notification preview, platform-setup checklist (6 done, 2 marked Day 22). 6 unit tests (channel-name + method-name constants, off-Android short-circuit; 4 Android-only tests skip on host VM as expected). |

| 22 | **iOS BGProcessingTask** — `ios/Runner/BackgroundProcessingHandler.swift` (NEW): `BGTaskScheduler.register(forTaskWithIdentifier: "com.zapsafe.dcs")` called from `AppDelegate.application(_:didFinishLaunchingWithOptions:)`; `scheduleNext()` submits a fresh `BGProcessingTaskRequest` with `earliestBeginDate` 15 min ahead; `handleDCSTask` re-schedules first then runs (stub) before completing — never strands the watchdog. MethodChannel `com.zapsafe/ios_background` exposes `scheduleNext` / `cancel` / `taskIdentifier` / `isRegistered`. **Info.plist** — `BGTaskSchedulerPermittedIdentifiers = ["com.zapsafe.dcs"]`, `UIBackgroundModes = [processing, remote-notification, audio, location]`, plus 5 `NSUsageDescription` strings (mic, location-always, location-when-in-use, camera, motion). **Android BootReceiver** — `BootReceiver.kt` (NEW) listens to `BOOT_COMPLETED` / `QUICKBOOT_POWERON` / `MY_PACKAGE_REPLACED` and restarts `ZapSafeService` via `startForegroundService` on Android 8+; manifest registers it with `RECEIVE_BOOT_COMPLETED` permission gate. **Dart façade** — `IosBackgroundHandler` w/ `scheduleNext()` / `cancel()` / `readTaskIdentifier()` / `isRegistered()` / `supported` / off-iOS short-circuit; constants mirror Swift side. `iosBackgroundHandlerProvider` + `iosBackgroundRegisteredProvider` Riverpod. `Day22WatchdogScreen` (`/watchdog`) — hero, platform-detection badge, Android card (4 checkpoints), iOS card with live REGISTERED chip + Schedule Next / Cancel buttons, side-by-side strategy comparison table (lifetime / restart-on-kill / restart-on-reboot / fallback / SOS-time latency). 9 unit tests (constants, supported flag, off-iOS short-circuits; 2 iOS-only tests skip on the host VM). |

| 23 | **Platform-channel backbone** — `lib/native/platform_channels.dart` (NEW): `PlatformChannelNames` registry (5 channels, all `com.zapsafe/*`), `BackgroundServiceChannel` typedef (re-exports Day 21), `SensorChannel` (method `com.zapsafe/sensors` for start/stop/isStreaming + EventChannel `com.zapsafe/sensors.events` for `ImuSample` broadcast), `AudioChannel` (method `com.zapsafe/audio` for start/stop/isRecording). `lib/native/imu_sample.dart` (NEW) — immutable `ImuSample` with `timestampMs / ax/ay/az / gx/gy/gz`, `accelMagnitude` / `gyroMagnitude` helpers, defensive `fromMap()` that defaults missing fields to 0. **Android Kotlin stubs** — `SensorChannelHandler.kt` emits a 10-Hz synthetic sine waveform via EventChannel (each axis phase-shifted, az includes +g so it looks gravity-correct); `AudioChannelHandler.kt` flips a `@Volatile` Boolean on start/stop. Both registered in `MainActivity.configureFlutterEngine`. **Riverpod** — `sensorChannelProvider`, `audioChannelProvider`, `imuStreamProvider` (broadcast StreamProvider), `audioRecordingProvider` (refreshable Future). `Day23PlatformChannelsScreen` (`/platform-channels`) — channel registry card (5 rows w/ identifiers + descriptions), sensor card (live IMU readout w/ axis values + magnitudes + timestamp, START/STOP), audio card (live recording chip, START/STOP). 17 new unit tests: 4 channel-name registry assertions (uniqueness, com.zapsafe/* prefix, sensorsEvents = sensors+".events"), 5 ImuSample.fromMap parsing tests (well-formed, missing fields → 0, ints accepted, magnitude formulas), 4 SensorChannel off-platform short-circuits, 4 AudioChannel off-platform short-circuits. |

| 24 | **LP4 watchdog** — `androidx.work:work-runtime-ktx:2.9.0` added to `android/app/build.gradle`. `WatchdogWorker.kt` (NEW) extends `Worker` — reads `last_heartbeat_ms` from SharedPreferences (`zapsafe_engine` prefs), restarts the service via `startForegroundService` when `now - lastPing > 30_000ms`, returns `Result.retry()` on exceptions so WorkManager backs off. `WatchdogChannelHandler.kt` (NEW) — `com.zapsafe/watchdog` MethodChannel w/ `enqueue` (PeriodicWorkRequest @ 15 min, `ExistingPeriodicWorkPolicy.KEEP`), `cancel`, `lastHeartbeatMs`, `secondsSinceLastPing`, `thresholdMs`. `ZapSafeService.kt` (UPDATED) — adds `Handler` + `Runnable` heartbeat that writes `System.currentTimeMillis()` to SharedPreferences every 10s; cancels on `onDestroy`. **Dart** — `WatchdogChannel` (start/cancel/readStatus + `defaultThresholdMs = 30000`), immutable `WatchdogStatus` w/ `isStale` predicate (true when no heartbeat OR `sinceLastPing * 1000 > thresholdMs`). `watchdogChannelProvider` + `watchdogStatusProvider`. `Day24Lp4WatchdogScreen` (`/lp4-watchdog`) — hero, live heartbeat card auto-refreshing every 2s (last timestamp + seconds-since + threshold), WorkManager controls (ENQUEUE/CANCEL, disabled off-Android), LP4 contract explainer (heartbeat period / threshold / recovery latency / 3-layer defense stack). 13 new unit tests: registry uniqueness + watchdog name, default-threshold constant, `Platform.isAndroid` supported flag, `WatchdogStatus.isStale` matrix (null = stale, within = fresh, exactly-at-30s = fresh, > = stale, long-dead = stale), off-Android short-circuits (enqueue/cancel/readStatus). |

| 25 | **Week 5 acceptance** — `lib/domain/integration/month1_runner.dart` now exposes `runIntegrationPhases` as the generic alias (Day 19's `runMonth1Integration` becomes the original name kept for stability). `WatchdogChannel.isEnqueued()` added — calls a new `isEnqueued` method on the Kotlin handler that synchronously queries `WorkManager.getWorkInfosForUniqueWork` via `.get()` and returns true for `ENQUEUED`/`RUNNING` states. `Day25Week5ReviewScreen` (`/week5-review`) — **6 acceptance phases** wired with platform-aware `expectedFailReason` so iOS-only / Android-only phases on the wrong platform render yellow not red: foreground service alive · heartbeat fresh · WorkManager watchdog enqueued · iOS BGTask registered · sensor channel reachable · audio channel reachable. **Recovery-layer matrix** card shows the four layers + latency targets in one table. Summary card mirrors Day 19's PASS / EXPECTED / FAIL / TOTAL with `isGreen` evaluation. 2 new unit tests (off-Android `isEnqueued` short-circuit + `runIntegrationPhases` alias equivalence). |

| 26 | **Audio capture pipeline (real)** — `AudioCaptureService.kt` (NEW): `AudioRecord` at 16 kHz mono PCM-16, 450 ms sliding window (= 7 200 samples), RMS-gated VAD with threshold = 300 (whisper ~80, conversation ~1200), pre-computed Hann window applied in-place on voiced frames. Capture runs on a dedicated `Thread` at `MAX_PRIORITY - 1`; frames are posted to the main thread via `Handler(Looper.getMainLooper())` for thread-safe EventChannel emission. `AudioChannelHandler.kt` rewritten — now drives the real service and adds `vadThreshold` / `sampleRateHz` / `windowMs` introspection methods. **Dart** — `AudioFrame` model (`timestampMs`, `rmsEnergy`, `voiced`, `sampleCount`, `windowMs`, `threshold`, `normalisedEnergy` getter that maps to `[0, 1]` clamped at 4× threshold). `AudioChannel` extended with `frameStream` (broadcast `Stream<AudioFrame>`) and three introspection methods. New `PlatformChannelNames.audioEvents = 'com.zapsafe/audio.events'` (7 channels total now). **Providers** — `audioFrameStreamProvider` (broadcast StreamProvider), `audioCaptureSpecProvider` (record of native specs). `Day26AudioCaptureScreen` (`/audio-capture`) — live RMS bar (color flips green when voiced), voiced/silent chip, frame counters (TOTAL / VOICED / SUPPRESSED), capture-spec card (sample rate · window · samples-per-window · VAD threshold · window function · PCM format), START/STOP. 13 new unit tests: 3 `AudioFrame.fromMap` parsing tests, 5 `normalisedEnergy` clamping tests, 5 channel-name + off-Android short-circuit tests. Registry uniqueness assertion bumped to 7 channels. |

| 27 | **Native feature extraction** — `MfccExtractor.kt` (NEW): pure-Kotlin in-place radix-2 Cooley-Tukey FFT (size = 8192, next power of 2 above the 7 200-sample window), 26-bin Mel filterbank computed via `hzToMel` / `melToHz`, DCT-II → 13 MFCC; reusable working buffers (`real` / `imag` / `mags` / `logMel`) avoid the ~64 KB-per-frame allocation. Plus zero-crossing rate (sign-flip counter / sample count) and spectral centroid (Σ mag·freq / Σ mag). `AudioCaptureService.kt` extended with an optional `onFeatures` callback — features are computed on the capture thread (after Hann windowing) only for voiced frames, then posted to the main thread for EventChannel emission. `AudioChannelHandler.kt` registers a third channel `com.zapsafe/audio.features` and adds `mfccCount` / `melBins` / `fftSize` introspection methods. **Dart** — `AudioFeatures` model (`timestampMs`, `mfcc` immutable list, `zcr`, `spectralCentroidHz`); defensive `fromMap()` (non-num list elements → 0); `toFloat32Tensor()` packs the 15 scalars into a `Float32List` ready for the Day-31 TFLite interpreter. `AudioChannel` extended with `featureStream` + 3 spec getters. New `PlatformChannelNames.audioFeatures` (8 channels total). **Providers** — `audioFeatureStreamProvider` (broadcast StreamProvider), `audioFeatureSpecProvider` (extractor specs record). `Day27AudioFeaturesScreen` (`/audio-features`) — live feature vector card (t · dimension · zcr · centroid · mfcc[0]), **custom-painted signed MFCC bar chart** (zero-axis line, green bars positive, red bars negative, auto-normalised against per-frame max-abs), extractor spec card, info banner explaining voiced-only emission + Float32 TFLite contract, START/STOP. 13 new unit tests: 5 `fromMap` parsing tests (well-formed / missing / int-to-double / non-list entries → 0 / unmodifiable list), 3 helper tests (dimension / Float32 packing order / empty-mfcc case w/ Float32 epsilon), 1 registry uniqueness (8 channels), 4 off-Android short-circuits. |

| 28 | **iOS audio capture parity** — `ios/Runner/AudioCaptureEngine.swift` (NEW): `AVAudioEngine` + `installTap(onBus: 0)` on the device mic at the hardware's native format, `AVAudioConverter` resamples to 16 kHz mono int16, sliding 7 200-sample buffer fires per-window with the same RMS-VAD (threshold 300) + Hann taper as Android. Same payload schema on `com.zapsafe/audio.events` so Flutter sees one frame format across both platforms. Method channel handles `start/stop/isRecording/vadThreshold/sampleRateHz/windowMs` mirroring Android; `mfccCount/melBins/fftSize` return 0 today (Swift MFCC port lands Day 29). `EventSink` writes go through `DispatchQueue.main.async` for thread safety. `AppDelegate.swift` registers the engine alongside `BackgroundProcessingHandler`. **Dart** — `AudioChannel.supported` now `Platform.isAndroid \|\| Platform.isIOS`; new `featuresSupported` flag stays Android-only until Day 29. `featureStream` gates on the narrower flag (empty on iOS). Day 25 review's audio phase rewritten to use `audio.supported` rather than hard-coding Android. Existing `audio_frame_test.dart` short-circuit assertions renamed "off Android" → "off-platform (host VM)" and updated to gate on `Platform.isAndroid \|\| Platform.isIOS`. `Day28IosAudioScreen` (`/ios-audio`) — hero, platform-detection chip ("RUNNING ON iOS · capture LIVE" vs "RUNNING ON ANDROID · iOS parity built" vs "HOST VM · code-only view"), cross-platform parity matrix (6 rows), iOS pipeline explainer (6 steps from `AVAudioSession` setup through main-thread emission), Info.plist usage-strings reminder. Index hero → "iOS Audio Parity", new tile pinned at top. |

| 29 | **Flutter inference pipeline** — `lib/data/models/inference_result.dart`: immutable `InferenceResult { label, score, classScores, latencyMs, timestampMs }` with `isConfident` (threshold 0.7), 4-tier `severity` mapping (none < 0.4, low < 0.7, medium < 0.85, high). `lib/data/services/interpreter.dart`: `Interpreter` interface (`modelLabel` / `expectedInputSize` / `classLabels` / `infer(Float32List)` / `dispose`), two stub impls — `EnergyStubInterpreter` (deterministic score derived from `mfcc[0]` + ZCR + spectral centroid via softmax over `normal/shout/scream`, useful for live demo because scores correlate with the actual mic input) and `FixedStubInterpreter` (canned response, for tests). `lib/data/services/audio_feature_service.dart`: subscribes to the feature stream, packs to `Float32List` via `AudioFeatures.toFloat32Tensor()`, calls `interpreter.infer()`, emits `InferenceResult` on a broadcast stream; tracks `framesIn` / `inferencesOut` / `triggersFired` / `maxScore` / `averageLatency`; defensive — drops mis-sized tensors with a debug log, survives interpreter exceptions, idempotent `start()` / `dispose()` cascades to interpreter. **Providers** — `interpreterProvider` (overridable, defaults to `EnergyStubInterpreter`), `audioFeatureServiceProvider`, `inferenceResultStreamProvider`. `Day29InferenceScreen` (`/inference`) — latest-inference card with class-score bars + TRIGGER chip when confident, live stats row (frames in / inferences out / triggers fired / avg latency), interpreter info card, scrollable recent-12 results list, START/STOP. 18 new unit tests: dispatch order, threshold counting (0.7 sharp boundary), tensor-shape mismatch drop, exception survival, `resetStats`, idempotent `start`, disposal cascade, 3 `InferenceResult` invariants (threshold + severity tier mapping), 3 `EnergyStubInterpreter` checks (softmax sums to 1.0, higher-energy → higher scream score, undersized tensor → `ArgumentError`). |

| 30 | **Week 6 acceptance** — `AudioFeatureService` extended with cadence tracking (EMA over inter-frame timestamps, α = 0.25) + end-to-end latency tracking (capture-to-inference-complete). New fields: `meanFrameIntervalMs`, `lastEndToEndLatencyMs`, `maxEndToEndLatencyMs`, `isWithinE2eBudget`, `static const endToEndBudgetMs = 530`. `resetStats()` clears them all. `Day30Week6ReviewScreen` (`/week6-review`) — 7 acceptance phases (channel supported · features supported · service alive · cadence in 400-500 ms band · e2e ≤ 530 ms · interpreter wired · battery target documented), live latency readout card, 4-row latency budget table (capture window · inference ceiling · total budget · battery target). Hero badge → "WEEK 6 COMPLETE · DAY 30 OF 30", new tile pinned, progress summary extended. 5 new unit tests covering EMA settle, pre-frame edge case, e2e population, budget constant, resetStats coverage. |

| 31 | **TFLite scaffold** — `tflite_flutter: ^0.10.4` added to `pubspec.yaml` (the package is free + open-source — no API keys, no subscriptions, runs on-device). **`assets/models/`** now ships 4 placeholder `.tflite` files (`scream_classifier_v1`, `motion_anomaly_v1`, `scene_analyzer_v1`, `dcs_fusion_v1`) — each is a 1 KB text stub that contains the `PLACEHOLDER_TFLITE_FILE` marker so `tflite_flutter` rejects it on load (the expected pre-Month-3 behaviour). **`ModelRegistry`** (`lib/data/services/model_registry.dart`) — `ModelDefinition` (key, displayName, assetPath, purpose, realModelEta, realSizeMb), `kZapsafeModels` const list of all 4, `loadAll() → List<ModelAssetStatus>` (sizeBytes, isPlaceholder, previewSnippet). **`TfliteInterpreter`** (`lib/data/services/tflite_interpreter.dart`) — implements `Interpreter`; static `tryLoad()` factory returns null on any failure (missing model · placeholder bytes · shape mismatch · no native FFI) so the rest of the app falls back to `EnergyStubInterpreter` from Day 29. **Providers** — new `realInterpreterProvider` FutureProvider attempts the upgrade, `modelRegistryProvider`, `modelAssetStatusesProvider`. `Day31TfliteModelsScreen` (`/tflite-models`) — active-interpreter card (REAL TFLITE / STUB FALLBACK chip), 4-row model asset table (PLACEHOLDER / MISSING / REAL with size readout, asset path, purpose, real ETA, preview line), 7-step fallback contract card. 8 new unit tests: catalogue count + key + path uniqueness + path convention + non-empty metadata + timeline-spec filename match + registry happy path + placeholder detection. |

| 32 | **DCS composite engine** — `MotionFeatures` model (`lib/data/models/motion_features.dart`): 6-DOF feature record with `atRest` / `walking` / `impact` factories, `toFloat32Tensor()`. `DCSScore` (`lib/data/models/dcs_score.dart`) holds the 4 per-modality `InferenceResult`s + `triggerCandidate` getter. `FixedStubInterpreter` extended with configurable `expectedInputSize` + `classLabels` so stub fallbacks can fit any of the 4 slots. New `LinearStubInterpreter` (weighted sum + 3-class synthesis) stands in for the fusion `.tflite`. **`DCSInferenceEngine`** (`lib/ml/inference/dcs_inference_engine.dart`): static async `create()` factory loads all 4 interpreters in parallel via `Future.wait`, each falls back to a slot-appropriate stub independently. `infer({audio, motion?, sceneFeatures?})` runs scream + motion + scene sequentially then feeds **danger-class probabilities** (not top-class scores) into fusion via `_dangerScore` helper — confident "normal" outputs no longer get treated as fusion signals. `dcsEngineProvider` FutureProvider. `Day32DcsEngineScreen` (`/dcs-engine`) — slot status table (REAL / STUB chip per slot), 4-scenario simulator (calm · walking · shout+walking · scream+impact), live DCSScore breakdown with class-score bars, trigger policy card. 14 new unit tests: 4 MotionFeatures (factory differentiation + tensor packing), 3 LinearStubInterpreter (weighted math · zero input · size validation), 6 DCSInferenceEngine (all-stub world · slot status order · infer returns 4-component DCSScore · runs counter · scream > calm danger-class probability · DCSScore.rows). |

| 33 | **DCS stream + auto-trigger** — `TriggerEvent` model (`lib/data/models/trigger_event.dart`) with `TriggerKind { alertPending, autoSos }`, backend-facing `label` strings ("ALERT_PENDING" / "AUTO_SOS"), LP25 `passive: true` flag on every event. **`DCSScoreWatcher`** (`lib/ml/inference/dcs_score_watcher.dart`) implements the two-tier policy: **`alertThreshold = 0.75`** for 3 consecutive windows → `alertPending`, **`autoSosThreshold = 0.85`** for a single window → `autoSos` (bypasses vote). Reset semantics: vote resets after firing, on a below-threshold window, OR on auto-SOS. `observe(DCSScore)` returns nullable event; `watch(Stream)` async-yields events. **Providers** — `dcsScoreWatcherProvider` (singleton), `dcsStreamProvider` (audio features → engine → DCSScore), `triggerEventStreamProvider`. `Day33DcsStreamScreen` (`/dcs-stream`) — vote progress dots (3-step), live fusion-scream sparkline with the two threshold lines drawn, INJECT CALM / HIGH / CRITICAL synthetic-score buttons that mutate watcher state deterministically, trigger event log with severity-coloured rows, RESET button. 14 new unit tests: thresholds + required-windows constants, single-high non-fire, three-in-a-row alert fire, vote-reset-after-firing, reset-on-low-window mid-vote, sharp 0.75 / just-below-0.749 boundary, auto-SOS single-window fire, auto-SOS clears alert counter, sharp 0.85 boundary, reset() clears state, `watch()` stream produces 2 events for a synthetic 6-frame trace, TriggerKind label coverage. **Bug-fix**: missing `dart:async` import in `inference_providers.dart` (StreamController) caught by the smoke test on first run. |

| 34 | **Inference on worker isolate** — `DCSInferenceEngine.fromInterpreters({...})` factory exposes the previously-private constructor so worker isolates can build their own stub engines. **`IsolatedDcsRunner`** (`lib/ml/inference/isolated_dcs_runner.dart`): wraps `compute()` with a sendable `IsolatedInferenceInput` record (AudioFeatures + MotionFeatures, both primitive-only and isolate-safe). The top-level `_runInferenceInIsolate` worker constructs a fresh 4-slot stub engine inside the worker isolate, runs one inference, returns the `DCSScore`. **Known limitation documented**: real `tflite_flutter` `Interpreter` instances are FFI pointers and can't cross isolate boundaries — Day 34 path is stub-only by design; Month 3 upgrade to a long-lived worker isolate with a persistent SendPort is mapped out in the screen's caveat card. **`LatencyProfiler`** (`lib/ml/inference/latency_profiler.dart`): pure-Dart `measure<T>(Future<T> Function())` wraps an async call with a stopwatch (records on success AND failure via try/finally); `record(int)` for explicit samples; `stats` exposes `min / p50 / p95 / max / mean / count` via `LatencyStats`; `LatencyStats.budgetMs = 450` matches the DCS capture cadence; `isWithinBudget` requires p95 ≤ budget (not just mean). **Provider** `isolatedDcsRunnerProvider`. `Day34IsolateLatencyScreen` (`/isolate-latency`) — live-UI card with an always-animating spinner (visceral demo: worker-isolate path keeps it smooth, main-isolate path stutters), STRESS TEST buttons for MAIN vs WORKER (30 cycles each), side-by-side stats table with budget chip (WITHIN / OVER), per-strategy latency histograms, TFLite cross-isolate caveat card. 13 new unit tests covering empty profiler, single-sample stats collapse, sorted-distribution percentiles, negative-sample rejection, order independence, reset, immutable samples view, async measurement, failure-path recording, budget constant, budget gate with empty/within/over states. |

| 35 | **Week 7 acceptance** — `Day35Week7ReviewScreen` (`/week7-review`): same pattern as Day 25/30 review runners. **8 acceptance phases**: (1) tflite_flutter package loadable, (2) ModelRegistry · 4 assets discoverable in bundle, (3) DCSInferenceEngine composes 4 slots, (4) Engine.infer() returns DCSScore with all 4 component results, (5) Watcher fires ALERT_PENDING after 3 synthetic high windows (uses a fresh `DCSScoreWatcher` instance — independent of any live stream state), (6) Watcher fires AUTO_SOS on a single ≥ 0.85 window with vote bypassed, (7) IsolatedDcsRunner returns a valid DCSScore over `compute()`, (8) Latency budget: 5-cycle main-isolate stress with p95 ≤ 450 ms gate. **10-row checklist card** at the top of the screen lists every day in the audio+ML pipeline arc (Day 26 → Day 35) with the Week-7 days highlighted green. Summary mirrors Day 25/30 pattern — PASS / EXPECTED / FAIL / TOTAL with `isGreen` evaluation. No new unit tests today; the phases themselves are runtime assertions that exercise existing tested code paths. |

| 36 | **IMU service + fall detection** — `FallEvent` model (`lib/data/models/fall_event.dart`): `timestampMs / peakAccelMagnitude / freefallDurationMs`. **`FallDetector`** (`lib/data/services/fall_detector.dart`) — pure state-machine class, 4 states (`idle / possibleFreefall / awaitingImpact / impactDetected`), thresholds: `freefallThreshold = 2.94 m/s²` (= 0.3 g), `impactThreshold = 25.0 m/s²` (≈ 2.5 g), `freefallMinMs = 200`, `impactWindowMs = 1000`, `impactLatchMs = 2000`. `observe(magnitude, timestampMs)` mutates state and returns nullable `FallEvent`. **`ImuService`** (`lib/data/services/imu_service.dart`) — wraps `sensors_plus` accelerometer + gyroscope streams; maintains 45-sample sliding window (~450 ms at 100 Hz); emits `MotionFeatures` snapshot every 450 ms with mean / variance / peak for accel + gyro magnitudes; `latestFeatures` getter for synchronous read by the DCS stream provider; broadcast `features` and `falls` streams; graceful `try/catch` on subscription so it degrades to dormant on unsupported platforms; `@visibleForTesting` `injectAccel(x,y,z, timestampMs)` for synthetic-fall demos and tests. **Providers** — `imuServiceProvider`, `motionFeaturesStreamProvider`, `fallEventStreamProvider`. **DCS stream upgrade** — `dcsStreamProvider` now reads `imu.latestFeatures` per audio frame (falls back to `MotionFeatures.atRest` if no sensor data yet). `Day36ImuServiceScreen` (`/imu-service`) — live accel/gyro magnitude bars with colour bands (orange below freefall threshold, red above impact), START/STOP, SIMULATE FALL button (injects 8 low-g + 1 spike samples), 450 ms feature snapshot card, fall-event log with timestamps. 14 new unit tests covering thresholds constants, state-machine transitions (idle → possibleFreefall → awaitingImpact → impactDetected → idle latch), false-alarm rejection (impact-only · walking gait · brief sub-200 ms zero-g), `lastPeak` lifecycle. **Bug-fix during build**: `AccelerometerEvent` in `sensors_plus_platform_interface 1.2.0` only accepts 3 positional args (x, y, z) — initial test code passed a 4th DateTime arg; fixed by dropping it. |
| 37 | **GPS service** — `lib/data/services/gps_service.dart` — adaptive-cadence Geolocator wrapper. `GpsPollingProfile.fromAppState(AppState)` maps the 7-state enum (idle/postIncident → off · monitoring → 5 min low · elevated → 30 s high · alertPending/sosActive/escalating → 10 s best). `setAppState()` restarts the timer at the new cadence and fires an immediate fix. Last-fix cache lives in SharedPreferences (`zapsafe.gps.last`). In-memory `_batch` buffer auto-flushes at 6 samples to `POST /api/v1/gps/batch/` (404 today — buffer kept on failure). `GpsSample.isHighQuality` enforces LP12 (≤ 50 m). 12 new unit tests covering sample round-trip, LP12 gate, profile mapping × 7 states, injectSample stream, setAppState rotation, clearBatch, no-api buffer behaviour. |
| 38 | **GPS fallback + central state machine + battery handler** — *Three deliverables this day per the timeline.* (1) **Cell / WiFi fallback** — `GpsSample` gains a `provider: GpsProvider` field (gps/cell/wifi · default gps · backwards-compatible `prov` JSON key). `lib/data/services/cell_location_service.dart` — façade over the new `com.zapsafe/cell` channel (Android `TelephonyManager` / iOS `CTTelephonyNetworkInfo`); native handler not wired today, Dart side returns null on host VM and exposes `syntheticEstimate(centre, radius, seed)` + `stubNext(GpsSample?)` for the screen + tests. `lib/data/services/gps_fallback_coordinator.dart` — attaches to `GpsService.samples`, applies LP12 gate (≤ 50 m), debounces with `minAttemptGap` (30 s default), restarts a 90 s `staleWindow` timer on every fix; calls `cell.estimate()` and `gps.injectSample(...)` to merge the result. Counters: `gpsLowQualityTriggers / staleTriggers / gpsRecoveries / fallbackEmissions`. (2) **Central 7-state machine** — `lib/domain/providers/app_state_provider.dart` — `AppStateNotifier extends StateNotifier<AppState>` with all transition methods documented in the timeline: `onElevatedSignal / onElevatedReset / onDCSThresholdExceeded / onManualTrigger(TriggerMethod) / onCancelWithRealPIN / onCancelWithDuressPIN (sets LP3 silentlyEscalating flag) / onAlertPendingExpired / onTier1Acknowledged / onSosResolved / returnToMonitoring / powerOn / powerOff`. 15 s alert countdown timer (`AppStateNotifier.alertCountdown`) auto-fires `onAlertPendingExpired` on schedule. Transition history capped at 32 entries with cause strings. `appStateGpsBridgeProvider` — Riverpod listener that mirrors transitions to `GpsService.setAppState` AND to the legacy `gpsAppStateProvider` (Day 37's screen still consumes the StateProvider directly). (3) **Battery threshold handler** — `battery_plus ^5.0.0` added. `lib/data/models/battery_profile.dart` — `BatteryTier` enum (normal/powerSaver/proactiveDrop/vadOnly), `BatteryThresholds.tierForLevel(level, isCharging)` table at 20/15/10 %, immutable `BatteryProfile` with `cameraEnabled / gpsReduced / proactiveDropActive / vadOnly` derived getters. `lib/data/services/battery_service.dart` — wraps `battery_plus`, subscribes to `onBatteryStateChanged`, runs a 60 s safety poll for OEMs that don't emit on fractional drops; broadcast `profiles` stream + `latest` getter; `injectLevel(int, {isCharging})` for screen + tests; catches `Object` in `refresh()` so MissingPluginException / upower failures never crash the loop. `Day38FallbackAndStateScreen` (`/day38`) — three panels in one screen (fallback counters · state machine + transition log · battery tier table). New `appStateProvider`, `batteryServiceProvider`, `batteryProfileStreamProvider`, `batteryProfileProvider`, `cellLocationServiceProvider`, `gpsFallbackCoordinatorProvider`, `gpsFallbackBootstrapProvider`. **54 new unit tests** across three test files: `app_state_notifier_test.dart` (16 tests covering every transition, history bound, LP3 silent flag, countdown auto-fire); `gps_fallback_test.dart` (17 tests covering provider wire encoding, GpsSample round-trip with `prov`, CellLocationService stubbing + counters + reproducible seed, FallbackCoordinator evaluate/attach/recovery/debounce/idempotent detach/force-bypass); `battery_service_test.dart` (21 tests covering threshold table, charging override, derived flags, copyWith, equality, stream dedup, refresh-never-throws guarantee, safety-poll constant). Smoke test hero updated to "Fallback · State · Battery". Index tile pinned at top of Day 5 nav screen. |
| 39 | **Trigger pipeline wiring** — connects yesterday's `AppStateNotifier` to the upstream trigger sources built in Days 33 (DCS watcher) + 36 (fall detector). **`lib/domain/integration/trigger_orchestrator.dart`** — pure policy-free wrapper: `attach({Stream<TriggerEvent> dcsEvents, Stream<FallEvent> fallEvents})` subscribes idempotently; per-event handlers route to the appropriate notifier method. Routing table: `TriggerKind.alertPending → notifier.onDCSThresholdExceeded` · `TriggerKind.autoSos → notifier.onAutoSos` (new) · `FallEvent → notifier.onManualTrigger(TriggerMethod.fall)` · `dispatchManual(method) → notifier.onManualTrigger`. Counters per source (`dcsAlertCount / dcsAutoSosCount / fallCount / manualCount / totalDispatched`) and a 32-entry rolling event log (`OrchestratorEvent { source, label, resultingState, at }`). Stream handlers exposed as public `dispatchDcs / dispatchFall / dispatchManual` so screens + tests can synthesise events without manufacturing real DCSScore pipelines. **New transition: `AppStateNotifier.onAutoSos`** — implements LP25: cancels any in-flight alert countdown, transitions monitoring/elevated/alertPending → sosActive in one hop. No-op when already SOS_ACTIVE/ESCALATING or in IDLE. **`triggerOrchestratorProvider`** (singleton) + **`triggerOrchestratorBootstrapProvider`** — bootstrap pipes `triggerEventStreamProvider` and `fallEventStreamProvider` through `StreamController`s into `orch.attach(...)`, keeping the orchestrator's API plain `Stream<T>` rather than Riverpod-aware. **PIN cancel flow** — `lib/data/services/pin_policy.dart`: `PinPolicy.classify(pin) → PinMatch?` (real / duress / null), demo PINs `1234` (real) and `9999` (duress) hard-coded for the screen until the onboarding flow (Day 41+) writes them to secure storage. `lib/presentation/widgets/zap_pin_entry.dart` — reusable 4-digit PIN entry widget (visually matched to Day 8 OTP boxes but smaller + masked + no clipboard helper). `Day39StateWiringScreen` (`/day39`) — live state card with countdown, pipeline counter card, inject buttons (DCS ALERT_PENDING / DCS AUTO_SOS / IMU FALL), manual SOS triple (manual / double-tap / voice cue), PIN entry pad (visible only during alertPending/sosActive/escalating, distinguishes real vs duress with correct LP3 wiring), orchestrator log + state transition log side-by-side. **19 new unit tests** in `trigger_orchestrator_test.dart`: `onAutoSos` × 4 (skip countdown · cancel mid-countdown · idle no-op · sosActive no-op), DCS routing × 7 (alert → state · autoSos → state · fall → state · manual counter · total sum · history limit · autoSos during alertPending), stream attach × 2 (idempotent · detach preserves counters), `PinPolicy` × 4 (classify branches · helpers · labels · constants), notifier integration × 2 (real PIN clears silent flag · duress flips LP3). Smoke test hero updated to "Trigger Pipeline · Wired". Index tile pinned at top of Day 5 nav screen. |
| 40 | **Month 2 wrap · acceptance runner + milestone review** — `lib/domain/integration/month2_runner.dart`. **`buildMonth2Phases(WidgetRef)`** declares **13 phases** covering every piece landed Days 21-39: (1) platform-channel registry (9 channels · com.zapsafe/* prefix); (2) Android FGS reachable (platform-aware expectedFail on iOS/host); (3) iOS BGProcessingTask handler reachable (platform-aware expectedFail on Android/host); (4) audio capture pipeline supported (Android + iOS); (5) TFLite registry · 4 model slots; (6) DCSInferenceEngine composes 4 slots; (7) DCS watcher · 3-window vote + AUTO_SOS bypass both fire; (8) IMU service instantiable + `MotionFeatures.atRest`; (9) GPS profile mapping × 7 states; (10) GPS fallback policy · LP12 50 m gate; (11) battery tier table (80/18/13/7 + charging override); (12) AppStateNotifier · monitoring → alertPending → sosActive → postIncident → monitoring; (13) TriggerOrchestrator wiring · synthetic DCS autoSos → sosActive + fall → alertPending. **Pure-runner abstraction** — `month2PhaseRunners` static helpers expose every Riverpod-free phase as a `PhaseResult` synthesiser so the unit tests can probe them without a Flutter binding. **`Day40Month2ReviewScreen`** (`/month2-review`) — mirrors Day 20 (Month 1 review) + Day 35 (Week 7 acceptance) shape: hero with "Month 2 SHIPPED · Day 40 of 390" badge, seven milestone tiles with deep-links to live proof screens (FGS → Day 21 · watchdog → Day 22/24 · audio → Day 26 · TFLite/DCS → Day 32 · IMU → Day 36 · GPS → Day 37 · state machine → Day 39), PASS/EXPECTED/FAIL/TOTAL summary, per-phase tiles, by-the-numbers stats card (318 tests · 20 LIVE screens · 32 routes · 15+ services · 9 channels · 4 ML slots), Month 3 preview card with the **HuggingFace Pro $9/mo Day 41 subscription heads-up** rendered in warning yellow. **10 new unit tests** in `month2_runner_test.dart` covering each pure runner + an `IntegrationSummary.isGreen` collapse over all unit-runnable phases. Smoke test hero updated to "Month 2 SHIPPED". Index hero badge → "MONTH 2 COMPLETE · DAY 40 OF 390" (safe-green). Tile pinned at top of Day 5 nav screen. |

**Total tests now: 328/328 passing (+ 6 platform-only skipped on the host VM).**

### Month 3 — Onboarding flow (Days 41-44 complete)
| Day | Deliverable |
|---|---|
| 41 | **Onboarding Step 1** — Welcome + Terms & Conditions · `_StepIndicator` (5-segment progress bar) · `_TermsCard` (scrollable) · `_AgreementCheckbox` (InkWell + Checkbox) · Next gated on agreement · `onboardingProvider` (shared StateNotifier for all 5 steps). Route `/onboarding/step1`. 9 widget tests. |
| 42 | **Onboarding Step 2** — Emergency Contacts · Tier 1 (max 1) / Tier 2 (max 2) / Tier 3 (max 2) · `_ContactRow` StatefulWidget (TextEditingControllers for name+phone) · Next gated on `hasRequiredContact` (Tier-1 valid). Route `/onboarding/step2`. 12 widget + 4 model tests. |
| 43 | **Onboarding Step 3** — Trusted Locations (optional · skip/next) · `_QuickAddSection` (preset chips: Home/Work/Gym/School/Custom) · `_PresetChip` animated with green+check when added · `_LocationList` with 5-cap counter · Custom location TextField. Route `/onboarding/step3`. 13 widget + 7 model tests. |
| 44 | **Onboarding Step 4** — Accessibility Preferences (optional) · `_LanguageSection` (DropdownButtonFormField, 13 languages, LP20 APAC baselines) · `_DisplaySection` (Simple Mode + High Contrast toggles) · `_FontScaleSection` (Slider 1×–2×, 4 stops, live preview text). Always-enabled Next. Route `/onboarding/step4`. 10 widget + 6 model tests. |
| 45 | **Onboarding Step 5** — Review + Complete · `_ContactsReviewCard` (lists contacts by tier with Edit → Step 2) · `_LocationsReviewCard` (chip list, "No locations" empty state, Edit → Step 3) · `_AccessibilityReviewCard` (language / simple mode / high contrast / font scale, Edit → Step 4) · Complete Setup button uses `ZapButton.isLoading` during stub 800 ms POST delay · calls `completeOnboarding()` then navigates to `/dashboard`. Backend POST (`/api/v1/onboarding/complete/`) wired when endpoint is live. Route `/onboarding/step5`. 13 widget tests. |

**Month 3 tests so far: 402/402 passing (+ 6 platform-only skipped).**

### 🎉 Month 2 SHIPPED
Seven milestones, all green:
1. **Android foreground service** — Days 21-22 · ZapSafeService + BootReceiver + FGS types
2. **iOS BGProcessingTask + watchdog** — Days 22 + 24 · BGTaskScheduler + WorkManager 15-min + LP4
3. **Audio capture pipeline** — Days 26-28 · 16 kHz · VAD · 13 MFCC + ZCR + centroid · iOS parity
4. **TFLite scaffold + DCS engine** — Days 31-34 · 4 model slots · stub fallback · compute() worker
5. **IMU service · fall detection** — Day 36 · accel + gyro · 450 ms snapshots · freefall + impact
6. **GPS + cell-tower fallback** — Days 37-38 · adaptive cadence · LP12 gate · cell merge
7. **7-state machine + trigger pipeline** — Days 38-39 · 12 transitions · LP3 · LP25 · orchestrator

### 🎉 Month 1 SHIPPED
Six milestones, all green:
1. **Design system** — Days 1–5 · OLED dark + WCAG-AAA high-contrast · 10+ ZapWidgets
2. **Auth flow** — Days 6–10 · Phone → OTP → JWT (Keystore/Keychain) · proactive refresh
3. **Permissions onboarding** — Days 11–12 · 5 permissions · one-at-a-time UX
4. **Device tier detection** — Days 13–14 · Tier A/B/C · cached · feature-flag-gated
5. **FCM push notifications** — Days 16–18 · 4 categories · action buttons · drill mode
6. **Navigation structure** — Days 5 + 7 + 17 · go_router · onboarding redirect · push routing

### Stub-mode caveat (Day 16)
The `firebase_messaging` plugin requires `google-services.json` (Android) /
`GoogleService-Info.plist` (iOS) to issue real FCM tokens. **Until those are
dropped in**, `PushService` falls back to stub mode:
- `getToken()` returns `STUB_FCM_TOKEN_ANDROID_<timestamp>` (deterministic per session)
- `setupHandlers()` is a no-op
- `requestPermission()` still works via `flutter_local_notifications` directly
- `showLocal(...)` still renders local notifications normally
- `registerWithBackend()` will 404 (backend route lands in backend Week 4)

To switch to live FCM:
1. Create a Firebase project at console.firebase.google.com
2. Add an Android app with package `com.zapsafe.zapsafe_mobile`
3. Drop the downloaded `google-services.json` into `android/app/`
4. Add to `android/build.gradle` → buildscript dependencies:
   `classpath 'com.google.gms:google-services:4.4.0'`
5. Add to `android/app/build.gradle` (top): `apply plugin: 'com.google.gms.google-services'`
6. Re-run — `PushService.firebaseAvailable` will flip to true automatically.

---

## 4. Conventions

### Riverpod patterns
- Singleton service exposed via `Provider((_) => Service())`.
- Async detection / hydration exposed via `FutureProvider`.
- Derived state exposed via `Provider<AsyncValue<T>>` that does `ref.watch(...).whenData(...)`.
- `AuthNotifier extends StateNotifier<AuthState>` — overridable in tests via
  `authStateProvider.overrideWith((_) => fakeNotifier)`.

### Test patterns
- Unit tests live in `test/unit/`.
- Widget tests live in `test/widget/`, override Riverpod providers with `_Fake*` subclasses.
- Smoke test at `test/widget_test.dart` verifies home index mounts.
- **Never use `find.widgetWithText(ElevatedButton, ...)`** — ZapButton is custom (`Material` + `InkWell`). Use `find.widgetWithText(ZapButton, ...)` or `find.text(...)`.

### Navigation
- All routes referenced via `AppRoutes.xxx` constants, never raw strings.
- Onboarding redirect: `isOnboardedProvider` (currently defaults `true` for dev).
- Day-specific screens have route names matching their feature (`/device-tier`, not `/day13`).

### Theme
- Dark theme by default (`ZapTheme.darkTheme()`).
- High-contrast variant available via `ZapTheme.highContrastTheme()`.
- Colors via `ZapColors.x`, never literals.
- Type via `ZapTypography.x.copyWith(...)`.
- Spacing via `ZapSpacing.xs/sm/md/lg/xl/xxl/xxxl/huge`.

### Accessibility
- All interactive widgets meet WCAG AAA 75×75dp via `ZapSpacing.minTouchTarget`.
- TalkBack/VoiceOver labels on every input (`Semantics(label: ..., ...)`)
- 21:1 contrast ratio in high-contrast mode.

---

## 5. What Day 40 SHIPPED

Month 2 wrap — Day 40 produces the acceptance runner that probes every
Month 2 deliverable in one pass, plus the milestone review screen that
ships alongside Day 20's Month 1 review.

### A. Month 2 acceptance runner

**`domain/integration/month2_runner.dart`** declares 13 phases via
`buildMonth2Phases(WidgetRef)` — reuses Day 19's `IntegrationPhase` /
`runIntegrationPhases` infrastructure so the UI shape matches Day 35's
Week 7 review.

| # | Phase | What it proves |
|---|---|---|
| 1  | Platform-channel registry | 9 channels declared · com.zapsafe/* prefix |
| 2  | Android FGS reachable     | platform-aware (expected on iOS / host) |
| 3  | iOS BGTask handler        | platform-aware (expected on Android / host) |
| 4  | Audio pipeline supported  | AudioChannel works on Android + iOS |
| 5  | TFLite registry           | 4 model slots declared · path convention |
| 6  | DCSInferenceEngine        | composes 4 slots (stubs OK) |
| 7  | DCS watcher               | 3-window vote + 0.85 AUTO_SOS both fire |
| 8  | IMU service               | instantiable · MotionFeatures.atRest synthesises |
| 9  | GPS profile mapping       | all 7 AppStates map correctly |
| 10 | GPS fallback policy       | LP12 50 m gate flags low-quality fixes |
| 11 | Battery tiers             | 80/18/13/7 + charging override |
| 12 | AppStateNotifier          | monitoring → alertPending → sosActive → … → monitoring |
| 13 | TriggerOrchestrator       | DCS autoSos → sosActive · fall → alertPending |

**Pure runner abstraction** — `month2PhaseRunners` static helpers expose
every Riverpod-free phase as a plain `PhaseResult` synthesiser. The unit
tests probe them directly on the host VM without a Flutter binding.

### B. Month 2 milestone review screen

**`presentation/screens/day40_month2_review_screen.dart`** (`/month2-review`)
mirrors Day 20's Month 1 review. Seven milestone tiles, each with a
deep-link to a live proof screen:

| Milestone | Days | Deep-link |
|---|---|---|
| Android foreground service | 21-22 | /background-engine |
| iOS BGProcessingTask + watchdog | 22 + 24 | /watchdog |
| Audio capture pipeline | 26-28 | /audio-capture |
| TFLite scaffold + DCS engine | 31-34 | /dcs-engine |
| IMU service · fall detection | 36 | /imu-service |
| GPS + cell-tower fallback | 37-38 | /gps-service |
| 7-state machine + trigger pipeline | 38-39 | /day39 |

Plus a stats card (20 days · 328 tests · 20 LIVE screens · 32 routes ·
15+ services · 9 channels · 4 ML slots) and a Month 3 preview card
flagging **the HuggingFace Pro $9/mo subscription that lands Day 41**
in warning yellow so it's impossible to miss.

### Files

- `domain/integration/month2_runner.dart`
- `presentation/screens/day40_month2_review_screen.dart`
- `test/unit/month2_runner_test.dart` — 10 unit tests

### Index updates

- Hero badge → "MONTH 2 COMPLETE · DAY 40 OF 390" (safe-green)
- Title → "Month 2 SHIPPED"
- Day 40 tile pinned at top of the navigation list

---

## 5b. What Day 39 SHIPPED (reference)

The Day 38 `AppStateNotifier` was policy-only — it knew how to transition
between states but nothing was calling its methods. Day 39 builds the
wiring layer that connects every upstream trigger source to those methods,
plus the LP3 duress-PIN cancel flow.

### A. TriggerOrchestrator

**`domain/integration/trigger_orchestrator.dart`** — pure policy-free
adapter. `attach({dcsEvents, fallEvents})` subscribes idempotently to
both streams; `detach()` cancels but preserves counters.

| Source                        | Kind / shape         | AppStateNotifier method                          |
|-------------------------------|----------------------|--------------------------------------------------|
| DCSScoreWatcher (Day 33)      | `alertPending`       | `onDCSThresholdExceeded`                         |
| DCSScoreWatcher (Day 33)      | `autoSos` (≥ 0.85)   | **`onAutoSos`** (new) · skips 15 s countdown     |
| FallDetector (Day 36)         | `FallEvent`          | `onManualTrigger(TriggerMethod.fall)`            |
| Manual surfaces               | `dispatchManual()`   | `onManualTrigger(method)`                        |

Public dispatch entrypoints (`dispatchDcs / dispatchFall / dispatchManual`)
let screens + tests synth events without manufacturing real pipelines.

Counters: `dcsAlertCount / dcsAutoSosCount / fallCount / manualCount /
totalDispatched`. 32-entry rolling event log (`OrchestratorEvent`).

### B. AppStateNotifier.onAutoSos (LP25)

New transition method: monitoring / elevated / alertPending → sosActive in
one hop. Cancels any in-flight alert countdown. No-op in idle (service
off) and from sosActive/escalating (already firing). The DCSScoreWatcher's
single-window ≥ 0.85 path uses this — the alert countdown only protects
against the vote-based trigger, never against a critical-signal trigger.

### C. PIN cancel flow (LP3)

**`data/services/pin_policy.dart`** — `PinPolicy.classify(pin)` returns
`PinMatch.real`, `PinMatch.duress`, or null. Demo PINs hard-coded for the
Day 39 screen (`1234` real / `9999` duress); production storage lands with
the onboarding flow (Day 41+).

**`presentation/widgets/zap_pin_entry.dart`** — reusable 4-digit PIN box
widget. Matches Day 8 OTP visually but smaller + dot-masked + no
clipboard helper (we don't want PINs in clipboard history).

The duress path is the LP3 contract:
1. UI shows the same "cancelled" snackbar as the real PIN
2. State transitions back to MONITORING
3. **`silentlyEscalating` flag flips to true** — the dispatch path
   (backend Week 4+) reads this and keeps firing SOS silently

The attacker who forced the PIN entry sees nothing distinguishing duress
from real. The real PIN flow clears the flag; subsequent duress attempts
can re-arm it independently.

### Riverpod surface

- `triggerOrchestratorProvider` — singleton bound to `appStateProvider.notifier`
- `triggerOrchestratorBootstrapProvider` — pipes `triggerEventStreamProvider`
  + `fallEventStreamProvider` into `orch.attach(...)`; watched by the
  Day 39 screen on mount

### Files

- `data/services/pin_policy.dart`
- `domain/integration/trigger_orchestrator.dart`
- `domain/providers/trigger_orchestrator_providers.dart`
- `presentation/widgets/zap_pin_entry.dart`
- `presentation/screens/day39_state_wiring_screen.dart`
- `test/unit/trigger_orchestrator_test.dart` — 19 unit tests
- *(modified)* `domain/providers/app_state_provider.dart` — added `onAutoSos`

## 5b. Day 38 reference (still relevant)

Three deliverables per the timeline: GPS fallback (cell-tower / WiFi), the
central 7-state app state machine, and the battery threshold handler.

### A. GPS cell-tower / WiFi fallback

**`data/models/gps_sample.dart`** gained a `GpsProvider` field
(gps / cell / wifi · defaults gps · serialised as `prov` only when
non-default, keeping old caches byte-compatible).

**`data/services/cell_location_service.dart`** — façade over the new
`com.zapsafe/cell` channel. Native handler doesn't ship in this build
(real impl tied to Mobile-Country-Code tables in Month 4); Dart side
returns null on real devices today and exposes:
- `syntheticEstimate({centre, radiusM, seed, provider})` — reproducible
  synthetic estimate used by the screen + tests
- `stubNext(GpsSample?)` — forces the next `estimate()` to return that sample
- counters `attempts / successes / failures`

**`data/services/gps_fallback_coordinator.dart`** — attaches to
`GpsService.samples`, applies the LP12 gate (≤ 50 m), debounces with
`minAttemptGap` (30 s default), restarts a 90 s `staleWindow` timer on
every fix. When the gate fails it calls `cell.estimate()` and merges the
result into the GPS stream via `gps.injectSample(...)`. Cell/WiFi
samples are passively passed through and never recurse.

### B. Central 7-state app state machine

**`domain/providers/app_state_provider.dart`** — `AppStateNotifier extends
StateNotifier<AppState>` with the timeline's full transition matrix:

- `onElevatedSignal / onElevatedReset` — monitoring ↔ elevated
- `onDCSThresholdExceeded` — monitoring/elevated → alertPending (starts 15 s countdown)
- `onManualTrigger(TriggerMethod)` — same, but cause is the trigger kind
- `onCancelWithRealPIN` — any → monitoring · clears `silentlyEscalating`
- `onCancelWithDuressPIN` — UI returns to monitoring **but** sets the LP3
  `silentlyEscalating` flag so the dispatch path keeps escalating silently
- `onAlertPendingExpired` — alertPending → sosActive (auto-fires after 15 s)
- `onTier1Acknowledged` — sosActive → escalating
- `onSosResolved` — sosActive/escalating → postIncident
- `returnToMonitoring` — anywhere non-idle → monitoring
- `powerOn / powerOff` — idle ↔ monitoring

Transition history capped at 32 entries with cause strings; the Day 38
screen renders it as a live audit log.

`appStateGpsBridgeProvider` — Riverpod listener that mirrors transitions
to (a) `GpsService.setAppState` (so GPS cadence rotates with the state
machine) and (b) the legacy `gpsAppStateProvider` (so Day 37's screen
keeps working without a refactor).

### C. Battery threshold handler

**`data/models/battery_profile.dart`** — `BatteryTier` enum + threshold
table at 20 % / 15 % / 10 %. `BatteryThresholds.tierForLevel(level,
isCharging)` is the single source of truth; charging always returns
`normal`. Derived getters on `BatteryProfile`: `cameraEnabled`,
`gpsReduced`, `proactiveDropActive`, `vadOnly`.

**`data/services/battery_service.dart`** — wraps `battery_plus ^5.0.0`,
subscribes to `onBatteryStateChanged`, plus a 60 s safety poll for OEMs
that don't emit on every fractional drop. `injectLevel(int, {isCharging})`
for screen + tests. `refresh()` catches `Object` so plugin failures
(missing native handler · upower not running on Windows · iOS simulator)
never crash the loop.

### Files

- `data/models/gps_sample.dart` — `GpsProvider` enum + `provider` field + `isFallback`
- `data/models/battery_profile.dart` — `BatteryTier` + `BatteryThresholds` + `BatteryProfile`
- `data/services/cell_location_service.dart` — channel façade + synthetic estimator
- `data/services/gps_fallback_coordinator.dart` — LP12 + stale-window policy
- `data/services/battery_service.dart` — `battery_plus` wrapper
- `domain/providers/app_state_provider.dart` — `AppStateNotifier`, `appStateProvider`, `appStateGpsBridgeProvider`, `TriggerMethod`, `AppStateTransition`
- `domain/providers/gps_fallback_providers.dart` — coordinator + cell service + bootstrap
- `domain/providers/battery_providers.dart` — service + profile stream + sync getter
- `native/platform_channels.dart` — registry entry for `com.zapsafe/cell`
- `presentation/screens/day38_fallback_and_state_screen.dart` — three-panel debug surface
- `test/unit/app_state_notifier_test.dart` — 16 transition tests
- `test/unit/gps_fallback_test.dart` — 17 cell + coordinator tests
- `test/unit/battery_service_test.dart` — 21 tier + service tests

**Route:** `/day38` (AppRoutes.day38FallbackAndState) · tile pinned at
the top of the Day 5 navigation index per the Day 35+ regression rule.

### 🌅 Heads-up for Day 41 subscriptions

🔴 **BLOCKING** (cost): **HuggingFace Pro · $9/mo** kicks in tomorrow per
the optimized solo-founder cost roadmap. Full ML training strategy lives
at `C:\Users\hridy\Desktop\zapsafeworking\ZAPSAFE_ML_TRAINING_STRATEGY.md`
— read it before sign-up.

🟡 OPTIONAL: `flutter_map ^6.0.0` is already in pubspec (added Day 1)
but `latlong2` will land Day 42 for the OSM home-pin step.

🟢 ALREADY-FLAGGED: every other dep Day 41 needs is in pubspec.

Day 41 work itself is the onboarding wrapper:
- `presentation/screens/onboarding/onboarding_wrapper.dart` w/ 4-step
  progress indicator
- `step1_ui_mode.dart` — choose Standard / Simple / High Contrast
- `step2_home_pin.dart` — drop pin on map (Day 42's `flutter_map`)
- `step3_add_contact.dart` — first emergency contact (Day 43 wires
  `fast_contacts`)
- `step4_medical.dart` — blood type / allergies (optional)
- `step5_done.dart` — Protection Score starts at 40 points

Day 41 itself ships steps 1, 4, 5 + the wrapper scaffold. Steps 2 and 3
land on Days 42-43 when their respective packages come in.

---

## 6. Index screen — what's tappable today

The home screen (`Day5NavigationIndexScreen` at `/`) currently shows tiles for:

**LIVE · MONTH 3 · DAYS 41–45** (real screens):
- Day 45 · Onboarding Step 5 — Review + Complete Setup ★ (latest)
- Day 44 · Onboarding Step 4 — Accessibility Preferences
- Day 43 · Onboarding Step 3 — Trusted Locations
- Day 42 · Onboarding Step 2 — Emergency Contacts
- Day 41 · Onboarding Step 1 — Welcome + Terms

**LIVE · MONTH 1 + MONTH 2 · DAYS 11–40** (real screens):
- Day 40 · Month 2 Review ★ (Month 2 milestone)
- Day 39 · State Wiring
- Day 38 · Fallback + State + Battery
- Day 37 · GPS Service
- Day 36 · IMU Service
- Day 35 · Week 7 Review (Week 7 milestone)
- Day 34 · Isolate Latency
- Day 33 · DCS Stream
- Day 32 · DCS Engine
- Day 31 · TFLite Models
- Day 30 · Week 6 Review (Week 6 milestone)
- Day 29 · Inference
- Day 28 · iOS Audio
- Day 27 · Audio Features
- Day 26 · Audio Capture
- Day 25 · Week 5 Review (Week 5 milestone)
- Day 24 · LP4 Watchdog
- Day 23 · Platform Channels
- Day 22 · Watchdog (cross-platform)
- Day 21 · Background Engine (Month 2 begins)
- Day 20 · Month 1 Review
- Day 19 · Month 1 Integration
- Day 18 · Drills & Schedule
- Day 17 · Push Routing
- Day 16 · Push Notifications
- Day 15 · Week 3 Review
- Day 14 · Feature Flags
- Day 13 · Device Tier
- Day 12 · Onboarding · Permissions
- Day 11 · Permissions (debug)
- Day 7 · Phone Entry
- Day 8 · OTP Verify
- Day 6 · Auth Lab

**PLACEHOLDERS · 6 routes wired**:
- Onboarding · Dashboard · Contacts · SOS Active · Evidence Vault · Settings

Every Live tile is fully functional. The Placeholder tiles route to stub
screens that explain when they'll be built (`PlaceholderScaffold` widget).

---

## 7. Test command

```bash
cd C:/Users/hridy/Desktop/zapsafe/letsstartbuilding/zapsafe_mobile
flutter test
```

Expected: `00:xx +402 ~6: All tests passed!` (6 platform-only tests skip on the host VM — 4 Android-only run on an Android emulator, 2 iOS-only run on a Mac/simulator)

> **Note:** `flutter analyze` crashes with OOM on Windows + Dart 3.3.4 (known
> Dart VM bug, not our code). `flutter test` covers compile-correctness more
> reliably anyway.

---

## 8. Backend coordination

- **Backend status:** Days 1-39 complete, 1124 tests passing, 91.59% coverage.
- **All Month-1 backend endpoints** the frontend depends on (auth, contacts,
  SOS trigger, FCM registration) are live and tested.
- See `zapsafe_backend/HANDOFF.md` for endpoint details, error codes, JWT format.
