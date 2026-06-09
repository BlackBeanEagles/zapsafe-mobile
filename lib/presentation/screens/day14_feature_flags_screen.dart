import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/services/device_tier_service.dart';
import '../../domain/providers/device_providers.dart';
import '../../domain/providers/feature_flags_provider.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_snackbar.dart';

/// Day 14 — Tier-gated feature flags.
///
/// Shows every feature the app knows about along with whether it's currently
/// available on this device. Locked features tap-to-explain why; if the
/// device upgrades to Tier A (e.g. user switches phones), the unlocked
/// features re-appear automatically because the provider reacts to
/// [deviceTierProvider].
class Day14FeatureFlagsScreen extends ConsumerWidget {
  const Day14FeatureFlagsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flagsAsync = ref.watch(featureFlagsProvider);
    final tierAsync = ref.watch(deviceTierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Day 14 · Feature Flags'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(ZapSpacing.lg),
          child: flagsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(ZapSpacing.huge),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => Text('Error: $e',
                style: ZapTypography.bodyMedium
                    .copyWith(color: ZapColors.danger)),
            data: (flags) => _Body(
              flags: flags,
              tier: tierAsync.valueOrNull?.tier ?? DeviceTier.tierB,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _Body extends StatelessWidget {
  final FeatureFlags flags;
  final DeviceTier tier;
  const _Body({required this.flags, required this.tier});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HeroBanner(flags: flags, tier: tier),
        const SizedBox(height: ZapSpacing.xl),

        _SectionLabel('ENABLED · ${flags.enabled.length}'),
        const SizedBox(height: ZapSpacing.md),
        ...flags.enabled.map((f) => _FeatureTile(feature: f, locked: false)),

        if (flags.locked.isNotEmpty) ...[
          const SizedBox(height: ZapSpacing.xl),
          _SectionLabel('LOCKED · ${flags.locked.length}'),
          const SizedBox(height: ZapSpacing.md),
          ...flags.locked.map((f) => _FeatureTile(feature: f, locked: true)),
        ],

        const SizedBox(height: ZapSpacing.xxl),
        ZapButton.outlined(
          label: 'BACK TO INDEX',
          icon: Icons.arrow_back_rounded,
          fullWidth: true,
          onPressed: () => context.go('/'),
        ),
        const SizedBox(height: ZapSpacing.huge),
      ],
    );
  }
}

class _HeroBanner extends StatelessWidget {
  final FeatureFlags flags;
  final DeviceTier tier;
  const _HeroBanner({required this.flags, required this.tier});

  @override
  Widget build(BuildContext context) {
    final color = switch (tier) {
      DeviceTier.tierA => ZapColors.safe,
      DeviceTier.tierB => ZapColors.warning,
      DeviceTier.tierC => ZapColors.info,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.12), color.withOpacity(0.04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(ZapSpacing.sm),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.flag_rounded, color: color, size: 22),
              ),
              const SizedBox(width: ZapSpacing.md),
              const ZapBadge(label: 'WEEK 3 · DAY 14', intent: ZapBadgeIntent.info),
              const SizedBox(width: ZapSpacing.sm),
              ZapBadge(
                label: tier.shortLabel,
                intent: switch (tier) {
                  DeviceTier.tierA => ZapBadgeIntent.safe,
                  DeviceTier.tierB => ZapBadgeIntent.warning,
                  DeviceTier.tierC => ZapBadgeIntent.info,
                },
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          Text(
            'Tier-Gated Features',
            style: ZapTypography.displaySmall.copyWith(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            'Every screen asks `featureFlags.canUse(Feature.x)` before showing '
            'a tier-gated feature. Locked features show an "Upgrade available" '
            'tooltip rather than disappearing — the user always knows what\'s '
            'on the table.',
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

class _FeatureTile extends StatelessWidget {
  final Feature feature;
  final bool locked;
  const _FeatureTile({required this.feature, required this.locked});

  @override
  Widget build(BuildContext context) {
    final color = locked ? ZapColors.textSecondary : ZapColors.safe;
    final icon =
        locked ? Icons.lock_rounded : Icons.check_circle_rounded;

    return Padding(
      padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        onTap: locked
            ? () => ZapSnackbar.info(
                  context,
                  'Upgrade available — ${feature.lockedReason}',
                )
            : null,
        child: Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: ZapColors.border),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: ZapSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      feature.label,
                      style: ZapTypography.bodyMedium.copyWith(
                        color: locked
                            ? ZapColors.textSecondary
                            : ZapColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        decoration:
                            locked ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (locked) ...[
                      const SizedBox(height: 2),
                      Text(
                        feature.lockedReason,
                        style: ZapTypography.labelSmall.copyWith(
                          color: ZapColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (locked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: ZapColors.warning.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'UPGRADE',
                    style: ZapTypography.labelSmall.copyWith(
                      color: ZapColors.warning,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
            ],
          ),
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
