/// Day 95-96 — Billing History screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../domain/providers/billing_history_providers.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _fmtDate(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
}

String _fmtPeriod(DateTime? start, DateTime? end) {
  if (start == null || end == null) {
    return '';
  }
  return '${_fmtDate(start)} – ${_fmtDate(end)}';
}

// ─── Root screen ──────────────────────────────────────────────────────────────

class Day95BillingHistoryScreen extends ConsumerWidget {
  const Day95BillingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoices = ref.watch(filteredInvoicesProvider);
    final state    = ref.watch(billingHistoryProvider);
    final stats    = ref.watch(billingStatsProvider);
    final years    = ref.watch(availableYearsProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: ZapColors.bgPrimary,
        surfaceTintColor: Colors.transparent,
        title: const Text('Billing History',
            style: ZapTypography.headlineSmall),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 20, color: ZapColors.textPrimary),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          // ── Stats card ────────────────────────────────────────
          _StatsCard(stats: stats),
          const SizedBox(height: ZapSpacing.lg),

          // ── Filters ───────────────────────────────────────────
          _StatusFilterRow(state: state),
          const SizedBox(height: ZapSpacing.sm),
          _YearFilterRow(state: state, years: years),
          const SizedBox(height: ZapSpacing.lg),

          // ── Results count ─────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${invoices.length} invoice${invoices.length == 1 ? '' : 's'}',
                style: ZapTypography.labelMedium
                    .copyWith(color: ZapColors.textSecondary),
              ),
              if (state.statusFilter != null || state.yearFilter != null)
                GestureDetector(
                  onTap: () {
                    ref
                        .read(billingHistoryProvider.notifier)
                        .setStatusFilter(null);
                    ref
                        .read(billingHistoryProvider.notifier)
                        .setYearFilter(null);
                  },
                  child: Text('Clear filters',
                      style: ZapTypography.labelSmall
                          .copyWith(color: ZapColors.info)),
                ),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),

          // ── Invoice list ──────────────────────────────────────
          if (invoices.isEmpty)
            const _EmptyState()
          else
            ...invoices.map(
              (inv) => _InvoiceTile(
                key: ValueKey(inv.id),
                invoice: inv,
                isDownloading: state.downloadingIds.contains(inv.id),
                isEmailing: state.emailingIds.contains(inv.id),
              ),
            ),

          const SizedBox(height: ZapSpacing.xxl),

          // ── Stripe portal banner ──────────────────────────────
          const _StripePortalBanner(),
          const SizedBox(height: ZapSpacing.xl),
        ],
      ),
    );
  }
}

// ─── Stats card ───────────────────────────────────────────────────────────────

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats});
  final BillingStats stats;

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
      child: Row(
        children: [
          Expanded(
            child: _StatCell(
              label: 'Total paid',
              value: stats.totalPaidDisplay,
              icon: Icons.payments_rounded,
              color: ZapColors.safe,
            ),
          ),
          const _VertDivider(),
          Expanded(
            child: _StatCell(
              label: 'This year',
              value: stats.thisYearDisplay,
              icon: Icons.calendar_today_rounded,
              color: ZapColors.info,
            ),
          ),
          const _VertDivider(),
          Expanded(
            child: _StatCell(
              label: 'Invoices',
              value: '${stats.invoiceCount}',
              icon: Icons.receipt_long_rounded,
              color: ZapColors.textSecondary,
            ),
          ),
          const _VertDivider(),
          Expanded(
            child: _StatCell(
              label: 'Refunds',
              value: '${stats.refundCount}',
              icon: Icons.undo_rounded,
              color: ZapColors.warning,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String   label;
  final String   value;
  final IconData icon;
  final Color    color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: ZapSpacing.xs),
        Text(value,
            style: ZapTypography.labelLarge
                .copyWith(color: ZapColors.textPrimary)),
        const SizedBox(height: 2),
        Text(label,
            style: ZapTypography.bodySmall
                .copyWith(color: ZapColors.textSecondary),
            textAlign: TextAlign.center),
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
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: ZapSpacing.sm),
      color: ZapColors.divider,
    );
  }
}

