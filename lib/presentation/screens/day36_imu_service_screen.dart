import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/models/fall_event.dart';
import '../../data/models/motion_features.dart';
import '../../data/services/fall_detector.dart';
import '../../domain/providers/imu_providers.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';
import '../widgets/zap_snackbar.dart';

/// Day 36 — IMU service live surface.
///
/// Shows live accelerometer + gyroscope magnitudes, the most recent
/// `MotionFeatures` snapshot (450 ms window), the fall-detector phase,
/// and a log of detected falls.
///
/// The "SIMULATE FALL" button feeds synthetic samples directly into the
/// service via [ImuService.injectAccel] — useful on emulators / host VMs
/// where the live sensor stream is silent.
class Day36ImuServiceScreen extends ConsumerStatefulWidget {
  const Day36ImuServiceScreen({super.key});

  @override
  ConsumerState<Day36ImuServiceScreen> createState() =>
      _Day36ImuServiceScreenState();
}

class _Day36ImuServiceScreenState
    extends ConsumerState<Day36ImuServiceScreen> {
  Timer? _uiTicker;
  final List<FallEvent> _falls = [];
  MotionFeatures? _latest;

  ProviderSubscription<AsyncValue<MotionFeatures>>? _featuresSub;
  ProviderSubscription<AsyncValue<FallEvent>>? _fallsSub;

  @override
  void initState() {
    super.initState();
    // 30 fps tick for the live magnitude readout (the live values are
    // simple getters on the service — no provider invalidation needed).
    _uiTicker = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (mounted) setState(() {});
    });

    _featuresSub = ref.listenManual<AsyncValue<MotionFeatures>>(
      motionFeaturesStreamProvider,
      (_, next) {
        next.whenData((f) {
          if (!mounted) return;
          setState(() => _latest = f);
        });
      },
    );
    _fallsSub = ref.listenManual<AsyncValue<FallEvent>>(
      fallEventStreamProvider,
      (_, next) {
        next.whenData((e) {
          if (!mounted) return;
          setState(() {
            _falls.insert(0, e);
            if (_falls.length > 6) _falls.removeRange(6, _falls.length);
          });
          ZapSnackbar.warning(
            context,
            'FALL detected · peak ${e.peakAccelMagnitude.toStringAsFixed(1)} m/s²',
          );
        });
      },
    );
  }

  @override
  void dispose() {
    _uiTicker?.cancel();
    _featuresSub?.close();
    _fallsSub?.close();
    super.dispose();
  }

  Future<void> _start() async {
    final ok = await ref.read(imuServiceProvider).start();
    if (!mounted) return;
    if (ok) {
      ZapSnackbar.success(context, 'IMU service running');
    } else {
      ZapSnackbar.warning(context, 'IMU unavailable on this platform');
    }
  }

  Future<void> _stop() async {
    await ref.read(imuServiceProvider).stop();
    if (mounted) ZapSnackbar.info(context, 'IMU service stopped');
  }

  /// Inject a synthetic fall sequence: 8 low-g samples (~250 ms freefall)
  /// then a single 30 m/s² impact spike. Uses [ImuService.injectAccel]
  /// so this works even on a host VM where the real sensors are silent.
  Future<void> _simulateFall() async {
    final svc = ref.read(imuServiceProvider);
    final baseTs = DateTime.now().millisecondsSinceEpoch;
    // Freefall phase: 8 samples at ~30 ms spacing → 240 ms total.
    // Per-sample magnitude near 0.1 g so the detector sees < 0.3 g hold.
    for (var i = 0; i < 8; i++) {
      svc.injectAccel(0.5, 0.5, 0.2, timestampMs: baseTs + i * 30);
    }
    // Impact spike: well above 25 m/s².
    svc.injectAccel(20.0, 20.0, 15.0,
        timestampMs: baseTs + 8 * 30); // sqrt(20²+20²+15²) ≈ 32 m/s²
    if (!mounted) return;
    ZapSnackbar.info(
        context, 'Synthetic fall injected · freefall + impact');
  }

  @override
  Widget build(BuildContext context) {
    final svc = ref.watch(imuServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Day 36 · IMU Service'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(ZapSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeroBanner(),
              const SizedBox(height: ZapSpacing.xl),

              const _SectionLabel('LIVE READOUT'),
              const SizedBox(height: ZapSpacing.md),
              _LiveReadoutCard(
                isRunning: svc.isRunning,
                accelMag: svc.liveAccelMagnitude,
                gyroMag: svc.liveGyroMagnitude,
                detectorState: svc.detectorState,
              ),

              const SizedBox(height: ZapSpacing.xl),

              Row(
                children: [
                  Expanded(
                    child: ZapButton.elevated(
                      label: 'START',
                      icon: Icons.play_arrow_rounded,
                      intent: ZapButtonIntent.safe,
                      onPressed: svc.isRunning ? null : _start,
                    ),
                  ),
                  const SizedBox(width: ZapSpacing.sm),
                  Expanded(
                    child: ZapButton.outlined(
                      label: 'STOP',
                      icon: Icons.stop_rounded,
                      intent: ZapButtonIntent.warning,
                      onPressed: svc.isRunning ? _stop : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ZapSpacing.sm),
              ZapButton.outlined(
                label: 'SIMULATE FALL (synthetic samples)',
                icon: Icons.bolt_rounded,
                intent: ZapButtonIntent.danger,
                fullWidth: true,
                onPressed: _simulateFall,
              ),

              const SizedBox(height: ZapSpacing.xl),

              const _SectionLabel('FEATURE SNAPSHOT · 450 ms WINDOW'),
              const SizedBox(height: ZapSpacing.md),
              _FeaturesCard(features: _latest),

              const SizedBox(height: ZapSpacing.xl),

              const _SectionLabel('FALL LOG · NEWEST FIRST'),
              const SizedBox(height: ZapSpacing.md),
              if (_falls.isEmpty)
                const _EmptyCard(
                  message: 'No falls detected yet. Tap SIMULATE FALL '
                      'or drop the phone (carefully, on a soft surface).',
                )
              else
                Column(children: [
                  for (final e in _falls) _FallRow(event: e),
                ]),

              const SizedBox(height: ZapSpacing.xxl),

              ZapButton.outlined(
                label: 'BACK TO INDEX',
                icon: Icons.arrow_back_rounded,
                fullWidth: true,
                onPressed: () => context.go('/'),
              ),
              const SizedBox(height: ZapSpacing.huge),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Hero ────────────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ZapColors.info.withOpacity(0.12),
            ZapColors.safe.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.info.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(ZapSpacing.sm),
                decoration: BoxDecoration(
                  color: ZapColors.info.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.vibration_rounded,
                    color: ZapColors.info, size: 22),
              ),
              const SizedBox(width: ZapSpacing.md),
              const ZapBadge(
                  label: 'MONTH 2 · WEEK 8 · DAY 36',
                  intent: ZapBadgeIntent.info),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          Text(
            'IMU Service · Fall Detection',
            style: ZapTypography.displaySmall.copyWith(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            'sensors_plus accelerometer + gyroscope · 450 ms feature window '
            'feeds MotionFeatures into the DCS engine · fall detector '
            'requires < 0.3 g for ≥ 200 ms followed by > 25 m/s² spike.',
            style: ZapTypography.bodyMedium.copyWith(
              color: ZapColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Live readout card ───────────────────────────────────────────────────────

class _LiveReadoutCard extends StatelessWidget {
  final bool isRunning;
  final double accelMag;
  final double gyroMag;
  final FallDetectorState detectorState;
  const _LiveReadoutCard({
    required this.isRunning,
    required this.accelMag,
    required this.gyroMag,
    required this.detectorState,
  });

  @override
  Widget build(BuildContext context) {
    final (chipLabel, chipColor) = switch (detectorState) {
      FallDetectorState.idle              => ('IDLE', ZapColors.safe),
      FallDetectorState.possibleFreefall  => ('POSSIBLE FREEFALL', ZapColors.warning),
      FallDetectorState.awaitingImpact    => ('AWAITING IMPACT', ZapColors.warning),
      FallDetectorState.impactDetected    => ('IMPACT', ZapColors.danger),
    };

    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isRunning ? Icons.sensors_rounded : Icons.sensors_off_rounded,
                color: isRunning ? ZapColors.safe : ZapColors.textSecondary,
                size: 22,
              ),
              const SizedBox(width: ZapSpacing.sm),
              Text(
                isRunning ? 'SERVICE RUNNING' : 'SERVICE IDLE',
                style: ZapTypography.labelMedium.copyWith(
                  color: isRunning ? ZapColors.safe : ZapColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.sm, vertical: 3),
                decoration: BoxDecoration(
                  color: chipColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  chipLabel,
                  style: ZapTypography.labelSmall.copyWith(
                    color: chipColor,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          _bar(
            label: 'ACCEL',
            value: accelMag,
            unit: 'm/s²',
            // Visual range: 0 → 30 m/s² covers gravity (~9.81) + impacts.
            max: 30,
            barColor: accelMag > FallDetector.impactThreshold
                ? ZapColors.danger
                : accelMag < FallDetector.freefallThreshold
                    ? ZapColors.warning
                    : ZapColors.safe,
          ),
          const SizedBox(height: ZapSpacing.sm),
          _bar(
            label: 'GYRO',
            value: gyroMag,
            unit: 'rad/s',
            // Visual range: 0 → 10 rad/s (≈ 570°/s — handles aggressive
            // wrist twists).
            max: 10,
            barColor: ZapColors.info,
          ),
        ],
      ),
    );
  }

  Widget _bar({
    required String label,
    required double value,
    required String unit,
    required double max,
    required Color barColor,
  }) {
    final clamped = (value / max).clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(
            label,
            style: ZapTypography.labelSmall.copyWith(
              color: ZapColors.textSecondary,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: clamped,
              minHeight: 12,
              backgroundColor: ZapColors.border,
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
        ),
        const SizedBox(width: ZapSpacing.sm),
        SizedBox(
          width: 80,
          child: Text(
            '${value.toStringAsFixed(2)} $unit',
            style: ZapTypography.monoSmall.copyWith(
              color: ZapColors.textPrimary,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

// ─── Features card ───────────────────────────────────────────────────────────

class _FeaturesCard extends StatelessWidget {
  final MotionFeatures? features;
  const _FeaturesCard({required this.features});

  @override
  Widget build(BuildContext context) {
    if (features == null) {
      return const _EmptyCard(
        message:
            'Waiting for first 450 ms window… (auto-emits once the buffer fills)',
      );
    }
    final f = features!;
    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row('accelMean', f.accelMean, 'm/s²'),
          _row('accelVar',  f.accelVar,  'm²/s⁴'),
          _row('accelPeak', f.accelPeak, 'm/s²'),
          _row('gyroMean',  f.gyroMean,  'rad/s'),
          _row('gyroVar',   f.gyroVar,   'rad²/s²'),
          _row('gyroPeak',  f.gyroPeak,  'rad/s'),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            't = ${f.timestampMs} (Δ = ${_msSince(f.timestampMs)} ms ago)',
            style: ZapTypography.monoSmall.copyWith(
              color: ZapColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  int _msSince(int ts) {
    final d = DateTime.now().millisecondsSinceEpoch - ts;
    return math.max(0, d);
  }

  Widget _row(String k, double v, String unit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              k,
              style: ZapTypography.labelSmall.copyWith(
                color: ZapColors.textSecondary,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '${v.toStringAsFixed(3)} $unit',
              style: ZapTypography.monoSmall.copyWith(
                color: ZapColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Fall row ────────────────────────────────────────────────────────────────

class _FallRow extends StatelessWidget {
  final FallEvent event;
  const _FallRow({required this.event});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ZapSpacing.xs),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: ZapSpacing.md, vertical: 6),
        decoration: BoxDecoration(
          color: ZapColors.bgCard,
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: ZapColors.danger.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: ZapColors.danger, size: 18),
            const SizedBox(width: ZapSpacing.sm),
            Expanded(
              child: Text(
                'peak ${event.peakAccelMagnitude.toStringAsFixed(1)} m/s² · '
                'freefall ${event.freefallDurationMs}ms · '
                't=${event.timestampMs}',
                style: ZapTypography.monoSmall.copyWith(
                  color: ZapColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty + Section ─────────────────────────────────────────────────────────

class _EmptyCard extends StatelessWidget {
  final String message;
  const _EmptyCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.border),
      ),
      child: Text(
        message,
        style: ZapTypography.bodySmall.copyWith(
          color: ZapColors.textSecondary,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: ZapTypography.labelSmall.copyWith(
            color: ZapColors.textSecondary,
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: ZapSpacing.md),
        const Expanded(child: Divider(color: ZapColors.border)),
      ],
    );
  }
}
