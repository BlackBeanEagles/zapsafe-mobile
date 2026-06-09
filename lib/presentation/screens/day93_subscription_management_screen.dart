/// Day 93-94 — Subscription Management screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../domain/providers/subscription_management_providers.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _fmtDate(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
}

// ─── Root screen ──────────────────────────────────────────────────────────────

class Day93SubscriptionManagementScreen extends ConsumerWidget {
  const Day93SubscriptionManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state    = ref.watch(subscriptionManagementProvider);
    final notifier = ref.read(subscriptionManagementProvider.notifier);

    // Show SnackBar whenever lastActionMessage appears
    ref.listen(subscriptionManagementProvider, (prev, next) {
      final msg = next.lastActionMessage;
      if (msg != null && msg != prev?.lastActionMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: ZapColors.bgElevated,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'OK',
              textColor: ZapColors.info,
              onPressed: notifier.clearMessage,
            ),
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: ZapColors.bgPrimary,
        surfaceTintColor: Colors.transparent,
        title: const Text('Subscription', style: ZapTypography.headlineSmall),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 20, color: ZapColors.textPrimary),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          // ── Status banner (if cancelled/cancels-at-end) ───────
          if (state.detail.status != PlanStatus.active) ...[
            _StatusBanner(state: state),
            const SizedBox(height: ZapSpacing.lg),
          ],

          // ── Current plan card ─────────────────────────────────
          _PlanCard(detail: state.detail),
          const SizedBox(height: ZapSpacing.lg),

          // ── Billing details card ──────────────────────────────
          _BillingCard(detail: state.detail),
          const SizedBox(height: ZapSpacing.lg),

          // ── Billing cycle switcher ────────────────────────────
          if (state.detail.status == PlanStatus.active) ...[
            _CycleSwitcher(state: state),
            const SizedBox(height: ZapSpacing.lg),
          ],

          // ── Included perks ────────────────────────────────────
          const _PerksCard(),
          const SizedBox(height: ZapSpacing.xxl),

          // ── Danger zone ───────────────────────────────────────
          _DangerZone(state: state),
          const SizedBox(height: ZapSpacing.xxl),
        ],
      ),
    );
  }
}

// ─── Status banner ────────────────────────────────────────────────────────────

class _StatusBanner extends ConsumerWidget {
  const _StatusBanner({required this.state});
  final ManagementState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail   = state.detail;
    final notifier = ref.read(subscriptionManagementProvider.notifier);
    final isCancelledAtEnd =
        detail.status == PlanStatus.cancelledAtPeriodEnd;

