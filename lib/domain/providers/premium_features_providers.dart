/// Day 92-93 — Premium Feature Highlights state.
///
/// Feature catalogue + category filter below are still fully self-
/// contained mock data (no real "which features are on my plan" API
/// exists). [subscriptionUsageProvider]'s isPremium/contacts/storage
/// fields, however, were rewired for real on Day 358 (premium tier
/// polish) — it now reads the real Day 303 `subscriptionStatusProvider`
/// (contactLimit, storageLimitMb/storageUsedBytes, hasPremiumBenefits)
/// and the real Day 83 `contactsProvider` (actual contact count) when
/// available, falling back to the original seeded mock only while that
/// data is loading or on error/offline. `activeTimers`/`timersLimit` and
/// `safeZones`/`safeZonesLimit` stay hardcoded mock — no real backend
/// endpoint reports check-in-timer or safe-zone *usage counts* today
/// (Day 65/58 only expose CRUD, not a usage-summary endpoint), documented
/// honestly rather than silently left looking real.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import 'contacts_providers.dart';
import 'premium_subscription_providers.dart';

// ─── Feature category ─────────────────────────────────────────────────────────

enum FeatureCategory { all, protection, storage, communication, management }

extension FeatureCategoryX on FeatureCategory {
  String get label {
    switch (this) {
      case FeatureCategory.all:           return 'All';
      case FeatureCategory.protection:    return 'Protection';
      case FeatureCategory.storage:       return 'Storage';
      case FeatureCategory.communication: return 'Communication';
      case FeatureCategory.management:    return 'Management';
    }
  }

  IconData get icon {
    switch (this) {
      case FeatureCategory.all:           return Icons.apps_rounded;
      case FeatureCategory.protection:    return Icons.shield_rounded;
      case FeatureCategory.storage:       return Icons.folder_rounded;
      case FeatureCategory.communication: return Icons.send_rounded;
      case FeatureCategory.management:    return Icons.settings_rounded;
    }
  }
}

// ─── Feature status ───────────────────────────────────────────────────────────

enum FeatureStatus { available, comingSoon }

extension FeatureStatusX on FeatureStatus {
  String get label {
    switch (this) {
      case FeatureStatus.available:  return 'Available';
      case FeatureStatus.comingSoon: return 'Coming Soon';
    }
  }

  Color get color {
    switch (this) {
      case FeatureStatus.available:  return ZapColors.safe;
      case FeatureStatus.comingSoon: return ZapColors.warning;
    }
  }
}

// ─── Premium feature model ────────────────────────────────────────────────────

class FeatureStat {
  const FeatureStat({required this.label, required this.value});
  final String label;
  final String value;
}

class PremiumFeature {
  const PremiumFeature({
    required this.id,
    required this.category,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.status,
    required this.stats,
    this.freeLimit,
  });

  final String         id;
  final FeatureCategory category;
  final IconData       icon;
  final Color          color;
  final String         title;
  final String         subtitle;
  final String         description;
  final FeatureStatus  status;
  final List<FeatureStat> stats;
  final String?        freeLimit; // null = not on free at all
}

