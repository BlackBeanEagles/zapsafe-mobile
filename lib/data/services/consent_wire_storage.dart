import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Day 319 — local storage for the GDPR consent flags, following the
/// exact Day 306 `NotificationTierAckStorage` / Day 37 `GpsStorage`
/// precedent: `SharedPreferences`, not Hive, because `main.dart` never
/// calls `Hive.initFlutter()`.
///
/// Field names deliberately match the REAL backend contract this session
/// confirmed live in `zapsafe_backend/account/models.py`'s `UserConsent`
/// model and `account/views.py`'s `ConsentView` — not the generic
/// `{ "analytics", "marketing", "location_history" }` placeholder shape
/// from the Day 319 spec text, which doesn't match any real field on
/// this backend. The real fields are:
///   location_sos, evidence_recording, cloud_backup,
///   heatmap_contribution, analytics, model_improvement
///
/// This is also the same shape Day 155's `_ConsentValuesProvider` /
/// `_ApiContractTab` already documented — this storage class is the
/// first thing in the repo that actually persists it across app kills
/// (Day 155-157 only ever held it in an in-memory `StateProvider`,
/// despite their headers saying "Hive storage").
///
/// Key: `zapsafe.consent.<field>`. Value: `"true"`/`"false"` string.
class ConsentWireStorage {
  static const _prefix = 'zapsafe.consent.';

  Future<void> setFlag(String field, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_prefix$field', value);
      await prefs.setString('$_prefix$field.updated_at', DateTime.now().toIso8601String());
    } catch (e) {
      if (kDebugMode) debugPrint('[consent-wire-storage] setFlag failed: $e');
    }
  }

  /// Returns null when never set (caller should fall back to the field's
  /// default value).
  Future<bool?> getFlag(String field) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('$_prefix$field');
    } catch (e) {
      if (kDebugMode) debugPrint('[consent-wire-storage] getFlag failed: $e');
      return null;
    }
  }

  Future<DateTime?> getUpdatedAt(String field) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefix$field.updated_at');
      if (raw == null) return null;
      return DateTime.tryParse(raw);
    } catch (_) {
      return null;
    }
  }

  /// Serializes every currently-stored flag into the exact real
  /// `UserConsent.as_contract_dict()` shape — this is the payload that
  /// would become the body of a real `PUT /api/v1/account/consent/`
  /// call once this screen graduates from MOCK-NOW to live-wired.
  Future<String> exportAsContractJson(Map<String, bool> currentValues) async {
    final body = {
      ...currentValues,
      'updated_at': DateTime.now().toIso8601String(),
    };
    return jsonEncode(body);
  }
}
