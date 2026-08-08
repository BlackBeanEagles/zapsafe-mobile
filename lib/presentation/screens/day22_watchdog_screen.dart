import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/services/ios_background_handler.dart';
import '../../domain/providers/background_service_providers.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';
import '../widgets/zap_snackbar.dart';

/// Day 22 — cross-platform watchdog overview.
///
/// Shows the side-by-side recovery strategy for keeping the safety engine
/// alive on Android (foreground service + BootReceiver) and iOS
/// (BGProcessingTask + silent-push watchdog), plus a live control for
/// re-scheduling the iOS BG task on-device.
class Day22WatchdogScreen extends ConsumerWidget {
  const Day22WatchdogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iosRegistered = ref.watch(iosBackgroundRegisteredProvider);
    final iosHandler = ref.watch(iosBackgroundHandlerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Day 22 · Watchdog'),
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

              _PlatformBadge(),
              const SizedBox(height: ZapSpacing.xl),

              const _SectionLabel('ANDROID · DAY 21 + DAY 22'),
              const SizedBox(height: ZapSpacing.md),
              _AndroidCard(),

              const SizedBox(height: ZapSpacing.xl),

              const _SectionLabel('iOS · DAY 22'),
              const SizedBox(height: ZapSpacing.md),
              _IosCard(
                registered: iosRegistered.valueOrNull,
                onScheduleNext: () async {
                  final ok = await iosHandler.scheduleNext();
                  if (!context.mounted) return;
                  if (ok) {
                    ZapSnackbar.success(
                        context, 'BGProcessingTask scheduled');
                  } else {
                    ZapSnackbar.warning(context,
                        Platform.isIOS
                            ? 'Scheduler refused — try again later'
                            : 'iOS-only · ignored on this platform');
                  }
                },
                onCancel: () async {
                  await iosHandler.cancel();
                  if (!context.mounted) return;
                  ZapSnackbar.info(context, 'Pending BGProcessingTask cancelled');
                },
              ),

              const SizedBox(height: ZapSpacing.xl),

              const _SectionLabel('STRATEGY COMPARISON'),
              const SizedBox(height: ZapSpacing.md),
              _ComparisonCard(),

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
            ZapColors.warning.withOpacity(0.04),
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
                child: const Icon(Icons.autorenew_rounded,
                    color: ZapColors.info, size: 22),
              ),
              const SizedBox(width: ZapSpacing.md),
              const ZapBadge(
                  label: 'MONTH 2 · WEEK 5 · DAY 22',
                  intent: ZapBadgeIntent.info),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          Text(
            'Cross-Platform Watchdog',
            style: ZapTypography.displaySmall.copyWith(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            'Two parallel recovery paths so the safety engine survives reboots, '
            'process kills, and OS-level throttling. Android: BootReceiver + '
            'foreground service. iOS: BGProcessingTask + silent-push watchdog.',
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

class _PlatformBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = Platform.isAndroid
        ? ('RUNNING ON ANDROID', ZapColors.safe, Icons.android_rounded)
        : Platform.isIOS
            ? ('RUNNING ON iOS', ZapColors.info, Icons.apple_rounded)
            : ('HOST VM', ZapColors.textSecondary, Icons.computer_rounded);

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: ZapSpacing.md, vertical: ZapSpacing.sm),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: ZapSpacing.sm),
          Text(
            label,
            style: ZapTypography.labelMedium.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Android card ────────────────────────────────────────────────────────────

class _AndroidCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row(
            Icons.check_circle_rounded,
            ZapColors.safe,
            'ZapSafeService · START_STICKY',
            'OS restarts the service automatically if killed while running.',
          ),
          _row(
            Icons.check_circle_rounded,
            ZapColors.safe,
            'BootReceiver · BOOT_COMPLETED + MY_PACKAGE_REPLACED',
            'Restarts the service after a device reboot or app upgrade.',
          ),
          _row(
            Icons.check_circle_rounded,
            ZapColors.safe,
            'Foreground notification on zapsafe_foreground channel',
            'Required for Android 8+ — keeps the OS from culling us.',
          ),
          _row(
            Icons.radio_button_unchecked_rounded,
            ZapColors.textSecondary,
            'WorkManager fallback watchdog (15-minute period)',
            'Restarts the service if it hasn\'t pinged in 30s. Lands Day 24.',
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, Color color, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ZapSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: ZapTypography.bodyMedium.copyWith(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
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
    );
  }
}

// ─── iOS card ────────────────────────────────────────────────────────────────

class _IosCard extends StatelessWidget {
  final bool? registered;
  final VoidCallback onScheduleNext;
  final VoidCallback onCancel;

