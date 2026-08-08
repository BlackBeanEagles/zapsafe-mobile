/// Day 177 — Data Retention: Auto-Deletion Scheduler & Change History
///
/// Second day of the Days 176-178 Data Retention Settings block.
/// Day 176: Per-category pickers + evidence vault + GPS purge       ✅
/// Day 177: Upcoming-deletions preview (next 7 days), auto-deletion
///           scheduler detail, retention change history log.
/// Day 178: Edge cases + DPDP §8 compliance + block sign-off.
///
/// 🟢 FRONTEND-ONLY for upcoming preview + change history display.
/// 🟡 MOCK-NOW for server-side scheduler (backend at Day 78).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _d177TabProvider         = StateProvider<int>((ref) => 0);
final _simulateRunProvider     = StateProvider<_RunState>((ref) => _RunState.idle);
final _runProgressProvider     = StateProvider<double>((ref) => 0.0);
final _deletedCountProvider    = StateProvider<int>((ref) => 0);
final _expandedUpcomingProvider= StateProvider<int?>((ref) => null);
final _expandedHistoryProvider = StateProvider<int?>((ref) => null);
final _expandedCatSchedProvider= StateProvider<int?>((ref) => null);

enum _RunState { idle, running, done }

// ── Data: upcoming deletions (next 7 days) ────────────────────────────────────
class _UpcomingDeletion {
  final int       daysFromNow;    // 0 = today
  final String    date;
  final String    category;
  final IconData  icon;
  final Color     color;
  final String    description;
  final String    itemCount;
  final String    estimatedSize;
  final bool      canPostpone;
  final String    postponeAction;
  const _UpcomingDeletion({
    required this.daysFromNow, required this.date,
    required this.category, required this.icon, required this.color,
    required this.description, required this.itemCount,
    required this.estimatedSize, required this.canPostpone,
    required this.postponeAction,
  });
}

const _kUpcoming = [
  _UpcomingDeletion(
    daysFromNow: 2, date: 'June 1, 2026',
    category: 'Location & GPS', icon: Icons.location_on_rounded,
    color: Color(0xFF10B981),
    description: 'GPS batch from May 18 — uploaded 14 days ago, '
        'hits the 14-day location retention limit.',
    itemCount: '63 location points', estimatedSize: '4.2 KB',
    canPostpone: true,
    postponeAction: 'Change Location retention to 30 days in Settings → '
        'Data Retention to postpone this deletion.',
  ),
  _UpcomingDeletion(
    daysFromNow: 3, date: 'June 2, 2026',
    category: 'Analytics & Crash Logs', icon: Icons.bar_chart_rounded,
    color: Color(0xFF8B5CF6),
    description: 'Usage analytics records and crash logs older than 30 days '
        '(collected May 3, 2026).',
    itemCount: '14 analytics events + 1 crash report', estimatedSize: '28 KB',
    canPostpone: true,
    postponeAction: 'Change Analytics retention to 90 days in Settings → '
        'Data Retention. Or toggle off analytics in Settings → Analytics.',
  ),
  _UpcomingDeletion(
    daysFromNow: 4, date: 'June 3, 2026',
    category: 'Location & GPS', icon: Icons.location_on_rounded,
    color: Color(0xFF10B981),
    description: 'GPS batch from May 20 — 14-day retention expires.',
    itemCount: '47 location points', estimatedSize: '3.1 KB',
    canPostpone: true,
    postponeAction: 'Change Location retention to 30 days.',
  ),
  _UpcomingDeletion(
    daysFromNow: 5, date: 'June 4, 2026',
    category: 'Notification History', icon: Icons.notifications_rounded,
    color: Color(0xFF6B7280),
    description: 'Push and SMS notification records older than 30 days '
        '(from May 5, 2026). Low sensitivity — safe to delete.',
    itemCount: '22 notification records', estimatedSize: '8 KB',
    canPostpone: false,
    postponeAction: 'Notification history cannot be extended. '
        'If needed, export to CSV first (Day 174 Export).',
  ),
  _UpcomingDeletion(
    daysFromNow: 7, date: 'June 6, 2026',
    category: 'Location & GPS', icon: Icons.location_on_rounded,
    color: Color(0xFF10B981),
    description: 'GPS batch from May 22 — 14-day retention expires.',
    itemCount: '31 location points', estimatedSize: '2.1 KB',
    canPostpone: true,
    postponeAction: 'Change Location retention to 30 days.',
  ),
];

// ── Data: scheduler categories ────────────────────────────────────────────────
class _SchedCat {
  final String   name;
  final IconData icon;
  final Color    color;
  final String   runsAt;
  final String   trigger;
  final String   scope;
  final bool     serverSide;
  const _SchedCat({
    required this.name, required this.icon, required this.color,
    required this.runsAt, required this.trigger, required this.scope,
    required this.serverSide,
  });
}

