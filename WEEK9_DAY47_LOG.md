# Week 9 · Day 47 — ML Pipeline Integration Tests

**Date:** 2026-05-23  
**Theme:** End-to-end integration tests across the full detection stack

---

## What Was Built

### Integration test suite (`test/unit/day47_ml_pipeline_integration_test.dart`)

**41 / 41 tests passed** across 8 groups:

| Group | Tests | What it covers |
|-------|-------|---------------|
| Scream detector end-to-end | 8 | Threat/safe fixtures → InferenceResult shape, `isConfident`, `severity`, timestampMs echo |
| Motion detector end-to-end | 5 | Impact/calm fixtures → well-formed result, threat classScore, input size, classLabels |
| Scene detector end-to-end | 4 | Dark/bright fixtures → threat classScore, `label='safe'`, expectedInputSize=8 |
| Cross-modality consistency | 4 | All 3 implement `Interpreter`, distinct modelLabels, `dispose()` safe |
| HeuristicDetectionEngine routing | 5 | Tier × null-AI combos, full inference via engine scream slot |
| DetectionSettings × engine mode | 3 | `aiEnabled=false` / `screamEnabled=false` → heuristic fallback |
| ModelBundleResult integrity | 6 | Current asset state (0 AI / 3 heuristic), size math, slot inference end-to-end |
| InferenceResult severity ladder | 6 | 0.90→high, 0.75→medium, 0.50→low, 0.20→none, 0.70/0.69 boundary |

### Key insights found during test writing

- `result.score` is the TOP class probability — not the threat score. For safe inputs, the `'normal'/'safe'` class wins with high confidence (e.g. 1.0). Tests must check `classScores['threat']` to verify absence of threat signal.
- `HeuristicMotionDetector` reads accelVar from `features[1]` — calm fixture must have low variance at index 1 to avoid varianceGate firing.
- `InferenceSeverity` maps `score >= 0.85 → high` regardless of class label.

### Screen (`lib/presentation/screens/day47_integration_tests_screen.dart`)
- Route: `/day47-integration-tests`
- Shows test pass badge (41/41), 8 group cards with test counts
- Index tile: `Icons.science_rounded`, `ZapColors.info`

## Files
| File | Action |
|------|--------|
| `test/unit/day47_ml_pipeline_integration_test.dart` | Created — 41 tests |
| `lib/presentation/screens/day47_integration_tests_screen.dart` | Created |
| `lib/presentation/navigation/app_router.dart` | Updated (route + import) |
| `lib/presentation/screens/day5_navigation_index_screen.dart` | Updated (tile added) |
