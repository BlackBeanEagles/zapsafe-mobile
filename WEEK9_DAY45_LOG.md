# Week 9 · Day 45 — Model Bundle Service

**Date:** 2026-05-23  
**Theme:** Bundle TFLite models, wire HeuristicDetectionEngine, verify app size < 50 MB

---

## What Was Built

### ModelBundleService (`lib/data/services/model_bundle_service.dart`)
- `ModelLoadStatus` enum: `placeholder`, `realLoaded`, `realLoadFailed`, `skippedImageModel`
- `ModelSlotResult`: per-model status, file size, active interpreter; `usesAi`, `statusLabel`, `sizeMbLabel`
- `ModelBundleResult`: all slots + `HeuristicDetectionEngine` + `totalModelBytes`; `loadedAiCount`, `heuristicCount`, `totalSizeLabel`
- `ModelBundleService.load(tier)`: tries each TFLite asset, gracefully falls to heuristic on placeholder/failure/shape mismatch

### Routing Logic
| Model | Expected Input | Asset Size | Outcome |
|-------|---------------|------------|---------|
| scream_classifier_v1 | 15 floats (MFCC) | 658 B (placeholder) | `placeholder` → HeuristicScreamDetector |
| motion_anomaly_v1 | 561 floats (UCI HAR) | 194,848 B | `realLoadFailed` (shape mismatch) → HeuristicMotionDetector |
| scene_analyzer_v1 | 224×224×3 image | 2,674,256 B | `skippedImageModel` → HeuristicSceneDetector |

### Providers (inference_providers.dart)
```dart
final modelBundleServiceProvider = Provider<ModelBundleService>((_) => ModelBundleService());
final detectionEngineProvider = FutureProvider<ModelBundleResult>((ref) async { ... });
```

### Screen (`lib/presentation/screens/day45_model_bundle_screen.dart`)
- Route: `/model-bundle`
- Summary banner: AI count vs heuristic count + total model footprint
- Routing mode card: AI or Heuristic with icon
- Per-model `_SlotCard`: status icon, file size, active interpreter label
- `_AppSizeCard`: estimated total (~35MB Flutter+fonts + model bytes) vs 50MB target with progress bar
- "Reload Bundle" button

## Test Results
**15/15 tests passed** (`test/unit/day45_model_bundle_test.dart`)

Groups tested:
- `ModelLoadStatus` — 4 enum values
- `ModelSlotResult` — usesAi logic, statusLabel text, sizeMbLabel formatting
- `ModelBundleResult` — loadedAiCount, heuristicCount, totalSizeLabel
- `HeuristicDetectionEngine routing` — low tier → heuristic, high tier null AI → heuristic, high tier with AI → uses AI

## App Size Estimate
- Models: ~2.8 MB (0.0006 + 0.19 + 2.61 MB)
- Flutter + fonts: ~35 MB
- **Total: ~37.8 MB — within 50 MB target ✅**

## Files Changed
| File | Action |
|------|--------|
| `lib/data/services/model_bundle_service.dart` | Created |
| `lib/domain/providers/inference_providers.dart` | Updated (2 new providers) |
| `lib/presentation/screens/day45_model_bundle_screen.dart` | Created |
| `lib/presentation/navigation/app_router.dart` | Updated (route + import) |
| `lib/presentation/screens/day5_navigation_index_screen.dart` | Updated (tile added) |
| `test/unit/day45_model_bundle_test.dart` | Created |
