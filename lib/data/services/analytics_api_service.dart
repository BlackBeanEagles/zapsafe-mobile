/// Analytics service — backend Day 81-85, wired for real Day 302.
///
/// GET /api/v1/analytics/sos-summary/
/// GET /api/v1/analytics/detections/
/// GET /api/v1/analytics/contacts/response-rate/
/// GET /api/v1/analytics/device-health/   (also POST, see [reportDeviceHealth])
///
/// Response shapes below match the real Django views
/// (`zapsafe_backend/analytics/views.py`) field-for-field, verified by
/// reading the view source directly (Docker was unavailable in this
/// sandbox, so this is code-level verification, not a live HTTP round trip
/// — see DAY301_305_INTEGRATION_WIRING.md for the full note).
library;

import '../../core/constants/api_config.dart';
import 'api_client.dart';

// ─── Models ───────────────────────────────────────────────────────────────

class SosSummary {
  const SosSummary({
    required this.totalSos,
    required this.falsePositives,
    required this.falsePositiveRate,
    required this.avgResponseTimeSecs,
    required this.mostCommonTrigger,
    required this.sosPerWeek,
  });

  final int totalSos;
  final int falsePositives;
  final double falsePositiveRate;
  final double? avgResponseTimeSecs;
  final String? mostCommonTrigger;
  final List<SosPerWeek> sosPerWeek;

  factory SosSummary.fromJson(Map<String, dynamic> j) => SosSummary(
        totalSos: (j['total_sos'] as num?)?.toInt() ?? 0,
        falsePositives: (j['false_positives'] as num?)?.toInt() ?? 0,
        falsePositiveRate: (j['false_positive_rate'] as num?)?.toDouble() ?? 0,
        avgResponseTimeSecs: (j['avg_response_time_secs'] as num?)?.toDouble(),
        mostCommonTrigger: j['most_common_trigger'] as String?,
        sosPerWeek: ((j['sos_per_week'] as List?) ?? [])
            .cast<Map<String, dynamic>>()
            .map(SosPerWeek.fromJson)
            .toList(),
      );
}

class SosPerWeek {
  const SosPerWeek({required this.weekStart, required this.count});
  final String weekStart;
  final int count;

  factory SosPerWeek.fromJson(Map<String, dynamic> j) => SosPerWeek(
        weekStart: j['week_start'] as String? ?? '',
        count: (j['count'] as num?)?.toInt() ?? 0,
      );
}

class DetectionAnalytics {
  const DetectionAnalytics({
    required this.perModel,
    required this.detectionsPerDay,
    required this.overallFpRate,
    required this.trend,
  });

  final List<ModelPerformanceRow> perModel;
  final Map<String, int> detectionsPerDay;
  final double overallFpRate;
  final String trend; // improving | declining | stable

  factory DetectionAnalytics.fromJson(Map<String, dynamic> j) => DetectionAnalytics(
        perModel: ((j['per_model'] as List?) ?? [])
            .cast<Map<String, dynamic>>()
            .map(ModelPerformanceRow.fromJson)
            .toList(),
        detectionsPerDay: _intMap(j['detections_per_day']),
        overallFpRate: (j['overall_fp_rate'] as num?)?.toDouble() ?? 0,
        trend: j['trend'] as String? ?? 'stable',
      );
}

class ModelPerformanceRow {
  const ModelPerformanceRow({
    required this.modelName,
    required this.totalDetections,
    required this.truePositives,
    required this.falsePositives,
    required this.accuracyPct,
  });

  final String modelName;
  final int totalDetections;
  final int truePositives;
  final int falsePositives;
  final double? accuracyPct;

  factory ModelPerformanceRow.fromJson(Map<String, dynamic> j) => ModelPerformanceRow(
        modelName: j['model_name'] as String? ?? '',
        totalDetections: (j['total_detections'] as num?)?.toInt() ?? 0,
        truePositives: (j['true_positives'] as num?)?.toInt() ?? 0,
        falsePositives: (j['false_positives'] as num?)?.toInt() ?? 0,
        accuracyPct: (j['accuracy_pct'] as num?)?.toDouble(),
      );
}

class ContactResponseRate {
  const ContactResponseRate({
    required this.totalNotifications,
    required this.totalAcks,
    required this.overallResponseRate,
    required this.avgAckTimeSecs,
    required this.responseRateTrend,
    required this.perContact,
  });

  final int totalNotifications;
  final int totalAcks;
  final double overallResponseRate;
  final double? avgAckTimeSecs;
  final String responseRateTrend;
  final List<ContactResponseRow> perContact;

  factory ContactResponseRate.fromJson(Map<String, dynamic> j) {
    final overall = (j['overall'] as Map<String, dynamic>?) ?? const {};
    return ContactResponseRate(
      totalNotifications: (overall['total_notifications'] as num?)?.toInt() ?? 0,
      totalAcks: (overall['total_acks'] as num?)?.toInt() ?? 0,
      overallResponseRate: (overall['overall_response_rate'] as num?)?.toDouble() ?? 0,
      avgAckTimeSecs: (overall['avg_ack_time_secs'] as num?)?.toDouble(),
      responseRateTrend: overall['response_rate_trend'] as String? ?? 'stable',
      perContact: ((j['per_contact'] as List?) ?? [])
          .cast<Map<String, dynamic>>()
          .map(ContactResponseRow.fromJson)
          .toList(),
    );
  }
}

