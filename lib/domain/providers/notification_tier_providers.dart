/// Day 306 — Production Notification Tiers.
///
/// Three-tier banner system for the production dashboard
/// ([DashboardPlaceholderScreen], route `/dashboard`):
///   • CRITICAL (red)    — battery <10%, evidence storage full. Must
///     acknowledge; the ack persists (see [NotificationTierAckStorage])
///     until the underlying condition itself clears, at which point the
///     ack is cleared too so a future recurrence surfaces fresh.
///   • IMPORTANT (orange) — unverified Tier-2 contact. Dismissible,
///     re-appears next app session (not persisted — a real contact
///     verification, not a snooze, is the correct fix).
///   • SUGGESTION (blue)  — monthly drill reminder. Lowest priority,
///     dismissible for 30 days via [DrillReminderStorage].
///
/// Real signals used — nothing here is a fabricated placeholder value:
///   • Battery — [batteryProfileProvider] (Day 38 `BatteryService`,
///     real `battery_plus` reading; falls back to `BatteryProfile.unknown`
///     — level -1 — on hosts without the plugin, which is correctly
///     treated as "not critical" below).
///   • Evidence storage — sums real `EvidenceFile.sizeBytes` across
///     [vaultEvidenceProvider] (Day 82) against the real Free-tier cap
///     (`FREE_STORAGE_MB = 50` in `zapsafe_backend/subscription/models.py`).
///     There is no frontend-facing GET quota endpoint on the backend
///     (only server-side 403 enforcement on upload via
///     `enforce_evidence_storage_limit`), so this is computed client-side
///     from the same local evidence list the vault screen already shows —
///     not invented.
///   • Tier-2 contact verification — [contactsProvider] (Day 83, real
///     `ContactsNotifier`, `isVerified` field backed by
///     `POST /api/v1/contacts/<id>/verify/` server-side, though per the
///     Day 301 audit that verify endpoint isn't called from the frontend
///     yet — a real, separate, already-documented gap).
///   • Monthly drill reminder — local-only 30-day nudge (no backend
///     "reminder shown" concept exists; real drills are tracked via
///     `/api/v1/drill/history/`, Day 60).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/notification_tier_storage.dart';
import 'battery_providers.dart';
import 'contacts_providers.dart';
import 'vault_providers.dart';

// ─── Model ──────────────────────────────────────────────────────────────────

enum NotificationTierKind { critical, important, suggestion }

class NotificationTierBanner {
  const NotificationTierBanner({
    required this.id,
    required this.kind,
    required this.title,
    required this.message,
  });

  final String id;
  final NotificationTierKind kind;
  final String title;
  final String message;
}

// ─── Real thresholds ────────────────────────────────────────────────────────

/// Battery <10% — matches `BatteryTier.vadOnly` (Day 38).
const int kCriticalBatteryLevel = 10;

/// Free tier evidence cap — mirrors `FREE_STORAGE_MB = 50` in
/// `zapsafe_backend/subscription/models.py`.
const int kFreeTierEvidenceCapBytes = 50 * 1024 * 1024;

const Duration kDrillReminderInterval = Duration(days: 30);

// ─── Derived condition providers ───────────────────────────────────────────

final vaultStorageBytesUsedProvider = Provider<int>((ref) {
  final entries = ref.watch(vaultEvidenceProvider);
  var total = 0;
  for (final e in entries) {
    for (final f in e.files) {
      total += f.sizeBytes;
    }
  }
  return total;
});

final evidenceStorageFullProvider = Provider<bool>((ref) {
  return ref.watch(vaultStorageBytesUsedProvider) >= kFreeTierEvidenceCapBytes;
});

final batteryCriticalProvider = Provider<bool>((ref) {
  final profile = ref.watch(batteryProfileProvider);
  if (profile.level < 0) return false; // BatteryProfile.unknown — no reading yet
  if (profile.isCharging) return false;
  return profile.level < kCriticalBatteryLevel;
});

final unverifiedTier2ContactProvider = Provider<bool>((ref) {
  final contacts = ref.watch(contactsProvider);
  return contacts.any((c) => c.tier == 2 && !c.isVerified);
});

final drillReminderStorageProvider = Provider<DrillReminderStorage>((ref) {
  return DrillReminderStorage();
});

final drillReminderDueProvider = FutureProvider<bool>((ref) async {
  final storage = ref.watch(drillReminderStorageProvider);
  final last = await storage.lastDismissedAt();
  if (last == null) return true;
  return DateTime.now().difference(last) >= kDrillReminderInterval;
});

// ─── Acknowledgement state (critical banners only) ─────────────────────────

const kCriticalBannerIds = ['battery_critical', 'evidence_storage_full'];