// ─── Status filter ────────────────────────────────────────────────────────────

class _StatusFilterRow extends ConsumerWidget {
  const _StatusFilterRow({required this.state});
  final BillingHistoryState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(billingHistoryProvider.notifier);

    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _FilterChip(
            label: 'All',
            selected: state.statusFilter == null,
            color: ZapColors.textSecondary,
            onTap: () => notifier.setStatusFilter(null),
          ),
          const SizedBox(width: ZapSpacing.sm),
          ...InvoiceStatus.values.map((s) => Padding(
                padding: const EdgeInsets.only(right: ZapSpacing.sm),
                child: _FilterChip(
                  label: s.label,
                  selected: state.statusFilter == s,
                  color: s.color,
                  onTap: () => notifier.setStatusFilter(
                      state.statusFilter == s ? null : s),
                ),
              )),
        ],
      ),
    );
  }
}

// ─── Year filter ──────────────────────────────────────────────────────────────

class _YearFilterRow extends ConsumerWidget {
  const _YearFilterRow({required this.state, required this.years});
  final BillingHistoryState state;
  final List<int>           years;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(billingHistoryProvider.notifier);

    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _FilterChip(
            label: 'All years',
            selected: state.yearFilter == null,
            color: ZapColors.textSecondary,
            onTap: () => notifier.setYearFilter(null),
          ),
          const SizedBox(width: ZapSpacing.sm),
          ...years.map((y) => Padding(
                padding: const EdgeInsets.only(right: ZapSpacing.sm),
                child: _FilterChip(
                  label: '$y',
                  selected: state.yearFilter == y,
                  color: ZapColors.info,
                  onTap: () => notifier.setYearFilter(
                      state.yearFilter == y ? null : y),
                ),
              )),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });
  final String       label;
  final bool         selected;
  final Color        color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
            horizontal: ZapSpacing.md, vertical: ZapSpacing.xs),
        decoration: BoxDecoration(
          color: selected ? color.withAlpha(26) : ZapColors.bgCard,
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(
            color: selected ? color : ZapColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(label,
            style: ZapTypography.labelSmall.copyWith(
              color: selected ? color : ZapColors.textSecondary,
            )),
      ),
    );
  }
}

// ─── Invoice tile ─────────────────────────────────────────────────────────────

class _InvoiceTile extends ConsumerStatefulWidget {
  const _InvoiceTile({
    super.key,
    required this.invoice,
    required this.isDownloading,
    required this.isEmailing,
  });
  final Invoice invoice;
  final bool    isDownloading;
  final bool    isEmailing;

  @override
  ConsumerState<_InvoiceTile> createState() => _InvoiceTileState();
}