  const _IosCard({
    required this.registered,
    required this.onScheduleNext,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final regColor = registered == true
        ? ZapColors.safe
        : (registered == false ? ZapColors.warning : ZapColors.textSecondary);
    final regLabel = registered == true
        ? 'REGISTERED'
        : (registered == false ? 'NOT REGISTERED' : 'OFF-iOS');

    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'BGTaskScheduler identifier',
                  style: ZapTypography.bodyMedium.copyWith(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.sm, vertical: 3),
                decoration: BoxDecoration(
                  color: regColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  regLabel,
                  style: ZapTypography.labelSmall.copyWith(
                    color: regColor,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            IosBackgroundHandler.taskIdentifier,
            style: ZapTypography.monoSmall.copyWith(
              color: ZapColors.info,
            ),
          ),
          const SizedBox(height: ZapSpacing.md),
          Text(
            'iOS doesn\'t allow indefinite foreground services. Instead, the '
            'OS runs the BGProcessingTask at intervals it chooses (no shorter '
            'than 15 minutes). The silent-push watchdog wakes us if iOS hasn\'t '
            'fired the task in a long while.',
            style: ZapTypography.bodySmall.copyWith(
              color: ZapColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: ZapSpacing.md),
          Row(
            children: [
              Expanded(
                child: ZapButton.elevated(
                  label: 'SCHEDULE NEXT',
                  icon: Icons.event_rounded,
                  intent: ZapButtonIntent.info,
                  // Bug-fix: disable off-iOS rather than firing a no-op snackbar.
                  onPressed: Platform.isIOS ? onScheduleNext : null,
                ),
              ),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: ZapButton.outlined(
                  label: 'CANCEL',
                  icon: Icons.cancel_rounded,
                  intent: ZapButtonIntent.warning,
                  onPressed: Platform.isIOS ? onCancel : null,
                ),
              ),
            ],
          ),
          if (!Platform.isIOS) ...[
            const SizedBox(height: ZapSpacing.sm),
            Text(
              'Buttons no-op outside iOS · Swift handler is registered '
              'from AppDelegate.application(_:didFinishLaunchingWithOptions:).',
              style: ZapTypography.bodySmall.copyWith(
                color: ZapColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Strategy comparison ─────────────────────────────────────────────────────

class _ComparisonCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final rows = <(String, String, String)>[
      ('Service lifetime',     'Indefinite (foreground service)', 'Capped: 30-second runs on schedule'),
      ('Restart-on-kill',      'START_STICKY · OS reanimates us',  'OS-decided next BGProcessingTask'),
      ('Restart-on-reboot',    'BootReceiver · BOOT_COMPLETED',    'BGTaskScheduler · OS re-schedules'),
      ('Watchdog fallback',    'WorkManager 15-min period · Day 24', 'Silent-push wake · Day 22'),
      ('SOS-time max latency', '<30 seconds',                       '<45 seconds (Apple cap)'),
    ];

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.border),
      ),
      child: Column(
        children: [
          // Header row
          Row(
            children: [
              const Expanded(flex: 3, child: SizedBox.shrink()),
              Expanded(
                flex: 3,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.android_rounded,
                        color: ZapColors.safe, size: 16),
                    const SizedBox(width: ZapSpacing.xs),
                    Text(
                      'ANDROID',
                      style: ZapTypography.labelSmall.copyWith(
                        color: ZapColors.safe,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.apple_rounded,
                        color: ZapColors.info, size: 16),
                    const SizedBox(width: ZapSpacing.xs),
                    Text(
                      'iOS',
                      style: ZapTypography.labelSmall.copyWith(
                        color: ZapColors.info,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(color: ZapColors.border),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: ZapSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      r.$1,
                      style: ZapTypography.labelSmall.copyWith(
                        color: ZapColors.textSecondary,
                        letterSpacing: 1.0,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      r.$2,
                      style: ZapTypography.bodySmall.copyWith(
                        color: ZapColors.textPrimary,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      r.$3,
                      style: ZapTypography.bodySmall.copyWith(
                        color: ZapColors.textPrimary,
                      ),
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
