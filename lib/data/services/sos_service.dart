/// SOS lifecycle service — wires the Flutter state machine to backend Day 10+ APIs.
///
/// POST /api/v1/sos/trigger/           — start SOS cascade
/// POST /api/v1/sos/<id>/cancel/       — cancel (LP3 duress PIN supported)
/// POST /api/v1/sos/<id>/location/     — stream GPS during live SOS
/// GET  /api/v1/sos/active/            — hydrate active session on cold start
library;

import '../../core/constants/api_config.dart';
import '../models/gps_sample.dart';
import 'api_client.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

class SosDispatchPlan {
  const SosDispatchPlan({
    required this.tier1,
    required this.tier2,
    required this.tier3,
  });

  final int tier1;
  final int tier2;
  final int tier3;

  factory SosDispatchPlan.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const SosDispatchPlan(tier1: 0, tier2: 0, tier3: 0);
    return SosDispatchPlan(
      tier1: (j['tier1_planned'] as num?)?.toInt() ??
          (j['tier_1'] as num?)?.toInt() ??
          0,
      tier2: (j['tier2_planned'] as num?)?.toInt() ??
          (j['tier_2'] as num?)?.toInt() ??
          0,
      tier3: (j['tier3_planned'] as num?)?.toInt() ??
          (j['tier_3'] as num?)?.toInt() ??
          0,
    );
  }
}

class SosEvent {
  const SosEvent({
    required this.id,
    required this.status,
    required this.triggerType,
    required this.isLive,
    this.locationLat,
    this.locationLng,
    this.locationAccuracyM,
    this.triggeredAt,
    this.dispatch,
  });

  final String id;
  final String status;
  final String triggerType;
  final bool isLive;
  final double? locationLat;
  final double? locationLng;
  final double? locationAccuracyM;
  final DateTime? triggeredAt;
  final SosDispatchPlan? dispatch;

  factory SosEvent.fromJson(Map<String, dynamic> j) => SosEvent(
        id: j['id'] as String,
        status: j['status'] as String,
        triggerType: (j['trigger_type'] as String?) ?? 'manual_button',
        isLive: (j['is_live'] as bool?) ?? false,
        locationLat: (j['location_lat'] as num?)?.toDouble(),
        locationLng: (j['location_lng'] as num?)?.toDouble(),
        locationAccuracyM: (j['location_accuracy_m'] as num?)?.toDouble(),
        triggeredAt: j['triggered_at'] != null
            ? DateTime.parse(j['triggered_at'] as String)
            : null,
        dispatch: SosDispatchPlan.fromJson(
          j['dispatch'] as Map<String, dynamic>?,
        ),
      );
}

enum SosTriggerType {
  manualButton('manual_button'),
  shake('shake'),
  volumeButton('volume_button'),
  aiDetected('ai_detected'),
  scheduledMissed('scheduled_missed');

  const SosTriggerType(this.apiValue);
  final String apiValue;
}

// ─── Service ──────────────────────────────────────────────────────────────────

class SosService {
  const SosService(this._client);
  final ApiClient _client;

  /// POST /api/v1/sos/trigger/
  Future<SosEvent> trigger({
    required SosTriggerType triggerType,
    GpsSample? location,
    String? note,
    int? batteryLevel,
    String? powerMode,
  }) async {
    final body = <String, dynamic>{
      'trigger_type': triggerType.apiValue,
      if (note != null && note.isNotEmpty) 'note': note,
      if (batteryLevel != null) 'battery_level': batteryLevel,
      if (powerMode != null) 'power_mode': powerMode,
      'client_now': DateTime.now().toUtc().toIso8601String(),
    };

    if (location != null) {
      body['location'] = {
        'lat': location.lat,
        'lng': location.lng,
        if (location.accuracyM > 0) 'accuracy_m': location.accuracyM,
      };
    }

    final res = await _client.dio.post(ApiConfig.sosTrigger, data: body);
    return SosEvent.fromJson(res.data as Map<String, dynamic>);
  }

  /// POST /api/v1/sos/<id>/cancel/
  ///
  /// Pass [pin] for LP3 duress handling — backend compares against duress_pin.
  Future<SosEvent> cancel({
    required String sosId,
    String? pin,
    String reason = 'user_cancelled',
  }) async {
    final res = await _client.dio.post(
      ApiConfig.sosCancelFor(sosId),
      data: {
        if (pin != null && pin.isNotEmpty) 'pin': pin,
        'reason': reason,
      },
    );
    return SosEvent.fromJson(res.data as Map<String, dynamic>);
  }

  /// POST /api/v1/sos/<id>/location/
  Future<void> postLocation({
    required String sosId,
    required GpsSample sample,
    int? batteryPercent,
  }) async {
    await _client.dio.post(
      ApiConfig.sosLocationFor(sosId),
      data: {
        'lat': sample.lat,
        'lng': sample.lng,
        if (sample.accuracyM > 0) 'accuracy_m': sample.accuracyM,
        if (sample.speedMps != null) 'speed_mps': sample.speedMps,
        if (sample.headingDeg != null) 'heading_deg': sample.headingDeg,
        if (batteryPercent != null) 'battery_percent': batteryPercent,
        'recorded_at': DateTime.fromMillisecondsSinceEpoch(
          sample.timestampMs,
          isUtc: true,
        ).toIso8601String(),
      },
    );
  }

  /// GET /api/v1/sos/active/ — null when no live SOS.
  Future<SosEvent?> fetchActive() async {
    final res = await _client.dio.get(ApiConfig.sosActive);
    final data = res.data;
    if (data == null) return null;
    if (data is Map<String, dynamic> && data.isEmpty) return null;
    return SosEvent.fromJson(data as Map<String, dynamic>);
  }
}
