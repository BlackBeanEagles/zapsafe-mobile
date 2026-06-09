# Week 9 · Day 49 — Audio Pipeline Validation

**Date:** 2026-05-23  
**Theme:** Real-device audio pipeline end-to-end: mic → MFCC → HeuristicScreamDetector → InferenceResult

---

## What Was Built

### Screen (`lib/presentation/screens/day49_audio_pipeline_screen.dart`)
- Route: `/audio-pipeline`
- **Start/Stop toggle**: opens mic via `AudioChannel.featureStream`, wires `AudioFeatureService` with `HeuristicScreamDetector`
- **LIVE DETECTION card**: top class label + score %, confidence bar, latency, TRIGGER badge, per-class breakdown bars
- **CONFIDENCE HISTORY**: rolling 20-frame bar chart — bars coloured green/orange/red by threshold
- **AUDIO FEATURES card**: live `mfcc[0]`, `zcr`, `spectralCentroidHz`, tensor length (15)
- **PIPELINE STATS card**: framesIn, triggersFired, maxScore %, avgLatency ms, running status

### How to use on real device
1. Open → tap **Start** (grant microphone permission)
2. Speak normally → label should read `normal`, score bar stays low
3. Whistle or shout loudly → `mfcc[0]` rises, ZCR + centroid rise, score bar turns orange/red
4. Scream → all 3 gates fire → label = `scream`, TRIGGER badge appears, triggersFired increments
5. Tap **Stop** — pipeline tears down cleanly

## Test Results
**22/22 tests passed** (`test/unit/day49_audio_pipeline_test.dart`)

| Group | Tests |
|-------|-------|
| AudioFeatures model | 4 — fields, tensor length=15, layout [MFCC·ZCR·centroid], silent values |
| HeuristicScreamDetector via tensor | 3 — scream score >0.5, silent classScore <0.1, inputSize matches |
| AudioFeatureService stats | 6 — framesIn, triggersFired, maxScore, averageLatency, isActive, inferencesOut |
| Confidence history window | 3 — rolling cap at 20, last item is most recent, clamp [0,1] |
| InferenceResult thresholds | 6 — isConfident boundary 0.70/0.69, severity high/medium/low/none |

## Files
| File | Action |
|------|--------|
| `lib/presentation/screens/day49_audio_pipeline_screen.dart` | Created |
| `lib/presentation/navigation/app_router.dart` | Updated |
| `lib/presentation/screens/day5_navigation_index_screen.dart` | Updated (tile added) |
| `test/unit/day49_audio_pipeline_test.dart` | Created — 22 tests |
