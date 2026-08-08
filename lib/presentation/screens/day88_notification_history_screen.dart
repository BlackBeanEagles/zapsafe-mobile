/// Day 88 — Notification History Screen (v2).
///
/// Refined timeline: stats bar · dual-filter chips · date-grouped list ·
/// expandable delivery timeline · retry-on-failed · clear history.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../domain/providers/notification_history_providers_v2.dart';

// ─── Helpers ─────────────────────────────────────────────────────────────────

List<Object> _buildGrouped(List<NotifEntry> entries) {
  if (entries.isEmpty) {
    return [];
  }

  final now       = DateTime.now();
  final today     = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  const months    = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  final result   = <Object>[];
  String? lastHdr;

  for (final entry in entries) {
    final d      = entry.sentAt;
    final bucket = DateTime(d.year, d.month, d.day);

    final String hdr;
    if (bucket == today) {
      hdr = 'Today';
    } else if (bucket == yesterday) {
      hdr = 'Yesterday';
    } else {
      hdr = '${d.day} ${months[d.month - 1]}';
    }

    if (hdr != lastHdr) {
      result.add(hdr);
      lastHdr = hdr;
    }
    result.add(entry);
  }

  return result;
}

String _fmtTime(DateTime? dt) {
  if (dt == null) {
    return '';
  }
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

String _fmtFull(DateTime? dt) {
  if (dt == null) {
    return '—';
  }
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${dt.day} ${months[dt.month - 1]}, ${_fmtTime(dt)}';
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class Day88NotificationHistoryScreen extends ConsumerWidget {
  const Day88NotificationHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all      = ref.watch(notifHistoryProvider);
    final filtered = ref.watch(filteredNotifProvider);

    final totalCount = all.length;
    final deliveredCount = all
        .where((e) =>
            e.status == NotifStatus.delivered ||
            e.status == NotifStatus.acked)
        .length;
    final failedCount  = all.where((e) => e.status == NotifStatus.failed).length;
    final pendingCount = all.where((e) => e.status == NotifStatus.sent).length;

    final grouped = _buildGrouped(filtered);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: ZapColors.bgPrimary,
        elevation: 0,
        iconTheme: const IconThemeData(color: ZapColors.textPrimary),
        title: Text(
          'Notification History',
          style: ZapTypography.headlineSmall.copyWith(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: 'Clear history',
            color: ZapColors.textSecondary,
            onPressed: all.isEmpty ? null : () => _confirmClear(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          _StatsBar(
            total: totalCount,
            delivered: deliveredCount,
            failed: failedCount,
            pending: pendingCount,
          ),
          const _FilterRow(),
          const Divider(height: 1, thickness: 1, color: ZapColors.divider),
          Expanded(
            child: grouped.isEmpty
                ? const _EmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                        ZapSpacing.lg, ZapSpacing.md,
                        ZapSpacing.lg, ZapSpacing.lg),
                    itemCount: grouped.length,
                    itemBuilder: (ctx, i) {
                      final item = grouped[i];
                      if (item is String) {
                        return _DateHeader(label: item);
                      }
                      final entry = item as NotifEntry;
                      return _NotifTile(
                        key: ValueKey(entry.id),
                        entry: entry,
                        onRetry: () => ref
                            .read(notifHistoryProvider.notifier)
                            .retry(entry.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: ZapColors.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
        ),
        title: Text(
          'Clear History',
          style: ZapTypography.headlineSmall.copyWith(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'All notification history will be permanently removed. '
          'This cannot be undone.',
          style: ZapTypography.bodyMedium.copyWith(
            color: ZapColors.textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: ZapTypography.labelMedium.copyWith(
                  color: ZapColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Clear All',
              style: ZapTypography.labelMedium.copyWith(
                color: ZapColors.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      ref.read(notifHistoryProvider.notifier).clearAll();
    }
  }
}

// ─── Stats bar ────────────────────────────────────────────────────────────────

class _StatsBar extends StatelessWidget {
  const _StatsBar({
    required this.total,
    required this.delivered,
    required this.failed,
    required this.pending,
  });

  final int total;
  final int delivered;
  final int failed;
  final int pending;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ZapColors.bgCard,
      padding: const EdgeInsets.symmetric(
          horizontal: ZapSpacing.lg, vertical: ZapSpacing.md),
      child: Row(
        children: [
          _StatCell(value: total,     label: 'Total',     color: ZapColors.textSecondary),
          const _VertDivider(),
          _StatCell(value: delivered, label: 'Delivered', color: ZapColors.safe),
          const _VertDivider(),
          _StatCell(value: failed,    label: 'Failed',    color: ZapColors.danger),
          const _VertDivider(),
          _StatCell(value: pending,   label: 'Pending',   color: ZapColors.warning),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.value,
    required this.label,
    required this.color,
  });

  final int    value;
  final String label;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: ZapTypography.headlineSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: ZapTypography.labelSmall.copyWith(
              color: ZapColors.textMuted,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _VertDivider extends StatelessWidget {
  const _VertDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      color: ZapColors.divider,
      margin: const EdgeInsets.symmetric(horizontal: ZapSpacing.sm),
    );
  }
}

// ─── Filter row ───────────────────────────────────────────────────────────────

class _FilterRow extends ConsumerWidget {
  const _FilterRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chanFil = ref.watch(notifChannelFilterProvider);
    final statFil = ref.watch(notifStatusFilterProvider);

    return Container(
      color: ZapColors.bgCard,
      height: 48,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
            horizontal: ZapSpacing.lg, vertical: ZapSpacing.sm),
        child: Row(
          children: [
            // Channel chips
            _Chip(
              label: 'All',
              selected: chanFil == null,
              onTap: () =>
                  ref.read(notifChannelFilterProvider.notifier).state = null,
            ),
            const SizedBox(width: ZapSpacing.xs),
            _Chip(
              label: 'Push',
              icon: Icons.notifications_rounded,
              accent: ZapColors.info,
              selected: chanFil == NotifChannel.push,
              onTap: () => ref.read(notifChannelFilterProvider.notifier).state =
                  NotifChannel.push,
            ),
            const SizedBox(width: ZapSpacing.xs),
            _Chip(
              label: 'SMS',
              icon: Icons.sms_rounded,
              accent: ZapColors.warning,
              selected: chanFil == NotifChannel.sms,
              onTap: () => ref.read(notifChannelFilterProvider.notifier).state =
                  NotifChannel.sms,
            ),
            // Group separator
            Container(
              width: 1,
              height: 20,
              color: ZapColors.divider,
              margin: const EdgeInsets.symmetric(horizontal: ZapSpacing.sm),
            ),
            // Status chips
            _Chip(
              label: 'All',
              selected: statFil == null,
              onTap: () =>
                  ref.read(notifStatusFilterProvider.notifier).state = null,
            ),
            const SizedBox(width: ZapSpacing.xs),
            _Chip(
              label: 'Delivered',
              accent: ZapColors.safe,
              selected: statFil == NotifStatus.delivered,
              onTap: () =>
                  ref.read(notifStatusFilterProvider.notifier).state =
                      NotifStatus.delivered,
            ),
            const SizedBox(width: ZapSpacing.xs),
            _Chip(
              label: 'Opened',
              accent: ZapColors.safe,
              selected: statFil == NotifStatus.acked,
              onTap: () =>
                  ref.read(notifStatusFilterProvider.notifier).state =
                      NotifStatus.acked,
            ),
            const SizedBox(width: ZapSpacing.xs),
            _Chip(
              label: 'Failed',
              accent: ZapColors.danger,
              selected: statFil == NotifStatus.failed,
              onTap: () =>
                  ref.read(notifStatusFilterProvider.notifier).state =
                      NotifStatus.failed,
            ),
            const SizedBox(width: ZapSpacing.xs),
            _Chip(
              label: 'Pending',
              accent: ZapColors.warning,
              selected: statFil == NotifStatus.sent,
              onTap: () =>
                  ref.read(notifStatusFilterProvider.notifier).state =
                      NotifStatus.sent,
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.accent,
  });

  final String       label;
  final bool         selected;
  final VoidCallback onTap;
  final IconData?    icon;
  final Color?       accent;

  @override
  Widget build(BuildContext context) {
    final c = accent ?? ZapColors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
            horizontal: ZapSpacing.sm, vertical: ZapSpacing.xs),
        decoration: BoxDecoration(
          color: selected ? c.withOpacity(0.15) : ZapColors.bgSurface,
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(
            color: selected ? c : ZapColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: selected ? c : ZapColors.textMuted),
              const SizedBox(width: ZapSpacing.xs),
            ],
            Text(
              label,
              style: ZapTypography.labelSmall.copyWith(
                color: selected ? c : ZapColors.textSecondary,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Date header ─────────────────────────────────────────────────────────────

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: ZapSpacing.lg, bottom: ZapSpacing.sm),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: ZapTypography.labelSmall.copyWith(
              color: ZapColors.textSecondary,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: ZapSpacing.md),
          const Expanded(child: Divider(color: ZapColors.divider, height: 1)),
        ],
      ),
    );
  }
}

// ─── Notification tile ────────────────────────────────────────────────────────

class _NotifTile extends StatefulWidget {
  const _NotifTile({
    super.key,
    required this.entry,
    required this.onRetry,
  });

  final NotifEntry   entry;
  final VoidCallback onRetry;

  @override
  State<_NotifTile> createState() => _NotifTileState();
}

class _NotifTileState extends State<_NotifTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final e        = widget.entry;
    final statCol  = e.status.color;
    final isFailed = e.status == NotifStatus.failed;

    return Padding(
      padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
      child: GestureDetector(
        onTap: () => setState(() {
          _expanded = !_expanded;
        }),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Status accent bar
                Container(width: 4, color: statCol),
                // Card content
                Expanded(
                  child: Container(
                    color: ZapColors.bgCard,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Header ──────────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                              ZapSpacing.md, ZapSpacing.md,
                              ZapSpacing.md, 0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Channel icon
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: e.channel.color.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(
                                      ZapSpacing.radiusSmall),
                                ),
                                child: Icon(e.channel.icon,
                                    color: e.channel.color, size: 16),
                              ),
                              const SizedBox(width: ZapSpacing.sm),
                              // Title + recipient
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      e.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: ZapTypography.bodyMedium.copyWith(
                                        color: ZapColors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      'To: ${e.recipientName}',
                                      style: ZapTypography.bodySmall.copyWith(
                                          color: ZapColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: ZapSpacing.sm),
                              // Status badge + time
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  _StatusBadge(status: e.status),
                                  const SizedBox(height: ZapSpacing.xs),
                                  Text(
                                    _fmtTime(e.sentAt),
                                    style: ZapTypography.labelSmall.copyWith(
                                        color: ZapColors.textMuted),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // ── Body preview ─────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                              ZapSpacing.md, ZapSpacing.xs,
                              ZapSpacing.md, 0),
                          child: Text(
                            e.body,
                            maxLines: _expanded ? null : 2,
                            overflow: _expanded
                                ? TextOverflow.visible
                                : TextOverflow.ellipsis,
                            style: ZapTypography.bodySmall.copyWith(
                                color: ZapColors.textSecondary, height: 1.5),
                          ),
                        ),
                        // ── SOS event badge ───────────────────────────────
                        if (e.sosEventId != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                                ZapSpacing.md, ZapSpacing.xs,
                                ZapSpacing.md, 0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.link_rounded,
                                    color: ZapColors.danger, size: 12),
                                const SizedBox(width: ZapSpacing.xs),
                                Flexible(
                                  child: Text(
                                    'SOS: ${e.sosEventId}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: ZapTypography.labelSmall.copyWith(
                                      color: ZapColors.danger,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // ── Expand toggle ─────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                              ZapSpacing.md, ZapSpacing.xs,
                              ZapSpacing.md, ZapSpacing.sm),
                          child: Row(
                            children: [
                              Icon(
                                _expanded
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                color: ZapColors.textMuted,
                                size: 14,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                _expanded
                                    ? 'Hide details'
                                    : 'Delivery details',
                                style: ZapTypography.labelSmall.copyWith(
                                    color: ZapColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                        // ── Expanded detail section ───────────────────────
                        if (_expanded) ...[
                          const Divider(
                              height: 1, thickness: 1,
                              color: ZapColors.divider),
                          Padding(
                            padding: const EdgeInsets.all(ZapSpacing.md),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Type + channel + phone
                                Row(
                                  children: [
                                    Icon(e.type.icon,
                                        size: 12,
                                        color: ZapColors.textMuted),
                                    const SizedBox(width: ZapSpacing.xs),
                                    Expanded(
                                      child: Text(
                                        '${e.type.label}  ·  '
                                        '${e.channel.label}  ·  '
                                        '${e.recipientPhone}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: ZapTypography.labelSmall
                                            .copyWith(
                                                color: ZapColors.textMuted),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: ZapSpacing.md),
                                // Delivery timeline
                                _DeliveryTimeline(entry: e),
                                // Error box
                                if (isFailed && e.errorMessage != null) ...[
                                  const SizedBox(height: ZapSpacing.sm),
                                  Container(
                                    width: double.infinity,
                                    padding:
                                        const EdgeInsets.all(ZapSpacing.sm),
                                    decoration: BoxDecoration(
                                      color: ZapColors.danger.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(
                                          ZapSpacing.radiusSmall),
                                      border: Border.all(
                                        color:
                                            ZapColors.danger.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                            Icons.error_outline_rounded,
                                            color: ZapColors.danger,
                                            size: 14),
                                        const SizedBox(width: ZapSpacing.xs),
                                        Expanded(
                                          child: Text(
                                            e.errorMessage!,
                                            style: ZapTypography.bodySmall
                                                .copyWith(
                                              color: ZapColors.danger,
                                              height: 1.4,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: ZapSpacing.sm),
                                  // Retry button
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: widget.onRetry,
                                      icon: const Icon(
                                          Icons.refresh_rounded, size: 16),
                                      label: const Text('Retry delivery'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: ZapColors.warning,
                                        side: const BorderSide(
                                            color: ZapColors.warning),
                                        padding:
                                            const EdgeInsets.symmetric(
                                                vertical: ZapSpacing.sm),
                                        textStyle:
                                            ZapTypography.labelMedium,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
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
        ),
      ),
    );
  }
}

// ─── Status badge ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final NotifStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: ZapSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: status.color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label.toUpperCase(),
        style: ZapTypography.labelSmall.copyWith(
          color: status.color,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          fontSize: 10,
        ),
      ),
    );
  }
}

// ─── Delivery timeline ────────────────────────────────────────────────────────

class _DeliveryTimeline extends StatelessWidget {
  const _DeliveryTimeline({required this.entry});

  final NotifEntry entry;

  @override
  Widget build(BuildContext context) {
    final isFailed   = entry.status == NotifStatus.failed;
    final hasDelivery = entry.deliveredAt != null;
    final hasAck     = entry.ackedAt != null;

    final Color midColor = isFailed
        ? ZapColors.danger
        : (hasDelivery ? ZapColors.safe : ZapColors.border);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TimelineStep(
          icon: Icons.send_rounded,
          label: 'Sent',
          timestamp: _fmtFull(entry.sentAt),
          color: ZapColors.info,
          isComplete: true,
        ),
        _TimelineLine(color: midColor),
        _TimelineStep(
          icon: isFailed
              ? Icons.cancel_rounded
              : Icons.check_circle_rounded,
          label: isFailed ? 'Failed' : 'Delivered',
          timestamp: isFailed
              ? 'Delivery failed'
              : (hasDelivery
                  ? _fmtFull(entry.deliveredAt)
                  : 'Awaiting delivery…'),
          color: midColor,
          isComplete: isFailed || hasDelivery,
        ),
        if (!isFailed) ...[
          _TimelineLine(color: hasAck ? ZapColors.safe : ZapColors.border),
          _TimelineStep(
            icon: Icons.notifications_active_rounded,
            label: 'Opened',
            timestamp: hasAck ? _fmtFull(entry.ackedAt) : 'Not yet opened',
            color: hasAck ? ZapColors.safe : ZapColors.textMuted,
            isComplete: hasAck,
          ),
        ],
      ],
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.icon,
    required this.label,
    required this.timestamp,
    required this.color,
    required this.isComplete,
  });

  final IconData icon;
  final String   label;
  final String   timestamp;
  final Color    color;
  final bool     isComplete;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isComplete
                ? color.withOpacity(0.15)
                : ZapColors.bgSurface,
            shape: BoxShape.circle,
            border: Border.all(
              color: isComplete ? color : ZapColors.border,
              width: isComplete ? 2 : 1,
            ),
          ),
          child: Icon(icon,
              size: 13,
              color: isComplete ? color : ZapColors.textMuted),
        ),
        const SizedBox(width: ZapSpacing.sm),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: ZapTypography.labelMedium.copyWith(
                  color: isComplete
                      ? ZapColors.textPrimary
                      : ZapColors.textMuted,
                  fontWeight: isComplete
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
              Flexible(
                child: Text(
                  timestamp,
                  textAlign: TextAlign.right,
                  style: ZapTypography.labelSmall.copyWith(
                      color: isComplete ? color : ZapColors.textMuted),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimelineLine extends StatelessWidget {
  const _TimelineLine({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 13),
      child: Container(width: 2, height: 16, color: color),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: ZapColors.bgCard,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              size: 36,
              color: ZapColors.textMuted,
            ),
          ),
          const SizedBox(height: ZapSpacing.lg),
          Text(
            'No notifications',
            style: ZapTypography.headlineSmall.copyWith(
                color: ZapColors.textSecondary),
          ),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            'Notifications will appear here\nonce they are sent.',
            textAlign: TextAlign.center,
            style: ZapTypography.bodyMedium.copyWith(
                color: ZapColors.textMuted, height: 1.5),
          ),
        ],
      ),
    );
  }
}
