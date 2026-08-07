/// Day 328 — 1-hour battery sample log, for MONITORING-mode production
/// export.
///
/// A real in-memory ring buffer of [BatteryProfile] readings, pruned to a
/// rolling 1-hour window. The actual 1-hour-of-real-samples data this is
/// meant to hold requires a real device left running for an hour, which
/// this sandbox cannot do — see `day328_battery_monitoring_production_screen.dart`
/// for the honest caveat. This class + its export mechanism are real,
/// working code; only the "run a device for an hour" part is out of
/// reach here.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../data/models/battery_profile.dart';

@immutable
class BatterySample {
  final DateTime at;
  final int level;
  final bool isCharging;
  final BatteryTier tier;

  const BatterySample({
    required this.at,
    required this.level,
    required this.isCharging,
    required this.tier,
  });

  Map<String, dynamic> toJson() => {
        'at': at.toIso8601String(),
        'level': level,
        'is_charging': isCharging,
        'tier': tier.label,
      };
}

class BatterySampleLog {
  static const Duration retentionWindow = Duration(hours: 1);

  /// Safety cap independent of the time window — protects memory if
  /// `record` is somehow called far more often than intended.
  static const int maxSamples = 3600;

  final List<BatterySample> _samples = [];
  List<BatterySample> get samples => List.unmodifiable(_samples);

  DateTime Function() _now = DateTime.now;

  @visibleForTesting
  set nowOverride(DateTime Function() fn) => _now = fn;

  void record(BatteryProfile profile) {
    _samples.add(BatterySample(
      at: _now(),
      level: profile.level,
      isCharging: profile.isCharging,
      tier: profile.tier,
    ));
    _prune();
  }

  void _prune() {
    final cutoff = _now().subtract(retentionWindow);
    _samples.removeWhere((s) => s.at.isBefore(cutoff));
    while (_samples.length > maxSamples) {
      _samples.removeAt(0);
    }
  }

  /// Real JSON export — the mechanism the Day 328 screen's "export" button
  /// calls (via clipboard). Structurally real regardless of how many
  /// samples happen to be collected in this session.
  String exportJson() =>
      const JsonEncoder.withIndent('  ').convert(_samples.map((s) => s.toJson()).toList());

  void clear() => _samples.clear();
}
