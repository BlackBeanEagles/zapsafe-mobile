/// Police dispatch status service — backend Day 204, wired for real Day 356.
///
/// GET /api/v1/police/dispatch/{sos_id}/
///
/// Always returns 200 — either the real `PoliceDispatch` row if one
/// exists for the SOS (a future live police integration would create
/// these), or a deterministic simulated timeline when none does (true
/// for every SOS today — no live police integration exists yet). The
/// response's `is_mock` field tells you which one you got; this service
/// surfaces it as-is rather than hiding it, per `police/dispatch_views.py`'s
/// own "mock mode" note.
///
/// Response shape matches `zapsafe_backend/police/dispatch_serializers.py`
/// (+ the `_mock_timeline()` fallback shape, which mirrors it field-for-
/// field on purpose) verified by reading the view + serializer source
/// directly (Docker unavailable in this sandbox — code-level
/// verification, not a live HTTP round trip).
library;

import '../../core/constants/api_config.dart';
import 'api_client.dart';

class PoliceDispatchTimelineEntry {
  const PoliceDispatchTimelineEntry({
    required this.status,
    required this.at,
    required this.note,
  });
  final String status;
  final DateTime? at;
  final String? note;

  factory PoliceDispatchTimelineEntry.fromJson(Map<String, dynamic> j) =>
      PoliceDispatchTimelineEntry(
        status: j['status'] as String? ?? '',
        at: j['at'] != null ? DateTime.tryParse(j['at'] as String) : null,
        note: j['note'] as String?,
      );
}

class PoliceDispatchStatus {
  const PoliceDispatchStatus({
    required this.sosId,
    required this.referenceNumber,
    required this.status,
    required this.timeline,
    required this.isMock,
  });

  final String sosId;
  final String referenceNumber;
  final String status; // dispatched | en_route | on_scene | resolved
  final List<PoliceDispatchTimelineEntry> timeline;
  final bool isMock;

  factory PoliceDispatchStatus.fromJson(Map<String, dynamic> j) => PoliceDispatchStatus(
        sosId: j['sos_id'] as String? ?? '',
        referenceNumber: j['reference_number'] as String? ?? '',
        status: j['status'] as String? ?? '',
        timeline: ((j['timeline'] as List?) ?? [])
            .cast<Map<String, dynamic>>()
            .map(PoliceDispatchTimelineEntry.fromJson)
            .toList(),
        isMock: (j['is_mock'] as bool?) ?? true,
      );
}

class PoliceDispatchApiService {
  const PoliceDispatchApiService(this._client);
  final ApiClient _client;

  /// GET /api/v1/police/dispatch/{sos_id}/ — 404 SOS_NOT_FOUND if the SOS
  /// doesn't exist or doesn't belong to the caller.
  Future<PoliceDispatchStatus> fetchDispatchStatus(String sosId) async {
    final res = await _client.dio.get(ApiConfig.policeDispatchFor(sosId));
    return PoliceDispatchStatus.fromJson(res.data as Map<String, dynamic>);
  }
}
