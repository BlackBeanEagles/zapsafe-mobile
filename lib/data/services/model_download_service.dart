/// Day 56 — Model Download Service
///
/// Handles:
///   POST /api/v1/ml/model-downloads/  — report a successful .tflite download
///   GET  /api/v1/ml/model-downloads/  — fetch own download history
///
/// Both endpoints require authentication — every request rides on the
/// [ApiClient] that carries the Authorization header automatically.
library;

import 'package:dio/dio.dart';

import '../../core/constants/api_config.dart';
import 'api_client.dart';
import 'capability_report_service.dart'; // getOrCreateDeviceId

// ─── Model type enum ──────────────────────────────────────────────────────────

/// The four model types the backend accepts.
enum DownloadModelType {
  scream,
  motion,
  scene,
  dcs;

  /// Wire value sent to / received from the backend.
  String get value => name; // "scream" | "motion" | "scene" | "dcs"

  /// Human-readable label for UI display.
  String get label {
    switch (this) {
      case DownloadModelType.scream: return 'Scream';
      case DownloadModelType.motion: return 'Motion';
      case DownloadModelType.scene:  return 'Scene';
      case DownloadModelType.dcs:    return 'DCS Fusion';
    }
  }

  static DownloadModelType fromValue(String v) {
    return DownloadModelType.values.firstWhere(
      (e) => e.value == v,
      orElse: () => DownloadModelType.scream,
    );
  }
}

// ─── Data models ─────────────────────────────────────────────────────────────

/// One download record as returned by the backend.
class ModelDownloadRecord {
  const ModelDownloadRecord({
    required this.id,
    required this.deviceId,
    this.model,
    required this.modelName,
    required this.modelVersion,
    required this.modelType,
    required this.modelTypeDisplay,
    required this.downloadSizeBytes,
    required this.sha256Verified,
    required this.tier,
    required this.tierDisplay,
    required this.appVersion,
    required this.createdAt,
    this.installDurationMs,
  });

  final String id;
  final String deviceId;
  final String? model;           // UUID FK to MLModel — null until HF publish
  final String modelName;        // "scream_classifier_v1"
  final String modelVersion;     // "1.0.0"
  final DownloadModelType modelType;
  final String modelTypeDisplay; // "Scream Detection"
  final int downloadSizeBytes;
  final bool sha256Verified;
  final double? installDurationMs;
  final String tier;             // "high" | "medium" | "low"
  final String tierDisplay;
  final String appVersion;
  final DateTime createdAt;

  factory ModelDownloadRecord.fromJson(Map<String, dynamic> json) {
    return ModelDownloadRecord(
      id:                 json['id'] as String,
      deviceId:           json['device_id'] as String,
      model:              json['model'] as String?,
      modelName:          json['model_name'] as String,
      modelVersion:       json['model_version'] as String,
      modelType:          DownloadModelType.fromValue(json['model_type'] as String),
      modelTypeDisplay:   (json['model_type_display'] as String?) ?? '',
      downloadSizeBytes:  (json['download_size_bytes'] as int),
      sha256Verified:     (json['sha256_verified'] as bool?) ?? false,
      installDurationMs:  json['install_duration_ms'] != null
                              ? (json['install_duration_ms'] as num).toDouble()
                              : null,
      tier:               json['tier'] as String,
      tierDisplay:        (json['tier_display'] as String?) ?? '',
      appVersion:         (json['app_version'] as String?) ?? '',
      createdAt:          DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}

/// Response envelope from GET /api/v1/ml/model-downloads/.
class ModelDownloadHistory {
  const ModelDownloadHistory({
    required this.count,
    required this.downloads,
  });

  final int count;
  final List<ModelDownloadRecord> downloads;

  static const empty = ModelDownloadHistory(count: 0, downloads: []);
}

// ─── Service ──────────────────────────────────────────────────────────────────

/// Day 56 — reports model downloads and fetches download history.
class ModelDownloadService {
  const ModelDownloadService(this._client);

  final ApiClient _client;

  // ── POST ──────────────────────────────────────────────────────────────────

  /// Report a successful .tflite model download + install.
  ///
  /// [tier] reflects the device capability tier at download time
  /// (taken from [CapabilityProbeResult]).
  Future<ModelDownloadRecord> submit({
    required String modelName,
    required String modelVersion,
    required DownloadModelType modelType,
    required int downloadSizeBytes,
    required bool sha256Verified,
    required String tier,
    double? installDurationMs,
  }) async {
    final deviceId = await CapabilityReportService.getOrCreateDeviceId();

    final body = <String, dynamic>{
      'device_id':            deviceId,
      'model_name':           modelName,
      'model_version':        modelVersion,
      'model_type':           modelType.value,
      'download_size_bytes':  downloadSizeBytes,
      'sha256_verified':      sha256Verified,
      'tier':                 tier,
      'app_version':          '1.0.0+1',
      if (installDurationMs != null) 'install_duration_ms': installDurationMs,
    };

    final response = await _client.dio.post<Map<String, dynamic>>(
      ApiConfig.modelDownloads,
      data: body,
    );

    final data = response.data;
    if (data == null || response.statusCode != 201) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        message: 'Submit failed: HTTP ${response.statusCode}',
      );
    }

    return ModelDownloadRecord.fromJson(data);
  }

  // ── GET ───────────────────────────────────────────────────────────────────

  /// Fetch the authenticated user's own download records, newest first.
  Future<ModelDownloadHistory> fetchHistory({
    DownloadModelType? modelType,
    bool? sha256Verified,
  }) async {
    final params = <String, String>{};
    if (modelType != null)      params['model_type']     = modelType.value;
    if (sha256Verified != null) params['sha256_verified'] = sha256Verified.toString();

    final response = await _client.dio.get<Map<String, dynamic>>(
      ApiConfig.modelDownloads,
      queryParameters: params.isNotEmpty ? params : null,
    );

    final data = response.data;
    if (data == null) return ModelDownloadHistory.empty;

    final rawList = (data['downloads'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    return ModelDownloadHistory(
      count:     (data['count'] as int?) ?? rawList.length,
      downloads: rawList.map(ModelDownloadRecord.fromJson).toList(),
    );
  }
}
