/// Family dashboard service — backend Day 224-225, wired for real Day 354.
///
/// GET /api/v1/family/dashboard/
/// GET /api/v1/family/members/{id}/sos-history/
///
/// Response shapes match `zapsafe_backend/family/views.py` +
/// `family/serializers.py` field-for-field, verified by reading the view
/// and serializer source directly (Docker unavailable in this sandbox —
/// code-level verification, not a live HTTP round trip).
library;

import '../../core/constants/api_config.dart';
import 'api_client.dart';

// ─── Models ─────────────────────────────────────────────────────────────────

class FamilyDashboardMember {
  const FamilyDashboardMember({
    required this.memberId,
    required this.fullName,
    required this.phone,
    required this.role,
    required this.lastSosStatus,
    required this.lastSosTriggeredAt,
    required this.hasLiveSos,
  });

  final String memberId;
  final String fullName;
  final String phone;
  final String role;
  final String? lastSosStatus;
  final DateTime? lastSosTriggeredAt;
  final bool hasLiveSos;

  factory FamilyDashboardMember.fromJson(Map<String, dynamic> j) => FamilyDashboardMember(
        memberId: j['member_id'] as String? ?? '',
        fullName: j['full_name'] as String? ?? '',
        phone: j['phone'] as String? ?? '',
        role: j['role'] as String? ?? '',
        lastSosStatus: j['last_sos_status'] as String?,
        lastSosTriggeredAt: j['last_sos_triggered_at'] != null
            ? DateTime.tryParse(j['last_sos_triggered_at'] as String)
            : null,
        hasLiveSos: (j['has_live_sos'] as bool?) ?? false,
      );
}

class FamilyDashboard {
  const FamilyDashboard({required this.count, required this.members});

  final int count;
  final List<FamilyDashboardMember> members;

  factory FamilyDashboard.fromJson(Map<String, dynamic> j) => FamilyDashboard(
        count: (j['count'] as num?)?.toInt() ?? 0,
        members: ((j['members'] as List?) ?? [])
            .cast<Map<String, dynamic>>()
            .map(FamilyDashboardMember.fromJson)
            .toList(),
      );
}

class FamilySosHistoryItem {
  const FamilySosHistoryItem({
    required this.id,
    required this.status,
    required this.triggerType,
    required this.triggeredAt,
    required this.note,
  });

  final String id;
  final String status;
  final String triggerType;
  final DateTime? triggeredAt;
  final String? note;

  factory FamilySosHistoryItem.fromJson(Map<String, dynamic> j) => FamilySosHistoryItem(
        id: j['id'] as String? ?? '',
        status: j['status'] as String? ?? '',
        triggerType: j['trigger_type'] as String? ?? '',
        triggeredAt:
            j['triggered_at'] != null ? DateTime.tryParse(j['triggered_at'] as String) : null,
        note: j['note'] as String?,
      );
}

class FamilySosHistory {
  const FamilySosHistory({
    required this.memberId,
    required this.count,
    required this.results,
  });

  final String memberId;
  final int count;
  final List<FamilySosHistoryItem> results;

  factory FamilySosHistory.fromJson(Map<String, dynamic> j) => FamilySosHistory(
        memberId: j['member_id'] as String? ?? '',
        count: (j['count'] as num?)?.toInt() ?? 0,
        results: ((j['results'] as List?) ?? [])
            .cast<Map<String, dynamic>>()
            .map(FamilySosHistoryItem.fromJson)
            .toList(),
      );
}

// ─── Service ────────────────────────────────────────────────────────────────

class FamilyApiService {
  const FamilyApiService(this._client);
  final ApiClient _client;

  /// GET /api/v1/family/dashboard/ — every FamilyLink row this user admins,
  /// each with the member's latest SOS status.
  Future<FamilyDashboard> fetchDashboard() async {
    final res = await _client.dio.get(ApiConfig.familyDashboard);
    return FamilyDashboard.fromJson(res.data as Map<String, dynamic>);
  }

  /// GET /api/v1/family/members/{id}/sos-history/ — 404 with code
  /// FAMILY_LINK_NOT_FOUND if the caller isn't that member's admin.
  /// [memberId] must be the real member's user UUID (from
  /// [fetchDashboard]'s `member_id`, not a mock string id).
  Future<FamilySosHistory> fetchMemberSosHistory(String memberId) async {
    final res = await _client.dio.get(ApiConfig.familyMemberSosHistoryFor(memberId));
    return FamilySosHistory.fromJson(res.data as Map<String, dynamic>);
  }
}
