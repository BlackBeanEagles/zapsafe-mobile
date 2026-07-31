/// Day 55 — Detection Event Service
///
/// Handles:
///   POST /api/v1/ml/detection-events/  — log a DCS detection event
///   GET  /api/v1/ml/detection-events/  — fetch own event history
///
/// Both endpoints require authentication — every request rides on the
/// [ApiClient] that carries the Authorization header automatically.
library;

import 'package:dio/dio.dart';

import '../../core/constants/api_config.dart';
import 'api_client.dart';
import 'capability_report_service.dart'; // getOrCreateDeviceId

// ─── Constants ────────────────────────────────────────────────────────────────

/// The event types the DCS pipeline can fire.
///
/// Day 262 added `gunshot` (mg_gunshot_retrain, a new detection family) and
/// `motionB` (m2_motion_b_retrain, a second independent fall detector run
/// alongside `motion`/m2_motion_v2 — see `motion_detector_b.dart`'s class
/// doc for why it is not fused into `motion`). Both require the matching
/// `EventType` additions on the backend
/// (`zapsafe_backend/ml/models.py`) — see the Day 262 migration.
/// Day 265 added `crowdPanic` (s_crowd_panic, ZapSafe's first two-input
/// audio+IMU fusion model — see `crowd_panic_detector.dart`/
/// `crowd_panic_pipeline.dart`). Requires the matching `EventType.CROWD_PANIC`
/// addition on the backend (`zapsafe_backend/ml/models.py`) — see the
/// Day 265 migration, which (unlike Day 262's gunshot/motion_b) is NOT a
/// no-op: "crowd_panic" (11 chars) needed event_type's column widened from
/// varchar(10) to varchar(20).
enum DetectionEventType {
  scream,
  motion,
  scene,
  dcs,
  gunshot,
  motionB,
  crowdPanic;

  /// Wire value sent to / received from the backend.
  String get value {
    switch (this) {
      case DetectionEventType.motionB: return 'motion_b';
      case DetectionEventType.crowdPanic: return 'crowd_panic';
      default: return name; // "scream" | "motion" | "scene" | "dcs" | "gunshot"
    }
  }

  /// Human-readable label for UI display.
  String get label {
    switch (this) {
      case DetectionEventType.scream: return 'Scream';
      case DetectionEventType.motion: return 'Motion';
      case DetectionEventType.scene:  return 'Scene';
      case DetectionEventType.dcs:    return 'DCS Fusion';
      case DetectionEventType.gunshot: return 'Gunshot';
      case DetectionEventType.motionB: return 'Motion (model B)';
      case DetectionEventType.crowdPanic: return 'Crowd Panic';
    }
  }

  static DetectionEventType fromValue(String v) {
    return DetectionEventType.values.firstWhere(
      (e) => e.value == v,
      orElse: () => DetectionEventType.dcs,
    );
  }
}

// ─── Data models ─────────────────────────────────────────────────────────────

/// One detection event record as returned by the backend.
class DetectionEventRecord {
  const DetectionEventRecord({
    required this.id,
    required this.deviceId,
    required this.eventType,
    required this.eventTypeDisplay,
    required this.confidence,
    required this.tier,
    required this.tierDisplay,
    required this.detectionMode,
    required this.detectionModeDisplay,
    required this.inferenceMs,
    required this.triggeredSos,
    required this.appVersion,
    required this.createdAt,
    this.locationLat,
    this.locationLng,
  });

  final String id;
  final DetectionEventType eventType;
  final String eventTypeDisplay;    // "Scream Detected"
  final String deviceId;
  final double confidence;          // 0.0–1.0
  final String tier;                // "high" | "medium" | "low"
  final String tierDisplay;
  final String detectionMode;       // "ai" | "heuristic"
  final String detectionModeDisplay;
  final double inferenceMs;
  final bool triggeredSos;
  final double? locationLat;
  final double? locationLng;
  final String appVersion;
  final DateTime createdAt;