class _InvoiceTileState extends ConsumerState<_InvoiceTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final inv      = widget.invoice;
    final notifier = ref.read(billingHistoryProvider.notifier);
    final color    = inv.status.color;

    return Padding(
      padding: const EdgeInsets.only(bottom: ZapSpacing.md),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: color),
              Expanded(
                child: Container(
                  color: ZapColors.bgCard,
                  child: Column(
                    children: [
                      // ── Main row ──────────────────────────────
                      InkWell(
                        onTap: () =>
                            setState(() => _expanded = !_expanded),
                        child: Padding(
                          padding: const EdgeInsets.all(ZapSpacing.lg),
                          child: Row(
                            children: [
                              // status icon
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: color.withAlpha(26),
                                  borderRadius:
                                      BorderRadius.circular(
                                          ZapSpacing.radiusSmall),
                                ),
                                child: Icon(inv.status.icon,
                                    size: 18, color: color),
                              ),
                              const SizedBox(width: ZapSpacing.md),

                              // description + number
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(inv.description,
                                        style: ZapTypography.bodyMedium
                                            .copyWith(
                                                color: ZapColors
                                                    .textPrimary),
                                        maxLines: 2,
                                        overflow:
                                            TextOverflow.ellipsis),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Text(inv.invoiceNumber,
                                            style: ZapTypography
                                                .bodySmall
                                                .copyWith(
                                                    color: ZapColors
                                                        .textMuted)),
                                        const SizedBox(
                                            width: ZapSpacing.sm),
                                        const Text('·',
                                            style: TextStyle(
                                                color:
                                                    ZapColors.textMuted)),
                                        const SizedBox(
                                            width: ZapSpacing.sm),
                                        Text(_fmtDate(inv.date),
                                            style: ZapTypography
                                                .bodySmall
                                                .copyWith(
                                                    color: ZapColors
                                                        .textSecondary)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: ZapSpacing.md),

                              // amount + expand icon
                              Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    inv.displayAmount,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: inv.status ==
                                              InvoiceStatus.refunded
                                          ? ZapColors.info
                                          : inv.status ==
                                                  InvoiceStatus.failed
                                              ? ZapColors.textMuted
                                              : ZapColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: ZapSpacing.xs),
                                  _StatusBadge(status: inv.status),
                                ],
                              ),
                              const SizedBox(width: ZapSpacing.sm),
                              Icon(
                                _expanded
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                size: 18,
                                color: ZapColors.textMuted,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ── Expanded detail ───────────────────────
                      if (_expanded) ...[
                        const Divider(
                            color: ZapColors.divider, height: 1),
                        _ExpandedDetail(
                          invoice:      inv,
                          isDownloading: widget.isDownloading,
                          isEmailing:   widget.isEmailing,
                          onDownload: () =>
                              notifier.downloadPdf(inv.id),
                          onEmail: () =>
                              notifier.emailReceipt(inv.id),
                        ),
                      ],
                    ],
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final InvoiceStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: ZapSpacing.xs, vertical: 2),
      decoration: BoxDecoration(
        color: status.color.withAlpha(26),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: status.color.withAlpha(77)),
      ),
      child: Text(status.label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: status.color,
          )),
    );
  }
}

class _ExpandedDetail extends StatelessWidget {
  const _ExpandedDetail({
    required this.invoice,
    required this.isDownloading,
    required this.isEmailing,
    required this.onDownload,
    required this.onEmail,
  });
  final Invoice  invoice;
  final bool     isDownloading;
  final bool     isEmailing;
  final VoidCallback onDownload;
  final VoidCallback onEmail;

  @override
  Widget build(BuildContext context) {
    final inv = invoice;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          ZapSpacing.lg, ZapSpacing.md, ZapSpacing.lg, ZapSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // detail rows
          if (inv.periodStart != null && inv.periodEnd != null)
            _DetailRow(
              label: 'Service period',
              value: _fmtPeriod(inv.periodStart, inv.periodEnd),
            ),
          _DetailRow(
            label: 'Plan',
            value: '${inv.planName} · ${inv.cycle.label}',
          ),
          _DetailRow(
            label: 'Currency',
            value: inv.currency,
          ),

          // failure reason
          if (inv.failureReason != null) ...[
            const SizedBox(height: ZapSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(ZapSpacing.sm),
              decoration: BoxDecoration(
                color: ZapColors.danger.withAlpha(13),
                borderRadius:
                    BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                    color: ZapColors.danger.withAlpha(51)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 14, color: ZapColors.danger),
                  const SizedBox(width: ZapSpacing.sm),
                  Expanded(
                    child: Text(inv.failureReason!,
                        style: ZapTypography.bodySmall
                            .copyWith(color: ZapColors.danger)),
                  ),
                ],
              ),
            ),
          ],

          // refund reason
          if (inv.refundReason != null) ...[
            const SizedBox(height: ZapSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(ZapSpacing.sm),
              decoration: BoxDecoration(
                color: ZapColors.info.withAlpha(13),
                borderRadius:
                    BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(color: ZapColors.info.withAlpha(51)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 14, color: ZapColors.info),
                  const SizedBox(width: ZapSpacing.sm),
                  Expanded(
                    child: Text(inv.refundReason!,
                        style: ZapTypography.bodySmall
                            .copyWith(color: ZapColors.info)),
                  ),
                ],
              ),
            ),
          ],

          // action buttons — only for paid/refunded invoices
          if (inv.status == InvoiceStatus.paid ||
              inv.status == InvoiceStatus.refunded) ...[
            const SizedBox(height: ZapSpacing.md),
            Row(
              children: [
                // download PDF
                Expanded(
                  child: _ActionButton(
                    icon: isDownloading
                        ? null
                        : Icons.download_rounded,
                    label: isDownloading
                        ? 'Downloading…'
                        : 'Download PDF',
                    loading: isDownloading,
                    color: ZapColors.info,
                    onTap: isDownloading ? null : onDownload,
                  ),
                ),
                const SizedBox(width: ZapSpacing.sm),
                // email receipt
                Expanded(
                  child: _ActionButton(
                    icon: isEmailing
                        ? null
                        : Icons.email_rounded,
                    label: isEmailing
                        ? 'Sending…'
                        : 'Email receipt',
                    loading: isEmailing,
                    color: ZapColors.textSecondary,
                    onTap: isEmailing ? null : onEmail,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ZapSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: ZapTypography.bodySmall
                  .copyWith(color: ZapColors.textSecondary)),
          Flexible(
            child: Text(value,
                style: ZapTypography.labelSmall
                    .copyWith(color: ZapColors.textPrimary),
                textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.loading,
    required this.color,
    required this.onTap,
    this.icon,
  });
  final IconData?    icon;
  final String       label;
  final bool         loading;
  final Color        color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withAlpha(128)),
        padding: const EdgeInsets.symmetric(
            vertical: ZapSpacing.sm, horizontal: ZapSpacing.sm),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        ),
        visualDensity: VisualDensity.compact,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: color),
            )
          else if (icon != null)
            Icon(icon, size: 14, color: color),
          const SizedBox(width: ZapSpacing.xs),
          Text(label,
              style:
                  ZapTypography.labelSmall.copyWith(color: color)),
        ],
      ),
    );
  }
}

