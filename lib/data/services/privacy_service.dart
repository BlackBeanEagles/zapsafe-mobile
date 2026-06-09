/// Day 70 — Privacy & Consent Service
///
/// GET   /api/v1/privacy/                   → PrivacySettings  (200)
/// PATCH /api/v1/privacy/                   → PrivacySettings  (200)
/// POST  /api/v1/privacy/deletion-request/  → DeletionRequest  (201)
/// GET   /api/v1/privacy/deletion-request/  → DeletionRequest  (200 | 404)
/// DELETE /api/v1/privacy/deletion-request/ → 204 | 400 | 404
library;

import 'package:dio/dio.dart';

import '../../core/constants/api_config.dart';
import '../models/auth_models.dart';
import 'api_client.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

class PrivacySettings {
  const PrivacySettings({
    required this.analyticsOptedIn,
    required this.autoArchiveDisabled,
    required this.evidenceCaptureConsent,
  });

  final bool analyticsOptedIn;
  final bool autoArchiveDisabled;
  final bool evidenceCaptureConsent;

  PrivacySettings copyWith({
    bool? analyticsOptedIn,
    bool? autoArchiveDisabled,
    bool? evidenceCaptureConsent,
  }) =>
      PrivacySettings(
        analyticsOptedIn:       analyticsOptedIn       ?? this.analyticsOptedIn,
        autoArchiveDisabled:    autoArchiveDisabled    ?? this.autoArchiveDisabled,
        evidenceCaptureConsent: evidenceCaptureConsent ?? this.evidenceCaptureConsent,
      );

  factory PrivacySettings.fromJson(Map<String, dynamic> j) => PrivacySettings(
        analyticsOptedIn:       j['analytics_opted_in']       as bool,
        autoArchiveDisabled:    j['auto_archive_disabled']    as bool,
        evidenceCaptureConsent: j['evidence_capture_consent'] as bool,
      );

  static const defaults = PrivacySettings(
    analyticsOptedIn:       false,
    autoArchiveDisabled:    false,
    evidenceCaptureConsent: false,
  );
}

// ─────────────────────────────────────────────────────────────────────────────

class DeletionRequest {
  const DeletionRequest({
    required this.id,
    required this.status,
    required this.reason,
    required this.isCancellable,
    required this.requestedAt,
  });

  final String   id;
  final String   status;        // pending | acknowledged | completed | cancelled
  final String   reason;
  final bool     isCancellable;
  final DateTime requestedAt;

  bool get isPending      => status == 'pending';
  bool get isAcknowledged => status == 'acknowledged';
  bool get isCompleted    => status == 'completed';

  factory DeletionRequest.fromJson(Map<String, dynamic> j) => DeletionRequest(
        id:            j['id']             as String,
        status:        j['status']         as String,
        reason:        (j['reason'] as String?) ?? '',
        isCancellable: j['is_cancellable'] as bool,
        requestedAt:   DateTime.parse(j['requested_at'] as String).toLocal(),
      );
}

// ─── Service ──────────────────────────────────────────────────────────────────

class PrivacyService {
  const PrivacyService(this._client);
  final ApiClient _client;

  /// GET /api/v1/privacy/
  Future<PrivacySettings> fetchSettings() async {
    final r = await _client.dio.get<Map<String, dynamic>>(ApiConfig.privacy);
    return PrivacySettings.fromJson(r.data!);
  }

  /// PATCH /api/v1/privacy/  — only send changed fields.
  Future<PrivacySettings> patchSettings({
    bool? analyticsOptedIn,
    bool? autoArchiveDisabled,
    bool? evidenceCaptureConsent,
  }) async {
    final body = <String, dynamic>{};
    if (analyticsOptedIn != null) {
      body['analytics_opted_in'] = analyticsOptedIn;
    }
    if (autoArchiveDisabled != null) {
      body['auto_archive_disabled'] = autoArchiveDisabled;
    }
    if (evidenceCaptureConsent != null) {
      body['evidence_capture_consent'] = evidenceCaptureConsent;
    }
    final r = await _client.dio.patch<Map<String, dynamic>>(
      ApiConfig.privacy,
      data: body,
    );
    return PrivacySettings.fromJson(r.data!);
  }

  /// GET /api/v1/privacy/deletion-request/
  /// Returns null when the server responds with 404 (no active request).
  Future<DeletionRequest?> fetchDeletion() async {
    try {
      final r = await _client.dio.get<Map<String, dynamic>>(
          ApiConfig.privacyDeletion);
      return DeletionRequest.fromJson(r.data!);
    } on DioException catch (e) {
      final err = e.error;
      if (err is ApiError && err.statusCode == 404) return null;
      rethrow;
    }
  }

  /// POST /api/v1/privacy/deletion-request/
  Future<DeletionRequest> createDeletion({String? reason}) async {
    final body = <String, dynamic>{};
    if (reason != null && reason.trim().isNotEmpty) {
      body['reason'] = reason.trim();
    }
    final r = await _client.dio.post<Map<String, dynamic>>(
      ApiConfig.privacyDeletion,
      data: body,
    );
    return DeletionRequest.fromJson(r.data!);
  }

  /// DELETE /api/v1/privacy/deletion-request/  → 204
  Future<void> cancelDeletion() async {
    await _client.dio.delete<void>(ApiConfig.privacyDeletion);
  }
}
