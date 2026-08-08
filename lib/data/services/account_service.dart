/// Day 147-158 backend — `/api/v1/account/*` DPDP surface, wired here for
/// Play Store item 10 (see zapsafe_backend/account/views.py for the real,
/// tested server implementation this mirrors).
///
/// Was: this backend surface has been real, live, and fully test-covered
/// since Day 147-158, but no Dart service ever called it — confirmed
/// repeatedly by this app's own self-audits (Day 301 backend integration
/// audit, Day 337 legal blockers live, Day 383 privacy audit followup,
/// Day 384 DPDP sign-off — all found `find lib/data/services -iname
/// '*account*'` returns nothing). A real Day 336/361 P1 finding.
///
/// Deliberately covers only consent / sessions / retention here — NOT
/// export-request or delete-request. Day 337's own audit already found
/// those two DPDP rights (data portability, right to erasure) fully live
/// end-to-end via the OLDER `/api/v1/data-export/` (Day 69,
/// `data_export_providers.dart`) and `/api/v1/privacy/deletion-request/`
/// (Day 70, `privacy_service.dart`) endpoints — wiring the newer Day 147
/// paths too would duplicate working functionality with no compliance
/// benefit, exactly the "do not wire" recommendation that audit reached.
///
///   GET /api/v1/account/consent/                    → UserConsent (200)
///   PUT /api/v1/account/consent/                     → {status} (200 | 400)
///   GET /api/v1/account/sessions/                    → sessions list (200)
///   DELETE /api/v1/account/sessions/<id>/             → 204 | 400 | 404
///   POST /api/v1/account/sessions/revoke-all/         → {revoked_count} (200)
///   GET /api/v1/account/retention/                    → RetentionPreference (200)
///   PUT /api/v1/account/retention/                    → RetentionPreference (200 | 400 | 403)
///   POST /api/v1/account/retention/purge-now/         → {purged_count} (200)
library;

import '../../core/constants/api_config.dart';
import 'api_client.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

/// Mirrors account.models.UserConsent.as_contract_dict() exactly —
/// zapsafe_backend/account/models.py.
class UserConsent {
  const UserConsent({
    required this.locationSos,
    required this.evidenceRecording,
    required this.cloudBackup,
    required this.heatmapContribution,
    required this.analytics,
    required this.modelImprovement,
    required this.updatedAt,
  });

  final bool locationSos; // server-enforced non-optional; PUT with false is rejected
  final bool evidenceRecording;
  final bool cloudBackup;
  final bool heatmapContribution;
  final bool analytics;
  final bool modelImprovement;
  final DateTime updatedAt;

  factory UserConsent.fromJson(Map<String, dynamic> j) => UserConsent(
        locationSos:          j['location_sos'] as bool,
        evidenceRecording:    j['evidence_recording'] as bool,
        cloudBackup:          j['cloud_backup'] as bool,
        heatmapContribution:  j['heatmap_contribution'] as bool,
        analytics:            j['analytics'] as bool,
        modelImprovement:     j['model_improvement'] as bool,
        updatedAt:            DateTime.parse(j['updated_at'] as String).toLocal(),
      );

  UserConsent copyWith({
    bool? locationSos,
    bool? evidenceRecording,
    bool? cloudBackup,
    bool? heatmapContribution,
    bool? analytics,
    bool? modelImprovement,
  }) =>
      UserConsent(
        locationSos:         locationSos         ?? this.locationSos,
        evidenceRecording:   evidenceRecording   ?? this.evidenceRecording,
        cloudBackup:         cloudBackup         ?? this.cloudBackup,
        heatmapContribution: heatmapContribution ?? this.heatmapContribution,
        analytics:           analytics           ?? this.analytics,
        modelImprovement:    modelImprovement    ?? this.modelImprovement,
        updatedAt:           updatedAt,
      );
}