const _kSchedCats = [
  _SchedCat(
    name: 'Location & GPS',
    icon: Icons.location_on_rounded, color: Color(0xFF10B981),
    runsAt: 'Daily 03:00 AM + on app foreground',
    trigger: 'GPS batch age > retention setting',
    scope: 'All GPS batches. Exception: batches linked to active SOS events.',
    serverSide: true,
  ),
  _SchedCat(
    name: 'Analytics & Crash Logs',
    icon: Icons.bar_chart_rounded, color: Color(0xFF8B5CF6),
    runsAt: 'Daily 03:00 AM',
    trigger: 'analytics_events.created_at < NOW() - retention_days',
    scope: 'All analytics events and crash log entries. '
        'Sentry crash reports are deleted via Sentry\'s own data retention API.',
    serverSide: false,
  ),
  _SchedCat(
    name: 'Notification History',
    icon: Icons.notifications_rounded, color: Color(0xFF6B7280),
    runsAt: 'Daily 03:00 AM',
    trigger: 'notifications.created_at < NOW() - retention_days',
    scope: 'All notification history records.',
    serverSide: false,
  ),
  _SchedCat(
    name: 'Data Access Audit Log',
    icon: Icons.history_rounded, color: Color(0xFF3B82F6),
    runsAt: 'Daily 03:00 AM',
    trigger: 'audit_events.timestamp < NOW() - retention_days',
    scope: 'All audit events EXCEPT suspicious events (flagged = retain 1 year).',
    serverSide: true,
  ),
  _SchedCat(
    name: 'Evidence Vault',
    icon: Icons.lock_rounded, color: Color(0xFFF59E0B),
    runsAt: 'Daily 03:00 AM (server-side only)',
    trigger: 'Per-SOS expiry date reached (set by vault extension history)',
    scope: 'All evidence files for expired SOS events. '
        'Exception: legal-hold events.',
    serverSide: true,
  ),
  _SchedCat(
    name: 'SOS Events Metadata',
    icon: Icons.warning_rounded, color: Color(0xFFEF4444),
    runsAt: 'Daily 03:00 AM (server-side only)',
    trigger: 'sos_events.created_at < NOW() - retention_days',
    scope: 'SOS metadata. Exception: events with open incidents or legal holds.',
    serverSide: true,
  ),
];

// ── Data: change history ──────────────────────────────────────────────────────
class _HistoryEntry {
  final DateTime ts;
  final String   category;
  final Color    color;
  final IconData icon;
  final String   fromPeriod;
  final String   toPeriod;
  final String   changedBy;  // 'User' or 'System default'
  final String   reason;
  const _HistoryEntry({
    required this.ts, required this.category, required this.color,
    required this.icon, required this.fromPeriod, required this.toPeriod,
    required this.changedBy, required this.reason,
  });
}

final _kHistory = [
  _HistoryEntry(
    ts: DateTime(2026, 5, 30, 14, 15),
    category: 'Analytics & Crash Logs', color: const Color(0xFF8B5CF6),
    icon: Icons.bar_chart_rounded,
    fromPeriod: '90 days', toPeriod: '30 days',
    changedBy: 'User', reason: 'Reduced after toggling analytics consent off.',
  ),
  _HistoryEntry(
    ts: DateTime(2026, 5, 22, 10, 00),
    category: 'Evidence Vault', color: const Color(0xFFF59E0B),
    icon: Icons.lock_rounded,
    fromPeriod: '1 year', toPeriod: '90 days',
    changedBy: 'User', reason: 'Reduced for storage savings.',
  ),
  _HistoryEntry(
    ts: DateTime(2026, 4, 15, 9, 00),
    category: 'Location & GPS', color: const Color(0xFF10B981),
    icon: Icons.location_on_rounded,
    fromPeriod: '30 days', toPeriod: '14 days',
    changedBy: 'User', reason: 'Tightened for privacy after reading DPDP §8.',
  ),
  _HistoryEntry(
    ts: DateTime(2026, 3, 10, 12, 30),
    category: 'Notification History', color: const Color(0xFF6B7280),
    icon: Icons.notifications_rounded,
    fromPeriod: '7 days', toPeriod: '30 days',
    changedBy: 'User', reason: 'Extended for better review capability.',
  ),
  _HistoryEntry(
    ts: DateTime(2026, 1, 15, 9, 0),
    category: 'All categories', color: const Color(0xFF3B82F6),
    icon: Icons.settings_rounded,
    fromPeriod: '—', toPeriod: 'ZapSafe defaults',
    changedBy: 'System default', reason: 'Initial account setup — ZapSafe recommended defaults applied.',
  ),
];

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day177DataRetentionSchedulerScreen extends ConsumerWidget {
  const Day177DataRetentionSchedulerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d177TabProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Retention: Scheduler & History'),
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: ZapSpacing.md, top: 8, bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.4)),
            ),
            child: const Text('DAY 177',
                style: TextStyle(color: Color(0xFF3B82F6), fontSize: 10,
                    fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Hero(),
            const SizedBox(height: ZapSpacing.xl),
            const _SectionLabel('SELECT VIEW'),
            const SizedBox(height: ZapSpacing.md),
            _TabBar(active: tab,
                onSelect: (t) => ref.read(_d177TabProvider.notifier).state = t),
            const SizedBox(height: ZapSpacing.xl),
            if (tab == 0) const _UpcomingTab(),
            if (tab == 1) const _SchedulerTab(),
            if (tab == 2) const _HistoryTab(),
            const SizedBox(height: ZapSpacing.huge),
          ],
        ),
      ),
    );
  }
}

