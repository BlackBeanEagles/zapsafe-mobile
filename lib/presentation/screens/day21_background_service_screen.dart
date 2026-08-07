import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../domain/providers/background_service_providers.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';
import '../widgets/zap_snackbar.dart';

/// Day 21 — Always-on safety engine (Android foreground service).
///
/// Drives `ZapSafeService.kt` via the `com.zapsafe/background_service`
/// method channel. The native side owns the lifecycle — this screen just
/// surfaces start / stop / status for emulator-test workflows.
class Day21BackgroundServiceScreen extends ConsumerStatefulWidget {
  const Day21BackgroundServiceScreen({super.key});

  @override
  ConsumerState<Day21BackgroundServiceScreen> createState() =>
      _Day21BackgroundServiceScreenState();
}

class _Day21BackgroundServiceScreenState
    extends ConsumerState<Day21BackgroundServiceScreen> {
  bool _busy = false;

  Future<void> _start() async {
    setState(() => _busy = true);
    try {
      final ok = await ref.read(backgroundServiceProvider).start();
      ref.invalidate(backgroundServiceRunningProvider);
      if (!mounted) return;
      if (ok) {
        ZapSnackbar.success(context,
            'Safety engine started · check your notification tray');
      } else {
        ZapSnackbar.warning(context,
            'Service not supported on this platform · Android only today');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop() async {
    setState(() => _busy = true);
    try {
      await ref.read(backgroundServiceProvider).stop();
      ref.invalidate(backgroundServiceRunningProvider);
      if (!mounted) return;
      ZapSnackbar.info(context, 'Safety engine stopped');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final svc = ref.watch(backgroundServiceProvider);
    final runningAsync = ref.watch(backgroundServiceRunningProvider);
    final running = runningAsync.valueOrNull ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Day 21 · Background Engine'),
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

              _StatusCard(
                supported: svc.supported,
                running: running,
                busy: _busy,
                onStart: _start,
                onStop: _stop,
                onRefresh: () => ref.invalidate(backgroundServiceRunningProvider),
              ),

              const SizedBox(height: ZapSpacing.xl),

              const _SectionLabel('ARCHITECTURE'),
              const SizedBox(height: ZapSpacing.md),
              _ArchitectureCard(),

              const SizedBox(height: ZapSpacing.xl),

              const _SectionLabel('PERSISTENT NOTIFICATION'),
              const SizedBox(height: ZapSpacing.md),
              _NotificationPreview(),

              const SizedBox(height: ZapSpacing.xl),

              const _SectionLabel('PLATFORM SETUP'),
              const SizedBox(height: ZapSpacing.md),
              _PlatformChecklist(),

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
            ZapColors.danger.withOpacity(0.10),
            ZapColors.warning.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.danger.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(ZapSpacing.sm),
                decoration: BoxDecoration(
                  color: ZapColors.danger.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shield_rounded,
                    color: ZapColors.danger, size: 22),
              ),
              const SizedBox(width: ZapSpacing.md),
              const ZapBadge(
                  label: 'MONTH 2 · WEEK 5 · DAY 21',
                  intent: ZapBadgeIntent.danger),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          Text(
            'Always-On Safety Engine',
            style: ZapTypography.displaySmall.copyWith(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            'Native Android foreground service · START_STICKY so it survives '
            'process death · persistent notification keeps the OS from killing '
            'us. DCS pipeline (audio + IMU + triggers) lands across Days 22–30.',
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

// ─── Status card ─────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final bool supported;
  final bool running;
  final bool busy;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onRefresh;

  const _StatusCard({
    required this.supported,
    required this.running,
    required this.busy,
    required this.onStart,
    required this.onStop,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor, statusIcon) = !supported
        ? ('UNSUPPORTED PLATFORM', ZapColors.textSecondary, Icons.devices_other_rounded)
        : running
            ? ('RUNNING', ZapColors.safe, Icons.check_circle_rounded)
            : ('STOPPED', ZapColors.warning, Icons.pause_circle_rounded);

    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 24),
              const SizedBox(width: ZapSpacing.sm),
              Text(
                statusLabel,
                style: ZapTypography.headlineSmall.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: busy ? null : onRefresh,
                tooltip: 'Refresh status',
              ),
            ],
          ),
          if (!supported) ...[
            const SizedBox(height: ZapSpacing.sm),
            Text(
              'Native foreground service only available on Android today. '
              'iOS gets a BGProcessingTask + silent-push watchdog on Day 22; '
              'web/desktop are out of scope for the safety engine.',
              style: ZapTypography.bodySmall.copyWith(
                color: ZapColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: ZapSpacing.lg),
          Row(
            children: [
              Expanded(
                child: ZapButton.elevated(
                  label: 'START',
                  icon: Icons.play_arrow_rounded,
                  intent: ZapButtonIntent.safe,
                  onPressed:
                      (supported && !running && !busy) ? onStart : null,
                  isLoading: busy && !running,
                ),
              ),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: ZapButton.outlined(
                  label: 'STOP',
                  icon: Icons.stop_rounded,
                  intent: ZapButtonIntent.danger,
                  onPressed:
                      (supported && running && !busy) ? onStop : null,
                  isLoading: busy && running,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Architecture explainer ──────────────────────────────────────────────────

class _ArchitectureCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final rows = <(String, IconData, String, Color)>[
      (
        'MainActivity.kt',
        Icons.flutter_dash_rounded,
        'Owns the MethodChannel · forwards start/stop/isRunning to the service.',
        ZapColors.info,
      ),
      (
        'ZapSafeService.kt',
        Icons.shield_rounded,
        'Foreground service · START_STICKY · DCS pipeline placeholder.',
        ZapColors.danger,
      ),
      (
        'BackgroundService (Dart)',
        Icons.code_rounded,
        'Type-safe façade · returns false off Android · cached running state.',
        ZapColors.safe,
      ),
      (
        'backgroundServiceProvider',
        Icons.swap_horiz_rounded,
        'Riverpod singleton + FutureProvider for the running flag.',
        ZapColors.warning,
      ),
    ];

    return ZapCard(
      child: Column(
        children: [
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: ZapSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: r.$4.withOpacity(0.15),
                      borderRadius:
                          BorderRadius.circular(ZapSpacing.radiusSmall),
                    ),
                    child: Icon(r.$2, color: r.$4, size: 18),
                  ),
                  const SizedBox(width: ZapSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.$1,
                          style: ZapTypography.bodyMedium.copyWith(
                            color: ZapColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          r.$3,
                          style: ZapTypography.bodySmall.copyWith(
                            color: ZapColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
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

// ─── Notification preview ────────────────────────────────────────────────────

class _NotificationPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: ZapColors.safe.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.shield_rounded,
                color: ZapColors.safe, size: 18),
          ),
          const SizedBox(width: ZapSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ZapSafe is protecting you',
                  style: ZapTypography.bodyMedium.copyWith(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Safety engine active · tap to open',
                  style: ZapTypography.bodySmall.copyWith(
                    color: ZapColors.textSecondary,
                  ),
                ),
                const SizedBox(height: ZapSpacing.xs),
                Text(
                  'Channel: zapsafe_foreground · Importance: LOW · ongoing',
                  style: ZapTypography.monoSmall.copyWith(
                    color: ZapColors.textSecondary,
                    fontSize: 11,
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

// ─── Platform checklist ──────────────────────────────────────────────────────

class _PlatformChecklist extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = <(String, bool, String?)>[
      ('FOREGROUND_SERVICE permission', true, null),
      ('FOREGROUND_SERVICE_MICROPHONE (Android 14+)', true, null),
      ('FOREGROUND_SERVICE_LOCATION (Android 14+)', true, null),
      ('FOREGROUND_SERVICE_DATA_SYNC (Android 14+)', true, null),
      ('Service registered in AndroidManifest.xml', true, null),
      ('foregroundServiceType="microphone|location|dataSync"', true, null),
      ('iOS BGProcessingTask + silent-push watchdog', false, 'Day 22'),
      ('Service auto-start after device reboot', false, 'Day 22 (BootReceiver)'),
    ];

    return ZapCard(
      child: Column(
        children: items.map((i) {
          final (label, done, deferredTo) = i;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: ZapSpacing.xs),
            child: Row(
              children: [
                Icon(
                  done
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: done ? ZapColors.safe : ZapColors.textSecondary,
                  size: 18,
                ),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    label,
                    style: ZapTypography.bodySmall.copyWith(
                      color: done
                          ? ZapColors.textPrimary
                          : ZapColors.textSecondary,
                    ),
                  ),
                ),
                if (!done && deferredTo != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: ZapColors.warning.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      deferredTo,
                      style: ZapTypography.labelSmall.copyWith(
                        color: ZapColors.warning,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Section label ───────────────────────────────────────────────────────────

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
