/// Day 66 — SOS Message Template Service
///
/// GET    /api/v1/sos-templates/              → {count, templates:[...]}  (200)
/// POST   /api/v1/sos-templates/              → SosTemplate               (201)
/// GET    /api/v1/sos-templates/<uuid>/       → SosTemplate               (200)
/// PATCH  /api/v1/sos-templates/<uuid>/       → SosTemplate               (200)
/// DELETE /api/v1/sos-templates/<uuid>/       →                           (204)
/// POST   /api/v1/sos-templates/<uuid>/activate/ → SosTemplate            (200)
library;

import '../../core/constants/api_config.dart';
import 'api_client.dart';

// ─── Model ────────────────────────────────────────────────────────────────────

class SosTemplate {
  const SosTemplate({
    required this.id,
    required this.title,
    required this.body,
    required this.includeLocation,
    required this.includeBatteryLevel,
    required this.isDefault,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String   id;
  final String   title;
  final String   body;
  final bool     includeLocation;
  final bool     includeBatteryLevel;
  final bool     isDefault;
  final String   notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory SosTemplate.fromJson(Map<String, dynamic> j) => SosTemplate(
        id:                  j['id']                     as String,
        title:               j['title']                  as String,
        body:                j['body']                   as String,
        includeLocation:     j['include_location']       as bool,
        includeBatteryLevel: j['include_battery_level']  as bool,
        isDefault:           j['is_default']             as bool,
        notes:               (j['notes'] as String?)     ?? '',
        createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
        updatedAt: DateTime.parse(j['updated_at'] as String).toLocal(),
      );
}

// ─── Service ──────────────────────────────────────────────────────────────────

class SosTemplateService {
  const SosTemplateService(this._client);
  final ApiClient _client;

  /// GET /api/v1/sos-templates/ — ordered default-first then alphabetically.
  Future<List<SosTemplate>> fetchAll() async {
    final r = await _client.dio.get<Map<String, dynamic>>(
      ApiConfig.sosTemplates,
    );
    final data = r.data;
    if (data == null) return [];
    final raw = (data['templates'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    return raw.map(SosTemplate.fromJson).toList();
  }

  /// POST /api/v1/sos-templates/
  Future<SosTemplate> create({
    required String title,
    required String body,
    bool   includeLocation      = true,
    bool   includeBatteryLevel  = false,
    bool   isDefault            = false,
    String notes                = '',
  }) async {
    final r = await _client.dio.post<Map<String, dynamic>>(
      ApiConfig.sosTemplates,
      data: {
        'title':                 title,
        'body':                  body,
        'include_location':      includeLocation,
        'include_battery_level': includeBatteryLevel,
        'is_default':            isDefault,
        'notes':                 notes,
      },
    );
    return SosTemplate.fromJson(r.data!);
  }

  /// PATCH /api/v1/sos-templates/<uuid>/
  Future<SosTemplate> update(
    String id, {
    String? title,
    String? body,
    bool?   includeLocation,
    bool?   includeBatteryLevel,
    bool?   isDefault,
    String? notes,
  }) async {
    final data = <String, dynamic>{};
    if (title               != null) data['title']                 = title;
    if (body                != null) data['body']                  = body;
    if (includeLocation     != null) data['include_location']      = includeLocation;
    if (includeBatteryLevel != null) data['include_battery_level'] = includeBatteryLevel;
    if (isDefault           != null) data['is_default']            = isDefault;
    if (notes               != null) data['notes']                 = notes;

    final r = await _client.dio.patch<Map<String, dynamic>>(
      '${ApiConfig.sosTemplates}$id/',
      data: data,
    );
    return SosTemplate.fromJson(r.data!);
  }

  /// DELETE /api/v1/sos-templates/<uuid>/ → 204
  Future<void> delete(String id) async {
    await _client.dio.delete<void>('${ApiConfig.sosTemplates}$id/');
  }

  /// POST /api/v1/sos-templates/<uuid>/activate/ → set as default.
  Future<SosTemplate> activate(String id) async {
    final r = await _client.dio.post<Map<String, dynamic>>(
      '${ApiConfig.sosTemplates}$id/activate/',
    );
    return SosTemplate.fromJson(r.data!);
  }
}
