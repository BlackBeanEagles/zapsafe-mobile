// Day 38 — Battery threshold tier mapping + service.

import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/data/models/battery_profile.dart';
import 'package:zapsafe_mobile/data/services/battery_service.dart';

void main() {
  group('BatteryThresholds.tierForLevel', () {
    test('> 20% → normal', () {
      expect(BatteryThresholds.tierForLevel(100), BatteryTier.normal);
      expect(BatteryThresholds.tierForLevel(50),  BatteryTier.normal);
      expect(BatteryThresholds.tierForLevel(21),  BatteryTier.normal);
    });

    test('20% → powerSaver (inclusive)', () {
      expect(BatteryThresholds.tierForLevel(20), BatteryTier.powerSaver);
      expect(BatteryThresholds.tierForLevel(16), BatteryTier.powerSaver);
    });

    test('15% → proactiveDrop (inclusive)', () {
      expect(BatteryThresholds.tierForLevel(15), BatteryTier.proactiveDrop);
      expect(BatteryThresholds.tierForLevel(11), BatteryTier.proactiveDrop);
    });

    test('10% → vadOnly (inclusive)', () {
      expect(BatteryThresholds.tierForLevel(10), BatteryTier.vadOnly);
      expect(BatteryThresholds.tierForLevel(5),  BatteryTier.vadOnly);
      expect(BatteryThresholds.tierForLevel(0),  BatteryTier.vadOnly);
    });

    test('unknown level (< 0) defaults to normal', () {
      expect(BatteryThresholds.tierForLevel(-1), BatteryTier.normal);
    });

    test('charging device stays normal regardless of level', () {
      expect(BatteryThresholds.tierForLevel(5, isCharging: true),
          BatteryTier.normal);
      expect(BatteryThresholds.tierForLevel(15, isCharging: true),
          BatteryTier.normal);
    });

    test('threshold constants match the timeline', () {
      expect(BatteryThresholds.powerSaverThreshold,    20);
      expect(BatteryThresholds.proactiveDropThreshold, 15);
      expect(BatteryThresholds.vadOnlyThreshold,       10);
    });
  });

  group('BatteryProfile · derived capability flags', () {
    test('normal allows everything', () {
      final p = BatteryProfile.fromLevel(80);
      expect(p.tier, BatteryTier.normal);
      expect(p.cameraEnabled, isTrue);
      expect(p.gpsReduced, isFalse);
      expect(p.proactiveDropActive, isFalse);
      expect(p.vadOnly, isFalse);
    });

    test('powerSaver disables camera + reduces GPS', () {
      final p = BatteryProfile.fromLevel(18);
      expect(p.tier, BatteryTier.powerSaver);
      expect(p.cameraEnabled, isFalse);
      expect(p.gpsReduced, isTrue);
      expect(p.proactiveDropActive, isFalse);
      expect(p.vadOnly, isFalse);
    });

    test('proactiveDrop adds banner', () {
      final p = BatteryProfile.fromLevel(13);
      expect(p.tier, BatteryTier.proactiveDrop);
      expect(p.proactiveDropActive, isTrue);
      expect(p.vadOnly, isFalse);
    });

    test('vadOnly cascades all flags', () {
      final p = BatteryProfile.fromLevel(7);
      expect(p.tier, BatteryTier.vadOnly);
      expect(p.cameraEnabled, isFalse);
      expect(p.gpsReduced, isTrue);
      expect(p.proactiveDropActive, isTrue);
      expect(p.vadOnly, isTrue);
    });

    test('copyWith preserves unspecified fields', () {
      const p = BatteryProfile(
        level: 50,
        isCharging: false,
        tier: BatteryTier.normal,
      );
      final q = p.copyWith(level: 18);
      expect(q.level, 18);
      expect(q.isCharging, false);
      expect(q.tier, BatteryTier.normal);
    });

    test('equality + hashCode', () {
      final a = BatteryProfile.fromLevel(80);
      final b = BatteryProfile.fromLevel(80);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(BatteryProfile.fromLevel(7)));
    });

    test('unknown placeholder has level = -1 and normal tier', () {
      expect(BatteryProfile.unknown.level, -1);
      expect(BatteryProfile.unknown.tier,  BatteryTier.normal);
    });
  });

  group('BatteryService · synthetic injection', () {
    test('injectLevel emits profile changes through the stream', () async {
      final svc = BatteryService();
      addTearDown(svc.dispose);
      final emissions = <BatteryProfile>[];
      final sub = svc.profiles.listen(emissions.add);

      svc.injectLevel(80);
      svc.injectLevel(18);
      svc.injectLevel(8);
      await Future<void>.delayed(Duration.zero);

      expect(emissions.map((e) => e.tier).toList(), [
        BatteryTier.normal,
        BatteryTier.powerSaver,
        BatteryTier.vadOnly,
      ]);
      expect(svc.latest.tier, BatteryTier.vadOnly);
      await sub.cancel();
    });

    test('duplicate injections are dedup\'d (stream stays quiet)', () async {
      final svc = BatteryService();
      addTearDown(svc.dispose);
      final emissions = <BatteryProfile>[];
      final sub = svc.profiles.listen(emissions.add);

      svc.injectLevel(50);
      svc.injectLevel(50);
      svc.injectLevel(50);
      await Future<void>.delayed(Duration.zero);

      expect(emissions, hasLength(1));
      await sub.cancel();
    });

    test('charging injection forces normal tier', () async {
      final svc = BatteryService();
      addTearDown(svc.dispose);
      svc.injectLevel(8, isCharging: true);
      expect(svc.latest.tier, BatteryTier.normal);
      expect(svc.latest.isCharging, isTrue);
    });

    test('refresh() never throws — failures keep the prior profile', () async {
      final svc = BatteryService();
      addTearDown(svc.dispose);
      svc.injectLevel(80);
      // refresh() may succeed (Windows upower) or fail silently. Either
      // way it must not throw and `latest` must remain a valid profile.
      await expectLater(svc.refresh(), completes);
      expect(svc.latest.level, greaterThanOrEqualTo(-1));
      expect(svc.latest.tier, isA<BatteryTier>());
    });

    test('safetyPollInterval matches doc constant', () {
      expect(BatteryService.safetyPollInterval,
          const Duration(seconds: 60));
    });
  });
}
