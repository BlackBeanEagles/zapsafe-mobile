/// Day 91-92 — Premium Subscription screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../domain/providers/subscription_providers.dart';

// ─── Root screen ──────────────────────────────────────────────────────────────

class Day91PremiumSubscriptionScreen extends ConsumerWidget {
  const Day91PremiumSubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(subscriptionProvider);

    // Show success sheet once purchase completes
    ref.listen(subscriptionProvider, (prev, next) {
      if (prev?.purchaseComplete == false && next.purchaseComplete) {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: ZapColors.bgCard,
          isDismissible: false,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
                top: Radius.circular(ZapSpacing.radiusSmall)),
          ),
          builder: (_) => _PurchaseSuccessSheet(
            plan: next.currentPlan,
            onDone: () {
              ref.read(subscriptionProvider.notifier).resetPurchaseComplete();
              Navigator.of(context).pop();
            },
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      body: CustomScrollView(
        slivers: [
          _AppBar(state: state),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  ZapSpacing.lg, 0, ZapSpacing.lg, ZapSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Billing cycle toggle ──────────────────────────
                  _BillingCycleToggle(state: state),
                  const SizedBox(height: ZapSpacing.lg),

                  // ── Plan cards ───────────────────────────────────
                  _PlanCards(state: state),
                  const SizedBox(height: ZapSpacing.xxl),

                  // ── Benefits comparison ──────────────────────────
                  _BenefitsSection(state: state),
                  const SizedBox(height: ZapSpacing.xxl),

                  // ── FAQ ──────────────────────────────────────────
                  const _FaqSection(),
                  const SizedBox(height: ZapSpacing.xl),

                  // ── Legal note ───────────────────────────────────
                  Text(
                    'Prices shown in USD. Subscriptions renew automatically. '
                    'Cancel anytime before renewal to avoid charges.',
                    style: ZapTypography.bodySmall
                        .copyWith(color: ZapColors.textMuted),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 120), // space for sticky CTA
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _StickyCtaBar(state: state),
    );
  }
}

// ─── Custom SliverAppBar / Hero ───────────────────────────────────────────────

class _AppBar extends StatelessWidget {
  const _AppBar({required this.state});
  final SubscriptionState state;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: ZapColors.bgPrimary,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            size: 20, color: ZapColors.textPrimary),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: _HeroBanner(state: state),
      ),
      title: const Text('Premium', style: ZapTypography.headlineSmall),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.state});
  final SubscriptionState state;

  @override
  Widget build(BuildContext context) {
    final isPremium = state.currentPlan == SubscriptionPlan.premium;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A2744),
            Color(0xFF0D1B38),
            ZapColors.bgPrimary,
          ],
          stops: [0.0, 0.6, 1.0],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              ZapSpacing.xxl, ZapSpacing.xl, ZapSpacing.xxl, ZapSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // shield icon with glow
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ZapColors.info.withAlpha(26),
                  border: Border.all(
                      color: ZapColors.info.withAlpha(77), width: 1.5),
                ),
                child: const Icon(Icons.shield_rounded,
                    size: 32, color: ZapColors.info),
              ),
              const SizedBox(height: ZapSpacing.md),
              Text(
                isPremium ? 'You\'re on Premium' : 'ZapSafe Premium',
                style: ZapTypography.headlineSmall
                    .copyWith(color: ZapColors.textPrimary),
              ),
              const SizedBox(height: ZapSpacing.xs),
              Text(
                isPremium
                    ? 'Complete protection, always on'
                    : 'Unlock everything. Stay safer.',
                style: ZapTypography.bodyMedium
                    .copyWith(color: ZapColors.textSecondary),
              ),
              if (isPremium) ...[
                const SizedBox(height: ZapSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: ZapSpacing.md, vertical: ZapSpacing.xs),
                  decoration: BoxDecoration(
                    color: ZapColors.safe.withAlpha(26),
                    borderRadius:
                        BorderRadius.circular(ZapSpacing.radiusSmall),
                    border: Border.all(
                        color: ZapColors.safe.withAlpha(77)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          size: 14, color: ZapColors.safe),
                      const SizedBox(width: ZapSpacing.xs),
                      Text('Active subscription',
                          style: ZapTypography.labelSmall
                              .copyWith(color: ZapColors.safe)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Billing cycle toggle ─────────────────────────────────────────────────────

class _BillingCycleToggle extends ConsumerWidget {
  const _BillingCycleToggle({required this.state});
  final SubscriptionState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(subscriptionProvider.notifier);

    return Container(
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.border),
      ),
      padding: const EdgeInsets.all(ZapSpacing.xs),
      child: Row(
        children: BillingCycle.values.map((cycle) {
          final selected = state.billingCycle == cycle;
          return Expanded(
            child: GestureDetector(
              onTap: () => notifier.setBillingCycle(cycle),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: ZapSpacing.sm),
                decoration: BoxDecoration(
                  color: selected ? ZapColors.info : Colors.transparent,
                  borderRadius:
                      BorderRadius.circular(ZapSpacing.radiusSmall),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      cycle.label,
                      style: ZapTypography.labelMedium.copyWith(
                        color: selected
                            ? Colors.white
                            : ZapColors.textSecondary,
                      ),
                    ),
                    if (cycle == BillingCycle.annual) ...[
                      const SizedBox(width: ZapSpacing.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: ZapSpacing.xs, vertical: 2),
                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.white.withAlpha(51)
                              : ZapColors.safe.withAlpha(26),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Save $kAnnualSavingPct%',
                          style: ZapTypography.labelSmall.copyWith(
                            color: selected
                                ? Colors.white
                                : ZapColors.safe,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
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

// ─── Plan cards ───────────────────────────────────────────────────────────────

class _PlanCards extends ConsumerWidget {
  const _PlanCards({required this.state});
  final SubscriptionState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(subscriptionProvider.notifier);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _PlanCard(
            plan: SubscriptionPlan.free,
            state: state,
            onTap: () => notifier.selectPlan(SubscriptionPlan.free),
          ),
        ),
        const SizedBox(width: ZapSpacing.md),
        Expanded(
          child: _PlanCard(
            plan: SubscriptionPlan.premium,
            state: state,
            onTap: () => notifier.selectPlan(SubscriptionPlan.premium),
          ),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.state,
    required this.onTap,
  });
  final SubscriptionPlan    plan;
  final SubscriptionState   state;
  final VoidCallback        onTap;

  String get _priceString {
    if (plan == SubscriptionPlan.free) {
      return '\$0';
    }
    if (state.billingCycle == BillingCycle.monthly) {
      return '\$${kPremiumMonthlyPrice.toStringAsFixed(2)}';
    }
    return '\$${kPremiumAnnualMonthlyPrice.toStringAsFixed(2)}';
  }

  String get _priceSuffix => plan == SubscriptionPlan.free ? '' : '/ mo';

  String? get _billingNote {
    if (plan != SubscriptionPlan.premium) {
      return null;
    }
    if (state.billingCycle == BillingCycle.annual) {
      return 'Billed \$${kPremiumAnnualTotal.toStringAsFixed(2)}/yr';
    }
    return 'Billed monthly';
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = state.selectedPlan == plan;
    final isCurrent  = state.currentPlan  == plan;
    final isPremium  = plan == SubscriptionPlan.premium;
    final borderColor = isPremium
        ? (isSelected ? ZapColors.info : ZapColors.border)
        : (isSelected ? ZapColors.textSecondary : ZapColors.border);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isSelected
              ? (isPremium
                  ? ZapColors.info.withAlpha(13)
                  : ZapColors.bgCard)
              : ZapColors.bgCard,
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        padding: const EdgeInsets.all(ZapSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // current badge
            if (isCurrent)
              Container(
                margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
                padding: const EdgeInsets.symmetric(
                    horizontal: ZapSpacing.sm, vertical: 2),
                decoration: BoxDecoration(
                  color: ZapColors.safe.withAlpha(26),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: ZapColors.safe.withAlpha(77)),
                ),
                child: Text('Current',
                    style: ZapTypography.labelSmall
                        .copyWith(color: ZapColors.safe)),
              ),

            // plan icon
            Icon(
              plan.icon,
              size: 28,
              color: isPremium ? ZapColors.info : ZapColors.textSecondary,
            ),
            const SizedBox(height: ZapSpacing.sm),

            // plan name
            Text(plan.label,
                style: ZapTypography.labelLarge
                    .copyWith(
                      color: isPremium
                          ? ZapColors.info
                          : ZapColors.textPrimary,
                    )),
            const SizedBox(height: ZapSpacing.xs),

            // price
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _priceString,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: ZapColors.textPrimary,
                    height: 1.0,
                  ),
                ),
                if (_priceSuffix.isNotEmpty) ...[
                  const SizedBox(width: 2),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(_priceSuffix,
                        style: ZapTypography.bodySmall
                            .copyWith(color: ZapColors.textSecondary)),
                  ),
                ],
              ],
            ),

            if (_billingNote != null) ...[
              const SizedBox(height: 2),
              Text(_billingNote!,
                  style: ZapTypography.bodySmall
                      .copyWith(color: ZapColors.textMuted)),
            ],

            const SizedBox(height: ZapSpacing.md),

            // tagline
            Text(plan.tagline,
                style: ZapTypography.bodySmall
                    .copyWith(color: ZapColors.textSecondary)),

            // selected indicator
            if (isSelected) ...[
              const SizedBox(height: ZapSpacing.sm),
              Row(
                children: [
                  const Icon(Icons.radio_button_checked_rounded,
                      size: 14, color: ZapColors.info),
                  const SizedBox(width: ZapSpacing.xs),
                  Text('Selected',
                      style: ZapTypography.labelSmall
                          .copyWith(color: ZapColors.info)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Benefits section ─────────────────────────────────────────────────────────

class _BenefitsSection extends StatelessWidget {
  const _BenefitsSection({required this.state});
  final SubscriptionState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.star_rounded, size: 16, color: ZapColors.warning),
            const SizedBox(width: ZapSpacing.sm),
            Text('What you get',
                style: ZapTypography.labelLarge
                    .copyWith(color: ZapColors.textPrimary)),
          ],
        ),
        const SizedBox(height: ZapSpacing.md),

        // column headers
        Padding(
          padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
          child: Row(
            children: [
              const Expanded(flex: 5, child: SizedBox.shrink()),
              Expanded(
                flex: 2,
                child: Text('Free',
                    style: ZapTypography.labelSmall
                        .copyWith(color: ZapColors.textSecondary),
                    textAlign: TextAlign.center),
              ),
              Expanded(
                flex: 2,
                child: Text('Premium',
                    style: ZapTypography.labelSmall
                        .copyWith(color: ZapColors.info),
                    textAlign: TextAlign.center),
              ),
            ],
          ),
        ),
        const Divider(color: ZapColors.divider, height: 1),

        ...kPlanBenefits.map((b) => _BenefitRow(benefit: b)),
      ],
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.benefit});
  final PlanBenefit benefit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: ZapSpacing.md),
          child: Row(
            children: [
              // icon + label
              Expanded(
                flex: 5,
                child: Row(
                  children: [
                    Icon(benefit.icon, size: 16,
                        color: ZapColors.textSecondary),
                    const SizedBox(width: ZapSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(benefit.label,
                              style: ZapTypography.bodyMedium
                                  .copyWith(color: ZapColors.textPrimary)),
                          Text(benefit.description,
                              style: ZapTypography.bodySmall
                                  .copyWith(color: ZapColors.textMuted),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // free value
              Expanded(
                flex: 2,
                child: benefit.freeValue != null
                    ? Text(benefit.freeValue!,
                        style: ZapTypography.labelSmall
                            .copyWith(color: ZapColors.textSecondary),
                        textAlign: TextAlign.center)
                    : const Icon(Icons.remove_rounded,
                        size: 16, color: ZapColors.textMuted),
              ),

              // premium value
              Expanded(
                flex: 2,
                child: benefit.freeValue == null ||
                        benefit.premiumValue != benefit.freeValue
                    ? Text(benefit.premiumValue,
                        style: ZapTypography.labelSmall
                            .copyWith(color: ZapColors.info),
                        textAlign: TextAlign.center,
                        maxLines: 2)
                    : const Icon(Icons.check_rounded,
                        size: 16, color: ZapColors.info),
              ),
            ],
          ),
        ),
        const Divider(color: ZapColors.divider, height: 1),
      ],
    );
  }
}

// ─── FAQ section ──────────────────────────────────────────────────────────────

class _FaqSection extends StatelessWidget {
  const _FaqSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.help_outline_rounded,
                size: 16, color: ZapColors.textSecondary),
            const SizedBox(width: ZapSpacing.sm),
            Text('Frequently asked',
                style: ZapTypography.labelLarge
                    .copyWith(color: ZapColors.textPrimary)),
          ],
        ),
        const SizedBox(height: ZapSpacing.md),
        Container(
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: ZapColors.border),
          ),
          child: Column(
            children: kSubscriptionFaq.asMap().entries.map((entry) {
              final i = entry.key;
              final faq = entry.value;
              return Column(
                children: [
                  if (i > 0)
                    const Divider(color: ZapColors.divider, height: 1),
                  _FaqTile(faq: faq),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _FaqTile extends StatefulWidget {
  const _FaqTile({required this.faq});
  final FaqItem faq;

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: ZapSpacing.lg, vertical: ZapSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Text(widget.faq.question,
                      style: ZapTypography.bodyMedium
                          .copyWith(color: ZapColors.textPrimary)),
                ),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: ZapColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                ZapSpacing.lg, 0, ZapSpacing.lg, ZapSpacing.md),
            child: Text(widget.faq.answer,
                style: ZapTypography.bodySmall
                    .copyWith(color: ZapColors.textSecondary)),
          ),
      ],
    );
  }
}

