# Week 9 · Day 50 — Motion & Fall Detection Validation

**Date:** 2026-05-23  
**Theme:** Real-device IMU pipeline: accelerometer/gyroscope → MotionFeatures → HeuristicMotionDetector + FallDetector state machine

---

## What Was Built

### Screen (`lib/presentation/screens/day50_motion_validation_screen.dart`)
- Route: `/motion-validation`
- **Start/Stop toggle**: calls `ImuService.start()/stop()`, subscribes to `features` + `falls` streams, polls live magnitudes at 10 Hz
- **LIVE SENSOR MAGNITUDES card**: accel (m/s²) + gyro (rad/s) big stats; 30-sample spark-line bar chart coloured green/orange/red by threshold
- **HEURISTIC MOTION DETECTOR card**: threat score bar, label, TRIGGER badge, triggers total, latency
- **MOTION FEATURES SNAPSHOT card**: all 6 fields (accelMean/Var/Peak, gyroMean/Var/Peak) + tensor length
- **FALL DETECTOR STATE MACHINE card**: current state with icon + colour, last FallEvent fields (peak, freefall ms), falls counter, 4-segment state progress bar

### How to use on real device
1. Tap **Start** — sensors activate
2. Hold phone still → accel ≈ 9.8 m/s², spark-line flat green, state = IDLE
3. Walk briskly → accel peak rises to 12–14, bar turns orange briefly
4. Simulate drop: hold phone chest-high, quickly thrust it downward and catch — accel dips then spikes → state machine progresses idle → freefall → awaitingImpact → impactDetected

### Key FallDetector timing (discovered during tests)
- Freefall threshold: < 2.94 m/s² (0.3 g)
- Freefall must sustain **≥ 200 ms** before transitioning to `awaitingImpact`
- Impact spike: ≥ 25 m/s² must occur within **1000 ms** of freefall confirmation
- Impact latched for **2000 ms** so UI can render the event

## Test Results
**24/24 tests passed** (`test/unit/day50_motion_validation_test.dart`)

| Group | Tests |
|-------|-------|
| MotionFeatures model | 6 — fixtures, tensor shape/layout, all-non-negative |
| HeuristicMotionDetector via tensor | 5 — impact/atRest threat scores, inputSize, classLabels, timestampMs |
| FallDetector state machine | 6 — idle start, freefall transition (200ms hold), full freefall→impact→FallEvent, reset, walking stays idle, enum values |
| FallEvent fields | 3 — all 3 fields preserved |
| Spark-line window | 4 — cap at 30, newest last, clamp [0,1], colour buckets |

## Files
| File | Action |
|------|--------|
| `lib/presentation/screens/day50_motion_validation_screen.dart` | Created |
| `lib/presentation/navigation/app_router.dart` | Updated |
| `lib/presentation/screens/day5_navigation_index_screen.dart` | Updated (tile added) |
| `test/unit/day50_motion_validation_test.dart` | Created — 24 tests |
