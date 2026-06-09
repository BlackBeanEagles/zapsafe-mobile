import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/gps_sample.dart';

/// Day 37 — persists the last-known [GpsSample] across app kills.
///
/// Implementation uses `SharedPreferences` (already initialised since
/// Day 13) rather than Hive — the timeline mentions Hive, but for one
/// JSON-shaped record SharedPreferences gives the same "survives app
/// kill" guarantee without forcing a `Hive.initFlutter()` call into the
/// app startup path.
///
/// Key: `zapsafe.gps.last`. Value: JSON string of [GpsSample.toMap].
class GpsStorage {
  static const _key = 'zapsafe.gps.last';

  /// Writes the most recent fix. Silently ignores serialization
  /// failures — losing one cache entry isn't worth crashing the app.
  Future<void> save(GpsSample sample) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(sample.toMap()));
    } catch (e) {
      if (kDebugMode) debugPrint('[gps-storage] save failed: $e');
    }
  }

  /// Reads the last-known fix. Returns null on a cold install or when
  /// the stored JSON is malformed.
  Future<GpsSample?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;
      final map = jsonDecode(raw);
      if (map is! Map<String, dynamic>) return null;
      return GpsSample.fromMap(map);
    } catch (e) {
      if (kDebugMode) debugPrint('[gps-storage] read failed: $e');
      return null;
    }
  }

  /// Removes the cached fix. Used at logout / data-wipe time.
  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {
      // best-effort
    }
  }
}
