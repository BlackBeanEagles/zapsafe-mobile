/// Day 97 — Accessibility Settings state.
///
/// Fully self-contained mock Riverpod state — no system-level bindings.
/// Covers font scale (5 steps), colour modes (5 with colour-blind filters),
/// reduce motion, animation speed, haptics, screen-reader optimisation,
/// and SOS ergonomics (large button + simplified panic mode).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Font scale ───────────────────────────────────────────────────────────────

enum FontScale { small, normal, large, xLarge, xxLarge }

extension FontScaleX on FontScale {
  String get description {
    switch (this) {
      case FontScale.small:   return 'Small (85%)';
      case FontScale.normal:  return 'Normal (100%)';
      case FontScale.large:   return 'Large (115%)';
      case FontScale.xLarge:  return 'X-Large (130%)';
      case FontScale.xxLarge: return 'XX-Large (150%)';
    }
  }

  double get scale {
    switch (this) {
      case FontScale.small:   return 0.85;
      case FontScale.normal:  return 1.0;
      case FontScale.large:   return 1.15;
      case FontScale.xLarge:  return 1.3;
      case FontScale.xxLarge: return 1.5;
    }
  }

  /// Visual size of the "A" glyph in the font-size selector.
  double get selectorSize {
    switch (this) {
      case FontScale.small:   return 13;
      case FontScale.normal:  return 17;
      case FontScale.large:   return 21;
      case FontScale.xLarge:  return 25;
      case FontScale.xxLarge: return 29;
    }
  }
}

// ─── Color mode ───────────────────────────────────────────────────────────────

enum ColorMode { normal, highContrast, deuteranopia, protanopia, tritanopia }

extension ColorModeX on ColorMode {
  String get label {
    switch (this) {
      case ColorMode.normal:       return 'Normal';
      case ColorMode.highContrast: return 'High Contrast';
      case ColorMode.deuteranopia: return 'Deuteranopia';
      case ColorMode.protanopia:   return 'Protanopia';
      case ColorMode.tritanopia:   return 'Tritanopia';
    }
  }

  String get description {
    switch (this) {
      case ColorMode.normal:       return 'Default app colours';
      case ColorMode.highContrast: return 'WCAG AAA · 21:1 contrast';
      case ColorMode.deuteranopia: return 'Green-blind safe';
      case ColorMode.protanopia:   return 'Red-blind safe';
      case ColorMode.tritanopia:   return 'Blue-blind safe';
    }
  }

  /// Colour used for "safe / positive" indicators in this mode.
  Color get safeColor {
    switch (this) {
      case ColorMode.normal:       return const Color(0xFF22C55E);
      case ColorMode.highContrast: return const Color(0xFFFFFFFF);
      case ColorMode.deuteranopia: return const Color(0xFF56B4E9); // sky-blue
      case ColorMode.protanopia:   return const Color(0xFF56B4E9);
      case ColorMode.tritanopia:   return const Color(0xFFF0E442); // yellow
    }
  }

  /// Colour used for "danger / alert" indicators in this mode.
  Color get dangerColor {
    switch (this) {
      case ColorMode.normal:       return const Color(0xFFEF4444);
      case ColorMode.highContrast: return const Color(0xFFFF6B6B);
      case ColorMode.deuteranopia: return const Color(0xFFD55E00); // orange
      case ColorMode.protanopia:   return const Color(0xFF0072B2); // blue
      case ColorMode.tritanopia:   return const Color(0xFFCC79A7); // pink
    }
  }
}

// ─── Animation speed ─────────────────────────────────────────────────────────

enum AnimationSpeed { none, reduced, normal }

extension AnimationSpeedX on AnimationSpeed {
  String get label {
    switch (this) {
      case AnimationSpeed.none:    return 'Off';
      case AnimationSpeed.reduced: return 'Reduced';
      case AnimationSpeed.normal:  return 'Normal';
    }
  }
}

// ─── State ───────────────────────────────────────────────────────────────────

class AccessibilityState {
  const AccessibilityState({
    required this.fontScale,
    required this.boldText,
    required this.wideLetterSpacing,
    required this.colorMode,
    required this.reduceTransparency,
    required this.reduceMotion,
    required this.animationSpeed,
    required this.hapticFeedback,
    required this.soundEffects,
    required this.screenReaderOptimized,
    required this.largeSOSButton,
    required this.simplifiedPanicMode,
  });