class ContactResponseRow {
  const ContactResponseRow({
    required this.contactId,
    required this.notifiedCount,
    required this.ackedCount,
    required this.responseRate,
  });

  final String contactId;
  final int notifiedCount;
  final int ackedCount;
  final double responseRate;

  factory ContactResponseRow.fromJson(Map<String, dynamic> j) => ContactResponseRow(
        contactId: j['contact_id'] as String? ?? '',
        notifiedCount: (j['notified_count'] as num?)?.toInt() ?? 0,
        ackedCount: (j['acked_count'] as num?)?.toInt() ?? 0,
        responseRate: (j['response_rate'] as num?)?.toDouble() ?? 0,
      );
}

class DeviceHealthReport {
  const DeviceHealthReport({
    this.batteryDrainPctPerHour,
    this.memoryUsageMb,
    this.cpuUsagePct,
    this.appSizeMb,
    this.detectionCycleLatencyMs,
    this.lastCrashAt,
    this.appVersion,
    this.osVersion,
    this.deviceModel,
    this.lastReportedAt,
    this.reportCount,
  });

  final double? batteryDrainPctPerHour;
  final double? memoryUsageMb;
  final double? cpuUsagePct;
  final double? appSizeMb;
  final double? detectionCycleLatencyMs;
  final String? lastCrashAt;
  final String? appVersion;
  final String? osVersion;
  final String? deviceModel;
  final String? lastReportedAt;
  final int? reportCount;

  factory DeviceHealthReport.fromJson(Map<String, dynamic> j) => DeviceHealthReport(
        batteryDrainPctPerHour: (j['battery_drain_pct_per_hour'] as num?)?.toDouble(),
        memoryUsageMb: (j['memory_usage_mb'] as num?)?.toDouble(),
        cpuUsagePct: (j['cpu_usage_pct'] as num?)?.toDouble(),
        appSizeMb: (j['app_size_mb'] as num?)?.toDouble(),
        detectionCycleLatencyMs: (j['detection_cycle_latency_ms'] as num?)?.toDouble(),
        lastCrashAt: j['last_crash_at'] as String?,
        appVersion: j['app_version'] as String?,
        osVersion: j['os_version'] as String?,
        deviceModel: j['device_model'] as String?,
        lastReportedAt: j['last_reported_at'] as String?,
        reportCount: (j['report_count'] as num?)?.toInt(),
      );
}

Map<String, int> _intMap(dynamic raw) {
  if (raw == null) return {};
  return (raw as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as num).toInt()));
}

// ─── Service ────────────────────────────────────────────────────────────────

class AnalyticsApiService {
  const AnalyticsApiService(this._client);
  final ApiClient _client;

  Future<SosSummary> fetchSosSummary() async {
    final res = await _client.dio.get(ApiConfig.analyticsSosSummary);
    return SosSummary.fromJson(res.data as Map<String, dynamic>);
  }

  Future<DetectionAnalytics> fetchDetections() async {
    final res = await _client.dio.get(ApiConfig.analyticsDetections);
    return DetectionAnalytics.fromJson(res.data as Map<String, dynamic>);
  }

  Future<ContactResponseRate> fetchContactResponseRate() async {
    final res = await _client.dio.get(ApiConfig.analyticsContactResponseRate);
    return ContactResponseRate.fromJson(res.data as Map<String, dynamic>);
  }

  Future<DeviceHealthReport> fetchDeviceHealth() async {
    final res = await _client.dio.get(ApiConfig.analyticsDeviceHealth);
    return DeviceHealthReport.fromJson(res.data as Map<String, dynamic>);
  }

  /// POST /api/v1/analytics/device-health/ — all fields optional, only
  /// present ones are stored server-side.
  Future<void> reportDeviceHealth({
    double? batteryDrainPctPerHour,
    double? memoryUsageMb,
    double? cpuUsagePct,
    double? appSizeMb,
    double? detectionCycleLatencyMs,
    String? lastCrashAt,
    String? appVersion,
    String? osVersion,
    String? deviceModel,
  }) async {
    await _client.dio.post(ApiConfig.analyticsDeviceHealth, data: {
      if (batteryDrainPctPerHour != null)
        'battery_drain_pct_per_hour': batteryDrainPctPerHour,
      if (memoryUsageMb != null) 'memory_usage_mb': memoryUsageMb,
      if (cpuUsagePct != null) 'cpu_usage_pct': cpuUsagePct,
      if (appSizeMb != null) 'app_size_mb': appSizeMb,
      if (detectionCycleLatencyMs != null)
        'detection_cycle_latency_ms': detectionCycleLatencyMs,
      if (lastCrashAt != null) 'last_crash_at': lastCrashAt,
      if (appVersion != null) 'app_version': appVersion,
      if (osVersion != null) 'os_version': osVersion,
      if (deviceModel != null) 'device_model': deviceModel,
    });
  }
}
