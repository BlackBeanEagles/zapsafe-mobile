/// Day 250 — Group Journey — Create Session
///
/// Section C (Days 241-260): start a multi-user journey — shared destination,
/// ETA (15 min–8 hr), invite up to 5 friends; mock POST create API with
/// session_id + invite_links.
///
/// Tag: 🟡 MOCK-NOW · `flutter_map` destination picker · group invite links.
///
/// Route: [AppRoutes.groupJourneyCreate] → `/group-journey-create`
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const _kAccent = Color(0xFF10B981);
const _kOrigin = LatLng(19.0760, 72.8777);
const _kTabs = ['Create', 'Members', 'Info'];
const _kMaxMembers = 5;
const _kJsonEncoder = JsonEncoder.withIndent('  ');

const _kDurationOptions = [15, 30, 60, 120, 240, 480];

const _kMockDestinations = [
  _GroupDestination(
    id: 'bandra',
    label: 'Bandra West',
    subtitle: 'Linking Road, Mumbai',
    latLng: LatLng(19.0596, 72.8295),
  ),
  _GroupDestination(
    id: 'andheri',
    label: 'Andheri East',
    subtitle: 'Metro station, Mumbai',
    latLng: LatLng(19.1136, 72.8697),
  ),
  _GroupDestination(
    id: 'pune',
    label: 'Pune Junction',
    subtitle: 'Railway station, Pune',
    latLng: LatLng(18.5314, 73.8740),
  ),
  _GroupDestination(
    id: 'navi',
    label: 'Vashi',
    subtitle: 'Navi Mumbai',
    latLng: LatLng(19.0770, 73.0120),
  ),
  _GroupDestination(
    id: 'airport',
    label: 'CSMIA Terminal 2',
    subtitle: 'Mumbai International Airport',
    latLng: LatLng(19.0997, 72.8750),
  ),
];

const _kGroupFriends = [
  _GroupFriend(
    id: 'a1b2c3d4-e001-0001-0000-000000000001',
    name: 'Rahul Mehta',
    phone: '+91 98765 43210',
    relation: 'Brother',
    online: true,
  ),
  _GroupFriend(
    id: 'a1b2c3d4-e002-0002-0000-000000000002',
    name: 'Aarti Sharma',
    phone: '+91 91234 56789',
    relation: 'Best friend',
    online: true,
  ),
  _GroupFriend(
    id: 'a1b2c3d4-e003-0003-0000-000000000003',
    name: 'Priya Nair',
    phone: '+91 97654 32109',
    relation: 'Roommate',
    online: false,
  ),
  _GroupFriend(
    id: 'a1b2c3d4-e004-0004-0000-000000000004',
    name: 'Vikram Patel',
    phone: '+91 99887 76655',
    relation: 'Colleague',
    online: false,
  ),
  _GroupFriend(
    id: 'a1b2c3d4-e005-0005-0000-000000000005',
    name: 'Sanjay Kulkarni',
    phone: '+91 90123 45678',
    relation: 'Neighbour',
    online: true,
  ),
  _GroupFriend(
    id: 'a1b2c3d4-e006-0006-0000-000000000006',
    name: 'Meera Joshi',
    phone: '+91 88776 65544',
    relation: 'Cousin',
    online: false,
  ),
  _GroupFriend(
    id: 'a1b2c3d4-e007-0007-0000-000000000007',
    name: 'Ananya Desai',
    phone: '+91 93456 78901',
    relation: 'College friend',
    online: true,
  ),
];

// ── Models ────────────────────────────────────────────────────────────────────
class _GroupDestination {
  const _GroupDestination({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.latLng,
  });

  final String id;
  final String label;
  final String subtitle;
  final LatLng latLng;

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'subtitle': subtitle,
        'lat': latLng.latitude,
        'lng': latLng.longitude,
      };
}

class _GroupFriend {
  const _GroupFriend({
    required this.id,
    required this.name,
    required this.phone,
    required this.relation,
    required this.online,
  });

  final String id;
  final String name;
  final String phone;
  final String relation;
  final bool online;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'relation': relation,
        'online': online,
      };
}

class _GroupInviteLink {
  const _GroupInviteLink({
    required this.memberId,
    required this.memberName,
    required this.link,
  });

  final String memberId;
  final String memberName;
  final String link;

  Map<String, dynamic> toJson() => {
        'member_id': memberId,
        'member_name': memberName,
        'link': link,
      };
}

