/// Day 61 — Inference Log Service
///
/// POST /api/v1/ml/inference-logs/        → {id}   (201)
/// GET  /api/v1/ml/inference-logs/        → [InferenceLogHistory]
/// GET  /api/v1/ml/inference-logs/stats/  → [InferenceLogStats]
library;

import '../../core/constants/api_config.dart';
import 'api_client.dart';

// ─── Enums / constants ────────────────────────────────────────────────────────

enum InfModelType {
  scream('scream', 'Scream'),
  motion('motion', 'Motion'),
  scene('scene',   'Scene'),
  dcs('dcs',       'DCS Fusion');

  const InfModelType(this.value, this.label);
  final String value;
  final String label;
}

enum InfDetectionMode {
  ai('ai',             'AI (TFLite)'),
  heuristic('heuristic', 'Heuristic');

  const InfDetectionMode(this.value, this.label);
  final String value;
  final String label;
}

enum InfTier {
  high('high',     'High (<100 ms)'),
  medium('medium', 'Medium (100–500 ms)'),
  low('low',       'Low (≥500 ms)');

  const InfTier(this.value, this.label);
  final String value;
  final String label;
}

// ─── Data models ──────────────────────────────────────────────────────────────

class InferenceLogEntry {
  const InferenceLogEntry({
    required this.id,
    required this.deviceId,
    required this.modelName,
    required this.modelType,
    required this.detectionMode,
    required this.tier,
    required this.inferenceMs,
    required this.confidence,
    required this.label,
    required this.triggeredSos,
    required this.appVersion,
    required this.createdAt,
  });

  final String   id;
  final String   deviceId;
  final String   modelName;
  final String   modelType;
  final String   detectionMode;
  final String   tier;
  final double   inferenceMs;
  final double   confidence;
  final String   label;
  final bool     triggeredSos;
  final String   appVersion;
  final DateTime createdAt;

  factory InferenceLogEntry.fromJson(Map<String, dynamic> j) =>
      InferenceLogEntry(
        id:           j['id']             as String,
        deviceId:     j['device_id']      as String,
        modelName:    j['model_name']     as String,
        modelType:    j['model_type']     as String,
        detectionMode: j['detection_mode'] as String,
        tier:         j['tier']           as String,
        inferenceMs:  (j['inference_ms']  as num).toDouble(),
        confidence:   (j['confidence']    as num).toDouble(),
        label:        (j['label']         as String?) ?? '',
        triggeredSos: j['triggered_sos']  as bool,
        appVersion:   (j['app_version']   as String?) ?? '',
        createdAt:    DateTime.parse(j['created_at'] as String).toLocal(),
      );
}

class InferenceLogHistory {
  const InferenceLogHistory({
    required this.count,
    required this.days,
    required this.logs,
  });

  final int                    count;
  final int                    days;
  final List<InferenceLogEntry> logs;

  static const empty = InferenceLogHistory(count: 0, days: 7, logs: []);
}

class ModelStatEntry {
  const ModelStatEntry({
    required this.modelType,
    required this.modelName,
    required this.count,
    required this.avgMs,
    required this.p50Ms,
    required this.p95Ms,
    required this.maxMs,
    required this.avgConfidence,
    required this.sosRate,
  });

  final String  modelType;
  final String  modelName;
  final int     count;
  final double? avgMs;
  final double? p50Ms;
  final double? p95Ms;
  final double? maxMs;
  final double? avgConfidence;
  final double  sosRate;

  factory ModelStatEntry.fromJson(Map<String, dynamic> j) => ModelStatEntry(
        modelType:    j['model_type']     as String,
        modelName:    j['model_name']     as String,
        count:        (j['count']         as num).toInt(),
        avgMs:        (j['avg_ms']        as num?)?.toDouble(),
        p50Ms:        (j['p50_ms']        as num?)?.toDouble(),
        p95Ms:        (j['p95_ms']        as num?)?.toDouble(),
        maxMs:        (j['max_ms']        as num?)?.toDouble(),
        avgConfidence: (j['avg_confidence'] as num?)?.toDouble(),
        sosRate:      (j['sos_rate']      as num?)?.toDouble() ?? 0.0,
      );
}

