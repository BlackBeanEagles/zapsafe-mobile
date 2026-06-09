import 'package:flutter/foundation.dart';

/// Day 38 — capability bundle that the rest of the app reads to decide
/// which sensors to keep alive at the current charge level.
///
/// The three thresholds come straight from the timeline:
///   • ≤ 20% → Mode B evidence, camera off, GPS reduced
///   • ≤ 15% → Proactive Mode drops one level (e.g. CRITICAL → HIGH)
///   • ≤ 10% → VAD-only — every sensor except mic VAD goes silent;
///             SOS dispatch still works end-to-end.
enum BatteryTier {
  /// Plenty of headroom — no throttling. Used when battery > 20 % or
  /// the battery API can't be queried (e.g. host VM during tests).
  normal,

  /// ≤ 20 % — camera off, GPS reduced cadence, Mode B evidence kicks in.
  powerSaver,

  /// ≤ 15 % — Proactive Mode drops one level. Banner visible on
  /// dashboard. Cumulative w/ [powerSaver].
  proactiveDrop,

  /// ≤ 10 % — VAD-only emergency mode. Sensors disabled except for the
  /// microphone VAD; SOS escalation still fires. Cumulative w/ everything
  /// above.
  vadOnly;

  String get label => switch (this) {
        BatteryTier.normal        => 'NORMAL',
        BatteryTier.powerSaver    => 'POWER_SAVER',
        BatteryTier.proactiveDrop => 'PROACTIVE_DROP',
        BatteryTier.vadOnly       => 'VAD_ONLY',
      };

  String get description => switch (this) {
        BatteryTier.normal =>
            'Battery healthy — no sensor throttling.',
        BatteryTier.powerSaver =>
            'Camera off · GPS cadence reduced · Mode B evidence.',
        BatteryTier.proactiveDrop =>
            'Proactive Mode dropped one tier · dashboard banner shown.',
        BatteryTier.vadOnly =>
            'All sensors off except mic VAD · SOS still fully functional.',
      };
}

/// Day 38 — snapshot of the battery sub-system + the [BatteryTier] it
/// maps to. Re-emitted on every charge change or charging-state change.
@immutable
class BatteryProfile {
  /// 0–100. Negative when unknown.
  final int level;

  /// True when the device is plugged in or wirelessly charging.
  final bool isCharging;

  final BatteryTier tier;

  const BatteryProfile({
    required this.level,
    required this.isCharging,
    required this.tier,
  });

  /// Synthesised by [BatteryService] on every reading.
  factory BatteryProfile.fromLevel(int level, {bool isCharging = false}) {
    final tier = BatteryThresholds.tierForLevel(level, isCharging: isCharging);
    return BatteryProfile(
      level: level,
      isCharging: isCharging,
      tier: tier,
    );
  }

  /// Convenience snapshot used as a placeholder before the service has
  /// produced its first reading.
  static const BatteryProfile unknown = BatteryProfile(
    level: -1,
    isCharging: false,
    tier: BatteryTier.normal,
  );

  /// True when the camera should be online. Day 38 sets this false
  /// once the device is at [BatteryTier.powerSaver] or worse.
  bool get cameraEnabled => tier == BatteryTier.normal;

  /// True when GPS should fall back to a lower-cadence profile
  /// (regardless of app state). False = AppState-driven cadence wins.
  bool get gpsReduced => tier != BatteryTier.normal;

  /// True when the proactive-mode "drop one level" banner should show.
  bool get proactiveDropActive =>
      tier == BatteryTier.proactiveDrop || tier == BatteryTier.vadOnly;

  /// True when only the mic VAD should remain online.
  bool get vadOnly => tier == BatteryTier.vadOnly;

  BatteryProfile copyWith({
    int? level,
    bool? isCharging,
    BatteryTier? tier,
  }) =>
      BatteryProfile(
        level: level ?? this.level,
        isCharging: isCharging ?? this.isCharging,
        tier: tier ?? this.tier,
      );

  @override
  String toString() =>
      'BatteryProfile($level%${isCharging ? '+chg' : ''} · ${tier.label})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BatteryProfile &&
          other.level == level &&
          other.isCharging == isCharging &&
          other.tier == tier;

  @override
  int get hashCode => Object.hash(level, isCharging, tier);
}

/// Pure threshold table — lives in the model file so [BatteryProfile]
/// can synthesise itself without an import cycle on the service.
abstract final class BatteryThresholds {
  static const int powerSaverThreshold    = 20;
  static const int proactiveDropThreshold = 15;
  static const int vadOnlyThreshold       = 10;

  /// Pure tier mapping. Charging devices stay at [BatteryTier.normal]
  /// regardless of charge level — there's no point throttling sensors
  /// when the wall is supplying power.
  static BatteryTier tierForLevel(int level, {bool isCharging = false}) {
    if (level < 0)              return BatteryTier.normal; // unknown
    if (isCharging)             return BatteryTier.normal;
    if (level <= vadOnlyThreshold)       return BatteryTier.vadOnly;
    if (level <= proactiveDropThreshold) return BatteryTier.proactiveDrop;
    if (level <= powerSaverThreshold)    return BatteryTier.powerSaver;
    return BatteryTier.normal;
  }
}
