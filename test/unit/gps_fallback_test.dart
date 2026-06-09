// Day 38 — GPS fallback policy + CellLocationService + GpsSample.provider.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zapsafe_mobile/data/models/gps_sample.dart';
import 'package:zapsafe_mobile/data/services/cell_location_service.dart';
import 'package:zapsafe_mobile/data/services/gps_fallback_coordinator.dart';
import 'package:zapsafe_mobile/data/services/gps_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('GpsProvider · wire encoding', () {
    test('round-trips through fromWire / wire', () {
      for (final p in GpsProvider.values) {
        expect(GpsProvider.fromWire(p.wire), p);
      }
    });

    test('unknown / null fall back to gps', () {
      expect(GpsProvider.fromWire(null), GpsProvider.gps);
      expect(GpsProvider.fromWire('lte_tower'), GpsProvider.gps);
    });
  });

  group('GpsSample · provider tag', () {
    test('default provider is gps and toMap omits the field', () {
      const s = GpsSample(
          timestampMs: 1, lat: 0, lng: 0, accuracyM: 8);
      expect(s.provider, GpsProvider.gps);
      expect(s.toMap().containsKey('prov'), isFalse);
      expect(s.isFallback, isFalse);
    });

    test('cell provider survives toMap → fromMap round-trip', () {
      const s = GpsSample(
        timestampMs: 1,
        lat: 12.97,
        lng: 77.59,
        accuracyM: 800,
        provider: GpsProvider.cell,
      );
      final restored = GpsSample.fromMap(s.toMap());
      expect(restored.provider, GpsProvider.cell);
      expect(restored.isFallback, isTrue);
      expect(s.toMap()['prov'], 'cell');
    });
  });

  group('CellLocationService', () {
    test('stubNext makes the next estimate() return that sample', () async {
      final svc = CellLocationService();
      final stub = svc.syntheticEstimate(seed: 42);
      svc.stubNext(stub);
      final out = await svc.estimate();
      expect(out, stub);
      expect(svc.successes, 1);
      expect(svc.lastEstimate, stub);
    });

    test('counters reset on resetCounters', () async {
      final svc = CellLocationService();
      svc.stubNext(svc.syntheticEstimate(seed: 7));
      await svc.estimate();
      expect(svc.attempts, 1);
      svc.resetCounters();
      expect(svc.attempts, 0);
      expect(svc.successes, 0);
    });

    test('syntheticEstimate is reproducible given a seed', () {
      final a = CellLocationService().syntheticEstimate(seed: 99);
      final b = CellLocationService().syntheticEstimate(seed: 99);
      expect(a.lat,  closeTo(b.lat, 1e-12));
      expect(a.lng,  closeTo(b.lng, 1e-12));
      expect(a.provider, GpsProvider.cell);
    });

    test('estimate() with no native channel returns null', () async {
      final svc = CellLocationService();
      final out = await svc.estimate();
      expect(out, isNull);
      expect(svc.failures, greaterThanOrEqualTo(1));
    });
  });

  group('GpsFallbackCoordinator', () {
    GpsSample _gps({double acc = 8}) => GpsSample(
        timestampMs: DateTime.now().millisecondsSinceEpoch,
        lat: 12.97,
        lng: 77.59,
        accuracyM: acc);

    test('evaluate() returns null for high-quality GPS', () {
      final gps  = GpsService();
      final cell = CellLocationService();
      final coord = GpsFallbackCoordinator(gps: gps, cell: cell);
      expect(coord.evaluate(_gps(acc: 10)), isNull);
    });

    test('evaluate() flags low-quality GPS', () {
      final gps  = GpsService();
      final cell = CellLocationService();
      final coord = GpsFallbackCoordinator(gps: gps, cell: cell);
      final reason = coord.evaluate(_gps(acc: 240));
      expect(reason, isNotNull);
      expect(reason, contains('240'));
    });

    test('cell-provider samples never trigger further fallback', () {
      final gps  = GpsService();
      final cell = CellLocationService();
      final coord = GpsFallbackCoordinator(gps: gps, cell: cell);
      final stub = cell.syntheticEstimate(seed: 1);
      expect(coord.evaluate(stub), isNull);
    });

    test('attach() wires the GPS stream and counts low-quality fixes',
        () async {
      final gps  = GpsService();
      final cell = CellLocationService();
      final coord = GpsFallbackCoordinator(
        gps: gps,
        cell: cell,
        // Use a wide stale window so the test isn't racing the timer.
        staleWindow: const Duration(minutes: 10),
        minAttemptGap: Duration.zero,
      );
      // Pre-stage a cell estimate so injecting bad GPS triggers a merge.
      cell.stubNext(cell.syntheticEstimate(seed: 11));
      coord.attach();
      addTearDown(coord.dispose);

      // High-quality fix → no fallback.
      gps.injectSample(_gps(acc: 9));
      await Future<void>.delayed(Duration.zero);
      expect(coord.gpsLowQualityTriggers, 0);

      // Low-quality fix → trigger.
      gps.injectSample(_gps(acc: 220));
      await Future<void>.delayed(Duration.zero);
      // Give the async _requestFallback a chance to resolve.
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(coord.gpsLowQualityTriggers, 1);
      expect(coord.fallbackEmissions, 1);
      expect(gps.latest!.provider, GpsProvider.cell);
    });

    test('GPS recovery counter ticks when quality returns', () async {
      final gps  = GpsService();
      final cell = CellLocationService();
      final coord = GpsFallbackCoordinator(
        gps: gps,
        cell: cell,
        staleWindow: const Duration(minutes: 10),
        minAttemptGap: Duration.zero,
      );
      coord.attach();
      addTearDown(coord.dispose);

      // Low-quality, then high-quality.
      gps.injectSample(_gps(acc: 220));
      await Future<void>.delayed(Duration.zero);
      gps.injectSample(_gps(acc: 12));
      await Future<void>.delayed(Duration.zero);

      expect(coord.gpsRecoveries, 1);
    });

    test('minAttemptGap suppresses back-to-back fallback attempts', () async {
      final gps  = GpsService();
      final cell = CellLocationService();
      final coord = GpsFallbackCoordinator(
        gps: gps,
        cell: cell,
        staleWindow: const Duration(minutes: 10),
        minAttemptGap: const Duration(seconds: 5),
      );
      cell.stubNext(cell.syntheticEstimate(seed: 22));
      coord.attach();
      addTearDown(coord.dispose);

      // Two bad fixes in quick succession; second one should be debounced.
      gps.injectSample(_gps(acc: 220));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      // The cell service was stubbed once → only one emission.
      cell.stubNext(cell.syntheticEstimate(seed: 23));
      gps.injectSample(_gps(acc: 220));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(coord.gpsLowQualityTriggers, 2); // both eval'd
      expect(coord.fallbackEmissions, 1);     // but only one merged
    });

    test('detach() is idempotent', () async {
      final gps  = GpsService();
      final cell = CellLocationService();
      final coord = GpsFallbackCoordinator(gps: gps, cell: cell);
      coord.attach();
      coord.detach();
      coord.detach(); // must not throw
      expect(coord.isAttached, isFalse);
    });

    test('requestFallback(force: true) bypasses minAttemptGap', () async {
      final gps  = GpsService();
      final cell = CellLocationService();
      final coord = GpsFallbackCoordinator(
        gps: gps,
        cell: cell,
        minAttemptGap: const Duration(minutes: 10),
      );
      cell.stubNext(cell.syntheticEstimate(seed: 30));
      final first = await coord.requestFallback(force: true);
      cell.stubNext(cell.syntheticEstimate(seed: 31));
      final second = await coord.requestFallback(force: true);
      expect(first,  isNotNull);
      expect(second, isNotNull);
      expect(coord.fallbackEmissions, 2);
    });

    test('accuracyThresholdM constant matches LP12', () {
      expect(GpsFallbackCoordinator.accuracyThresholdM, 50);
    });
  });
}
