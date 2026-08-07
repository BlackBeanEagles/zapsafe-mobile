/// Day 252 — Group Journey — Group Panic
///
/// Section C (Days 241-260): one button alerts **all** group members'
/// emergency contacts simultaneously during an active group journey session.
///
/// Tag: 🟡 MOCK-NOW · parallel contact dispatch · hold-to-confirm panic.
///
/// Route: [AppRoutes.groupJourneyPanic] → `/group-journey-panic`
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const _kAccent = Color(0xFFDC2626);
const _kGroupAccent = Color(0xFF10B981);
const _kTabs = ['Panic', 'Dispatch', 'Info'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');
const _kMockSessionId = 'gj_252_group_demo';
const _kHoldDuration = Duration(seconds: 2);

const _kGroupMembers = [
  _GroupMember(
    id: 'you',
    name: 'You (Host)',
    shortName: 'You',
    isHost: true,
    color: _kGroupAccent,
    contacts: [
      _MemberContact(
        id: 'c_you_1',
        name: 'Sunita Mehta',
        phone: '+91 98100 11223',
        tier: 'Tier 1',
        relation: 'Mother',
      ),
      _MemberContact(
        id: 'c_you_2',
        name: 'Rahul Mehta',
        phone: '+91 98765 43210',
        tier: 'Tier 1',
        relation: 'Brother',
      ),
    ],
  ),
  _GroupMember(
    id: 'rahul',
    name: 'Rahul Mehta',
    shortName: 'Rahul',
    color: Color(0xFF3B82F6),
    contacts: [
      _MemberContact(
        id: 'c_rahul_1',
        name: 'Aarti Sharma',
        phone: '+91 91234 56789',
        tier: 'Tier 1',
        relation: 'Partner',
      ),
      _MemberContact(
        id: 'c_rahul_2',
        name: 'Priya Nair',
        phone: '+91 97654 32109',
        tier: 'Tier 2',
        relation: 'Friend',
      ),
    ],
  ),
  _GroupMember(
    id: 'aarti',
    name: 'Aarti Sharma',
    shortName: 'Aarti',
    color: Color(0xFF8B5CF6),
    contacts: [
      _MemberContact(
        id: 'c_aarti_1',
        name: 'Rahul Mehta',
        phone: '+91 98765 43210',
        tier: 'Tier 1',
        relation: 'Partner',
      ),
      _MemberContact(
        id: 'c_aarti_2',
        name: 'Vikram Patel',
        phone: '+91 99887 76655',
        tier: 'Tier 2',
        relation: 'Colleague',
      ),
    ],
  ),
  _GroupMember(
    id: 'sanjay',
    name: 'Sanjay Kulkarni',
    shortName: 'Sanjay',
    color: Color(0xFFF97316),
    contacts: [
      _MemberContact(
        id: 'c_sanjay_1',
        name: 'Meera Joshi',
        phone: '+91 88776 65544',
        tier: 'Tier 1',
        relation: 'Cousin',
      ),
      _MemberContact(
        id: 'c_sanjay_2',
        name: 'Rajesh Kulkarni',
        phone: '+91 90000 12345',
        tier: 'Tier 1',
        relation: 'Father',
      ),
    ],
  ),
  _GroupMember(
    id: 'vikram',
    name: 'Vikram Patel',
    shortName: 'Vikram',
    color: Color(0xFFEC4899),
    contacts: [
      _MemberContact(
        id: 'c_vikram_1',
        name: 'Ananya Desai',
        phone: '+91 93456 78901',
        tier: 'Tier 1',
        relation: 'Sister',
      ),
      _MemberContact(
        id: 'c_vikram_2',
        name: 'Office Security',
        phone: '+91 022 4000 9999',
        tier: 'Tier 2',
        relation: 'Workplace',
      ),
    ],
  ),
];

enum _PanicPhase { idle, holding, dispatching, complete }

enum _DispatchStep { pending, sending, delivered, failed }

// ── Models ────────────────────────────────────────────────────────────────────
class _MemberContact {
  const _MemberContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.tier,
    required this.relation,
  });

  final String id;
  final String name;
  final String phone;
  final String tier;
  final String relation;

  bool get isTier1 => tier == 'Tier 1';

  Map<String, dynamic> toJson(String memberId, String memberName) => {
        'contact_id': id,
        'member_id': memberId,
        'member_name': memberName,
        'name': name,
        'phone': phone,
        'tier': tier,
      };
}

