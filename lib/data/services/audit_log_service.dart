/// Day 68 — User Activity Audit Log Service
///
/// POST  /api/v1/audit-log/          → AuditLogEntry        (201)
/// GET   /api/v1/audit-log/          → AuditLogPage         (200)
///   ?event_type=<slug>  ?resource_type=<str>  ?days=<int>  ?limit=<int>  ?offset=<int>
/// GET   /api/v1/audit-log/summary/  → AuditLogSummary      (200)
library;

import '../../core/constants/api_config.dart';
import 'api_client.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.eventType,
    required this.resourceType,
    required this.resourceId,
    required this.details,
    required this.ipAddress,
    required this.createdAt,
  });

  final String                id;
  final String                eventType;
  final String                resourceType;
  final String                resourceId;
  final Map<String, dynamic>  details;
  final String?               ipAddress;
  final DateTime              createdAt;

  factory AuditLogEntry.fromJson(Map<String, dynamic> j) => AuditLogEntry(
        id:           j['id']            as String,
        eventType:    j['event_type']    as String,
        resourceType: (j['resource_type'] as String?) ?? '',
        resourceId:   (j['resource_id']   as String?) ?? '',
        details:      (j['details']  as Map<String, dynamic>?) ?? {},
        ipAddress:    j['ip_address'] as String?,
        createdAt:    DateTime.parse(j['created_at'] as String).toLocal(),
      );
}

class AuditLogPage {
  const AuditLogPage({
    required this.count,
    required this.limit,
    required this.offset,
    required this.entries,
  });

  final int                  count;
  final int                  limit;
  final int                  offset;
  final List<AuditLogEntry>  entries;

  factory AuditLogPage.fromJson(Map<String, dynamic> j) => AuditLogPage(
        count:   j['count']  as int,
        limit:   j['limit']  as int,
        offset:  j['offset'] as int,
        entries: (j['entries'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(AuditLogEntry.fromJson)
            .toList(),
      );
}

class AuditLogSummary {
  const AuditLogSummary({
    required this.totalCount,
    required this.last30Days,
    required this.byEventType,
    required this.byEventType30d,
  });

  final int                totalCount;
  final int                last30Days;
  final Map<String, int>   byEventType;
  final Map<String, int>   byEventType30d;

  factory AuditLogSummary.fromJson(Map<String, dynamic> j) => AuditLogSummary(
        totalCount:    j['total_count']        as int,
        last30Days:    j['last_30_days']        as int,
        byEventType:   _toIntMap(j['by_event_type']),
        byEventType30d: _toIntMap(j['by_event_type_30d']),
      );

  static Map<String, int> _toIntMap(dynamic raw) {
    if (raw == null) return {};
    return (raw as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, (v as num).toInt()),
    );
  }
}

// ─── Service ──────────────────────────────────────────────────────────────────

class AuditLogService {
  const AuditLogService(this._client);
  final ApiClient _client;

  /// GET /api/v1/audit-log/ with optional filters.
  Future<AuditLogPage> fetchList({
    String? eventType,
    String? resourceType,
    int?    days,
    int     limit  = 50,
    int     offset = 0,
  }) async {
    final params = <String, dynamic>{
      'limit':  limit,
      'offset': offset,
    };
    if (eventType    != null) params['event_type']    = eventType;
    if (resourceType != null) params['resource_type'] = resourceType;
    if (days         != null) params['days']          = days;

    final r = await _client.dio.get<Map<String, dynamic>>(
      ApiConfig.auditLog,
      queryParameters: params,
    );
    return AuditLogPage.fromJson(r.data!);
  }

  /// GET /api/v1/audit-log/summary/
  Future<AuditLogSummary> fetchSummary() async {
    final r = await _client.dio.get<Map<String, dynamic>>(
      ApiConfig.auditLogSummary,
    );
    return AuditLogSummary.fromJson(r.data!);
  }

  /// POST /api/v1/audit-log/ — log a client-side event.
  Future<AuditLogEntry> create({
    required String              eventType,
    String                       resourceType = '',
    String                       resourceId   = '',
    Map<String, dynamic>         details      = const {},
  }) async {
    final r = await _client.dio.post<Map<String, dynamic>>(
      ApiConfig.auditLog,
      data: {
        'event_type':    eventType,
        'resource_type': resourceType,
        'resource_id':   resourceId,
        'details':       details,
      },
    );
    return AuditLogEntry.fromJson(r.data!);
  }
}
