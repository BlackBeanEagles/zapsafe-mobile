/// Day 241 — Journey Mode v2 — Plan & Start
///
/// Section C (Days 241-260): phone-only Journey Mode polish — map + bottom
/// sheet plan UI, notify contact + ETA (15 min–8 hr max), live session with
/// mock location stream and check-in button.
///
/// Tag: 🟣 POLISH · OpenStreetMap tiles via `flutter_map` (mock geocoding).
///
/// Route: [AppRoutes.journeyModeV2] → `/journey-mode-v2`
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

// ── Mock data ─────────────────────────────────────────────────────────────────
const _kOrigin = LatLng(19.0760, 72.8777); // Mumbai CST area

const _kMockDestinations = [
  _JourneyDestination(
    id: 'bandra',
    label: 'Bandra West',
    subtitle: 'Linking Road, Mumbai',
    latLng: LatLng(19.0596, 72.8295),
  ),
  _JourneyDestination(
    id: 'andheri',
    label: 'Andheri East',
    subtitle: 'Metro station, Mumbai',
    latLng: LatLng(19.1136, 72.8697),
  ),
  _JourneyDestination(
    id: 'pune',
    label: 'Pune Junction',
    subtitle: 'Railway station, Pune',
    latLng: LatLng(18.5314, 73.8740),
  ),
  _JourneyDestination(
    id: 'navi',
    label: 'Vashi',
    subtitle: 'Navi Mumbai',
    latLng: LatLng(19.0770, 73.0120),
  ),
  _JourneyDestination(
    id: 'airport',
    label: 'CSMIA Terminal 2',
    subtitle: 'Mumbai International Airport',
    latLng: LatLng(19.0997, 72.8750),
  ),
];

const _kMockContacts = [
  _JourneyContact(
    id: 'rahul',
    name: 'Rahul Mehta',
    phone: '+91 98765 43210',
    tier: 'Tier 1',
    relation: 'Brother',
  ),
  _JourneyContact(
    id: 'aarti',
    name: 'Aarti Sharma',
    phone: '+91 91234 56789',
    tier: 'Tier 1',
    relation: 'Best friend',
  ),
  _JourneyContact(
    id: 'vikram',
    name: 'Vikram Patel',
    phone: '+91 99887 76655',
    tier: 'Tier 2',
    relation: 'Colleague',
  ),
];

/// Duration options in minutes — 15 min minimum, 8 hr maximum (no indefinite).
const _kDurationOptions = [15, 30, 60, 120, 240, 480];

const _kTabs = ['Plan', 'Live', 'Safety'];

const _kJsonEncoder = JsonEncoder.withIndent('  ');

