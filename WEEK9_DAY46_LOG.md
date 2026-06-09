# Week 9 · Day 46 — Detection Settings

**Date:** 2026-05-23  
**Theme:** Per-model AI toggle + phone capability display, persisted to SharedPreferences

---

## What Was Built

### DetectionSettings model + provider (`lib/domain/providers/detection_settings_provider.dart`)
- `DetectionSettings`: immutable value object with 5 flags — `aiEnabled` (master), `screamEnabled`, `motionEnabled`, `sceneEnabled`, `heuristicFallback` (always true, shown for transparency)
- `copyWith` + `==` + `hashCode`
- `DetectionSettingsNotifier`: hydrates from SharedPreferences on init, persists on every toggle
- `resetToDefaults()`: restores all flags to true and clears SharedPreferences keys
- `detectionSettingsProvider`: `StateNotifierProvider<DetectionSettingsNotifier, DetectionSettings>`

### Screen (`lib/presentation/screens/day46_detection_settings_screen.dart`)
- Route: `/detection-settings`
- **AI DETECTION** section: master Switch — flips all 3 model cards to 45% opacity when off
- **DETECTION MODELS** section: per-model toggle cards (Scream/Motion/Scene) with icon, description, disabled hint
- **PHONE CAPABILITY** section: shows cached `PhoneCapabilityTier` with color coding (green/orange/red), "Re-Test Phone" button triggers `PhoneCapabilityDetector().detect(forceReprobe: true)`
- **HEURISTIC FALLBACK** info card: explains it's always active, cannot be disabled
- **Reset to Defaults** button

### Fixes applied
- Typography tokens corrected: `labelMd/Sm/Lg` → `labelMedium/Small/Large`, `bodySm` → `bodySmall`
- Color fixes: `ZapColors.primary` → `ZapColors.safe`, `ZapColors.textTertiary` → `ZapColors.textMuted`
- Button variant fixes: `ghost` → `text`, `secondary` → `outlined`
- `ZapBadge`: `color:` → `intent: ZapBadgeIntent.info`

## Test Results
**11/11 tests passed** (`test/unit/day46_detection_settings_test.dart`)

Groups tested:
- `DetectionSettings defaults` — all 5 flags true
- `DetectionSettings.copyWith` — individual flag flips, all-false
- `DetectionSettings equality` — `==` and `hashCode`
- `heuristicFallback invariant` — always true, preserved by `copyWith`

## Files
| File | Action |
|------|--------|
| `lib/domain/providers/detection_settings_provider.dart` | Pre-existed, verified correct |
| `lib/presentation/screens/day46_detection_settings_screen.dart` | Pre-existed, fixed 7 type errors |
| `test/unit/day46_detection_settings_test.dart` | Created |
| Route `/detection-settings` in `app_router.dart` | Pre-wired |
| Day 46 tile in `day5_navigation_index_screen.dart` | Pre-wired |