const kPremiumFeatures = <PremiumFeature>[
  PremiumFeature(
    id: 'unlimited_contacts',
    category: FeatureCategory.protection,
    icon: Icons.people_rounded,
    color: ZapColors.info,
    title: 'Unlimited Contacts',
    subtitle: 'Reach everyone who matters',
    description:
        'Add as many emergency contacts as you need — family, friends, '
        'colleagues, neighbours. When seconds count, every contact '
        'is a potential lifeline. Free accounts are limited to 3.',
    status: FeatureStatus.available,
    freeLimit: 'Up to 3',
    stats: [
      FeatureStat(label: 'Free limit',    value: '3 contacts'),
      FeatureStat(label: 'Premium',       value: 'Unlimited'),
      FeatureStat(label: 'Alert reach',   value: '3× wider'),
      FeatureStat(label: 'Channels',      value: 'SMS + Push + Call'),
    ],
  ),
  PremiumFeature(
    id: 'priority_sms',
    category: FeatureCategory.communication,
    icon: Icons.bolt_rounded,
    color: ZapColors.warning,
    title: 'Priority SMS Delivery',
    subtitle: 'Sub-500 ms guaranteed',
    description:
        'Premium SOS alerts are routed through a priority carrier lane — '
        'bypassing shared queues. Dual-carrier fallback ensures delivery '
        'even when one network is overloaded.',
    status: FeatureStatus.available,
    freeLimit: 'Standard delivery',
    stats: [
      FeatureStat(label: 'Free latency',    value: 'Standard (2-5 s)'),
      FeatureStat(label: 'Premium latency', value: '< 500 ms'),
      FeatureStat(label: 'Uptime SLA',      value: '99.9%'),
      FeatureStat(label: 'Carrier routes',  value: 'Dual-carrier fallback'),
    ],
  ),
  PremiumFeature(
    id: 'evidence_vault',
    category: FeatureCategory.storage,
    icon: Icons.folder_rounded,
    color: ZapColors.safe,
    title: '5 GB Evidence Vault',
    subtitle: 'Audio, photo & video — auto-captured',
    description:
        'ZapSafe automatically records audio and captures photos during '
        'active SOS events. All files are AES-256 encrypted at rest and '
        'retained for up to one year — admissible as evidence in '
        'many jurisdictions.',
    status: FeatureStatus.available,
    freeLimit: '100 MB',
    stats: [
      FeatureStat(label: 'Free storage',    value: '100 MB'),
      FeatureStat(label: 'Premium storage', value: '5 GB'),
      FeatureStat(label: 'Encryption',      value: 'AES-256 at rest'),
      FeatureStat(label: 'Retention',       value: '1 year'),
    ],
  ),
  PremiumFeature(
    id: 'offline_sos',
    category: FeatureCategory.protection,
    icon: Icons.wifi_off_rounded,
    color: ZapColors.danger,
    title: 'Offline SOS Mode',
    subtitle: 'No internet? Still protected.',
    description:
        'Premium accounts cache contact details, SOS templates, and GPS '
        'coordinates locally. When you lose connectivity, ZapSafe queues '
        'alerts and fires them the moment a signal is restored — or via '
        'SMS over a cellular connection alone.',
    status: FeatureStatus.available,
    freeLimit: null,
    stats: [
      FeatureStat(label: 'Free',          value: 'Requires internet'),
      FeatureStat(label: 'Premium',       value: 'Full offline support'),
      FeatureStat(label: 'Queue depth',   value: 'Unlimited alerts'),
      FeatureStat(label: 'SMS fallback',  value: 'Cellular only'),
    ],
  ),
  PremiumFeature(
    id: 'safe_zones',
    category: FeatureCategory.protection,
    icon: Icons.location_on_rounded,
    color: ZapColors.safe,
    title: 'Unlimited Safe Zones',
    subtitle: 'Smart geofencing everywhere',
    description:
        'Define GPS safe zones for home, work, school — anywhere you feel '
        'protected. Alerts are automatically suppressed inside zones and '
        're-enabled the moment you leave. Free accounts allow 3 zones.',
    status: FeatureStatus.available,
    freeLimit: '3 zones',
    stats: [
      FeatureStat(label: 'Free limit',    value: '3 zones'),
      FeatureStat(label: 'Premium',       value: 'Unlimited'),
      FeatureStat(label: 'Min radius',    value: '50 m'),
      FeatureStat(label: 'Auto-suppress', value: 'Yes'),
    ],
  ),
  PremiumFeature(
    id: 'timer_chains',
    category: FeatureCategory.protection,
    icon: Icons.timer_rounded,
    color: ZapColors.info,
    title: 'Check-in Timer Chains',
    subtitle: 'Cascading dead-man switches',
    description:
        'Run unlimited simultaneous check-in timers — each with its own '
        'escalation policy, contact list, and SOS message. Chain them '
        'together: if timer A fires, timer B automatically starts as a '
        'follow-up. Free accounts allow 2 active timers.',
    status: FeatureStatus.available,
    freeLimit: '2 active',
    stats: [
      FeatureStat(label: 'Free limit',    value: '2 active timers'),
      FeatureStat(label: 'Premium',       value: 'Unlimited'),
      FeatureStat(label: 'Chaining',      value: 'Supported'),
      FeatureStat(label: 'Min interval',  value: '1 minute'),
    ],
  ),
  PremiumFeature(
    id: 'audit_retention',
    category: FeatureCategory.management,
    icon: Icons.history_rounded,
    color: ZapColors.textSecondary,
    title: '1-Year Audit Trail',
    subtitle: 'Full activity history retained',
    description:
        'Every SOS event, check-in, consent change, and login attempt is '
        'logged in your tamper-evident audit trail. Premium retains the '
        'full year — useful for insurance claims, legal proceedings, and '
        'personal safety reviews. Free retains 30 days.',
    status: FeatureStatus.available,
    freeLimit: '30 days',
    stats: [
      FeatureStat(label: 'Free retention',    value: '30 days'),
      FeatureStat(label: 'Premium retention', value: '365 days'),
      FeatureStat(label: 'Tamper-proof',      value: 'Yes'),
      FeatureStat(label: 'Export formats',    value: 'JSON + ZIP'),
    ],
  ),
  PremiumFeature(
    id: 'priority_support',
    category: FeatureCategory.management,
    icon: Icons.headset_mic_rounded,
    color: ZapColors.warning,
    title: '24/7 Priority Support',
    subtitle: 'Real humans, any time',
    description:
        'Skip the queue entirely. Premium subscribers reach a dedicated '
        'support team via in-app chat, email, or phone — 24 hours a day, '
        '7 days a week. Average first response under 5 minutes.',
    status: FeatureStatus.available,
    freeLimit: null,
    stats: [
      FeatureStat(label: 'Free support',     value: 'Email (48h SLA)'),
      FeatureStat(label: 'Premium support',  value: '24/7 chat + phone'),
      FeatureStat(label: 'First response',   value: '< 5 minutes'),
      FeatureStat(label: 'Channels',         value: 'Chat · Email · Phone'),
    ],
  ),
  PremiumFeature(
    id: 'live_tracking',
    category: FeatureCategory.communication,
    icon: Icons.share_location_rounded,
    color: ZapColors.info,
    title: 'Live Location Sharing',
    subtitle: 'Real-time GPS broadcast to contacts',
    description:
        'Broadcast your live GPS location to all emergency contacts during '
        'an active SOS event. Contacts receive a shareable map link that '
        'updates every 10 seconds — no app install required on their end.',
    status: FeatureStatus.comingSoon,
    freeLimit: null,
    stats: [
      FeatureStat(label: 'Update interval', value: 'Every 10 s'),
      FeatureStat(label: 'Duration',        value: 'Until SOS resolved'),
      FeatureStat(label: 'Accuracy',        value: 'GPS ± 3 m'),
      FeatureStat(label: 'App required',    value: 'No (web link)'),
    ],
  ),
  PremiumFeature(
    id: 'ai_analysis',
    category: FeatureCategory.protection,
    icon: Icons.psychology_rounded,
    color: ZapColors.danger,
    title: 'AI Threat Analysis',
    subtitle: 'Advanced pattern recognition',
    description:
        'On-device ML models analyse audio, motion, and location patterns '
        'in real time — detecting threats like screaming, aggressive motion, '
        'and rapid entry into high-risk areas before you can manually '
        'trigger SOS.',
    status: FeatureStatus.comingSoon,
    freeLimit: 'Basic heuristics only',
    stats: [
      FeatureStat(label: 'Detection modes', value: 'Audio · Motion · GPS'),
      FeatureStat(label: 'Latency',         value: '< 200 ms'),
      FeatureStat(label: 'False positive',  value: '< 2% (target)'),
      FeatureStat(label: 'On-device',       value: 'Yes — private'),
    ],
  ),
];