    return ClipRRect(
      borderRadius: BorderRadius.circular(ZapSpacing.radius),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: detail.status.color),
            Expanded(
              child: Container(
                color: ZapColors.bgCard,
                padding: const EdgeInsets.all(ZapSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(detail.status.icon,
                            size: 16, color: detail.status.color),
                        const SizedBox(width: ZapSpacing.sm),
                        Text(detail.status.label,
                            style: ZapTypography.labelLarge
                                .copyWith(color: detail.status.color)),
                      ],
                    ),
                    const SizedBox(height: ZapSpacing.sm),
                    Text(
                      isCancelledAtEnd
                          ? 'Premium access remains active until '
                            '${_fmtDate(detail.nextBillingDate)}. '
                            'Reactivate anytime to continue without interruption.'
                          : 'Your subscription has ended. '
                            'Upgrade again to restore Premium features.',
                      style: ZapTypography.bodySmall
                          .copyWith(color: ZapColors.textSecondary),
                    ),
                    if (isCancelledAtEnd) ...[
                      const SizedBox(height: ZapSpacing.md),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: state.isReactivating
                              ? null
                              : notifier.reactivate,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: ZapColors.safe,
                            side: const BorderSide(color: ZapColors.safe),
                            padding: const EdgeInsets.symmetric(
                                vertical: ZapSpacing.sm),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(ZapSpacing.radius),
                            ),
                          ),
                          child: state.isReactivating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: ZapColors.safe,
                                  ),
                                )
                              : Text('Reactivate subscription',
                                  style: ZapTypography.labelLarge
                                      .copyWith(color: ZapColors.safe)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Plan card ────────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.detail});
  final SubscriptionDetail detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A2744), Color(0xFF0D1B38)],
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.info.withAlpha(51)),
      ),
      padding: const EdgeInsets.all(ZapSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ZapColors.info.withAlpha(26),
                  border: Border.all(
                      color: ZapColors.info.withAlpha(77)),
                ),
                child: const Icon(Icons.shield_rounded,
                    size: 22, color: ZapColors.info),
              ),
              const SizedBox(width: ZapSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(detail.plan,
                        style: ZapTypography.headlineSmall
                            .copyWith(color: ZapColors.textPrimary)),
                    Text(detail.billingCycle.billedLabel,
                        style: ZapTypography.bodySmall
                            .copyWith(color: ZapColors.textSecondary)),
                  ],
                ),
              ),
              // status badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: ZapSpacing.sm, vertical: 4),
                decoration: BoxDecoration(
                  color: detail.status.color.withAlpha(26),
                  borderRadius:
                      BorderRadius.circular(ZapSpacing.radiusSmall),
                  border: Border.all(
                      color: detail.status.color.withAlpha(77)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(detail.status.icon,
                        size: 12, color: detail.status.color),
                    const SizedBox(width: 4),
                    Text(detail.status.label,
                        style: ZapTypography.labelSmall
                            .copyWith(color: detail.status.color)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.xl),

          // price display
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${detail.billingCycle.monthlyPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: ZapColors.textPrimary,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text('/ mo',
                    style: ZapTypography.bodyMedium
                        .copyWith(color: ZapColors.textSecondary)),
              ),
              const Spacer(),
              if (detail.billingCycle == MgmtBillingCycle.annual)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: ZapSpacing.sm, vertical: 3),
                  decoration: BoxDecoration(
                    color: ZapColors.safe.withAlpha(26),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: ZapColors.safe.withAlpha(77)),
                  ),
                  child: Text('20% saved',
                      style: ZapTypography.labelSmall
                          .copyWith(color: ZapColors.safe)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '\$${detail.billingCycle.billedAmount.toStringAsFixed(2)} '
            'billed ${detail.billingCycle == MgmtBillingCycle.annual ? 'annually' : 'monthly'}',
            style: ZapTypography.bodySmall
                .copyWith(color: ZapColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ─── Billing details card ─────────────────────────────────────────────────────

class _BillingCard extends StatelessWidget {
  const _BillingCard({required this.detail});
  final SubscriptionDetail detail;

  @override
  Widget build(BuildContext context) {
    final isCancelledAtEnd =
        detail.status == PlanStatus.cancelledAtPeriodEnd;

    return Container(
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.border),
      ),
      child: Column(
        children: [
          _BillingRow(
            icon: Icons.calendar_today_rounded,
            label: isCancelledAtEnd ? 'Access until' : 'Next billing date',
            value: _fmtDate(detail.nextBillingDate),
            valueColor: isCancelledAtEnd
                ? ZapColors.warning
                : ZapColors.textPrimary,
          ),
          const Divider(color: ZapColors.divider, height: 1),
          _BillingRow(
            icon: Icons.event_rounded,
            label: 'Current period started',
            value: _fmtDate(detail.currentPeriodStart),
            valueColor: ZapColors.textPrimary,
          ),
          const Divider(color: ZapColors.divider, height: 1),
          _BillingRow(
            icon: Icons.payments_rounded,
            label: 'Amount due',
            value: isCancelledAtEnd
                ? '\$0.00'
                : '\$${detail.billingCycle.billedAmount.toStringAsFixed(2)}',
            valueColor: isCancelledAtEnd
                ? ZapColors.textMuted
                : ZapColors.textPrimary,
          ),
          const Divider(color: ZapColors.divider, height: 1),
          _BillingRow(
            icon: Icons.hourglass_top_rounded,
            label: 'Days remaining',
            value: '${detail.daysRemaining} days',
            valueColor: detail.daysRemaining < 7
                ? ZapColors.warning
                : ZapColors.textPrimary,
          ),
        ],
      ),
    );
  }
}

class _BillingRow extends StatelessWidget {
  const _BillingRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
  });
  final IconData icon;
  final String   label;
  final String   value;
  final Color    valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: ZapSpacing.lg, vertical: ZapSpacing.md),
      child: Row(
        children: [
          Icon(icon, size: 16, color: ZapColors.textSecondary),
          const SizedBox(width: ZapSpacing.md),
          Expanded(
            child: Text(label,
                style: ZapTypography.bodyMedium
                    .copyWith(color: ZapColors.textSecondary)),
          ),
          Text(value,
              style: ZapTypography.labelMedium
                  .copyWith(color: valueColor)),
        ],
      ),
    );
  }
}

// ─── Billing cycle switcher ───────────────────────────────────────────────────

