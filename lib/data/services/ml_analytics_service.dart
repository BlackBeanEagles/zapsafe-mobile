/// Day 57 — ML Analytics Service
///
/// Handles:
///   GET /api/v1/ml/analytics/  — fetch aggregate ML telemetry stats
///
/// Authentication required — rides on [ApiClient].
library;

import '../../core/constants/api_config.dart';
import 'api_client.dart';

// ─── Data models ─────────────────────────────────────────────────────────────

/// Aggregate stats for detection events within the requested period.
class DetectionEventStats {
  const DetectionEventStats({
    required this.total,
    required this.byType,
    required this.sosTriggered,
    required this.sosRate,
    required this.avgConfidence,
    required this.byMode,
  });

  final int total;
  final Map<String, int> byType;      // {"scream": 45, "motion": 38, ...}
  final int sosTriggered;
  final double sosRate;               // 0.0–1.0
  final double? avgConfidence;        // null when total == 0
  final Map<String, int> byMode;      // {"ai": 98, "heuristic": 44}

  factory DetectionEventStats.fromJson(Map<String, dynamic> json) {
    return DetectionEventStats(
      total:          (json['total'] as int? ) ?? 0,
      byType:         _intMap(json['by_type']),
      sosTriggered:   (json['sos_triggered'] as int?) ?? 0,
      sosRate:        (json['sos_rate'] as num?)?.toDouble() ?? 0.0,
      avgConfidence:  json['avg_confidence'] != null
                          ? (json['avg_confidence'] as num).toDouble()
                          : null,
      byMode:         _intMap(json['by_mode']),
    );
  }

  static const empty = DetectionEventStats(
    total: 0, byType: {}, sosTriggered: 0,
    sosRate: 0.0, avgConfidence: null, byMode: {},
  );
}

/// Aggregate stats for device capability reports within the period.
class DeviceCapabilityStats {
  const DeviceCapabilityStats({
    required this.totalReports,
    required this.byTier,
    required this.avgInferenceMs,
    required this.byMode,
  });

  final int totalReports;
  final Map<String, int> byTier;      // {"high": 2, "medium": 1, "low": 0}
  final double? avgInferenceMs;       // null when totalReports == 0
  final Map<String, int> byMode;      // {"ai": 3, "heuristic": 0}

  factory DeviceCapabilityStats.fromJson(Map<String, dynamic> json) {
    return DeviceCapabilityStats(
      totalReports:   (json['total_reports'] as int?) ?? 0,
      byTier:         _intMap(json['by_tier']),
      avgInferenceMs: json['avg_inference_ms'] != null
                          ? (json['avg_inference_ms'] as num).toDouble()
                          : null,
      byMode:         _intMap(json['by_mode']),
    );
  }

  static const empty = DeviceCapabilityStats(
    totalReports: 0, byTier: {}, avgInferenceMs: null, byMode: {},
  );
}

/// Aggregate stats for model download records within the period.
class ModelDownloadStats {
  const ModelDownloadStats({
    required this.total,
    required this.byType,
    required this.sha256Verified,
    required this.sha256VerifiedRate,
    required this.totalBytes,
  });

  final int total;
  final Map<String, int> byType;      // {"scream": 3, "motion": 2, ...}
  final int sha256Verified;
  final double sha256VerifiedRate;    // 0.0–1.0
  final int totalBytes;

  factory ModelDownloadStats.fromJson(Map<String, dynamic> json) {
    return ModelDownloadStats(
      total:               (json['total'] as int?) ?? 0,
      byType:              _intMap(json['by_type']),
      sha256Verified:      (json['sha256_verified'] as int?) ?? 0,
      sha256VerifiedRate:  (json['sha256_verified_rate'] as num?)?.toDouble() ?? 0.0,
      totalBytes:          (json['total_bytes'] as int?) ?? 0,
    );
  }

  static const empty = ModelDownloadStats(
    total: 0, byType: {}, sha256Verified: 0,
    sha256VerifiedRate: 0.0, totalBytes: 0,
  );
}

/// Full analytics response from GET /api/v1/ml/analytics/.
class MLAnalyticsResult {
  const MLAnalyticsResult({
    required this.periodDays,
    required this.generatedAt,
    required this.detectionEvents,
    required this.deviceCapability,
    required this.modelDownloads,
  });

  final int periodDays;
  final DateTime generatedAt;
  final DetectionEventStats detectionEvents;
  final DeviceCapabilityStats deviceCapability;
  final ModelDownloadStats modelDownloads;

  factory MLAnalyticsResult.fromJson(Map<String, dynamic> json) {
    return MLAnalyticsResult(
      periodDays:       (json['period_days'] as int?) ?? 30,
      generatedAt:      DateTime.parse(json['generated_at'] as String).toLocal(),
      detectionEvents:  DetectionEventStats.fromJson(
                            json['detection_events'] as Map<String, dynamic>),
      deviceCapability: DeviceCapabilityStats.fromJson(
                            json['device_capability'] as Map<String, dynamic>),
      modelDownloads:   ModelDownloadStats.fromJson(
                            json['model_downloads'] as Map<String, dynamic>),
    );
  }
}

// ─── Service ──────────────────────────────────────────────────────────────────

/// Day 57 — fetches aggregate ML telemetry analytics.
class MLAnalyticsService {
  const MLAnalyticsService(this._client);

  final ApiClient _client;

  /// Fetch analytics for [days] days back (default 30, backend clamps 1–365).
  Future<MLAnalyticsResult> fetch({int days = 30}) async {
    final response = await _client.dio.get<Map<String, dynamic>>(
      ApiConfig.mlAnalytics,
      queryParameters: {'days': days},
    );

    final data = response.data;
    if (data == null) {
      throw Exception('Analytics: empty response from server.');
    }

    return MLAnalyticsResult.fromJson(data);
  }
}

// ─── Internal helper ──────────────────────────────────────────────────────────

Map<String, int> _intMap(dynamic raw) {
  if (raw is! Map) return const {};
  return raw.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
}
