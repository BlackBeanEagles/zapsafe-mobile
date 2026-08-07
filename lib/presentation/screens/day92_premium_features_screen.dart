/// Day 92-93 — Premium Feature Highlights screen.
///
/// Day 358 — `_UsageCard`'s header now also shows the shared
/// [PremiumTierBadge] (same visual treatment as Day 308's real-wired
/// badge) alongside its existing "Premium Plan"/"Free Plan" label, and
/// [subscriptionUsageProvider] itself was rewired to read real Day 303
/// subscription status + real Day 83 contact count instead of a
/// hardcoded mock (see `premium_features_providers.dart`'s header).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../domain/providers/premium_features_providers.dart';
import '../widgets/premium_tier_badge.dart';

// ─── Root screen ──────────────────────────────────────────────────────────────

class Day92PremiumFeaturesScreen extends ConsumerWidget {
  const Day92PremiumFeaturesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final features = ref.watch(filteredFeaturesProvider);
    final usage    = ref.watch(subscriptionUsageProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      body: CustomScrollView(
        slivers: [
          // ── App bar ───────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            backgroundColor: ZapColors.bgPrimary,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 20, color: ZapColors.textPrimary),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            title: const Text('Premium Features',
                style: ZapTypography.headlineSmall),
          ),

          // ── Usage card ────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  ZapSpacing.lg, ZapSpacing.sm,
                  ZapSpacing.lg, ZapSpacing.lg),
              child: _UsageCard(usage: usage),
            ),
          ),

          // ── Category filter ───────────────────────────────────
          const SliverToBoxAdapter(child: _CategoryFilter()),
          const SliverToBoxAdapter(
              child: SizedBox(height: ZapSpacing.lg)),

          // ── Feature grid ──────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
                ZapSpacing.lg, 0, ZapSpacing.lg, ZapSpacing.xxl),
            sliver: features.isEmpty
                ? const SliverToBoxAdapter(child: _EmptyState())
                : SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: ZapSpacing.md,
                      mainAxisSpacing: ZapSpacing.md,
                      childAspectRatio: 0.82,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _FeatureCard(feature: features[i]),
                      childCount: features.length,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Usage card ───────────────────────────────────────────────────────────────

class _UsageCard extends StatelessWidget {
  const _UsageCard({required this.usage});
  final SubscriptionUsage usage;

  @override
  Widget build(BuildContext context) {
    final isPremium = usage.isPremium;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A2744), Color(0xFF0D1B38)],
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(
            color: ZapColors.info.withAlpha(51)),
      ),
      padding: const EdgeInsets.all(ZapSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // plan badge row
          Row(
            children: [
              Icon(
                isPremium
                    ? Icons.shield_rounded
                    : Icons.shield_outlined,
                size: 18,
                color: isPremium ? ZapColors.info : ZapColors.textSecondary,
              ),
              const SizedBox(width: ZapSpacing.sm),
              Text(
                isPremium ? 'Premium Plan' : 'Free Plan',
                style: ZapTypography.labelLarge.copyWith(
                  color: isPremium ? ZapColors.info : ZapColors.textPrimary,
                ),
              ),
              const SizedBox(width: ZapSpacing.sm),
              PremiumTierBadge(
                planLabel: isPremium ? 'PREMIUM' : 'FREE',
                isPremium: isPremium,
              ),
              const Spacer(),
              if (!isPremium)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: ZapSpacing.sm, vertical: 3),
                  decoration: BoxDecoration(
                    color: ZapColors.info.withAlpha(26),
                    borderRadius:
                        BorderRadius.circular(ZapSpacing.radiusSmall),
                    border: Border.all(color: ZapColors.info.withAlpha(77)),
                  ),
                  child: Text('Upgrade available',
                      style: ZapTypography.labelSmall
                          .copyWith(color: ZapColors.info)),
                ),
            ],
          ),
          const SizedBox(height: ZapSpacing.lg),

          // usage metrics row
          Row(
            children: [
              Expanded(
                child: _UsageStat(
                  label: 'Contacts',
                  used: usage.contactsUsed,
                  limit: usage.contactsLimit,
                ),
              ),
              const _VertDivider(),
              Expanded(
                child: _UsageStat(
                  label: 'Timers',
                  used: usage.activeTimers,
                  limit: usage.timersLimit,
                ),
              ),
              const _VertDivider(),
              Expanded(
                child: _UsageStat(
                  label: 'Safe Zones',
                  used: usage.safeZones,
                  limit: usage.safeZonesLimit,
                ),
              ),
            ],
          ),

          const SizedBox(height: ZapSpacing.lg),

          // storage bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Evidence Storage',
                      style: ZapTypography.bodySmall
                          .copyWith(color: ZapColors.textSecondary)),
                  Text(usage.storageLabel,
                      style: ZapTypography.labelSmall
                          .copyWith(color: ZapColors.textPrimary)),
                ],
              ),
              const SizedBox(height: ZapSpacing.xs),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: usage.storagePercent,
                  backgroundColor: ZapColors.bgSurface,
                  color: usage.storagePercent > 0.8
                      ? ZapColors.danger
                      : ZapColors.info,
                  minHeight: 5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UsageStat extends StatelessWidget {
  const _UsageStat({
    required this.label,
    required this.used,
    required this.limit,
  });
  final String label;
  final int    used;
  final int?   limit; // null = unlimited

  @override
  Widget build(BuildContext context) {
    final limitStr = limit == null ? '∞' : '$limit';
    final nearLimit = limit != null && used >= limit! - 1;

    return Column(
      children: [
        Text(
          '$used / $limitStr',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: nearLimit ? ZapColors.warning : ZapColors.textPrimary,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 2),
        Text(label,
            style: ZapTypography.bodySmall
                .copyWith(color: ZapColors.textSecondary)),
      ],
    );
  }
}

