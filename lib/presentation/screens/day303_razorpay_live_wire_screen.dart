/// Day 303 — Wire Razorpay Premium Flow
///
/// QA + demo screen for the real subscription endpoints
/// (`/api/v1/subscription/create|status|cancel/`) via
/// `premium_subscription_service.dart` + `premium_subscription_providers.dart`.
/// Shows the real tier badge, contact/storage limits, and SMS priority
/// pulled from the live `status/` payload, and exercises checkout + cancel.
/// Razorpay's own checkout UI runs inside a webview on `checkout_url` —
/// completing an actual payment is a manual step that can't be automated
/// from this screen (documented below instead of faked).
/// Tag: 🔵 EXISTING-API
///
/// Route: AppRoutes.razorpayLiveWire
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/services/premium_subscription_service.dart';
import '../../domain/providers/premium_subscription_providers.dart';
import '../navigation/app_router.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';
import '../widgets/zap_snackbar.dart';

class Day303RazorpayLiveWireScreen extends ConsumerWidget {
  const Day303RazorpayLiveWireScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(subscriptionStatusRawProvider);
    final action = ref.watch(subscriptionActionProvider);

    return Scaffold(
      appBar: AppBar(title: Text('day301_305.razorpay_title'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          Text('day301_305.razorpay_heading'.tr(),
              style: ZapTypography.headlineMedium
                  .copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            'GET /api/v1/subscription/status/ — drives the tier badge below '
            'directly from the real payload.',
            style: ZapTypography.bodyMedium.copyWith(color: ZapColors.textSecondary),
          ),
          const SizedBox(height: ZapSpacing.lg),
          statusAsync.when(
            data: (s) => _StatusCard(status: s),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: ZapSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => ZapCard(
              borderColor: ZapColors.danger.withOpacity(0.4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_friendlyError(e),
                      style: ZapTypography.bodyMedium.copyWith(color: ZapColors.danger)),
                  const SizedBox(height: ZapSpacing.sm),
                  ZapButton.outlined(
                    label: 'Retry',
                    intent: ZapButtonIntent.danger,
                    onPressed: () => ref.invalidate(subscriptionStatusRawProvider),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          Text('Checkout flow (test mode)',
              style: ZapTypography.headlineSmall.copyWith(color: ZapColors.textPrimary)),
          const SizedBox(height: ZapSpacing.sm),
          ZapCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'POST /api/v1/subscription/create/ returns a Razorpay '
                  '`checkout_url`. Manual step required to actually pay: '
                  'open that URL in a webview and complete the Razorpay '
                  'test-mode flow (card 4111 1111 1111 1111, any future '
                  'expiry/CVV) — this cannot be automated headlessly from '
                  'this screen.',
                  style: ZapTypography.bodySmall.copyWith(color: ZapColors.textSecondary),
                ),
                const SizedBox(height: ZapSpacing.md),
                ZapButton.elevated(
                  label: 'Start checkout (premium)',
                  intent: ZapButtonIntent.info,
                  fullWidth: true,
                  isLoading: action.isLoading,
                  onPressed: () async {
                    final result = await ref
                        .read(subscriptionActionProvider.notifier)
                        .startCheckout(plan: SubscriptionPlan.premium);
                    if (!context.mounted) return;
                    if (result != null) {
                      ZapSnackbar.success(
                        context,
                        'Checkout URL: ${result.checkoutUrl}',
                      );
                    } else {
                      ZapSnackbar.danger(context, 'Checkout create failed — see below.');
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.lg),
          ZapCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cancel subscription',
                    style: ZapTypography.headlineSmall.copyWith(color: ZapColors.textPrimary)),
                const SizedBox(height: ZapSpacing.xs),
                Text(
                  'POST /api/v1/subscription/cancel/ — cancels at period '
                  'end; local state (tier badge above) refreshes '
                  'immediately after a successful call.',
                  style: ZapTypography.bodySmall.copyWith(color: ZapColors.textSecondary),
                ),
                const SizedBox(height: ZapSpacing.md),
                ZapButton.outlined(
                  label: 'Cancel at period end',
                  intent: ZapButtonIntent.warning,
                  fullWidth: true,
                  isLoading: action.isLoading,
                  onPressed: () async {
                    final ok = await ref.read(subscriptionActionProvider.notifier).cancel();
                    if (!context.mounted) return;
                    if (ok) {
                      ZapSnackbar.success(context, 'Cancellation requested.');
                    } else {
                      ZapSnackbar.danger(context, 'Cancel failed — see status above.');
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          ZapCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Graceful fallback',
                    style: ZapTypography.headlineSmall.copyWith(color: ZapColors.textPrimary)),
                const SizedBox(height: ZapSpacing.xs),
                Text(
                  'subscriptionStatusProvider (used by the real dashboard, '
                  'not this QA screen) falls back to SubscriptionStatus.fallback '
                  '(free tier, 3 contacts, 100MB, normal SMS priority) if the '
                  'status call fails for any reason — including Razorpay '
                  'keys being unset server-side, which the real backend '
                  'CreateSubscriptionView reports as a CheckoutError rather '
                  'than a raw 500.',
                  style: ZapTypography.bodySmall.copyWith(color: ZapColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          ZapButton.elevated(
            label: 'Back to integration audit',
            intent: ZapButtonIntent.info,
            fullWidth: true,
            onPressed: () => context.go(AppRoutes.integrationAudit),
          ),
          const SizedBox(height: ZapSpacing.huge),
        ],
      ),
    );
  }

  String _friendlyError(Object e) {
    final s = e.toString();
    if (s.contains('401')) return 'Session expired — please log in again.';
    if (s.contains('NETWORK') || s.contains('Cannot reach server')) {
      return 'Backend unreachable (is Django running?).';
    }
    return 'Status fetch failed: $s';
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status});
  final SubscriptionStatus status;

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ZapBadge(
                label: status.plan.apiValue.toUpperCase(),
                intent: status.isPremium ? ZapBadgeIntent.safe : ZapBadgeIntent.neutral,
              ),
              const SizedBox(width: ZapSpacing.sm),
              ZapBadge(
                label: status.status.toUpperCase(),
                intent: status.status == 'active' ? ZapBadgeIntent.safe : ZapBadgeIntent.warning,
                style: ZapBadgeStyle.outlined,
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          _row('Contact limit', status.contactLimit?.toString() ?? 'Unlimited'),
          _row('Storage', '${status.storageUsedBytes ~/ 1024 ~/ 1024} MB / ${status.storageLimitMb} MB'),
          _row('SMS priority', status.smsPriority),
          _row('Amount / month', '₹${status.amountMonthly}'),
          _row('Next billing', status.nextBillingDate?.toIso8601String() ?? '—'),
          _row('Premium benefits', status.hasPremiumBenefits ? 'Yes' : 'No'),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: ZapTypography.bodySmall.copyWith(color: ZapColors.textSecondary)),
            ),
            Text(value,
                style: ZapTypography.bodySmall
                    .copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
