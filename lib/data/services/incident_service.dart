/// Day 62 — Incident Report Service
///
/// POST  /api/v1/incidents/        → {id, title}            (201)
/// GET   /api/v1/incidents/        → IncidentHistory         (200)
/// GET   /api/v1/incidents/<uuid>/ → IncidentDetail          (200)
/// PATCH /api/v1/incidents/<uuid>/ → IncidentDetail          (200)
library;

import '../../core/constants/api_config.dart';
import 'api_client.dart';

// ─── Enums ────────────────────────────────────────────────────────────────────

enum IncidentStatusFilter {
  all('',           'All'),
  draft('draft',    'Draft'),
  finalized('finalized', 'Finalized');

  const IncidentStatusFilter(this.value, this.label);
  final String value;
  final String label;
}

// ─── Data models ──────────────────────────────────────────────────────────────

class IncidentContactEntry {
  const IncidentContactEntry({
    required this.name,
    required this.acked,
    this.phone,
    this.tier,
    this.ackTimeMs,
  });

  final String  name;
  final bool    acked;
  final String? phone;
  final int?    tier;
  final int?    ackTimeMs;

  factory IncidentContactEntry.fromJson(Map<String, dynamic> j) =>
      IncidentContactEntry(
        name:      j['name']        as String,
        acked:     (j['acked']      as bool?) ?? false,
        phone:     j['phone']       as String?,
        tier:      (j['tier']       as num?)?.toInt(),
        ackTimeMs: (j['ack_time_ms'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => {
        'name':  name,
        'acked': acked,
        if (phone != null)     'phone':      phone,
        if (tier != null)      'tier':       tier,
        if (ackTimeMs != null) 'ack_time_ms': ackTimeMs,
      };
}

/// Compact list entry — no contacts_notified / inference_summary blobs.
class IncidentListEntry {
  const IncidentListEntry({
    required this.id,
    required this.title,
    required this.status,
    required this.startedAt,
    required this.createdAt,
    this.endedAt,
    this.durationSeconds,
    this.locationLabel,
    this.gpsPointCount,
    this.evidenceCount,
    this.ackedContactCount,
  });

  final String   id;
  final String   title;
  final String   status;
  final DateTime startedAt;
  final DateTime createdAt;
  final DateTime? endedAt;
  final int?     durationSeconds;
  final String?  locationLabel;
  final int?     gpsPointCount;
  final int?     evidenceCount;
  final int?     ackedContactCount;

  factory IncidentListEntry.fromJson(Map<String, dynamic> j) =>
      IncidentListEntry(
        id:                j['id']    as String,
        title:             j['title'] as String,
        status:            j['status'] as String,
        startedAt:         DateTime.parse(j['started_at'] as String).toLocal(),
        createdAt:         DateTime.parse(j['created_at'] as String).toLocal(),
        endedAt:           j['ended_at'] == null
            ? null
            : DateTime.parse(j['ended_at'] as String).toLocal(),
        durationSeconds:   (j['duration_seconds'] as num?)?.toInt(),
        locationLabel:     j['location_label'] as String?,
        gpsPointCount:     (j['gps_point_count'] as num?)?.toInt(),
        evidenceCount:     (j['evidence_count'] as num?)?.toInt(),
        ackedContactCount: (j['acked_contact_count'] as num?)?.toInt(),
      );
}

/// Full detail entry — includes contacts, inference summary, coords, notes.
class IncidentDetail {
  const IncidentDetail({
    required this.id,
    required this.title,
    required this.status,
    required this.startedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.contactsNotified,
    required this.inferenceSummary,
    this.endedAt,
    this.durationSeconds,
    this.latitude,
    this.longitude,
    this.locationLabel,
    this.gpsPointCount,
    this.ackedContactCount,
    this.evidenceCount,
    this.notes,
  });

  final String   id;
  final String   title;
  final String   status;
  final DateTime startedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<IncidentContactEntry> contactsNotified;
  final Map<String, dynamic> inferenceSummary;
  final DateTime? endedAt;
  final int?     durationSeconds;
  final double?  latitude;
  final double?  longitude;
  final String?  locationLabel;
  final int?     gpsPointCount;
  final int?     ackedContactCount;
  final int?     evidenceCount;
  final String?  notes;

  factory IncidentDetail.fromJson(Map<String, dynamic> j) => IncidentDetail(
        id:        j['id']     as String,
        title:     j['title']  as String,
        status:    j['status'] as String,
        startedAt: DateTime.parse(j['started_at'] as String).toLocal(),
        createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
        updatedAt: DateTime.parse(j['updated_at'] as String).toLocal(),
        contactsNotified: (j['contacts_notified'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>()
            .map(IncidentContactEntry.fromJson)
            .toList(),
        inferenceSummary:
            (j['inference_summary'] as Map<String, dynamic>?) ?? {},
        endedAt: j['ended_at'] == null
            ? null
            : DateTime.parse(j['ended_at'] as String).toLocal(),
        durationSeconds:   (j['duration_seconds']    as num?)?.toInt(),
        latitude:          (j['latitude']            as num?)?.toDouble(),
        longitude:         (j['longitude']           as num?)?.toDouble(),
        locationLabel:     j['location_label']        as String?,
        gpsPointCount:     (j['gps_point_count']     as num?)?.toInt(),
        ackedContactCount: (j['acked_contact_count'] as num?)?.toInt(),
        evidenceCount:     (j['evidence_count']      as num?)?.toInt(),
        notes:             j['notes']                as String?,
      );
}

class IncidentHistory {
  const IncidentHistory({
    required this.count,
    required this.days,
    required this.reports,
  });

  final int                    count;
  final int                    days;
  final List<IncidentListEntry> reports;

  static const empty = IncidentHistory(count: 0, days: 30, reports: []);
}

// ─── Service ──────────────────────────────────────────────────────────────────

class IncidentService {
  const IncidentService(this._client);
  final ApiClient _client;

  /// POST /api/v1/incidents/ — create a new incident report.
  ///
  /// Returns `{id, title}` on 201.
  Future<Map<String, String>> create({
    required DateTime startedAt,
    DateTime?         endedAt,
    String            title         = '',
    String            locationLabel = '',
    double?           latitude,
    double?           longitude,
    int               gpsPointCount = 0,
    List<Map<String, dynamic>> contactsNotified = const [],
    int               evidenceCount    = 0,
    Map<String, dynamic> inferenceSummary = const {},
    String            notes         = '',
    String            status        = 'draft',
  }) async {
    final data = <String, dynamic>{
      'started_at':          startedAt.toUtc().toIso8601String(),
      'status':              status,
      'gps_point_count':     gpsPointCount,
      'contacts_notified':   contactsNotified,
      'evidence_count':      evidenceCount,
      'inference_summary':   inferenceSummary,
    };
    if (title.isNotEmpty)         data['title']          = title;
    if (endedAt != null)          data['ended_at']       = endedAt.toUtc().toIso8601String();
    if (locationLabel.isNotEmpty) data['location_label'] = locationLabel;
    if (latitude != null)         data['latitude']       = latitude;
    if (longitude != null)        data['longitude']      = longitude;
    if (notes.isNotEmpty)         data['notes']          = notes;

    final r = await _client.dio.post<Map<String, dynamic>>(
      ApiConfig.incidents,
      data: data,
    );
    return {
      'id':    r.data!['id']    as String,
      'title': r.data!['title'] as String,
    };
  }

  /// GET /api/v1/incidents/?days=N&status=X
  Future<IncidentHistory> fetchHistory({
    int    days   = 30,
    String status = '',
  }) async {
    final params = <String, dynamic>{'days': days};
    if (status.isNotEmpty) params['status'] = status;

    final r = await _client.dio.get<Map<String, dynamic>>(
      ApiConfig.incidents,
      queryParameters: params,
    );
    final data = r.data;
    if (data == null) return IncidentHistory.empty;
    final raw = (data['reports'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    return IncidentHistory(
      count:   (data['count'] as int?) ?? raw.length,
      days:    (data['days']  as int?) ?? days,
      reports: raw.map(IncidentListEntry.fromJson).toList(),
    );
  }

  /// GET /api/v1/incidents/<uuid>/
  Future<IncidentDetail> fetchDetail(String id) async {
    final r = await _client.dio.get<Map<String, dynamic>>(
      '${ApiConfig.incidents}$id/',
    );
    return IncidentDetail.fromJson(r.data!);
  }

  /// PATCH /api/v1/incidents/<uuid>/ — update mutable fields.
  Future<IncidentDetail> updateReport(
    String id, {
    String? title,
    String? notes,
    String? status,
  }) async {
    final data = <String, dynamic>{};
    if (title  != null) data['title']  = title;
    if (notes  != null) data['notes']  = notes;
    if (status != null) data['status'] = status;

    final r = await _client.dio.patch<Map<String, dynamic>>(
      '${ApiConfig.incidents}$id/',
      data: data,
    );
    return IncidentDetail.fromJson(r.data!);
  }
}