// ── Hero ───────────────────────────────────────────────────────────────────────
class _Hero extends StatelessWidget {
  const _Hero();
  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF080E14), Color(0xFF050A10), Color(0xFF0A0A0A)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.5), width: 2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: ZapSpacing.sm, runSpacing: ZapSpacing.sm, children: [
          _badge('⚡  DAY 177',              const Color(0xFF3B82F6)),
          _badge('🟢/🟡 MIXED',              const Color(0xFF10B981)),
          _badge('Retention  ·  Day 2/3',    const Color(0xFF8B5CF6)),
        ]),
        const SizedBox(height: ZapSpacing.md),
        const Text('Auto-Deletion Scheduler\n& Change History',
            style: TextStyle(color: Colors.white, fontSize: 26,
                fontWeight: FontWeight.w900, height: 1.2)),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          '"What gets deleted in the next 7 days" — act before it\'s gone. '
          'How the daily purge scheduler works. '
          'Full log of every retention setting change.',
          style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6)),
        const SizedBox(height: ZapSpacing.md),
        const Row(children: [
          _HStat('5',  '5 upcoming deletions',  Color(0xFFEF4444)),
          _HStat('6',  '6 scheduled categories',Color(0xFF3B82F6)),
          _HStat('5',  'History entries',       Color(0xFF8B5CF6)),
          _HStat('03h','Daily run time',        Color(0xFF10B981)),
        ]),
      ]));

  Widget _badge(String l, Color c) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.withOpacity(0.4))),
      child: Text(l, style: TextStyle(color: c, fontSize: 11,
          fontWeight: FontWeight.w700, letterSpacing: 0.5)));
}

class _HStat extends StatelessWidget {
  final String value, label; final Color color;
  const _HStat(this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(value, style: TextStyle(color: color, fontSize: 13,
        fontWeight: FontWeight.w800), textAlign: TextAlign.center),
    Text(label, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 9),
        textAlign: TextAlign.center),
  ]));
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);
  @override
  Widget build(BuildContext context) => Text(label,
      style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10,
          fontWeight: FontWeight.w700, letterSpacing: 1.5));
}

class _TabBar extends StatelessWidget {
  final int active; final ValueChanged<int> onSelect;
  const _TabBar({required this.active, required this.onSelect});
  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.calendar_today_rounded,  Color(0xFFEF4444), 'Next 7 Days'),
      (Icons.schedule_rounded,        Color(0xFF3B82F6), 'Scheduler'),
      (Icons.manage_history_rounded,  Color(0xFF8B5CF6), 'History'),
    ];
    return Row(children: List.generate(3, (i) {
      final (icon, color, label) = items[i];
      final isActive = i == active;
      return Expanded(child: GestureDetector(
        onTap: () => onSelect(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: EdgeInsets.only(right: i < 2 ? ZapSpacing.sm : 0),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
              color: isActive ? color.withOpacity(0.12) : const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(
                  color: isActive ? color.withOpacity(0.5) : const Color(0xFF2A2A2A),
                  width: isActive ? 2 : 1)),
          child: Column(children: [
            Icon(icon, color: isActive ? color : const Color(0xFF6B7280), size: 18),
            const SizedBox(height: ZapSpacing.xs),
            Text(label, style: TextStyle(
                color: isActive ? color : const Color(0xFF6B7280), fontSize: 9,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400)),
          ]),
        ),
      ));
    }));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 1 — Upcoming Deletions (Next 7 Days)
// ══════════════════════════════════════════════════════════════════════════════
class _UpcomingTab extends ConsumerWidget {
  const _UpcomingTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(_expandedUpcomingProvider);

