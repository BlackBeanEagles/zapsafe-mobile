/// Day 80 — Dashboard state management.
///
/// Wired to GET /api/v1/sos/dashboard/ when [kUseMockData] is false.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_flags.dart';
import '../../data/services/dashboard_service.dart';
import 'auth_providers.dart';

// ─── Period ───────────────────────────────────────────────────────────────────

enum DashboardPeriod {
  week,
  month,
  quarter;

  String get label {
    switch (this) {
      case DashboardPeriod.week:    return '7 days';
      case DashboardPeriod.month:   return '30 days';
      case DashboardPeriod.quarter: return '90 days';
    }
  }

  int get days {
    switch (this) {
      case DashboardPeriod.week:    return 7;
      case DashboardPeriod.month:   return 30;
      case DashboardPeriod.quarter: return 90;
    }
  }
}

// ─── Data model ───────────────────────────────────────────────────────────────

class DashboardData {
  const DashboardData({
    required this.totalEvents,
    required this.falseAlarmPct,
    required this.avgResponseSec,
    required this.byDayOfWeek,
    required this.trendPoints,
    required this.peakHours,
    required this.tier1Pct,
    required this.tier2Pct,
    required this.safetyScore,
    required this.screamCount,
    required this.motionCount,
    required this.sceneCount,
    required this.heatmap,    // [dayIndex 0=Mon][hourIndex 0=midnight]
  });

  final int                    totalEvents;
  final double                 falseAlarmPct;
  final int                    avgResponseSec;
  final List<double>           byDayOfWeek;  // 7 values Mon–Sun
  final List<double>           trendPoints;
  final List<(String, int)>    peakHours;
  final double                 tier1Pct;
  final double                 tier2Pct;
  final double                 safetyScore;
  final int                    screamCount;
  final int                    motionCount;
  final int                    sceneCount;
  final List<List<int>>        heatmap;      // 7 days × 24 hours
}

// ─── Mock data factory ────────────────────────────────────────────────────────

DashboardData _mockData(DashboardPeriod period) {
  switch (period) {
    case DashboardPeriod.week:
      return DashboardData(
        totalEvents:    4,
        falseAlarmPct:  25,
        avgResponseSec: 38,
        byDayOfWeek:    [0, 0, 1, 0, 1, 1, 1],
        trendPoints:    [0, 1, 0, 0, 1, 1, 1],
        peakHours:      [('22:00', 2), ('10:00', 1), ('07:00', 1)],
        tier1Pct:       75,
        tier2Pct:       25,
        safetyScore:    87,
        screamCount:    2,
        motionCount:    1,
        sceneCount:     1,
        heatmap:        _buildHeatmap(scale: 1),
      );
    case DashboardPeriod.month:
      return DashboardData(
        totalEvents:    11,
        falseAlarmPct:  18,
        avgResponseSec: 45,
        byDayOfWeek:    [1, 2, 1, 0, 2, 3, 2],
        trendPoints:    [1, 0, 2, 1, 1, 0, 1, 2, 1, 0, 1, 1],
        peakHours:      [('22:00', 4), ('09:00', 3), ('21:00', 2)],
        tier1Pct:       64,
        tier2Pct:       36,
        safetyScore:    82,
        screamCount:    5,
        motionCount:    4,
        sceneCount:     2,
        heatmap:        _buildHeatmap(scale: 3),
      );
    case DashboardPeriod.quarter:
      return DashboardData(
        totalEvents:    28,
        falseAlarmPct:  14,
        avgResponseSec: 52,
        byDayOfWeek:    [3, 4, 4, 2, 5, 6, 4],
        trendPoints:    [2, 3, 1, 4, 3, 2, 4, 5, 2, 3, 1, 4, 2, 3, 5, 3],
        peakHours:      [('22:00', 9), ('09:00', 7), ('21:00', 5)],
        tier1Pct:       61,
        tier2Pct:       39,
        safetyScore:    78,
        screamCount:    12,
        motionCount:    10,
        sceneCount:     6,
        heatmap:        _buildHeatmap(scale: 7),
      );
  }
}