class _GroupMember {
  const _GroupMember({
    required this.id,
    required this.name,
    required this.shortName,
    required this.color,
    required this.contacts,
    this.isHost = false,
  });

  final String id;
  final String name;
  final String shortName;
  final Color color;
  final List<_MemberContact> contacts;
  final bool isHost;
}

class _DispatchRow {
  _DispatchRow({
    required this.member,
    required this.contact,
  })  : step = _DispatchStep.pending,
        notifiedAt = null;

  final _GroupMember member;
  final _MemberContact contact;
  _DispatchStep step;
  DateTime? notifiedAt;

  String get key => '${member.id}:${contact.id}';

  Map<String, dynamic> toJson() => {
        ...contact.toJson(member.id, member.name),
        'status': step.name,
        'notified_at': notifiedAt?.toIso8601String(),
      };
}

// ── Providers ─────────────────────────────────────────────────────────────────
final _d252TabProvider = StateProvider<int>((ref) => 0);
final _d252SessionActiveProvider = StateProvider<bool>((ref) => true);
final _d252PhaseProvider = StateProvider<_PanicPhase>((ref) => _PanicPhase.idle);
final _d252HoldProgressProvider = StateProvider<double>((ref) => 0);
final _d252DispatchRowsProvider =
    StateProvider<List<_DispatchRow>>((ref) => _buildDispatchRows());
final _d252PanicIdProvider = StateProvider<String?>((ref) => null);
final _d252TriggeredAtProvider = StateProvider<DateTime?>((ref) => null);

List<_DispatchRow> _buildDispatchRows() {
  final rows = <_DispatchRow>[];
  for (final member in _kGroupMembers) {
    for (final contact in member.contacts) {
      rows.add(_DispatchRow(member: member, contact: contact));
    }
  }
  return rows;
}

int _totalContactCount() {
  return _kGroupMembers.fold<int>(0, (sum, m) => sum + m.contacts.length);
}

List<Map<String, dynamic>> _allContactsPayload() {
  return _buildDispatchRows()
      .map((r) => r.contact.toJson(r.member.id, r.member.name))
      .toList();
}

// ── Screen ────────────────────────────────────────────────────────────────────
class Day252GroupPanicScreen extends ConsumerStatefulWidget {
  const Day252GroupPanicScreen({super.key});

  @override
  ConsumerState<Day252GroupPanicScreen> createState() =>
      _Day252GroupPanicScreenState();
}

class _Day252GroupPanicScreenState extends ConsumerState<Day252GroupPanicScreen> {
  Timer? _holdTimer;
  Timer? _dispatchTimer;
  int _dispatchIndex = 0;

  @override
  void dispose() {
    _holdTimer?.cancel();
    _dispatchTimer?.cancel();
    super.dispose();
  }

