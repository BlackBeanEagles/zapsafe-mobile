import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Day 306 — persists critical-banner acknowledgements across app kills.
///
/// The Day 306 spec text says "acknowledge persists in local Hive until
/// condition clears". This repo's `main.dart` never calls
/// `Hive.initFlutter()` — the only precedent for "survive app kill"
/// persistence ([GpsStorage], Day 37) deliberately chose
/// `SharedPreferences` over Hive for exactly this reason (see that file's
/// header comment). This service follows the same real precedent rather
/// than being the first production code path to force a Hive box open at
/// boot — that's a bigger infra change than a Day 306 polish task should
/// make unilaterally to `main.dart`'s startup sequence.
///
/// Key: `zapsafe.notif_tier.ack.<bannerId>`. Value: ISO8601 timestamp of
/// the acknowledgement — kept (not just a bool) so a future "re-surface
/// after N days even if condition never cleared" rule has something to
/// read.
class NotificationTierAckStorage {
  static const _prefix = 'zapsafe.notif_tier.ack.';

  Future<void> acknowledge(String bannerId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_prefix$bannerId', DateTime.now().toIso8601String());
    } catch (e) {
      if (kDebugMode) debugPrint('[notif-tier-storage] ack save failed: $e');
    }
  }

  /// Null when never acknowledged (or on read failure).
  Future<DateTime?> acknowledgedAt(String bannerId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefix$bannerId');
      if (raw == null) return null;
      return DateTime.tryParse(raw);
    } catch (e) {
      if (kDebugMode) debugPrint('[notif-tier-storage] ack read failed: $e');
      return null;
    }
  }

  /// Clears one banner's acknowledgement — called when its condition
  /// clears so a future recurrence surfaces again instead of staying
  /// silently suppressed forever.
  Future<void> clear(String bannerId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_prefix$bannerId');
    } catch (_) {
      // best-effort
    }
  }
}

/// Day 306 — local-only monthly drill reminder tracking.
///
/// There is no backend endpoint for "last drill reminder shown" — Day 60's
/// real `/api/v1/drill/start/` + `/history/` record actual completed
/// drills, but the *reminder* itself (30-day nudge) is a pure client-side
/// UX nicety, so it's local-only by design, not a wiring gap.
class DrillReminderStorage {
  static const _key = 'zapsafe.drill.last_reminder_dismissed_at';

  Future<void> dismiss() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, DateTime.now().toIso8601String());
    } catch (e) {
      if (kDebugMode) debugPrint('[drill-reminder-storage] dismiss failed: $e');
    }
  }

  Future<DateTime?> lastDismissedAt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;
      return DateTime.tryParse(raw);
    } catch (e) {
      if (kDebugMode) debugPrint('[drill-reminder-storage] read failed: $e');
      return null;
    }
  }
}