/// Generates a 7×24 heatmap with realistic peaks.
/// [scale] multiplies the base pattern to simulate more events in longer periods.
List<List<int>> _buildHeatmap({required int scale}) {
  // Base pattern for one week: [dayIndex][hourIndex]
  // Peaks: late evening (21-23), early morning (7-9), quiet at night (0-5)
  final pattern = List.generate(7, (day) {
    return List.generate(24, (hour) {
      // Late evening peak
      if (hour >= 21 && hour <= 23) return (2 + (day % 3)).clamp(0, 5);
      // Morning peak
      if (hour >= 7 && hour <= 9) return (1 + (day % 2)).clamp(0, 5);
      // Afternoon minor
      if (hour >= 14 && hour <= 16) return (day % 2).clamp(0, 5);
      // Dead zone (early night)
      if (hour >= 0 && hour <= 5) return 0;
      return 0;
    });
  });

  if (scale == 1) return pattern;
  return pattern
      .map((row) => row.map((v) => (v * scale ~/ 3).clamp(0, 9)).toList())
      .toList();
}

// ─── Service ──────────────────────────────────────────────────────────────────

final dashboardServiceProvider = Provider<DashboardService>((ref) {
  return DashboardService(ref.watch(apiClientProvider));
});

DashboardData _fromApiRollup(SosDashboardRollup rollup, DashboardPeriod period) {
  final byDay = List<double>.generate(7, (i) {
    return (rollup.byDayOfWeek['$i'] ?? rollup.byDayOfWeek[i.toString()] ?? 0)
        .toDouble();
  });

  final falseRate = rollup.falseAlarmRate;
  final falsePct = falseRate == null
      ? 0.0
      : (falseRate <= 1 ? falseRate * 100 : falseRate);

  final peakHours = rollup.byHourOfDay.entries
      .toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final topPeaks = peakHours
      .take(3)
      .map((e) => ('${e.key}:00', e.value))
      .toList();

  final totalTier = rollup.byStatus.values.fold<int>(0, (a, b) => a + b);
  final resolved = (rollup.byStatus['resolved'] ?? 0).toDouble();
  final tier1Pct = totalTier == 0 ? 0.0 : (resolved / totalTier) * 100;

  return DashboardData(
    totalEvents: rollup.totalTriggers,
    falseAlarmPct: falsePct,
    avgResponseSec: rollup.avgResponseTimeSeconds?.round() ?? 0,
    byDayOfWeek: byDay,
    trendPoints: byDay,
    peakHours: topPeaks,
    tier1Pct: tier1Pct,
    tier2Pct: 100 - tier1Pct,
    safetyScore: (100 - falsePct).clamp(0, 100),
    screamCount: rollup.byTriggerType['ai_detected'] ?? 0,
    motionCount: rollup.byTriggerType['shake'] ?? 0,
    sceneCount: rollup.byTriggerType['manual_button'] ?? 0,
    heatmap: _buildHeatmap(scale: period.days ~/ 7),
  );
}

// ─── Providers ────────────────────────────────────────────────────────────────

/// Currently selected period — drives [dashboardDataProvider].
final dashboardPeriodProvider =
    StateProvider<DashboardPeriod>((ref) => DashboardPeriod.week);

/// Dashboard data keyed by [DashboardPeriod].
final dashboardDataProvider =
    FutureProvider.family<DashboardData, DashboardPeriod>((ref, period) async {
  if (!kUseMockData && ref.watch(isLoggedInProvider)) {
    try {
      final rollup =
          await ref.watch(dashboardServiceProvider).fetchSosDashboard();
      return _fromApiRollup(rollup, period);
    } catch (e) {
      if (kDebugMode) debugPrint('[dashboard] API failed, using mock: $e');
    }
  }
  await Future<void>.delayed(const Duration(milliseconds: 300));
  return _mockData(period);
});
