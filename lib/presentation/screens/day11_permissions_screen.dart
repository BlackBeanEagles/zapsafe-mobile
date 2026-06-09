import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/services/permission_service.dart';
import '../../domain/providers/permission_providers.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';
import '../widgets/zap_snackbar.dart';

// ─── Providers ────────────────────────────────────────────────────────────────
// Bug-fix pass — the canonical PermissionService instance lives in
// `permission_providers.dart` (Day 20 extracted it for test overrides).
// Day 11 used to create its own copy, which meant Day 11 debug surface and
// Day 12 onboarding screen could see divergent permission state.

final _permissionsResultProvider = FutureProvider<PermissionsResult>((ref) {
  return ref.watch(permissionServiceProvider).checkAll();
});

final _deviceInfoProvider = FutureProvider<DeviceBasicInfo>((ref) {
  return ref.watch(permissionServiceProvider).deviceInfo();
});

// ─── Screen ───────────────────────────────────────────────────────────────────

class Day11PermissionsScreen extends ConsumerWidget {
  const Day11PermissionsScreen({super.key});

  static const _perms = [
    _PermMeta(
      id: 'microphone',
      icon: Icons.mic_rounded,
      name: 'Microphone',
      purpose: 'Audio capture + voice SOS trigger',
      impact: 'Voice trigger and audio evidence disabled',
      accent: ZapColors.danger,
    ),
    _PermMeta(
      id: 'locationAlways',
      icon: Icons.my_location_rounded,
      name: 'Location (Always)',
      purpose: 'Background GPS tracking during active SOS',
      impact: 'Real-time location sharing with contacts disabled',
      accent: ZapColors.warning,
    ),
    _PermMeta(
      id: 'camera',
      icon: Icons.camera_alt_rounded,
      name: 'Camera',
      purpose: 'Video evidence + blink-code trigger',
      impact: 'Video capture and blink-code trigger disabled',
      accent: ZapColors.info,
    ),
    _PermMeta(
      id: 'notifications',
      icon: Icons.notifications_rounded,
      name: 'Notifications',
      purpose: 'Push alerts for SOS updates and contact responses',
      impact: 'Silent operation — you may miss urgent updates',
      accent: ZapColors.safe,
    ),
    _PermMeta(
      id: 'activity',
      icon: Icons.directions_run_rounded,
      name: 'Physical Activity',
      purpose: 'IMU sensors for motion-triggered SOS',
      impact: 'Impact detection and motion triggers disabled',
      accent: ZapColors.info,
    ),
  ];

