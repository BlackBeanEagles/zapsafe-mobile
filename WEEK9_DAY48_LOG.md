# Week 9 · Day 48 — Device Diagnostics Screen

**Date:** 2026-05-23  
**Theme:** Real-device health check dashboard — all sensors + ML pipeline in one screen

---

## What Was Built

### Screen (`lib/presentation/screens/day48_device_diagnostics_screen.dart`)
- Route: `/device-diagnostics`
- **PHONE CAPABILITY card**: cached tier display + live Probe button (runs `PhoneCapabilityDetector().detect(forceReprobe: true)`)
- **MODEL BUNDLE card**: `detectionEngineProvider` async — shows AI count, heuristic count, total size
- **IMU card**: Start/Stop toggle — live `accelPeak`, `accelMean`, `gyroPeak` from `motionFeaturesStreamProvider`
- **GPS card**: Start/Stop toggle — shows lat/lng/accuracy on first fix from `gpsServiceProvider`
- **PERMISSIONS card**: 5-permission status grid (microphone, locationAlways, camera, notifications, activityRecognition) with Recheck button

### How to use on real device
1. Open the app → tap "Day 48 · Device Diagnostics" tile
2. Tap **Probe** → verify capability tier matches your device (flagship = HIGH)
3. Tap **Start** on IMU → walk/shake phone → confirm accelPeak rises above 10 m/s²
4. Tap **Start** on GPS (requires location permission) → wait for fix → confirm lat/lng update
5. Check permissions — all 5 should be green on a freshly onboarded device

## Test Results
**23/23 tests passed** (`test/unit/day48_device_diagnostics_test.dart`)

| Group | Tests |
|-------|-------|
| PhoneCapabilityTier.tierFor | 6 — boundary tests: <100→high, 100-499→medium, ≥500→low |
| CapabilityProbeResult.aiViable | 3 — threshold at 1000 ms |
| CapabilityProbeResult construction | 2 — fields and tierLabel |
| MotionFeatures (IMU data source) | 5 — atRest/walking/impact fixtures, non-negative fields, tensor shape |
| GpsSample (GPS data source) | 3 — lat/lng/accuracyM preserved, timestampMs positive |
| PermissionOutcome (permissions check) | 4 — granted/denied equality, enum values |

## Files
| File | Action |
|------|--------|
| `lib/presentation/screens/day48_device_diagnostics_screen.dart` | Created |
| `lib/presentation/navigation/app_router.dart` | Updated |
| `lib/presentation/screens/day5_navigation_index_screen.dart` | Updated (tile added) |
| `test/unit/day48_device_diagnostics_test.dart` | Created — 23 tests |