class _VertDivider extends StatelessWidget {
  const _VertDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: ZapSpacing.sm),
      color: ZapColors.divider,
    );
  }
}

// ─── Category filter ──────────────────────────────────────────────────────────

class _CategoryFilter extends ConsumerWidget {
  const _CategoryFilter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(featureCategoryFilterProvider);
    final notifier = ref.read(featureCategoryFilterProvider.notifier);

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.lg),
        children: FeatureCategory.values.map((cat) {
          final isSelected = selected == cat;
          return Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.sm),
            child: GestureDetector(
              onTap: () => notifier.state = cat,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: ZapSpacing.md, vertical: ZapSpacing.sm),
                decoration: BoxDecoration(
                  color: isSelected
                      ? ZapColors.info.withAlpha(26)
                      : ZapColors.bgCard,
                  borderRadius:
                      BorderRadius.circular(ZapSpacing.radiusSmall),
                  border: Border.all(
                    color: isSelected ? ZapColors.info : ZapColors.border,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(cat.icon,
                        size: 14,
                        color: isSelected
                            ? ZapColors.info
                            : ZapColors.textSecondary),
                    const SizedBox(width: ZapSpacing.xs),
                    Text(cat.label,
                        style: ZapTypography.labelSmall.copyWith(
                          color: isSelected
                              ? ZapColors.info
                              : ZapColors.textSecondary,
                        )),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Feature card ─────────────────────────────────────────────────────────────

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.feature});
  final PremiumFeature feature;

  @override
  Widget build(BuildContext context) {
    final isComingSoon = feature.status == FeatureStatus.comingSoon;

    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Container(
        decoration: BoxDecoration(
          color: ZapColors.bgCard,
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          border: Border.all(color: ZapColors.border),
        ),
        padding: const EdgeInsets.all(ZapSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // icon + status badge row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: feature.color.withAlpha(26),
                    borderRadius:
                        BorderRadius.circular(ZapSpacing.radiusSmall),
                  ),
                  child: Icon(feature.icon,
                      size: 22, color: feature.color),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: ZapSpacing.xs, vertical: 3),
                  decoration: BoxDecoration(
                    color: feature.status.color.withAlpha(26),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: feature.status.color.withAlpha(77)),
                  ),
                  child: Text(
                    feature.status.label,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: feature.status.color,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),

            // title
            Text(feature.title,
                style: ZapTypography.labelLarge
                    .copyWith(
                      color: isComingSoon
                          ? ZapColors.textSecondary
                          : ZapColors.textPrimary,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),

            // subtitle
            Text(feature.subtitle,
                style: ZapTypography.bodySmall
                    .copyWith(color: ZapColors.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: ZapSpacing.sm),

            // free limit chip
            if (feature.freeLimit != null)
              Row(
                children: [
                  const Icon(Icons.arrow_circle_up_rounded,
                      size: 12, color: ZapColors.info),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text('Free: ${feature.freeLimit}',
                        style: ZapTypography.bodySmall
                            .copyWith(color: ZapColors.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              )
            else if (!isComingSoon)
              Row(
                children: [
                  const Icon(Icons.lock_open_rounded,
                      size: 12, color: ZapColors.safe),
                  const SizedBox(width: 3),
                  Text('Premium only',
                      style: ZapTypography.bodySmall
                          .copyWith(color: ZapColors.safe)),
                ],
              ),

            const SizedBox(height: ZapSpacing.sm),

            // tap hint
            Row(
              children: [
                Text('Learn more',
                    style: ZapTypography.bodySmall
                        .copyWith(color: ZapColors.info)),
                const SizedBox(width: 2),
                const Icon(Icons.chevron_right_rounded,
                    size: 14, color: ZapColors.info),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ZapColors.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(ZapSpacing.radiusSmall)),
      ),
      builder: (_) => _FeatureDetailSheet(feature: feature),
    );
  }
}

// ─── Feature detail sheet ─────────────────────────────────────────────────────

class _FeatureDetailSheet extends StatelessWidget {
  const _FeatureDetailSheet({required this.feature});
  final PremiumFeature feature;

  @override
  Widget build(BuildContext context) {
    final isComingSoon = feature.status == FeatureStatus.comingSoon;
    final hasFreeLimit = feature.freeLimit != null;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(
              ZapSpacing.xxl, ZapSpacing.md,
              ZapSpacing.xxl, ZapSpacing.xxl),
          children: [
            // handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: ZapSpacing.xl),
                decoration: BoxDecoration(
                  color: ZapColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // icon + status
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: feature.color.withAlpha(26),
                    borderRadius: BorderRadius.circular(ZapSpacing.radius),
                  ),
                  child: Icon(feature.icon,
                      size: 28, color: feature.color),
                ),
                const SizedBox(width: ZapSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(feature.title,
                          style: ZapTypography.headlineSmall
                              .copyWith(color: ZapColors.textPrimary)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: ZapSpacing.sm, vertical: 2),
                            decoration: BoxDecoration(
                              color: feature.status.color.withAlpha(26),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: feature.status.color.withAlpha(77)),
                            ),
                            child: Text(feature.status.label,
                                style: ZapTypography.labelSmall
                                    .copyWith(
                                        color: feature.status.color)),
                          ),
                          const SizedBox(width: ZapSpacing.sm),
                          Text(
                            feature.category.label,
                            style: ZapTypography.bodySmall
                                .copyWith(color: ZapColors.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: ZapSpacing.xl),

            // description
            Text(feature.description,
                style: ZapTypography.bodyMedium
                    .copyWith(
                        color: ZapColors.textSecondary, height: 1.6)),
            const SizedBox(height: ZapSpacing.xl),

            // free vs premium callout
            if (hasFreeLimit) ...[
              Container(
                decoration: BoxDecoration(
                  color: ZapColors.bgSurface,
                  borderRadius:
                      BorderRadius.circular(ZapSpacing.radiusSmall),
                  border: Border.all(color: ZapColors.border),
                ),
                child: Column(
                  children: [
                    _CompareRow(
                      label: 'Free',
                      value: feature.freeLimit!,
                      color: ZapColors.textSecondary,
                      icon: Icons.shield_outlined,
                    ),
                    const Divider(color: ZapColors.divider, height: 1),
                    _CompareRow(
                      label: 'Premium',
                      value: feature.stats.isNotEmpty
                          ? feature.stats[1].value
                          : 'Unlimited',
                      color: ZapColors.info,
                      icon: Icons.shield_rounded,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: ZapSpacing.xl),
            ] else if (!isComingSoon) ...[
              Container(
                padding: const EdgeInsets.all(ZapSpacing.md),
                decoration: BoxDecoration(
                  color: ZapColors.safe.withAlpha(13),
                  borderRadius:
                      BorderRadius.circular(ZapSpacing.radiusSmall),
                  border: Border.all(color: ZapColors.safe.withAlpha(51)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_open_rounded,
                        size: 16, color: ZapColors.safe),
                    const SizedBox(width: ZapSpacing.sm),
                    Text('Exclusive Premium feature — not on Free',
                        style: ZapTypography.bodySmall
                            .copyWith(color: ZapColors.safe)),
                  ],
                ),
              ),
              const SizedBox(height: ZapSpacing.xl),
            ],

            // stats table
            Text('Specs',
                style: ZapTypography.labelMedium
                    .copyWith(color: ZapColors.textSecondary)),
            const SizedBox(height: ZapSpacing.sm),
            Container(
              decoration: BoxDecoration(
                color: ZapColors.bgCard,
                borderRadius:
                    BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(color: ZapColors.border),
              ),
              child: Column(
                children: feature.stats.asMap().entries.map((entry) {
                  final i   = entry.key;
                  final stat = entry.value;
                  return Column(
                    children: [
                      if (i > 0)
                        const Divider(color: ZapColors.divider, height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: ZapSpacing.lg,
                            vertical: ZapSpacing.md),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(stat.label,
                                style: ZapTypography.bodySmall
                                    .copyWith(
                                        color: ZapColors.textSecondary)),
                            Text(stat.value,
                                style: ZapTypography.labelSmall
                                    .copyWith(
                                        color: ZapColors.textPrimary)),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: ZapSpacing.xxl),

            // CTA
            if (isComingSoon)
              _ComingSoonCta()
            else
              _AvailableCta(feature: feature),
          ],
        );
      },
    );
  }
}

class _CompareRow extends StatelessWidget {
  const _CompareRow({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });
  final String   label;
  final String   value;
  final Color    color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: ZapSpacing.lg, vertical: ZapSpacing.md),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: ZapSpacing.sm),
          Text(label,
              style: ZapTypography.labelSmall
                  .copyWith(color: ZapColors.textSecondary)),
          const Spacer(),
          Text(value,
              style: ZapTypography.labelMedium.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _ComingSoonCta extends StatefulWidget {
  @override
  State<_ComingSoonCta> createState() => _ComingSoonCtaState();
}

class _ComingSoonCtaState extends State<_ComingSoonCta> {
  bool _notified = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(ZapSpacing.lg),
          decoration: BoxDecoration(
            color: ZapColors.warning.withAlpha(13),
            borderRadius:
                BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: ZapColors.warning.withAlpha(51)),
          ),
          child: Row(
            children: [
              const Icon(Icons.construction_rounded,
                  size: 16, color: ZapColors.warning),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: Text(
                  'This feature is in active development and will be '
                  'available to Premium subscribers first.',
                  style: ZapTypography.bodySmall
                      .copyWith(color: ZapColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _notified
                ? null
                : () => setState(() => _notified = true),
            style: OutlinedButton.styleFrom(
              foregroundColor: ZapColors.warning,
              side: const BorderSide(color: ZapColors.warning),
              padding: const EdgeInsets.symmetric(
                  vertical: ZapSpacing.md),
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(ZapSpacing.radius),
              ),
            ),
            icon: Icon(
              _notified
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_outlined,
              size: 18,
            ),
            label: Text(
              _notified
                  ? 'You\'ll be notified ✓'
                  : 'Notify me when available',
              style: ZapTypography.labelLarge.copyWith(
                  color: _notified
                      ? ZapColors.textSecondary
                      : ZapColors.warning),
            ),
          ),
        ),
      ],
    );
  }
}

class _AvailableCta extends StatelessWidget {
  const _AvailableCta({required this.feature});
  final PremiumFeature feature;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () => Navigator.of(context).pop(),
        style: FilledButton.styleFrom(
          backgroundColor: feature.color,
          padding:
              const EdgeInsets.symmetric(vertical: ZapSpacing.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
          ),
        ),
        icon: const Icon(Icons.workspace_premium_rounded,
            size: 18, color: Colors.white),
        label: Text('Unlock with Premium',
            style: ZapTypography.labelLarge
                .copyWith(color: Colors.white)),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Column(
        children: [
          const Icon(Icons.category_rounded,
              size: 48, color: ZapColors.textMuted),
          const SizedBox(height: ZapSpacing.lg),
          Text('No features in this category',
              style: ZapTypography.labelLarge
                  .copyWith(color: ZapColors.textSecondary)),
        ],
      ),
    );
  }
}
