/// Day 202 — Dashboard Notification Hierarchy
///
/// Section A (Days 201-220): 3-tier inline dashboard banners.
/// Critical (ack required) · Important (dismissible) · Suggestion (low priority).
///
/// Tag: 🟣 POLISH — ships reusable [DashboardNotificationBanner] widget.
///
/// Route: [AppRoutes.dashboardNotifications] → `/dashboard-notifications`
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../widgets/dashboard_notification_banner.dart';

// ── Providers ─────────────────────────────────────────────────────────────────
final _d202TabProvider = StateProvider<int>((ref) => 0);

/// Active notification ids (mock dashboard state).
final _d202ActiveProvider = StateProvider<Set<String>>((ref) => {
      'critical_battery',
      'important_contact',
      'suggestion_drill',
    });

/// Critical items awaiting acknowledge (cannot dismiss until ack).
final _d202PendingAckProvider = StateProvider<Set<String>>((ref) => {
      'critical_battery',
    });

final _d202ShowCriticalProvider = StateProvider<bool>((ref) => true);
final _d202ShowImportantProvider = StateProvider<bool>((ref) => true);
final _d202ShowSuggestionProvider = StateProvider<bool>((ref) => true);

const _kTabs = ['Live Preview', 'Tier Controls', 'Spec'];

const _kSeedNotifications = [
  DashboardNotificationData(
    id: 'critical_battery',
    tier: DashboardNotificationTier.critical,
    title: 'Battery critically low',
    message:
        'Battery below 10%. SOS evidence may be limited to audio-only until you charge.',
  ),
  DashboardNotificationData(
    id: 'important_contact',
    tier: DashboardNotificationTier.important,
    title: 'Tier 2 contact unverified',
    message:
        'Priya Sharma has not confirmed your emergency contact request. They may not receive SMS backup.',
    actionLabel: 'Verify now',
  ),
  DashboardNotificationData(
    id: 'suggestion_drill',
    tier: DashboardNotificationTier.suggestion,
    title: 'Monthly drill due',
    message: 'Last drill was 28 days ago. A 10-second practice keeps contacts prepared.',
    actionLabel: 'Start drill',
  ),
];

// ── Screen ────────────────────────────────────────────────────────────────────
class Day202DashboardNotificationsScreen extends ConsumerWidget {
  const Day202DashboardNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d202TabProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 202 · Dashboard Alerts'),
      ),
      body: Column(
        children: [
          _TabBar(
            tab: tab,
            onSelect: (i) => ref.read(_d202TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (tab) {
              0 => const _PreviewTab(),
              1 => const _ControlsTab(),
              _ => const _SpecTab(),
            },
          ),
        ],
      ),
    );
  }

  static List<DashboardNotificationData> _visibleNotifications(WidgetRef ref) {
    final showC = ref.watch(_d202ShowCriticalProvider);
    final showI = ref.watch(_d202ShowImportantProvider);
    final showS = ref.watch(_d202ShowSuggestionProvider);
    final active = ref.watch(_d202ActiveProvider);
    final pendingAck = ref.watch(_d202PendingAckProvider);

    return _kSeedNotifications.where((n) {
      if (!active.contains(n.id)) return false;
      if (n.tier == DashboardNotificationTier.critical) {
        if (!showC) return false;
        if (pendingAck.contains(n.id)) return true;
        return false;
      }
      if (n.tier == DashboardNotificationTier.important && !showI) {
        return false;
      }
      if (n.tier == DashboardNotificationTier.suggestion && !showS) {
        return false;
      }
      return true;
    }).toList();
  }
}