  final FontScale      fontScale;
  final bool           boldText;
  final bool           wideLetterSpacing;
  final ColorMode      colorMode;
  final bool           reduceTransparency;
  final bool           reduceMotion;
  final AnimationSpeed animationSpeed;
  final bool           hapticFeedback;
  final bool           soundEffects;
  final bool           screenReaderOptimized;
  final bool           largeSOSButton;
  final bool           simplifiedPanicMode;

  bool get isDefault =>
      fontScale      == FontScale.normal      &&
      !boldText                               &&
      !wideLetterSpacing                      &&
      colorMode      == ColorMode.normal      &&
      !reduceTransparency                     &&
      !reduceMotion                           &&
      animationSpeed == AnimationSpeed.normal &&
      hapticFeedback                          &&
      soundEffects                            &&
      !screenReaderOptimized                  &&
      !largeSOSButton                         &&
      !simplifiedPanicMode;

  AccessibilityState copyWith({
    FontScale?      fontScale,
    bool?           boldText,
    bool?           wideLetterSpacing,
    ColorMode?      colorMode,
    bool?           reduceTransparency,
    bool?           reduceMotion,
    AnimationSpeed? animationSpeed,
    bool?           hapticFeedback,
    bool?           soundEffects,
    bool?           screenReaderOptimized,
    bool?           largeSOSButton,
    bool?           simplifiedPanicMode,
  }) {
    return AccessibilityState(
      fontScale:             fontScale             ?? this.fontScale,
      boldText:              boldText              ?? this.boldText,
      wideLetterSpacing:     wideLetterSpacing     ?? this.wideLetterSpacing,
      colorMode:             colorMode             ?? this.colorMode,
      reduceTransparency:    reduceTransparency    ?? this.reduceTransparency,
      reduceMotion:          reduceMotion          ?? this.reduceMotion,
      animationSpeed:        animationSpeed        ?? this.animationSpeed,
      hapticFeedback:        hapticFeedback        ?? this.hapticFeedback,
      soundEffects:          soundEffects          ?? this.soundEffects,
      screenReaderOptimized: screenReaderOptimized ?? this.screenReaderOptimized,
      largeSOSButton:        largeSOSButton        ?? this.largeSOSButton,
      simplifiedPanicMode:   simplifiedPanicMode   ?? this.simplifiedPanicMode,
    );
  }
}

// ─── Defaults ────────────────────────────────────────────────────────────────

const _kDefault = AccessibilityState(
  fontScale:             FontScale.normal,
  boldText:              false,
  wideLetterSpacing:     false,
  colorMode:             ColorMode.normal,
  reduceTransparency:    false,
  reduceMotion:          false,
  animationSpeed:        AnimationSpeed.normal,
  hapticFeedback:        true,
  soundEffects:          true,
  screenReaderOptimized: false,
  largeSOSButton:        false,
  simplifiedPanicMode:   false,
);

// ─── Notifier ────────────────────────────────────────────────────────────────

class AccessibilityNotifier extends StateNotifier<AccessibilityState> {
  AccessibilityNotifier() : super(_kDefault);

  void setFontScale(FontScale v) =>
      state = state.copyWith(fontScale: v);

  void toggleBoldText() =>
      state = state.copyWith(boldText: !state.boldText);

  void toggleWideLetterSpacing() =>
      state = state.copyWith(wideLetterSpacing: !state.wideLetterSpacing);

  void setColorMode(ColorMode v) =>
      state = state.copyWith(colorMode: v);

  void toggleReduceTransparency() =>
      state = state.copyWith(reduceTransparency: !state.reduceTransparency);

  void toggleReduceMotion() =>
      state = state.copyWith(reduceMotion: !state.reduceMotion);

  void setAnimationSpeed(AnimationSpeed v) =>
      state = state.copyWith(animationSpeed: v);

  void toggleHapticFeedback() =>
      state = state.copyWith(hapticFeedback: !state.hapticFeedback);

  void toggleSoundEffects() =>
      state = state.copyWith(soundEffects: !state.soundEffects);

  void toggleScreenReaderOptimized() =>
      state = state.copyWith(
          screenReaderOptimized: !state.screenReaderOptimized);

  void toggleLargeSOSButton() =>
      state = state.copyWith(largeSOSButton: !state.largeSOSButton);

  void toggleSimplifiedPanicMode() =>
      state = state.copyWith(simplifiedPanicMode: !state.simplifiedPanicMode);

  void resetToDefaults() => state = _kDefault;
}

// ─── Provider ────────────────────────────────────────────────────────────────

final accessibilityProvider =
    StateNotifierProvider<AccessibilityNotifier, AccessibilityState>(
  (ref) => AccessibilityNotifier(),
);
