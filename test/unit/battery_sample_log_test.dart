// Day 328 — BatterySampleLog tests.

import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/data/models/battery_profile.dart';
import 'package:zapsafe_mobile/domain/battery/battery_sample_log.dart';

void main() {
  test('record() appends a sample with the real profile fields', () {
    final log = BatterySampleLog();
    log.record(BatteryProfile.fromLevel(45, isCharging: false));
    expect(log.samples, hasLength(1));
    expect(log.samples.single.level, 45);
    expect(log.samples.single.isCharging, isFalse);
    expect(log.samples.single.tier, BatteryTier.normal);
  });

  test('prunes samples older than the 1-hour retention window', () {
    final log = BatterySampleLog();
    var now = DateTime(2026, 1, 1, 12, 0, 0);
    log.nowOverride = () => now;

    log.record(BatteryProfile.fromLevel(50)); // t=12:00
    now = now.add(const Duration(minutes: 90)); // t=13:30, > 1h later
    log.record(BatteryProfile.fromLevel(40)); // t=13:30

    expect(log.samples, hasLength(1));
    expect(log.samples.single.level, 40);
  });

  test('exportJson produces valid JSON with real field names', () {
    final log = BatterySampleLog();
    log.record(BatteryProfile.fromLevel(18)); // powerSaver tier
    final json = log.exportJson();
    expect(json, contains('"level": 18'));
    expect(json, contains('"tier": "POWER_SAVER"'));
    expect(json, contains('"is_charging"'));
  });

  test('clear() empties the log', () {
    final log = BatterySampleLog();
    log.record(BatteryProfile.fromLevel(50));
    log.clear();
    expect(log.samples, isEmpty);
  });

  test('maxSamples caps the log even within the retention window', () {
    final log = BatterySampleLog();
    var now = DateTime(2026, 1, 1, 12, 0, 0);
    log.nowOverride = () => now;
    for (var i = 0; i < BatterySampleLog.maxSamples + 10; i++) {
      log.record(BatteryProfile.fromLevel(50));
      now = now.add(const Duration(milliseconds: 1));
    }
    expect(log.samples.length, BatterySampleLog.maxSamples);
  });
}