// ─── Stripe portal banner ─────────────────────────────────────────────────────

class _StripePortalBanner extends StatefulWidget {
  const _StripePortalBanner();

  @override
  State<_StripePortalBanner> createState() => _StripePortalBannerState();
}

class _StripePortalBannerState extends State<_StripePortalBanner> {
  bool _opening = false;

  Future<void> _open() async {
    setState(() => _opening = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) {
      return;
    }
    setState(() => _opening = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Stripe Customer Portal would open in your browser here.'),
        backgroundColor: ZapColors.bgElevated,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.border),
      ),
      padding: const EdgeInsets.all(ZapSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF635BFF).withAlpha(26),
              borderRadius:
                  BorderRadius.circular(ZapSpacing.radiusSmall),
            ),
            child: const Icon(Icons.open_in_new_rounded,
                size: 20, color: Color(0xFF635BFF)),
          ),
          const SizedBox(width: ZapSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Stripe Customer Portal',
                    style: ZapTypography.labelLarge
                        .copyWith(color: ZapColors.textPrimary)),
                const SizedBox(height: 2),
                Text(
                  'Full invoice history, payment method updates, '
                  'and tax documents.',
                  style: ZapTypography.bodySmall
                      .copyWith(color: ZapColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: ZapSpacing.md),
          _opening
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF635BFF),
                  ),
                )
              : IconButton(
                  onPressed: _open,
                  icon: const Icon(Icons.arrow_forward_ios_rounded,
                      size: 16, color: ZapColors.textSecondary),
                  visualDensity: VisualDensity.compact,
                ),
        ],
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
      padding: const EdgeInsets.symmetric(vertical: ZapSpacing.massive),
      child: Column(
        children: [
          const Icon(Icons.receipt_long_rounded,
              size: 52, color: ZapColors.textMuted),
          const SizedBox(height: ZapSpacing.lg),
          Text('No invoices found',
              style: ZapTypography.labelLarge
                  .copyWith(color: ZapColors.textSecondary)),
          const SizedBox(height: ZapSpacing.sm),
          Text('Try removing the active filters.',
              style: ZapTypography.bodySmall
                  .copyWith(color: ZapColors.textMuted)),
        ],
      ),
    );
  }
}
