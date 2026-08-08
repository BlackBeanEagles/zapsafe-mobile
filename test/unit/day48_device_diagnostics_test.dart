/// Day 48 — Device Diagnostics unit tests.
///
/// Since the diagnostics screen is a pure aggregator of existing services,
/// these tests focus on the data models that power each card:
///   - PhoneCapabilityTier label / tierFor mapping
///   - CapabilityProbeResult constructors and aiViable threshold
///   - MotionFeatures field values (what the IMU card displays)
///   - GpsSample field values (what the GPS card displays)
///   - PermissionOutcome equality (what the permissions card checks)
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/data/models/gps_sample.dart';
import 'package:zapsafe_mobile/data/models/motion_features.dart';
import 'package:zapsafe_mobile/data/services/permission_service.dart';
import 'package:zapsafe_mobile/data/services/phone_capability_detector.dart';

void main() {
  // ── PhoneCapabilityTier.tierFor mapping ───────────────────────────────────
  group('PhoneCapabilityTier.tierFor', () {
    test('< 100 ms → high', () {
      expect(CapabilityProbeResult.tierFor(99.9), PhoneCapabilityTier.high);
    });

    test('exactly 100 ms → medium', () {
      expect(CapabilityProbeResult.tierFor(100.0), PhoneCapabilityTier.medium);
    });

    test('100–499 ms → medium', () {
      expect(CapabilityProbeResult.tierFor(250.0), PhoneCapabilityTier.medium);
    });

    test('exactly 500 ms → low', () {
      expect(CapabilityProbeResult.tierFor(500.0), PhoneCapabilityTier.low);
    });

    test('> 500 ms → low', () {
      expect(CapabilityProbeResult.tierFor(1000.0), PhoneCapabilityTier.low);
    });

    test('0 ms → high', () {
      expect(CapabilityProbeResult.tierFor(0.0), PhoneCapabilityTier.high);
    });
  });

  // ── CapabilityProbeResult.aiViable ────────────────────────────────────────
  group('CapabilityProbeResult.aiViable', () {
    test('999 ms → AI viable', () {
      expect(CapabilityProbeResult.aiViable(999.9), isTrue);
    });

    test('1000 ms (threshold) → NOT viable', () {
      expect(CapabilityProbeResult.aiViable(1000.0), isFalse);
    });

    test('5000 ms → NOT viable', () {
      expect(CapabilityProbeResult.aiViable(5000.0), isFalse);
    });
  });

  // ── CapabilityProbeResult construction ────────────────────────────────────
  group('CapabilityProbeResult', () {
    test('high tier result has correct fields', () {
      const r = CapabilityProbeResult(
        tier: PhoneCapabilityTier.high,
        inferenceMs: 42.0,
        shouldUseAi: true,
      );
      expect(r.tier, PhoneCapabilityTier.high);
      expect(r.inferenceMs, 42.0);
      expect(r.shouldUseAi, isTrue);
      expect(r.tierLabel, contains('High'));
    });

    test('low tier result has correct label', () {
      const r = CapabilityProbeResult(
        tier: PhoneCapabilityTier.low,
        inferenceMs: 800.0,
        shouldUseAi: false,
      );
      expect(r.tierLabel, contains('Heuristic'));
    });
  });

  // ── MotionFeatures (IMU card data source) ─────────────────────────────────
  group('MotionFeatures for IMU card', () {
    test('atRest fixture has low motion values', () {
      final f = MotionFeatures.atRest(timestampMs: 1000);
      expect(f.accelPeak, lessThan(12.0));   // gravity only
      expect(f.gyroPeak,  lessThan(0.1));
      expect(f.timestampMs, equals(1000));
    });

    test('walking fixture has moderate accel', () {
      final f = MotionFeatures.walking(timestampMs: 2000);
      expect(f.accelPeak, greaterThan(f.accelMean));
      expect(f.timestampMs, equals(2000));
    });

    test('impact fixture has high accel peak', () {
      final f = MotionFeatures.impact(timestampMs: 3000);
      expect(f.accelPeak, greaterThan(15.0));
    });

    test('fields are all non-negative', () {
      final f = MotionFeatures.atRest(timestampMs: 0);
      expect(f.accelMean, greaterThanOrEqualTo(0.0));
      expect(f.accelVar,  greaterThanOrEqualTo(0.0));
      expect(f.accelPeak, greaterThanOrEqualTo(0.0));
      expect(f.gyroMean,  greaterThanOrEqualTo(0.0));
      expect(f.gyroVar,   greaterThanOrEqualTo(0.0));
      expect(f.gyroPeak,  greaterThanOrEqualTo(0.0));
    });

    test('toFloat32Tensor returns 6-element list', () {
      final f = MotionFeatures.atRest(timestampMs: 0);
      expect(f.toFloat32Tensor().length, equals(6));
    });
  });

  // ── GpsSample (GPS card data source) ─────────────────────────────────────
  group('GpsSample for GPS card', () {
    GpsSample sample({double lat = 51.5, double lng = -0.1, double acc = 5.0}) =>
        GpsSample(
          timestampMs: DateTime.now().millisecondsSinceEpoch,
          lat: lat,
          lng: lng,
          accuracyM: acc,
          provider: GpsProvider.gps,
        );

    test('lat/lng are preserved', () {
      final s = sample(lat: 37.7749, lng: -122.4194);
      expect(s.lat, closeTo(37.7749, 0.0001));
      expect(s.lng, closeTo(-122.4194, 0.0001));
    });

    test('accuracyM is preserved', () {
      final s = sample(acc: 8.5);
      expect(s.accuracyM, equals(8.5));
    });

    test('timestampMs is positive', () {
      expect(sample().timestampMs, greaterThan(0));
    });
  });

  // ── PermissionOutcome (permissions card check) ────────────────────────────
  group('PermissionOutcome for permissions card', () {
    test('granted == granted', () {
      expect(
        PermissionOutcome.granted == PermissionOutcome.granted,
        isTrue,
      );
    });

    test('denied != granted', () {
      expect(
        PermissionOutcome.denied == PermissionOutcome.granted,
        isFalse,
      );
    });

    test('deniedForever != granted', () {
      expect(
        PermissionOutcome.deniedForever == PermissionOutcome.granted,
        isFalse,
      );
    });

    test('all PermissionOutcome values exist', () {
      expect(PermissionOutcome.values, containsAll([
        PermissionOutcome.granted,
        PermissionOutcome.denied,
        PermissionOutcome.deniedForever,
      ]));
    });
  });
}
