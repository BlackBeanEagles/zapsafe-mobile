/// Day 64 — Escalation Policy Service
///
/// GET    /api/v1/escalation-policies/              → {count, policies:[...]}  (200)
/// POST   /api/v1/escalation-policies/              → EscalationPolicy         (201)
/// GET    /api/v1/escalation-policies/<uuid>/       → EscalationPolicy         (200)
/// PATCH  /api/v1/escalation-policies/<uuid>/       → EscalationPolicy         (200)
/// DELETE /api/v1/escalation-policies/<uuid>/       →                          (204)
/// POST   /api/v1/escalation-policies/<uuid>/activate/ → EscalationPolicy      (200)
library;

import '../../core/constants/api_config.dart';
import 'api_client.dart';

// ─── Model ────────────────────────────────────────────────────────────────────

class EscalationPolicy {
  const EscalationPolicy({
    required this.id,
    required this.name,
    required this.isDefault,
    required this.tier1TimeoutSeconds,
    required this.tier1RetryCount,
    required this.escalateToTier2,
    required this.tier2TimeoutSeconds,
    required this.autoCallEmergency,
    required this.sendLocationSms,
    required this.loopAudioAlarm,
    required this.notes,
    required this.createdAt,
  });

  final String   id;
  final String   name;
  final bool     isDefault;
  final int      tier1TimeoutSeconds;
  final int      tier1RetryCount;
  final bool     escalateToTier2;
  final int      tier2TimeoutSeconds;
  final bool     autoCallEmergency;
  final bool     sendLocationSms;
  final bool     loopAudioAlarm;
  final String   notes;
  final DateTime createdAt;

  factory EscalationPolicy.fromJson(Map<String, dynamic> j) => EscalationPolicy(
        id:                   j['id']                       as String,
        name:                 j['name']                     as String,
        isDefault:            j['is_default']               as bool,
        tier1TimeoutSeconds:  (j['tier1_timeout_seconds']   as num).toInt(),
        tier1RetryCount:      (j['tier1_retry_count']       as num).toInt(),
        escalateToTier2:      j['escalate_to_tier2']        as bool,
        tier2TimeoutSeconds:  (j['tier2_timeout_seconds']   as num).toInt(),
        autoCallEmergency:    j['auto_call_emergency']      as bool,
        sendLocationSms:      j['send_location_sms']        as bool,
        loopAudioAlarm:       j['loop_audio_alarm']         as bool,
        notes:                (j['notes'] as String?) ?? '',
        createdAt:            DateTime.parse(j['created_at'] as String).toLocal(),
      );
}

// ─── Service ──────────────────────────────────────────────────────────────────

class EscalationService {
  const EscalationService(this._client);
  final ApiClient _client;

  /// GET /api/v1/escalation-policies/ → list ordered default-first.
  Future<List<EscalationPolicy>> fetchAll() async {
    final r = await _client.dio.get<Map<String, dynamic>>(
      ApiConfig.escalationPolicies,
    );
    final data = r.data;
    if (data == null) return [];
    final raw = (data['policies'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    return raw.map(EscalationPolicy.fromJson).toList();
  }

  /// POST /api/v1/escalation-policies/ — create a new policy.
  Future<EscalationPolicy> create({
    required String name,
    required int    tier1TimeoutSeconds,
    required int    tier1RetryCount,
    required int    tier2TimeoutSeconds,
    bool            isDefault          = false,
    bool            escalateToTier2    = true,
    bool            autoCallEmergency  = false,
    bool            sendLocationSms    = true,
    bool            loopAudioAlarm     = false,
    String          notes              = '',
  }) async {
    final data = <String, dynamic>{
      'name':                  name,
      'tier1_timeout_seconds': tier1TimeoutSeconds,
      'tier1_retry_count':     tier1RetryCount,
      'tier2_timeout_seconds': tier2TimeoutSeconds,
      'is_default':            isDefault,
      'escalate_to_tier2':     escalateToTier2,
      'auto_call_emergency':   autoCallEmergency,
      'send_location_sms':     sendLocationSms,
      'loop_audio_alarm':      loopAudioAlarm,
      'notes':                 notes,
    };
    final r = await _client.dio.post<Map<String, dynamic>>(
      ApiConfig.escalationPolicies,
      data: data,
    );
    return EscalationPolicy.fromJson(r.data!);
  }

  /// PATCH /api/v1/escalation-policies/<uuid>/
  Future<EscalationPolicy> update(
    String id, {
    String? name,
    int?    tier1TimeoutSeconds,
    int?    tier1RetryCount,
    int?    tier2TimeoutSeconds,
    bool?   isDefault,
    bool?   escalateToTier2,
    bool?   autoCallEmergency,
    bool?   sendLocationSms,
    bool?   loopAudioAlarm,
    String? notes,
  }) async {
    final data = <String, dynamic>{};
    if (name                 != null) data['name']                  = name;
    if (tier1TimeoutSeconds  != null) data['tier1_timeout_seconds'] = tier1TimeoutSeconds;
    if (tier1RetryCount      != null) data['tier1_retry_count']     = tier1RetryCount;
    if (tier2TimeoutSeconds  != null) data['tier2_timeout_seconds'] = tier2TimeoutSeconds;
    if (isDefault            != null) data['is_default']            = isDefault;
    if (escalateToTier2      != null) data['escalate_to_tier2']     = escalateToTier2;
    if (autoCallEmergency    != null) data['auto_call_emergency']   = autoCallEmergency;
    if (sendLocationSms      != null) data['send_location_sms']     = sendLocationSms;
    if (loopAudioAlarm       != null) data['loop_audio_alarm']      = loopAudioAlarm;
    if (notes                != null) data['notes']                 = notes;

    final r = await _client.dio.patch<Map<String, dynamic>>(
      '${ApiConfig.escalationPolicies}$id/',
      data: data,
    );
    return EscalationPolicy.fromJson(r.data!);
  }

  /// DELETE /api/v1/escalation-policies/<uuid>/ → 204
  Future<void> delete(String id) async {
    await _client.dio.delete<void>('${ApiConfig.escalationPolicies}$id/');
  }

  /// POST /api/v1/escalation-policies/<uuid>/activate/ → sets as default, clears others.
  Future<EscalationPolicy> activate(String id) async {
    final r = await _client.dio.post<Map<String, dynamic>>(
      '${ApiConfig.escalationPolicies}$id/activate/',
    );
    return EscalationPolicy.fromJson(r.data!);
  }
}
