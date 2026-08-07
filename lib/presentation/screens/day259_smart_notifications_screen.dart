/// Day 259 — Smart Contextual Notifications
///
/// Section C (Days 241-260): settings for predictive safety nudges
/// ("Walking late — enable Journey Mode?") with quiet-hours integration
/// from Day 73 Do Not Disturb.
///
/// Tag: 🟢 FRONTEND-ONLY · mock nudge catalog · simulate preview.
///
/// Route: [AppRoutes.smartNotifications] → `/smart-notifications`
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const _kAccent = Color(0xFF6366F1);
const _kTabs = ['Nudges', 'Quiet Hours', 'Info'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');

class _NudgeDef {
  const _NudgeDef({
    required this.id,
    required this.title,
    required this.body,
    required this.context,
    required this.icon,
    required this.color,
    required this.actionLabel,
    required this.route,
    required this.respectsQuietHours,
  });

  final String id;
  final String title;
  final String body;
  final String context;
  final IconData icon;
  final Color color;
  final String actionLabel;
  final String route;
  final bool respectsQuietHours;
}

const _kNudgeCatalog = [
  _NudgeDef(
    id: 'late_walk_journey',
    title: 'Walking late?',
    body: 'It\'s 10:42 PM and you\'re still moving. Enable Journey Mode?',
    context: 'GPS speed + time-of-day · weekday evening',
    icon: Icons.directions_walk_rounded,
    color: Color(0xFF8B5CF6),
    actionLabel: 'Enable Journey',
    route: AppRoutes.journeyModeV2,
    respectsQuietHours: true,
  ),
  _NudgeDef(
    id: 'low_protection_score',
    title: 'Boost your score',
    body: 'Protection score is 58. Add a Tier 1 contact to reach 75+.',
    context: 'Score sync · last updated 2h ago',
    icon: Icons.shield_outlined,
    color: Color(0xFF059669),
    actionLabel: 'View score',
    route: AppRoutes.protectionScore,
    respectsQuietHours: true,
  ),
  _NudgeDef(
    id: 'unfamiliar_area',
    title: 'New area detected',
    body: 'You entered an unfamiliar zone. Turn on elevated monitoring?',
    context: 'Geofence delta · 1.2 km from home cluster',
    icon: Icons.location_on_outlined,
    color: Color(0xFFF97316),
    actionLabel: 'Elevate mode',
    route: AppRoutes.dashboard,
    respectsQuietHours: false,
  ),
  _NudgeDef(
    id: 'drill_reminder',
    title: 'Safety drill due',
    body: 'It\'s been 21 days since your last drill. Run a 30-second practice?',
    context: 'Drill scheduler · family plan admin',
    icon: Icons.fitness_center_rounded,
    color: Color(0xFF0EA5E9),
    actionLabel: 'Start drill',
    route: AppRoutes.dashboard,
    respectsQuietHours: true,
  ),
  _NudgeDef(
    id: 'group_journey_invite',
    title: 'Group journey pending',
    body: 'Priya invited you to "Friday commute". Join live map?',
    context: 'Group journey · Day 250 create flow',
    icon: Icons.group_rounded,
    color: Color(0xFFEC4899),
    actionLabel: 'Open map',
    route: AppRoutes.groupJourneyLiveMap,
    respectsQuietHours: false,
  ),
];

_NudgeDef _nudgeById(String id) =>
    _kNudgeCatalog.firstWhere((n) => n.id == id, orElse: () => _kNudgeCatalog.first);

class _SimulatedNudge {
  const _SimulatedNudge({
    required this.at,
    required this.nudgeId,
    required this.delivered,
    required this.reason,
  });

  final DateTime at;
  final String nudgeId;
  final bool delivered;
  final String reason;
}

String _formatHour(int hour) {
  final period = hour < 12 ? 'AM' : 'PM';
  final h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
  return '$h:00 $period';
}

bool _isInQuietHours(int hour, int start, int end) {
  if (start == end) return false;
  if (start < end) return hour >= start && hour < end;
  return hour >= start || hour < end;
}

// ── Providers ─────────────────────────────────────────────────────────────────
final _d259TabProvider = StateProvider<int>((ref) => 0);
final _d259EnabledNudgesProvider = StateProvider<Set<String>>(
  (ref) => _kNudgeCatalog.map((n) => n.id).toSet(),
);
final _d259MasterProvider = StateProvider<bool>((ref) => true);
final _d259SelectedNudgeProvider =
    StateProvider<String>((ref) => _kNudgeCatalog.first.id);
final _d259PreviewVisibleProvider = StateProvider<bool>((ref) => false);
final _d259SimCountProvider = StateProvider<int>((ref) => 0);
final _d259HistoryProvider =
    StateProvider<List<_SimulatedNudge>>((ref) => const []);
final _d259QuietRespectProvider = StateProvider<bool>((ref) => true);
final _d259QuietStartProvider = StateProvider<int>((ref) => 22);
final _d259QuietEndProvider = StateProvider<int>((ref) => 7);
final _d259MockHourProvider = StateProvider<int>((ref) => 22);

// ── Screen ────────────────────────────────────────────────────────────────────
class Day259SmartNotificationsScreen extends ConsumerWidget {
  const Day259SmartNotificationsScreen({super.key});

  void _simulateNudge(BuildContext context, WidgetRef ref) {
    if (!ref.read(_d259MasterProvider)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enable smart nudges first.')),
      );
      return;
    }

    final id = ref.read(_d259SelectedNudgeProvider);
    final nudge = _nudgeById(id);
    final enabled = ref.read(_d259EnabledNudgesProvider);
    final mockHour = ref.read(_d259MockHourProvider);
    final quietStart = ref.read(_d259QuietStartProvider);
    final quietEnd = ref.read(_d259QuietEndProvider);
    final respectQuiet = ref.read(_d259QuietRespectProvider);
    final inQuiet =
        respectQuiet && _isInQuietHours(mockHour, quietStart, quietEnd);

    String reason;
    var delivered = true;

    if (!enabled.contains(id)) {
      delivered = false;
      reason = 'Nudge type disabled in catalog';
    } else if (inQuiet && nudge.respectsQuietHours) {
      delivered = false;
      reason = 'Suppressed · quiet hours '
          '${_formatHour(quietStart)}–${_formatHour(quietEnd)}';
    } else if (inQuiet && !nudge.respectsQuietHours) {
      delivered = true;
      reason = 'Delivered · safety-critical · bypasses quiet hours';
    } else {
      reason = 'Delivered · outside quiet hours';
    }

    ref.read(_d259HistoryProvider.notifier).state = [
      _SimulatedNudge(
        at: DateTime.now(),
        nudgeId: id,
        delivered: delivered,
        reason: reason,
      ),
      ...ref.read(_d259HistoryProvider),
    ].take(8).toList();

    ref.read(_d259SimCountProvider.notifier).state =
        ref.read(_d259SimCountProvider) + 1;
    ref.read(_d259PreviewVisibleProvider.notifier).state = delivered;

    if (delivered) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nudge delivered: ${nudge.title}'),
          action: SnackBarAction(
            label: nudge.actionLabel,
            onPressed: () => context.push(nudge.route),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nudge suppressed · $reason')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d259TabProvider);
    final master = ref.watch(_d259MasterProvider);
    final simCount = ref.watch(_d259SimCountProvider);
    final enabledCount = ref.watch(_d259EnabledNudgesProvider).length;

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 259 · Smart Nudges'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (master ? _kAccent : ZapColors.textMuted)
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: (master ? _kAccent : ZapColors.textMuted)
                        .withOpacity(0.45),
                  ),
                ),
                child: Text(
                  master ? '$enabledCount/${_kNudgeCatalog.length}' : 'OFF',
                  style: TextStyle(
                    color: master ? _kAccent : ZapColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
          if (simCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: ZapSpacing.sm),
              child: Center(
                child: Text(
                  '$simCount sim${simCount == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: ZapColors.textMuted,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _TabBar(
            tab: tab,
            onSelect: (i) => ref.read(_d259TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (tab) {
              0 => _NudgesTab(onSimulate: () => _simulateNudge(context, ref)),
              1 => const _QuietHoursTab(),
              _ => const _InfoTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Nudges ─────────────────────────────────────────────────────────────
class _NudgesTab extends ConsumerWidget {
  const _NudgesTab({required this.onSimulate});

  final VoidCallback onSimulate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final master = ref.watch(_d259MasterProvider);
    final enabled = ref.watch(_d259EnabledNudgesProvider);
    final selected = ref.watch(_d259SelectedNudgeProvider);
    final preview = ref.watch(_d259PreviewVisibleProvider);
    final history = ref.watch(_d259HistoryProvider);
    final nudge = _nudgeById(selected);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _kAccent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _kAccent.withOpacity(0.35)),
          ),
          child: const Text(
            '🟢 FRONTEND-ONLY · Section C Day 19/20 · predictive nudges · '
            'quiet hours aware',
            style: TextStyle(color: _kAccent, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Smart contextual nudges',
            style: TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: const Text(
            'On-device signals trigger helpful prompts — never spam SOS alerts.',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 12),
          ),
          value: master,
          activeColor: _kAccent,
          onChanged: (v) => ref.read(_d259MasterProvider.notifier).state = v,
        ),
        const SizedBox(height: ZapSpacing.md),
        const Text(
          'Nudge catalog',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        ..._kNudgeCatalog.map(
          (n) => _NudgeTile(
            nudge: n,
            enabled: master && enabled.contains(n.id),
            selected: selected == n.id,
            onSelect: () =>
                ref.read(_d259SelectedNudgeProvider.notifier).state = n.id,
            onToggle: master
                ? (v) {
                    final next = {...enabled};
                    if (v) {
                      next.add(n.id);
                    } else {
                      next.remove(n.id);
                    }
                    ref.read(_d259EnabledNudgesProvider.notifier).state = next;
                  }
                : null,
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Simulate delivery',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        DropdownButtonFormField<String>(
          value: selected,
          decoration: const InputDecoration(
            labelText: 'Nudge to simulate',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final n in _kNudgeCatalog)
              DropdownMenuItem(value: n.id, child: Text(n.title)),
          ],
          onChanged: master
              ? (v) {
                  if (v != null) {
                    ref.read(_d259SelectedNudgeProvider.notifier).state = v;
                  }
                }
              : null,
        ),
        const SizedBox(height: ZapSpacing.sm),
        FilledButton.icon(
          onPressed: master ? onSimulate : null,
          icon: const Icon(Icons.notifications_active_rounded),
          label: const Text('Simulate nudge'),
          style: FilledButton.styleFrom(
            backgroundColor: _kAccent,
            minimumSize: const Size.fromHeight(48),
          ),
        ),
        if (preview) ...[
          const SizedBox(height: ZapSpacing.lg),
          _NotificationPreviewCard(nudge: nudge),
        ],
        if (history.isNotEmpty) ...[
          const SizedBox(height: ZapSpacing.lg),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Simulation log',
                  style: TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  ref.read(_d259HistoryProvider.notifier).state = [];
                  ref.read(_d259PreviewVisibleProvider.notifier).state = false;
                },
                child: const Text('Clear'),
              ),
            ],
          ),
          ...history.map((h) => _HistoryRow(entry: h)),
        ],
      ],
    );
  }
}