// ─── Subscription usage model ─────────────────────────────────────────────────

class SubscriptionUsage {
  const SubscriptionUsage({
    required this.isPremium,
    required this.contactsUsed,
    required this.contactsLimit,
    required this.storageMbUsed,
    required this.storageMbLimit,
    required this.activeTimers,
    required this.timersLimit,
    required this.safeZones,
    required this.safeZonesLimit,
  });

  final bool   isPremium;
  final int    contactsUsed;
  final int?   contactsLimit;  // null = unlimited
  final double storageMbUsed;
  final int?   storageMbLimit; // null = unlimited (in MB)
  final int    activeTimers;
  final int?   timersLimit;
  final int    safeZones;
  final int?   safeZonesLimit;

  double get storagePercent {
    if (storageMbLimit == null || storageMbLimit == 0) {
      return 0;
    }
    return (storageMbUsed / storageMbLimit!).clamp(0.0, 1.0);
  }

  String get storageLabel {
    final usedStr = storageMbUsed >= 1024
        ? '${(storageMbUsed / 1024).toStringAsFixed(1)} GB'
        : '${storageMbUsed.toStringAsFixed(0)} MB';
    final limitStr = storageMbLimit == null
        ? 'Unlimited'
        : storageMbLimit! >= 1024
            ? '${(storageMbLimit! / 1024).toStringAsFixed(0)} GB'
            : '$storageMbLimit MB';
    return '$usedStr of $limitStr';
  }
}

