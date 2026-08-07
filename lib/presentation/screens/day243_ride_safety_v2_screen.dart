/// Day 243 — Ride Safety Mode Polish
///
/// Section C (Days 241-260): ride safety v2 — vehicle + driver form, planned
/// route on map, mock live tracking, deviation simulation (>500m auto-SOS mock),
/// link to Day 86 escalation policy.
///
/// Tag: 🟣 POLISH · `flutter_map` route polyline · deviation QA.
///
/// Route: [AppRoutes.rideSafetyV2] → `/ride-safety-v2`
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

// ── Route constants ───────────────────────────────────────────────────────────
const _kRouteStart = LatLng(19.0760, 72.8777); // Mumbai CST
const _kDeviationThresholdM = 500;
const _kJsonEncoder = JsonEncoder.withIndent('  ');
const _kTabs = ['Setup', 'Ride', 'Safety'];
const _kRideAccent = Color(0xFFF59E0B);

const Distance _kDistance = Distance();

const _kDestinations = [
  _RideDestination(
    id: 'bandra',
    label: 'Bandra West',
    subtitle: 'Linking Road',
    latLng: LatLng(19.0596, 72.8295),
  ),
  _RideDestination(
    id: 'andheri',
    label: 'Andheri East',
    subtitle: 'Metro station',
    latLng: LatLng(19.1136, 72.8697),
  ),
  _RideDestination(
    id: 'airport',
    label: 'CSMIA T2',
    subtitle: 'Mumbai Airport',
    latLng: LatLng(19.0997, 72.8750),
  ),
  _RideDestination(
    id: 'pune',
    label: 'Pune Junction',
    subtitle: 'Railway station',
    latLng: LatLng(18.5314, 73.8740),
  ),
];

// ── Models ────────────────────────────────────────────────────────────────────
class _RideDestination {
  const _RideDestination({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.latLng,
  });

  final String id;
  final String label;
  final String subtitle;
  final LatLng latLng;
}

enum _RideStatus { idle, active, deviated, autoSos }

extension _RideStatusX on _RideStatus {
  String get label => switch (this) {
        _RideStatus.idle => 'IDLE',
        _RideStatus.active => 'ON RIDE',
        _RideStatus.deviated => 'DEVIATION',
        _RideStatus.autoSos => 'AUTO-SOS',
      };

  Color get color => switch (this) {
        _RideStatus.idle => ZapColors.textMuted,
        _RideStatus.active => _kRideAccent,
        _RideStatus.deviated => ZapColors.warning,
        _RideStatus.autoSos => ZapColors.danger,
      };
}

// ── Providers ─────────────────────────────────────────────────────────────────
final _d243TabProvider = StateProvider<int>((ref) => 0);
final _d243VehicleProvider = StateProvider<String>((ref) => 'MH-02-AB-1234');
final _d243DriverProvider = StateProvider<String>((ref) => 'Rajesh Kumar');
final _d243DestinationProvider =
    StateProvider<_RideDestination>((ref) => _kDestinations.first);
final _d243RideActiveProvider = StateProvider<bool>((ref) => false);
final _d243ProgressProvider = StateProvider<double>((ref) => 0);
final _d243CurrentPositionProvider =
    StateProvider<LatLng>((ref) => _kRouteStart);
final _d243DeviationMetersProvider = StateProvider<double>((ref) => 0);
final _d243RideStatusProvider =
    StateProvider<_RideStatus>((ref) => _RideStatus.idle);
final _d243RideStartedAtProvider = StateProvider<DateTime?>((ref) => null);
final _d243AutoSosAtProvider = StateProvider<DateTime?>((ref) => null);

// ── Helpers ───────────────────────────────────────────────────────────────────
LatLng _lerpLatLng(LatLng a, LatLng b, double t) {
  return LatLng(
    a.latitude + (b.latitude - a.latitude) * t,
    a.longitude + (b.longitude - a.longitude) * t,
  );
}

