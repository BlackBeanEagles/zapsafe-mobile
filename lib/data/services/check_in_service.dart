/// Day 65 — Safety Check-in Timer Service
///
/// POST /api/v1/check-ins/                     → CheckInDetail  (201)
/// GET  /api/v1/check-ins/                     → {count, check_ins:[...]}  (200)
/// GET  /api/v1/check-ins/<uuid>/              → CheckInDetail  (200)
/// POST /api/v1/check-ins/<uuid>/check-in/     → CheckInDetail  (200)
/// POST /api/v1/check-ins/<uuid>/cancel/       → CheckInDetail  (200)
/// POST /api/v1/check-ins/<uuid>/expire/       → CheckInDetail  (200)
library;

import '../../core/constants/api_config.dart';
import 'api_client.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

class CheckInListEntry {
  const CheckInListEntry({
    required this.id,
    required this.label,
    required this.durationMinutes,
    required this.status,
    required this.isOverdue,
    required this.remainingSeconds,
    required this.expiresAt,
    required this.createdAt,
    this.checkedInAt,
  });

  final String   id;
  final String   label;
  final int      durationMinutes;
  final String   status;
  final bool     isOverdue;
  final int      remainingSeconds;
  final DateTime expiresAt;
  final DateTime createdAt;
  final DateTime? checkedInAt;

  factory CheckInListEntry.fromJson(Map<String, dynamic> j) =>
      CheckInListEntry(
        id:               j['id']                as String,
        label:            (j['label'] as String?) ?? '',
        durationMinutes:  (j['duration_minutes'] as num).toInt(),
        status:           j['status']            as String,
        isOverdue:        j['is_overdue']         as bool,
        remainingSeconds: (j['remaining_seconds'] as num).toInt(),
        expiresAt:  DateTime.parse(j['expires_at']  as String).toLocal(),
        createdAt:  DateTime.parse(j['created_at']  as String).toLocal(),
        checkedInAt: j['checked_in_at'] == null
            ? null
            : DateTime.parse(j['checked_in_at'] as String).toLocal(),
      );
}

class CheckInDetail {
  const CheckInDetail({
    required this.id,
    required this.label,
    required this.durationMinutes,
    required this.status,
    required this.isOverdue,
    required this.remainingSeconds,
    required this.startedAt,
    required this.expiresAt,
    required this.createdAt,
    required this.notes,
    this.escalationPolicy,
    this.checkedInAt,
  });

  final String   id;
  final String   label;
  final int      durationMinutes;
  final String   status;
  final bool     isOverdue;
  final int      remainingSeconds;
  final DateTime startedAt;
  final DateTime expiresAt;
  final DateTime createdAt;
  final String   notes;
  final String?  escalationPolicy;
  final DateTime? checkedInAt;

  factory CheckInDetail.fromJson(Map<String, dynamic> j) => CheckInDetail(
        id:               j['id']                as String,
        label:            (j['label'] as String?) ?? '',
        durationMinutes:  (j['duration_minutes'] as num).toInt(),
        status:           j['status']            as String,
        isOverdue:        j['is_overdue']         as bool,
        remainingSeconds: (j['remaining_seconds'] as num).toInt(),
        startedAt:  DateTime.parse(j['started_at']  as String).toLocal(),
        expiresAt:  DateTime.parse(j['expires_at']  as String).toLocal(),
        createdAt:  DateTime.parse(j['created_at']  as String).toLocal(),
        notes:            (j['notes'] as String?) ?? '',
        escalationPolicy: j['escalation_policy'] as String?,
        checkedInAt: j['checked_in_at'] == null
            ? null
            : DateTime.parse(j['checked_in_at'] as String).toLocal(),
      );
}

// ─── Service ──────────────────────────────────────────────────────────────────

class CheckInService {
  const CheckInService(this._client);
  final ApiClient _client;

  /// GET /api/v1/check-ins/?status=<filter>&days=<N>
  Future<List<CheckInListEntry>> fetchAll({
    String status = '',
    int?   days,
  }) async {
    final params = <String, dynamic>{};
    if (status.isNotEmpty) params['status'] = status;
    if (days != null)       params['days']   = days;

    final r = await _client.dio.get<Map<String, dynamic>>(
      ApiConfig.checkIns,
      queryParameters: params.isEmpty ? null : params,
    );
    final data = r.data;
    if (data == null) return [];
    final raw = (data['check_ins'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    return raw.map(CheckInListEntry.fromJson).toList();
  }

  /// POST /api/v1/check-ins/ — start a new check-in timer.
  Future<CheckInDetail> create({
    required int   durationMinutes,
    String         label             = '',
    String?        escalationPolicy,
    String         notes             = '',
  }) async {
    final data = <String, dynamic>{
      'duration_minutes': durationMinutes,
      'label':            label,
      'notes':            notes,
    };
    if (escalationPolicy != null) data['escalation_policy'] = escalationPolicy;

    final r = await _client.dio.post<Map<String, dynamic>>(
      ApiConfig.checkIns,
      data: data,
    );
    return CheckInDetail.fromJson(r.data!);
  }

  /// POST /api/v1/check-ins/<uuid>/check-in/ — mark as safe.
  Future<CheckInDetail> checkIn(String id) async {
    final r = await _client.dio.post<Map<String, dynamic>>(
      '${ApiConfig.checkIns}$id/check-in/',
    );
    return CheckInDetail.fromJson(r.data!);
  }

  /// POST /api/v1/check-ins/<uuid>/cancel/ — cancel timer.
  Future<CheckInDetail> cancel(String id) async {
    final r = await _client.dio.post<Map<String, dynamic>>(
      '${ApiConfig.checkIns}$id/cancel/',
    );
    return CheckInDetail.fromJson(r.data!);
  }

  /// POST /api/v1/check-ins/<uuid>/expire/ — mark as expired.
  Future<CheckInDetail> expire(String id) async {
    final r = await _client.dio.post<Map<String, dynamic>>(
      '${ApiConfig.checkIns}$id/expire/',
    );
    return CheckInDetail.fromJson(r.data!);
  }
}
