/// Day 63 — Alert Threshold Service
///
/// GET    /api/v1/alert-thresholds/        → {count, thresholds:[...]}  (200)
/// POST   /api/v1/alert-thresholds/        → AlertThreshold             (201)
/// GET    /api/v1/alert-thresholds/<uuid>/ → AlertThreshold             (200)
/// PATCH  /api/v1/alert-thresholds/<uuid>/ → AlertThreshold             (200)
/// DELETE /api/v1/alert-thresholds/<uuid>/ →                            (204)
library;

import '../../core/constants/api_config.dart';
import 'api_client.dart';

// ─── Enum ─────────────────────────────────────────────────────────────────────

enum AlertModelType {
  scream('scream', 'Scream'),
  motion('motion', 'Motion'),
  scene('scene',   'Scene'),
  dcs('dcs',       'DCS Fusion');

  const AlertModelType(this.value, this.label);
  final String value;
  final String label;

  static AlertModelType fromValue(String v) =>
      AlertModelType.values.firstWhere((e) => e.value == v,
          orElse: () => AlertModelType.scream);
}

// ─── Model ────────────────────────────────────────────────────────────────────

class AlertThreshold {
  const AlertThreshold({
    required this.id,
    required this.modelType,
    required this.minConfidence,
    required this.consecutiveTriggers,
    required this.cooldownSeconds,
    required this.autoSos,
    required this.notifyContacts,
    required this.isActive,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.maxLatencyMs,
  });

  final String   id;
  final String   modelType;
  final double   minConfidence;
  final double?  maxLatencyMs;
  final int      consecutiveTriggers;
  final int      cooldownSeconds;
  final bool     autoSos;
  final bool     notifyContacts;
  final bool     isActive;
  final String   notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory AlertThreshold.fromJson(Map<String, dynamic> j) => AlertThreshold(
        id:                   j['id']                    as String,
        modelType:            j['model_type']            as String,
        minConfidence:        (j['min_confidence']       as num).toDouble(),
        maxLatencyMs:         (j['max_latency_ms']       as num?)?.toDouble(),
        consecutiveTriggers:  (j['consecutive_triggers'] as num).toInt(),
        cooldownSeconds:      (j['cooldown_seconds']     as num).toInt(),
        autoSos:              j['auto_sos']              as bool,
        notifyContacts:       j['notify_contacts']       as bool,
        isActive:             j['is_active']             as bool,
        notes:                (j['notes']                as String?) ?? '',
        createdAt:            DateTime.parse(j['created_at'] as String).toLocal(),
        updatedAt:            DateTime.parse(j['updated_at'] as String).toLocal(),
      );
}

// ─── Service ──────────────────────────────────────────────────────────────────

class AlertThresholdService {
  const AlertThresholdService(this._client);
  final ApiClient _client;

  /// GET /api/v1/alert-thresholds/?is_active=<true|false>
  Future<List<AlertThreshold>> fetchAll({String isActive = ''}) async {
    final params = <String, dynamic>{};
    if (isActive.isNotEmpty) params['is_active'] = isActive;

    final r = await _client.dio.get<Map<String, dynamic>>(
      ApiConfig.alertThresholds,
      queryParameters: params.isEmpty ? null : params,
    );
    final data = r.data;
    if (data == null) return [];
    final raw = (data['thresholds'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    return raw.map(AlertThreshold.fromJson).toList();
  }

  /// POST /api/v1/alert-thresholds/ — create a new threshold.
  Future<AlertThreshold> create({
    required String modelType,
    required double minConfidence,
    required int    consecutiveTriggers,
    required int    cooldownSeconds,
    required bool   autoSos,
    required bool   notifyContacts,
    double?         maxLatencyMs,
    bool            isActive = true,
    String          notes    = '',
  }) async {
    final data = <String, dynamic>{
      'model_type':           modelType,
      'min_confidence':       minConfidence,
      'consecutive_triggers': consecutiveTriggers,
      'cooldown_seconds':     cooldownSeconds,
      'auto_sos':             autoSos,
      'notify_contacts':      notifyContacts,
      'is_active':            isActive,
      'notes':                notes,
    };
    if (maxLatencyMs != null) data['max_latency_ms'] = maxLatencyMs;

    final r = await _client.dio.post<Map<String, dynamic>>(
      ApiConfig.alertThresholds,
      data: data,
    );
    return AlertThreshold.fromJson(r.data!);
  }

  /// PATCH /api/v1/alert-thresholds/<uuid>/
  Future<AlertThreshold> update(
    String id, {
    double? minConfidence,
    double? maxLatencyMs,
    int?    consecutiveTriggers,
    int?    cooldownSeconds,
    bool?   autoSos,
    bool?   notifyContacts,
    bool?   isActive,
    String? notes,
  }) async {
    final data = <String, dynamic>{};
    if (minConfidence        != null) data['min_confidence']       = minConfidence;
    if (maxLatencyMs         != null) data['max_latency_ms']       = maxLatencyMs;
    if (consecutiveTriggers  != null) data['consecutive_triggers'] = consecutiveTriggers;
    if (cooldownSeconds      != null) data['cooldown_seconds']     = cooldownSeconds;
    if (autoSos              != null) data['auto_sos']             = autoSos;
    if (notifyContacts       != null) data['notify_contacts']      = notifyContacts;
    if (isActive             != null) data['is_active']            = isActive;
    if (notes                != null) data['notes']                = notes;

    final r = await _client.dio.patch<Map<String, dynamic>>(
      '${ApiConfig.alertThresholds}$id/',
      data: data,
    );
    return AlertThreshold.fromJson(r.data!);
  }

  /// DELETE /api/v1/alert-thresholds/<uuid>/ → 204
  Future<void> delete(String id) async {
    await _client.dio.delete<void>('${ApiConfig.alertThresholds}$id/');
  }
}