double _deviationFromRoute(LatLng point, LatLng start, LatLng end) {
  // Perpendicular distance to route segment (mock geodesic via latlong2).
  final routeLen = _kDistance.as(LengthUnit.Meter, start, end);
  if (routeLen < 1) {
    return _kDistance.as(LengthUnit.Meter, point, start);
  }

  final t = _projectT(point, start, end);
  final closest = _lerpLatLng(start, end, t);
  return _kDistance.as(LengthUnit.Meter, point, closest);
}

double _projectT(LatLng point, LatLng start, LatLng end) {
  final dx = end.longitude - start.longitude;
  final dy = end.latitude - start.latitude;
  if (dx == 0 && dy == 0) return 0;
  final px = point.longitude - start.longitude;
  final py = point.latitude - start.latitude;
  return (px * dx + py * dy) / (dx * dx + dy * dy).clamp(0.000001, double.infinity);
}

String _formatElapsed(DateTime? started) {
  if (started == null) return '—';
  final d = DateTime.now().difference(started);
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '${d.inHours > 0 ? '${d.inHours}:' : ''}$m:$s';
}

// ── Screen ────────────────────────────────────────────────────────────────────
class Day243RideSafetyV2Screen extends ConsumerStatefulWidget {
  const Day243RideSafetyV2Screen({super.key});

  @override
  ConsumerState<Day243RideSafetyV2Screen> createState() =>
      _Day243RideSafetyV2ScreenState();
}

