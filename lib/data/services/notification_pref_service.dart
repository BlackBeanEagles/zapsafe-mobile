/// Day 67 — Notification Category Preference Service
///
/// GET   /api/v1/notification-prefs/              → {count, prefs:[5]}  (200)
/// GET   /api/v1/notification-prefs/<category>/   → NotificationCategoryPref (200)
/// PATCH /api/v1/notification-prefs/<category>/   → NotificationCategoryPref (200)
///
/// Categories: sos_alert · check_in · drill · insight · digest
library;

import '../../core/constants/api_config.dart';
import 'api_client.dart';

// ─── Model ────────────────────────────────────────────────────────────────────

class NotificationCategoryPref {
  const NotificationCategoryPref({
    required this.id,
    required this.category,
    required this.pushEnabled,
    required this.smsEnabled,
    required this.bypassQuietHours,
    required this.updatedAt,
  });

  final String   id;
  final String   category;
  final bool     pushEnabled;
  final bool     smsEnabled;
  final bool     bypassQuietHours;
  final DateTime updatedAt;

  factory NotificationCategoryPref.fromJson(Map<String, dynamic> j) =>
      NotificationCategoryPref(
        id:               j['id']                  as String,
        category:         j['category']            as String,
        pushEnabled:      j['push_enabled']        as bool,
        smsEnabled:       j['sms_enabled']         as bool,
        bypassQuietHours: j['bypass_quiet_hours']  as bool,
        updatedAt: DateTime.parse(j['updated_at'] as String).toLocal(),
      );

  NotificationCategoryPref copyWith({
    bool? pushEnabled,
    bool? smsEnabled,
    bool? bypassQuietHours,
  }) =>
      NotificationCategoryPref(
        id:               id,
        category:         category,
        pushEnabled:      pushEnabled      ?? this.pushEnabled,
        smsEnabled:       smsEnabled       ?? this.smsEnabled,
        bypassQuietHours: bypassQuietHours ?? this.bypassQuietHours,
        updatedAt:        updatedAt,
      );
}

// ─── Service ──────────────────────────────────────────────────────────────────

class NotificationPrefService {
  const NotificationPrefService(this._client);
  final ApiClient _client;

  /// GET /api/v1/notification-prefs/ — auto-seeds all 5 rows server-side.
  Future<List<NotificationCategoryPref>> fetchAll() async {
    final r = await _client.dio.get<Map<String, dynamic>>(
      ApiConfig.notificationPrefs,
    );
    final raw = (r.data!['prefs'] as List<dynamic>).cast<Map<String, dynamic>>();
    return raw.map(NotificationCategoryPref.fromJson).toList();
  }

  /// PATCH /api/v1/notification-prefs/<category>/
  /// All fields optional — partial update.
  Future<NotificationCategoryPref> update(
    String category, {
    bool? pushEnabled,
    bool? smsEnabled,
    bool? bypassQuietHours,
  }) async {
    final data = <String, dynamic>{};
    if (pushEnabled      != null) data['push_enabled']       = pushEnabled;
    if (smsEnabled       != null) data['sms_enabled']        = smsEnabled;
    if (bypassQuietHours != null) data['bypass_quiet_hours'] = bypassQuietHours;

    final r = await _client.dio.patch<Map<String, dynamic>>(
      '${ApiConfig.notificationPrefs}$category/',
      data: data,
    );
    return NotificationCategoryPref.fromJson(r.data!);
  }
}