  factory DetectionEventRecord.fromJson(Map<String, dynamic> json) {
    return DetectionEventRecord(
      id:                   json['id'] as String,
      deviceId:             json['device_id'] as String,
      eventType:            DetectionEventType.fromValue(json['event_type'] as String),
      eventTypeDisplay:     (json['event_type_display'] as String?) ?? '',
      confidence:           (json['confidence'] as num).toDouble(),
      tier:                 json['tier'] as String,
      tierDisplay:          (json['tier_display'] as String?) ?? '',
      detectionMode:        json['detection_mode'] as String,
      detectionModeDisplay: (json['detection_mode_display'] as String?) ?? '',
      inferenceMs:          (json['inference_ms'] as num).toDouble(),
      triggeredSos:         (json['triggered_sos'] as bool?) ?? false,
      locationLat:          json['location_lat'] != null
                                ? (json['location_lat'] as num).toDouble()
                                : null,
      locationLng:          json['location_lng'] != null
                                ? (json['location_lng'] as num).toDouble()
                                : null,
      appVersion:           (json['app_version'] as String?) ?? '',
      createdAt:            DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}

/// Response envelope from GET /api/v1/ml/detection-events/.
class DetectionEventHistory {
  const DetectionEventHistory({
    required this.count,
    required this.events,
  });

  final int count;
  final List<DetectionEventRecord> events;

  static const empty = DetectionEventHistory(count: 0, events: []);
}

// ─── Service ──────────────────────────────────────────────────────────────────

/// Day 55 — logs detection events and fetches event history.
class DetectionEventService {
  const DetectionEventService(this._client);

  final ApiClient _client;

  // ── POST ──────────────────────────────────────────────────────────────────

  /// Log one DCS detection event.
  ///
  /// [tier], [detectionMode], and [inferenceMs] reflect the device's
  /// capability at the time of detection (taken from [CapabilityProbeResult]).
  Future<DetectionEventRecord> submit({
    required DetectionEventType eventType,
    required double confidence,
    required String tier,
    required String detectionMode,
    required double inferenceMs,
    bool triggeredSos = false,
    double? locationLat,
    double? locationLng,
  }) async {
    final deviceId = await CapabilityReportService.getOrCreateDeviceId();

    final body = <String, dynamic>{
      'device_id':      deviceId,
      'event_type':     eventType.value,
      'confidence':     confidence,
      'tier':           tier,
      'detection_mode': detectionMode,
      'inference_ms':   inferenceMs,
      'triggered_sos':  triggeredSos,
      'app_version':    '1.0.0+1',
      if (locationLat != null) 'location_lat': locationLat,
      if (locationLng != null) 'location_lng': locationLng,
    };

    final response = await _client.dio.post<Map<String, dynamic>>(
      ApiConfig.detectionEvents,
      data: body,
    );

    final data = response.data;
    if (data == null || response.statusCode != 201) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        message: 'Submit failed: HTTP ${response.statusCode}',
      );
    }

    return DetectionEventRecord.fromJson(data);
  }

  // ── GET ───────────────────────────────────────────────────────────────────

  /// Fetch the authenticated user's own detection events, newest first.
  ///
  /// All parameters are optional filters.
  Future<DetectionEventHistory> fetchHistory({
    DetectionEventType? eventType,
    bool? triggeredSos,
    String? tier,
    String? deviceId,
  }) async {
    final params = <String, String>{};
    if (eventType != null)    params['event_type']    = eventType.value;
    if (triggeredSos != null) params['triggered_sos'] = triggeredSos.toString();
    if (tier != null && tier.isNotEmpty) params['tier'] = tier;
    if (deviceId != null && deviceId.isNotEmpty) params['device_id'] = deviceId;

    final response = await _client.dio.get<Map<String, dynamic>>(
      ApiConfig.detectionEvents,
      queryParameters: params.isNotEmpty ? params : null,
    );

    final data = response.data;
    if (data == null) return DetectionEventHistory.empty;

    final rawEvents = (data['events'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    return DetectionEventHistory(
      count:  (data['count'] as int?) ?? rawEvents.length,
      events: rawEvents.map(DetectionEventRecord.fromJson).toList(),
    );
  }
}
