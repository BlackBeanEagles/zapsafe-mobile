/// Day 251 — Group Journey — Live Map
///
/// Section C (Days 241-260): multi-user live map — multiple member markers,
/// shared route polyline, mock location stream, deviation alert banner when
/// any member exceeds 500m off the group route.
///
/// Tag: 🟡 MOCK-NOW · `flutter_map` · group deviation banner.
///
/// Route: [AppRoutes.groupJourneyLiveMap] → `/group-journey-live-map`
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

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
const _kDestination = LatLng(19.0596, 72.8295);
const _kDestinationLabel = 'Bandra West';
const _kDeviationThresholdM = 500;
const _kTabs = ['Map', 'Members', 'Info'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');
const _kDistance = Distance();
const _kMockSessionId = 'gj_251_live_demo';

const _kMemberDefs = [
  _MemberDef(
    id: 'you',
    name: 'You (Host)',
    shortName: 'You',
    isHost: true,
    color: _kAccent,
    speed: 0.035,
  ),
  _MemberDef(
    id: 'rahul',
    name: 'Rahul Mehta',
    shortName: 'Rahul',
    color: Color(0xFF3B82F6),
    speed: 0.032,
  ),
  _MemberDef(
    id: 'aarti',
    name: 'Aarti Sharma',
    shortName: 'Aarti',
    color: Color(0xFF8B5CF6),
    speed: 0.038,
  ),
  _MemberDef(
    id: 'sanjay',
    name: 'Sanjay Kulkarni',
    shortName: 'Sanjay',
    color: Color(0xFFF97316),
    speed: 0.028,
  ),
  _MemberDef(
    id: 'vikram',
    name: 'Vikram Patel',
    shortName: 'Vikram',
    color: Color(0xFFEC4899),
    speed: 0.030,
  ),
];

// ── Models ────────────────────────────────────────────────────────────────────
class _MemberDef {
  const _MemberDef({
    required this.id,
    required this.name,
    required this.shortName,
    required this.color,
    required this.speed,
    this.isHost = false,
  });

  final String id;
  final String name;
  final String shortName;
  final Color color;
  final double speed;
  final bool isHost;
}

class _MemberLiveState {
  _MemberLiveState({
    required this.def,
    required this.progress,
    required this.position,
    required this.deviationMeters,
  }) : deviated = false;

  final _MemberDef def;
  double progress;
  LatLng position;
  double deviationMeters;
  bool deviated;

  Map<String, dynamic> toJson() => {
        'member_id': def.id,
        'name': def.name,
        'lat': position.latitude,
        'lng': position.longitude,
        'progress': (progress * 100).round(),
        'deviation_meters': deviationMeters.round(),
        'off_route': deviationMeters > _kDeviationThresholdM,
      };
}

// ── Providers ─────────────────────────────────────────────────────────────────
final _d251TabProvider = StateProvider<int>((ref) => 0);
final _d251SessionActiveProvider = StateProvider<bool>((ref) => false);
final _d251MembersProvider = StateProvider<List<_MemberLiveState>>((ref) => []);
final _d251SessionStartedAtProvider = StateProvider<DateTime?>((ref) => null);
final _d251HighlightedMemberProvider = StateProvider<String?>((ref) => null);

// ── Helpers ───────────────────────────────────────────────────────────────────
LatLng _lerpLatLng(LatLng a, LatLng b, double t) {
  return LatLng(
    a.latitude + (b.latitude - a.latitude) * t,
    a.longitude + (b.longitude - a.longitude) * t,
  );
}

double _projectT(LatLng point, LatLng start, LatLng end) {
  final dx = end.longitude - start.longitude;
  final dy = end.latitude - start.latitude;
  if (dx == 0 && dy == 0) return 0;
  final px = point.longitude - start.longitude;
  final py = point.latitude - start.latitude;
  return (px * dx + py * dy) /
      (dx * dx + dy * dy).clamp(0.000001, double.infinity);
}

double _deviationFromRoute(LatLng point, LatLng start, LatLng end) {
  final routeLen = _kDistance.as(LengthUnit.Meter, start, end);
  if (routeLen < 1) {
    return _kDistance.as(LengthUnit.Meter, point, start);
  }
  final t = _projectT(point, start, end).clamp(0.0, 1.0);
  final closest = _lerpLatLng(start, end, t);
  return _kDistance.as(LengthUnit.Meter, point, closest);
}

LatLng _offRoutePoint(LatLng onRoute, LatLng start, LatLng end) {
  final mid = _lerpLatLng(start, end, 0.5);
  final latOffset = (onRoute.latitude - mid.latitude).sign * 0.012;
  final lngOffset = (onRoute.longitude - mid.longitude).sign * 0.012;
  if (latOffset.abs() < 0.004 && lngOffset.abs() < 0.004) {
    return LatLng(onRoute.latitude + 0.012, onRoute.longitude - 0.008);
  }
  return LatLng(onRoute.latitude + latOffset, onRoute.longitude + lngOffset);
}

List<_MemberLiveState> _initialMemberStates() {
  return _kMemberDefs.map((def) {
    final progress = def.isHost ? 0.25 : 0.18 + def.speed * 2;
    final pos = _lerpLatLng(_kOrigin, _kDestination, progress);
    return _MemberLiveState(
      def: def,
      progress: progress,
      position: pos,
      deviationMeters: _deviationFromRoute(pos, _kOrigin, _kDestination),
    );
  }).toList();
}

_MemberLiveState? _worstDeviant(List<_MemberLiveState> members) {
  _MemberLiveState? worst;
  for (final m in members) {
    if (m.deviationMeters <= _kDeviationThresholdM) continue;
    if (worst == null || m.deviationMeters > worst.deviationMeters) {
      worst = m;
    }
  }
  return worst;
}

String _formatElapsed(DateTime? started) {
  if (started == null) return '—';
  final d = DateTime.now().difference(started);
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '${d.inHours > 0 ? '${d.inHours}:' : ''}$m:$s';
}

// ── Screen ────────────────────────────────────────────────────────────────────
class Day251GroupJourneyLiveMapScreen extends ConsumerStatefulWidget {
  const Day251GroupJourneyLiveMapScreen({super.key});

  @override
  ConsumerState<Day251GroupJourneyLiveMapScreen> createState() =>
      _Day251GroupJourneyLiveMapScreenState();
}

class _Day251GroupJourneyLiveMapScreenState
    extends ConsumerState<Day251GroupJourneyLiveMapScreen> {
  Timer? _liveTimer;
  final _mapController = MapController();

  @override
  void dispose() {
    _liveTimer?.cancel();
    super.dispose();
  }

  void _startSession() {
    ref.read(_d251SessionActiveProvider.notifier).state = true;
    ref.read(_d251MembersProvider.notifier).state = _initialMemberStates();
    ref.read(_d251SessionStartedAtProvider.notifier).state = DateTime.now();
    ref.read(_d251HighlightedMemberProvider.notifier).state = null;
    ref.read(_d251TabProvider.notifier).state = 0;

    _liveTimer?.cancel();
    _liveTimer = Timer.periodic(const Duration(seconds: 2), (_) => _tickLive());

    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Group live map started · 5 members on route to Bandra West',
        ),
      ),
    );
  }

  void _tickLive() {
    if (!mounted || !ref.read(_d251SessionActiveProvider)) return;

    final members = List<_MemberLiveState>.from(ref.read(_d251MembersProvider));
    var changed = false;

    for (final m in members) {
      if (m.deviated) continue;
      final next = math.min(1.0, m.progress + m.def.speed);
      if (next == m.progress) continue;
      m.progress = next;
      m.position = _lerpLatLng(_kOrigin, _kDestination, next);
      m.deviationMeters =
          _deviationFromRoute(m.position, _kOrigin, _kDestination);
      changed = true;
      if (next >= 1.0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${m.def.name} arrived at destination (mock).')),
        );
      }
    }

    if (changed) {
      ref.read(_d251MembersProvider.notifier).state = members;
      setState(() {});
    }
  }

  void _endSession() {
    _liveTimer?.cancel();
    ref.read(_d251SessionActiveProvider.notifier).state = false;
    ref.read(_d251MembersProvider.notifier).state = [];
    ref.read(_d251SessionStartedAtProvider.notifier).state = null;
    ref.read(_d251HighlightedMemberProvider.notifier).state = null;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Group live map session ended (mock).')),
    );
  }

  void _simulateDeviation() {
    if (!ref.read(_d251SessionActiveProvider)) return;

    final members = List<_MemberLiveState>.from(ref.read(_d251MembersProvider));
    final target = members.firstWhere(
      (m) => m.def.id == 'vikram',
      orElse: () => members.last,
    );
    final offRoute = _offRoutePoint(target.position, _kOrigin, _kDestination);
    target.position = offRoute;
    target.deviated = true;
    target.deviationMeters =
        _deviationFromRoute(offRoute, _kOrigin, _kDestination);

    ref.read(_d251MembersProvider.notifier).state = members;
    ref.read(_d251HighlightedMemberProvider.notifier).state = target.def.id;
    ref.read(_d251TabProvider.notifier).state = 0;

    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${target.def.name} deviated · '
          '${target.deviationMeters.round()}m off group route',
        ),
      ),
    );
    setState(() {});
  }

  void _resetDeviation() {
    if (!ref.read(_d251SessionActiveProvider)) return;

    final members = List<_MemberLiveState>.from(ref.read(_d251MembersProvider));
    for (final m in members) {
      if (!m.deviated) continue;
      m.deviated = false;
      m.position = _lerpLatLng(_kOrigin, _kDestination, m.progress);
      m.deviationMeters =
          _deviationFromRoute(m.position, _kOrigin, _kDestination);
    }
    ref.read(_d251MembersProvider.notifier).state = members;
    ref.read(_d251HighlightedMemberProvider.notifier).state = null;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Member returned to group route (mock).')),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(_d251TabProvider);
    final active = ref.watch(_d251SessionActiveProvider);
    final members = ref.watch(_d251MembersProvider);
    final worst = _worstDeviant(members);
    final showBanner = active && worst != null;

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 251 · Group Live Map'),
        actions: [
          if (active)
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
                  child: Text(
                    '${members.length} LIVE',
                    style: const TextStyle(
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
          if (showBanner)
            _DeviationAlertBanner(
              memberName: worst.def.name,
              deviationMeters: worst.deviationMeters,
            ),
          _TabBar(
            tab: tab,
            onSelect: (i) => ref.read(_d251TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (tab) {
              0 => _MapTab(
                  mapController: _mapController,
                  active: active,
                  onStart: _startSession,
                  onSimulateDeviation: _simulateDeviation,
                  onResetDeviation: _resetDeviation,
                  onEndSession: _endSession,
                ),
              1 => _MembersTab(
                  onHighlight: (id) =>
                      ref.read(_d251HighlightedMemberProvider.notifier).state =
                          id,
                ),
              _ => const _InfoTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Deviation banner ──────────────────────────────────────────────────────────
class _DeviationAlertBanner extends StatelessWidget {
  const _DeviationAlertBanner({
    required this.memberName,
    required this.deviationMeters,
  });

  final String memberName;
  final double deviationMeters;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: ZapSpacing.lg,
        vertical: ZapSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: ZapColors.warning.withOpacity(0.15),
        border: Border(
          bottom: BorderSide(color: ZapColors.warning.withOpacity(0.45)),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: ZapColors.warning,
            size: 20,
          ),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Text(
              'Group route deviation · $memberName · '
              '${deviationMeters.round()}m > ${_kDeviationThresholdM}m · '
              'Notify host + circle (mock)',
              style: const TextStyle(
                color: ZapColors.warning,
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

// ── Tab 0: Map ────────────────────────────────────────────────────────────────
class _MapTab extends ConsumerWidget {
  const _MapTab({
    required this.mapController,
    required this.active,
    required this.onStart,
    required this.onSimulateDeviation,
    required this.onResetDeviation,
    required this.onEndSession,
  });

  final MapController mapController;
  final bool active;
  final VoidCallback onStart;
  final VoidCallback onSimulateDeviation;
  final VoidCallback onResetDeviation;
  final VoidCallback onEndSession;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!active) {
      return ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          Icon(
            Icons.map_rounded,
            size: 64,
            color: ZapColors.textMuted.withOpacity(0.4),
          ),
          const SizedBox(height: ZapSpacing.lg),
          const Text(
            'No active group journey',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'Start a mock group session to see all member markers, shared '
            'route polyline, and live deviation alerts.',
            textAlign: TextAlign.center,
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: ZapSpacing.lg),
          FilledButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Start group live map'),
            style: FilledButton.styleFrom(
              backgroundColor: _kAccent,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: ZapSpacing.md),
          OutlinedButton.icon(
            onPressed: () => context.push(AppRoutes.groupJourneyCreate),
            icon: const Icon(Icons.group_add_rounded),
            label: const Text('Day 250 · Create session first'),
          ),
        ],
      );
    }

    final members = ref.watch(_d251MembersProvider);
    final started = ref.watch(_d251SessionStartedAtProvider);
    final highlight = ref.watch(_d251HighlightedMemberProvider);
    final worst = _worstDeviant(members);
    final hasDeviation = worst != null;

    return Stack(
      children: [
        _GroupLiveMap(
          mapController: mapController,
          members: members,
          highlightId: highlight,
        ),
        Positioned(
          top: ZapSpacing.md,
          left: ZapSpacing.md,
          right: ZapSpacing.md,
          child: Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.bgCard.withOpacity(0.95),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kAccent.withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: _kAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: ZapSpacing.sm),
                    const Text(
                      'Group live · $_kMockSessionId',
                      style: TextStyle(
                        color: _kAccent,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatElapsed(started),
                      style: const TextStyle(
                        color: ZapColors.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ZapSpacing.sm),
                Text(
                  '→ $_kDestinationLabel · ${members.length} members on map',
                  style: const TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                if (hasDeviation) ...[
                  const SizedBox(height: ZapSpacing.sm),
                  Text(
                    '⚠ ${worst.def.shortName} · '
                    '${worst.deviationMeters.round()}m off route',
                    style: const TextStyle(
                      color: ZapColors.warning,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Positioned(
          bottom: ZapSpacing.lg,
          left: ZapSpacing.lg,
          right: ZapSpacing.lg,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          hasDeviation ? onResetDeviation : onSimulateDeviation,
                      icon: Icon(
                        hasDeviation
                            ? Icons.check_circle_outline_rounded
                            : Icons.alt_route_rounded,
                      ),
                      label: Text(
                        hasDeviation ? 'Back on route' : 'Simulate deviation',
                      ),
                    ),
                  ),
                  const SizedBox(width: ZapSpacing.md),
                  OutlinedButton(
                    onPressed: onEndSession,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ZapColors.danger,
                      side: const BorderSide(color: ZapColors.danger),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    child: const Icon(Icons.stop_circle_outlined),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Tab 1: Members ────────────────────────────────────────────────────────────
class _MembersTab extends ConsumerWidget {
  const _MembersTab({required this.onHighlight});

  final ValueChanged<String?> onHighlight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(_d251SessionActiveProvider);
    final members = ref.watch(_d251MembersProvider);
    final highlight = ref.watch(_d251HighlightedMemberProvider);

    if (!active || members.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          const Text(
            'Member roster appears when the group live map session is active.',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: ZapSpacing.lg),
          OutlinedButton.icon(
            onPressed: () => ref.read(_d251TabProvider.notifier).state = 0,
            icon: const Icon(Icons.map_rounded),
            label: const Text('Go to Map tab'),
          ),
        ],
      );
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
            '🟡 MOCK-NOW · Section C Day 11/20 · per-member deviation tracking',
            style: TextStyle(color: ZapColors.warning, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        ...members.map(
          (m) => _MemberStatusTile(
            member: m,
            selected: highlight == m.def.id,
            onTap: () => onHighlight(
              highlight == m.def.id ? null : m.def.id,
            ),
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
    final active = ref.watch(_d251SessionActiveProvider);
    final members = ref.watch(_d251MembersProvider);

    final response = {
      'session_id': _kMockSessionId,
      'destination': {
        'label': _kDestinationLabel,
        'lat': _kDestination.latitude,
        'lng': _kDestination.longitude,
      },
      'members': active
          ? members.map((m) => m.toJson()).toList()
          : [
              {
                'member_id': 'you',
                'name': 'You (Host)',
                'lat': _kOrigin.latitude,
                'lng': _kOrigin.longitude,
                'progress': 0,
                'deviation_meters': 0,
                'off_route': false,
              },
            ],
      'deviation_threshold_meters': _kDeviationThresholdM,
    };

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text(
          'Group Journey — live map',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          'Real-time positions for all invited members on one shared route. '
          'Deviation banner fires when any member exceeds 500m from the '
          'group polyline (same threshold as Day 243 ride safety).',
          style: TextStyle(
            color: ZapColors.textSecondary,
            fontSize: 12,
            height: 1.45,
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'GET /api/v1/journey/group/{session_id}/live/',
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
              ClipboardData(text: _kJsonEncoder.convert(response)),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Live map API JSON copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy live map JSON'),
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
              label: const Text('Day 252 Group Panic'),
              onPressed: () => context.push(AppRoutes.groupJourneyPanic),
            ),
            ActionChip(
              label: const Text('Day 250 Group Create'),
              onPressed: () => context.push(AppRoutes.groupJourneyCreate),
            ),
            ActionChip(
              label: const Text('Day 243 Ride Safety'),
              onPressed: () => context.push(AppRoutes.rideSafetyV2),
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

// ── Map widget ────────────────────────────────────────────────────────────────
class _GroupLiveMap extends StatelessWidget {
  const _GroupLiveMap({
    required this.mapController,
    required this.members,
    this.highlightId,
  });

  final MapController mapController;
  final List<_MemberLiveState> members;
  final String? highlightId;

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[
      const Marker(
        point: _kOrigin,
        width: 32,
        height: 32,
        child: Icon(Icons.trip_origin, color: ZapColors.safe, size: 26),
      ),
      const Marker(
        point: _kDestination,
        width: 36,
        height: 36,
        child: Icon(
          Icons.flag_rounded,
          color: ZapColors.danger,
          size: 30,
        ),
      ),
      ...members.map(
        (m) => Marker(
          point: m.position,
          width: highlightId == m.def.id ? 52 : 44,
          height: highlightId == m.def.id ? 52 : 44,
          child: _MemberMarker(
            member: m,
            highlighted: highlightId == m.def.id,
          ),
        ),
      ),
    ];

    return FlutterMap(
      mapController: mapController,
      options: const MapOptions(
        initialCenter: LatLng(19.068, 72.853),
        initialZoom: 12,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.zapsafe.mobile',
        ),
        PolylineLayer(
          polylines: [
            Polyline(
              points: [_kOrigin, _kDestination],
              color: _kAccent.withOpacity(0.75),
              strokeWidth: 5,
            ),
          ],
        ),
        MarkerLayer(markers: markers),
      ],
    );
  }
}

class _MemberMarker extends StatelessWidget {
  const _MemberMarker({
    required this.member,
    required this.highlighted,
  });

  final _MemberLiveState member;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final offRoute = member.deviationMeters > _kDeviationThresholdM;
    final ringColor = offRoute ? ZapColors.warning : member.def.color;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: highlighted ? 40 : 34,
          height: highlighted ? 40 : 34,
          decoration: BoxDecoration(
            color: ringColor.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(
              color: ringColor,
              width: highlighted ? 3 : 2,
            ),
          ),
          child: Center(
            child: Text(
              member.def.shortName[0],
              style: TextStyle(
                color: ringColor,
                fontWeight: FontWeight.w900,
                fontSize: highlighted ? 14 : 12,
              ),
            ),
          ),
        ),
        if (member.def.isHost)
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: _kAccent,
              borderRadius: BorderRadius.circular(3),
            ),
            child: const Text(
              'HOST',
              style: TextStyle(
                color: Colors.white,
                fontSize: 7,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }
}

class _MemberStatusTile extends StatelessWidget {
  const _MemberStatusTile({
    required this.member,
    required this.selected,
    required this.onTap,
  });

  final _MemberLiveState member;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final offRoute = member.deviationMeters > _kDeviationThresholdM;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: selected
            ? member.def.color.withOpacity(0.1)
            : ZapColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected
              ? member.def.color.withOpacity(0.45)
              : offRoute
                  ? ZapColors.warning.withOpacity(0.5)
                  : ZapColors.border,
        ),
      ),
      child: ListTile(
        dense: true,
        onTap: onTap,
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: member.def.color.withOpacity(0.2),
          child: Text(
            member.def.shortName[0],
            style: TextStyle(
              color: member.def.color,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ),
        title: Text(
          member.def.name,
          style: const TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        subtitle: Text(
          '${(member.progress * 100).round()}% route · '
          '${member.deviationMeters.round()}m off · '
          '${member.deviated ? 'deviated' : 'on route'}',
          style: TextStyle(
            color: offRoute ? ZapColors.warning : ZapColors.textSecondary,
            fontSize: 11,
          ),
        ),
        trailing: Icon(
          offRoute ? Icons.warning_amber_rounded : Icons.check_circle_outline,
          color: offRoute ? ZapColors.warning : ZapColors.safe,
          size: 20,
        ),
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