// ── Tab 0: Live preview ───────────────────────────────────────────────────────
class _PreviewTab extends ConsumerWidget {
  const _PreviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = Day202DashboardNotificationsScreen._visibleNotifications(ref);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _badge('🟣 POLISH', ZapColors.warning),
              const SizedBox(width: ZapSpacing.sm),
              _badge('DAY 202', ZapColors.info),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          const Text(
            'Mock dashboard — banners appear below the mode badge, above the SOS button.',
            style: TextStyle(color: ZapColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: ZapSpacing.lg),
          Container(
            padding: const EdgeInsets.all(ZapSpacing.lg),
            decoration: BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.circular(ZapSpacing.radius),
              border: Border.all(color: ZapColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ModeBadge(),
                const SizedBox(height: ZapSpacing.md),
                DashboardNotificationStack(
                  notifications: notifications,
                  onDismiss: (id) {
                    ref.read(_d202ActiveProvider.notifier).update(
                          (s) => {...s}..remove(id),
                        );
                  },
                  onAcknowledge: (id) {
                    ref.read(_d202PendingAckProvider.notifier).update(
                          (s) => {...s}..remove(id),
                        );
                    ref.read(_d202ActiveProvider.notifier).update(
                          (s) => {...s}..remove(id),
                        );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Acknowledged: $id'),
                        backgroundColor: ZapColors.safe,
                      ),
                    );
                  },
                  onAction: (id) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Action tapped for $id (mock navigation)'),
                      ),
                    );
                  },
                ),
                if (notifications.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(ZapSpacing.md),
                    decoration: BoxDecoration(
                      color: ZapColors.bgSurface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'No active banners — dashboard is clean.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: ZapColors.textSecondary),
                    ),
                  ),
                const SizedBox(height: ZapSpacing.xl),
                const _SosPlaceholder(),
                const SizedBox(height: ZapSpacing.lg),
                const Center(
                  child: Text(
                    'Protection Score ring · Quick actions',
                    style: TextStyle(
                      color: ZapColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.lg),
          _IntegrationNote(),
          const SizedBox(height: ZapSpacing.md),
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ZapColors.info.withOpacity(0.3)),
            ),
            child: const Text(
              'Next: Day 204 — Persistent mode status card.',
              style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ModeBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ZapSpacing.md,
        vertical: ZapSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: ZapColors.safe.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ZapColors.safe.withOpacity(0.4)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_rounded, color: ZapColors.safe, size: 18),
          SizedBox(width: ZapSpacing.sm),
          Text(
            'MONITORING',
            style: TextStyle(
              color: ZapColors.safe,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SosPlaceholder extends StatelessWidget {
  const _SosPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        label: 'Emergency SOS button placeholder',
        button: true,
        child: Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ZapColors.danger.withOpacity(0.15),
            border: Border.all(color: ZapColors.danger, width: 2),
          ),
          child: const Icon(
            Icons.emergency_rounded,
            color: ZapColors.danger,
            size: 40,
          ),
        ),
      ),
    );
  }
}

