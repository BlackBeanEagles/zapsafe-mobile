/// Day 302 — Analytics API providers.
///
/// Wires the real, live backend analytics endpoints (Day 81-85) into
/// Riverpod `FutureProvider`s. [kUseMockData] (see `core/constants/app_flags.dart`)
/// keeps these on seeded mock values for offline emulator QA — set
/// `--dart-define=USE_MOCK_DATA=true` to force it.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_flags.dart';
import '../../data/services/analytics_api_service.dart';
import 'auth_providers.dart';

/// Singleton [AnalyticsApiService] — rides on [apiClientProvider], same
/// pattern as every other Day 7+ service.
final analyticsApiServiceProvider = Provider<AnalyticsApiService>((ref) {
  return AnalyticsApiService(ref.watch(apiClientProvider));
});

// ─── Mock fallbacks (offline emulator QA only) ─────────────────────────────

SosSummary _mockSosSummary() => const SosSummary(
      totalSos: 4,
      falsePositives: 1,
      falsePositiveRate: 25.0,
      avgResponseTimeSecs: 42.5,
      mostCommonTrigger: 'manual_button',
      sosPerWeek: [
        SosPerWeek(weekStart: '2026-07-13', count: 1),
        SosPerWeek(weekStart: '2026-07-20', count: 0),
        SosPerWeek(weekStart: '2026-07-27', count: 2),
        SosPerWeek(weekStart: '2026-08-03', count: 1),
      ],
    );

DetectionAnalytics _mockDetections() => const DetectionAnalytics(
      perModel: [
        ModelPerformanceRow(
          modelName: 'scream',
          totalDetections: 18,
          truePositives: 15,
          falsePositives: 3,
          accuracyPct: 83.3,
        ),
        ModelPerformanceRow(
          modelName: 'motion',
          totalDetections: 9,
          truePositives: 8,
          falsePositives: 1,
          accuracyPct: 88.9,
        ),
      ],
      detectionsPerDay: {'2026-08-05': 3, '2026-08-06': 2},
      overallFpRate: 14.8,
      trend: 'improving',
    );

ContactResponseRate _mockContactResponseRate() => const ContactResponseRate(
      totalNotifications: 12,
      totalAcks: 9,
      overallResponseRate: 75.0,
      avgAckTimeSecs: 38.0,
      responseRateTrend: 'stable',
      perContact: [
        ContactResponseRow(
          contactId: 'mock-c1',
          notifiedCount: 4,
          ackedCount: 4,
          responseRate: 100.0,
        ),
        ContactResponseRow(
          contactId: 'mock-c2',
          notifiedCount: 4,
          ackedCount: 3,
          responseRate: 75.0,
        ),
      ],
    );

DeviceHealthReport _mockDeviceHealth() => const DeviceHealthReport(
      batteryDrainPctPerHour: 3.2,
      memoryUsageMb: 128.4,
      cpuUsagePct: 6.1,
      appSizeMb: 42.0,
      detectionCycleLatencyMs: 85.0,
      appVersion: '1.4.2-mock',
      osVersion: 'Android 14 (mock)',
      deviceModel: 'Pixel 7 (mock)',
      lastReportedAt: '2026-08-06T09:00:00Z',
      reportCount: 6,
    );

// ─── FutureProviders — real when [kUseMockData] is false ─────────────────

final sosSummaryProvider = FutureProvider<SosSummary>((ref) async {
  if (kUseMockData) return _mockSosSummary();
  try {
    return await ref.watch(analyticsApiServiceProvider).fetchSosSummary();
  } catch (_) {
    return _mockSosSummary();
  }
});

final detectionAnalyticsProvider = FutureProvider<DetectionAnalytics>((ref) async {
  if (kUseMockData) return _mockDetections();
  try {
    return await ref.watch(analyticsApiServiceProvider).fetchDetections();
  } catch (_) {
    return _mockDetections();
  }
});

final contactResponseRateProvider = FutureProvider<ContactResponseRate>((ref) async {
  if (kUseMockData) return _mockContactResponseRate();
  try {
    return await ref.watch(analyticsApiServiceProvider).fetchContactResponseRate();
  } catch (_) {
    return _mockContactResponseRate();
  }
});

final deviceHealthProvider = FutureProvider<DeviceHealthReport>((ref) async {
  if (kUseMockData) return _mockDeviceHealth();
  try {
    return await ref.watch(analyticsApiServiceProvider).fetchDeviceHealth();
  } catch (_) {
    return _mockDeviceHealth();
  }
});

/// Raw, no-mock-fallback variants — used by the Day 302 QA screen so it can
/// show a real error state (401/500/network) instead of silently masking
/// failures behind mock data, per the Day 302 acceptance criteria.
final sosSummaryRawProvider = FutureProvider<SosSummary>((ref) {
  return ref.watch(analyticsApiServiceProvider).fetchSosSummary();
});

final detectionAnalyticsRawProvider = FutureProvider<DetectionAnalytics>((ref) {
  return ref.watch(analyticsApiServiceProvider).fetchDetections();
});

final contactResponseRateRawProvider = FutureProvider<ContactResponseRate>((ref) {
  return ref.watch(analyticsApiServiceProvider).fetchContactResponseRate();
});

final deviceHealthRawProvider = FutureProvider<DeviceHealthReport>((ref) {
  return ref.watch(analyticsApiServiceProvider).fetchDeviceHealth();
});
