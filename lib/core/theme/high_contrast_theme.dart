import 'package:flutter/material.dart';
import 'colors.dart';
import 'typography.dart';
import 'spacing.dart';

/// High Contrast Theme — WCAG 2.1 AAA
///
/// Used by users with low vision, glare sensitivity, or who prefer maximum
/// readability. ZapSafe is a safety-critical app — every user must be able
/// to read SOS-related text reliably.
///
/// Design rules:
/// - Pure black background (#000000) for maximum OLED contrast
/// - Pure white text (#FFFFFF) — contrast ratio 21:1 (AAA needs ≥ 7:1)
/// - Yellow focus rings (#FFFF00) on every interactive element
/// - All borders 2px (vs 1px in normal mode) for visibility
/// - All touch targets remain 75×75dp minimum
class ZapHighContrastTheme {
  static ThemeData theme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: ZapColors.hcBackground,

      colorScheme: const ColorScheme.dark(
        primary: ZapColors.hcText,
        onPrimary: ZapColors.hcBackground,
        secondary: ZapColors.hcFocus, // Yellow
        onSecondary: ZapColors.hcBackground,
        tertiary: Colors.cyan,
        onTertiary: ZapColors.hcBackground,
        surface: ZapColors.hcBackground,
        onSurface: ZapColors.hcText,
        error: Color(0xFFFF6B6B), // Bright red, easier to read
        onError: ZapColors.hcBackground,
        brightness: Brightness.dark,
      ),

      // ─── Typography ─ all white, all weights bumped for legibility ───
      textTheme: TextTheme(
        displayLarge: ZapTypography.displayLarge.copyWith(
          color: ZapColors.hcText,
          fontWeight: FontWeight.w700,
        ),
        displayMedium: ZapTypography.displayMedium.copyWith(
          color: ZapColors.hcText,
          fontWeight: FontWeight.w700,
        ),
        displaySmall: ZapTypography.displaySmall.copyWith(
          color: ZapColors.hcText,
          fontWeight: FontWeight.w700,
        ),
        headlineLarge: ZapTypography.headlineLarge.copyWith(
          color: ZapColors.hcText,
          fontWeight: FontWeight.w700, // bumped from semibold
        ),
        headlineMedium: ZapTypography.headlineMedium.copyWith(
          color: ZapColors.hcText,
          fontWeight: FontWeight.w700,
        ),
        headlineSmall: ZapTypography.headlineSmall.copyWith(
          color: ZapColors.hcText,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: ZapTypography.bodyLarge.copyWith(
          color: ZapColors.hcText,
          fontWeight: FontWeight.w500, // bumped from regular
        ),
        bodyMedium: ZapTypography.bodyMedium.copyWith(
          color: ZapColors.hcText,
          fontWeight: FontWeight.w500,
        ),
        bodySmall: ZapTypography.bodySmall.copyWith(
          color: ZapColors.hcText,
          fontWeight: FontWeight.w500,
        ),
        labelLarge: ZapTypography.labelLarge.copyWith(
          color: ZapColors.hcText,
          fontWeight: FontWeight.w700,
        ),
        labelMedium: ZapTypography.labelMedium.copyWith(
          color: ZapColors.hcText,
          fontWeight: FontWeight.w700,
        ),
        labelSmall: ZapTypography.labelSmall.copyWith(
          color: ZapColors.hcText,
          fontWeight: FontWeight.w700,
        ),
      ),

      // ─── AppBar ─ pure black with white text + yellow underline ──────
      appBarTheme: AppBarTheme(
        backgroundColor: ZapColors.hcBackground,
        foregroundColor: ZapColors.hcText,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: ZapTypography.headlineLarge.copyWith(
          color: ZapColors.hcText,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: const IconThemeData(color: ZapColors.hcText, size: 28),
      ),

      // ─── Card ─ white outline 2px on black ──────────────────────────
      cardTheme: CardTheme(
        color: ZapColors.hcBackground,
        elevation: 0,
        margin: const EdgeInsets.all(ZapSpacing.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          side: const BorderSide(color: ZapColors.hcText, width: 2), // 2px!
        ),
      ),

      // ─── Buttons ─ white fill, black text, yellow focus ring ────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ZapColors.hcText,
          foregroundColor: ZapColors.hcBackground,
          padding: const EdgeInsets.symmetric(
            horizontal: ZapSpacing.lg,
            vertical: ZapSpacing.md,
          ),
          minimumSize: const Size.fromHeight(ZapSpacing.minTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            side: const BorderSide(color: ZapColors.hcFocus, width: 2),
          ),
          textStyle: ZapTypography.labelLarge.copyWith(
            fontWeight: FontWeight.w700,
            color: ZapColors.hcBackground,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ZapColors.hcText,
          padding: const EdgeInsets.symmetric(
            horizontal: ZapSpacing.lg,
            vertical: ZapSpacing.md,
          ),
          minimumSize: const Size.fromHeight(ZapSpacing.minTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
          ),
          side: const BorderSide(color: ZapColors.hcText, width: 3), // 3px!
          textStyle: ZapTypography.labelLarge.copyWith(fontWeight: FontWeight.w700),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ZapColors.hcFocus, // yellow for text-only links
          padding: const EdgeInsets.symmetric(
            horizontal: ZapSpacing.md,
            vertical: ZapSpacing.sm,
          ),
          minimumSize: const Size(ZapSpacing.minTouchTarget, ZapSpacing.minTouchTarget),
          textStyle: ZapTypography.labelLarge.copyWith(
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.underline, // always underline links in HC
          ),
        ),
      ),

      // ─── Inputs ─ white 2px border, yellow focused border ───────────
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: ZapSpacing.lg,
          vertical: ZapSpacing.lg,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          borderSide: const BorderSide(color: ZapColors.hcText, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          borderSide: const BorderSide(color: ZapColors.hcText, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          borderSide: const BorderSide(color: ZapColors.hcFocus, width: 3),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 3),
        ),
        hintStyle: ZapTypography.bodyMedium.copyWith(
          color: ZapColors.hcText.withOpacity(0.7),
          fontWeight: FontWeight.w500,
        ),
        labelStyle: ZapTypography.labelLarge.copyWith(
          color: ZapColors.hcText,
          fontWeight: FontWeight.w700,
        ),
        errorStyle: ZapTypography.bodySmall.copyWith(
          color: const Color(0xFFFF6B6B),
          fontWeight: FontWeight.w700,
        ),
      ),