// Original seeded mock — free plan with some usage. Used verbatim as the
// fallback while the real subscription status hasn't loaded yet (or is
// unavailable offline), so this screen never flashes an empty/zero state.
const _kMockUsageFallback = SubscriptionUsage(
  isPremium:       false,
  contactsUsed:    2,
  contactsLimit:   3,
  storageMbUsed:   14.3,
  storageMbLimit:  100,
  activeTimers:    1,
  timersLimit:     2,
  safeZones:       2,
  safeZonesLimit:  3,
);

/// Day 358 — real where real data exists, honestly mock where it doesn't.
///
/// isPremium / contactsLimit / storage*: from the real Day 303
/// `subscriptionStatusProvider` once it resolves.
/// contactsUsed: from the real Day 83 `contactsProvider` (actual list
/// length), not a hardcoded number.
/// activeTimers / timersLimit / safeZones / safeZonesLimit: still mock —
/// no real backend usage-count endpoint exists for either (see file
/// header).
final subscriptionUsageProvider = Provider<SubscriptionUsage>((ref) {
  final realStatus = ref.watch(subscriptionStatusProvider).valueOrNull;
  final realContactsUsed = ref.watch(contactsProvider).length;

  if (realStatus == null) {
    // Still loading / offline / error — real contact count is still
    // reflected even in this fallback branch since contactsProvider is
    // synchronous and separately real.
    return SubscriptionUsage(
      isPremium:      _kMockUsageFallback.isPremium,
      contactsUsed:   realContactsUsed,
      contactsLimit:  _kMockUsageFallback.contactsLimit,
      storageMbUsed:  _kMockUsageFallback.storageMbUsed,
      storageMbLimit: _kMockUsageFallback.storageMbLimit,
      activeTimers:   _kMockUsageFallback.activeTimers,
      timersLimit:    _kMockUsageFallback.timersLimit,
      safeZones:      _kMockUsageFallback.safeZones,
      safeZonesLimit: _kMockUsageFallback.safeZonesLimit,
    );
  }

  return SubscriptionUsage(
    isPremium:      realStatus.hasPremiumBenefits,
    contactsUsed:   realContactsUsed,
    contactsLimit:  realStatus.contactLimit,
    storageMbUsed:  realStatus.storageUsedBytes / (1024 * 1024),
    // SubscriptionStatus.storageLimitMb is always a finite number on the
    // real backend (no "0/null = unlimited" convention documented for
    // storage the way contactLimit has) — passed through as-is.
    storageMbLimit: realStatus.storageLimitMb,
    activeTimers:   _kMockUsageFallback.activeTimers,
    timersLimit:    _kMockUsageFallback.timersLimit,
    safeZones:      _kMockUsageFallback.safeZones,
    safeZonesLimit: _kMockUsageFallback.safeZonesLimit,
  );
});

// ─── Filter provider ──────────────────────────────────────────────────────────

final featureCategoryFilterProvider =
    StateProvider<FeatureCategory>((ref) => FeatureCategory.all);

final filteredFeaturesProvider = Provider<List<PremiumFeature>>((ref) {
  final cat = ref.watch(featureCategoryFilterProvider);
  if (cat == FeatureCategory.all) {
    return kPremiumFeatures;
  }
  return kPremiumFeatures.where((f) => f.category == cat).toList();
});