    // Total size being deleted

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.calendar_today_rounded, color: const Color(0xFFEF4444),
          text: '"What will be deleted in the next 7 days." '
              'Review each item and either postpone it by changing '
              'the retention period, or download/export before it\'s gone.'),
      const SizedBox(height: ZapSpacing.lg),

      // Week overview strip
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A))),
        child: Column(children: [
          Row(children: [
            const Icon(Icons.delete_sweep_rounded, color: Color(0xFFEF4444), size: 18),
            const SizedBox(width: ZapSpacing.sm),
            Expanded(child: Text(
                '${_kUpcoming.length} deletions scheduled over the next 7 days',
                style: const TextStyle(color: Colors.white, fontSize: 12,
                    fontWeight: FontWeight.w600))),
          ]),
          const SizedBox(height: ZapSpacing.md),
          // Mini calendar strip
          Row(children: List.generate(8, (i) {
            final now   = DateTime.now();
            final day   = now.add(Duration(days: i));
            final hasEvent = _kUpcoming.any((d) => d.daysFromNow == i);
            final dayLabel = i == 0 ? 'Today' : _dayName(day.weekday);
            return Expanded(child: Column(children: [
              Text(dayLabel, style: const TextStyle(
                  color: Color(0xFF4B5563), fontSize: 8)),
              const SizedBox(height: 3),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 28, height: 28,
                decoration: BoxDecoration(
                    color: hasEvent
                        ? const Color(0xFFEF4444).withOpacity(0.15)
                        : const Color(0xFF1A1A1A),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: hasEvent
                            ? const Color(0xFFEF4444).withOpacity(0.6)
                            : const Color(0xFF2A2A2A),
                        width: hasEvent ? 2 : 1)),
                child: Center(child: Text('${day.day}', style: TextStyle(
                    color: hasEvent ? const Color(0xFFEF4444) : const Color(0xFF6B7280),
                    fontSize: 10, fontWeight: hasEvent ? FontWeight.w800 : FontWeight.w400))),
              ),
            ]));
          })),
          const SizedBox(height: 6),
          const Row(children: [
            Icon(Icons.circle, color: Color(0xFFEF4444), size: 8),
            SizedBox(width: ZapSpacing.xs),
            Text('= deletion day', style: TextStyle(
                color: Color(0xFF6B7280), fontSize: 9)),
          ]),
        ]),
      ),
      const SizedBox(height: ZapSpacing.xl),

      const _SectionLabel('UPCOMING DELETIONS  ·  TAP TO SEE DETAILS + ACTIONS'),
      const SizedBox(height: ZapSpacing.md),

      ..._kUpcoming.asMap().entries.map((e) {
        final i    = e.key;
        final del  = e.value;
        final isExp= expanded == i;
        final urgency = del.daysFromNow <= 2
            ? const Color(0xFFEF4444)
            : del.daysFromNow <= 4
                ? const Color(0xFFF59E0B)
                : del.color;

        return GestureDetector(
          onTap: () => ref.read(_expandedUpcomingProvider.notifier).state =
              isExp ? null : i,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            decoration: BoxDecoration(
                color: isExp ? urgency.withOpacity(0.07) : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                    color: isExp ? urgency.withOpacity(0.4) : const Color(0xFF2A2A2A),
                    width: isExp ? 2 : 1)),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(ZapSpacing.md),
                child: Row(children: [
                  // Day badge
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                        color: urgency.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10)),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(del.daysFromNow == 0 ? 'Today'
                          : 'Day\n+${del.daysFromNow}',
                          style: TextStyle(color: urgency, fontSize: 9,
                              fontWeight: FontWeight.w800, height: 1.2),
                          textAlign: TextAlign.center),
                    ])),
                  const SizedBox(width: ZapSpacing.md),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(del.category, style: const TextStyle(
                        color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                    Text(del.date, style: TextStyle(
                        color: urgency, fontSize: 10, fontWeight: FontWeight.w600)),
                    Text(del.itemCount, style: const TextStyle(
                        color: Color(0xFF6B7280), fontSize: 10)),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Icon(del.icon, color: del.color, size: 16),
                    const SizedBox(height: ZapSpacing.xs),
                    if (del.canPostpone)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6)),
                        child: const Text('Can postpone',
                            style: TextStyle(color: Color(0xFF10B981),
                                fontSize: 8, fontWeight: FontWeight.w700)))
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: const Color(0xFF4B5563).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6)),
                        child: const Text('Fixed',
                            style: TextStyle(color: Color(0xFF4B5563),
                                fontSize: 8))),
                  ]),
                  const SizedBox(width: ZapSpacing.sm),
                  Icon(isExp
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                      color: const Color(0xFF4B5563), size: 16),
                ]),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                child: isExp
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(
                            ZapSpacing.md, 0, ZapSpacing.md, ZapSpacing.md),
                        child: _DeletionDetail(del: del, urgency: urgency))
                    : const SizedBox.shrink(),
              ),
            ]),
          ),
        );
      }),

      const SizedBox(height: ZapSpacing.xl),

      // Bulk action
      _infoBox(icon: Icons.info_outline_rounded, color: const Color(0xFF3B82F6),
          text: 'To postpone location deletions: go to Day 176 → Retention → '
              'Location & GPS → change to 30 days. '
              'All upcoming location purges will shift by 16 days.'),
    ]);
  }

  static String _dayName(int weekday) => const ['Mon','Tue','Wed','Thu',
      'Fri','Sat','Sun'][weekday - 1];
}

