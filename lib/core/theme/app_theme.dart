import 'package:flutter/material.dart';
import 'colors.dart';
import 'typography.dart';
import 'spacing.dart';
import 'high_contrast_theme.dart';

/// ZapSafe Main Theme (Dark Mode)
///
/// Day 3 — Wires up the full Material 3 ThemeData with:
/// - Dark-first design (OLED-optimized)
/// - All text styles from ZapTypography
/// - WCAG 2.1 AAA: every interactive element ≥ 75×75dp touch target
/// - Refined components: cards, buttons, inputs, switches, chips, dialogs
///
/// To use High Contrast Mode, switch via [highContrastTheme()] (see
/// `high_contrast_theme.dart`).
class ZapTheme {
  // Re-export for convenience
  static ThemeData highContrastTheme() => ZapHighContrastTheme.theme();

  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: ZapColors.bgPrimary,

      // ─── Color scheme ────────────────────────────────────────────────
      colorScheme: const ColorScheme.dark(
        primary: ZapColors.danger,
        onPrimary: Colors.white,
        secondary: ZapColors.safe,
        onSecondary: ZapColors.textInverse,
        tertiary: ZapColors.info,
        onTertiary: ZapColors.textInverse,
        surface: ZapColors.bgCard,
        onSurface: ZapColors.textPrimary,
        error: ZapColors.error,
        onError: Colors.white,
        outline: ZapColors.border,
        brightness: Brightness.dark,
      ),

      // ─── Text theme ──────────────────────────────────────────────────
      textTheme: TextTheme(
        displayLarge: ZapTypography.displayLarge.copyWith(color: ZapColors.textPrimary),
        displayMedium: ZapTypography.displayMedium.copyWith(color: ZapColors.textPrimary),
        displaySmall: ZapTypography.displaySmall.copyWith(color: ZapColors.textPrimary),
        headlineLarge: ZapTypography.headlineLarge.copyWith(color: ZapColors.textPrimary),
        headlineMedium: ZapTypography.headlineMedium.copyWith(color: ZapColors.textPrimary),
        headlineSmall: ZapTypography.headlineSmall.copyWith(color: ZapColors.textPrimary),
        bodyLarge: ZapTypography.bodyLarge.copyWith(color: ZapColors.textPrimary),
        bodyMedium: ZapTypography.bodyMedium.copyWith(color: ZapColors.textPrimary),
        bodySmall: ZapTypography.bodySmall.copyWith(color: ZapColors.textSecondary),
        labelLarge: ZapTypography.labelLarge.copyWith(color: ZapColors.textPrimary),
        labelMedium: ZapTypography.labelMedium.copyWith(color: ZapColors.textSecondary),
        labelSmall: ZapTypography.labelSmall.copyWith(color: ZapColors.textMuted),
      ),

