/// Day 58 — Safe Zone Service
///
/// Handles full CRUD for user-defined circular GPS safe zones:
///   GET    /api/v1/safe-zones/          list
///   POST   /api/v1/safe-zones/          create
///   GET    /api/v1/safe-zones/<pk>/     retrieve
///   PATCH  /api/v1/safe-zones/<pk>/     partial update
///   DELETE /api/v1/safe-zones/<pk>/     delete
///
/// All endpoints require authentication — rides on [ApiClient].
library;

import 'package:dio/dio.dart';

import '../../core/constants/api_config.dart';
import 'api_client.dart';

// ─── Data model ───────────────────────────────────────────────────────────────

class SafeZone {
  const SafeZone({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.isActive,
    required this.notifyOnEntry,
    required this.notifyOnExit,
    required this.color,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final int    radiusMeters;
  final bool   isActive;
  final bool   notifyOnEntry;
  final bool   notifyOnExit;
  final String color;          // "#RRGGBB"
  final DateTime createdAt;
  final DateTime updatedAt;

  factory SafeZone.fromJson(Map<String, dynamic> json) => SafeZone(
        id:            json['id'] as String,
        name:          json['name'] as String,
        latitude:      (json['latitude']  as num).toDouble(),
        longitude:     (json['longitude'] as num).toDouble(),
        radiusMeters:  (json['radius_meters'] as int),
        isActive:      (json['is_active'] as bool? ) ?? true,
        notifyOnEntry: (json['notify_on_entry'] as bool?) ?? true,
        notifyOnExit:  (json['notify_on_exit']  as bool?) ?? true,
        color:         (json['color'] as String?) ?? '#06D6A0',
        createdAt:     DateTime.parse(json['created_at'] as String).toLocal(),
        updatedAt:     DateTime.parse(json['updated_at'] as String).toLocal(),
      );

  /// Returns a copy with the given fields overridden.
  SafeZone copyWith({
    String? name,
    double? latitude,
    double? longitude,
    int?    radiusMeters,
    bool?   isActive,
    bool?   notifyOnEntry,
    bool?   notifyOnExit,
    String? color,
  }) => SafeZone(
        id:            id,
        name:          name          ?? this.name,
        latitude:      latitude      ?? this.latitude,
        longitude:     longitude     ?? this.longitude,
        radiusMeters:  radiusMeters  ?? this.radiusMeters,
        isActive:      isActive      ?? this.isActive,
        notifyOnEntry: notifyOnEntry ?? this.notifyOnEntry,
        notifyOnExit:  notifyOnExit  ?? this.notifyOnExit,
        color:         color         ?? this.color,
        createdAt:     createdAt,
        updatedAt:     updatedAt,
      );
}

/// Response envelope from GET /api/v1/safe-zones/.
class SafeZoneList {
  const SafeZoneList({required this.count, required this.zones});
  final int count;
  final List<SafeZone> zones;
  static const empty = SafeZoneList(count: 0, zones: []);
}

// ─── Service ──────────────────────────────────────────────────────────────────

class SafeZoneService {
  const SafeZoneService(this._client);
  final ApiClient _client;

  // ── LIST ──────────────────────────────────────────────────────────────────

  Future<SafeZoneList> fetchAll({bool? isActive}) async {
    final params = <String, String>{};
    if (isActive != null) params['is_active'] = isActive.toString();

    final r = await _client.dio.get<Map<String, dynamic>>(
      ApiConfig.safeZones,
      queryParameters: params.isNotEmpty ? params : null,
    );
    final data = r.data;
    if (data == null) return SafeZoneList.empty;

    final raw = (data['zones'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    return SafeZoneList(
      count: (data['count'] as int?) ?? raw.length,
      zones: raw.map(SafeZone.fromJson).toList(),
    );
  }

  // ── CREATE ────────────────────────────────────────────────────────────────

  Future<SafeZone> create({
    required String name,
    required double latitude,
    required double longitude,
    int    radiusMeters  = 200,
    bool   isActive      = true,
    bool   notifyOnEntry = true,
    bool   notifyOnExit  = true,
    String color         = '#06D6A0',
  }) async {
    final r = await _client.dio.post<Map<String, dynamic>>(
      ApiConfig.safeZones,
      data: {
        'name':             name,
        'latitude':         latitude,
        'longitude':        longitude,
        'radius_meters':    radiusMeters,
        'is_active':        isActive,
        'notify_on_entry':  notifyOnEntry,
        'notify_on_exit':   notifyOnExit,
        'color':            color,
      },
    );
    final data = r.data;
    if (data == null || r.statusCode != 201) {
      throw DioException(
        requestOptions: r.requestOptions,
        response: r,
        message: 'Create failed: HTTP ${r.statusCode}',
      );
    }
    return SafeZone.fromJson(data);
  }

  // ── RETRIEVE ──────────────────────────────────────────────────────────────

  Future<SafeZone> retrieve(String id) async {
    final r = await _client.dio.get<Map<String, dynamic>>(
      '${ApiConfig.safeZones}$id/',
    );
    return SafeZone.fromJson(r.data!);
  }

  // ── PATCH ─────────────────────────────────────────────────────────────────

  Future<SafeZone> patch(String id, Map<String, dynamic> fields) async {
    final r = await _client.dio.patch<Map<String, dynamic>>(
      '${ApiConfig.safeZones}$id/',
      data: fields,
    );
    return SafeZone.fromJson(r.data!);
  }

  // ── DELETE ────────────────────────────────────────────────────────────────

  Future<void> delete(String id) async {
    await _client.dio.delete<void>('${ApiConfig.safeZones}$id/');
  }
}