class _GroupSessionResult {
  const _GroupSessionResult({
    required this.sessionId,
    required this.createdAt,
    required this.etaMinutes,
    required this.destination,
    required this.inviteLinks,
  });

  final String sessionId;
  final DateTime createdAt;
  final int etaMinutes;
  final _GroupDestination destination;
  final List<_GroupInviteLink> inviteLinks;

  Map<String, dynamic> toResponseJson() => {
        'session_id': sessionId,
        'created_at': createdAt.toIso8601String(),
        'eta_minutes': etaMinutes,
        'destination': destination.toJson(),
        'invite_links': inviteLinks.map((l) => l.toJson()).toList(),
      };
}

// ── Providers ─────────────────────────────────────────────────────────────────
final _d250TabProvider = StateProvider<int>((ref) => 0);
final _d250SearchProvider = StateProvider<String>((ref) => '');
final _d250DestinationProvider =
    StateProvider<_GroupDestination?>((ref) => null);
final _d250DurationMinutesProvider = StateProvider<int>((ref) => 60);
final _d250SelectedMembersProvider =
    StateProvider<Set<String>>((ref) => {'a1b2c3d4-e001-0001-0000-000000000001', 'a1b2c3d4-e002-0002-0000-000000000002'});
final _d250CreatingProvider = StateProvider<bool>((ref) => false);
final _d250SessionResultProvider =
    StateProvider<_GroupSessionResult?>((ref) => null);

// ── Helpers ───────────────────────────────────────────────────────────────────
String _formatDurationLabel(int minutes) {
  if (minutes >= 60) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }
  return '${minutes}m';
}

_GroupFriend? _friendById(String id) {
  for (final f in _kGroupFriends) {
    if (f.id == id) return f;
  }
  return null;
}

List<_GroupFriend> _friendsByIds(Set<String> ids) {
  return _kGroupFriends.where((f) => ids.contains(f.id)).toList();
}

Future<_GroupSessionResult> _mockCreateGroupSession({
  required _GroupDestination destination,
  required List<String> memberIds,
  required int etaMinutes,
}) async {
  await Future<void>.delayed(const Duration(milliseconds: 1600));
  final sessionId =
      'gj_${DateTime.now().millisecondsSinceEpoch ~/ 1000}';
  final links = memberIds.map((id) {
    final friend = _friendById(id);
    final token = id.replaceAll('-', '').substring(0, 8);
    return _GroupInviteLink(
      memberId: id,
      memberName: friend?.name ?? 'Member',
      link: 'https://zapsafe.app/join/$sessionId?member=$token',
    );
  }).toList();
  return _GroupSessionResult(
    sessionId: sessionId,
    createdAt: DateTime.now(),
    etaMinutes: etaMinutes,
    destination: destination,
    inviteLinks: links,
  );
}

Map<String, dynamic> _buildRequestPayload(
  _GroupDestination? destination,
  Set<String> memberIds,
) {
  return {
    'destination_lat': destination?.latLng.latitude ?? 0,
    'destination_lng': destination?.latLng.longitude ?? 0,
    'member_ids': memberIds.toList(),
  };
}

// ── Screen ────────────────────────────────────────────────────────────────────
class Day250GroupJourneyCreateScreen extends ConsumerStatefulWidget {
  const Day250GroupJourneyCreateScreen({super.key});

  @override
  ConsumerState<Day250GroupJourneyCreateScreen> createState() =>
      _Day250GroupJourneyCreateScreenState();
}