class _DeletionDetail extends StatelessWidget {
  final _UpcomingDeletion del; final Color urgency;
  const _DeletionDetail({required this.del, required this.urgency});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Description
      Container(
        padding: const EdgeInsets.all(ZapSpacing.sm),
        decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(del.description, style: const TextStyle(
              color: Color(0xFFD1D5DB), fontSize: 11, height: 1.5)),
          const SizedBox(height: 6),
          Row(children: [
            _kv2('Items', del.itemCount),
            const SizedBox(width: ZapSpacing.lg),
            _kv2('Size',  del.estimatedSize),
          ]),
        ])),
      const SizedBox(height: ZapSpacing.sm),

      // Postpone / action
      Container(
        padding: const EdgeInsets.all(ZapSpacing.sm),
        decoration: BoxDecoration(
            color: del.canPostpone
                ? const Color(0xFF10B981).withOpacity(0.06)
                : const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(
                color: del.canPostpone
                    ? const Color(0xFF10B981).withOpacity(0.25)
                    : const Color(0xFF2A2A2A))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(del.canPostpone ? Icons.more_time_rounded : Icons.lock_outline_rounded,
              color: del.canPostpone
                  ? const Color(0xFF10B981) : const Color(0xFF4B5563),
              size: 13),
          const SizedBox(width: 6),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(del.canPostpone ? 'How to postpone' : 'Cannot postpone',
                style: TextStyle(
                    color: del.canPostpone
                        ? const Color(0xFF10B981) : const Color(0xFF4B5563),
                    fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1)),
            const SizedBox(height: 3),
            Text(del.postponeAction, style: const TextStyle(
                color: Color(0xFF9CA3AF), fontSize: 10, height: 1.4)),
          ])),
        ])),
      const SizedBox(height: ZapSpacing.md),

      // Actions row
      Row(children: [
        Expanded(child: _actionBtn(
          'Export before delete',
          Icons.download_rounded, const Color(0xFF3B82F6),
          () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Mock: navigate to Day 174 audit export'),
              backgroundColor: Color(0xFF3B82F6))))),
        if (del.canPostpone) ...[
          const SizedBox(width: ZapSpacing.sm),
          Expanded(child: _actionBtn(
            'Change retention',
            Icons.tune_rounded, const Color(0xFF10B981),
            () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Mock: navigate to Day 176 retention settings'),
                backgroundColor: Color(0xFF10B981))))),
        ],
      ]),
    ]);
  }

  Widget _kv2(String k, String v) => Row(children: [
    Text('$k: ', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10)),
    Text(v, style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 10,
        fontWeight: FontWeight.w600)),
  ]);

  Widget _actionBtn(String l, IconData icon, Color c, VoidCallback onTap) =>
      GestureDetector(onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
                color: c.withOpacity(0.1),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(color: c.withOpacity(0.35))),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, color: c, size: 12),
              const SizedBox(width: ZapSpacing.xs),
              Text(l, style: TextStyle(color: c, fontSize: 9,
                  fontWeight: FontWeight.w700)),
            ])));
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — Scheduler Detail
// ══════════════════════════════════════════════════════════════════════════════
class _SchedulerTab extends ConsumerWidget {
  const _SchedulerTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runState   = ref.watch(_simulateRunProvider);
    final progress   = ref.watch(_runProgressProvider);
    final deleted    = ref.watch(_deletedCountProvider);
    final expandedIdx= ref.watch(_expandedCatSchedProvider);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.schedule_rounded, color: const Color(0xFF3B82F6),
          text: 'The auto-deletion scheduler runs daily at 03:00 AM device local time '
              'and checks every data category against its retention setting. '
              'It also runs on app foreground for local categories.'),
      const SizedBox(height: ZapSpacing.lg),

      // Scheduler status card
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withOpacity(0.07),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.35))),
        child: Column(children: [
          Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 12, height: 12,
              decoration: BoxDecoration(
                  color: runState == _RunState.running
                      ? const Color(0xFFF59E0B)
                      : runState == _RunState.done
                          ? const Color(0xFF10B981)
                          : const Color(0xFF10B981),
                  shape: BoxShape.circle),
            ),
            const SizedBox(width: ZapSpacing.sm),
            Text(
              runState == _RunState.running ? 'Scheduler RUNNING…'
                  : runState == _RunState.done ? 'Scheduler COMPLETE ✅'
                  : 'Scheduler ACTIVE ● Waiting for next run',
              style: TextStyle(
                  color: runState == _RunState.running
                      ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                  fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: ZapSpacing.md),
          _statusRow('Next run',     'Tonight 03:00 AM (in ~13 hours)'),
          _statusRow('Last run',     'May 30, 2026  03:00 AM'),
          _statusRow('Last result',  '141 items deleted across 3 categories'),
          _statusRow('Avg duration', '2.3 seconds'),
          _statusRow('Run mode',     'Daily cron + app-foreground trigger'),
        ]),
      ),
      const SizedBox(height: ZapSpacing.lg),

      // Simulate run button
      if (runState == _RunState.idle)
        _primaryBtn(
          label: 'Simulate Scheduler Run  (Mock)',
          color: const Color(0xFF3B82F6),
          onTap: () => _runSimulation(ref),
        )
      else if (runState == _RunState.running)
        _RunningCard(progress: progress, deleted: deleted)
      else
        _RunDoneCard(deleted: deleted, ref: ref),

      const SizedBox(height: ZapSpacing.xl),

      // Per-category schedule
      const _SectionLabel('6 SCHEDULED CATEGORIES  ·  TAP TO EXPAND'),
      const SizedBox(height: ZapSpacing.md),

      ..._kSchedCats.asMap().entries.map((e) {
        final i    = e.key;
        final cat  = e.value;
        final isExp= expandedIdx == i;
        return GestureDetector(
          onTap: () => ref.read(_expandedCatSchedProvider.notifier).state =
              isExp ? null : i,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            decoration: BoxDecoration(
                color: isExp ? cat.color.withOpacity(0.07) : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                    color: isExp ? cat.color.withOpacity(0.4) : const Color(0xFF2A2A2A),
                    width: isExp ? 2 : 1)),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(ZapSpacing.md),
                child: Row(children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                        color: cat.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8)),
                    child: Icon(cat.icon, color: cat.color, size: 15)),
                  const SizedBox(width: ZapSpacing.md),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(cat.name, style: const TextStyle(color: Colors.white,
                        fontSize: 12, fontWeight: FontWeight.w600)),
                    Text(cat.runsAt, style: const TextStyle(
                        color: Color(0xFF6B7280), fontSize: 10)),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: (cat.serverSide
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF10B981)).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(cat.serverSide ? '🟡 Server' : '🟢 Local',
                        style: const TextStyle(fontSize: 9))),
                  const SizedBox(width: ZapSpacing.sm),
                  Icon(isExp ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                      color: const Color(0xFF4B5563), size: 14),
                ]),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                child: isExp
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(
                            ZapSpacing.md, 0, ZapSpacing.md, ZapSpacing.md),
                        child: Container(
                          padding: const EdgeInsets.all(ZapSpacing.sm),
                          decoration: BoxDecoration(
                              color: const Color(0xFF111111),
                              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                              border: Border.all(color: const Color(0xFF2A2A2A))),
                          child: Column(children: [
                            _detailRow('Trigger', cat.trigger, cat.color),
                            const SizedBox(height: 6),
                            _detailRow('Scope',   cat.scope,   const Color(0xFF9CA3AF)),
                          ])))
                    : const SizedBox.shrink(),
              ),
            ]),
          ),
        );
      }),

      const SizedBox(height: ZapSpacing.lg),

      // How local scheduler works
      const _SectionLabel('LOCAL SCHEDULER  ·  DART CODE PATTERN'),
      const SizedBox(height: ZapSpacing.md),
      _codeCard(context, _kSchedulerCode),
    ]);
  }

  static Widget _statusRow(String k, String v) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        SizedBox(width: 96, child: Text(k, style: const TextStyle(
            color: Color(0xFF6B7280), fontSize: 10))),
        Expanded(child: Text(v, style: const TextStyle(
            color: Color(0xFFD1D5DB), fontSize: 10))),
      ]));

  static Widget _detailRow(String k, String v, Color color) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 52, child: Text(k, style: TextStyle(
            color: color, fontSize: 9, fontWeight: FontWeight.w700))),
        Expanded(child: Text(v, style: const TextStyle(
            color: Color(0xFF9CA3AF), fontSize: 10, height: 1.4))),
      ]);

  static Future<void> _runSimulation(WidgetRef ref) async {
    ref.read(_simulateRunProvider.notifier).state = _RunState.running;
    ref.read(_deletedCountProvider.notifier).state = 0;

    const totalItems = 141; // mock total
    const steps      = 60;
    for (int i = 1; i <= steps; i++) {
      await Future.delayed(const Duration(milliseconds: 40));
      ref.read(_runProgressProvider.notifier).state = i / steps;
      ref.read(_deletedCountProvider.notifier).state =
          ((i / steps) * totalItems).round();
    }
    ref.read(_simulateRunProvider.notifier).state = _RunState.done;
  }
}

