/// Group journey session service — backend Days 221-223, wired for real
/// Day 357.
///
/// POST /api/v1/journey/group/create/         create session, auto-joins creator
/// POST /api/v1/journey/group/join/            join via invite token
/// GET  /api/v1/journey/group/{session_id}/    members-only state
/// POST /api/v1/journey/group/{session_id}/panic/  trigger real SOS for every joined member
///
/// Response shapes match `zapsafe_backend/journey/serializers.py`
/// field-for-field, verified by reading the view + serializer source
/// directly (Docker unavailable in this sandbox — code-level
/// verification, not a live HTTP round trip).
library;

import '../../core/constants/api_config.dart';
import 'api_client.dart';

class GroupJourneyMember {
  const GroupJourneyMember({
    required this.phone,
    required this.fullName,
    required this.status,
    required this.joinedAt,
  });

  final String phone;
  final String fullName;
  final String status; // invited | joined | left
  final DateTime? joinedAt;

  factory GroupJourneyMember.fromJson(Map<String, dynamic> j) => GroupJourneyMember(
        phone: j['phone'] as String? ?? '',
        fullName: j['full_name'] as String? ?? '',
        status: j['status'] as String? ?? '',
        joinedAt: j['joined_at'] != null ? DateTime.tryParse(j['joined_at'] as String) : null,
      );
}

class GroupJourneySession {
  const GroupJourneySession({
    required this.id,
    required this.status,
    required this.destinationName,
    required this.destinationLat,
    required this.destinationLng,
    required this.inviteToken,
    required this.inviteLink,
    required this.members,
    required this.createdAt,
  });

  final String id;
  final String status; // active | completed | cancelled
  final String destinationName;
  final double? destinationLat;
  final double? destinationLng;
  final String inviteToken;
  final String inviteLink;
  final List<GroupJourneyMember> members;
  final DateTime? createdAt;

  factory GroupJourneySession.fromJson(Map<String, dynamic> j) => GroupJourneySession(
        id: j['id'] as String? ?? '',
        status: j['status'] as String? ?? '',
        destinationName: j['destination_name'] as String? ?? '',
        destinationLat: (j['destination_lat'] as num?)?.toDouble(),
        destinationLng: (j['destination_lng'] as num?)?.toDouble(),
        inviteToken: j['invite_token'] as String? ?? '',
        inviteLink: j['invite_link'] as String? ?? '',
        members: ((j['members'] as List?) ?? [])
            .cast<Map<String, dynamic>>()
            .map(GroupJourneyMember.fromJson)
            .toList(),
        createdAt: j['created_at'] != null ? DateTime.tryParse(j['created_at'] as String) : null,
      );
}

class GroupJourneyPanicResult {
  const GroupJourneyPanicResult({
    required this.sessionId,
    required this.triggeredSosIds,
    required this.skippedUserIds,
    required this.memberCount,
  });

  final String sessionId;
  final List<String> triggeredSosIds;
  final List<String> skippedUserIds;
  final int memberCount;

  factory GroupJourneyPanicResult.fromJson(Map<String, dynamic> j) => GroupJourneyPanicResult(
        sessionId: j['session_id'] as String? ?? '',
        triggeredSosIds: ((j['triggered_sos_ids'] as List?) ?? []).cast<String>(),
        skippedUserIds: ((j['skipped_user_ids'] as List?) ?? []).cast<String>(),
        memberCount: (j['member_count'] as num?)?.toInt() ?? 0,
      );
}

class GroupJourneyApiService {
  const GroupJourneyApiService(this._client);
  final ApiClient _client;

  /// POST /api/v1/journey/group/create/
  Future<GroupJourneySession> createSession({
    String destinationName = '',
    double? destinationLat,
    double? destinationLng,
  }) async {
    final res = await _client.dio.post(ApiConfig.journeyGroupCreate, data: {
      'destination_name': destinationName,
      if (destinationLat != null) 'destination_lat': destinationLat,
      if (destinationLng != null) 'destination_lng': destinationLng,
    });
    return GroupJourneySession.fromJson(res.data as Map<String, dynamic>);
  }

  /// POST /api/v1/journey/group/join/  body: {"token": "<invite_token>"}
  Future<GroupJourneySession> joinSession(String token) async {
    final res = await _client.dio.post(ApiConfig.journeyGroupJoin, data: {'token': token});
    return GroupJourneySession.fromJson(res.data as Map<String, dynamic>);
  }

  /// GET /api/v1/journey/group/{session_id}/ — 404 JOURNEY_NOT_FOUND if the
  /// caller isn't a member (anti-enumeration, same as a session that
  /// doesn't exist at all).
  Future<GroupJourneySession> fetchState(String sessionId) async {
    final res = await _client.dio.get(ApiConfig.journeyGroupStateFor(sessionId));
    return GroupJourneySession.fromJson(res.data as Map<String, dynamic>);
  }

  /// POST /api/v1/journey/group/{session_id}/panic/ — triggers a real SOS
  /// event for every JOINED member (not just the caller). 202 Accepted.
  Future<GroupJourneyPanicResult> triggerPanic(
    String sessionId, {
    double? lat,
    double? lng,
    double? accuracyM,
  }) async {
    final res = await _client.dio.post(
      ApiConfig.journeyGroupPanicFor(sessionId),
      data: {
        if (lat != null || lng != null)
          'location': {
            if (lat != null) 'lat': lat,
            if (lng != null) 'lng': lng,
            if (accuracyM != null) 'accuracy_m': accuracyM,
          },
      },
    );
    return GroupJourneyPanicResult.fromJson(res.data as Map<String, dynamic>);
  }
}