/// Mirrors AccountApp's SessionListView entry shape exactly.
class UserSession {
  const UserSession({
    required this.id,
    required this.deviceName,
    required this.platform,
    required this.ipCity,
    required this.lastActive,
    required this.createdAt,
    required this.isCurrent,
  });

  final String id;
  final String deviceName;
  final String platform;
  final String? ipCity;
  final DateTime lastActive;
  final DateTime createdAt;
  final bool isCurrent;

  factory UserSession.fromJson(Map<String, dynamic> j) => UserSession(
        id:          j['id'] as String,
        deviceName:  j['device_name'] as String,
        platform:    j['platform'] as String,
        ipCity:      j['ip_city'] as String?,
        lastActive:  DateTime.parse(j['last_active'] as String).toLocal(),
        createdAt:   DateTime.parse(j['created_at'] as String).toLocal(),
        isCurrent:   j['is_current'] as bool,
      );
}

/// Mirrors account.models.RetentionPreference.as_contract_dict() exactly.
class RetentionPreference {
  const RetentionPreference({
    required this.evidenceDays,
    required this.gpsDays,
    required this.updatedAt,
  });

  final int evidenceDays; // one of 7 / 30 / 90 (90 requires premium)
  final int gpsDays;
  final DateTime updatedAt;

  factory RetentionPreference.fromJson(Map<String, dynamic> j) => RetentionPreference(
        evidenceDays: j['evidence_days'] as int,
        gpsDays:      j['gps_days'] as int,
        updatedAt:    DateTime.parse(j['updated_at'] as String).toLocal(),
      );
}

/// Mirrors AuditLogView's entry shape exactly — account/views.py. Real
/// fields are much sparser than the account-scoped audit UI's own
/// mock data assumed (no per-entry "actor"/"device"/"location"/
/// "suspicious"/granular data-category — just a bucketed [type], a
/// human-readable [description] the server already composed, a
/// [timestamp], and a raw [metadata] map for whatever detail the
/// server captured for that specific event type).
class AccountAuditEntry {
  const AccountAuditEntry({
    required this.id,
    required this.type,
    required this.description,
    required this.timestamp,
    required this.metadata,
  });

