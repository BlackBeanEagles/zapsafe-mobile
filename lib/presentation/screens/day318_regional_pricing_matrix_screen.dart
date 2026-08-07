/// Day 318 — Regional Pricing Matrix
///
/// Table of country/region -> premium monthly price. Only the India row
/// is real, live pricing — confirmed in
/// `zapsafe_backend/subscription/models.py`:
///   PLAN_PRICE_INR = { FREE: 0, PREMIUM: 99, PREMIUM_PLUS: 199 }
/// billed via Razorpay (already wired, Day 303's live-wire day).
///
/// Every other region's figures are illustrative proposals this screen's
/// author invented for planning purposes — clearly badged PROPOSED
/// throughout, never presented as a decided price. ZapSafe uses
/// Razorpay exclusively today (Stripe was evaluated and dropped earlier
/// in the project — see the project pivots memory); there is no live
/// USD/EUR billing integration of any kind. A "Billing" column makes
/// that explicit per market: India = Razorpay (live); every other
/// region = App/Play Store in-app purchase (not yet implemented).
///
/// Tag: 🟢 FRONTEND-ONLY
///
/// Route: AppRoutes.regionalPricingMatrix
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_card.dart';

enum _BillingStatus { live, notImplemented }

class _RegionPrice {
  const _RegionPrice({
    required this.flag,
    required this.region,
    required this.currencyLabel,
    required this.premiumPrice,
    required this.premiumPlusPrice,
    required this.isLive,
    required this.billing,
    this.note,
  });

  final String flag;
  final String region;
  final String currencyLabel;
  final String premiumPrice;
  final String premiumPlusPrice;
  final bool isLive;
  final _BillingStatus billing;
  final String? note;
}

const _kRegions = [
  _RegionPrice(
    flag: '🇮🇳',
    region: 'India',
    currencyLabel: 'INR',
    premiumPrice: '₹99',
    premiumPlusPrice: '₹199',
    isLive: true,
    billing: _BillingStatus.live,
    note: 'Real, live — zapsafe_backend/subscription/models.py PLAN_PRICE_INR. '
        'This price is deliberately low relative to what a flat USD/EUR conversion '
        'would suggest — a common PPP (purchasing-power-parity) pricing rationale '
        'for the Indian market, not itself a documented ZapSafe pricing memo, '
        'offered here only as context for why the other regions below aren\'t a '
        'straight FX conversion of ₹99/₹199 either.',
  ),
  _RegionPrice(
    flag: '🇪🇺',
    region: 'EU (27 member states)',
    currencyLabel: 'EUR',
    premiumPrice: '€1.99',
    premiumPlusPrice: '€3.99',
    isLive: false,
    billing: _BillingStatus.notImplemented,
    note: 'Illustrative price point, not a straight FX conversion of ₹99 — EU '
        'consumer pricing psychology typically anchors near round numbers.',
  ),
  _RegionPrice(
    flag: '🌎',
    region: 'LATAM (reference: USD)',
    currencyLabel: 'USD',
    premiumPrice: '\$1.99',
    premiumPlusPrice: '\$3.99',
    isLive: false,
    billing: _BillingStatus.notImplemented,
    note: 'Local-currency pricing (MXN, BRL, COP, ARS, etc.) would replace this '
        'USD reference figure per country before a real launch.',
  ),
  _RegionPrice(
    flag: '🌏',
    region: 'SEA (reference: USD)',
    currencyLabel: 'USD',
    premiumPrice: '\$1.49',
    premiumPlusPrice: '\$2.99',
    isLive: false,
    billing: _BillingStatus.notImplemented,
    note: 'Local-currency pricing (SGD, MYR, IDR, PHP, VND, THB) would replace '
        'this USD reference figure per country before a real launch.',
  ),
];

class Day318RegionalPricingMatrixScreen extends StatelessWidget {
  const Day318RegionalPricingMatrixScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('day311_320.pricing_matrix_title'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          ZapCard(
            backgroundColor: ZapColors.danger.withOpacity(0.08),
            borderColor: ZapColors.danger.withOpacity(0.3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_rounded, color: ZapColors.danger, size: 20),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    'Only the India row is real, live pricing (Razorpay, ₹99/₹199). '
                    'Every other region below is a PROPOSED figure this screen\'s '
                    'author invented for planning — pending an actual business '
                    'decision, not decided pricing, and no USD/EUR billing exists yet.',
                    style: ZapTypography.bodySmall.copyWith(color: ZapColors.textPrimary, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.lg),
          for (final r in _kRegions)
            ZapCard(
              margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(r.flag, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: ZapSpacing.sm),
                      Expanded(
                        child: Text(r.region,
                            style: ZapTypography.bodyMedium
                                .copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w700)),
                      ),
                      ZapBadge(
                        label: r.isLive ? 'LIVE' : 'PROPOSED',
                        intent: r.isLive ? ZapBadgeIntent.safe : ZapBadgeIntent.warning,
                        size: ZapBadgeSize.small,
                      ),
                    ],
                  ),
                  const SizedBox(height: ZapSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: _PriceTile(label: 'Premium / mo', price: r.premiumPrice, isLive: r.isLive),
                      ),
                      const SizedBox(width: ZapSpacing.sm),
                      Expanded(
                        child: _PriceTile(label: 'Premium+ / mo', price: r.premiumPlusPrice, isLive: r.isLive),
                      ),
                    ],
                  ),
                  const SizedBox(height: ZapSpacing.md),
                  Row(
                    children: [
                      Icon(
                        r.billing == _BillingStatus.live ? Icons.check_circle_rounded : Icons.pending_rounded,
                        size: 16,
                        color: r.billing == _BillingStatus.live ? ZapColors.safe : ZapColors.textSecondary,
                      ),
                      const SizedBox(width: ZapSpacing.xs),
                      Expanded(
                        child: Text(
                          r.billing == _BillingStatus.live
                              ? 'Billing: Razorpay (live)'
                              : 'Billing: App/Play Store IAP (not yet implemented)',
                          style: ZapTypography.labelMedium.copyWith(
                            color: r.billing == _BillingStatus.live ? ZapColors.safe : ZapColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (r.note != null) ...[
                    const SizedBox(height: ZapSpacing.sm),
                    Container(
                      padding: const EdgeInsets.all(ZapSpacing.sm),
                      decoration: BoxDecoration(
                        color: ZapColors.bgSurface,
                        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                      ),
                      child: Text(r.note!,
                          style: ZapTypography.bodySmall.copyWith(color: ZapColors.textSecondary, height: 1.5)),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: ZapSpacing.huge),
        ],
      ),
    );
  }
}

class _PriceTile extends StatelessWidget {
  const _PriceTile({required this.label, required this.price, required this.isLive});
  final String label;
  final String price;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    final color = isLive ? ZapColors.safe : ZapColors.warning;
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.sm),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: ZapTypography.labelMedium.copyWith(color: ZapColors.textSecondary)),
          const SizedBox(height: 2),
          Text(price,
              style: ZapTypography.headlineSmall.copyWith(color: color, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
