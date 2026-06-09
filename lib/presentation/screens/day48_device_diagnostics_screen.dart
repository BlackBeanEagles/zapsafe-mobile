import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/models/gps_sample.dart';
import '../../data/models/motion_features.dart';
import '../../data/services/model_bundle_service.dart';
import '../../data/services/phone_capability_detector.dart';
import '../../domain/providers/gps_providers.dart';
import '../../domain/providers/imu_providers.dart';
import '../../domain/providers/inference_providers.dart';
import '../../data/services/permission_service.dart';
import '../../domain/providers/permission_providers.dart';
import '../navigation/app_router.dart';
import '../widgets/zap_card.dart';

/// Day 48 — Device Diagnostics Screen.
///
/// Route: /device-diagnostics
///
/// Real-device health check: exercises IMU, GPS, phone capability probe,
/// model bundle status, and permission state in one place. Use this screen
/// on a physical device to verify the full sensor + ML pipeline is live.
class Day48DeviceDiagnosticsScreen extends ConsumerStatefulWidget {
  const Day48DeviceDiagnosticsScreen({super.key});

  @override
  ConsumerState<Day48DeviceDiagnosticsScreen> createState() =>
      _Day48DeviceDiagnosticsScreenState();
}

class _Day48DeviceDiagnosticsScreenState
    extends ConsumerState<Day48DeviceDiagnosticsScreen> {
  // ── IMU ──────────────────────────────────────────────────────────────────
  bool _imuRunning = false;

  // ── GPS ──────────────────────────────────────────────────────────────────
  bool _gpsRunning = false;
  GpsSample? _latestGps;
  StreamSubscription<GpsSample>? _gpsSub;

  // ── Phone capability ──────────────────────────────────────────────────────
  PhoneCapabilityTier? _tier;
  double? _probeMs;
  bool _probing = false;

  // ── Permissions ───────────────────────────────────────────────────────────
  Map<String, bool> _perms = {};
  bool _checkingPerms = false;

  @override
  void initState() {
    super.initState();
    _loadCachedTier();
    _checkPermissions();
  }

  @override
  void dispose() {
    _gpsSub?.cancel();
    if (_imuRunning) ref.read(imuServiceProvider).stop();
    if (_gpsRunning) ref.read(gpsServiceProvider).stop();
    super.dispose();
  }

  Future<void> _loadCachedTier() async {
    final t = await PhoneCapabilityDetector.cachedTier();
    if (mounted) setState(() => _tier = t);
  }

  Future<void> _probeCapability() async {
    setState(() => _probing = true);
    final r = await PhoneCapabilityDetector().detect(forceReprobe: true);
    if (mounted) {
      setState(() {
        _tier     = r.tier;
        _probeMs  = r.inferenceMs;
        _probing  = false;
      });
    }
  }

  Future<void> _toggleImu() async {
    final svc = ref.read(imuServiceProvider);
    if (_imuRunning) {
      await svc.stop();
      if (mounted) setState(() => _imuRunning = false);
    } else {
      final started = await svc.start();
      if (mounted) setState(() => _imuRunning = started);
    }
  }

  Future<void> _toggleGps() async {
    final svc = ref.read(gpsServiceProvider);
    if (_gpsRunning) {
      await _gpsSub?.cancel();
      _gpsSub = null;
      svc.stop();
      setState(() {
        _gpsRunning = false;
        _latestGps  = null;
      });
    } else {
      svc.start();
      _gpsSub = svc.samples.listen((s) {
        if (mounted) setState(() => _latestGps = s);
      });
      setState(() => _gpsRunning = true);
    }
  }

  Future<void> _checkPermissions() async {
    setState(() => _checkingPerms = true);
    try {
      final svc = ref.read(permissionServiceProvider);
      final r = await svc.checkAll();
      if (mounted) {
        setState(() {
          _perms = {
            'microphone':          r.microphone          == PermissionOutcome.granted,
            'locationAlways':      r.locationAlways      == PermissionOutcome.granted,
            'camera':              r.camera              == PermissionOutcome.granted,
            'notifications':       r.notifications       == PermissionOutcome.granted,
            'activityRecognition': r.activityRecognition == PermissionOutcome.granted,
          };
          _checkingPerms = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _checkingPerms = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final motionAsync = ref.watch(motionFeaturesStreamProvider);
    final bundleAsync = ref.watch(detectionEngineProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: ZapColors.bgPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: ZapColors.textPrimary),
          onPressed: () => context.go(AppRoutes.home),
        ),
        title: Row(
          children: [
            const Text('Device Diagnostics',
                style: TextStyle(color: ZapColors.textPrimary)),
            const SizedBox(width: ZapSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: ZapSpacing.sm, vertical: 2),
              decoration: BoxDecoration(
                color: ZapColors.info.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'DAY 48',
                style: ZapTypography.labelSmall.copyWith(
                  color: ZapColors.info,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: ZapColors.textSecondary),
            tooltip: 'Refresh all',
            onPressed: () {
              _checkPermissions();
              _loadCachedTier();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Phone capability ───────────────────────────────────────────
            _SectionLabel('PHONE CAPABILITY'),
            const SizedBox(height: ZapSpacing.sm),
            _CapabilityCard(
              tier: _tier,
              probeMs: _probeMs,
              probing: _probing,
              onProbe: _probeCapability,
            ),
            const SizedBox(height: ZapSpacing.xl),

            // ── Model bundle ───────────────────────────────────────────────
            _SectionLabel('MODEL BUNDLE'),
            const SizedBox(height: ZapSpacing.sm),
            _BundleStatusCard(bundleAsync: bundleAsync),
            const SizedBox(height: ZapSpacing.xl),

            // ── IMU ────────────────────────────────────────────────────────
            _SectionLabel('IMU · ACCELEROMETER + GYROSCOPE'),
            const SizedBox(height: ZapSpacing.sm),
            _ImuCard(
              running: _imuRunning,
              motionAsync: motionAsync,
              onToggle: _toggleImu,
            ),
            const SizedBox(height: ZapSpacing.xl),

            // ── GPS ────────────────────────────────────────────────────────
            _SectionLabel('GPS'),
            const SizedBox(height: ZapSpacing.sm),
            _GpsCard(
              running: _gpsRunning,
              latest: _latestGps,
              onToggle: _toggleGps,
            ),
            const SizedBox(height: ZapSpacing.xl),

            // ── Permissions ────────────────────────────────────────────────
            _SectionLabel('PERMISSIONS'),
            const SizedBox(height: ZapSpacing.sm),
            _PermissionsCard(
              perms: _perms,
              checking: _checkingPerms,
              onRecheck: _checkPermissions,
            ),
            const SizedBox(height: ZapSpacing.xxxl),
          ],
        ),
      ),
    );
  }
}

// ─── Phone capability card ────────────────────────────────────────────────────

class _CapabilityCard extends StatelessWidget {
  const _CapabilityCard({
    required this.tier,
    required this.probeMs,
    required this.probing,
    required this.onProbe,
  });

  final PhoneCapabilityTier? tier;
  final double? probeMs;
  final bool probing;
  final VoidCallback onProbe;

  Color get _color {
    switch (tier) {
      case PhoneCapabilityTier.high:   return ZapColors.safe;
      case PhoneCapabilityTier.medium: return ZapColors.warning;
      case PhoneCapabilityTier.low:    return ZapColors.danger;
      case null:                       return ZapColors.textMuted;
    }
  }

  String get _label {
    if (probing) return 'Probing…';
    switch (tier) {
      case PhoneCapabilityTier.high:   return 'HIGH';
      case PhoneCapabilityTier.medium: return 'MEDIUM';
      case PhoneCapabilityTier.low:    return 'LOW';
      case null:                       return 'NOT TESTED';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Row(
        children: [
          Icon(Icons.speed_rounded, color: _color, size: 22),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_label,
                    style: ZapTypography.labelMedium.copyWith(
                        color: _color, fontWeight: FontWeight.w700)),
                if (probeMs != null)
                  Text('${probeMs!.toStringAsFixed(1)} ms median inference',
                      style: ZapTypography.bodySmall.copyWith(
                          color: ZapColors.textSecondary,
                          fontFamily: 'IBMPlexMono')),
              ],
            ),
          ),
          if (probing)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: ZapColors.safe),
            )
          else
            TextButton(
              onPressed: onProbe,
              child: Text('Probe',
                  style: ZapTypography.labelSmall
                      .copyWith(color: ZapColors.safe)),
            ),
        ],
      ),
    );
  }
}