class _CycleSwitcher extends ConsumerWidget {
  const _CycleSwitcher({required this.state});
  final ManagementState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier  = ref.read(subscriptionManagementProvider.notifier);
    final detail    = state.detail;
    final isSwitching = state.isSwitchingCycle;
    final isAnnual  = detail.billingCycle == MgmtBillingCycle.annual;

    return Container(
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.border),
      ),
      padding: const EdgeInsets.all(ZapSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sync_alt_rounded,
                  size: 18, color: ZapColors.info),
              const SizedBox(width: ZapSpacing.sm),
              Text('Billing Cycle',
                  style: ZapTypography.labelLarge
                      .copyWith(color: ZapColors.textPrimary)),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),

          // current cycle info
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current: ${detail.billingCycle.label}',
                      style: ZapTypography.bodyMedium
                          .copyWith(color: ZapColors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '\$${detail.billingCycle.billedAmount.toStringAsFixed(2)}'
                      ' ${isAnnual ? "/ year" : "/ month"}',
                      style: ZapTypography.bodySmall
                          .copyWith(color: ZapColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (!isAnnual)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: ZapSpacing.sm, vertical: 3),
                  decoration: BoxDecoration(
                    color: ZapColors.safe.withAlpha(26),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: ZapColors.safe.withAlpha(77)),
                  ),
                  child: Text('Save 20% going annual',
                      style: ZapTypography.labelSmall
                          .copyWith(color: ZapColors.safe)),
                ),
            ],
          ),

          if (!isAnnual) ...[
            const SizedBox(height: ZapSpacing.sm),
            Container(
              padding: const EdgeInsets.all(ZapSpacing.sm),
              decoration: BoxDecoration(
                color: ZapColors.safe.withAlpha(13),
                borderRadius:
                    BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(color: ZapColors.safe.withAlpha(51)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.savings_rounded,
                      size: 14, color: ZapColors.safe),
                  const SizedBox(width: ZapSpacing.sm),
                  Expanded(
                    child: Text(
                      'Switch to annual and save '
                      '\$${(4.99 * 12 - 47.88).toStringAsFixed(2)}/year',
                      style: ZapTypography.bodySmall
                          .copyWith(color: ZapColors.safe),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: ZapSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: isSwitching ? null : () => _confirmSwitch(context, notifier, detail),
              style: OutlinedButton.styleFrom(
                foregroundColor: ZapColors.info,
                side: const BorderSide(color: ZapColors.info),
                padding:
                    const EdgeInsets.symmetric(vertical: ZapSpacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ZapSpacing.radius),
                ),
              ),
              child: isSwitching
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: ZapColors.info,
                      ),
                    )
                  : Text(detail.billingCycle.switchCtaLabel,
                      style: ZapTypography.labelLarge
                          .copyWith(color: ZapColors.info)),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmSwitch(
    BuildContext context,
    ManagementNotifier notifier,
    SubscriptionDetail detail,
  ) {
    final other     = detail.billingCycle.other;
    final newAmount = other.billedAmount;
    final period    = other == MgmtBillingCycle.annual ? 'year' : 'month';

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ZapColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(ZapSpacing.radiusSmall)),
      ),
      builder: (_) => _ConfirmSwitchSheet(
        newCycle: other,
        newAmount: newAmount,
        period: period,
        onConfirm: notifier.switchBillingCycle,
      ),
    );
  }
}

class _ConfirmSwitchSheet extends StatefulWidget {
  const _ConfirmSwitchSheet({
    required this.newCycle,
    required this.newAmount,
    required this.period,
    required this.onConfirm,
  });
  final MgmtBillingCycle newCycle;
  final double           newAmount;
  final String           period;
  final Future<void> Function() onConfirm;

  @override
  State<_ConfirmSwitchSheet> createState() => _ConfirmSwitchSheetState();
}

class _ConfirmSwitchSheetState extends State<_ConfirmSwitchSheet> {
  bool _loading = false;

