import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/services/device_tier_service.dart';
import '../../data/services/permission_service.dart';
import '../../domain/providers/device_providers.dart';
import '../../domain/providers/feature_flags_provider.dart';
import '../../domain/providers/permission_providers.dart';
import '../navigation/app_router.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_button.dart';

/// Day 15 — Week 3 milestone review.
///
/// Consolidates the three Week 3 systems on one screen:
/// 1. Permissions (5 safety-critical) — status pulled from PermissionService.
/// 2. Device tier — pulled from deviceTierProvider.
/// 3. Feature flags — pulled from featureFlagsProvider.
///
/// Acts as the "is Week 3 working end-to-end?" verification surface.
class Day15Week3ReviewScreen extends ConsumerStatefulWidget {
  const Day15Week3ReviewScreen({super.key});

  @override
  ConsumerState<Day15Week3ReviewScreen> createState() =>
      _Day15Week3ReviewScreenState();
}

class _Day15Week3ReviewScreenState
    extends ConsumerState<Day15Week3ReviewScreen> {
  PermissionsResult? _permissions;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    // Bug-fix: use the shared provider rather than a fresh instance.
    final res = await ref.read(permissionServiceProvider).checkAll();
    if (mounted) setState(() => _permissions = res);
  }

  @override
  Widget build(BuildContext context) {
    final tierAsync = ref.watch(deviceTierProvider);
    final flagsAsync = ref.watch(featureFlagsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Day 15 · Week 3 Review'),
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

              // ─── Permissions check ─────────────────────────────────────
              _ChecklistSection(
                title: 'PERMISSIONS · 5 SAFETY-CRITICAL',
                ctaLabel: 'OPEN PERMISSIONS',
                onCta: () => context.go(AppRoutes.onboardingPermissions),
                items: _permissions == null
                    ? const [_ChecklistItem.loading('Loading…')]
                    : [
                        _ChecklistItem(
                          label: 'Microphone',
                          ok: _permissions!.microphone == PermissionOutcome.granted,
                        ),
                        _ChecklistItem(
                          label: 'Location (Always)',
                          ok: _permissions!.locationAlways == PermissionOutcome.granted,
                        ),
                        _ChecklistItem(
                          label: 'Camera',
                          ok: _permissions!.camera == PermissionOutcome.granted,
                        ),
                        _ChecklistItem(
                          label: 'Notifications',
                          ok: _permissions!.notifications == PermissionOutcome.granted,
                        ),
                        _ChecklistItem(
                          label: 'Physical Activity',
                          ok: _permissions!.activityRecognition ==
                              PermissionOutcome.granted,
                        ),
                      ],
              ),

              const SizedBox(height: ZapSpacing.xl),

              // ─── Device tier ────────────────────────────────────────────
              tierAsync.when(
                loading: () => const _LoadingCard(label: 'Detecting device tier…'),
                error: (e, _) => _ErrorCard(message: e.toString()),
                data: (result) => _ChecklistSection(
                  title: 'DEVICE TIER',
                  ctaLabel: 'OPEN TIER DETAILS',
                  onCta: () => context.go(AppRoutes.deviceTier),
                  items: [
                    _ChecklistItem(
                      label: result.tier.label,
                      ok: true,
                    ),
                    _ChecklistItem(
                      label: '${result.model} · ${result.osVersion}',
                      ok: true,
                      muted: true,
                    ),
                    _ChecklistItem(
                      label: '${result.enabledFeatures.length} features enabled',
                      ok: true,
                      muted: true,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: ZapSpacing.xl),

              // ─── Feature flags ──────────────────────────────────────────
              flagsAsync.when(
                loading: () => const _LoadingCard(label: 'Building feature flags…'),
                error: (e, _) => _ErrorCard(message: e.toString()),
                data: (flags) => _ChecklistSection(
                  title: 'FEATURE FLAGS',
                  ctaLabel: 'OPEN FEATURE FLAGS',
                  onCta: () => context.go(AppRoutes.featureFlags),
                  items: [
                    _ChecklistItem(
                      label: '${flags.enabled.length} features available',
                      ok: true,
                    ),
                    _ChecklistItem(
                      label: '${flags.locked.length} features locked (upgrade)',
                      ok: true,
                      muted: true,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: ZapSpacing.xxl),
              _Summary(
                permissionsReady: _permissions?.allGranted ?? false,
                tierReady: tierAsync.hasValue,
                flagsReady: flagsAsync.hasValue,
              ),
              const SizedBox(height: ZapSpacing.xl),

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

// ─── Hero ─────────────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ZapColors.safe.withOpacity(0.14),
            ZapColors.info.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.safe.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(ZapSpacing.sm),
                decoration: BoxDecoration(
                  color: ZapColors.safe.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_rounded,
                    color: ZapColors.safe, size: 22),
              ),
              const SizedBox(width: ZapSpacing.md),
              const ZapBadge(
                label: 'WEEK 3 · DAY 15 OF 15',
                intent: ZapBadgeIntent.safe,
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          Text(
            'Week 3 Complete',
            style: ZapTypography.displaySmall.copyWith(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            'Permissions onboarding · Device tier detection · Tier-gated feature '
            'flags. Three systems landed this week — they wire together so the '
            'rest of the app can ask `canUse(Feature.x)` without thinking about tiers.',
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

// ─── Section primitives ──────────────────────────────────────────────────────

class _ChecklistSection extends StatelessWidget {
  final String title;
  final List<_ChecklistItem> items;
  final String ctaLabel;
  final VoidCallback onCta;

  const _ChecklistSection({
    required this.title,
    required this.items,
    required this.ctaLabel,
    required this.onCta,
  });

  @override
  Widget build(BuildContext context) {
    final passCount = items.where((i) => i.ok).length;
    final fail = items.any((i) => !i.ok && !i.loading);
    final headerColor = fail ? ZapColors.warning : ZapColors.safe;

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: ZapTypography.labelSmall.copyWith(
                    color: ZapColors.textSecondary,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.sm, vertical: 3),
                decoration: BoxDecoration(
                  color: headerColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$passCount / ${items.length}',
                  style: ZapTypography.labelSmall.copyWith(
                    color: headerColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          ...items.map((i) => Padding(
                padding: const EdgeInsets.symmetric(vertical: ZapSpacing.xs),
                child: Row(
                  children: [
                    Icon(
                      i.loading
                          ? Icons.hourglass_empty_rounded
                          : (i.ok
                              ? Icons.check_circle_rounded
                              : Icons.cancel_rounded),
                      size: 18,
                      color: i.loading
                          ? ZapColors.textSecondary
                          : (i.ok ? ZapColors.safe : ZapColors.warning),
                    ),
                    const SizedBox(width: ZapSpacing.sm),
                    Expanded(
                      child: Text(
                        i.label,
                        style: ZapTypography.bodySmall.copyWith(
                          color: i.muted || i.loading
                              ? ZapColors.textSecondary
                              : ZapColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: ZapSpacing.md),
          ZapButton.outlined(
            label: ctaLabel,
            icon: Icons.arrow_forward_rounded,
            onPressed: onCta,
            fullWidth: true,
          ),
        ],
      ),
    );
  }
}

class _ChecklistItem {
  final String label;
  final bool ok;
  final bool muted;
  final bool loading;
  const _ChecklistItem(
      {required this.label,
      required this.ok,
      this.muted = false})
      : loading = false;
  const _ChecklistItem.loading(this.label)
      : ok = false,
        muted = true,
        loading = true;
}

class _Summary extends StatelessWidget {
  final bool permissionsReady;
  final bool tierReady;
  final bool flagsReady;

  const _Summary({
    required this.permissionsReady,
    required this.tierReady,
    required this.flagsReady,
  });

  @override
  Widget build(BuildContext context) {
    final allReady = permissionsReady && tierReady && flagsReady;
    final color = allReady ? ZapColors.safe : ZapColors.warning;

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Icon(
            allReady ? Icons.verified_rounded : Icons.error_outline_rounded,
            color: color,
            size: 28,
          ),
          const SizedBox(width: ZapSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  allReady
                      ? 'Week 3 GREEN'
                      : 'Week 3 partially complete',
                  style: ZapTypography.headlineSmall.copyWith(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: ZapSpacing.xs),
                Text(
                  allReady
                      ? 'All three Week 3 systems are wired and responding.'
                      : 'Some Week 3 systems are missing inputs — '
                          'grant permissions to fully complete the milestone.',
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

class _LoadingCard extends StatelessWidget {
  final String label;
  const _LoadingCard({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.border),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: ZapSpacing.md),
          Text(label,
              style: ZapTypography.bodyMedium.copyWith(
                color: ZapColors.textSecondary,
              )),
        ],
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
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color: ZapColors.danger.withOpacity(0.1),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.danger.withOpacity(0.3)),
      ),
      child: Text(
        'Error: $message',
        style: ZapTypography.bodySmall.copyWith(color: ZapColors.danger),
      ),
    );
  }
}
