/// Day 254 — Family Member SOS History
///
/// Section C (Days 241-260): admin-only drill-down per linked family member —
/// chronological timeline of SOS, drill, false-positive, and group events.
///
/// Tag: 🟡 MOCK-NOW · GET member sos-history · privacy admin role.
///
/// Route: [AppRoutes.familySosHistory] → `/family-sos-history`
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
const _kAccent = Color(0xFF7C3AED);
const _kTabs = ['Timeline', 'Members', 'Info'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');

const _kFamilyMembers = [
  _MemberSummary(
    id: 'fam_mom_001',
    name: 'Sunita Mehta',
    relation: 'Mother',
    initials: 'SM',
    color: Color(0xFFEC4899),
  ),
  _MemberSummary(
    id: 'fam_dad_002',
    name: 'Rajesh Mehta',
    relation: 'Father',
    initials: 'RM',
    color: Color(0xFF3B82F6),
  ),
  _MemberSummary(
    id: 'fam_sis_003',
    name: 'Ananya Mehta',
    relation: 'Sister',
    initials: 'AM',
    color: Color(0xFF8B5CF6),
  ),
  _MemberSummary(
    id: 'fam_bro_004',
    name: 'Rahul Mehta',
    relation: 'Brother',
    initials: 'RM',
    color: Color(0xFFDC2626),
  ),
  _MemberSummary(
    id: 'fam_grand_005',
    name: 'Kamala Mehta',
    relation: 'Grandmother',
    initials: 'KM',
    color: Color(0xFFF59E0B),
  ),
  _MemberSummary(
    id: 'fam_child_006',
    name: 'Arjun Mehta',
    relation: 'Son (Child profile)',
    initials: 'AM',
    color: Color(0xFF10B981),
    childProfile: true,
  ),
];

const _kHistoryEvents = [
  _SosHistoryEvent(
    id: 'evt_001',
    memberId: 'fam_bro_004',
    type: _EventType.sos,
    title: 'SOS active',
    detail: 'Manual trigger · Tier 1 notified · location sharing on',
    occurredAt: 'Today · 14:32 IST',
    sortKey: 0,
    duration: 'Ongoing',
    contactsNotified: 2,
    resolved: false,
  ),
  _SosHistoryEvent(
    id: 'evt_002',
    memberId: 'fam_bro_004',
    type: _EventType.drill,
    title: 'Safety drill',
    detail: 'Monthly family drill · all contacts acknowledged',
    occurredAt: '3 days ago · 19:00 IST',
    sortKey: 3,
    duration: '4m 12s',
    contactsNotified: 2,
    resolved: true,
  ),
  _SosHistoryEvent(
    id: 'evt_003',
    memberId: 'fam_bro_004',
    type: _EventType.falsePositive,
    title: 'False alarm reported',
    detail: 'User marked false positive · ML training signal sent',
    occurredAt: '8 days ago · 22:15 IST',
    sortKey: 8,
    duration: '1m 45s',
    contactsNotified: 2,
    resolved: true,
  ),
  _SosHistoryEvent(
    id: 'evt_004',
    memberId: 'fam_bro_004',
    type: _EventType.groupPanic,
    title: 'Group journey panic',
    detail: 'Host triggered group panic · 10 contacts notified',
    occurredAt: '12 days ago · 21:40 IST',
    sortKey: 12,
    duration: '6m 30s',
    contactsNotified: 10,
    resolved: true,
  ),
  _SosHistoryEvent(
    id: 'evt_005',
    memberId: 'fam_mom_001',
    type: _EventType.drill,
    title: 'Safety drill',
    detail: 'Scheduled weekly drill · passed',
    occurredAt: '5 days ago · 10:00 IST',
    sortKey: 5,
    duration: '3m 05s',
    contactsNotified: 1,
    resolved: true,
  ),
  _SosHistoryEvent(
    id: 'evt_006',
    memberId: 'fam_mom_001',
    type: _EventType.drill,
    title: 'Safety drill',
    detail: 'Onboarding drill after app install',
    occurredAt: '28 days ago · 11:30 IST',
    sortKey: 28,
    duration: '2m 50s',
    contactsNotified: 1,
    resolved: true,
  ),
  _SosHistoryEvent(
    id: 'evt_007',
    memberId: 'fam_dad_002',
    type: _EventType.journey,
    title: 'Journey auto-alert',
    detail: 'Session expired without check-in · notify contact sent',
    occurredAt: '6 days ago · 23:10 IST',
    sortKey: 6,
    duration: '—',
    contactsNotified: 1,
    resolved: true,
  ),
  _SosHistoryEvent(
    id: 'evt_008',
    memberId: 'fam_dad_002',
    type: _EventType.sos,
    title: 'SOS resolved',
    detail: 'Ride deviation >500m · auto-SOS · cancelled on arrival',
    occurredAt: '14 days ago · 18:05 IST',
    sortKey: 14,
    duration: '12m 20s',
    contactsNotified: 2,
    resolved: true,
  ),
  _SosHistoryEvent(
    id: 'evt_009',
    memberId: 'fam_sis_003',
    type: _EventType.drill,
    title: 'Safety drill',
    detail: 'Campus safety week drill',
    occurredAt: '10 days ago · 16:00 IST',
    sortKey: 10,
    duration: '3m 40s',
    contactsNotified: 2,
    resolved: true,
  ),
  _SosHistoryEvent(
    id: 'evt_010',
    memberId: 'fam_child_006',
    type: _EventType.sos,
    title: 'SOS cancelled (admin PIN)',
    detail: 'Child profile · parent PIN required to cancel',
    occurredAt: '20 days ago · 15:22 IST',
    sortKey: 20,
    duration: '45s',
    contactsNotified: 2,
    resolved: true,
  ),
  _SosHistoryEvent(
    id: 'evt_011',
    memberId: 'fam_child_006',
    type: _EventType.drill,
    title: 'School safety drill',
    detail: 'Supervised drill with teacher present',
    occurredAt: '25 days ago · 12:00 IST',
    sortKey: 25,
    duration: '2m 10s',
    contactsNotified: 2,
    resolved: true,
  ),
  _SosHistoryEvent(
    id: 'evt_012',
    memberId: 'fam_grand_005',
    type: _EventType.drill,
    title: 'Safety drill',
    detail: 'Family admin ran drill on grandmother device',
    occurredAt: '45 days ago · 09:00 IST',
    sortKey: 45,
    duration: '5m 00s',
    contactsNotified: 1,
    resolved: true,
  ),
];

enum _EventType { sos, drill, falsePositive, groupPanic, journey }

enum _HistoryFilter { all, sosOnly, drillsOnly }

// ── Models ────────────────────────────────────────────────────────────────────
class _MemberSummary {
  const _MemberSummary({
    required this.id,
    required this.name,
    required this.relation,
    required this.initials,
    required this.color,
    this.childProfile = false,
  });

  final String id;
  final String name;
  final String relation;
  final String initials;
  final Color color;
  final bool childProfile;
}

class _SosHistoryEvent {
  const _SosHistoryEvent({
    required this.id,
    required this.memberId,
    required this.type,
    required this.title,
    required this.detail,
    required this.occurredAt,
    required this.sortKey,
    required this.duration,
    required this.contactsNotified,
    required this.resolved,
  });

  final String id;
  final String memberId;
  final _EventType type;
  final String title;
  final String detail;
  final String occurredAt;
  final int sortKey;
  final String duration;
  final int contactsNotified;
  final bool resolved;

  Map<String, dynamic> toJson() => {
        'id': id,
        'member_id': memberId,
        'type': type.name,
        'title': title,
        'detail': detail,
        'occurred_at': occurredAt,
        'duration': duration,
        'contacts_notified': contactsNotified,
        'resolved': resolved,
      };
}

// ── Providers ─────────────────────────────────────────────────────────────────
final _d254TabProvider = StateProvider<int>((ref) => 0);
final _d254MemberIdProvider =
    StateProvider<String>((ref) => 'fam_bro_004');
final _d254FilterProvider =
    StateProvider<_HistoryFilter>((ref) => _HistoryFilter.all);
final _d254ExpandedEventProvider = StateProvider<String?>((ref) => null);

// ── Helpers ───────────────────────────────────────────────────────────────────
_MemberSummary? _memberById(String id) {
  for (final m in _kFamilyMembers) {
    if (m.id == id) return m;
  }
  return null;
}

List<_SosHistoryEvent> _eventsForMember(String memberId) {
  return _kHistoryEvents
      .where((e) => e.memberId == memberId)
      .toList()
    ..sort((a, b) => a.sortKey.compareTo(b.sortKey));
}

List<_SosHistoryEvent> _filteredEvents(
  List<_SosHistoryEvent> events,
  _HistoryFilter filter,
) {
  return switch (filter) {
    _HistoryFilter.sosOnly => events
        .where(
          (e) =>
              e.type == _EventType.sos ||
              e.type == _EventType.groupPanic ||
              e.type == _EventType.journey,
        )
        .toList(),
    _HistoryFilter.drillsOnly =>
      events.where((e) => e.type == _EventType.drill).toList(),
    _ => events,
  };
}

int _eventCountForMember(String memberId) =>
    _eventsForMember(memberId).length;

Color _eventColor(_EventType type) {
  return switch (type) {
    _EventType.sos => ZapColors.danger,
    _EventType.drill => ZapColors.safe,
    _EventType.falsePositive => ZapColors.warning,
    _EventType.groupPanic => const Color(0xFFDC2626),
    _EventType.journey => const Color(0xFF8B5CF6),
  };
}

IconData _eventIcon(_EventType type) {
  return switch (type) {
    _EventType.sos => Icons.emergency_rounded,
    _EventType.drill => Icons.fitness_center_rounded,
    _EventType.falsePositive => Icons.report_gmailerrorred_rounded,
    _EventType.groupPanic => Icons.groups_rounded,
    _EventType.journey => Icons.navigation_rounded,
  };
}

String _eventTypeLabel(_EventType type) {
  return switch (type) {
    _EventType.sos => 'SOS',
    _EventType.drill => 'Drill',
    _EventType.falsePositive => 'False positive',
    _EventType.groupPanic => 'Group panic',
    _EventType.journey => 'Journey alert',
  };
}

Map<String, dynamic> _historyPayload(String memberId) {
  final member = _memberById(memberId);
  final events = _eventsForMember(memberId);
  return {
    'member_id': memberId,
    'member_name': member?.name,
    'admin_role_required': true,
    'events': events.map((e) => e.toJson()).toList(),
    'total_events': events.length,
  };
}

// ── Screen ────────────────────────────────────────────────────────────────────
class Day254FamilySosHistoryScreen extends ConsumerWidget {
  const Day254FamilySosHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d254TabProvider);
    final memberId = ref.watch(_d254MemberIdProvider);
    final member = _memberById(memberId);
    final activeSos = _eventsForMember(memberId)
        .any((e) => e.type == _EventType.sos && !e.resolved);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 254 · SOS History'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _kAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _kAccent.withOpacity(0.45)),
                ),
                child: const Text(
                  'ADMIN',
                  style: TextStyle(
                    color: _kAccent,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (activeSos && member != null)
            _ActiveSosBanner(memberName: member.name),
          _TabBar(
            tab: tab,
            onSelect: (i) => ref.read(_d254TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (tab) {
              0 => const _TimelineTab(),
              1 => _MembersTab(
                  onSelect: (id) {
                    ref.read(_d254MemberIdProvider.notifier).state = id;
                    ref.read(_d254TabProvider.notifier).state = 0;
                  },
                ),
              _ => const _InfoTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Banner ────────────────────────────────────────────────────────────────────
class _ActiveSosBanner extends StatelessWidget {
  const _ActiveSosBanner({required this.memberName});

  final String memberName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: ZapSpacing.lg,
        vertical: ZapSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: ZapColors.danger.withOpacity(0.12),
        border: Border(
          bottom: BorderSide(color: ZapColors.danger.withOpacity(0.4)),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.emergency_rounded, color: ZapColors.danger, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$memberName has an unresolved SOS in history view',
              style: const TextStyle(
                color: ZapColors.danger,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Timeline ───────────────────────────────────────────────────────────
class _TimelineTab extends ConsumerWidget {
  const _TimelineTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberId = ref.watch(_d254MemberIdProvider);
    final filter = ref.watch(_d254FilterProvider);
    final expandedId = ref.watch(_d254ExpandedEventProvider);
    final member = _memberById(memberId);
    final events = _filteredEvents(_eventsForMember(memberId), filter);

    if (member == null) {
      return const Center(child: Text('Member not found.'));
    }

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: ZapColors.warning.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: ZapColors.warning.withOpacity(0.35)),
          ),
          child: const Text(
            '🟡 MOCK-NOW · Section C Day 14/20 · admin-only privacy · per-member timeline',
            style: TextStyle(color: ZapColors.warning, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: member.color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: member.color.withOpacity(0.35)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: member.color.withOpacity(0.2),
                child: Text(
                  member.initials,
                  style: TextStyle(
                    color: member.color,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      style: const TextStyle(
                        color: ZapColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${member.relation} · ${_eventCountForMember(memberId)} events',
                      style: const TextStyle(
                        color: ZapColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: () => ref.read(_d254TabProvider.notifier).state = 1,
                child: const Text('Switch'),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _kFamilyMembers.map((m) {
              final selected = m.id == memberId;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(m.name.split(' ').first),
                  selected: selected,
                  onSelected: (_) =>
                      ref.read(_d254MemberIdProvider.notifier).state = m.id,
                  selectedColor: _kAccent.withOpacity(0.25),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              label: const Text('All'),
              selected: filter == _HistoryFilter.all,
              onSelected: (_) => ref
                  .read(_d254FilterProvider.notifier)
                  .state = _HistoryFilter.all,
            ),
            FilterChip(
              label: const Text('SOS & alerts'),
              selected: filter == _HistoryFilter.sosOnly,
              onSelected: (_) => ref
                  .read(_d254FilterProvider.notifier)
                  .state = _HistoryFilter.sosOnly,
            ),
            FilterChip(
              label: const Text('Drills only'),
              selected: filter == _HistoryFilter.drillsOnly,
              onSelected: (_) => ref
                  .read(_d254FilterProvider.notifier)
                  .state = _HistoryFilter.drillsOnly,
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.lg),
        if (events.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Text(
              'No events for this filter.',
              textAlign: TextAlign.center,
              style: TextStyle(color: ZapColors.textMuted),
            ),
          )
        else
          ...events.asMap().entries.map((entry) {
            final i = entry.key;
            final event = entry.value;
            final isLast = i == events.length - 1;
            return _TimelineEventTile(
              event: event,
              expanded: expandedId == event.id,
              showConnector: !isLast,
              onTap: () {
                ref.read(_d254ExpandedEventProvider.notifier).state =
                    expandedId == event.id ? null : event.id;
              },
            );
          }),
      ],
    );
  }
}

// ── Tab 1: Members ────────────────────────────────────────────────────────────
class _MembersTab extends ConsumerWidget {
  const _MembersTab({required this.onSelect});

  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(_d254MemberIdProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text(
          'Select a member to view SOS & drill history',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          'Privacy: only family admins can access another member\'s event timeline.',
          style: TextStyle(color: ZapColors.textSecondary, fontSize: 11),
        ),
        const SizedBox(height: ZapSpacing.lg),
        ..._kFamilyMembers.map((m) {
          final count = _eventCountForMember(m.id);
          final hasActiveSos = _eventsForMember(m.id)
              .any((e) => e.type == _EventType.sos && !e.resolved);
          return _MemberPickTile(
            member: m,
            eventCount: count,
            selected: selectedId == m.id,
            hasActiveSos: hasActiveSos,
            onTap: () => onSelect(m.id),
          );
        }),
        const SizedBox(height: ZapSpacing.lg),
        OutlinedButton.icon(
          onPressed: () => context.push(AppRoutes.familyAlertsDashboard),
          icon: const Icon(Icons.dashboard_rounded),
          label: const Text('Day 253 · Family Dashboard'),
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
    final memberId = ref.watch(_d254MemberIdProvider);
    final payload = _historyPayload(memberId);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text(
          'Family Member SOS History',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          'Drill-down timeline per linked member — real SOS, drills, false '
          'positives, group panic, and journey alerts. Non-admin members '
          'cannot view other profiles\' history.',
          style: TextStyle(
            color: ZapColors.textSecondary,
            fontSize: 12,
            height: 1.45,
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'GET /api/v1/family/members/{member_id}/sos-history/',
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
              const SnackBar(content: Text('SOS history JSON copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy history JSON'),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const _PolicyRow(
          icon: Icons.lock_rounded,
          title: 'Admin role required',
          subtitle:
              'Matches Day 253 dashboard admin gate. Child profile events '
              'include admin-PIN cancel metadata (Day 255).',
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
            'Next: Day 365 — Global Launch Milestone.',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              label: const Text('Day 256 SOS Widget'),
              onPressed: () => context.push(AppRoutes.homeWidgetSos),
            ),
            ActionChip(
              label: const Text('Day 255 Child Admin Lock'),
              onPressed: () => context.push(AppRoutes.childModeAdmin),
            ),
            ActionChip(
              label: const Text('Day 253 Family Dashboard'),
              onPressed: () => context.push(AppRoutes.familyAlertsDashboard),
            ),
            ActionChip(
              label: const Text('Day 252 Group Panic'),
              onPressed: () => context.push(AppRoutes.groupJourneyPanic),
            ),
            ActionChip(
              label: const Text('Day 76 SOS Active'),
              onPressed: () => context.push(AppRoutes.sosActive),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────
class _TimelineEventTile extends StatelessWidget {
  const _TimelineEventTile({
    required this.event,
    required this.expanded,
    required this.showConnector,
    required this.onTap,
  });

  final _SosHistoryEvent event;
  final bool expanded;
  final bool showConnector;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _eventColor(event.type);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: color),
                  ),
                  child: Icon(_eventIcon(event.type), color: color, size: 14),
                ),
                if (showConnector)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: ZapColors.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: expanded ? color.withOpacity(0.06) : ZapColors.bgCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: expanded ? color.withOpacity(0.35) : ZapColors.border,
                ),
              ),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.all(ZapSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _eventTypeLabel(event.type),
                              style: TextStyle(
                                color: color,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (!event.resolved)
                            const Text(
                              'ACTIVE',
                              style: TextStyle(
                                color: ZapColors.danger,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        event.title,
                        style: const TextStyle(
                          color: ZapColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        event.occurredAt,
                        style: const TextStyle(
                          color: ZapColors.textMuted,
                          fontSize: 10,
                        ),
                      ),
                      if (expanded) ...[
                        const SizedBox(height: 8),
                        Text(
                          event.detail,
                          style: const TextStyle(
                            color: ZapColors.textSecondary,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _DetailRow(
                          label: 'Duration',
                          value: event.duration,
                        ),
                        _DetailRow(
                          label: 'Contacts notified',
                          value: '${event.contactsNotified}',
                        ),
                        _DetailRow(
                          label: 'Resolved',
                          value: event.resolved ? 'Yes' : 'No',
                          valueColor:
                              event.resolved ? ZapColors.safe : ZapColors.danger,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberPickTile extends StatelessWidget {
  const _MemberPickTile({
    required this.member,
    required this.eventCount,
    required this.selected,
    required this.hasActiveSos,
    required this.onTap,
  });

  final _MemberSummary member;
  final int eventCount;
  final bool selected;
  final bool hasActiveSos;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: selected ? _kAccent.withOpacity(0.08) : ZapColors.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? _kAccent.withOpacity(0.4) : ZapColors.border,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: member.color.withOpacity(0.2),
          child: Text(
            member.initials,
            style: TextStyle(
              color: member.color,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ),
        title: Text(
          member.name,
          style: const TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        subtitle: Text(
          '${member.relation} · $eventCount events'
          '${member.childProfile ? ' · Child profile' : ''}',
          style: const TextStyle(
            color: ZapColors.textSecondary,
            fontSize: 11,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasActiveSos)
              const Icon(
                Icons.emergency_rounded,
                color: ZapColors.danger,
                size: 18,
              ),
            const SizedBox(width: 8),
            Icon(
              selected ? Icons.check_circle : Icons.chevron_right_rounded,
              color: selected ? _kAccent : ZapColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: ZapColors.textMuted,
                fontSize: 10,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? ZapColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ],
      ),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: ZapColors.info, size: 20),
        const SizedBox(width: 10),
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