class _IntegrationNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ZapColors.border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Integration',
            style: TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: ZapSpacing.xs),
          Text(
            'Import dashboard_notification_banner.dart into the production '
            'dashboard when it replaces the placeholder. Feed active alerts '
            'from Riverpod (battery service, contact verification, drill scheduler).',
            style: TextStyle(
              color: ZapColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab 1: Controls ───────────────────────────────────────────────────────────
class _ControlsTab extends ConsumerWidget {
  const _ControlsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showC = ref.watch(_d202ShowCriticalProvider);
    final showI = ref.watch(_d202ShowImportantProvider);
    final showS = ref.watch(_d202ShowSuggestionProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text(
          'Toggle tiers to preview dashboard behaviour.',
          style: TextStyle(color: ZapColors.textSecondary),
        ),
        const SizedBox(height: ZapSpacing.lg),
        _TierToggle(
          title: 'Critical tier',
          subtitle: 'Must tap "Got it" — no X dismiss',
          color: ZapColors.danger,
          value: showC,
          onChanged: (v) {
            ref.read(_d202ShowCriticalProvider.notifier).state = v;
            if (v) {
              ref.read(_d202ActiveProvider.notifier).update(
                    (s) => {...s, 'critical_battery'},
                  );
              ref.read(_d202PendingAckProvider.notifier).update(
                    (s) => {...s, 'critical_battery'},
                  );
            }
          },
        ),
        _TierToggle(
          title: 'Important tier',
          subtitle: 'Dismissible with X',
          color: ZapColors.warning,
          value: showI,
          onChanged: (v) {
            ref.read(_d202ShowImportantProvider.notifier).state = v;
            if (v) {
              ref.read(_d202ActiveProvider.notifier).update(
                    (s) => {...s, 'important_contact'},
                  );
            }
          },
        ),
        _TierToggle(
          title: 'Suggestion tier',
          subtitle: 'Low priority — dismissible',
          color: ZapColors.info,
          value: showS,
          onChanged: (v) {
            ref.read(_d202ShowSuggestionProvider.notifier).state = v;
            if (v) {
              ref.read(_d202ActiveProvider.notifier).update(
                    (s) => {...s, 'suggestion_drill'},
                  );
            }
          },
        ),
        const SizedBox(height: ZapSpacing.xl),
        Semantics(
          label: 'Reset all notifications to default',
          button: true,
          child: OutlinedButton(
            onPressed: () {
              ref.read(_d202ActiveProvider.notifier).state = {
                'critical_battery',
                'important_contact',
                'suggestion_drill',
              };
              ref.read(_d202PendingAckProvider.notifier).state = {
                'critical_battery',
              };
              ref.read(_d202ShowCriticalProvider.notifier).state = true;
              ref.read(_d202ShowImportantProvider.notifier).state = true;
              ref.read(_d202ShowSuggestionProvider.notifier).state = true;
            },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 75),
            ),
            child: const Text('Reset to defaults'),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Semantics(
          label: 'Dismiss all banners',
          button: true,
          child: FilledButton(
            onPressed: () {
              ref.read(_d202ActiveProvider.notifier).state = {};
              ref.read(_d202PendingAckProvider.notifier).state = {};
            },
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 75),
              backgroundColor: ZapColors.bgElevated,
              foregroundColor: ZapColors.textPrimary,
            ),
            child: const Text('Clear all banners'),
          ),
        ),
      ],
    );
  }
}

class _TierToggle extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _TierToggle({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: color.withOpacity(value ? 0.5 : 0.2)),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeColor: color,
        title: Text(
          title,
          style: const TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: ZapColors.textSecondary, fontSize: 12),
        ),
      ),
    );
  }
}

// ── Tab 2: Spec ───────────────────────────────────────────────────────────────
class _SpecTab extends StatelessWidget {
  const _SpecTab();

  @override
  Widget build(BuildContext context) {
    const rows = [
      ('Critical', 'Red / danger', 'Must acknowledge', 'Battery <10%'),
      ('Important', 'Orange / warning', 'Dismissible (X)', 'Unverified contact'),
      ('Suggestion', 'Blue / info', 'Dismissible (X)', 'Drill due'),
    ];

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text(
          '3-tier notification hierarchy (MASTER_HANDOFF Improvement #1)',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        ...rows.map((r) => Container(
              margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
              padding: const EdgeInsets.all(ZapSpacing.md),
              decoration: BoxDecoration(
                color: ZapColors.bgCard,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ZapColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.$1,
                    style: const TextStyle(
                      color: ZapColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: ZapSpacing.xs),
                  Text(
                    'Color: ${r.$2}\nBehavior: ${r.$3}\nExample: ${r.$4}',
                    style: const TextStyle(
                      color: ZapColors.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            )),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Widget: lib/presentation/widgets/dashboard_notification_banner.dart\n'
          '• DashboardNotificationBanner — single banner\n'
          '• DashboardNotificationStack — sorted list',
          style: TextStyle(
            color: ZapColors.textSecondary,
            fontSize: 12,
            fontFamily: 'monospace',
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _TabBar extends StatelessWidget {
  final int tab;
  final ValueChanged<int> onSelect;

  const _TabBar({required this.tab, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ZapColors.bgCard,
      child: Row(
        children: List.generate(_kTabs.length, (i) {
          final selected = tab == i;
          return Expanded(
            child: Semantics(
              label: '${_kTabs[i]} tab',
              button: true,
              selected: selected,
              child: InkWell(
                onTap: () => onSelect(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: ZapSpacing.md),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: selected ? ZapColors.safe : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    _kTabs[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: selected
                          ? ZapColors.textPrimary
                          : ZapColors.textSecondary,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