  Future<void> _submit() async {
    setState(() => _loading = true);
    await widget.onConfirm();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(ZapSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: ZapSpacing.xl),
              decoration: BoxDecoration(
                  color: ZapColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const Icon(Icons.sync_alt_rounded,
                size: 32, color: ZapColors.info),
            const SizedBox(height: ZapSpacing.md),
            Text('Switch to ${widget.newCycle.label}?',
                style: ZapTypography.headlineSmall),
            const SizedBox(height: ZapSpacing.sm),
            Text(
              'You\'ll be charged \$${widget.newAmount.toStringAsFixed(2)} '
              'per ${widget.period} starting from your next billing date.',
              style: ZapTypography.bodyMedium
                  .copyWith(color: ZapColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: ZapSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _loading
                        ? null
                        : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ZapColors.textSecondary,
                      side: const BorderSide(color: ZapColors.border),
                      padding: const EdgeInsets.symmetric(
                          vertical: ZapSpacing.md),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(ZapSpacing.radius),
                      ),
                    ),
                    child: Text('Cancel',
                        style: ZapTypography.labelLarge
                            .copyWith(
                                color: ZapColors.textSecondary)),
                  ),
                ),
                const SizedBox(width: ZapSpacing.md),
                Expanded(
                  child: FilledButton(
                    onPressed: _loading ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: ZapColors.info,
                      padding: const EdgeInsets.symmetric(
                          vertical: ZapSpacing.md),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(ZapSpacing.radius),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white),
                          )
                        : Text('Confirm',
                            style: ZapTypography.labelLarge
                                .copyWith(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Included perks card ──────────────────────────────────────────────────────

class _PerksCard extends StatelessWidget {
  const _PerksCard();

  @override
  Widget build(BuildContext context) {
    const perks = <_Perk>[
      _Perk(icon: Icons.people_rounded,      label: 'Unlimited emergency contacts'),
      _Perk(icon: Icons.bolt_rounded,         label: 'Priority SMS — sub-500 ms'),
      _Perk(icon: Icons.folder_rounded,       label: '5 GB encrypted evidence storage'),
      _Perk(icon: Icons.wifi_off_rounded,     label: 'Full offline SOS mode'),
      _Perk(icon: Icons.location_on_rounded,  label: 'Unlimited safe zones'),
      _Perk(icon: Icons.history_rounded,      label: '1-year activity history'),
      _Perk(icon: Icons.headset_mic_rounded,  label: '24/7 priority support'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                ZapSpacing.lg, ZapSpacing.lg, ZapSpacing.lg, ZapSpacing.sm),
            child: Row(
              children: [
                const Icon(Icons.star_rounded,
                    size: 16, color: ZapColors.warning),
                const SizedBox(width: ZapSpacing.sm),
                Text('What\'s included',
                    style: ZapTypography.labelLarge
                        .copyWith(color: ZapColors.textPrimary)),
              ],
            ),
          ),
          const Divider(color: ZapColors.divider, height: 1),
          ...perks.map((p) => _PerkRow(perk: p)),
        ],
      ),
    );
  }
}

class _Perk {
  const _Perk({required this.icon, required this.label});
  final IconData icon;
  final String   label;
}

class _PerkRow extends StatelessWidget {
  const _PerkRow({required this.perk});
  final _Perk perk;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: ZapSpacing.lg, vertical: ZapSpacing.sm),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              size: 14, color: ZapColors.safe),
          const SizedBox(width: ZapSpacing.sm),
          Icon(perk.icon, size: 14, color: ZapColors.textSecondary),
          const SizedBox(width: ZapSpacing.sm),
          Text(perk.label,
              style: ZapTypography.bodyMedium
                  .copyWith(color: ZapColors.textPrimary)),
        ],
      ),
    );
  }
}

// ─── Danger zone ──────────────────────────────────────────────────────────────

class _DangerZone extends ConsumerWidget {
  const _DangerZone({required this.state});
  final ManagementState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(subscriptionManagementProvider.notifier);
    final detail   = state.detail;

    // Don't show cancel button if already cancelled
    if (detail.status == PlanStatus.cancelled) {
      return const SizedBox.shrink();
    }
    if (detail.status == PlanStatus.cancelledAtPeriodEnd) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.danger.withAlpha(51)),
      ),
      padding: const EdgeInsets.all(ZapSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 18, color: ZapColors.danger),
              const SizedBox(width: ZapSpacing.sm),
              Text('Cancel Subscription',
                  style: ZapTypography.labelLarge
                      .copyWith(color: ZapColors.danger)),
            ],
          ),
          const SizedBox(height: ZapSpacing.sm),
          Text(
            'Cancelling will not end access immediately. You keep all '
            'Premium features until ${_fmtDate(detail.nextBillingDate)}, '
            'then your account downgrades to Free.',
            style: ZapTypography.bodySmall
                .copyWith(color: ZapColors.textSecondary),
          ),
          const SizedBox(height: ZapSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: state.isCancelling
                  ? null
                  : () => _showCancelSheet(context, notifier, detail),
              style: OutlinedButton.styleFrom(
                foregroundColor: ZapColors.danger,
                side: const BorderSide(color: ZapColors.danger),
                padding:
                    const EdgeInsets.symmetric(vertical: ZapSpacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ZapSpacing.radius),
                ),
              ),
              child: state.isCancelling
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: ZapColors.danger,
                      ),
                    )
                  : Text('Cancel Subscription',
                      style: ZapTypography.labelLarge
                          .copyWith(color: ZapColors.danger)),
            ),
          ),
        ],
      ),
    );
  }

  void _showCancelSheet(
    BuildContext context,
    ManagementNotifier notifier,
    SubscriptionDetail detail,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ZapColors.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(ZapSpacing.radiusSmall)),
      ),
      builder: (_) => _CancelSheet(
        accessUntil: detail.nextBillingDate,
        onCancel: notifier.cancelSubscription,
      ),
    );
  }
}

