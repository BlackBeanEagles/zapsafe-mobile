import 'package:flutter/material.dart';

class ZapTypography {
  // Clash Display - headings, mode labels, score numbers (bold, large)
  static const displayLarge = TextStyle(
    fontFamily: 'ClashDisplay',
    fontSize: 48,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.2,
  );

  static const displayMedium = TextStyle(
    fontFamily: 'ClashDisplay',
    fontSize: 36,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.25,
    height: 1.3,
  );

  static const displaySmall = TextStyle(
    fontFamily: 'ClashDisplay',
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    height: 1.35,
  );

  // Syne - body, labels, descriptions (medium weight)
  static const headlineLarge = TextStyle(
    fontFamily: 'Syne',
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.4,
  );

  static const headlineMedium = TextStyle(
    fontFamily: 'Syne',
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.4,
  );

  static const headlineSmall = TextStyle(
    fontFamily: 'Syne',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.5,
  );

  static const bodyLarge = TextStyle(
    fontFamily: 'Syne',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
    height: 1.5,
  );

  static const bodyMedium = TextStyle(
    fontFamily: 'Syne',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
    height: 1.5,
  );

  static const bodySmall = TextStyle(
    fontFamily: 'Syne',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    height: 1.5,
  );

  static const labelLarge = TextStyle(
    fontFamily: 'Syne',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.43,
  );

  static const labelMedium = TextStyle(
    fontFamily: 'Syne',
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.33,
  );

  static const labelSmall = TextStyle(
    fontFamily: 'Syne',
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.45,
  );

  // IBM Plex Mono - hashes, timestamps, technical info
  static const monoLarge = TextStyle(
    fontFamily: 'IBMPlexMono',
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.5,
  );

  static const monoMedium = TextStyle(
    fontFamily: 'IBMPlexMono',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.5,
  );

  static const monoSmall = TextStyle(
    fontFamily: 'IBMPlexMono',
    fontSize: 11,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.45,
  );
}
