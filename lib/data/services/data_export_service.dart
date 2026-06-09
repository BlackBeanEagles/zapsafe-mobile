/// Day 69 — Data Export Service
///
/// POST  /api/v1/data-export/              → DataExportRequest     (201)
/// GET   /api/v1/data-export/              → {count, exports:[]}   (200)
/// GET   /api/v1/data-export/<uuid>/       → DataExportRequest     (200)
/// GET   /api/v1/data-export/<uuid>/download/ → DataExportPayload  (200 | 202 | 404)
library;

import '../../core/constants/api_config.dart';
import 'api_client.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

class DataExportRequest {
  const DataExportRequest({
    required this.id,
    required this.status,
    required this.isExpired,
    required this.requestedAt,
    required this.errorMessage,
    this.readyAt,
    this.expiresAt,
  });

  final String    id;
  final String    status;       // pending | processing | ready | failed | expired
  final bool      isExpired;
  final DateTime  requestedAt;
  final DateTime? readyAt;
  final DateTime? expiresAt;
  final String    errorMessage;

  bool get isReady    => status == 'ready'      && !isExpired;
  bool get isPending  => status == 'pending'    || status == 'processing';
  bool get isFailed   => status == 'failed';
  bool get isExpiredState => status == 'expired' || isExpired;

  factory DataExportRequest.fromJson(Map<String, dynamic> j) => DataExportRequest(
        id:           j['id']            as String,
        status:       j['status']        as String,
        isExpired:    j['is_expired']    as bool,
        requestedAt:  DateTime.parse(j['requested_at'] as String).toLocal(),
        readyAt:      j['ready_at']   != null
            ? DateTime.parse(j['ready_at']  as String).toLocal()
            : null,
        expiresAt:    j['expires_at'] != null
            ? DateTime.parse(j['expires_at'] as String).toLocal()
            : null,
        errorMessage: (j['error_message'] as String?) ?? '',
      );
}

/// Structured view of the downloaded payload — section record counts + profile.
class DataExportPayload {
  const DataExportPayload({
    required this.exportedAt,
    required this.schemaVersion,
    required this.historyDays,
    required this.sections,
    required this.profilePhone,
    required this.sectionCounts,
    required this.rawSections,
  });

  final String              exportedAt;
  final String              schemaVersion;
  final int                 historyDays;
  final List<String>        sections;
  final String              profilePhone;
  final Map<String, int>    sectionCounts;   // section → item count
  final Map<String, dynamic> rawSections;    // for future deep-dive

  factory DataExportPayload.fromJson(Map<String, dynamic> j) {
    final meta     = j['meta']    as Map<String, dynamic>? ?? {};
    final profile  = j['profile'] as Map<String, dynamic>? ?? {};
    final sections = (meta['sections'] as List<dynamic>? ?? []).cast<String>();

    // Count items in each list section.
    final counts = <String, int>{};
    for (final s in sections) {
      final v = j[s];
      if (v is List) counts[s] = v.length;
    }

    final raw = <String, dynamic>{};
    for (final s in sections) {
      if (j.containsKey(s)) raw[s] = j[s];
    }

    return DataExportPayload(
      exportedAt:    (meta['exported_at']   as String?) ?? '',
      schemaVersion: (meta['schema_version'] as String?) ?? '1.0',
      historyDays:   (meta['history_days']   as int?)    ?? 90,
      sections:      sections,
      profilePhone:  (profile['phone']       as String?) ?? '',
      sectionCounts: counts,
      rawSections:   raw,
    );
  }
}

// ─── Service ──────────────────────────────────────────────────────────────────

class DataExportService {
  const DataExportService(this._client);
  final ApiClient _client;

  /// GET /api/v1/data-export/
  Future<List<DataExportRequest>> fetchList() async {
    final r = await _client.dio.get<Map<String, dynamic>>(ApiConfig.dataExport);
    final raw = (r.data!['exports'] as List<dynamic>).cast<Map<String, dynamic>>();
    return raw.map(DataExportRequest.fromJson).toList();
  }

  /// POST /api/v1/data-export/ — request a new export.
  Future<DataExportRequest> create() async {
    final r = await _client.dio.post<Map<String, dynamic>>(ApiConfig.dataExport);
    return DataExportRequest.fromJson(r.data!);
  }

  /// GET /api/v1/data-export/<uuid>/download/
  /// Returns null if the export is not ready (202) or not found (404).
  Future<DataExportPayload?> download(String id) async {
    try {
      final r = await _client.dio.get<Map<String, dynamic>>(
        '${ApiConfig.dataExport}$id/download/',
      );
      if (r.statusCode == 202 || r.data == null) return null;
      return DataExportPayload.fromJson(r.data!);
    } catch (_) {
      return null;
    }
  }
}
