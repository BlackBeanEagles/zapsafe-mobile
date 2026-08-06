/// Day 242 — Trusted Circle — Session Sharing Polish
///
/// Section C (Days 241-260): Trusted Circle map with Tier 1/2 contact markers,
/// session-based location share (15m / 30m / 1h / 4h / 8h), active session
/// banner, and end-session control.
///
/// Tag: 🟣 POLISH · `flutter_map` contact markers · multi-contact sessions.
///
/// Route: [AppRoutes.trustedCircleV2] → `/trusted-circle-v2`
library;

import 'dart:async';
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

// ── Mock data ─────────────────────────────────────────────────────────────────
const _kUserPosition = LatLng(19.0760, 72.8777); // Mumbai CST

/// Session durations per spec: 15m / 30m / 1h / 4h / 8h (no indefinite).
const _kDurationOptions = [15, 30, 60, 240, 480];

const _kTabs = ['Circle', 'Share', 'Safety'];

const _kJsonEncoder = JsonEncoder.withIndent('  ');

const _kCircleContacts = [
  _CircleContact(
    id: 'rahul',
    name: 'Rahul Mehta',
    phone: '+91 98765 43210',
    tier: 'Tier 1',
    relation: 'Brother',
    position: LatLng(19.0596, 72.8295),
    lastSeen: 'Online now',
    online: true,
  ),
  _CircleContact(
    id: 'aarti',
    name: 'Aarti Sharma',
    phone: '+91 91234 56789',
    tier: 'Tier 1',
    relation: 'Best friend',
    position: LatLng(19.1136, 72.8697),
    lastSeen: '3 min ago',
    online: true,
  ),
  _CircleContact(
    id: 'priya',
    name: 'Priya Nair',
    phone: '+91 97654 32109',
    tier: 'Tier 1',
    relation: 'Roommate',
    position: LatLng(18.9067, 72.8147),
    lastSeen: '12 min ago',
    online: false,
  ),
  _CircleContact(
    id: 'vikram',
    name: 'Vikram Patel',
    phone: '+91 99887 76655',
    tier: 'Tier 2',
    relation: 'Colleague',
    position: LatLng(19.1176, 72.9060),
    lastSeen: '1 hr ago',
    online: false,
  ),
  _CircleContact(
    id: 'sanjay',
    name: 'Sanjay Kulkarni',
    phone: '+91 90123 45678',
    tier: 'Tier 2',
    relation: 'Neighbour',
    position: LatLng(19.2183, 72.9781),
    lastSeen: '25 min ago',
    online: true,
  ),
  _CircleContact(
    id: 'meera',
    name: 'Meera Joshi',
    phone: '+91 88776 65544',
    tier: 'Tier 2',
    relation: 'Cousin',
    position: LatLng(19.0330, 73.0297),
    lastSeen: 'Offline',
    online: false,
  ),
];

// ── Models ────────────────────────────────────────────────────────────────────
class _CircleContact {
  const _CircleContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.tier,
    required this.relation,
    required this.position,
    required this.lastSeen,
    required this.online,
  });

  final String id;
  final String name;
  final String phone;
  final String tier;
  final String relation;
  final LatLng position;
  final String lastSeen;
  final bool online;

  bool get isTier1 => tier == 'Tier 1';

  Color get tierColor => isTier1 ? ZapColors.safe : ZapColors.warning;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'tier': tier,
        'relation': relation,
        'lat': position.latitude,
        'lng': position.longitude,
        'last_seen': lastSeen,
        'online': online,
      };
}

// ── Providers ─────────────────────────────────────────────────────────────────
final _d242TabProvider = StateProvider<int>((ref) => 0);
final _d242HighlightedContactProvider = StateProvider<String?>((ref) => null);
final _d242ShareTargetsProvider =
    StateProvider<Set<String>>((ref) => {'rahul', 'aarti'});
final _d242DurationMinutesProvider = StateProvider<int>((ref) => 60);
final _d242SessionActiveProvider = StateProvider<bool>((ref) => false);
final _d242SessionEndAtProvider = StateProvider<DateTime?>((ref) => null);
final _d242SessionStartedAtProvider = StateProvider<DateTime?>((ref) => null);

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