// ─── Model bundle status card ─────────────────────────────────────────────────

class _BundleStatusCard extends StatelessWidget {
  const _BundleStatusCard({required this.bundleAsync});
  final AsyncValue<ModelBundleResult> bundleAsync;

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: bundleAsync.when(
        loading: () => Row(
          children: [
            const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: ZapColors.safe)),
            const SizedBox(width: ZapSpacing.sm),
            Text('Loading bundle…',
                style: ZapTypography.bodySmall
                    .copyWith(color: ZapColors.textSecondary)),
          ],
        ),
        error: (e, _) => Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: ZapColors.danger, size: 18),
            const SizedBox(width: ZapSpacing.sm),
            Expanded(
              child: Text('Bundle error: $e',
                  style: ZapTypography.bodySmall
                      .copyWith(color: ZapColors.danger)),
            ),
          ],
        ),
        data: (bundle) => Row(
          children: [
            Icon(
              bundle.loadedAiCount > 0
                  ? Icons.memory_rounded
                  : Icons.tune_rounded,
              color: bundle.loadedAiCount > 0
                  ? ZapColors.safe
                  : ZapColors.warning,
              size: 18,
            ),
            const SizedBox(width: ZapSpacing.sm),
            Expanded(
              child: Text(
                '${bundle.loadedAiCount} AI  ·  '
                '${bundle.heuristicCount} Heuristic  ·  '
                '${bundle.totalSizeLabel}',
                style: ZapTypography.bodySmall.copyWith(
                    color: ZapColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── IMU card ─────────────────────────────────────────────────────────────────

class _ImuCard extends StatelessWidget {
  const _ImuCard({
    required this.running,
    required this.motionAsync,
    required this.onToggle,
  });

  final bool running;
  final AsyncValue<MotionFeatures> motionAsync;
  final AsyncCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.vibration_rounded,
                color: running ? ZapColors.safe : ZapColors.textMuted,
                size: 18,
              ),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: Text(
                  running ? 'IMU Active' : 'IMU Stopped',
                  style: ZapTypography.labelMedium.copyWith(
                    color: running ? ZapColors.safe : ZapColors.textMuted,
                  ),
                ),
              ),
              TextButton(
                onPressed: onToggle,
                child: Text(
                  running ? 'Stop' : 'Start',
                  style: ZapTypography.labelSmall.copyWith(
                    color: running ? ZapColors.warning : ZapColors.safe,
                  ),
                ),
              ),
            ],
          ),
          if (running) ...[
            const SizedBox(height: ZapSpacing.xs),
            motionAsync.when(
              loading: () => Text('Waiting for first sample…',
                  style: ZapTypography.bodySmall.copyWith(
                      color: ZapColors.textSecondary)),
              error: (e, _) => Text('IMU error: $e',
                  style: ZapTypography.bodySmall.copyWith(
                      color: ZapColors.danger)),
              data: (f) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MonoRow('accel peak',
                      '${f.accelPeak.toStringAsFixed(2)} m/s²'),
                  _MonoRow('accel mean',
                      '${f.accelMean.toStringAsFixed(2)} m/s²'),
                  _MonoRow('gyro peak',
                      '${f.gyroPeak.toStringAsFixed(3)} rad/s'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── GPS card ────────────────────────────────────────────────────────────────

class _GpsCard extends StatelessWidget {
  const _GpsCard({
    required this.running,
    required this.latest,
    required this.onToggle,
  });

  final bool running;
  final GpsSample? latest;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.gps_fixed_rounded,
                color: running ? ZapColors.safe : ZapColors.textMuted,
                size: 18,
              ),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: Text(
                  running
                      ? latest != null
                          ? 'Fix acquired'
                          : 'Waiting for fix…'
                      : 'GPS Stopped',
                  style: ZapTypography.labelMedium.copyWith(
                    color: running
                        ? latest != null
                            ? ZapColors.safe
                            : ZapColors.warning
                        : ZapColors.textMuted,
                  ),
                ),
              ),
              TextButton(
                onPressed: onToggle,
                child: Text(
                  running ? 'Stop' : 'Start',
                  style: ZapTypography.labelSmall.copyWith(
                    color: running ? ZapColors.warning : ZapColors.safe,
                  ),
                ),
              ),
            ],
          ),
          if (running && latest != null) ...[
            const SizedBox(height: ZapSpacing.xs),
            _MonoRow('lat', latest!.lat.toStringAsFixed(6)),
            _MonoRow('lng', latest!.lng.toStringAsFixed(6)),
            _MonoRow('accuracy', '${latest!.accuracyM.toStringAsFixed(1)} m'),
          ],
        ],
      ),
    );
  }
}

