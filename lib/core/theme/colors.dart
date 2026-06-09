import 'package:flutter/material.dart';

class ZapColors {
  // Primary brand colors
  static const danger = Color(0xFFE63946); // Red — SOS, critical
  static const safe = Color(0xFF06D6A0); // Green — safe state
  static const info = Color(0xFF4CC9F0); // Blue — info
  static const warning = Color(0xFFF4A261); // Orange — elevated

  // Background colors (OLED-optimized dark)
  static const bgPrimary = Color(0xFF07070E); // Near-black — main bg
  static const bgCard = Color(0xFF0D0D16); // Card bg
  static const bgSurface = Color(0xFF16161F); // Surface bg
  static const bgElevated = Color(0xFF1D1D2B); // Elevated surface

  // Text colors
  static const textPrimary = Color(0xFFE0E0EE); // Primary text
  static const textSecondary = Color(0xFF6E6E82); // Secondary text, hints
  static const textMuted = Color(0xFF4A4A5E); // Muted text
  static const textInverse = Color(0xFF07070E); // Text on light backgrounds

  // High Contrast Mode
  static const hcBackground = Color(0xFF000000); // Pure black
  static const hcText = Color(0xFFFFFFFF); // Pure white
  static const hcFocus = Color(0xFFFFFF00); // Yellow border on focus

  // Status colors
  static const success = safe;
  static const error = danger;
  static const warning2 = warning;

  // Semantic colors
  static const critical = danger;
  static const alert = warning;
  static const neutral = Color(0xFF8F8FA3);
  static const disabled = Color(0xFF3A3A47);

  // Border & divider
  static const border = Color(0xFF2A2A35);
  static const divider = Color(0xFF1D1D2B);

  // Overlay
  static const overlay = Color(0x00000080); // Semi-transparent black
  static const scrim = Color(0xFF000000);
}
