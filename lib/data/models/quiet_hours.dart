import 'package:flutter/foundation.dart';

/// Window during which non-critical notifications (currently
/// `CHECK_IN_REMINDER`) are suppressed. Critical pushes (`SOS_ALERT`) always
/// fire — quiet hours never block safety alerts.
///
/// Wrapping the hours window is supported: e.g. 22:00 → 07:00 spans midnight.
@immutable
class QuietHoursConfig {
  /// When false, no notifications are ever suppressed.
  final bool enabled;

  /// Hour of day (0-23) when quiet hours start.
  final int startHour;

  /// Hour of day (0-23) when quiet hours end. May be less than [startHour] —
  /// the window wraps midnight when so.
  final int endHour;

  const QuietHoursConfig({
    this.enabled = true,
    this.startHour = 22,
    this.endHour = 7,
  })  : assert(startHour >= 0 && startHour < 24),
        assert(endHour >= 0 && endHour < 24);

  /// Default: 22:00 → 07:00, enabled.
  static const defaults = QuietHoursConfig();

  /// True when [now] falls inside the configured window.
  /// Returns false when [enabled] is false.
  bool covers(DateTime now) {
    if (!enabled) return false;
    final h = now.hour;
    if (startHour == endHour) return false;
    if (startHour < endHour) {
      // Same-day window, e.g. 13:00 → 17:00.
      return h >= startHour && h < endHour;
    }
    // Wrapping window, e.g. 22:00 → 07:00.
    return h >= startHour || h < endHour;
  }

  /// Human-readable rendering, e.g. "10pm → 7am".
  String get prettyRange {
    String fmt(int h) {
      if (h == 0) return '12am';
      if (h < 12) return '${h}am';
      if (h == 12) return '12pm';
      return '${h - 12}pm';
    }

    return '${fmt(startHour)} → ${fmt(endHour)}';
  }

  QuietHoursConfig copyWith({bool? enabled, int? startHour, int? endHour}) =>
      QuietHoursConfig(
        enabled: enabled ?? this.enabled,
        startHour: startHour ?? this.startHour,
        endHour: endHour ?? this.endHour,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QuietHoursConfig &&
          enabled == other.enabled &&
          startHour == other.startHour &&
          endHour == other.endHour);

  @override
  int get hashCode => Object.hash(enabled, startHour, endHour);
}
