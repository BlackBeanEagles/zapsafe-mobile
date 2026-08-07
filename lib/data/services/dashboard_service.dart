/// Production dashboard data — GET /api/v1/sos/dashboard/ (backend Day 21+).
library;

import '../../core/constants/api_config.dart';
import 'api_client.dart';

class SosDashboardRollup {
  const SosDashboardRollup({
    required this.totalTriggers,
    required this.liveCount,
    required this.last7dCount,
    required this.last30dCount,
    required this.falseAlarmCount,
    required this.falseAlarmRate,
    required this.duressCount,
    required this.byStatus,
    required this.byTriggerType,
    required this.mostUsedTriggerType,
    required this.avgResponseTimeSeconds,
    required this.totalEvidenceItems,
    required this.totalLocationPings,
    required this.byHourOfDay,
    required this.byDayOfWeek,
    required this.peakHour,
  });

  final int totalTriggers;
  final int liveCount;
  final int last7dCount;
  final int last30dCount;
  final int falseAlarmCount;
  final double? falseAlarmRate;
  final int duressCount;
  final Map<String, int> byStatus;
  final Map<String, int> byTriggerType;
  final String? mostUsedTriggerType;
  final double? avgResponseTimeSeconds;
  final int totalEvidenceItems;
  final int totalLocationPings;
  final Map<String, int> byHourOfDay;
  final Map<String, int> byDayOfWeek;
  final String? peakHour;

  factory SosDashboardRollup.fromJson(Map<String, dynamic> j) =>
      SosDashboardRollup(
        totalTriggers: (j['total_triggers'] as num?)?.toInt() ?? 0,
        liveCount: (j['live_count'] as num?)?.toInt() ?? 0,
        last7dCount: (j['last_7d_count'] as num?)?.toInt() ?? 0,
        last30dCount: (j['last_30d_count'] as num?)?.toInt() ?? 0,
        falseAlarmCount: (j['false_alarm_count'] as num?)?.toInt() ?? 0,
        falseAlarmRate: (j['false_alarm_rate'] as num?)?.toDouble(),
        duressCount: (j['duress_count'] as num?)?.toInt() ?? 0,
        byStatus: _intMap(j['by_status']),
        byTriggerType: _intMap(j['by_trigger_type']),
        mostUsedTriggerType: j['most_used_trigger_type'] as String?,
        avgResponseTimeSeconds:
            (j['avg_response_time_seconds'] as num?)?.toDouble(),
        totalEvidenceItems:
            (j['total_evidence_items'] as num?)?.toInt() ?? 0,
        totalLocationPings:
            (j['total_location_pings'] as num?)?.toInt() ?? 0,
        byHourOfDay: _intMap(j['by_hour_of_day']),
        byDayOfWeek: _intMap(j['by_day_of_week']),
        peakHour: j['peak_hour'] as String?,
      );

  static Map<String, int> _intMap(dynamic raw) {
    if (raw == null) return {};
    return (raw as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, (v as num).toInt()),
    );
  }
}

class DashboardService {
  const DashboardService(this._client);
  final ApiClient _client;

  Future<SosDashboardRollup> fetchSosDashboard() async {
    final res = await _client.dio.get(ApiConfig.sosDashboard);
    return SosDashboardRollup.fromJson(res.data as Map<String, dynamic>);
  }
}