class _RunningCard extends StatelessWidget {
  final double progress; final int deleted;
  const _RunningCard({required this.progress, required this.deleted});

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
          color: const Color(0xFF3B82F6).withOpacity(0.07),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.35))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(
              color: Color(0xFF3B82F6), strokeWidth: 2)),
          const SizedBox(width: ZapSpacing.sm),
          const Text('Scheduler running…', style: TextStyle(
              color: Color(0xFF3B82F6), fontSize: 13, fontWeight: FontWeight.w700)),
          const Spacer(),
          Text('$deleted items deleted',
              style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
        ]),
        const SizedBox(height: ZapSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFF2A2A2A),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF3B82F6)),
              minHeight: 6)),
        const SizedBox(height: 6),
        Text('${(progress * 100).toStringAsFixed(0)}% complete',
            style: const TextStyle(color: Color(0xFF4B5563), fontSize: 9)),
      ]));
}

class _RunDoneCard extends StatelessWidget {
  final int deleted; final WidgetRef ref;
  const _RunDoneCard({required this.deleted, required this.ref});

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
          color: const Color(0xFF10B981).withOpacity(0.07),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.35))),
      child: Column(children: [
        const Row(children: [
          Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
          SizedBox(width: ZapSpacing.sm),
          Text('Scheduler run complete ✅', style: TextStyle(
              color: Color(0xFF10B981), fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: ZapSpacing.sm),
        Text('$deleted items deleted across 3 categories.\n'
            'All retention policies are now enforced.',
            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11, height: 1.5)),
        const SizedBox(height: ZapSpacing.md),
        GestureDetector(
          onTap: () {
            ref.read(_simulateRunProvider.notifier).state = _RunState.idle;
            ref.read(_runProgressProvider.notifier).state = 0;
            ref.read(_deletedCountProvider.notifier).state = 0;
          },
          child: const Text('Run again', style: TextStyle(
              color: Color(0xFF3B82F6), fontSize: 11,
              decoration: TextDecoration.underline))),
      ]));
}