  void _startHold() {
    if (!ref.read(_d252SessionActiveProvider)) return;
    if (ref.read(_d252PhaseProvider) != _PanicPhase.idle) return;

    ref.read(_d252PhaseProvider.notifier).state = _PanicPhase.holding;
    ref.read(_d252HoldProgressProvider.notifier).state = 0;
    HapticFeedback.lightImpact();

    final started = DateTime.now();
    _holdTimer?.cancel();
    _holdTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted) return;
      final elapsed = DateTime.now().difference(started);
      final progress =
          (elapsed.inMilliseconds / _kHoldDuration.inMilliseconds).clamp(0.0, 1.0);
      ref.read(_d252HoldProgressProvider.notifier).state = progress;
      if (progress >= 1.0) {
        _holdTimer?.cancel();
        _triggerGroupPanic();
      }
    });
  }

  void _cancelHold() {
    _holdTimer?.cancel();
    if (ref.read(_d252PhaseProvider) == _PanicPhase.holding) {
      ref.read(_d252PhaseProvider.notifier).state = _PanicPhase.idle;
      ref.read(_d252HoldProgressProvider.notifier).state = 0;
    }
  }

  Future<void> _triggerGroupPanic() async {
    ref.read(_d252PhaseProvider.notifier).state = _PanicPhase.dispatching;
    ref.read(_d252HoldProgressProvider.notifier).state = 1;
    ref.read(_d252TriggeredAtProvider.notifier).state = DateTime.now();
    ref.read(_d252PanicIdProvider.notifier).state =
        'gp_${DateTime.now().millisecondsSinceEpoch ~/ 1000}';
    ref.read(_d252TabProvider.notifier).state = 1;

    final rows = _buildDispatchRows();
    ref.read(_d252DispatchRowsProvider.notifier).state = rows;
    _dispatchIndex = 0;

    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Group panic triggered · notifying ${_totalContactCount()} contacts',
        ),
      ),
    );

    _dispatchTimer?.cancel();
    _dispatchTimer = Timer.periodic(const Duration(milliseconds: 350), (_) {
      if (!mounted) return;
      final current = List<_DispatchRow>.from(ref.read(_d252DispatchRowsProvider));
      if (_dispatchIndex >= current.length) {
        _dispatchTimer?.cancel();
        ref.read(_d252PhaseProvider.notifier).state = _PanicPhase.complete;
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All member emergency contacts notified (mock).'),
          ),
        );
        return;
      }

      current[_dispatchIndex].step = _DispatchStep.sending;
      ref.read(_d252DispatchRowsProvider.notifier).state = List.from(current);

      final idx = _dispatchIndex;
      Future<void>.delayed(const Duration(milliseconds: 220), () {
        if (!mounted) return;
        final updated = List<_DispatchRow>.from(ref.read(_d252DispatchRowsProvider));
        if (idx >= updated.length) return;
        updated[idx].step = _DispatchStep.delivered;
        updated[idx].notifiedAt = DateTime.now();
        ref.read(_d252DispatchRowsProvider.notifier).state = updated;
      });

      _dispatchIndex++;
    });
  }

  void _resetPanic() {
    _holdTimer?.cancel();
    _dispatchTimer?.cancel();
    ref.read(_d252PhaseProvider.notifier).state = _PanicPhase.idle;
    ref.read(_d252HoldProgressProvider.notifier).state = 0;
    ref.read(_d252DispatchRowsProvider.notifier).state = _buildDispatchRows();
    ref.read(_d252PanicIdProvider.notifier).state = null;
    ref.read(_d252TriggeredAtProvider.notifier).state = null;
    _dispatchIndex = 0;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Group panic reset (mock drill).')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(_d252TabProvider);
    final phase = ref.watch(_d252PhaseProvider);
    final sessionActive = ref.watch(_d252SessionActiveProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 252 · Group Panic'),
        actions: [
          if (phase == _PanicPhase.dispatching || phase == _PanicPhase.complete)
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
                    'PANIC',
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
          if (phase == _PanicPhase.dispatching || phase == _PanicPhase.complete)
            _ActivePanicBanner(phase: phase),
          _TabBar(
            tab: tab,
            onSelect: (i) => ref.read(_d252TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (tab) {
              0 => _PanicTab(
                  sessionActive: sessionActive,
                  phase: phase,
                  onHoldStart: _startHold,
                  onHoldEnd: _cancelHold,
                  onReset: _resetPanic,
                ),
              1 => _DispatchTab(onReset: _resetPanic),
              _ => const _InfoTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Banner ────────────────────────────────────────────────────────────────────
class _ActivePanicBanner extends ConsumerWidget {
  const _ActivePanicBanner({required this.phase});

  final _PanicPhase phase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(_d252DispatchRowsProvider);
    final delivered =
        rows.where((r) => r.step == _DispatchStep.delivered).length;
    final total = rows.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: ZapSpacing.lg,
        vertical: ZapSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: _kAccent.withOpacity(0.15),
        border: Border(bottom: BorderSide(color: _kAccent.withOpacity(0.45))),
      ),
      child: Row(
        children: [
          Icon(
            phase == _PanicPhase.complete
                ? Icons.check_circle_rounded
                : Icons.emergency_rounded,
            color: _kAccent,
            size: 20,
          ),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Text(
              phase == _PanicPhase.complete
                  ? 'Group panic complete · $delivered / $total contacts notified'
                  : 'Dispatching group panic · $delivered / $total contacts…',
              style: const TextStyle(
                color: _kAccent,
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

// ── Tab 0: Panic ──────────────────────────────────────────────────────────────
class _PanicTab extends ConsumerWidget {
  const _PanicTab({
    required this.sessionActive,
    required this.phase,
    required this.onHoldStart,
    required this.onHoldEnd,
    required this.onReset,
  });

  final bool sessionActive;
  final _PanicPhase phase;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final holdProgress = ref.watch(_d252HoldProgressProvider);
    final totalContacts = _totalContactCount();
    final canTrigger = sessionActive &&
        (phase == _PanicPhase.idle || phase == _PanicPhase.holding);
    final isDone = phase == _PanicPhase.complete;

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
            '🟡 MOCK-NOW · Section C Day 12/20 · simultaneous multi-member SOS',
            style: TextStyle(color: ZapColors.warning, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: _kGroupAccent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kGroupAccent.withOpacity(0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sessionActive
                    ? 'Active group session · $_kMockSessionId'
                    : 'No active group session',
                style: const TextStyle(
                  color: _kGroupAccent,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: ZapSpacing.xs),
              Text(
                '${_kGroupMembers.length} members · $totalContacts emergency contacts '
                'will be notified at once',
                style: const TextStyle(
                  color: ZapColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Group members & contact count',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        ..._kGroupMembers.map(
          (m) => _MemberSummaryTile(member: m),
        ),
        const SizedBox(height: ZapSpacing.xl),
        Center(
          child: GestureDetector(
            onLongPressStart: canTrigger ? (_) => onHoldStart() : null,
            onLongPressEnd: canTrigger ? (_) => onHoldEnd() : null,
            onLongPressCancel: onHoldEnd,
            child: SizedBox(
              width: 220,
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 220,
                    height: 220,
                    child: CircularProgressIndicator(
                      value: phase == _PanicPhase.holding ? holdProgress : 0,
                      strokeWidth: 8,
                      color: _kAccent,
                      backgroundColor: _kAccent.withOpacity(0.12),
                    ),
                  ),
                  Container(
                    width: 190,
                    height: 190,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: canTrigger
                          ? _kAccent
                          : _kAccent.withOpacity(0.35),
                      boxShadow: [
                        BoxShadow(
                          color: _kAccent.withOpacity(0.35),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isDone ? Icons.check_rounded : Icons.emergency_rounded,
                          color: Colors.white,
                          size: 48,
                        ),
                        const SizedBox(height: ZapSpacing.sm),
                        Text(
                          isDone
                              ? 'DISPATCHED'
                              : phase == _PanicPhase.holding
                                  ? 'HOLD…'
                                  : 'GROUP\nPANIC',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Text(
          isDone
              ? 'All member emergency contacts were notified simultaneously.'
              : sessionActive
                  ? 'Hold the button for 2 seconds to trigger group panic.'
                  : 'Start a group journey on Day 250/251 first (mock session enabled here).',
          textAlign: TextAlign.center,
          style: const TextStyle(color: ZapColors.textSecondary, fontSize: 12),
        ),
        if (isDone) ...[
          const SizedBox(height: ZapSpacing.lg),
          OutlinedButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reset drill'),
          ),
          FilledButton.icon(
            onPressed: () => ref.read(_d252TabProvider.notifier).state = 1,
            icon: const Icon(Icons.list_alt_rounded),
            label: const Text('View dispatch log'),
            style: FilledButton.styleFrom(
              backgroundColor: _kAccent,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ] else ...[
          const SizedBox(height: ZapSpacing.lg),
          OutlinedButton.icon(
            onPressed: () => context.push(AppRoutes.groupJourneyLiveMap),
            icon: const Icon(Icons.map_rounded),
            label: const Text('Day 251 · Live map'),
          ),
        ],
      ],
    );
  }
}

// ── Tab 1: Dispatch ───────────────────────────────────────────────────────────
class _DispatchTab extends ConsumerWidget {
  const _DispatchTab({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = ref.watch(_d252PhaseProvider);
    final rows = ref.watch(_d252DispatchRowsProvider);
    final panicId = ref.watch(_d252PanicIdProvider);
    final triggered = ref.watch(_d252TriggeredAtProvider);

    if (phase == _PanicPhase.idle) {
      return ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          const Text(
            'Dispatch log appears after group panic is triggered.',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: ZapSpacing.lg),
          OutlinedButton.icon(
            onPressed: () => ref.read(_d252TabProvider.notifier).state = 0,
            icon: const Icon(Icons.emergency_rounded),
            label: const Text('Go to Panic tab'),
          ),
        ],
      );
    }

    final delivered =
        rows.where((r) => r.step == _DispatchStep.delivered).length;

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        if (panicId != null)
          Container(
            width: double.infinity,
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
                  panicId,
                  style: const TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: ZapSpacing.xs),
                Text(
                  'Triggered ${triggered?.toIso8601String() ?? '—'} · '
                  '$delivered / ${rows.length} delivered',
                  style: const TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: ZapSpacing.lg),
        ...rows.map((row) => _DispatchRowTile(row: row)),
        if (phase == _PanicPhase.complete) ...[
          const SizedBox(height: ZapSpacing.lg),
          OutlinedButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reset drill'),
          ),
        ],
      ],
    );
  }
}

// ── Tab 2: Info ───────────────────────────────────────────────────────────────
class _InfoTab extends ConsumerWidget {
  const _InfoTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = ref.watch(_d252PhaseProvider);
    final panicId = ref.watch(_d252PanicIdProvider);

    final request = {
      'session_id': _kMockSessionId,
      'triggered_by': 'you',
      'notify_all_member_contacts': true,
      'contacts': _allContactsPayload(),
    };

    final response = {
      'panic_id': panicId ?? 'gp_789012',
      'status': phase == _PanicPhase.complete ? 'completed' : 'accepted',
      'contacts_notified': phase == _PanicPhase.complete
          ? _totalContactCount()
          : 0,
      'members': _kGroupMembers
          .map(
            (m) => {
              'member_id': m.id,
              'name': m.name,
              'contact_count': m.contacts.length,
            },
          )
          .toList(),
    };

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text(
          'Group Journey — group panic',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          'Host or any member can trigger a group-wide panic. One action fans out '
          'to every emergency contact linked to every member in the session — '
          'parallel dispatch, not sequential per member.',
          style: TextStyle(
            color: ZapColors.textSecondary,
            fontSize: 12,
            height: 1.45,
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'POST /api/v1/journey/group/panic/',
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
          'Response 202',
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
              const SnackBar(content: Text('Group panic API JSON copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy API contract JSON'),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const _PolicyRow(
          icon: Icons.policy_rounded,
          title: 'Escalation policy',
          subtitle:
              'Uses Tier 1 / Tier 2 routing from Day 86 — all tiers notified '
              'in group panic (no delay between members).',
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
              label: const Text('Day 254 SOS History'),
              onPressed: () => context.push(AppRoutes.familySosHistory),
            ),
            ActionChip(
              label: const Text('Day 253 Family Dashboard'),
              onPressed: () => context.push(AppRoutes.familyAlertsDashboard),
            ),
            ActionChip(
              label: const Text('Day 251 Live Map'),
              onPressed: () => context.push(AppRoutes.groupJourneyLiveMap),
            ),
            ActionChip(
              label: const Text('Day 250 Group Create'),
              onPressed: () => context.push(AppRoutes.groupJourneyCreate),
            ),
            ActionChip(
              label: const Text('Day 86 Escalation'),
              onPressed: () => context.push(AppRoutes.escalationPoliciesV2),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────
class _MemberSummaryTile extends StatelessWidget {
  const _MemberSummaryTile({required this.member});

  final _GroupMember member;

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
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: member.color.withOpacity(0.2),
            child: Text(
              member.shortName[0],
              style: TextStyle(
                color: member.color,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: ZapSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  style: const TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  member.contacts.map((c) => c.name).join(' · '),
                  style: const TextStyle(
                    color: ZapColors.textMuted,
                    fontSize: 10,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _kAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${member.contacts.length}',
              style: const TextStyle(
                color: _kAccent,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DispatchRowTile extends StatelessWidget {
  const _DispatchRowTile({required this.row});

  final _DispatchRow row;

  @override
  Widget build(BuildContext context) {
    final step = row.step;
    final color = switch (step) {
      _DispatchStep.delivered => ZapColors.safe,
      _DispatchStep.sending => ZapColors.warning,
      _DispatchStep.failed => ZapColors.danger,
      _ => ZapColors.textMuted,
    };
    final icon = switch (step) {
      _DispatchStep.delivered => Icons.check_circle_rounded,
      _DispatchStep.sending => Icons.sync_rounded,
      _DispatchStep.failed => Icons.error_outline_rounded,
      _ => Icons.schedule_rounded,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: step == _DispatchStep.delivered
              ? ZapColors.safe.withOpacity(0.35)
              : ZapColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.contact.name,
                  style: const TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '${row.member.shortName} · ${row.contact.tier} · '
                  '${row.contact.phone}',
                  style: const TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Text(
            step.name,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
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
