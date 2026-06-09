/// Day 81 — Settings state management.
///
/// Providers for user-configurable settings.  In Month 4 these are backed by
/// GET/PUT /api/v1/users/preferences/ — for now they hold in-memory defaults
/// that persist for the lifetime of the app session.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── DCS sensitivity ──────────────────────────────────────────────────────────

enum DcsSensitivity {
  low,
  medium,
  high;

  String get label {
    switch (this) {
      case DcsSensitivity.low:    return 'Low';
      case DcsSensitivity.medium: return 'Medium';
      case DcsSensitivity.high:   return 'High';
    }
  }

  String get description {
    switch (this) {
      case DcsSensitivity.low:
        return 'Fewer alerts, higher confidence threshold. Best for noisy environments.';
      case DcsSensitivity.medium:
        return 'Balanced detection. Recommended for most users.';
      case DcsSensitivity.high:
        return 'Maximum sensitivity. May generate more false alarms.';
    }
  }
}

// ─── Providers ────────────────────────────────────────────────────────────────

/// User's display name (shown in profile section).
final displayNameProvider = StateProvider<String>((ref) => 'ZapSafe User');

/// ISO-639-1 language code for the app UI language.
final selectedLanguageProvider = StateProvider<String>((ref) => 'en');

/// DCS (Distributed Classifier System) detection sensitivity.
final dcsSensitivityProvider =
    StateProvider<DcsSensitivity>((ref) => DcsSensitivity.medium);

/// Whether high-contrast accessibility mode is enabled.
final highContrastProvider = StateProvider<bool>((ref) => false);

/// Font scale factor (1.0 = default, up to 1.5).
final fontScaleProvider = StateProvider<double>((ref) => 1.0);