const _kSchedulerCode = '''
// lib/services/retention_scheduler.dart
// 🟢 FRONTEND-ONLY — runs locally on device for non-server categories

class RetentionScheduler {
  final HiveBox retentionBox;
  final HiveBox analyticsBox;
  final HiveBox notifBox;

  /// Called on app foreground + WorkManager daily job
  Future<void> runPurge() async {
    final settings = RetentionSettings.fromHive(retentionBox);
    int deleted = 0;

    // Analytics & crash logs (local Hive)
    if (settings.analyticsDays > 0) {
      final cutoff = DateTime.now()
          .subtract(Duration(days: settings.analyticsDays));
      deleted += await analyticsBox.deleteWhere(
          (e) => e.createdAt.isBefore(cutoff));
    }

    // Notification history (local Hive)
    if (settings.notificationsDays > 0) {
      final cutoff = DateTime.now()
          .subtract(Duration(days: settings.notificationsDays));
      deleted += await notifBox.deleteWhere(
          (e) => e.createdAt.isBefore(cutoff));
    }

    // Server-enforced categories (SOS, Evidence, Location, Audit)
    // → backend scheduler handles these; frontend just displays status
    debugPrint("Purge complete: \$deleted items deleted");
  }
}''';

// ══════════════════════════════════════════════════════════════════════════════
// TAB 3 — Change History
// ══════════════════════════════════════════════════════════════════════════════
class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(_expandedHistoryProvider);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.manage_history_rounded, color: const Color(0xFF8B5CF6),
          text: 'Every change to your data retention settings is logged. '
              'GDPR Art. 5(2) accountability: ZapSafe must demonstrate '
              'that processing meets the principles, including retention limits.'),
      const SizedBox(height: ZapSpacing.lg),

      // Stats
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A))),
        child: Row(children: [
          _stat('${_kHistory.length}', 'Total changes',  const Color(0xFF8B5CF6)),
          _stat('${_kHistory.where((h) => h.changedBy == "User").length}',
              'By user', const Color(0xFF3B82F6)),
          _stat('1', 'By system', const Color(0xFF6B7280)),
          _stat('Jan 15', 'First change', const Color(0xFF10B981)),
        ]),
      ),
      const SizedBox(height: ZapSpacing.lg),

      const _SectionLabel('RETENTION CHANGE LOG  ·  NEWEST FIRST'),
      const SizedBox(height: ZapSpacing.md),

      ..._kHistory.asMap().entries.map((e) {
        final i    = e.key;
        final hist = e.value;
        final isExp= expanded == i;

        return GestureDetector(
          onTap: () => ref.read(_expandedHistoryProvider.notifier).state =
              isExp ? null : i,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            decoration: BoxDecoration(
                color: isExp
                    ? hist.color.withOpacity(0.07) : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                    color: isExp
                        ? hist.color.withOpacity(0.4) : const Color(0xFF2A2A2A),
                    width: isExp ? 2 : 1)),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(ZapSpacing.md),
                child: Row(children: [
                  Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                        color: hist.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8)),
                    child: Icon(hist.icon, color: hist.color, size: 16)),
                  const SizedBox(width: ZapSpacing.md),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(hist.category, style: const TextStyle(color: Colors.white,
                        fontSize: 12, fontWeight: FontWeight.w600)),
                    Row(children: [
                      // from → to
                      if (hist.fromPeriod != '—') ...[
                        Text(hist.fromPeriod, style: const TextStyle(
                            color: Color(0xFFEF4444), fontSize: 10)),
                        const Icon(Icons.arrow_forward_rounded,
                            color: Color(0xFF4B5563), size: 12),
                      ],
                      Text(hist.toPeriod, style: const TextStyle(
                          color: Color(0xFF10B981), fontSize: 10,
                          fontWeight: FontWeight.w700)),
                    ]),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(_fmtDate(hist.ts), style: const TextStyle(
                        color: Color(0xFF4B5563), fontSize: 9)),
                    const SizedBox(height: 3),
                    Text(hist.changedBy, style: const TextStyle(
                        color: Color(0xFF6B7280), fontSize: 9)),
                  ]),
                  const SizedBox(width: ZapSpacing.sm),
                  Icon(isExp ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                      color: const Color(0xFF4B5563), size: 14),
                ]),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                child: isExp
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(
                            ZapSpacing.md, 0, ZapSpacing.md, ZapSpacing.md),
                        child: Container(
                          padding: const EdgeInsets.all(ZapSpacing.sm),
                          decoration: BoxDecoration(
                              color: const Color(0xFF111111),
                              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                              border: Border.all(color: const Color(0xFF2A2A2A))),
                          child: Column(children: [
                            _histRow('Changed by', hist.changedBy),
                            _histRow('Date/time',  _fmtFull(hist.ts)),
                            _histRow('Category',   hist.category),
                            _histRow('From',        hist.fromPeriod),
                            _histRow('To',          hist.toPeriod),
                            _histRow('Reason',      hist.reason),
                          ])))
                    : const SizedBox.shrink(),
              ),
            ]),
          ),
        );
      }),

      const SizedBox(height: ZapSpacing.lg),

      // GDPR accountability note
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFF8B5CF6).withOpacity(0.06),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3))),
        child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.gavel_rounded, color: Color(0xFF8B5CF6), size: 14),
            SizedBox(width: ZapSpacing.sm),
            Text('GDPR Art. 5(2) — Accountability',
                style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ]),
          SizedBox(height: 6),
          Text(
            '"The controller shall be responsible for, and be able to demonstrate '
            'compliance with, paragraph 1." This change history is part of that '
            'demonstration — ZapSafe logs every retention change with timestamp, '
            'actor, and reason.',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 10,
                height: 1.6, fontStyle: FontStyle.italic)),
        ])),
    ]);
  }

  Widget _stat(String v, String l, Color c) => Expanded(child: Column(children: [
    Text(v, style: TextStyle(color: c, fontSize: 14, fontWeight: FontWeight.w900),
        textAlign: TextAlign.center),
    Text(l, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 9, height: 1.3),
        textAlign: TextAlign.center),
  ]));

  Widget _histRow(String k, String v) => Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 72, child: Text(k, style: const TextStyle(
            color: Color(0xFF6B7280), fontSize: 10))),
        Expanded(child: Text(v, style: const TextStyle(
            color: Color(0xFFD1D5DB), fontSize: 10, height: 1.4))),
      ]));

  static String _fmtDate(DateTime d) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun',
                'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[d.month-1]} ${d.day}, ${d.year}';
  }

  static String _fmtFull(DateTime d) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun',
                'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[d.month-1]} ${d.day}, ${d.year}  '
        '${d.hour.toString().padLeft(2,'0')}:'
        '${d.minute.toString().padLeft(2,'0')} IST';
  }
}