      // ─── AppBar ──────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: ZapColors.bgPrimary,
        foregroundColor: ZapColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: ZapTypography.headlineLarge.copyWith(color: ZapColors.textPrimary),
        iconTheme: const IconThemeData(color: ZapColors.textPrimary, size: 24),
      ),

      // ─── Card ────────────────────────────────────────────────────────
      cardTheme: CardTheme(
        color: ZapColors.bgCard,
        elevation: 0,
        margin: const EdgeInsets.all(ZapSpacing.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          side: const BorderSide(color: ZapColors.border, width: 1),
        ),
      ),

      // ─── Elevated Button (primary danger button) ─────────────────────
      // WCAG AAA: minimum 75×75dp tap area
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ZapColors.danger,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: ZapSpacing.xxl,
            vertical: ZapSpacing.lg,
          ),
          minimumSize: const Size(ZapSpacing.minTouchTarget, ZapSpacing.minTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
          ),
          textStyle: ZapTypography.labelLarge,
          elevation: 0,
        ),
      ),

      // ─── Outlined Button ─────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ZapColors.danger,
          padding: const EdgeInsets.symmetric(
            horizontal: ZapSpacing.xxl,
            vertical: ZapSpacing.lg,
          ),
          minimumSize: const Size(ZapSpacing.minTouchTarget, ZapSpacing.minTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
          ),
          side: const BorderSide(color: ZapColors.danger, width: 2),
          textStyle: ZapTypography.labelLarge,
        ),
      ),

      // ─── Text Button ─────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ZapColors.info,
          padding: const EdgeInsets.symmetric(
            horizontal: ZapSpacing.lg,
            vertical: ZapSpacing.md,
          ),
          minimumSize: const Size(ZapSpacing.minTouchTarget, ZapSpacing.minTouchTarget),
          textStyle: ZapTypography.labelLarge,
        ),
      ),

      // ─── Input fields ────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ZapColors.bgCard,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: ZapSpacing.lg,
          vertical: ZapSpacing.xl, // 20px = matches 75dp total height with text
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          borderSide: const BorderSide(color: ZapColors.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          borderSide: const BorderSide(color: ZapColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          borderSide: const BorderSide(color: ZapColors.info, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          borderSide: const BorderSide(color: ZapColors.error, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          borderSide: const BorderSide(color: ZapColors.error, width: 2),
        ),
        hintStyle: ZapTypography.bodyMedium.copyWith(color: ZapColors.textSecondary),
        labelStyle: ZapTypography.labelLarge.copyWith(color: ZapColors.textSecondary),
        errorStyle: ZapTypography.bodySmall.copyWith(color: ZapColors.error),
      ),

      // ─── FAB ─────────────────────────────────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: ZapColors.danger,
        foregroundColor: Colors.white,
        sizeConstraints: const BoxConstraints.tightFor(
          width: ZapSpacing.sosButtonDiameter,
          height: ZapSpacing.sosButtonDiameter,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
        ),
      ),

      // ─── Bottom Navigation ───────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: ZapColors.bgCard,
        indicatorColor: ZapColors.danger.withOpacity(0.15),
        iconTheme: MaterialStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(MaterialState.selected)
                ? ZapColors.danger
                : ZapColors.textSecondary,
            size: 24,
          );
        }),
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          return ZapTypography.labelSmall.copyWith(
            color: states.contains(MaterialState.selected)
                ? ZapColors.danger
                : ZapColors.textSecondary,
          );
        }),
        height: ZapSpacing.navItemHeight,
      ),

      // ─── Dialog ──────────────────────────────────────────────────────
      dialogTheme: DialogTheme(
        backgroundColor: ZapColors.bgCard,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          side: const BorderSide(color: ZapColors.border, width: 1),
        ),
        titleTextStyle: ZapTypography.headlineSmall.copyWith(color: ZapColors.textPrimary),
        contentTextStyle: ZapTypography.bodyMedium.copyWith(color: ZapColors.textPrimary),
      ),

      // ─── Snackbar ────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ZapColors.bgCard,
        contentTextStyle: ZapTypography.bodyMedium.copyWith(color: ZapColors.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZapSpacing.md),
          side: const BorderSide(color: ZapColors.border, width: 1),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // ─── Switch ──────────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          return states.contains(MaterialState.selected)
              ? Colors.white
              : ZapColors.textSecondary;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          return states.contains(MaterialState.selected)
              ? ZapColors.safe
              : ZapColors.bgSurface;
        }),
      ),

      // ─── Checkbox ────────────────────────────────────────────────────
      checkboxTheme: CheckboxThemeData(
        side: const BorderSide(color: ZapColors.border, width: 2),
        fillColor: MaterialStateProperty.resolveWith((states) {
          return states.contains(MaterialState.selected)
              ? ZapColors.safe
              : Colors.transparent;
        }),
        checkColor: MaterialStateProperty.all(Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZapSpacing.xs),
        ),
      ),

      // ─── Chip ────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: ZapColors.bgCard,
        selectedColor: ZapColors.danger.withOpacity(0.2),
        labelStyle: ZapTypography.labelMedium.copyWith(color: ZapColors.textPrimary),
        secondaryLabelStyle: ZapTypography.labelMedium.copyWith(color: ZapColors.danger),
        side: const BorderSide(color: ZapColors.border, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZapSpacing.radiusPill),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: ZapSpacing.md,
          vertical: ZapSpacing.sm,
        ),
      ),

      // ─── Divider ─────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: ZapColors.border,
        thickness: 1,
        space: ZapSpacing.lg,
      ),

      // ─── Icon ────────────────────────────────────────────────────────
      iconTheme: const IconThemeData(
        color: ZapColors.textPrimary,
        size: 24,
      ),

      // ─── Progress indicator ──────────────────────────────────────────
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: ZapColors.danger,
        linearTrackColor: ZapColors.bgSurface,
        circularTrackColor: ZapColors.bgSurface,
      ),

      // ─── Slider ──────────────────────────────────────────────────────
      sliderTheme: const SliderThemeData(
        activeTrackColor: ZapColors.danger,
        inactiveTrackColor: ZapColors.bgSurface,
        thumbColor: Colors.white,
        overlayColor: Color(0x22E63946),
      ),

      // ─── Tab bar ─────────────────────────────────────────────────────
      tabBarTheme: const TabBarTheme(
        labelColor: ZapColors.danger,
        unselectedLabelColor: ZapColors.textSecondary,
        indicatorColor: ZapColors.danger,
        labelStyle: ZapTypography.labelLarge,
        unselectedLabelStyle: ZapTypography.labelLarge,
      ),
    );
  }
}