class _NudgeTile extends StatelessWidget {
  const _NudgeTile({
    required this.nudge,
    required this.enabled,
    required this.selected,
    required this.onSelect,
    required this.onToggle,
  });

  final _NudgeDef nudge;
  final bool enabled;
  final bool selected;
  final VoidCallback onSelect;
  final ValueChanged<bool>? onToggle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(ZapSpacing.sm),
        decoration: BoxDecoration(
          color: selected
              ? nudge.color.withOpacity(0.08)
              : ZapColors.bgCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? nudge.color.withOpacity(0.45)
                : ZapColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(nudge.icon, color: nudge.color, size: 20),
            const SizedBox(width: ZapSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nudge.title,
                    style: const TextStyle(
                      color: ZapColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    nudge.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ZapColors.textSecondary,
                      fontSize: 10,
                      height: 1.35,
                    ),
                  ),
                  Text(
                    nudge.respectsQuietHours
                        ? 'Respects quiet hours'
                        : 'Bypasses quiet hours (safety)',
                    style: TextStyle(
                      color: nudge.respectsQuietHours
                          ? ZapColors.textMuted
                          : ZapColors.warning,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: enabled,
              activeColor: nudge.color,
              onChanged: onToggle == null ? null : (v) => onToggle!(v),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationPreviewCard extends StatelessWidget {
  const _NotificationPreviewCard({required this.nudge});

  final _NudgeDef nudge;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: nudge.color.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: nudge.color.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_rounded, color: nudge.color, size: 18),
              const SizedBox(width: ZapSpacing.sm),
              const Text(
                'ZapSafe · now',
                style: TextStyle(
                  color: ZapColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.sm),
          Text(
            nudge.title,
            style: const TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            nudge.body,
            style: const TextStyle(
              color: ZapColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => context.push(nudge.route),
                child: Text(nudge.actionLabel),
              ),
              TextButton(
                onPressed: () {},
                child: const Text('Dismiss'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry});

  final _SimulatedNudge entry;

  @override
  Widget build(BuildContext context) {
    final nudge = _nudgeById(entry.nudgeId);
    final time =
        '${entry.at.hour.toString().padLeft(2, '0')}:'
        '${entry.at.minute.toString().padLeft(2, '0')}:'
        '${entry.at.second.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(ZapSpacing.sm),
      decoration: BoxDecoration(
        color: entry.delivered
            ? _kAccent.withOpacity(0.06)
            : ZapColors.bgCard,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: entry.delivered
              ? _kAccent.withOpacity(0.3)
              : ZapColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            entry.delivered
                ? Icons.check_circle_outline_rounded
                : Icons.block_rounded,
            size: 16,
            color: entry.delivered ? ZapColors.safe : ZapColors.textMuted,
          ),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$time · ${nudge.title}',
                  style: const TextStyle(
                    color: ZapColors.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  entry.reason,
                  style: const TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab 1: Quiet Hours ────────────────────────────────────────────────────────
class _QuietHoursTab extends ConsumerWidget {
  const _QuietHoursTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final respectQuiet = ref.watch(_d259QuietRespectProvider);
    final start = ref.watch(_d259QuietStartProvider);
    final end = ref.watch(_d259QuietEndProvider);
    final mockHour = ref.watch(_d259MockHourProvider);
    final inQuiet = _isInQuietHours(mockHour, start, end);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: inQuiet
                ? ZapColors.warning.withOpacity(0.08)
                : ZapColors.safe.withOpacity(0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: inQuiet
                  ? ZapColors.warning.withOpacity(0.35)
                  : ZapColors.safe.withOpacity(0.35),
            ),
          ),
          child: Row(
            children: [
              Icon(
                inQuiet ? Icons.nightlight_round : Icons.wb_sunny_outlined,
                color: inQuiet ? ZapColors.warning : ZapColors.safe,
              ),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: Text(
                  inQuiet
                      ? 'Mock time ${_formatHour(mockHour)} is inside quiet hours '
                      '(${_formatHour(start)} → ${_formatHour(end)}). '
                      'Non-critical nudges are suppressed.'
                      : 'Mock time ${_formatHour(mockHour)} is outside quiet hours.',
                  style: const TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Respect quiet hours',
            style: TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: const Text(
            'When on, nudges marked "respects quiet hours" are held until '
            'morning. SOS and safety-critical alerts always bypass DND.',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 12),
          ),
          value: respectQuiet,
          activeColor: _kAccent,
          onChanged: (v) =>
              ref.read(_d259QuietRespectProvider.notifier).state = v,
        ),
        const SizedBox(height: ZapSpacing.md),
        Text(
          'Quiet window · ${_formatHour(start)} → ${_formatHour(end)}',
          style: const TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        Slider(
          value: start.toDouble(),
          min: 0,
          max: 23,
          divisions: 23,
          label: _formatHour(start),
          activeColor: _kAccent,
          onChanged: (v) =>
              ref.read(_d259QuietStartProvider.notifier).state = v.round(),
        ),
        Slider(
          value: end.toDouble(),
          min: 0,
          max: 23,
          divisions: 23,
          label: _formatHour(end),
          activeColor: _kAccent,
          onChanged: (v) =>
              ref.read(_d259QuietEndProvider.notifier).state = v.round(),
        ),
        const SizedBox(height: ZapSpacing.md),
        Text(
          'Mock current hour · ${_formatHour(mockHour)}',
          style: const TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        Slider(
          value: mockHour.toDouble(),
          min: 0,
          max: 23,
          divisions: 23,
          label: _formatHour(mockHour),
          activeColor: ZapColors.warning,
          onChanged: (v) =>
              ref.read(_d259MockHourProvider.notifier).state = v.round(),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const _PolicyRow(
          icon: Icons.emergency_rounded,
          title: 'SOS always bypasses',
          subtitle:
              'Alert pending, auto-SOS, and group panic never respect quiet '
              'hours — same policy as Day 73 Do Not Disturb.',
        ),
        const SizedBox(height: ZapSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              label: const Text('Day 73 Do Not Disturb'),
              onPressed: () => context.push(AppRoutes.doNotDisturb),
            ),
            ActionChip(
              label: const Text('Day 67 Notification Prefs'),
              onPressed: () => context.push(AppRoutes.notificationPrefs),
            ),
            ActionChip(
              label: const Text('Day 17 Push Routing'),
              onPressed: () => context.push(AppRoutes.pushRouting),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Tab 2: Info ───────────────────────────────────────────────────────────────
class _InfoTab extends ConsumerWidget {
  const _InfoTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final master = ref.watch(_d259MasterProvider);
    final enabled = ref.watch(_d259EnabledNudgesProvider);
    final respectQuiet = ref.watch(_d259QuietRespectProvider);
    final start = ref.watch(_d259QuietStartProvider);
    final end = ref.watch(_d259QuietEndProvider);

    final payload = {
      'endpoint': 'PATCH /api/v1/settings/smart-notifications/',
      'enabled': master,
      'respect_quiet_hours': respectQuiet,
      'quiet_hours': {
        'start_hour': start,
        'end_hour': end,
        'source': 'synced_from_day_73_preferences',
      },
      'enabled_nudge_types': enabled.toList()..sort(),
      'catalog': [
        for (final n in _kNudgeCatalog)
          {
            'id': n.id,
            'title': n.title,
            'respects_quiet_hours': n.respectsQuietHours,
            'deep_link': n.route,
          },
      ],
      'delivery': 'on_device_rules_engine · no cloud ML in v1 mock',
    };

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _PolicyRow(
          icon: Icons.psychology_outlined,
          title: 'Predictive, not noisy',
          subtitle:
              'Signals like time-of-day, GPS speed, protection score, and '
              'geofence deltas trigger one actionable nudge — not alert spam.',
        ),
        const _PolicyRow(
          icon: Icons.nightlight_round,
          title: 'Quiet hours integration',
          subtitle:
              'Reads the same quiet window as Day 73. Journey and drill '
              'reminders wait until morning; safety-critical nudges can bypass.',
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'API contract (mock)',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.border),
          ),
          child: SelectableText(
            _kJsonEncoder.convert(payload),
            style: const TextStyle(
              color: ZapColors.textSecondary,
              fontSize: 10,
              fontFamily: 'monospace',
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(
              ClipboardData(text: _kJsonEncoder.convert(payload)),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Smart notifications JSON copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy settings JSON'),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.info.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.info.withOpacity(0.3)),
          ),
          child: const Text(
            'Next: Day 365 — Global Launch Milestone '
            '(Phase 2 finale · worldwide rollout).',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              label: const Text('Day 258 Fall Detection'),
              onPressed: () => context.push(AppRoutes.fallDetectionTuning),
            ),
            ActionChip(
              label: const Text('Day 241 Journey Mode'),
              onPressed: () => context.push(AppRoutes.journeyModeV2),
            ),
            ActionChip(
              label: const Text('Day 73 Do Not Disturb'),
              onPressed: () => context.push(AppRoutes.doNotDisturb),
            ),
          ],
        ),
      ],
    );
  }
}

class _PolicyRow extends StatelessWidget {
  const _PolicyRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ZapSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: _kAccent),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.tab, required this.onSelect});

  final int tab;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ZapColors.bgCard,
      child: Row(
        children: List.generate(_kTabs.length, (i) {
          final selected = tab == i;
          return Expanded(
            child: InkWell(
              onTap: () => onSelect(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected ? _kAccent : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  _kTabs[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? _kAccent : ZapColors.textMuted,
                    fontWeight:
                        selected ? FontWeight.w800 : FontWeight.w500,
                    fontSize: 12,
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
