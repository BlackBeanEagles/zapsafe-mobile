// Day 323 — journey risk heuristic tests. Pure Dart, deterministic.

import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/data/models/gps_sample.dart';
import 'package:zapsafe_mobile/domain/journey/journey_risk_heuristic.dart';

GpsSample _sample({double? speedMps, double accuracyM = 8, int t = 0}) =>
    GpsSample(timestampMs: t, lat: 0, lng: 0, accuracyM: accuracyM, speedMps: speedMps);

void main() {
  group('computeJourneyRiskScore · time of day', () {
    test('night hours (23:00) add +30 over the daytime baseline', () {
      final night = computeJourneyRiskScore(
        recentSamples: [_sample(speedMps: 1.4)],
        now: DateTime(2026, 1, 1, 23, 0),
      );
      final day = computeJourneyRiskScore(
        recentSamples: [_sample(speedMps: 1.4)],
        now: DateTime(2026, 1, 1, 12, 0),
      );
      expect(night.riskScore - day.riskScore, 30);
    });

    test('dawn/dusk hours add +10 over the daytime baseline', () {
      final dusk = computeJourneyRiskScore(
        recentSamples: [_sample(speedMps: 1.4)],
        now: DateTime(2026, 1, 1, 19, 0),
      );
      final day = computeJourneyRiskScore(
        recentSamples: [_sample(speedMps: 1.4)],
        now: DateTime(2026, 1, 1, 12, 0),
      );
      expect(dusk.riskScore - day.riskScore, 10);
    });
  });

  group('computeJourneyRiskScore · speed', () {
    test('stationary sample raises risk', () {
      final stationary = computeJourneyRiskScore(
        recentSamples: [_sample(speedMps: 0.05)],
        now: DateTime(2026, 1, 1, 12, 0),
      );
      final moving = computeJourneyRiskScore(
        recentSamples: [_sample(speedMps: 1.4)],
        now: DateTime(2026, 1, 1, 12, 0),
      );
      expect(stationary.riskScore, greaterThan(moving.riskScore));
    });

    test('unusually fast sample raises risk over normal movement', () {
      final fast = computeJourneyRiskScore(
        recentSamples: [_sample(speedMps: 40)],
        now: DateTime(2026, 1, 1, 12, 0),
      );
      final moving = computeJourneyRiskScore(
        recentSamples: [_sample(speedMps: 1.4)],
        now: DateTime(2026, 1, 1, 12, 0),
      );
      expect(fast.riskScore, greaterThan(moving.riskScore));
    });

    test('null speed adds a small uncertainty bump', () {
      final unknown = computeJourneyRiskScore(
        recentSamples: [_sample(speedMps: null)],
        now: DateTime(2026, 1, 1, 12, 0),
      );
      final moving = computeJourneyRiskScore(
        recentSamples: [_sample(speedMps: 1.4)],
        now: DateTime(2026, 1, 1, 12, 0),
      );
      expect(unknown.riskScore, greaterThan(moving.riskScore));
    });
  });

  group('computeJourneyRiskScore · GPS quality + variability', () {
    test('low-quality fix (>50m) raises risk', () {
      final poor = computeJourneyRiskScore(
        recentSamples: [_sample(speedMps: 1.4, accuracyM: 120)],
        now: DateTime(2026, 1, 1, 12, 0),
      );
      final good = computeJourneyRiskScore(
        recentSamples: [_sample(speedMps: 1.4, accuracyM: 8)],
        now: DateTime(2026, 1, 1, 12, 0),
      );
      expect(poor.riskScore, greaterThan(good.riskScore));
    });

    test('erratic speed pattern (high variance) raises risk', () {
      final erratic = computeJourneyRiskScore(
        recentSamples: [
          _sample(speedMps: 0, t: 0),
          _sample(speedMps: 20, t: 1),
          _sample(speedMps: 1, t: 2),
          _sample(speedMps: 18, t: 3),
        ],
        now: DateTime(2026, 1, 1, 12, 0),
      );
      final steady = computeJourneyRiskScore(
        recentSamples: [
          _sample(speedMps: 1.4, t: 0),
          _sample(speedMps: 1.5, t: 1),
          _sample(speedMps: 1.3, t: 2),
          _sample(speedMps: 1.4, t: 3),
        ],
        now: DateTime(2026, 1, 1, 12, 0),
      );
      expect(erratic.riskScore, greaterThan(steady.riskScore));
    });
  });

  group('computeJourneyRiskScore · bounds + empty input', () {
    test('empty sample list returns baseline + small uncertainty bump', () {
      final result = computeJourneyRiskScore(
        recentSamples: const [],
        now: DateTime(2026, 1, 1, 12, 0),
      );
      expect(result.riskScore, 25); // 20 baseline + 5 no-samples
      expect(result.reasons, isNotEmpty);
    });

    test('risk score never exceeds 100', () {
      final worst = computeJourneyRiskScore(
        recentSamples: [_sample(speedMps: 0.0, accuracyM: 500)],
        now: DateTime(2026, 1, 1, 3, 0), // night
      );
      expect(worst.riskScore, lessThanOrEqualTo(100));
    });

    test('confidenceScore is exactly 100 - riskScore', () {
      final r = computeJourneyRiskScore(
        recentSamples: [_sample(speedMps: 1.4)],
        now: DateTime(2026, 1, 1, 12, 0),
      );
      expect(r.confidenceScore, 100 - r.riskScore);
    });
  });
}