String _formatCountdown(Duration remaining) {
  if (remaining.isNegative) return '00:00';
  final h = remaining.inHours;
  final m = remaining.inMinutes.remainder(60);
  final s = remaining.inSeconds.remainder(60);
  if (h > 0) {
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

List<_CircleContact> _contactsByIds(Set<String> ids) {
  return _kCircleContacts.where((c) => ids.contains(c.id)).toList();
}

// ── Screen ────────────────────────────────────────────────────────────────────
class Day242TrustedCircleV2Screen extends ConsumerStatefulWidget {
  const Day242TrustedCircleV2Screen({super.key});

  @override
  ConsumerState<Day242TrustedCircleV2Screen> createState() =>
      _Day242TrustedCircleV2ScreenState();
}

class _Day242TrustedCircleV2ScreenState
    extends ConsumerState<Day242TrustedCircleV2Screen> {
  Timer? _countdownTicker;
  final _mapController = MapController();

  @override
  void dispose() {
    _countdownTicker?.cancel();
    super.dispose();
  }

  void _startSession() {
    final targets = ref.read(_d242ShareTargetsProvider);
    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one circle contact.')),
      );
      return;
    }

    final minutes = ref.read(_d242DurationMinutesProvider);
    final now = DateTime.now();

    ref.read(_d242SessionActiveProvider.notifier).state = true;
    ref.read(_d242SessionStartedAtProvider.notifier).state = now;
    ref.read(_d242SessionEndAtProvider.notifier).state =
        now.add(Duration(minutes: minutes));

    _countdownTicker?.cancel();
    _countdownTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (!ref.read(_d242SessionActiveProvider)) return;
      final endAt = ref.read(_d242SessionEndAtProvider);
      if (endAt != null && DateTime.now().isAfter(endAt)) {
        _endSession(expired: true);
      } else {
        setState(() {});
      }
    });

    HapticFeedback.mediumImpact();
    final names = _contactsByIds(targets).map((c) => c.name.split(' ').first);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Sharing live location with ${names.join(', ')} · '
          '${_formatDurationLabel(minutes)}',
        ),
      ),
    );
  }

  void _endSession({bool expired = false}) {
    _countdownTicker?.cancel();
    ref.read(_d242SessionActiveProvider.notifier).state = false;
    ref.read(_d242SessionEndAtProvider.notifier).state = null;
    ref.read(_d242SessionStartedAtProvider.notifier).state = null;

    if (!mounted) return;
    final msg = expired
        ? 'Share session expired — location hidden from circle.'
        : 'Share session ended.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(_d242TabProvider);
    final sessionActive = ref.watch(_d242SessionActiveProvider);
    final endAt = ref.watch(_d242SessionEndAtProvider);
    final remaining =
        endAt != null ? endAt.difference(DateTime.now()) : Duration.zero;

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 242 · Trusted Circle v2'),
        actions: [
          if (sessionActive)
            Padding(
              padding: const EdgeInsets.only(right: ZapSpacing.md),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: const Color(0xFF3B82F6).withOpacity(0.45),
                    ),
                  ),
                  child: Text(
                    _formatCountdown(remaining),
                    style: const TextStyle(
                      color: Color(0xFF3B82F6),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (sessionActive) _ActiveSessionBanner(onEnd: () => _endSession()),
          _TabBar(
            tab: tab,
            onSelect: (i) => ref.read(_d242TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (tab) {
              0 => _CircleTab(mapController: _mapController),
              1 => _ShareTab(
                  onStart: _startSession,
                  onEnd: () => _endSession(),
                ),
              _ => const _SafetyTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Active session banner ─────────────────────────────────────────────────────
class _ActiveSessionBanner extends ConsumerWidget {
  const _ActiveSessionBanner({required this.onEnd});

  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targets = ref.watch(_d242ShareTargetsProvider);
    final endAt = ref.watch(_d242SessionEndAtProvider);
    final duration = ref.watch(_d242DurationMinutesProvider);
    final remaining = endAt != null
        ? endAt.difference(DateTime.now())
        : Duration(minutes: duration);
    final contacts = _contactsByIds(targets);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: ZapSpacing.lg,
        vertical: ZapSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6).withOpacity(0.12),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFF3B82F6).withOpacity(0.35),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF3B82F6),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Live location sharing',
                  style: TextStyle(
                    color: Color(0xFF3B82F6),
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
                Text(
                  '${contacts.length} contact${contacts.length == 1 ? '' : 's'} · '
                  '${_formatCountdown(remaining)} left',
                  style: const TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onEnd,
            style: TextButton.styleFrom(foregroundColor: ZapColors.danger),
            child: const Text('End', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Circle map ─────────────────────────────────────────────────────────
class _CircleTab extends ConsumerWidget {
  const _CircleTab({required this.mapController});

  final MapController mapController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final highlighted = ref.watch(_d242HighlightedContactProvider);
    final sessionActive = ref.watch(_d242SessionActiveProvider);
    final shareTargets = ref.watch(_d242ShareTargetsProvider);

    return Column(
      children: [
        Expanded(
          flex: 6,
          child: _CircleMap(
            mapController: mapController,
            highlightedId: highlighted,
            sessionActive: sessionActive,
            sharingWithIds: shareTargets,
          ),
        ),
        Expanded(
          flex: 5,
          child: Container(
            decoration: const BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(top: BorderSide(color: ZapColors.border)),
            ),
            child: ListView(
              padding: const EdgeInsets.all(ZapSpacing.lg),
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFF3B82F6).withOpacity(0.35),
                    ),
                  ),
                  child: const Text(
                    '🟣 POLISH · Section C Day 2/20 · Tier 1/2 markers · tap to focus map',
                    style: TextStyle(color: Color(0xFF3B82F6), fontSize: 11),
                  ),
                ),
                const SizedBox(height: ZapSpacing.md),
                const Row(
                  children: [
                    _LegendDot(color: ZapColors.safe, label: 'Tier 1'),
                    SizedBox(width: 16),
                    _LegendDot(color: ZapColors.warning, label: 'Tier 2'),
                    SizedBox(width: 16),
                    _LegendDot(
                      color: Color(0xFF3B82F6),
                      label: 'You',
                    ),
                  ],
                ),
                const SizedBox(height: ZapSpacing.md),
                ..._kCircleContacts.map(
                  (c) => _ContactListTile(
                    contact: c,
                    selected: highlighted == c.id,
                    isSharingWith: sessionActive && shareTargets.contains(c.id),
                    onTap: () {
                      ref.read(_d242HighlightedContactProvider.notifier).state =
                          c.id;
                      mapController.move(c.position, 13);
                    },
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

// ── Tab 1: Share session ──────────────────────────────────────────────────────
class _ShareTab extends ConsumerWidget {
  const _ShareTab({required this.onStart, required this.onEnd});

  final VoidCallback onStart;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targets = ref.watch(_d242ShareTargetsProvider);
    final duration = ref.watch(_d242DurationMinutesProvider);
    final sessionActive = ref.watch(_d242SessionActiveProvider);
    final endAt = ref.watch(_d242SessionEndAtProvider);
    final remaining = endAt != null
        ? endAt.difference(DateTime.now())
        : Duration(minutes: duration);
    final sharedContacts = _contactsByIds(targets);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        if (sessionActive) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ZapSpacing.lg),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF3B82F6).withOpacity(0.2),
                  const Color(0xFF3B82F6).withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF3B82F6).withOpacity(0.45),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.share_location_rounded,
                      color: Color(0xFF3B82F6),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Active share session',
                      style: TextStyle(
                        color: Color(0xFF3B82F6),
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatCountdown(remaining),
                      style: const TextStyle(
                        color: ZapColors.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Visible to: ${sharedContacts.map((c) => c.name.split(' ').first).join(', ')}',
                  style: const TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Duration: ${_formatDurationLabel(duration)} · auto-stops at expiry',
                  style: const TextStyle(
                    color: ZapColors.textMuted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: ZapSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onEnd,
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('End session'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ZapColors.danger,
                      side: const BorderSide(color: ZapColors.danger),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.lg),
        ],
        const Text(
          'Who can see your location?',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Select Tier 1/2 contacts. They receive a push when sharing starts (mock).',
          style: TextStyle(color: ZapColors.textMuted, fontSize: 11),
        ),
        const SizedBox(height: ZapSpacing.sm),
        ..._kCircleContacts.map(
          (c) => _ShareTargetTile(
            contact: c,
            selected: targets.contains(c.id),
            disabled: sessionActive,
            onChanged: (on) {
              final next = Set<String>.from(targets);
              if (on) {
                next.add(c.id);
              } else {
                next.remove(c.id);
              }
              ref.read(_d242ShareTargetsProvider.notifier).state = next;
            },
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Session duration',
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
              onSelected: sessionActive
                  ? null
                  : (_) =>
                      ref.read(_d242DurationMinutesProvider.notifier).state = m,
              selectedColor: const Color(0xFF3B82F6).withOpacity(0.25),
              labelStyle: TextStyle(
                color: selected
                    ? const Color(0xFF3B82F6)
                    : ZapColors.textSecondary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: ZapSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: sessionActive ? null : onStart,
            icon: const Icon(Icons.location_on_rounded),
            label: Text(
              sessionActive ? 'Session active' : 'Start share session',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              disabledBackgroundColor: ZapColors.textMuted.withOpacity(0.2),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        OutlinedButton.icon(
          onPressed: () => context.push(AppRoutes.journeyModeV2),
          icon: const Icon(Icons.route_rounded, size: 18),
          label: const Text('Day 241 · Journey Mode (single contact)'),
        ),
      ],
    );
  }
}

// ── Tab 2: Safety ─────────────────────────────────────────────────────────────
class _SafetyTab extends ConsumerWidget {
  const _SafetyTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targets = ref.watch(_d242ShareTargetsProvider);
    final duration = ref.watch(_d242DurationMinutesProvider);
    final active = ref.watch(_d242SessionActiveProvider);
    final startedAt = ref.watch(_d242SessionStartedAtProvider);
    final endAt = ref.watch(_d242SessionEndAtProvider);

    final payload = {
      'feature': 'trusted_circle_v2',
      'version': '2.0.0',
      'section': 'C',
      'day': 242,
      'session_active': active,
      'share_targets': _contactsByIds(targets).map((c) => c.toJson()).toList(),
      'duration_minutes': duration,
      'duration_options_minutes': _kDurationOptions,
      'duration_max_minutes': 480,
      'indefinite_sharing_allowed': false,
      'user_position': {
        'lat': _kUserPosition.latitude,
        'lng': _kUserPosition.longitude,
      },
      'circle_contacts': _kCircleContacts.map((c) => c.toJson()).toList(),
      'session_started_at': startedAt?.toIso8601String(),
      'session_ends_at': endAt?.toIso8601String(),
      'map_provider': 'OpenStreetMap via flutter_map',
    };

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
            '🟣 POLISH · Multi-contact session share · Tier 1 gets SOS priority in prod',
            style: TextStyle(color: ZapColors.warning, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Session rules',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        const _PolicyRow(
          icon: Icons.groups_rounded,
          title: 'Trusted Circle map',
          subtitle:
              'See mock positions for Tier 1 (green) and Tier 2 (amber) contacts.',
        ),
        const _PolicyRow(
          icon: Icons.timer_rounded,
          title: 'Session durations: 15m · 30m · 1h · 4h · 8h',
          subtitle: 'Picker matches product spec. Auto-stops — no indefinite share.',
        ),
        const _PolicyRow(
          icon: Icons.stop_circle_outlined,
          title: 'End session anytime',
          subtitle:
              'Banner + Share tab control. Location hidden immediately (mock).',
        ),
        const _PolicyRow(
          icon: Icons.route_rounded,
          title: 'Journey Mode vs Trusted Circle',
          subtitle:
              'Day 241 = single notify contact + route. Day 242 = circle multi-share.',
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
              const SnackBar(content: Text('Circle session JSON copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy session JSON'),
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
              label: const Text('Day 250 Group Journey'),
              onPressed: () => context.push(AppRoutes.groupJourneyCreate),
            ),
            ActionChip(
              label: const Text('Day 249 Voice Assistants'),
              onPressed: () => context.push(AppRoutes.voiceAssistantSetup),
            ),
            ActionChip(
              label: const Text('Day 248 Siri Shortcuts'),
              onPressed: () => context.push(AppRoutes.siriShortcuts),
            ),
            ActionChip(
              label: const Text('Day 247 Haptic Patterns'),
              onPressed: () => context.push(AppRoutes.hapticPatterns),
            ),
            ActionChip(
              label: const Text('Day 246 Visual Alerts'),
              onPressed: () => context.push(AppRoutes.hearingImpairedVisual),
            ),
            ActionChip(
              label: const Text('Day 245 Offline SOS'),
              onPressed: () => context.push(AppRoutes.offlineSosUx),
            ),
            ActionChip(
              label: const Text('Day 244 Fake Call'),
              onPressed: () => context.push(AppRoutes.fakeCallPolish),
            ),
            ActionChip(
              label: const Text('Day 243 Ride Safety'),
              onPressed: () => context.push(AppRoutes.rideSafetyV2),
            ),
            ActionChip(
              label: const Text('Day 241 Journey Mode'),
              onPressed: () => context.push(AppRoutes.journeyModeV2),
            ),
            ActionChip(
              label: const Text('Day 240 Section B'),
              onPressed: () =>
                  context.push(AppRoutes.sectionBCatchupMilestone),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Map ───────────────────────────────────────────────────────────────────────
class _CircleMap extends StatelessWidget {
  const _CircleMap({
    required this.mapController,
    required this.highlightedId,
    required this.sessionActive,
    required this.sharingWithIds,
  });

  final MapController mapController;
  final String? highlightedId;
  final bool sessionActive;
  final Set<String> sharingWithIds;

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[
      Marker(
        point: _kUserPosition,
        width: sessionActive ? 52 : 40,
        height: sessionActive ? 52 : 40,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withOpacity(sessionActive ? 0.25 : 0.15),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF3B82F6),
              width: sessionActive ? 3 : 2,
            ),
          ),
          child: Icon(
            sessionActive ? Icons.share_location_rounded : Icons.person_pin_circle,
            color: const Color(0xFF3B82F6),
            size: sessionActive ? 26 : 22,
          ),
        ),
      ),
      ..._kCircleContacts.map((c) {
        final highlighted = highlightedId == c.id;
        final sharing = sessionActive && sharingWithIds.contains(c.id);
        return Marker(
          point: c.position,
          width: highlighted ? 48 : 40,
          height: highlighted ? 48 : 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (sharing)
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.tierColor.withOpacity(0.15),
                    border: Border.all(color: c.tierColor, width: 2),
                  ),
                ),
              CircleAvatar(
                radius: highlighted ? 18 : 15,
                backgroundColor: c.tierColor.withOpacity(0.25),
                child: Text(
                  c.name[0],
                  style: TextStyle(
                    color: c.tierColor,
                    fontWeight: FontWeight.w900,
                    fontSize: highlighted ? 14 : 12,
                  ),
                ),
              ),
              if (c.online)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: ZapColors.safe,
                      shape: BoxShape.circle,
                      border: Border.all(color: ZapColors.bgPrimary, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
    ];

    return FlutterMap(
      mapController: mapController,
      options: const MapOptions(
        initialCenter: _kUserPosition,
        initialZoom: 11,
        interactionOptions: InteractionOptions(
          flags: InteractiveFlag.all,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.zapsafe.zapsafe_mobile',
        ),
        MarkerLayer(markers: markers),
      ],
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────
class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: ZapColors.textMuted, fontSize: 10),
        ),
      ],
    );
  }
}

class _ContactListTile extends StatelessWidget {
  const _ContactListTile({
    required this.contact,
    required this.selected,
    required this.isSharingWith,
    required this.onTap,
  });

  final _CircleContact contact;
  final bool selected;
  final bool isSharingWith;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected
            ? contact.tierColor.withOpacity(0.1)
            : ZapColors.bgPrimary,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? contact.tierColor : ZapColors.border,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: contact.tierColor.withOpacity(0.2),
                  child: Text(
                    contact.name[0],
                    style: TextStyle(
                      color: contact.tierColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            contact.name,
                            style: const TextStyle(
                              color: ZapColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          if (isSharingWith) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.visibility_rounded,
                              size: 14,
                              color: Color(0xFF3B82F6),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        '${contact.relation} · ${contact.lastSeen}',
                        style: const TextStyle(
                          color: ZapColors.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: contact.tierColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    contact.tier,
                    style: TextStyle(
                      color: contact.tierColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShareTargetTile extends StatelessWidget {
  const _ShareTargetTile({
    required this.contact,
    required this.selected,
    required this.disabled,
    required this.onChanged,
  });

  final _CircleContact contact;
  final bool selected;
  final bool disabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: selected,
      onChanged: disabled ? null : (v) => onChanged(v ?? false),
      activeColor: const Color(0xFF3B82F6),
      title: Text(
        contact.name,
        style: const TextStyle(
          color: ZapColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
      subtitle: Text(
        '${contact.tier} · ${contact.relation}',
        style: const TextStyle(color: ZapColors.textMuted, fontSize: 10),
      ),
      secondary: CircleAvatar(
        radius: 16,
        backgroundColor: contact.tierColor.withOpacity(0.2),
        child: Text(
          contact.name[0],
          style: TextStyle(
            color: contact.tierColor,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      contentPadding: EdgeInsets.zero,
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
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
                      color: selected
                          ? const Color(0xFF3B82F6)
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  _kTabs[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFF3B82F6)
                        : ZapColors.textMuted,
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
