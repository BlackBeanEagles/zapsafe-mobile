import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/services/device_tier_service.dart';
import '../../domain/providers/device_providers.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_button.dart';


class Day13DeviceTierScreen extends ConsumerWidget {
  const Day13DeviceTierScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tierAsync = ref.watch(deviceTierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Day 13 · Device Tier'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(ZapSpacing.lg),
          child: tierAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(ZapSpacing.huge),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => _ErrorState(message: e.toString()),
            data: (result) => _TierBody(result: result),
          ),
        ),
      ),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _TierBody extends StatelessWidget {
  final DeviceTierResult result;
  const _TierBody({required this.result});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HeroBanner(result: result),
        const SizedBox(height: ZapSpacing.xl),

        const _SectionLabel('DEVICE INFO'),
        const SizedBox(height: ZapSpacing.md),
        _DeviceInfoCard(result: result),
        const SizedBox(height: ZapSpacing.xl),

        _SectionLabel('ENABLED FEATURES (${result.enabledFeatures.length})'),
        const SizedBox(height: ZapSpacing.md),
        _FeatureList(
          features: result.enabledFeatures,
          enabled: true,
        ),

        if (result.disabledFeatures.isNotEmpty) ...[
          const SizedBox(height: ZapSpacing.xl),
          _SectionLabel('UNAVAILABLE ON THIS DEVICE (${result.disabledFeatures.length})'),
          const SizedBox(height: ZapSpacing.md),
          _FeatureList(
            features: result.disabledFeatures,
            enabled: false,
          ),
        ],

        const SizedBox(height: ZapSpacing.xl),
        _TierComparisonTable(currentTier: result.tier),
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

// ─── Hero banner ──────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  final DeviceTierResult result;
  const _HeroBanner({required this.result});

  Color get _tierColor => switch (result.tier) {
        DeviceTier.tierA => ZapColors.safe,
        DeviceTier.tierB => ZapColors.warning,
        DeviceTier.tierC => ZapColors.info,
      };

  IconData get _tierIcon => switch (result.tier) {
        DeviceTier.tierA => Icons.star_rounded,
        DeviceTier.tierB => Icons.star_half_rounded,
        DeviceTier.tierC => Icons.star_border_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final color = _tierColor;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.14), color.withOpacity(0.04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: color.withOpacity(0.4)),
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
                child: Icon(_tierIcon, color: color, size: 22),
              ),
              const SizedBox(width: ZapSpacing.md),
              const ZapBadge(
                label: 'WEEK 3 · DAY 13',
                intent: ZapBadgeIntent.info,
              ),
              const SizedBox(width: ZapSpacing.sm),
              ZapBadge(
                label: result.tier.shortLabel,
                intent: switch (result.tier) {
                  DeviceTier.tierA => ZapBadgeIntent.safe,
                  DeviceTier.tierB => ZapBadgeIntent.warning,
                  DeviceTier.tierC => ZapBadgeIntent.info,
                },
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          Text(
            result.tier.label,
            style: ZapTypography.displaySmall.copyWith(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            result.tier.description,
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

// ─── Device info card ─────────────────────────────────────────────────────────

class _DeviceInfoCard extends StatelessWidget {
  final DeviceTierResult result;
  const _DeviceInfoCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Model', result.model),
      ('Manufacturer', result.manufacturer),
      ('OS', result.osVersion),
      ('API / Version', result.osLevelOrVersion.toString()),
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

// ─── Feature list ─────────────────────────────────────────────────────────────

class _FeatureList extends StatelessWidget {
  final List<String> features;
  final bool enabled;
  const _FeatureList({required this.features, required this.enabled});

  @override
  Widget build(BuildContext context) {
    final color = enabled ? ZapColors.safe : ZapColors.textSecondary;
    final icon = enabled ? Icons.check_circle_rounded : Icons.cancel_rounded;

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.border),
      ),
      child: Column(
        children: features.map((f) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: ZapSpacing.xs),
            child: Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: ZapSpacing.md),
                Expanded(
                  child: Text(
                    f,
                    style: ZapTypography.bodyMedium.copyWith(
                      color: enabled
                          ? ZapColors.textPrimary
                          : ZapColors.textSecondary,
                      decoration: enabled
                          ? null
                          : TextDecoration.lineThrough,
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

// ─── Tier comparison table ────────────────────────────────────────────────────

class _TierComparisonTable extends StatelessWidget {
  final DeviceTier currentTier;
  const _TierComparisonTable({required this.currentTier});

  @override
  Widget build(BuildContext context) {
    final tiers = [
      (DeviceTier.tierA, 'Android 12+ / iOS 16+', ZapColors.safe),
      (DeviceTier.tierB, 'Android 7–11 / iOS 13–15', ZapColors.warning),
      (DeviceTier.tierC, 'Android <7 / iOS <13', ZapColors.info),
    ];

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
          const _SectionLabel('TIER THRESHOLDS'),
          const SizedBox(height: ZapSpacing.md),
          ...tiers.map((t) {
            final isCurrent = t.$1 == currentTier;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: ZapSpacing.xs),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.sm, vertical: 3),
                    decoration: BoxDecoration(
                      color: t.$3.withOpacity(isCurrent ? 0.25 : 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: isCurrent
                          ? Border.all(color: t.$3, width: 1.5)
                          : null,
                    ),
                    child: Text(
                      t.$1.shortLabel,
                      style: ZapTypography.labelSmall.copyWith(
                        color: t.$3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: ZapSpacing.md),
                  Expanded(
                    child: Text(
                      t.$2,
                      style: ZapTypography.bodySmall.copyWith(
                        color: isCurrent
                            ? ZapColors.textPrimary
                            : ZapColors.textSecondary,
                        fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (isCurrent)
                    Icon(Icons.arrow_left_rounded, color: t.$3, size: 20),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

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

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ZapSpacing.xl),
        child: Text(
          'Detection failed: $message',
          style: ZapTypography.bodyMedium.copyWith(color: ZapColors.danger),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