// ── Shared helpers ─────────────────────────────────────────────────────────────
Widget _primaryBtn({required String label, required Color color,
    required VoidCallback onTap}) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color, color.withOpacity(0.8)]),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            boxShadow: [BoxShadow(color: color.withOpacity(0.3),
                blurRadius: 14, offset: const Offset(0, 4))]),
        child: Center(child: Text(label, style: const TextStyle(
            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)))));

Widget _codeCard(BuildContext context, String code) => GestureDetector(
    onLongPress: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Copied'), backgroundColor: Color(0xFF1A1A1A),
        duration: Duration(seconds: 1))),
    child: Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: const Color(0xFF2A2A2A))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Expanded(child: Text('long-press to copy',
              style: TextStyle(color: Color(0xFF4B5563), fontSize: 9))),
          Icon(Icons.copy_rounded, color: Color(0xFF4B5563), size: 12),
        ]),
        const SizedBox(height: ZapSpacing.sm),
        Text(code, style: const TextStyle(color: Color(0xFF86EFAC),
            fontSize: 10, fontFamily: 'monospace', height: 1.6)),
      ])));

Widget _infoBox({required IconData icon, required Color color, required String text}) =>
    Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: color.withOpacity(0.25))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: ZapSpacing.sm),
        Expanded(child: Text(text, style: const TextStyle(
            color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6))),
      ]));