  final String id;
  /// One of the 5 bucketed values AuditLogView maps to ('login',
  /// 'location_share', 'evidence_export', 'sos', 'consent_change') OR
  /// a raw internal event_type string (e.g. 'session_revoked',
  /// 'account_deletion_requested') for anything outside that bucket —
  /// the real backend deliberately still surfaces those rather than
  /// drop them, so this field is NOT a closed enum on the wire.
  final String type;
  final String description;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  factory AccountAuditEntry.fromJson(Map<String, dynamic> j) => AccountAuditEntry(
        id:          j['id'] as String,
        type:        j['type'] as String,
        description: j['description'] as String,
        timestamp:   DateTime.parse(j['timestamp'] as String).toLocal(),
        metadata:    (j['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
}

/// One page of [AccountAuditEntry] results, mirroring AuditLogView's real
/// page-based response shape ({entries, page, has_more} — not
/// offset/limit like the older /api/v1/audit-log/).
class AccountAuditLogPage {
  const AccountAuditLogPage({
    required this.entries,
    required this.page,
    required this.hasMore,
  });

  final List<AccountAuditEntry> entries;
  final int page;
  final bool hasMore;
}

// ─── Service ──────────────────────────────────────────────────────────────────

class AccountService {
  const AccountService(this._client);
  final ApiClient _client;

  /// GET /api/v1/account/consent/
  Future<UserConsent> fetchConsent() async {
    final r = await _client.dio.get<Map<String, dynamic>>(ApiConfig.accountConsent);
    return UserConsent.fromJson(r.data!);
  }

  /// PUT /api/v1/account/consent/ — only send changed fields; the server
  /// rejects `location_sos: false` with 400 LOCATION_SOS_REQUIRED, which
  /// surfaces as a normal [ApiError] through [ApiClient]'s error
  /// interceptor — callers don't need special handling beyond that.
  Future<void> putConsent({
    bool? locationSos,
    bool? evidenceRecording,
    bool? cloudBackup,
    bool? heatmapContribution,
    bool? analytics,
    bool? modelImprovement,
  }) async {
    final body = <String, dynamic>{};
    if (locationSos != null) body['location_sos'] = locationSos;
    if (evidenceRecording != null) body['evidence_recording'] = evidenceRecording;
    if (cloudBackup != null) body['cloud_backup'] = cloudBackup;
    if (heatmapContribution != null) body['heatmap_contribution'] = heatmapContribution;
    if (analytics != null) body['analytics'] = analytics;
    if (modelImprovement != null) body['model_improvement'] = modelImprovement;
    await _client.dio.put<Map<String, dynamic>>(ApiConfig.accountConsent, data: body);
  }

  /// GET /api/v1/account/sessions/
  Future<List<UserSession>> fetchSessions() async {
    final r = await _client.dio.get<Map<String, dynamic>>(ApiConfig.accountSessions);
    final list = (r.data!['sessions'] as List).cast<Map<String, dynamic>>();
    return list.map(UserSession.fromJson).toList();
  }

  /// DELETE /api/v1/account/sessions/<id>/  → 204
  Future<void> revokeSession(String sessionId) async {
    await _client.dio.delete<void>(ApiConfig.accountSessionRevokeFor(sessionId));
  }

  /// POST /api/v1/account/sessions/revoke-all/  → count of sessions revoked
  Future<int> revokeAllOtherSessions() async {
    final r = await _client.dio
        .post<Map<String, dynamic>>(ApiConfig.accountSessionsRevokeAll);
    return r.data!['revoked_count'] as int;
  }

  /// GET /api/v1/account/retention/
  Future<RetentionPreference> fetchRetention() async {
    final r = await _client.dio.get<Map<String, dynamic>>(ApiConfig.accountRetention);
    return RetentionPreference.fromJson(r.data!);
  }

  /// PUT /api/v1/account/retention/ — server rejects `90` with 403
  /// RETENTION_90_REQUIRES_PREMIUM for non-premium accounts; surfaces as
  /// a normal [ApiError], same as consent's validation errors.
  Future<RetentionPreference> putRetention({int? evidenceDays, int? gpsDays}) async {
    final body = <String, dynamic>{};
    if (evidenceDays != null) body['evidence_days'] = evidenceDays;
    if (gpsDays != null) body['gps_days'] = gpsDays;
    final r = await _client.dio.put<Map<String, dynamic>>(
      ApiConfig.accountRetention,
      data: body,
    );
    return RetentionPreference.fromJson(r.data!);
  }

  /// POST /api/v1/account/retention/purge-now/ → count of files purged
  Future<int> purgeRetentionNow() async {
    final r = await _client.dio
        .post<Map<String, dynamic>>(ApiConfig.accountRetentionPurgeNow);
    return r.data!['purged_count'] as int;
  }

  /// GET /api/v1/account/audit-log/?type=&page=
  /// [type] filters by the bucketed value ('login', 'sos', etc.) or
  /// 'all' (the server's own default). Page 1-indexed, matching the
  /// real backend's own convention.
  Future<AccountAuditLogPage> fetchAuditLog({String type = 'all', int page = 1}) async {
    final r = await _client.dio.get<Map<String, dynamic>>(
      ApiConfig.accountAuditLog,
      queryParameters: {'type': type, 'page': page},
    );
    final data = r.data!;
    final entries = (data['entries'] as List)
        .cast<Map<String, dynamic>>()
        .map(AccountAuditEntry.fromJson)
        .toList();
    return AccountAuditLogPage(
      entries: entries,
      page: data['page'] as int,
      hasMore: data['has_more'] as bool,
    );
  }
}