class _Day250GroupJourneyCreateScreenState
    extends ConsumerState<Day250GroupJourneyCreateScreen> {
  final _mapController = MapController();
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      ref.read(_d250SearchProvider.notifier).state = _searchCtrl.text;
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _createSession() async {
    final destination = ref.read(_d250DestinationProvider);
    final members = ref.read(_d250SelectedMembersProvider);
    final duration = ref.read(_d250DurationMinutesProvider);
    final existing = ref.read(_d250SessionResultProvider);

    if (existing != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session already created — end it to start a new one.'),
        ),
      );
      ref.read(_d250TabProvider.notifier).state = 1;
      return;
    }

    if (destination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a shared destination first.')),
      );
      return;
    }

    if (members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invite at least one friend (Members tab).')),
      );
      ref.read(_d250TabProvider.notifier).state = 1;
      return;
    }

    ref.read(_d250CreatingProvider.notifier).state = true;
    try {
      final result = await _mockCreateGroupSession(
        destination: destination,
        memberIds: members.toList(),
        etaMinutes: duration,
      );
      if (!mounted) return;
      ref.read(_d250SessionResultProvider.notifier).state = result;
      ref.read(_d250TabProvider.notifier).state = 1;
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Group journey created · ${result.sessionId} · '
            '${result.inviteLinks.length} invite links',
          ),
        ),
      );
    } finally {
      if (mounted) {
        ref.read(_d250CreatingProvider.notifier).state = false;
      }
    }
  }

  void _endSession() {
    ref.read(_d250SessionResultProvider.notifier).state = null;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Group journey session ended (mock).')),
    );
  }

  void _toggleMember(String id) {
    if (ref.read(_d250SessionResultProvider) != null) return;
    final current = Set<String>.from(ref.read(_d250SelectedMembersProvider));
    if (current.contains(id)) {
      current.remove(id);
    } else {
      if (current.length >= _kMaxMembers) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Maximum 5 friends per group journey.'),
          ),
        );
        return;
      }
      current.add(id);
    }
    ref.read(_d250SelectedMembersProvider.notifier).state = current;
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(_d250TabProvider);
    final session = ref.watch(_d250SessionResultProvider);
    final creating = ref.watch(_d250CreatingProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 250 · Group Journey'),
        actions: [
          if (session != null)
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
                    'ACTIVE',
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
          _TabBar(
            tab: tab,
            onSelect: (i) => ref.read(_d250TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (tab) {
              0 => _CreateTab(
                  mapController: _mapController,
                  searchCtrl: _searchCtrl,
                  creating: creating,
                  onCreate: _createSession,
                  onOpenMembers: () =>
                      ref.read(_d250TabProvider.notifier).state = 1,
                ),
              1 => _MembersTab(
                  onToggle: _toggleMember,
                  onEndSession: _endSession,
                ),
              _ => const _InfoTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Create ─────────────────────────────────────────────────────────────
class _CreateTab extends ConsumerWidget {
  const _CreateTab({
    required this.mapController,
    required this.searchCtrl,
    required this.creating,
    required this.onCreate,
    required this.onOpenMembers,
  });

  final MapController mapController;
  final TextEditingController searchCtrl;
  final bool creating;
  final VoidCallback onCreate;
  final VoidCallback onOpenMembers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(_d250SearchProvider).toLowerCase();
    final destination = ref.watch(_d250DestinationProvider);
    final duration = ref.watch(_d250DurationMinutesProvider);
    final members = ref.watch(_d250SelectedMembersProvider);
    final session = ref.watch(_d250SessionResultProvider);

    final filtered = _kMockDestinations.where((d) {
      if (query.isEmpty) return true;
      return d.label.toLowerCase().contains(query) ||
          d.subtitle.toLowerCase().contains(query);
    }).toList();

    final canCreate = destination != null &&
        members.isNotEmpty &&
        session == null &&
        !creating;

    final etaAt = DateTime.now().add(Duration(minutes: duration));

    return Column(
      children: [
        Expanded(
          flex: 5,
          child: _GroupMap(
            mapController: mapController,
            destination: destination?.latLng,
          ),
        ),
        Expanded(
          flex: 6,
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(top: BorderSide(color: ZapColors.border)),
            ),
            child: ListView(
              padding: const EdgeInsets.all(ZapSpacing.lg),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: ZapSpacing.md),
                    decoration: BoxDecoration(
                      color: ZapColors.textMuted.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: ZapColors.warning.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: ZapColors.warning.withOpacity(0.35),
                    ),
                  ),
                  child: const Text(
                    '🟡 MOCK-NOW · Section C Day 10/20 · up to 5 friends · shared ETA',
                    style: TextStyle(color: ZapColors.warning, fontSize: 11),
                  ),
                ),
                const SizedBox(height: ZapSpacing.lg),
                const Text(
                  'Shared destination',
                  style: TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: ZapSpacing.sm),
                TextField(
                  controller: searchCtrl,
                  enabled: session == null,
                  style: const TextStyle(color: ZapColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Bandra, Pune, airport…',
                    hintStyle: const TextStyle(color: ZapColors.textMuted),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: ZapColors.textMuted,
                    ),
                    filled: true,
                    fillColor: ZapColors.bgPrimary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: ZapColors.border),
                    ),
                  ),
                ),
                const SizedBox(height: ZapSpacing.sm),
                ...filtered.map(
                  (d) => _DestinationTile(
                    destination: d,
                    selected: destination?.id == d.id,
                    enabled: session == null,
                    onTap: () {
                      ref.read(_d250DestinationProvider.notifier).state = d;
                      mapController.move(d.latLng, 12);
                    },
                  ),
                ),
                const SizedBox(height: ZapSpacing.lg),
                const Text(
                  'Group ETA (max session window)',
                  style: TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: ZapSpacing.sm),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _kDurationOptions.map((m) {
                    final selected = duration == m;
                    return ChoiceChip(
                      label: Text(_formatDurationLabel(m)),
                      selected: selected,
                      onSelected: session == null
                          ? (_) => ref
                              .read(_d250DurationMinutesProvider.notifier)
                              .state = m
                          : null,
                      selectedColor: _kAccent.withOpacity(0.25),
                      labelStyle: TextStyle(
                        color: selected ? _kAccent : ZapColors.textSecondary,
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w500,
                        fontSize: 12,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: ZapSpacing.sm),
                Text(
                  'Expected arrival by ${TimeOfDay.fromDateTime(etaAt).format(context)} '
                  '(${_formatDurationLabel(duration)} window)',
                  style: const TextStyle(
                    color: ZapColors.textMuted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: ZapSpacing.lg),
                InkWell(
                  onTap: onOpenMembers,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(ZapSpacing.md),
                    decoration: BoxDecoration(
                      color: ZapColors.bgPrimary,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: ZapColors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.group_rounded,
                          color: members.isEmpty
                              ? ZapColors.textMuted
                              : _kAccent,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${members.length} / $_kMaxMembers friends invited',
                                style: const TextStyle(
                                  color: ZapColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                members.isEmpty
                                    ? 'Tap to select friends on Members tab'
                                    : _friendsByIds(members)
                                        .map((f) => f.name.split(' ').first)
                                        .join(', '),
                                style: const TextStyle(
                                  color: ZapColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: ZapColors.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: ZapSpacing.lg),
                FilledButton.icon(
                  onPressed: canCreate ? onCreate : null,
                  icon: creating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.group_add_rounded),
                  label: Text(
                    session != null
                        ? 'Session active — see Members tab'
                        : creating
                            ? 'Creating session…'
                            : 'Create group journey',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _kAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Tab 1: Members ────────────────────────────────────────────────────────────
class _MembersTab extends ConsumerWidget {
  const _MembersTab({
    required this.onToggle,
    required this.onEndSession,
  });

  final ValueChanged<String> onToggle;
  final VoidCallback onEndSession;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(_d250SelectedMembersProvider);
    final session = ref.watch(_d250SessionResultProvider);
    final locked = session != null;

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        if (session != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: _kAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kAccent.withOpacity(0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Session created',
                  style: TextStyle(
                    color: _kAccent,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                SelectableText(
                  session.sessionId,
                  style: const TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${session.destination.label} · '
                  'ETA ${_formatDurationLabel(session.etaMinutes)} · '
                  '${session.inviteLinks.length} invites',
                  style: const TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: ZapSpacing.md),
                OutlinedButton.icon(
                  onPressed: onEndSession,
                  icon: const Icon(Icons.stop_circle_outlined, size: 18),
                  label: const Text('End group session'),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.lg),
          const Text(
            'Invite links (mock)',
            style: TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          ...session.inviteLinks.map(
            (link) => _InviteLinkTile(link: link),
          ),
          const SizedBox(height: ZapSpacing.lg),
          const Divider(color: ZapColors.border),
          const SizedBox(height: ZapSpacing.md),
        ],
        Row(
          children: [
            Expanded(
              child: Text(
                locked
                    ? 'Invited members'
                    : 'Select friends (max $_kMaxMembers)',
                style: const TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _kAccent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${selected.length} / $_kMaxMembers',
                style: const TextStyle(
                  color: _kAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.sm),
        ..._kGroupFriends.map(
          (friend) => _FriendTile(
            friend: friend,
            selected: selected.contains(friend.id),
            locked: locked && !selected.contains(friend.id),
            onToggle: () => onToggle(friend.id),
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
    final destination = ref.watch(_d250DestinationProvider);
    final members = ref.watch(_d250SelectedMembersProvider);
    final session = ref.watch(_d250SessionResultProvider);

    final request = _buildRequestPayload(destination, members);
    final response = session?.toResponseJson() ??
        {
          'session_id': 'gj_123',
          'invite_links': [
            {
              'member_id': 'uuid',
              'member_name': 'Friend',
              'link': 'https://zapsafe.app/join/gj_123?member=abc',
            },
          ],
        };

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text(
          'Group Journey — create session',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          'Multi-user journey with one shared destination and ETA. Host invites '
          'up to 5 friends; each receives a deep link to join the live map '
          '(Day 251).',
          style: TextStyle(
            color: ZapColors.textSecondary,
            fontSize: 12,
            height: 1.45,
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'POST /api/v1/journey/group/create/',
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
            _kJsonEncoder.convert(request),
            style: const TextStyle(
              color: ZapColors.textSecondary,
              fontSize: 10,
              fontFamily: 'monospace',
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        const Text(
          'Response 201',
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
            _kJsonEncoder.convert(response),
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
              ClipboardData(
                text: _kJsonEncoder.convert({
                  'request': request,
                  'response': response,
                }),
              ),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Group journey API JSON copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy API contract JSON'),
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
              label: const Text('Day 252 Group Panic'),
              onPressed: () => context.push(AppRoutes.groupJourneyPanic),
            ),
            ActionChip(
              label: const Text('Day 251 Live Map'),
              onPressed: () => context.push(AppRoutes.groupJourneyLiveMap),
            ),
            ActionChip(
              label: const Text('Day 241 Journey Mode'),
              onPressed: () => context.push(AppRoutes.journeyModeV2),
            ),
            ActionChip(
              label: const Text('Day 242 Trusted Circle'),
              onPressed: () => context.push(AppRoutes.trustedCircleV2),
            ),
            ActionChip(
              label: const Text('Day 249 Voice Assistants'),
              onPressed: () => context.push(AppRoutes.voiceAssistantSetup),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────
class _GroupMap extends StatelessWidget {
  const _GroupMap({
    required this.mapController,
    this.destination,
  });

  final MapController mapController;
  final LatLng? destination;

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[
      const Marker(
        point: _kOrigin,
        width: 36,
        height: 36,
        child: Icon(Icons.trip_origin, color: ZapColors.safe, size: 28),
      ),
    ];

    if (destination != null) {
      markers.add(
        Marker(
          point: destination!,
          width: 36,
          height: 36,
          child: const Icon(
            Icons.location_on_rounded,
            color: ZapColors.danger,
            size: 32,
          ),
        ),
      );
    }

    final polylines = <Polyline>[];
    if (destination != null) {
      polylines.add(
        Polyline(
          points: [_kOrigin, destination!],
          color: _kAccent.withOpacity(0.7),
          strokeWidth: 4,
        ),
      );
    }

    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: destination ?? _kOrigin,
        initialZoom: destination != null ? 11.5 : 12,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.zapsafe.mobile',
        ),
        if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
        MarkerLayer(markers: markers),
      ],
    );
  }
}

class _DestinationTile extends StatelessWidget {
  const _DestinationTile({
    required this.destination,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  final _GroupDestination destination;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      enabled: enabled,
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: selected ? _kAccent : ZapColors.textMuted,
        size: 20,
      ),
      title: Text(
        destination.label,
        style: TextStyle(
          color: enabled ? ZapColors.textPrimary : ZapColors.textMuted,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
          fontSize: 13,
        ),
      ),
      subtitle: Text(
        destination.subtitle,
        style: const TextStyle(color: ZapColors.textMuted, fontSize: 11),
      ),
      onTap: enabled ? onTap : null,
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({
    required this.friend,
    required this.selected,
    required this.locked,
    required this.onToggle,
  });

  final _GroupFriend friend;
  final bool selected;
  final bool locked;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: selected ? _kAccent.withOpacity(0.08) : ZapColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? _kAccent.withOpacity(0.4) : ZapColors.border,
        ),
      ),
      child: CheckboxListTile(
        value: selected,
        onChanged: locked ? null : (_) => onToggle(),
        activeColor: _kAccent,
        title: Row(
          children: [
            Expanded(
              child: Text(
                friend.name,
                style: const TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: friend.online ? ZapColors.safe : ZapColors.textMuted,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        subtitle: Text(
          '${friend.relation} · ${friend.phone}',
          style: const TextStyle(color: ZapColors.textSecondary, fontSize: 11),
        ),
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }
}

class _InviteLinkTile extends StatelessWidget {
  const _InviteLinkTile({required this.link});

  final _GroupInviteLink link;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
            link.memberName,
            style: const TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            link.link,
            style: const TextStyle(
              color: ZapColors.textSecondary,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: link.link));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Invite link copied for ${link.memberName}.')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 14),
            label: const Text('Copy link'),
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