// ─── Permissions card ─────────────────────────────────────────────────────────

class _PermissionsCard extends StatelessWidget {
  const _PermissionsCard({
    required this.perms,
    required this.checking,
    required this.onRecheck,
  });

  final Map<String, bool> perms;
  final bool checking;
  final VoidCallback onRecheck;

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                perms.values.every((v) => v)
                    ? Icons.lock_open_rounded
                    : Icons.lock_rounded,
                color: perms.values.every((v) => v)
                    ? ZapColors.safe
                    : ZapColors.warning,
                size: 18,
              ),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: Text(
                  checking
                      ? 'Checking permissions…'
                      : perms.isEmpty
                          ? 'No permissions found'
                          : '${perms.values.where((v) => v).length}/${perms.length} granted',
                  style: ZapTypography.labelMedium.copyWith(
                      color: ZapColors.textPrimary),
                ),
              ),
              TextButton(
                onPressed: checking ? null : onRecheck,
                child: Text('Recheck',
                    style: ZapTypography.labelSmall.copyWith(
                        color: ZapColors.safe)),
              ),
            ],
          ),
          if (!checking && perms.isNotEmpty) ...[
            const SizedBox(height: ZapSpacing.xs),
            ...perms.entries.map((e) => _PermRow(name: e.key, granted: e.value)),
          ],
        ],
      ),
    );
  }
}

class _PermRow extends StatelessWidget {
  const _PermRow({required this.name, required this.granted});
  final String name;
  final bool granted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            granted ? Icons.check_rounded : Icons.close_rounded,
            size: 14,
            color: granted ? ZapColors.safe : ZapColors.danger,
          ),
          const SizedBox(width: ZapSpacing.xs),
          Text(
            name,
            style: ZapTypography.bodySmall.copyWith(
              color: granted ? ZapColors.textPrimary : ZapColors.textSecondary,
              fontFamily: 'IBMPlexMono',
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: ZapTypography.labelSmall.copyWith(
          color: ZapColors.textSecondary,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w600,
        ),
      );
}

class _MonoRow extends StatelessWidget {
  const _MonoRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(
          children: [
            SizedBox(
              width: 88,
              child: Text(label,
                  style: ZapTypography.bodySmall.copyWith(
                      color: ZapColors.textSecondary)),
            ),
            Text(value,
                style: ZapTypography.bodySmall.copyWith(
                    color: ZapColors.textPrimary,
                    fontFamily: 'IBMPlexMono')),
          ],
        ),
      );
}
