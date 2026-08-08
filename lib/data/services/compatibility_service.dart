import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../../core/constants/api_config.dart';
import 'cert_pinning.dart';

// ─── Data models ─────────────────────────────────────────────────────────────

/// Detection mode reported by the backend for a given device.
enum DeviceDetectionMode { ai, heuristic }

/// Pass / fail / untested status for a given device.
enum DeviceCompatStatus { pass, fail, untested }

/// One row from the compatibility matrix.
class CompatibilityEntry {
  const CompatibilityEntry({
    required this.id,
    required this.deviceName,
    required this.deviceFamily,
    required this.year,
    required this.osName,
    required this.osVersion,
    required this.detectionMode,
    required this.detectionModeDisplay,
    required this.expectedResponseMs,
    required this.batteryImpactPct,
    required this.status,
    required this.statusDisplay,
    required this.notes,
    this.testedDate,
  });

  final String id;
  final String deviceName;
  final String deviceFamily;
  final int year;
  final String osName;
  final String osVersion;
  final DeviceDetectionMode detectionMode;
  final String detectionModeDisplay;
  final int expectedResponseMs;
  final double batteryImpactPct;
  final DeviceCompatStatus status;
  final String statusDisplay;
  final String notes;
  final DateTime? testedDate;

  factory CompatibilityEntry.fromJson(Map<String, dynamic> json) {
    return CompatibilityEntry(
      id:                    json['id'] as String,
      deviceName:            json['device_name'] as String,
      deviceFamily:          json['device_family'] as String,
      year:                  json['year'] as int,
      osName:                json['os_name'] as String,
      osVersion:             json['os_version'] as String,
      detectionMode:         (json['detection_mode'] as String) == 'ai'
                                 ? DeviceDetectionMode.ai
                                 : DeviceDetectionMode.heuristic,
      detectionModeDisplay:  json['detection_mode_display'] as String,
      expectedResponseMs:    json['expected_response_ms'] as int,
      batteryImpactPct:      (json['battery_impact_pct'] as num).toDouble(),
      status:                _parseStatus(json['status'] as String),
      statusDisplay:         json['status_display'] as String,
      notes:                 (json['notes'] as String?) ?? '',
      testedDate:            json['tested_date'] != null
                                 ? DateTime.tryParse(json['tested_date'] as String)
                                 : null,
    );
  }

  static DeviceCompatStatus _parseStatus(String raw) {
    switch (raw) {
      case 'pass':     return DeviceCompatStatus.pass;
      case 'fail':     return DeviceCompatStatus.fail;
      default:         return DeviceCompatStatus.untested;
    }
  }
}

/// Summary counts returned alongside the device list.
class CompatibilitySummary {
  const CompatibilitySummary({
    required this.aiDevices,
    required this.heuristicDevices,
    required this.pass,
    required this.fail,
    required this.untested,
  });

  final int aiDevices;
  final int heuristicDevices;
  final int pass;
  final int fail;
  final int untested;

  factory CompatibilitySummary.fromJson(Map<String, dynamic> json) {
    return CompatibilitySummary(
      aiDevices:         (json['ai_devices'] as int?) ?? 0,
      heuristicDevices:  (json['heuristic_devices'] as int?) ?? 0,
      pass:              (json['pass'] as int?) ?? 0,
      fail:              (json['fail'] as int?) ?? 0,
      untested:          (json['untested'] as int?) ?? 0,
    );
  }
}

/// Full response from GET /api/v1/ml/compatibility-matrix/.
class CompatibilityMatrixResult {
  const CompatibilityMatrixResult({
    required this.count,
    required this.summary,
    required this.devices,
  });

  final int count;
  final CompatibilitySummary summary;
  final List<CompatibilityEntry> devices;
}

// ─── Service ──────────────────────────────────────────────────────────────────

/// Day 53 — fetches the device compatibility matrix from the backend.
///
/// The endpoint is public — no Authorization header required.
/// Uses a plain [Dio] instance (no auth interceptor) to keep it simple.
class CompatibilityService {
  CompatibilityService() : _dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      contentType: 'application/json',
      headers: const {'Accept': 'application/json'},
      validateStatus: (s) => s != null && s > 0,
    ),
  ) {
    // Real TLS cert pinning for the production API host — see
    // cert_pinning.dart. This service builds its own separate Dio
    // instance (no shared ApiClient), so it needs the same wiring
    // independently to fix the same Day 336/361 P0 finding.
    _dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () => CertPinning.buildPinnedHttpClient(ApiConfig.baseUrl),
    );
  }

  final Dio _dio;

  /// Fetch the full matrix. Throws [DioException] on network/server errors.
  Future<CompatibilityMatrixResult> fetch() async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiConfig.compatibilityMatrix,
    );

    final data = response.data!;
    final rawDevices = (data['devices'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    return CompatibilityMatrixResult(
      count:   (data['count'] as int?) ?? rawDevices.length,
      summary: CompatibilitySummary.fromJson(
        (data['summary'] as Map<String, dynamic>?) ?? {},
      ),
      devices: rawDevices.map(CompatibilityEntry.fromJson).toList(),
    );
  }
}