class _Day243RideSafetyV2ScreenState
    extends ConsumerState<Day243RideSafetyV2Screen> {
  Timer? _rideTimer;
  Timer? _sosTimer;
  final _mapController = MapController();
  final _vehicleCtrl = TextEditingController(text: 'MH-02-AB-1234');
  final _driverCtrl = TextEditingController(text: 'Rajesh Kumar');

  @override
  void initState() {
    super.initState();
    _vehicleCtrl.addListener(() {
      ref.read(_d243VehicleProvider.notifier).state = _vehicleCtrl.text;
    });
    _driverCtrl.addListener(() {
      ref.read(_d243DriverProvider.notifier).state = _driverCtrl.text;
    });
  }

  @override
  void dispose() {
    _rideTimer?.cancel();
    _sosTimer?.cancel();
    _vehicleCtrl.dispose();
    _driverCtrl.dispose();
    super.dispose();
  }

  void _startRide() {
    final vehicle = _vehicleCtrl.text.trim();
    final driver = _driverCtrl.text.trim();
    if (vehicle.isEmpty || driver.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter vehicle number and driver name.'),
        ),
      );
      return;
    }

    ref.read(_d243RideActiveProvider.notifier).state = true;
    ref.read(_d243RideStatusProvider.notifier).state = _RideStatus.active;
    ref.read(_d243ProgressProvider.notifier).state = 0;
    ref.read(_d243CurrentPositionProvider.notifier).state = _kRouteStart;
    ref.read(_d243DeviationMetersProvider.notifier).state = 0;
    ref.read(_d243RideStartedAtProvider.notifier).state = DateTime.now();
    ref.read(_d243AutoSosAtProvider.notifier).state = null;
    ref.read(_d243TabProvider.notifier).state = 1;

    final dest = ref.read(_d243DestinationProvider);

    _rideTimer?.cancel();
    _rideTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted || !ref.read(_d243RideActiveProvider)) return;
      if (ref.read(_d243RideStatusProvider) == _RideStatus.autoSos) return;

      final progress = ref.read(_d243ProgressProvider);
      final next = math.min(1.0, progress + 0.05);
      final pos = _lerpLatLng(_kRouteStart, dest.latLng, next);

      ref.read(_d243ProgressProvider.notifier).state = next;
      ref.read(_d243CurrentPositionProvider.notifier).state = pos;

      if (ref.read(_d243RideStatusProvider) != _RideStatus.deviated) {
        ref.read(_d243DeviationMetersProvider.notifier).state =
            _deviationFromRoute(pos, _kRouteStart, dest.latLng);
      }

      if (next >= 1.0) {
        _endRide(arrived: true);
      } else {
        setState(() {});
      }
    });

    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Ride started · $vehicle · Driver $driver')),
    );
  }

  void _simulateDeviation() {
    if (!ref.read(_d243RideActiveProvider)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Start a ride first (Setup tab).')),
      );
      return;
    }

    final dest = ref.read(_d243DestinationProvider);
    final progress = ref.read(_d243ProgressProvider);
    final onRoute = _lerpLatLng(_kRouteStart, dest.latLng, progress);
    // Offset ~612m north-east off planned route for QA.
    final offRoute = LatLng(onRoute.latitude + 0.0055, onRoute.longitude + 0.002);
    final deviation = _deviationFromRoute(offRoute, _kRouteStart, dest.latLng);

    ref.read(_d243CurrentPositionProvider.notifier).state = offRoute;
    ref.read(_d243DeviationMetersProvider.notifier).state = deviation;
    ref.read(_d243RideStatusProvider.notifier).state = _RideStatus.deviated;

    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Deviation simulated · ${deviation.round()}m off route '
          '(threshold ${_kDeviationThresholdM}m)',
        ),
        backgroundColor: ZapColors.warning,
      ),
    );

    if (deviation > _kDeviationThresholdM) {
      _scheduleAutoSos();
    }
    setState(() {});
  }

  void _scheduleAutoSos() {
    _sosTimer?.cancel();
    _sosTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted || !ref.read(_d243RideActiveProvider)) return;
      if (ref.read(_d243DeviationMetersProvider) <= _kDeviationThresholdM) {
        return;
      }
      ref.read(_d243RideStatusProvider.notifier).state = _RideStatus.autoSos;
      ref.read(_d243AutoSosAtProvider.notifier).state = DateTime.now();
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Auto-SOS triggered — escalation policy engaged (mock).'),
          backgroundColor: ZapColors.danger,
        ),
      );
      setState(() {});
    });
  }

  void _endRide({bool arrived = false}) {
    _rideTimer?.cancel();
    _sosTimer?.cancel();
    ref.read(_d243RideActiveProvider.notifier).state = false;
    ref.read(_d243RideStatusProvider.notifier).state = _RideStatus.idle;
    ref.read(_d243ProgressProvider.notifier).state = 0;
    ref.read(_d243CurrentPositionProvider.notifier).state = _kRouteStart;
    ref.read(_d243DeviationMetersProvider.notifier).state = 0;
    ref.read(_d243RideStartedAtProvider.notifier).state = null;
    ref.read(_d243AutoSosAtProvider.notifier).state = null;

    if (!mounted) return;
    final msg = arrived
        ? 'Arrived at destination — ride ended safely.'
        : 'Ride ended.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(_d243TabProvider);
    final status = ref.watch(_d243RideStatusProvider);
    final rideActive = ref.watch(_d243RideActiveProvider);
    final deviation = ref.watch(_d243DeviationMetersProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 243 · Ride Safety v2'),
        actions: [
          if (rideActive)
            Padding(
              padding: const EdgeInsets.only(right: ZapSpacing.md),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: status.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: status.color.withOpacity(0.45)),
                  ),
                  child: Text(
                    status.label,
                    style: TextStyle(
                      color: status.color,
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
          if (rideActive && deviation > _kDeviationThresholdM)
            _DeviationAlertBanner(
              deviationMeters: deviation,
              autoSos: status == _RideStatus.autoSos,
            ),
          _TabBar(
            tab: tab,
            onSelect: (i) => ref.read(_d243TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (tab) {
              0 => _SetupTab(
                  vehicleCtrl: _vehicleCtrl,
                  driverCtrl: _driverCtrl,
                  mapController: _mapController,
                  onStart: _startRide,
                ),
              1 => _RideTab(
                  mapController: _mapController,
                  onSimulateDeviation: _simulateDeviation,
                  onEndRide: () => _endRide(),
                ),
              _ => const _SafetyTab(),
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
    required this.deviationMeters,
    required this.autoSos,
  });

  final double deviationMeters;
  final bool autoSos;

  @override
  Widget build(BuildContext context) {
    final color = autoSos ? ZapColors.danger : ZapColors.warning;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: ZapSpacing.lg,
        vertical: ZapSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        border: Border(bottom: BorderSide(color: color.withOpacity(0.45))),
      ),
      child: Row(
        children: [
          Icon(
            autoSos ? Icons.emergency_rounded : Icons.warning_amber_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              autoSos
                  ? 'AUTO-SOS ACTIVE · ${deviationMeters.round()}m off route · '
                      'Tier 1 notified (mock)'
                  : 'Route deviation · ${deviationMeters.round()}m > '
                      '${_kDeviationThresholdM}m · Auto-SOS in 5s (mock)',
              style: TextStyle(
                color: color,
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

// ── Tab 0: Setup ──────────────────────────────────────────────────────────────
class _SetupTab extends ConsumerWidget {
  const _SetupTab({
    required this.vehicleCtrl,
    required this.driverCtrl,
    required this.mapController,
    required this.onStart,
  });

  final TextEditingController vehicleCtrl;
  final TextEditingController driverCtrl;
  final MapController mapController;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destination = ref.watch(_d243DestinationProvider);
    final rideActive = ref.watch(_d243RideActiveProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _kRideAccent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _kRideAccent.withOpacity(0.35)),
          ),
          child: const Text(
            '🟣 POLISH · Section C Day 3/20 · vehicle + driver · planned route · '
            '500m deviation auto-SOS',
            style: TextStyle(color: _kRideAccent, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        SizedBox(
          height: 180,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _RideMap(
              mapController: mapController,
              destination: destination.latLng,
              currentPosition: _kRouteStart,
              showLiveMarker: false,
              deviationMeters: 0,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Vehicle details',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        TextField(
          controller: vehicleCtrl,
          enabled: !rideActive,
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(color: ZapColors.textPrimary),
          decoration: _fieldDecoration(
            hint: 'MH-02-AB-1234',
            icon: Icons.directions_car_rounded,
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        TextField(
          controller: driverCtrl,
          enabled: !rideActive,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(color: ZapColors.textPrimary),
          decoration: _fieldDecoration(
            hint: 'Driver full name',
            icon: Icons.person_rounded,
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Destination',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        ..._kDestinations.map(
          (d) => _DestinationTile(
            destination: d,
            selected: destination.id == d.id,
            disabled: rideActive,
            onTap: () {
              ref.read(_d243DestinationProvider.notifier).state = d;
              mapController.move(
                LatLng(
                  (_kRouteStart.latitude + d.latLng.latitude) / 2,
                  (_kRouteStart.longitude + d.latLng.longitude) / 2,
                ),
                11,
              );
            },
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: rideActive ? null : onStart,
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(rideActive ? 'Ride in progress' : 'Start ride'),
            style: FilledButton.styleFrom(
              backgroundColor: _kRideAccent,
              disabledBackgroundColor: ZapColors.textMuted.withOpacity(0.2),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: ZapColors.textMuted),
      prefixIcon: Icon(icon, color: ZapColors.textMuted),
      filled: true,
      fillColor: ZapColors.bgCard,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: ZapColors.border),
      ),
    );
  }
}

// ── Tab 1: Ride ───────────────────────────────────────────────────────────────
class _RideTab extends ConsumerWidget {
  const _RideTab({
    required this.mapController,
    required this.onSimulateDeviation,
    required this.onEndRide,
  });

  final MapController mapController;
  final VoidCallback onSimulateDeviation;
  final VoidCallback onEndRide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rideActive = ref.watch(_d243RideActiveProvider);
    final destination = ref.watch(_d243DestinationProvider);
    final vehicle = ref.watch(_d243VehicleProvider);
    final driver = ref.watch(_d243DriverProvider);
    final progress = ref.watch(_d243ProgressProvider);
    final current = ref.watch(_d243CurrentPositionProvider);
    final deviation = ref.watch(_d243DeviationMetersProvider);
    final status = ref.watch(_d243RideStatusProvider);
    final startedAt = ref.watch(_d243RideStartedAtProvider);

    if (!rideActive) {
      return ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          Icon(
            Icons.local_taxi_rounded,
            size: 64,
            color: ZapColors.textMuted.withOpacity(0.35),
          ),
          const SizedBox(height: ZapSpacing.lg),
          const Text(
            'No active ride',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'Enter vehicle number and driver name on Setup, then start the ride.',
            textAlign: TextAlign.center,
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: ZapSpacing.lg),
          Center(
            child: OutlinedButton.icon(
              onPressed: () => ref.read(_d243TabProvider.notifier).state = 0,
              icon: const Icon(Icons.edit_rounded),
              label: const Text('Go to Setup'),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Expanded(
          child: _RideMap(
            mapController: mapController,
            destination: destination.latLng,
            currentPosition: current,
            showLiveMarker: true,
            deviationMeters: deviation,
            followCurrent: true,
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.lg),
          decoration: const BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(top: BorderSide(color: ZapColors.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _kRideAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.local_taxi_rounded,
                      color: _kRideAccent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vehicle,
                          style: const TextStyle(
                            color: ZapColors.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          'Driver: $driver · → ${destination.label}',
                          style: const TextStyle(
                            color: ZapColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatElapsed(startedAt),
                        style: const TextStyle(
                          color: ZapColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        status.label,
                        style: TextStyle(
                          color: status.color,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: ZapSpacing.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: ZapColors.bgPrimary,
                  color: deviation > _kDeviationThresholdM
                      ? ZapColors.danger
                      : _kRideAccent,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    '${(progress * 100).round()}% route',
                    style: const TextStyle(
                      color: ZapColors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Off route: ${deviation.round()}m',
                    style: TextStyle(
                      color: deviation > _kDeviationThresholdM
                          ? ZapColors.danger
                          : ZapColors.textMuted,
                      fontSize: 10,
                      fontWeight: deviation > _kDeviationThresholdM
                          ? FontWeight.w800
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ZapSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onSimulateDeviation,
                      icon: const Icon(Icons.alt_route_rounded, size: 18),
                      label: const Text('Simulate deviation'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ZapColors.warning,
                        side: const BorderSide(color: ZapColors.warning),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: onEndRide,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ZapColors.danger,
                      side: const BorderSide(color: ZapColors.danger),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('End ride'),
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

// ── Tab 2: Safety ─────────────────────────────────────────────────────────────
class _SafetyTab extends ConsumerWidget {
  const _SafetyTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicle = ref.watch(_d243VehicleProvider);
    final driver = ref.watch(_d243DriverProvider);
    final destination = ref.watch(_d243DestinationProvider);
    final rideActive = ref.watch(_d243RideActiveProvider);
    final deviation = ref.watch(_d243DeviationMetersProvider);
    final status = ref.watch(_d243RideStatusProvider);
    final startedAt = ref.watch(_d243RideStartedAtProvider);
    final autoSosAt = ref.watch(_d243AutoSosAtProvider);

    final payload = {
      'feature': 'ride_safety_v2',
      'version': '2.0.0',
      'section': 'C',
      'day': 243,
      'ride_active': rideActive,
      'vehicle_number': vehicle,
      'driver_name': driver,
      'destination': {
        'label': destination.label,
        'lat': destination.latLng.latitude,
        'lng': destination.latLng.longitude,
      },
      'route_start': {
        'lat': _kRouteStart.latitude,
        'lng': _kRouteStart.longitude,
      },
      'deviation_threshold_meters': _kDeviationThresholdM,
      'current_deviation_meters': deviation.round(),
      'ride_status': status.name,
      'auto_sos_at': autoSosAt?.toIso8601String(),
      'ride_started_at': startedAt?.toIso8601String(),
      'escalation_policy_route': AppRoutes.escalationPoliciesV2,
      'map_provider': 'OpenStreetMap via flutter_map',
    };

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: ZapColors.danger.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: ZapColors.danger.withOpacity(0.35)),
          ),
          child: const Text(
            '🟣 POLISH · Auto-SOS if route deviates >500m · links Day 86 escalation',
            style: TextStyle(color: ZapColors.danger, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Deviation policy',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        const _PolicyRow(
          icon: Icons.straighten_rounded,
          title: 'Threshold: 500 metres',
          subtitle:
              'GPS position compared to planned route polyline every tick (mock).',
        ),
        const _PolicyRow(
          icon: Icons.emergency_rounded,
          title: 'Auto-SOS on breach',
          subtitle:
              '5-second grace window then SOS + Tier 1 notify per escalation policy.',
        ),
        const _PolicyRow(
          icon: Icons.alt_route_rounded,
          title: 'QA: Simulate deviation',
          subtitle:
              'Ride tab button jumps ~600m off route to test alert + auto-SOS flow.',
        ),
        const SizedBox(height: ZapSpacing.md),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => context.push(AppRoutes.escalationPoliciesV2),
            icon: const Icon(Icons.policy_rounded),
            label: const Text('Day 86 · Escalation policy'),
            style: FilledButton.styleFrom(
              backgroundColor: ZapColors.info,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
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
              const SnackBar(content: Text('Ride safety JSON copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy ride JSON'),
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

// ── Map ───────────────────────────────────────────────────────────────────────
class _RideMap extends StatelessWidget {
  const _RideMap({
    required this.mapController,
    required this.destination,
    required this.currentPosition,
    required this.showLiveMarker,
    required this.deviationMeters,
    this.followCurrent = false,
  });

  final MapController mapController;
  final LatLng destination;
  final LatLng currentPosition;
  final bool showLiveMarker;
  final double deviationMeters;
  final bool followCurrent;

  @override
  Widget build(BuildContext context) {
    if (followCurrent && showLiveMarker) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        mapController.move(currentPosition, mapController.camera.zoom);
      });
    }

    final offRoute = deviationMeters > _kDeviationThresholdM;
    final routeColor = offRoute ? ZapColors.danger : _kRideAccent;

    final markers = <Marker>[
      const Marker(
        point: _kRouteStart,
        width: 36,
        height: 36,
        child: Icon(Icons.trip_origin, color: ZapColors.safe, size: 28),
      ),
      Marker(
        point: destination,
        width: 36,
        height: 36,
        child: const Icon(
          Icons.flag_rounded,
          color: ZapColors.danger,
          size: 28,
        ),
      ),
    ];

    if (showLiveMarker) {
      markers.add(
        Marker(
          point: currentPosition,
          width: 44,
          height: 44,
          child: Container(
            decoration: BoxDecoration(
              color: routeColor.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: routeColor, width: 2),
            ),
            child: Icon(
              offRoute ? Icons.warning_rounded : Icons.local_taxi_rounded,
              color: routeColor,
              size: 22,
            ),
          ),
        ),
      );
    }

    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: LatLng(
          (_kRouteStart.latitude + destination.latitude) / 2,
          (_kRouteStart.longitude + destination.longitude) / 2,
        ),
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
        PolylineLayer(
          polylines: [
            Polyline(
              points: [_kRouteStart, destination],
              color: routeColor.withOpacity(0.55),
              strokeWidth: 4,
            ),
            if (showLiveMarker)
              Polyline(
                points: [_kRouteStart, currentPosition],
                color: routeColor,
                strokeWidth: 5,
              ),
          ],
        ),
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
    required this.disabled,
    required this.onTap,
  });

  final _RideDestination destination;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected
            ? _kRideAccent.withOpacity(0.12)
            : ZapColors.bgPrimary,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: disabled ? null : onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? _kRideAccent : ZapColors.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: selected ? _kRideAccent : ZapColors.textMuted,
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
                      color: selected ? _kRideAccent : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  _kTabs[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? _kRideAccent : ZapColors.textMuted,
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