class InferenceLogStats {
  const InferenceLogStats({
    required this.periodDays,
    required this.totalCount,
    required this.globalAvgMs,
    required this.globalP50Ms,
    required this.globalP95Ms,
    required this.byModel,
  });

  final int                 periodDays;
  final int                 totalCount;
  final double?             globalAvgMs;
  final double?             globalP50Ms;
  final double?             globalP95Ms;
  final List<ModelStatEntry> byModel;

  static const empty = InferenceLogStats(
    periodDays:  7,
    totalCount:  0,
    globalAvgMs: null,
    globalP50Ms: null,
    globalP95Ms: null,
    byModel:     [],
  );

  factory InferenceLogStats.fromJson(Map<String, dynamic> j) =>
      InferenceLogStats(
        periodDays:  (j['period_days'] as num).toInt(),
        totalCount:  (j['total_count'] as num).toInt(),
        globalAvgMs: (j['global_avg_ms'] as num?)?.toDouble(),
        globalP50Ms: (j['global_p50_ms'] as num?)?.toDouble(),
        globalP95Ms: (j['global_p95_ms'] as num?)?.toDouble(),
        byModel:     (j['by_model'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(ModelStatEntry.fromJson)
            .toList(),
      );
}

// ─── Service ──────────────────────────────────────────────────────────────────

class InferenceLogService {
  const InferenceLogService(this._client);
  final ApiClient _client;

  /// POST /api/v1/ml/inference-logs/ — submit one inference telemetry record.
  Future<String> submit({
    required String   deviceId,
    required String   modelName,
    required String   modelType,
    required String   detectionMode,
    required String   tier,
    required double   inferenceMs,
    required double   confidence,
    String            label        = '',
    bool              triggeredSos = false,
    String            appVersion   = '',
  }) async {
    final r = await _client.dio.post<Map<String, dynamic>>(
      ApiConfig.inferenceLogs,
      data: {
        'device_id':      deviceId,
        'model_name':     modelName,
        'model_type':     modelType,
        'detection_mode': detectionMode,
        'tier':           tier,
        'inference_ms':   inferenceMs,
        'confidence':     confidence,
        'label':          label,
        'triggered_sos':  triggeredSos,
        'app_version':    appVersion,
      },
    );
    return r.data!['id'] as String;
  }

  /// GET /api/v1/ml/inference-logs/?days=N&model_type=X
  Future<InferenceLogHistory> fetchHistory({
    int    days      = 7,
    String modelType = '',
  }) async {
    final params = <String, dynamic>{'days': days};
    if (modelType.isNotEmpty) params['model_type'] = modelType;

    final r = await _client.dio.get<Map<String, dynamic>>(
      ApiConfig.inferenceLogs,
      queryParameters: params,
    );
    final data = r.data;
    if (data == null) return InferenceLogHistory.empty;
    final raw = (data['logs'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    return InferenceLogHistory(
      count: (data['count'] as int?) ?? raw.length,
      days:  (data['days']  as int?) ?? days,
      logs:  raw.map(InferenceLogEntry.fromJson).toList(),
    );
  }

  /// GET /api/v1/ml/inference-logs/stats/?days=N&model_type=X
  Future<InferenceLogStats> fetchStats({
    int    days      = 7,
    String modelType = '',
  }) async {
    final params = <String, dynamic>{'days': days};
    if (modelType.isNotEmpty) params['model_type'] = modelType;

    final r = await _client.dio.get<Map<String, dynamic>>(
      ApiConfig.inferenceLogsStats,
      queryParameters: params,
    );
    if (r.data == null) return InferenceLogStats.empty;
    return InferenceLogStats.fromJson(r.data!);
  }
}