// ── Models ────────────────────────────────────────────────────────────────────
class _JourneyDestination {
  const _JourneyDestination({
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

class _JourneyContact {
  const _JourneyContact({
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

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'tier': tier,
        'relation': relation,
      };
}

// ── Providers ─────────────────────────────────────────────────────────────────
final _d241TabProvider = StateProvider<int>((ref) => 0);
final _d241SearchProvider = StateProvider<String>((ref) => '');
final _d241DestinationProvider =
    StateProvider<_JourneyDestination?>((ref) => null);
final _d241ContactProvider = StateProvider<_JourneyContact?>((ref) => null);
final _d241DurationMinutesProvider = StateProvider<int>((ref) => 60);
final _d241SessionActiveProvider = StateProvider<bool>((ref) => false);
final _d241ProgressProvider = StateProvider<double>((ref) => 0);
final _d241CurrentPositionProvider =
    StateProvider<LatLng>((ref) => _kOrigin);
final _d241SessionEndAtProvider = StateProvider<DateTime?>((ref) => null);
final _d241CheckInCountProvider = StateProvider<int>((ref) => 0);
final _d241SessionStartedAtProvider = StateProvider<DateTime?>((ref) => null);

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

LatLng _lerpLatLng(LatLng a, LatLng b, double t) {
  return LatLng(
    a.latitude + (b.latitude - a.latitude) * t,
    a.longitude + (b.longitude - a.longitude) * t,
  );
}

// ── Screen ────────────────────────────────────────────────────────────────────
class Day241JourneyModeV2Screen extends ConsumerStatefulWidget {
  const Day241JourneyModeV2Screen({super.key});

  @override
  ConsumerState<Day241JourneyModeV2Screen> createState() =>
      _Day241JourneyModeV2ScreenState();
}

class _Day241JourneyModeV2ScreenState
    extends ConsumerState<Day241JourneyModeV2Screen> {
  Timer? _locationTimer;
  Timer? _countdownTicker;
  final _mapController = MapController();
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      ref.read(_d241SearchProvider.notifier).state = _searchCtrl.text;
    });
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _countdownTicker?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _startSession() {
    final dest = ref.read(_d241DestinationProvider);
    final contact = ref.read(_d241ContactProvider);
    if (dest == null || contact == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a destination and notify contact first.'),
        ),
      );
      return;
    }

    final minutes = ref.read(_d241DurationMinutesProvider);
    final now = DateTime.now();
    final endAt = now.add(Duration(minutes: minutes));

    ref.read(_d241SessionActiveProvider.notifier).state = true;
    ref.read(_d241SessionStartedAtProvider.notifier).state = now;
    ref.read(_d241SessionEndAtProvider.notifier).state = endAt;
    ref.read(_d241ProgressProvider.notifier).state = 0;
    ref.read(_d241CurrentPositionProvider.notifier).state = _kOrigin;
    ref.read(_d241CheckInCountProvider.notifier).state = 0;
    ref.read(_d241TabProvider.notifier).state = 1;

    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      final active = ref.read(_d241SessionActiveProvider);
      if (!active) return;

      final progress = ref.read(_d241ProgressProvider);
      final next = math.min(1.0, progress + 0.04);
      ref.read(_d241ProgressProvider.notifier).state = next;
      ref.read(_d241CurrentPositionProvider.notifier).state =
          _lerpLatLng(_kOrigin, dest.latLng, next);

      if (next >= 1.0) {
        _endSession(arrived: true);
      }
    });

    _countdownTicker?.cancel();
    _countdownTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (!ref.read(_d241SessionActiveProvider)) return;
      final endAt = ref.read(_d241SessionEndAtProvider);
      if (endAt != null && DateTime.now().isAfter(endAt)) {
        _endSession(expired: true);
      } else {
        setState(() {});
      }
    });

    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Journey started · ${contact.name} notified · '
          '${_formatDurationLabel(minutes)} session',
        ),
      ),
    );
  }

  void _endSession({bool arrived = false, bool expired = false}) {
    _locationTimer?.cancel();
    _countdownTicker?.cancel();
    ref.read(_d241SessionActiveProvider.notifier).state = false;
    ref.read(_d241SessionEndAtProvider.notifier).state = null;
    ref.read(_d241SessionStartedAtProvider.notifier).state = null;
    ref.read(_d241ProgressProvider.notifier).state = 0;
    ref.read(_d241CurrentPositionProvider.notifier).state = _kOrigin;

    if (!mounted) return;
    final msg = arrived
        ? 'Arrived at destination — session ended.'
        : expired
            ? 'Session time expired — sharing stopped.'
            : 'Journey session ended.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    setState(() {});
  }

  void _onCheckIn() {
    if (!ref.read(_d241SessionActiveProvider)) return;
    ref.read(_d241CheckInCountProvider.notifier).state =
        ref.read(_d241CheckInCountProvider) + 1;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Check-in sent to notify contact (mock).')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(_d241TabProvider);
    final sessionActive = ref.watch(_d241SessionActiveProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 241 · Journey Mode v2'),
        actions: [
          if (sessionActive)
            Padding(
              padding: const EdgeInsets.only(right: ZapSpacing.md),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: ZapColors.safe.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                    border:
                        Border.all(color: ZapColors.safe.withOpacity(0.45)),
                  ),
                  child: const Text(
                    'LIVE',
                    style: TextStyle(
                      color: ZapColors.safe,
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
            onSelect: (i) => ref.read(_d241TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (tab) {
              0 => _PlanTab(
                  mapController: _mapController,
                  searchCtrl: _searchCtrl,
                  onStart: _startSession,
                ),
              1 => _LiveTab(
                  mapController: _mapController,
                  onCheckIn: _onCheckIn,
                  onEndSession: () => _endSession(),
                ),
              _ => const _SafetyTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Plan ───────────────────────────────────────────────────────────────
class _PlanTab extends ConsumerWidget {
  const _PlanTab({
    required this.mapController,
    required this.searchCtrl,
    required this.onStart,
  });

  final MapController mapController;
  final TextEditingController searchCtrl;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(_d241SearchProvider).toLowerCase();
    final destination = ref.watch(_d241DestinationProvider);
    final contact = ref.watch(_d241ContactProvider);
    final duration = ref.watch(_d241DurationMinutesProvider);
    final sessionActive = ref.watch(_d241SessionActiveProvider);

    final filtered = _kMockDestinations.where((d) {
      if (query.isEmpty) return true;
      return d.label.toLowerCase().contains(query) ||
          d.subtitle.toLowerCase().contains(query);
    }).toList();

    final canStart =
        destination != null && contact != null && !sessionActive;

    return Column(
      children: [
        Expanded(
          flex: 5,
          child: _JourneyMap(
            mapController: mapController,
            showRoute: destination != null,
            destination: destination?.latLng,
            currentPosition: _kOrigin,
            showCurrentMarker: false,
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
                    color: const Color(0xFF8B5CF6).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFF8B5CF6).withOpacity(0.35),
                    ),
                  ),
                  child: const Text(
                    '🟣 POLISH · Section C Day 1/20 · OSM map · mock geocoding · 15m–8h max',
                    style: TextStyle(
                      color: Color(0xFF8B5CF6),
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(height: ZapSpacing.lg),
                const Text(
                  'Search destination',
                  style: TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: ZapSpacing.sm),
                TextField(
                  controller: searchCtrl,
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
                    onTap: () {
                      ref.read(_d241DestinationProvider.notifier).state = d;
                      mapController.move(d.latLng, 12);
                    },
                  ),
                ),
                const SizedBox(height: ZapSpacing.lg),
                const Text(
                  'Notify contact',
                  style: TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: ZapSpacing.sm),
                ..._kMockContacts.map(
                  (c) => _ContactTile(
                    contact: c,
                    selected: contact?.id == c.id,
                    onTap: () =>
                        ref.read(_d241ContactProvider.notifier).state = c,
                  ),
                ),
                const SizedBox(height: ZapSpacing.lg),
                const Text(
                  'Share duration (max 8 hours)',
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
                      onSelected: (_) =>
                          ref.read(_d241DurationMinutesProvider.notifier).state =
                              m,
                      selectedColor:
                          const Color(0xFF8B5CF6).withOpacity(0.25),
                      labelStyle: TextStyle(
                        color: selected
                            ? const Color(0xFF8B5CF6)
                            : ZapColors.textSecondary,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 12,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: ZapSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: canStart ? onStart : null,
                    icon: const Icon(Icons.navigation_rounded),
                    label: Text(
                      sessionActive
                          ? 'Session active — see Live tab'
                          : 'Start journey',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      disabledBackgroundColor:
                          ZapColors.textMuted.withOpacity(0.2),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
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

// ── Tab 1: Live ───────────────────────────────────────────────────────────────
class _LiveTab extends ConsumerWidget {
  const _LiveTab({
    required this.mapController,
    required this.onCheckIn,
    required this.onEndSession,
  });

  final MapController mapController;
  final VoidCallback onCheckIn;
  final VoidCallback onEndSession;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(_d241SessionActiveProvider);
    final destination = ref.watch(_d241DestinationProvider);
    final contact = ref.watch(_d241ContactProvider);
    final progress = ref.watch(_d241ProgressProvider);
    final current = ref.watch(_d241CurrentPositionProvider);
    final checkIns = ref.watch(_d241CheckInCountProvider);
    final endAt = ref.watch(_d241SessionEndAtProvider);
    final durationMin = ref.watch(_d241DurationMinutesProvider);

    final remaining = endAt != null
        ? endAt.difference(DateTime.now())
        : Duration(minutes: durationMin);

    if (!active || destination == null) {
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
            'No active journey',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'Plan a destination on the Plan tab, pick a notify contact and '
            'duration, then tap Start journey.',
            textAlign: TextAlign.center,
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: ZapSpacing.lg),
          Center(
            child: OutlinedButton.icon(
              onPressed: () => ref.read(_d241TabProvider.notifier).state = 0,
              icon: const Icon(Icons.edit_location_alt_rounded),
              label: const Text('Go to Plan'),
            ),
          ),
        ],
      );
    }

    return Stack(
      children: [
        _JourneyMap(
          mapController: mapController,
          showRoute: true,
          destination: destination.latLng,
          currentPosition: current,
          showCurrentMarker: true,
          followCurrent: true,
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
              border: Border.all(color: ZapColors.safe.withOpacity(0.4)),
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
                        color: ZapColors.safe,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Live sharing',
                      style: TextStyle(
                        color: ZapColors.safe,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatCountdown(remaining),
                      style: const TextStyle(
                        color: ZapColors.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '→ ${destination.label} · ${contact?.name ?? '—'}',
                  style: const TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: ZapColors.bgPrimary,
                    color: const Color(0xFF8B5CF6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(progress * 100).round()}% route · $checkIns check-in${checkIns == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: ZapColors.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: ZapSpacing.lg,
          left: ZapSpacing.lg,
          right: ZapSpacing.lg,
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onCheckIn,
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('Check in'),
                  style: FilledButton.styleFrom(
                    backgroundColor: ZapColors.safe,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
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
                child: const Text('End'),
              ),
            ],
          ),
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
    final destination = ref.watch(_d241DestinationProvider);
    final contact = ref.watch(_d241ContactProvider);
    final duration = ref.watch(_d241DurationMinutesProvider);
    final active = ref.watch(_d241SessionActiveProvider);
    final checkIns = ref.watch(_d241CheckInCountProvider);
    final startedAt = ref.watch(_d241SessionStartedAtProvider);

    final payload = {
      'feature': 'journey_mode_v2',
      'version': '2.0.0',
      'section': 'C',
      'day': 241,
      'session_active': active,
      'origin': {'lat': _kOrigin.latitude, 'lng': _kOrigin.longitude},
      'destination': destination?.toJson(),
      'notify_contact': contact?.toJson(),
      'duration_minutes': duration,
      'duration_max_minutes': 480,
      'indefinite_sharing_allowed': false,
      'check_in_count': checkIns,
      'session_started_at': startedAt?.toIso8601String(),
      'mock_location_stream': 'Timer.periodic 2s · progress +0.04',
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
            '🟣 POLISH · Session-based sharing only — no indefinite location share',
            style: TextStyle(color: ZapColors.warning, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Safety limits',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        const _PolicyRow(
          icon: Icons.timer_rounded,
          title: 'Max session: 8 hours',
          subtitle:
              'ETA picker offers 15m, 30m, 1h, 2h, 4h, 8h. Auto-stops at expiry.',
        ),
        const _PolicyRow(
          icon: Icons.block_rounded,
          title: 'No indefinite sharing',
          subtitle:
              'Unlike legacy "share until I stop", v2 requires explicit duration.',
        ),
        const _PolicyRow(
          icon: Icons.person_pin_circle_rounded,
          title: 'Single notify contact',
          subtitle: 'Tier 1 preferred. Trusted Circle multi-share is Day 242.',
        ),
        const _PolicyRow(
          icon: Icons.check_circle_rounded,
          title: 'Manual check-ins',
          subtitle:
              'User taps Check in during live session; contact gets push (mock).',
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
              const SnackBar(content: Text('Session JSON copied.')),
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
              label: const Text('Day 242 Trusted Circle'),
              onPressed: () => context.push(AppRoutes.trustedCircleV2),
            ),
            ActionChip(
              label: const Text('Day 240 Section B'),
              onPressed: () =>
                  context.push(AppRoutes.sectionBCatchupMilestone),
            ),
            ActionChip(
              label: const Text('Day 238 Emergency #'),
              onPressed: () =>
                  context.push(AppRoutes.regionEmergencyNumbers),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Map widget ────────────────────────────────────────────────────────────────
class _JourneyMap extends StatelessWidget {
  const _JourneyMap({
    required this.mapController,
    required this.showRoute,
    this.destination,
    required this.currentPosition,
    this.showCurrentMarker = false,
    this.followCurrent = false,
  });

  final MapController mapController;
  final bool showRoute;
  final LatLng? destination;
  final LatLng currentPosition;
  final bool showCurrentMarker;
  final bool followCurrent;

  @override
  Widget build(BuildContext context) {
    if (followCurrent && showCurrentMarker) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        mapController.move(currentPosition, mapController.camera.zoom);
      });
    }

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

    if (showCurrentMarker) {
      markers.add(
        Marker(
          point: currentPosition,
          width: 44,
          height: 44,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF8B5CF6), width: 2),
            ),
            child: const Icon(
              Icons.navigation_rounded,
              color: Color(0xFF8B5CF6),
              size: 22,
            ),
          ),
        ),
      );
    }

    final polylines = <Polyline>[];
    if (showRoute && destination != null) {
      polylines.add(
        Polyline(
          points: [_kOrigin, destination!],
          color: const Color(0xFF8B5CF6).withOpacity(0.7),
          strokeWidth: 4,
        ),
      );
      if (showCurrentMarker) {
        polylines.add(
          Polyline(
            points: [_kOrigin, currentPosition],
            color: ZapColors.safe,
            strokeWidth: 5,
          ),
        );
      }
    }

    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: destination ?? _kOrigin,
        initialZoom: 11.5,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.zapsafe.zapsafe_mobile',
        ),
        if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
        MarkerLayer(markers: markers),
      ],
    );
  }
}

// ── Tiles ─────────────────────────────────────────────────────────────────────
class _DestinationTile extends StatelessWidget {
  const _DestinationTile({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _JourneyDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected
            ? const Color(0xFF8B5CF6).withOpacity(0.12)
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
                color: selected
                    ? const Color(0xFF8B5CF6)
                    : ZapColors.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: selected
                      ? const Color(0xFF8B5CF6)
                      : ZapColors.textMuted,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        destination.label,
                        style: TextStyle(
                          color: selected
                              ? ZapColors.textPrimary
                              : ZapColors.textSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        destination.subtitle,
                        style: const TextStyle(
                          color: ZapColors.textMuted,
                          fontSize: 11,
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
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.contact,
    required this.selected,
    required this.onTap,
  });

  final _JourneyContact contact;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tierColor = contact.tier == 'Tier 1'
        ? ZapColors.safe
        : ZapColors.warning;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected
            ? tierColor.withOpacity(0.1)
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
                color: selected ? tierColor : ZapColors.border,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: tierColor.withOpacity(0.2),
                  child: Text(
                    contact.name[0],
                    style: TextStyle(
                      color: tierColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.name,
                        style: const TextStyle(
                          color: ZapColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '${contact.relation} · ${contact.phone}',
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
                    color: tierColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    contact.tier,
                    style: TextStyle(
                      color: tierColor,
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
                          ? const Color(0xFF8B5CF6)
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
                        ? const Color(0xFF8B5CF6)
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
