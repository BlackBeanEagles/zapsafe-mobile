/// Day 54 — Capability Report Service
///
/// Handles:
///   POST /api/v1/ml/device-capability/  — submit a probe result
///   GET  /api/v1/ml/device-capability/  — fetch own report history
///
/// Both endpoints require authentication — every request rides on the
/// [ApiClient] that carries the Authorization header automatically.
library;

import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/api_config.dart';
import 'api_client.dart';
import 'phone_capability_detector.dart';

// ─── Data models ─────────────────────────────────────────────────────────────

/// One capability report record as returned by the backend.
class CapabilityReportRecord {
  const CapabilityReportRecord({
    required this.id,
    required this.deviceId,
    required this.deviceModel,
    required this.osName,
    required this.osVersion,
    required this.inferenceMs,
    required this.tier,
    required this.tierDisplay,
    required this.detectionMode,
    required this.detectionModeDisplay,
    required this.appVersion,
    required this.createdAt,
  });

  final String id;
  final String deviceId;
  final String deviceModel;        // "iPhone 14"
  final String osName;             // "iOS" | "Android"
  final String osVersion;          // "17" | "14"
  final double inferenceMs;        // 87.4
  final String tier;               // "high" | "medium" | "low"
  final String tierDisplay;        // "High — AI models, <100 ms"
  final String detectionMode;      // "ai" | "heuristic"
  final String detectionModeDisplay;
  final String appVersion;         // "1.0.0+1"
  final DateTime createdAt;

  factory CapabilityReportRecord.fromJson(Map<String, dynamic> json) {
    return CapabilityReportRecord(
      id:                   json['id'] as String,
      deviceId:             json['device_id'] as String,
      deviceModel:          (json['device_model'] as String?) ?? '',
      osName:               (json['os_name'] as String?) ?? '',
      osVersion:            (json['os_version'] as String?) ?? '',
      inferenceMs:          (json['inference_ms'] as num).toDouble(),
      tier:                 json['tier'] as String,
      tierDisplay:          (json['tier_display'] as String?) ?? '',
      detectionMode:        json['detection_mode'] as String,
      detectionModeDisplay: (json['detection_mode_display'] as String?) ?? '',
      appVersion:           (json['app_version'] as String?) ?? '',
      createdAt:            DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}

/// Response envelope from GET /api/v1/ml/device-capability/.
class CapabilityReportHistory {
  const CapabilityReportHistory({
    required this.count,
    required this.reports,
  });

  final int count;
  final List<CapabilityReportRecord> reports;

  static const empty = CapabilityReportHistory(count: 0, reports: []);
}

// ─── Service ──────────────────────────────────────────────────────────────────

/// Day 54 — submits capability probe results and fetches report history.
class CapabilityReportService {
  const CapabilityReportService(this._client);

  final ApiClient _client;

  static const _prefKeyDeviceId = 'zapsafe_device_id';

  // ── Device ID ─────────────────────────────────────────────────────────────

  /// Returns the cached app-level device ID, creating one on first call.
  ///
  /// This is a stable UUID persisted in SharedPreferences — not a hardware ID.
  /// It survives app updates but is reset on a fresh install / data clear.
  static Future<String> getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_prefKeyDeviceId);
    if (existing != null && existing.isNotEmpty) return existing;
    final newId = const Uuid().v4();
    await prefs.setString(_prefKeyDeviceId, newId);
    return newId;
  }

  // ── POST ──────────────────────────────────────────────────────────────────

  /// Submit a capability probe result to the backend.
  ///
  /// The device ID, model, OS name/version, and app version are gathered
  /// automatically; only the [probe] result from [PhoneCapabilityDetector]
  /// needs to be passed in.
  Future<CapabilityReportRecord> submit(CapabilityProbeResult probe) async {
    final deviceId = await getOrCreateDeviceId();
    final (model, osName, osVersion) = await _collectDeviceInfo();

    final body = <String, dynamic>{
      'device_id':      deviceId,
      'device_model':   model,
      'os_name':        osName,
      'os_version':     osVersion,
      'inference_ms':   probe.inferenceMs,
      'tier':           probe.tier.name,
      'detection_mode': probe.shouldUseAi ? 'ai' : 'heuristic',
      'app_version':    '1.0.0+1',
    };

    final response = await _client.dio.post<Map<String, dynamic>>(
      ApiConfig.deviceCapability,
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

    return CapabilityReportRecord.fromJson(data);
  }

  // ── GET ───────────────────────────────────────────────────────────────────

  /// Fetch the authenticated user's own capability reports, newest first.
  ///
  /// Optional [deviceId] and [tier] narrow the results to a single device
  /// or tier ("high" | "medium" | "low").
  Future<CapabilityReportHistory> fetchHistory({
    String? deviceId,
    String? tier,
  }) async {
    final params = <String, String>{};
    if (deviceId != null && deviceId.isNotEmpty) params['device_id'] = deviceId;
    if (tier != null && tier.isNotEmpty) params['tier'] = tier;

    final response = await _client.dio.get<Map<String, dynamic>>(
      ApiConfig.deviceCapability,
      queryParameters: params.isNotEmpty ? params : null,
    );

    final data = response.data;
    if (data == null) return CapabilityReportHistory.empty;

    final rawReports = (data['reports'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    return CapabilityReportHistory(
      count:   (data['count'] as int?) ?? rawReports.length,
      reports: rawReports.map(CapabilityReportRecord.fromJson).toList(),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Returns (deviceModel, osName, osVersion) using device_info_plus.
  /// Falls back to empty strings on any error or unsupported platform.
  static Future<(String, String, String)> _collectDeviceInfo() async {
    try {
      final plugin = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        return (info.model, 'Android', info.version.release);
      } else if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        return (info.utsname.machine, 'iOS', info.systemVersion);
      }
    } catch (_) {}
    return ('', '', '');
  }
}
