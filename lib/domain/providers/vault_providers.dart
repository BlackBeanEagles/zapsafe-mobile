/// Day 82 — Evidence Vault state management.
///
/// [vaultLockProvider]       — whether the vault is currently PIN-locked.
/// [vaultWrongPinCountProvider] — wrong PIN attempt counter (LP23 cascade).
/// [vaultEvidenceProvider]   — mock list of SOS evidence entries.
///
/// LP16: vault PIN is independent from SOS cancel/duress PINs.
/// LP23: 3 wrong → key-rotate banner; 5 wrong → wipe state.
///
/// Day 309 — added [EvidenceEntry.triggerCategory] / [EvidenceEntry.status]
/// plus the filter providers at the bottom of this file
/// ([vaultDateRangeFilterProvider], [vaultTriggerFilterProvider],
/// [vaultStatusFilterProvider], [vaultTamperOnlyFilterProvider],
/// [vaultSearchQueryProvider], combined by [filteredVaultEvidenceProvider]
/// with AND logic). All local — this evidence list is still the Day 82
/// mock (comment below: "replaced by GET /api/v1/vault/ in Month 4"), so
/// filtering is genuinely offline/local-only, matching the Day 309 spec's
/// "filters work on local Hive/cache data offline" acceptance criterion.
/// A real backend search endpoint does exist —
/// `GET /api/v1/evidence/search/?q=&type=&from=&to=` (Day 209,
/// `zapsafe_backend/evidence/search_views.py`) — but it wasn't in the Day
/// 301 audit's seed list (a real gap, now added there) and wiring it is
/// out of scope for this polish day, which explicitly asks for offline
/// filtering, not another live-wire day.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/vault_pin_storage.dart';

// ─── File type ────────────────────────────────────────────────────────────────

enum EvidenceFileType {
  audio,
  videoFront,
  videoRear,
  imu,
  gps,
  dcsLog;

  String get label {
    switch (this) {
      case EvidenceFileType.audio:      return 'Audio';
      case EvidenceFileType.videoFront: return 'Video (front)';
      case EvidenceFileType.videoRear:  return 'Video (rear)';
      case EvidenceFileType.imu:        return 'IMU data';
      case EvidenceFileType.gps:        return 'GPS track';
      case EvidenceFileType.dcsLog:     return 'DCS log';
    }
  }

  String get ext {
    switch (this) {
      case EvidenceFileType.audio:      return '.opus';
      case EvidenceFileType.videoFront: return '.mp4';
      case EvidenceFileType.videoRear:  return '.mp4';
      case EvidenceFileType.imu:        return '.csv';
      case EvidenceFileType.gps:        return '.gpx';
      case EvidenceFileType.dcsLog:     return '.jsonl';
    }
  }
}

// ─── Data models ──────────────────────────────────────────────────────────────

class EvidenceFile {
  const EvidenceFile({
    required this.type,
    required this.sizeBytes,
    this.durationSec,
    required this.sha256,
    required this.isTampered,
  });

  final EvidenceFileType type;
  final int              sizeBytes;
  final int?             durationSec;
  final String           sha256;        // full 64-char hex
  final bool             isTampered;

  String get hashPreview =>
      '${sha256.substring(0, 8)}…${sha256.substring(sha256.length - 4)}';