final notificationTierAckStorageProvider = Provider<NotificationTierAckStorage>((ref) {
  return NotificationTierAckStorage();
});

/// Map of bannerId → acknowledged. Hydrated from [NotificationTierAckStorage]
/// on first read of each id.
class NotificationTierAckNotifier extends StateNotifier<Map<String, bool>> {
  NotificationTierAckNotifier(this._storage) : super(const {}) {
    _hydrate();
  }

  final NotificationTierAckStorage _storage;

  Future<void> _hydrate() async {
    final result = <String, bool>{};
    for (final id in kCriticalBannerIds) {
      result[id] = (await _storage.acknowledgedAt(id)) != null;
    }
    if (mounted) state = result;
  }

  Future<void> acknowledge(String bannerId) async {
    state = {...state, bannerId: true};
    await _storage.acknowledge(bannerId);
  }

  /// Called once a condition is observed false — clears any stale ack so
  /// a future recurrence of the same condition surfaces again instead of
  /// staying silently suppressed forever.
  Future<void> clearIfSet(String bannerId) async {
    if (state[bannerId] != true) return;
    state = {...state, bannerId: false};
    await _storage.clear(bannerId);
  }
}

final notificationTierAckProvider =
    StateNotifierProvider<NotificationTierAckNotifier, Map<String, bool>>((ref) {
  return NotificationTierAckNotifier(ref.watch(notificationTierAckStorageProvider));
});

/// Side-effect bridge — same pattern as [appStateGpsBridgeProvider]
/// (`app_state_provider.dart`, Day 38): reacts to condition providers via
/// `ref.listen` (fires *after* the build that produced the new value, not
/// during it) rather than mutating [notificationTierAckProvider] inline
/// inside [activeNotificationBannersProvider]'s own computation — doing the
/// mutation inline there would modify one provider's state while another
/// provider is still being built, which Riverpod flags as unsafe. Kept
/// alive by being watched once from the dashboard screen on mount.
final notificationTierAckBridgeProvider = Provider<void>((ref) {
  ref.listen<bool>(batteryCriticalProvider, (prev, next) {
    if (!next) ref.read(notificationTierAckProvider.notifier).clearIfSet('battery_critical');
  }, fireImmediately: true);
  ref.listen<bool>(evidenceStorageFullProvider, (prev, next) {
    if (!next) {
      ref.read(notificationTierAckProvider.notifier).clearIfSet('evidence_storage_full');
    }
  }, fireImmediately: true);
});

// ─── Combined banner list ───────────────────────────────────────────────────

/// All currently-active banners, already trimmed to "only one critical at
/// a time" (acceptance criterion) — the highest-priority unacknowledged
/// critical condition wins; the rest queue behind it.
final activeNotificationBannersProvider = Provider<List<NotificationTierBanner>>((ref) {
  final ackMap = ref.watch(notificationTierAckProvider);
  final banners = <NotificationTierBanner>[];

  // ── Critical (priority order: battery, then storage) ──────────────────
  final batteryCritical = ref.watch(batteryCriticalProvider);
  final storageFull = ref.watch(evidenceStorageFullProvider);

  if (batteryCritical && ackMap['battery_critical'] != true) {
    banners.add(const NotificationTierBanner(
      id: 'battery_critical',
      kind: NotificationTierKind.critical,
      title: 'Battery below 10%',
      message: 'Sensors are dropping to VAD-only. SOS dispatch still works, '
          'but plug in soon — motion/audio detection is now off.',
    ));
  } else if (storageFull && ackMap['evidence_storage_full'] != true) {
    banners.add(const NotificationTierBanner(
      id: 'evidence_storage_full',
      kind: NotificationTierKind.critical,
      title: 'Evidence storage full',
      message: 'Free plan storage (50 MB) is full. New SOS evidence may fail '
          'to upload. Upgrade to Premium or delete old evidence.',
    ));
  }

  // ── Important ───────────────────────────────────────────────────────────
  if (ref.watch(unverifiedTier2ContactProvider)) {
    banners.add(const NotificationTierBanner(
      id: 'unverified_tier2_contact',
      kind: NotificationTierKind.important,
      title: 'Unverified Tier-2 contact',
      message: 'One or more Tier-2 contacts haven\'t verified their number. '
          'They may not receive your SOS alert.',
    ));
  }

  // ── Suggestion ───────────────────────────────────────────────────────────
  final drillDue = ref.watch(drillReminderDueProvider);
  if (drillDue.value == true) {
    banners.add(const NotificationTierBanner(
      id: 'monthly_drill_reminder',
      kind: NotificationTierKind.suggestion,
      title: 'Monthly drill due',
      message: 'It\'s been a while since your last practice SOS drill. '
          'Run one to keep your contacts response-ready.',
    ));
  }

  return banners;
});
