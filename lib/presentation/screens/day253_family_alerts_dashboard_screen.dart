/// Day 253 — Family Alerts Dashboard
///
/// Section C (Days 241-260): family admin view of all linked members —
/// last active timestamps, SOS status indicators, protection scores.
///
/// Tag: 🟡 MOCK-NOW · GET family dashboard · admin role mock.
///
/// Route: [AppRoutes.familyAlertsDashboard] → `/family-alerts-dashboard`
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
const _kTabs = ['Dashboard', 'Members', 'Info'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');

const _kInitialMembers = [
  _FamilyMember(
    id: 'fam_mom_001',
    name: 'Sunita Mehta',
    relation: 'Mother',
    initials: 'SM',
    color: Color(0xFFEC4899),
    lastSeen: '5 min ago',
    lastSeenMinutes: 5,
    sosActive: false,
    protectionScore: 72,
    device: 'Samsung Galaxy A54',
    journeyActive: false,
  ),
  _FamilyMember(
    id: 'fam_dad_002',
    name: 'Rajesh Mehta',
    relation: 'Father',
    initials: 'RM',
    color: Color(0xFF3B82F6),
    lastSeen: '1 hr ago',
    lastSeenMinutes: 60,
    sosActive: false,
    protectionScore: 85,
    device: 'iPhone 13',
    journeyActive: true,
  ),
  _FamilyMember(
    id: 'fam_sis_003',
    name: 'Ananya Mehta',
    relation: 'Sister',
    initials: 'AM',
    color: Color(0xFF8B5CF6),
    lastSeen: '2 min ago',
    lastSeenMinutes: 2,
    sosActive: false,
    protectionScore: 91,
    device: 'Pixel 8',
    journeyActive: false,
  ),
  _FamilyMember(
    id: 'fam_bro_004',
    name: 'Rahul Mehta',
    relation: 'Brother',
    initials: 'RM',
    color: Color(0xFFDC2626),
    lastSeen: 'Just now',
    lastSeenMinutes: 0,
    sosActive: true,
    protectionScore: 45,
    device: 'OnePlus 12',
    journeyActive: false,
  ),
  _FamilyMember(
    id: 'fam_grand_005',
    name: 'Kamala Mehta',
    relation: 'Grandmother',
    initials: 'KM',
    color: Color(0xFFF59E0B),
    lastSeen: '3 days ago',
    lastSeenMinutes: 4320,
    sosActive: false,
    protectionScore: 58,
    device: 'Redmi Note 12',
    journeyActive: false,
  ),
  _FamilyMember(
    id: 'fam_child_006',
    name: 'Arjun Mehta',
    relation: 'Son (Child profile)',
    initials: 'AM',
    color: Color(0xFF10B981),
    lastSeen: '18 min ago',
    lastSeenMinutes: 18,
    sosActive: false,
    protectionScore: 67,
    device: 'Samsung Tab A8',
    journeyActive: false,
    childProfile: true,
  ),
];

// ── Models ────────────────────────────────────────────────────────────────────
class _FamilyMember {
  const _FamilyMember({
    required this.id,
    required this.name,
    required this.relation,
    required this.initials,
    required this.color,
    required this.lastSeen,
    required this.lastSeenMinutes,
    required this.sosActive,
    required this.protectionScore,
    required this.device,
    required this.journeyActive,
    this.childProfile = false,
  });

  final String id;
  final String name;
  final String relation;
  final String initials;
  final Color color;
  final String lastSeen;
  final int lastSeenMinutes;
  final bool sosActive;
  final int protectionScore;
  final String device;
  final bool journeyActive;
  final bool childProfile;

  bool get isOffline => lastSeenMinutes > 1440;

  _FamilyMember copyWith({
    bool? sosActive,
    int? protectionScore,
    String? lastSeen,
    int? lastSeenMinutes,
  }) {
    return _FamilyMember(
      id: id,
      name: name,
      relation: relation,
      initials: initials,
      color: color,
      lastSeen: lastSeen ?? this.lastSeen,
      lastSeenMinutes: lastSeenMinutes ?? this.lastSeenMinutes,
      sosActive: sosActive ?? this.sosActive,
      protectionScore: protectionScore ?? this.protectionScore,
      device: device,
      journeyActive: journeyActive,
      childProfile: childProfile,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'relation': relation,
        'last_seen': lastSeen,
        'last_seen_minutes': lastSeenMinutes,
        'sos_active': sosActive,
        'protection_score': protectionScore,
        'device': device,
        'journey_active': journeyActive,
        'child_profile': childProfile,
      };
}

enum _MemberFilter { all, sosActive, offline }

// ── Providers ─────────────────────────────────────────────────────────────────
final _d253TabProvider = StateProvider<int>((ref) => 0);
final _d253MembersProvider =
    StateProvider<List<_FamilyMember>>((ref) => List.from(_kInitialMembers));
final _d253FilterProvider =
    StateProvider<_MemberFilter>((ref) => _MemberFilter.all);
final _d253LoadingProvider = StateProvider<bool>((ref) => false);
final _d253SelectedIdProvider = StateProvider<String?>((ref) => null);
final _d253LastRefreshProvider = StateProvider<DateTime?>((ref) => null);

// ── Helpers ───────────────────────────────────────────────────────────────────
List<_FamilyMember> _filteredMembers(
  List<_FamilyMember> members,
  _MemberFilter filter,
) {
  return switch (filter) {
    _MemberFilter.sosActive => members.where((m) => m.sosActive).toList(),
    _MemberFilter.offline => members.where((m) => m.isOffline).toList(),
    _ => members,
  };
}

Map<String, dynamic> _buildDashboardPayload(List<_FamilyMember> members) {
  return {
    'members': members.map((m) => m.toJson()).toList(),
    'admin_id': 'fam_admin_you',
    'family_name': 'Mehta Family',
    'sos_active_count': members.where((m) => m.sosActive).length,
    'member_count': members.length,
  };
}

Color _scoreColor(int score) {
  if (score >= 80) return ZapColors.safe;
  if (score >= 60) return ZapColors.warning;
  return ZapColors.danger;
}

// ── Screen ────────────────────────────────────────────────────────────────────
class Day253FamilyAlertsDashboardScreen extends ConsumerWidget {
  const Day253FamilyAlertsDashboardScreen({super.key});

  Future<void> _refreshDashboard(WidgetRef ref) async {
    ref.read(_d253LoadingProvider.notifier).state = true;
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    ref.read(_d253MembersProvider.notifier).state = List.from(_kInitialMembers);
    ref.read(_d253LastRefreshProvider.notifier).state = DateTime.now();
    ref.read(_d253LoadingProvider.notifier).state = false;
  }

  void _toggleMemberSos(WidgetRef ref, String id) {
    final members = ref.read(_d253MembersProvider).map((m) {
      if (m.id != id) return m;
      return m.copyWith(sosActive: !m.sosActive);
    }).toList();
    ref.read(_d253MembersProvider.notifier).state = members;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d253TabProvider);
    final members = ref.watch(_d253MembersProvider);
    final sosCount = members.where((m) => m.sosActive).length;

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 253 · Family Dashboard'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: sosCount > 0
                      ? ZapColors.danger.withOpacity(0.15)
                      : _kAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: sosCount > 0
                        ? ZapColors.danger.withOpacity(0.45)
                        : _kAccent.withOpacity(0.45),
                  ),
                ),
                child: Text(
                  sosCount > 0 ? '$sosCount SOS' : 'ADMIN',
                  style: TextStyle(
                    color: sosCount > 0 ? ZapColors.danger : _kAccent,
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
          if (sosCount > 0) _SosAlertStrip(count: sosCount),
          _TabBar(
            tab: tab,
            onSelect: (i) => ref.read(_d253TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (tab) {
              0 => _DashboardTab(
                  onRefresh: () => _refreshDashboard(ref),
                  onSelectMember: (id) {
                    ref.read(_d253SelectedIdProvider.notifier).state = id;
                    ref.read(_d253TabProvider.notifier).state = 1;
                  },
                ),
              1 => _MembersTab(
                  onToggleSos: (id) => _toggleMemberSos(ref, id),
                ),
              _ => const _InfoTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── SOS strip ─────────────────────────────────────────────────────────────────
class _SosAlertStrip extends StatelessWidget {
  const _SosAlertStrip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: ZapSpacing.lg,
        vertical: ZapSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: ZapColors.danger.withOpacity(0.15),
        border: Border(
          bottom: BorderSide(color: ZapColors.danger.withOpacity(0.45)),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.emergency_rounded, color: ZapColors.danger, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$count family member${count == 1 ? '' : 's'} with active SOS — '
              'tap member for details',
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

// ── Tab 0: Dashboard ──────────────────────────────────────────────────────────
class _DashboardTab extends ConsumerWidget {
  const _DashboardTab({
    required this.onRefresh,
    required this.onSelectMember,
  });

  final Future<void> Function() onRefresh;
  final ValueChanged<String> onSelectMember;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(_d253MembersProvider);
    final filter = ref.watch(_d253FilterProvider);
    final loading = ref.watch(_d253LoadingProvider);
    final lastRefresh = ref.watch(_d253LastRefreshProvider);
    final filtered = _filteredMembers(members, filter);

    final sosCount = members.where((m) => m.sosActive).length;
    final offlineCount = members.where((m) => m.isOffline).length;
    final avgScore = members.isEmpty
        ? 0
        : (members.map((m) => m.protectionScore).reduce((a, b) => a + b) /
                members.length)
            .round();

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: _kAccent,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
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
              '🟡 MOCK-NOW · Section C Day 13/20 · family admin · linked members',
              style: TextStyle(color: ZapColors.warning, fontSize: 11),
            ),
          ),
          const SizedBox(height: ZapSpacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _kAccent.withOpacity(0.2),
                  _kAccent.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kAccent.withOpacity(0.35)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _kAccent.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.family_restroom_rounded,
                    color: _kAccent,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Mehta Family',
                        style: TextStyle(
                          color: ZapColors.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Admin view · ${members.length} linked members'
                        '${lastRefresh != null ? ' · refreshed ${_formatRefresh(lastRefresh)}' : ''}',
                        style: const TextStyle(
                          color: ZapColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (loading)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Members',
                  value: '${members.length}',
                  icon: Icons.people_rounded,
                  color: _kAccent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  label: 'SOS active',
                  value: '$sosCount',
                  icon: Icons.emergency_rounded,
                  color: sosCount > 0 ? ZapColors.danger : ZapColors.safe,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Avg protection',
                  value: '$avgScore',
                  icon: Icons.shield_rounded,
                  color: _scoreColor(avgScore),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  label: 'Offline 24h+',
                  value: '$offlineCount',
                  icon: Icons.wifi_off_rounded,
                  color: offlineCount > 0
                      ? ZapColors.warning
                      : ZapColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.lg),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: const Text('All'),
                selected: filter == _MemberFilter.all,
                onSelected: (_) => ref
                    .read(_d253FilterProvider.notifier)
                    .state = _MemberFilter.all,
                selectedColor: _kAccent.withOpacity(0.25),
              ),
              FilterChip(
                label: const Text('SOS active'),
                selected: filter == _MemberFilter.sosActive,
                onSelected: (_) => ref
                    .read(_d253FilterProvider.notifier)
                    .state = _MemberFilter.sosActive,
                selectedColor: ZapColors.danger.withOpacity(0.2),
              ),
              FilterChip(
                label: const Text('Offline'),
                selected: filter == _MemberFilter.offline,
                onSelected: (_) => ref
                    .read(_d253FilterProvider.notifier)
                    .state = _MemberFilter.offline,
                selectedColor: ZapColors.warning.withOpacity(0.2),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          ...filtered.map(
            (m) => _MemberDashboardCard(
              member: m,
              onTap: () => onSelectMember(m.id),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatRefresh(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  return '${diff.inHours}h ago';
}

// ── Tab 1: Members ────────────────────────────────────────────────────────────
class _MembersTab extends ConsumerWidget {
  const _MembersTab({required this.onToggleSos});

  final ValueChanged<String> onToggleSos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(_d253MembersProvider);
    final selectedId = ref.watch(_d253SelectedIdProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text(
          'Linked members — admin drill controls',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          'Toggle SOS status to QA dashboard indicators (mock only).',
          style: TextStyle(color: ZapColors.textSecondary, fontSize: 11),
        ),
        const SizedBox(height: ZapSpacing.lg),
        ...members.map(
          (m) => _MemberDetailTile(
            member: m,
            expanded: selectedId == m.id,
            onTap: () {
              ref.read(_d253SelectedIdProvider.notifier).state =
                  selectedId == m.id ? null : m.id;
            },
            onToggleSos: () => onToggleSos(m.id),
          ),
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
    final members = ref.watch(_d253MembersProvider);
    final payload = _buildDashboardPayload(members);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text(
          'Family Alerts Dashboard',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          'Family admin role sees all linked profiles — last active time, live '
          'SOS badge, and protection score (0–100 composite from permissions, '
          'recent drills, and journey usage).',
          style: TextStyle(
            color: ZapColors.textSecondary,
            fontSize: 12,
            height: 1.45,
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'GET /api/v1/family/dashboard/',
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
              const SnackBar(content: Text('Family dashboard JSON copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy API response JSON'),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const _PolicyRow(
          icon: Icons.admin_panel_settings_rounded,
          title: 'Admin role only',
          subtitle:
              'Only family admins see SOS status for all members. Child '
              'profiles (Day 255) restrict cancel without PIN.',
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
              label: const Text('Day 255 Child Admin Lock'),
              onPressed: () => context.push(AppRoutes.childModeAdmin),
            ),
            ActionChip(
              label: const Text('Day 254 SOS History'),
              onPressed: () => context.push(AppRoutes.familySosHistory),
            ),
            ActionChip(
              label: const Text('Day 252 Group Panic'),
              onPressed: () => context.push(AppRoutes.groupJourneyPanic),
            ),
            ActionChip(
              label: const Text('Day 242 Trusted Circle'),
              onPressed: () => context.push(AppRoutes.trustedCircleV2),
            ),
            ActionChip(
              label: const Text('Day 241 Journey Mode'),
              onPressed: () => context.push(AppRoutes.journeyModeV2),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ZapColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 22,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: ZapColors.textMuted,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberDashboardCard extends StatelessWidget {
  const _MemberDashboardCard({
    required this.member,
    required this.onTap,
  });

  final _FamilyMember member;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: member.sosActive
            ? ZapColors.danger.withOpacity(0.06)
            : ZapColors.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: member.sosActive
              ? ZapColors.danger.withOpacity(0.45)
              : ZapColors.border,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Stack(
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
            if (member.sosActive)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: ZapColors.danger,
                    shape: BoxShape.circle,
                    border: Border.all(color: ZapColors.bgCard, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                member.name,
                style: const TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            if (member.sosActive)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: ZapColors.danger.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'SOS',
                  style: TextStyle(
                    color: ZapColors.danger,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          '${member.relation} · Last active ${member.lastSeen}',
          style: const TextStyle(color: ZapColors.textSecondary, fontSize: 11),
        ),
        trailing: _ProtectionScoreRing(score: member.protectionScore),
      ),
    );
  }
}

class _ProtectionScoreRing extends StatelessWidget {
  const _ProtectionScoreRing({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final color = _scoreColor(score);
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: score / 100,
            strokeWidth: 4,
            color: color,
            backgroundColor: color.withOpacity(0.15),
          ),
          Text(
            '$score',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberDetailTile extends StatelessWidget {
  const _MemberDetailTile({
    required this.member,
    required this.expanded,
    required this.onTap,
    required this.onToggleSos,
  });

  final _FamilyMember member;
  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback onToggleSos;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: expanded ? _kAccent.withOpacity(0.45) : ZapColors.border,
        ),
      ),
      child: Column(
        children: [
          ListTile(
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
              member.relation,
              style: const TextStyle(
                color: ZapColors.textSecondary,
                fontSize: 11,
              ),
            ),
            trailing: Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              color: ZapColors.textMuted,
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1, color: ZapColors.border),
            Padding(
              padding: const EdgeInsets.all(ZapSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailRow(label: 'Last seen', value: member.lastSeen),
                  _DetailRow(label: 'Device', value: member.device),
                  _DetailRow(
                    label: 'Protection score',
                    value: '${member.protectionScore} / 100',
                  ),
                  _DetailRow(
                    label: 'Journey active',
                    value: member.journeyActive ? 'Yes' : 'No',
                  ),
                  _DetailRow(
                    label: 'SOS active',
                    value: member.sosActive ? 'Yes — alert live' : 'No',
                    valueColor:
                        member.sosActive ? ZapColors.danger : ZapColors.safe,
                  ),
                  if (member.childProfile)
                    const _DetailRow(
                      label: 'Profile type',
                      value: 'Child (admin lock Day 255)',
                    ),
                  const SizedBox(height: ZapSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: onToggleSos,
                    icon: Icon(
                      member.sosActive
                          ? Icons.check_circle_outline
                          : Icons.emergency_rounded,
                    ),
                    label: Text(
                      member.sosActive
                          ? 'Clear SOS (mock)'
                          : 'Simulate SOS (mock)',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          member.sosActive ? ZapColors.safe : ZapColors.danger,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
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
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: ZapColors.textMuted,
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? ZapColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
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