  PermissionOutcome _outcomeFor(PermissionsResult r, String id) {
    return switch (id) {
      'microphone'    => r.microphone,
      'locationAlways' => r.locationAlways,
      'camera'        => r.camera,
      'notifications' => r.notifications,
      _               => r.activityRecognition,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultAsync = ref.watch(_permissionsResultProvider);
    final deviceAsync = ref.watch(_deviceInfoProvider);
    final svc = ref.read(permissionServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Day 11 · Permissions'),
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

              // ─── Permission tiles ──────────────────────────────────────
              resultAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(ZapSpacing.xl),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (e, _) => _ErrorCard(message: e.toString()),
                data: (result) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (result.anyDenied)
                      _LimitedBanner(anyDeniedForever: result.anyDeniedForever),
                    if (result.anyDenied) const SizedBox(height: ZapSpacing.lg),
                    ..._perms.map((meta) => _PermTile(
                          meta: meta,
                          outcome: _outcomeFor(result, meta.id),
                        )),
                    const SizedBox(height: ZapSpacing.lg),
                    _ActionRow(
                      result: result,
                      onRequest: () async {
                        final res = await svc.requestAll();
                        ref.invalidate(_permissionsResultProvider);
                        if (!context.mounted) return;
                        if (res.allGranted) {
                          ZapSnackbar.success(context, 'All permissions granted — full safety features active');
                        } else if (res.anyDeniedForever) {
                          ZapSnackbar.warning(context, 'Some permissions blocked — tap "Open Settings" to fix');
                        } else {
                          ZapSnackbar.info(context, 'Some permissions still pending');
                        }
                      },
                      onOpenSettings: () => svc.openSettings(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: ZapSpacing.xxl),

              // ─── Device info ───────────────────────────────────────────
              const _SectionLabel('DEVICE INFO'),
              const SizedBox(height: ZapSpacing.md),
              deviceAsync.when(
                loading: () => const SizedBox(
                  height: 48,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => _ErrorCard(message: e.toString()),
                data: (info) => _DeviceInfoCard(info: info),
              ),

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

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _PermMeta {
  final String id;
  final IconData icon;
  final String name;
  final String purpose;
  final String impact;
  final Color accent;

  const _PermMeta({
    required this.id,
    required this.icon,
    required this.name,
    required this.purpose,
    required this.impact,
    required this.accent,
  });
}

class _HeroBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ZapColors.warning.withOpacity(0.12),
            ZapColors.info.withOpacity(0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.warning.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(ZapSpacing.sm),
                decoration: BoxDecoration(
                  color: ZapColors.warning.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.security_rounded, color: ZapColors.warning, size: 22),
              ),
              const SizedBox(width: ZapSpacing.md),
              const ZapBadge(label: 'WEEK 3 · DAY 11', intent: ZapBadgeIntent.warning),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          Text(
            'Permissions Service',
            style: ZapTypography.displaySmall.copyWith(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            'Five safety-critical permissions. Each maps to a specific '
            'ZapSafe feature — denied permissions degrade the app gracefully '
            'rather than blocking it entirely.',
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

class _LimitedBanner extends StatelessWidget {
  final bool anyDeniedForever;
  const _LimitedBanner({required this.anyDeniedForever});

  @override
  Widget build(BuildContext context) {
    final color = anyDeniedForever ? ZapColors.danger : ZapColors.warning;
    final msg = anyDeniedForever
        ? 'One or more permissions require manual approval in device Settings.'
        : 'Limited safety features active — some permissions not yet granted.';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ZapSpacing.md,
        vertical: ZapSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: color, size: 18),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Text(
              msg,
              style: ZapTypography.bodySmall.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermTile extends StatelessWidget {
  final _PermMeta meta;
  final PermissionOutcome outcome;
  const _PermTile({required this.meta, required this.outcome});

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor) = switch (outcome) {
      PermissionOutcome.granted       => ('GRANTED', ZapColors.safe),
      PermissionOutcome.denied        => ('DENIED', ZapColors.warning),
      PermissionOutcome.deniedForever => ('SETTINGS NEEDED', ZapColors.danger),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: ZapSpacing.md),
      child: ZapCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: meta.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              ),
              child: Icon(meta.icon, color: meta.accent, size: 22),
            ),
            const SizedBox(width: ZapSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          meta.name,
                          style: ZapTypography.headlineSmall.copyWith(
                            color: ZapColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          statusLabel,
                          style: ZapTypography.labelSmall.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: ZapSpacing.xs),
                  Text(
                    meta.purpose,
                    style: ZapTypography.bodySmall.copyWith(
                      color: ZapColors.textSecondary,
                    ),
                  ),
                  if (outcome != PermissionOutcome.granted) ...[
                    const SizedBox(height: ZapSpacing.xs),
                    Text(
                      '⚠ ${meta.impact}',
                      style: ZapTypography.bodySmall.copyWith(
                        color: ZapColors.warning,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final PermissionsResult result;
  final VoidCallback onRequest;
  final VoidCallback onOpenSettings;

  const _ActionRow({
    required this.result,
    required this.onRequest,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    if (result.allGranted) {
      return const ZapButton.elevated(
        label: 'ALL PERMISSIONS GRANTED',
        icon: Icons.check_circle_rounded,
        intent: ZapButtonIntent.safe,
        fullWidth: true,
        onPressed: null,
      );
    }

    return Column(
      children: [
        ZapButton.elevated(
          label: 'REQUEST PERMISSIONS',
          icon: Icons.security_rounded,
          intent: ZapButtonIntent.safe,
          fullWidth: true,
          onPressed: onRequest,
        ),
        if (result.anyDeniedForever) ...[
          const SizedBox(height: ZapSpacing.md),
          ZapButton.outlined(
            label: 'OPEN APP SETTINGS',
            icon: Icons.settings_rounded,
            intent: ZapButtonIntent.warning,
            fullWidth: true,
            onPressed: onOpenSettings,
          ),
        ],
      ],
    );
  }
}

class _DeviceInfoCard extends StatelessWidget {
  final DeviceBasicInfo info;
  const _DeviceInfoCard({required this.info});

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Model', info.model),
      ('Manufacturer', info.manufacturer),
      ('OS', info.osVersion),
    ];

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.border),
      ),
      child: Column(
        children: rows.map((r) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: ZapSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 110,
                  child: Text(
                    r.$1,
                    style: ZapTypography.labelMedium.copyWith(
                      color: ZapColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    r.$2,
                    style: ZapTypography.monoSmall.copyWith(
                      color: ZapColors.textPrimary,
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

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.danger.withOpacity(0.1),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: ZapColors.danger.withOpacity(0.3)),
      ),
      child: Text(
        message,
        style: ZapTypography.bodySmall.copyWith(color: ZapColors.danger),
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