// ─── Cancel sheet ─────────────────────────────────────────────────────────────

class _CancelSheet extends StatefulWidget {
  const _CancelSheet({
    required this.accessUntil,
    required this.onCancel,
  });
  final DateTime                           accessUntil;
  final Future<void> Function(CancelReason?) onCancel;

  @override
  State<_CancelSheet> createState() => _CancelSheetState();
}

class _CancelSheetState extends State<_CancelSheet> {
  CancelReason? _reason;
  bool          _loading = false;

  Future<void> _submit() async {
    setState(() => _loading = true);
    final messenger = ScaffoldMessenger.of(context);
    await widget.onCancel(_reason);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
            'Subscription cancelled. Access until '
            '${_fmtDate(widget.accessUntil)}.'),
        backgroundColor: ZapColors.bgElevated,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(ZapSpacing.xxl, ZapSpacing.md,
          ZapSpacing.xxl, ZapSpacing.xxl + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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

          Row(
            children: [
              const Icon(Icons.cancel_rounded,
                  size: 22, color: ZapColors.danger),
              const SizedBox(width: ZapSpacing.sm),
              Text('Cancel Subscription',
                  style: ZapTypography.headlineSmall
                      .copyWith(color: ZapColors.danger)),
            ],
          ),
          const SizedBox(height: ZapSpacing.sm),
          Text(
            'You\'ll keep Premium until ${_fmtDate(widget.accessUntil)}. '
            'No charge after that.',
            style: ZapTypography.bodyMedium
                .copyWith(color: ZapColors.textSecondary),
          ),
          const SizedBox(height: ZapSpacing.xl),

          Text('Reason (optional)',
              style: ZapTypography.labelMedium
                  .copyWith(color: ZapColors.textSecondary)),
          const SizedBox(height: ZapSpacing.sm),

          ...CancelReason.values.map((r) {
            final selected = _reason == r;
            return GestureDetector(
              onTap: _loading
                  ? null
                  : () => setState(() {
                        _reason = selected ? null : r;
                      }),
              child: Container(
                width: double.infinity,
                margin:
                    const EdgeInsets.only(bottom: ZapSpacing.sm),
                padding: const EdgeInsets.symmetric(
                    horizontal: ZapSpacing.lg,
                    vertical: ZapSpacing.md),
                decoration: BoxDecoration(
                  color: selected
                      ? ZapColors.danger.withAlpha(13)
                      : ZapColors.bgSurface,
                  borderRadius:
                      BorderRadius.circular(ZapSpacing.radiusSmall),
                  border: Border.all(
                    color: selected
                        ? ZapColors.danger.withAlpha(77)
                        : ZapColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      selected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 16,
                      color: selected
                          ? ZapColors.danger
                          : ZapColors.textMuted,
                    ),
                    const SizedBox(width: ZapSpacing.md),
                    Text(r.label,
                        style: ZapTypography.bodyMedium.copyWith(
                          color: selected
                              ? ZapColors.textPrimary
                              : ZapColors.textSecondary,
                        )),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: ZapSpacing.lg),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _loading
                      ? null
                      : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ZapColors.safe,
                    side: const BorderSide(color: ZapColors.safe),
                    padding: const EdgeInsets.symmetric(
                        vertical: ZapSpacing.md),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(ZapSpacing.radius),
                    ),
                  ),
                  child: Text('Keep Premium',
                      style: ZapTypography.labelLarge
                          .copyWith(color: ZapColors.safe)),
                ),
              ),
              const SizedBox(width: ZapSpacing.md),
              Expanded(
                child: FilledButton(
                  onPressed: _loading ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: ZapColors.danger,
                    disabledBackgroundColor: ZapColors.bgElevated,
                    padding: const EdgeInsets.symmetric(
                        vertical: ZapSpacing.md),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(ZapSpacing.radius),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white),
                        )
                      : Text('Confirm Cancel',
                          style: ZapTypography.labelLarge
                              .copyWith(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