  String get sizeLabel {
    if (sizeBytes < 1024)         return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024)  return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String? get durationLabel {
    if (durationSec == null) return null;
    final m = durationSec! ~/ 60;
    final s = durationSec! % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

/// Day 309 — normalized trigger bucket used by the filter chips.
/// [EvidenceEntry.triggerType] stays as the free-text display label
/// (e.g. "Scream detected") — this is the machine-filterable category
/// behind it.
enum EvidenceTriggerCategory { manual, ai, fall }

/// Day 309 — outcome status used by the filter chips.
enum EvidenceStatus { resolved, falsePositive, drill }

extension EvidenceStatusLabel on EvidenceStatus {
  String get label => switch (this) {
        EvidenceStatus.resolved => 'Resolved',
        EvidenceStatus.falsePositive => 'False positive',
        EvidenceStatus.drill => 'Drill',
      };
}

extension EvidenceTriggerCategoryLabel on EvidenceTriggerCategory {
  String get label => switch (this) {
        EvidenceTriggerCategory.manual => 'Manual',
        EvidenceTriggerCategory.ai => 'AI',
        EvidenceTriggerCategory.fall => 'Fall',
      };
}

class EvidenceEntry {
  const EvidenceEntry({
    required this.sosId,
    required this.timestamp,
    required this.locationLabel,
    required this.files,
    required this.hasTamperFlag,
    required this.expiresAt,
    required this.triggerType,
    required this.triggerCategory,
    required this.status,
  });

  final String         sosId;
  final DateTime       timestamp;
  final String         locationLabel;
  final List<EvidenceFile> files;
  final bool           hasTamperFlag;
  final DateTime       expiresAt;
  final String         triggerType;
  final EvidenceTriggerCategory triggerCategory;
  final EvidenceStatus status;

  int get daysUntilExpiry =>
      expiresAt.difference(DateTime.now()).inDays.clamp(0, 9999);
}

// ─── Mock data ────────────────────────────────────────────────────────────────

List<EvidenceEntry> _buildMockEntries() {
  final now = DateTime.now();

  String fakeHash(int seed) {
    const chars = '0123456789abcdef';
    final buf   = StringBuffer();
    for (var i = 0; i < 64; i++) {
      buf.write(chars[(seed * 31 + i * 7) % chars.length]);
    }
    return buf.toString();
  }

  return [
    EvidenceEntry(
      sosId:         'SOS-20260528-001',
      timestamp:     now.subtract(const Duration(hours: 3)),
      locationLabel: 'Connaught Place, Delhi',
      triggerType:   'Scream detected',
      triggerCategory: EvidenceTriggerCategory.ai,
      status:        EvidenceStatus.resolved,
      hasTamperFlag: false,
      expiresAt:     now.add(const Duration(days: 28)),
      files: [
        EvidenceFile(type: EvidenceFileType.audio,      sizeBytes: 2450000,  durationSec: 183,  sha256: fakeHash(1),  isTampered: false),
        EvidenceFile(type: EvidenceFileType.videoFront, sizeBytes: 48200000, durationSec: 183,  sha256: fakeHash(2),  isTampered: false),
        EvidenceFile(type: EvidenceFileType.videoRear,  sizeBytes: 51000000, durationSec: 183,  sha256: fakeHash(3),  isTampered: false),
        EvidenceFile(type: EvidenceFileType.imu,        sizeBytes: 124000,   durationSec: null, sha256: fakeHash(4),  isTampered: false),
        EvidenceFile(type: EvidenceFileType.gps,        sizeBytes: 18400,    durationSec: null, sha256: fakeHash(5),  isTampered: false),
        EvidenceFile(type: EvidenceFileType.dcsLog,     sizeBytes: 32800,    durationSec: null, sha256: fakeHash(6),  isTampered: false),
      ],
    ),
    EvidenceEntry(
      sosId:         'SOS-20260527-003',
      timestamp:     now.subtract(const Duration(days: 1, hours: 7)),
      locationLabel: 'Lajpat Nagar, Delhi',
      triggerType:   'Manual trigger',
      triggerCategory: EvidenceTriggerCategory.manual,
      status:        EvidenceStatus.falsePositive,
      hasTamperFlag: true,
      expiresAt:     now.add(const Duration(days: 2)),
      files: [
        EvidenceFile(type: EvidenceFileType.audio,      sizeBytes: 890000,   durationSec: 67,   sha256: fakeHash(7),  isTampered: true),
        EvidenceFile(type: EvidenceFileType.videoFront, sizeBytes: 19400000, durationSec: 67,   sha256: fakeHash(8),  isTampered: false),
        EvidenceFile(type: EvidenceFileType.videoRear,  sizeBytes: 21000000, durationSec: 67,   sha256: fakeHash(9),  isTampered: false),
        EvidenceFile(type: EvidenceFileType.imu,        sizeBytes: 44200,    durationSec: null, sha256: fakeHash(10), isTampered: false),
        EvidenceFile(type: EvidenceFileType.gps,        sizeBytes: 6800,     durationSec: null, sha256: fakeHash(11), isTampered: false),
        EvidenceFile(type: EvidenceFileType.dcsLog,     sizeBytes: 11400,    durationSec: null, sha256: fakeHash(12), isTampered: false),
      ],
    ),
    EvidenceEntry(
      sosId:         'SOS-20260520-002',
      timestamp:     now.subtract(const Duration(days: 8)),
      locationLabel: 'Saket, Delhi',
      triggerType:   'Motion detected',
      triggerCategory: EvidenceTriggerCategory.ai,
      status:        EvidenceStatus.drill,
      hasTamperFlag: false,
      expiresAt:     now.add(const Duration(days: 22)),
      files: [
        EvidenceFile(type: EvidenceFileType.audio,      sizeBytes: 5100000,   durationSec: 381, sha256: fakeHash(13), isTampered: false),
        EvidenceFile(type: EvidenceFileType.videoFront, sizeBytes: 102000000, durationSec: 381, sha256: fakeHash(14), isTampered: false),
        EvidenceFile(type: EvidenceFileType.videoRear,  sizeBytes: 98000000,  durationSec: 381, sha256: fakeHash(15), isTampered: false),
        EvidenceFile(type: EvidenceFileType.imu,        sizeBytes: 280000,    durationSec: null, sha256: fakeHash(16), isTampered: false),
        EvidenceFile(type: EvidenceFileType.gps,        sizeBytes: 42000,     durationSec: null, sha256: fakeHash(17), isTampered: false),
        EvidenceFile(type: EvidenceFileType.dcsLog,     sizeBytes: 76000,     durationSec: null, sha256: fakeHash(18), isTampered: false),
      ],
    ),
  ];
}

// ─── Providers ────────────────────────────────────────────────────────────────

/// Whether the vault is currently unlocked.
final vaultLockedProvider = StateProvider<bool>((ref) => true);

/// Wrong PIN attempt count (LP23 cascade).
final vaultWrongPinCountProvider = StateProvider<int>((ref) => 0);

/// Whether vault has been wiped (LP23: 5 wrong PINs).
final vaultWipedProvider = StateProvider<bool>((ref) => false);

/// Mock evidence entries (replaced by GET /api/v1/vault/ in Month 4).
final vaultEvidenceProvider =
    Provider<List<EvidenceEntry>>((ref) => _buildMockEntries());

// LP16 — was: vault PIN hardcoded to '1234' for every install (Day 336/361
// P1 finding). Now backed by [VaultPinStorage] — a real, per-install,
// user-chosen PIN, its hash held in FlutterSecureStorage (Keystore/Keychain
// backed), the same storage mechanism already used for auth tokens
// ([TokenStorage]). See vault_pin_storage.dart for the full design note.
final vaultPinStorageProvider = Provider<VaultPinStorage>((ref) => VaultPinStorage());

/// Whether a real vault PIN has ever been set on this device. Drives
/// whether the PIN gate shows "set up your PIN" (first run / post-wipe)
/// or "enter your PIN" (already configured).
/// Callers must `ref.invalidate(vaultHasPinProvider)` after `setPin()` /
/// `clearPin()` — Riverpod FutureProviders don't otherwise know storage
/// changed underneath them.
final vaultHasPinProvider = FutureProvider<bool>((ref) {
  return ref.watch(vaultPinStorageProvider).hasPin();
});

// ─── Day 309 — Evidence Vault Search filters ───────────────────────────────────

enum EvidenceDateRangeFilter {
  all,
  last7Days,
  last30Days;

  String get label => switch (this) {
        EvidenceDateRangeFilter.all => 'Any date',
        EvidenceDateRangeFilter.last7Days => 'Last 7 days',
        EvidenceDateRangeFilter.last30Days => 'Last 30 days',
      };
}

enum EvidenceTriggerFilter {
  all,
  manual,
  ai,
  fall;

  String get label => switch (this) {
        EvidenceTriggerFilter.all => 'Any trigger',
        EvidenceTriggerFilter.manual => 'Manual',
        EvidenceTriggerFilter.ai => 'AI',
        EvidenceTriggerFilter.fall => 'Fall',
      };
}

enum EvidenceStatusFilter {
  all,
  resolved,
  falsePositive,
  drill;

  String get label => switch (this) {
        EvidenceStatusFilter.all => 'Any status',
        EvidenceStatusFilter.resolved => 'Resolved',
        EvidenceStatusFilter.falsePositive => 'False positive',
        EvidenceStatusFilter.drill => 'Drill',
      };
}

final vaultDateRangeFilterProvider =
    StateProvider<EvidenceDateRangeFilter>((ref) => EvidenceDateRangeFilter.all);
final vaultTriggerFilterProvider =
    StateProvider<EvidenceTriggerFilter>((ref) => EvidenceTriggerFilter.all);
final vaultStatusFilterProvider =
    StateProvider<EvidenceStatusFilter>((ref) => EvidenceStatusFilter.all);
final vaultTamperOnlyFilterProvider = StateProvider<bool>((ref) => false);

/// SOS id prefix search. Case-insensitive `startsWith` — matches the Day
/// 309 spec's "Search by SOS id prefix" acceptance item literally (not a
/// general substring/fuzzy search).
final vaultSearchQueryProvider = StateProvider<String>((ref) => '');

/// True when at least one filter/search control is non-default — drives
/// whether the "Clear filters" affordance is shown.
final vaultAnyFilterActiveProvider = Provider<bool>((ref) {
  return ref.watch(vaultDateRangeFilterProvider) != EvidenceDateRangeFilter.all ||
      ref.watch(vaultTriggerFilterProvider) != EvidenceTriggerFilter.all ||
      ref.watch(vaultStatusFilterProvider) != EvidenceStatusFilter.all ||
      ref.watch(vaultTamperOnlyFilterProvider) ||
      ref.watch(vaultSearchQueryProvider).trim().isNotEmpty;
});

/// All active filters combined with AND logic (Day 309 acceptance
/// criterion), applied to the same local/offline [vaultEvidenceProvider]
/// list the vault screen already renders — no network call.
final filteredVaultEvidenceProvider = Provider<List<EvidenceEntry>>((ref) {
  final entries = ref.watch(vaultEvidenceProvider);
  final dateRange = ref.watch(vaultDateRangeFilterProvider);
  final trigger = ref.watch(vaultTriggerFilterProvider);
  final status = ref.watch(vaultStatusFilterProvider);
  final tamperOnly = ref.watch(vaultTamperOnlyFilterProvider);
  final query = ref.watch(vaultSearchQueryProvider).trim().toLowerCase();
  final now = DateTime.now();

  return entries.where((e) {
    if (dateRange == EvidenceDateRangeFilter.last7Days &&
        now.difference(e.timestamp) > const Duration(days: 7)) {
      return false;
    }
    if (dateRange == EvidenceDateRangeFilter.last30Days &&
        now.difference(e.timestamp) > const Duration(days: 30)) {
      return false;
    }
    if (trigger != EvidenceTriggerFilter.all && e.triggerCategory.name != trigger.name) {
      return false;
    }
    if (status != EvidenceStatusFilter.all && e.status.name != status.name) {
      return false;
    }
    if (tamperOnly && !e.hasTamperFlag) {
      return false;
    }
    if (query.isNotEmpty && !e.sosId.toLowerCase().startsWith(query)) {
      return false;
    }
    return true;
  }).toList();
});