// ─── Sticky CTA bar ───────────────────────────────────────────────────────────

class _StickyCtaBar extends ConsumerWidget {
  const _StickyCtaBar({required this.state});
  final SubscriptionState state;

  String get _ctaLabel {
    if (state.isPurchasing) {
      return 'Processing…';
    }
    if (state.isAlreadyOnSelectedPlan) {
      if (state.currentPlan == SubscriptionPlan.premium) {
        return 'You\'re on Premium ✓';
      }
      return 'Free plan selected';
    }
    if (state.selectedPlan == SubscriptionPlan.premium) {
      final price = state.billingCycle == BillingCycle.annual
          ? '\$${kPremiumAnnualMonthlyPrice.toStringAsFixed(2)}/mo'
          : '\$${kPremiumMonthlyPrice.toStringAsFixed(2)}/mo';
      return 'Upgrade to Premium  ·  $price';
    }
    return 'Switch to Free';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(subscriptionProvider.notifier);
    final disabled = state.isPurchasing || state.isAlreadyOnSelectedPlan;
    final isPremiumCta = state.selectedPlan == SubscriptionPlan.premium &&
        !state.isAlreadyOnSelectedPlan;

    return Container(
      decoration: const BoxDecoration(
        color: ZapColors.bgPrimary,
        border: Border(top: BorderSide(color: ZapColors.divider)),
      ),
      padding: EdgeInsets.fromLTRB(
        ZapSpacing.lg,
        ZapSpacing.md,
        ZapSpacing.lg,
        ZapSpacing.md + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: disabled ? null : notifier.purchase,
              style: FilledButton.styleFrom(
                backgroundColor:
                    isPremiumCta ? ZapColors.info : ZapColors.bgElevated,
                disabledBackgroundColor: ZapColors.bgElevated,
                padding: const EdgeInsets.symmetric(vertical: ZapSpacing.lg),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ZapSpacing.radius),
                ),
              ),
              child: state.isPurchasing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _ctaLabel,
                      style: ZapTypography.labelLarge.copyWith(
                        color: disabled
                            ? ZapColors.textMuted
                            : Colors.white,
                      ),
                    ),
            ),
          ),
          if (state.billingCycle == BillingCycle.annual &&
              state.selectedPlan == SubscriptionPlan.premium &&
              !state.isAlreadyOnSelectedPlan) ...[
            const SizedBox(height: ZapSpacing.xs),
            Text(
              'Billed as \$${kPremiumAnnualTotal.toStringAsFixed(2)} annually  ·  Cancel anytime',
              style: ZapTypography.bodySmall
                  .copyWith(color: ZapColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Purchase success sheet ───────────────────────────────────────────────────

class _PurchaseSuccessSheet extends StatelessWidget {
  const _PurchaseSuccessSheet({
    required this.plan,
    required this.onDone,
  });
  final SubscriptionPlan plan;
  final VoidCallback     onDone;

  @override
  Widget build(BuildContext context) {
    final isPremium = plan == SubscriptionPlan.premium;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(ZapSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // handle
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: ZapSpacing.xl),
              decoration: BoxDecoration(
                color: ZapColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // success icon
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ZapColors.safe.withAlpha(26),
                border: Border.all(
                    color: ZapColors.safe.withAlpha(77), width: 2),
              ),
              child: const Icon(Icons.check_rounded,
                  size: 36, color: ZapColors.safe),
            ),
            const SizedBox(height: ZapSpacing.xl),

            Text(
              isPremium
                  ? 'Welcome to Premium!'
                  : 'Plan updated',
              style: ZapTypography.headlineSmall
                  .copyWith(color: ZapColors.textPrimary),
            ),
            const SizedBox(height: ZapSpacing.sm),
            Text(
              isPremium
                  ? 'Your ZapSafe Premium subscription is now active. '
                    'Unlimited contacts, 5 GB storage, and priority response '
                    'are all unlocked.'
                  : 'You\'ve switched to the Free plan.',
              style: ZapTypography.bodyMedium
                  .copyWith(color: ZapColors.textSecondary),
              textAlign: TextAlign.center,
            ),

            if (isPremium) ...[
              const SizedBox(height: ZapSpacing.xl),
              // quick benefits summary
              const _SuccessBenefitChip(
                  icon: Icons.people_rounded, label: 'Unlimited contacts'),
              const SizedBox(height: ZapSpacing.sm),
              const _SuccessBenefitChip(
                  icon: Icons.folder_rounded, label: '5 GB evidence storage'),
              const SizedBox(height: ZapSpacing.sm),
              const _SuccessBenefitChip(
                  icon: Icons.bolt_rounded,
                  label: 'Priority response < 500 ms'),
            ],

            const SizedBox(height: ZapSpacing.xxl),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onDone,
                style: FilledButton.styleFrom(
                  backgroundColor: ZapColors.safe,
                  padding:
                      const EdgeInsets.symmetric(vertical: ZapSpacing.lg),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(ZapSpacing.radius),
                  ),
                ),
                child: Text(
                  'Get started',
                  style: ZapTypography.labelLarge
                      .copyWith(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessBenefitChip extends StatelessWidget {
  const _SuccessBenefitChip({required this.icon, required this.label});
  final IconData icon;
  final String   label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: ZapSpacing.lg, vertical: ZapSpacing.sm),
      decoration: BoxDecoration(
        color: ZapColors.safe.withAlpha(13),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: ZapColors.safe.withAlpha(51)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: ZapColors.safe),
          const SizedBox(width: ZapSpacing.md),
          Text(label,
              style: ZapTypography.bodyMedium
                  .copyWith(color: ZapColors.textPrimary)),
          const Spacer(),
          const Icon(Icons.check_rounded,
              size: 14, color: ZapColors.safe),
        ],
      ),
    );
  }
}