      // ─── FAB ─ yellow, very visible ─────────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: ZapColors.hcFocus,
        foregroundColor: ZapColors.hcBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          side: const BorderSide(color: ZapColors.hcText, width: 2),
        ),
      ),

      // ─── Nav bar ─ pure black, yellow selected, white unselected ────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: ZapColors.hcBackground,
        iconTheme: MaterialStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(MaterialState.selected)
                ? ZapColors.hcFocus
                : ZapColors.hcText,
            size: 28,
          );
        }),
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          return ZapTypography.labelSmall.copyWith(
            color: states.contains(MaterialState.selected)
                ? ZapColors.hcFocus
                : ZapColors.hcText,
            fontWeight: FontWeight.w700,
          );
        }),
        height: ZapSpacing.navItemHeight,
      ),

      // ─── Dialog ─ black bg, white border 2px ────────────────────────
      dialogTheme: DialogTheme(
        backgroundColor: ZapColors.hcBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          side: const BorderSide(color: ZapColors.hcText, width: 2),
        ),
        titleTextStyle: ZapTypography.headlineSmall.copyWith(
          color: ZapColors.hcText,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: ZapTypography.bodyMedium.copyWith(
          color: ZapColors.hcText,
          fontWeight: FontWeight.w500,
        ),
      ),

      // ─── Snackbar ─ yellow on black ─────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ZapColors.hcBackground,
        contentTextStyle: ZapTypography.bodyMedium.copyWith(
          color: ZapColors.hcText,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZapSpacing.md),
          side: const BorderSide(color: ZapColors.hcFocus, width: 2),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // ─── Switch ─ yellow active, white inactive ─────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          return states.contains(MaterialState.selected)
              ? ZapColors.hcFocus
              : ZapColors.hcText;
        }),
        trackColor: MaterialStateProperty.all(ZapColors.hcBackground),
        trackOutlineColor: MaterialStateProperty.all(ZapColors.hcText),
      ),

      // ─── Checkbox ─ white box, yellow checkmark ─────────────────────
      checkboxTheme: CheckboxThemeData(
        side: const BorderSide(color: ZapColors.hcText, width: 2),
        fillColor: MaterialStateProperty.resolveWith((states) {
          return states.contains(MaterialState.selected)
              ? ZapColors.hcFocus
              : Colors.transparent;
        }),
        checkColor: MaterialStateProperty.all(ZapColors.hcBackground),
      ),

      // ─── Chip ─ white border on black, yellow when selected ─────────
      chipTheme: ChipThemeData(
        backgroundColor: ZapColors.hcBackground,
        selectedColor: ZapColors.hcFocus,
        labelStyle: ZapTypography.labelMedium.copyWith(
          color: ZapColors.hcText,
          fontWeight: FontWeight.w700,
        ),
        secondaryLabelStyle: ZapTypography.labelMedium.copyWith(
          color: ZapColors.hcBackground,
          fontWeight: FontWeight.w700,
        ),
        side: const BorderSide(color: ZapColors.hcText, width: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZapSpacing.radiusPill),
        ),
        padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.md, vertical: ZapSpacing.sm),
      ),

      // ─── Divider ─ white, 2px ───────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: ZapColors.hcText,
        thickness: 2,
        space: ZapSpacing.lg,
      ),

      // ─── Icon ─ white, 28px (bigger than default 24) ────────────────
      iconTheme: const IconThemeData(
        color: ZapColors.hcText,
        size: 28,
      ),
    );
  }
}
