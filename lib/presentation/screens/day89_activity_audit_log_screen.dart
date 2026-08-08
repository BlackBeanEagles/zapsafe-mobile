/// Day 89 — Activity Audit Log Screen (v2).
///
/// Self-contained, fully mock audit trail:
/// Stats bar · live text search · category filter chips ·
/// date-grouped timeline · expandable detail panel · CSV/JSON export.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../domain/providers/audit_log_providers_v2.dart';

// ─── Helpers ─────────────────────────────────────────────────────────────────

List<Object> _buildGrouped(List<AuditEntryV2> entries) {
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
    final d      = entry.timestamp;
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

String _fmtTime(DateTime dt) {
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

String _fmtKey(String key) {
  return key
      .split('_')
      .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class Day89ActivityAuditLogScreen extends ConsumerWidget {
  const Day89ActivityAuditLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats    = ref.watch(auditStatsV2Provider);
    final filtered = ref.watch(filteredAuditLogV2Provider);
    final catFil   = ref.watch(auditCategoryFilterV2Provider);
    final query    = ref.watch(auditSearchV2Provider);

    final grouped = _buildGrouped(filtered);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: ZapColors.bgPrimary,
        elevation: 0,
        iconTheme: const IconThemeData(color: ZapColors.textPrimary),
        title: Text(
          'Activity Audit Log',
          style: ZapTypography.headlineSmall.copyWith(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export log',
            color: ZapColors.textSecondary,
            onPressed: () => _showExportSheet(context, stats.total),
          ),
        ],
      ),
      body: Column(
        children: [
          _StatsBar(stats: stats),
          const _SearchField(),
          const _CategoryFilterRow(),
          const Divider(height: 1, thickness: 1, color: ZapColors.divider),
          Expanded(
            child: grouped.isEmpty
                ? _EmptyState(
                    hasFilters: catFil != null || query.isNotEmpty)
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
                      final entry = item as AuditEntryV2;
                      return _AuditTile(
                        key: ValueKey(entry.id),
                        entry: entry,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showExportSheet(BuildContext context, int count) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ZapColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(ZapSpacing.radius)),
      ),
      builder: (_) => _ExportSheet(totalEvents: count),
    );
  }
}

// ─── Stats bar ────────────────────────────────────────────────────────────────

class _StatsBar extends StatelessWidget {
  const _StatsBar({required this.stats});

  final AuditStatsV2 stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ZapColors.bgCard,
      padding: const EdgeInsets.symmetric(
          horizontal: ZapSpacing.lg, vertical: ZapSpacing.md),
      child: Row(
        children: [
          _StatCell(value: stats.total,     label: 'Total',     color: ZapColors.textSecondary),
          const _VertDivider(),
          _StatCell(value: stats.today,     label: 'Today',     color: ZapColors.info),
          const _VertDivider(),
          _StatCell(value: stats.sosEvents, label: 'SOS',       color: ZapColors.danger),
          const _VertDivider(),
          _StatCell(value: stats.critical,  label: 'Critical',  color: ZapColors.danger),
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

// ─── Search field ─────────────────────────────────────────────────────────────

class _SearchField extends ConsumerStatefulWidget {
  const _SearchField();

  @override
  ConsumerState<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends ConsumerState<_SearchField> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: ref.read(auditSearchV2Provider));
    _ctrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ZapColors.bgCard,
      padding: const EdgeInsets.fromLTRB(
          ZapSpacing.lg, 0, ZapSpacing.lg, ZapSpacing.sm),
      child: TextField(
        controller: _ctrl,
        onChanged: (v) =>
            ref.read(auditSearchV2Provider.notifier).state = v,
        style: ZapTypography.bodyMedium.copyWith(
            color: ZapColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search events…',
          hintStyle: ZapTypography.bodyMedium.copyWith(
              color: ZapColors.textMuted),
          prefixIcon: const Icon(Icons.search_rounded,
              color: ZapColors.textMuted, size: 20),
          suffixIcon: _ctrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded,
                      color: ZapColors.textMuted, size: 18),
                  onPressed: () {
                    _ctrl.clear();
                    ref.read(auditSearchV2Provider.notifier).state = '';
                  },
                )
              : null,
          filled: true,
          fillColor: ZapColors.bgSurface,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: ZapSpacing.md, vertical: ZapSpacing.sm),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            borderSide: const BorderSide(color: ZapColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            borderSide: const BorderSide(color: ZapColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            borderSide: const BorderSide(color: ZapColors.info, width: 1.5),
          ),
        ),
      ),
    );
  }
}

// ─── Category filter row ─────────────────────────────────────────────────────

class _CategoryFilterRow extends ConsumerWidget {
  const _CategoryFilterRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catFil = ref.watch(auditCategoryFilterV2Provider);

    return Container(
      color: ZapColors.bgCard,
      height: 44,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
            horizontal: ZapSpacing.lg, vertical: 6),
        child: Row(
          children: [
            _CatChip(
              label: 'All',
              icon: Icons.list_rounded,
              color: ZapColors.textSecondary,
              selected: catFil == null,
              onTap: () =>
                  ref.read(auditCategoryFilterV2Provider.notifier).state =
                      null,
            ),
            for (final cat in AuditCategory.values) ...[
              const SizedBox(width: ZapSpacing.xs),
              _CatChip(
                label: cat.label,
                icon: cat.icon,
                color: cat.color,
                selected: catFil == cat,
                onTap: () =>
                    ref.read(auditCategoryFilterV2Provider.notifier).state =
                        cat,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CatChip extends StatelessWidget {
  const _CatChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String       label;
  final IconData     icon;
  final Color        color;
  final bool         selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
            horizontal: ZapSpacing.sm, vertical: ZapSpacing.xs),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : ZapColors.bgSurface,
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(
            color: selected ? color : ZapColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 12, color: selected ? color : ZapColors.textMuted),
            const SizedBox(width: ZapSpacing.xs),
            Text(
              label,
              style: ZapTypography.labelSmall.copyWith(
                color: selected ? color : ZapColors.textSecondary,
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

// ─── Audit tile ───────────────────────────────────────────────────────────────

class _AuditTile extends StatefulWidget {
  const _AuditTile({super.key, required this.entry});

  final AuditEntryV2 entry;

  @override
  State<_AuditTile> createState() => _AuditTileState();
}

class _AuditTileState extends State<_AuditTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final e           = widget.entry;
    final accentColor = e.severity.color;
    final catColor    = e.category.color;

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
                // Severity accent bar
                Container(width: 4, color: accentColor),
                // Content
                Expanded(
                  child: Container(
                    color: ZapColors.bgCard,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Header row ─────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                              ZapSpacing.md, ZapSpacing.md,
                              ZapSpacing.md, 0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Category icon
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: catColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(
                                      ZapSpacing.radiusSmall),
                                ),
                                child: Icon(e.category.icon,
                                    color: catColor, size: 16),
                              ),
                              const SizedBox(width: ZapSpacing.sm),
                              // Title + description
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      e.title,
                                      style: ZapTypography.bodyMedium.copyWith(
                                        color: ZapColors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (e.description != null)
                                      Text(
                                        e.description!,
                                        maxLines: _expanded ? null : 1,
                                        overflow: _expanded
                                            ? TextOverflow.visible
                                            : TextOverflow.ellipsis,
                                        style: ZapTypography.bodySmall
                                            .copyWith(
                                                color:
                                                    ZapColors.textSecondary),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: ZapSpacing.xs),
                              // Time + severity dot
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _fmtTime(e.timestamp),
                                    style: ZapTypography.labelSmall.copyWith(
                                        color: ZapColors.textMuted),
                                  ),
                                  const SizedBox(height: ZapSpacing.xs),
                                  if (e.severity != AuditSeverity.info)
                                    Icon(
                                      e.severity.dotIcon,
                                      size: 14,
                                      color: accentColor,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // ── Metadata row ───────────────────────────────
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                              ZapSpacing.md, ZapSpacing.xs,
                              ZapSpacing.md, 0),
                          child: Row(
                            children: [
                              // Category badge
                              _Badge(
                                  label: e.category.label, color: catColor),
                              if (e.resourceLabel != null) ...[
                                const SizedBox(width: ZapSpacing.xs),
                                Flexible(
                                  child: _ResourceChip(
                                      label: e.resourceLabel!),
                                ),
                              ],
                              const Spacer(),
                              if (e.ipAddress != null)
                                Row(
                                  children: [
                                    const Icon(Icons.router_rounded,
                                        size: 11,
                                        color: ZapColors.textMuted),
                                    const SizedBox(width: 3),
                                    Text(
                                      e.ipAddress!,
                                      style: ZapTypography.labelSmall
                                          .copyWith(
                                              color: ZapColors.textMuted),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        // ── Expand toggle ──────────────────────────────
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
                                _expanded ? 'Hide details' : 'Details',
                                style: ZapTypography.labelSmall.copyWith(
                                    color: ZapColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                        // ── Expanded detail panel ──────────────────────
                        if (_expanded && e.details.isNotEmpty) ...[
                          const Divider(
                              height: 1, thickness: 1,
                              color: ZapColors.divider),
                          Padding(
                            padding: const EdgeInsets.all(ZapSpacing.md),
                            child: Column(
                              children: [
                                for (final kv in e.details.entries)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        bottom: ZapSpacing.xs),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          width: 110,
                                          child: Text(
                                            _fmtKey(kv.key),
                                            style: ZapTypography.labelSmall
                                                .copyWith(
                                              color: ZapColors.textMuted,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            kv.value,
                                            style: ZapTypography.bodySmall
                                                .copyWith(
                                              color: ZapColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
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

// ─── Small widgets ────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: ZapSpacing.xs, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label.toUpperCase(),
        style: ZapTypography.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          fontSize: 9,
        ),
      ),
    );
  }
}

class _ResourceChip extends StatelessWidget {
  const _ResourceChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: ZapSpacing.xs, vertical: 2),
      decoration: BoxDecoration(
        color: ZapColors.bgSurface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: ZapColors.border),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: ZapTypography.labelSmall.copyWith(
          color: ZapColors.textSecondary,
          fontSize: 10,
        ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasFilters});

  final bool hasFilters;

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
              Icons.manage_search_rounded,
              size: 36,
              color: ZapColors.textMuted,
            ),
          ),
          const SizedBox(height: ZapSpacing.lg),
          Text(
            hasFilters ? 'No matching events' : 'No activity recorded',
            style: ZapTypography.headlineSmall.copyWith(
                color: ZapColors.textSecondary),
          ),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            hasFilters
                ? 'Try adjusting your search or category filter.'
                : 'Events will appear here as you use the app.',
            textAlign: TextAlign.center,
            style: ZapTypography.bodyMedium.copyWith(
                color: ZapColors.textMuted, height: 1.5),
          ),
        ],
      ),
    );
  }
}

// ─── Export bottom sheet ──────────────────────────────────────────────────────

class _ExportSheet extends StatefulWidget {
  const _ExportSheet({required this.totalEvents});

  final int totalEvents;

  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<_ExportSheet> {
  bool _exporting = false;

  Future<void> _export(String format) async {
    setState(() => _exporting = true);
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) { return; }
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Exported ${widget.totalEvents} events as $format — ready to share.',
        ),
        backgroundColor: ZapColors.safe,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        ZapSpacing.lg,
        ZapSpacing.md,
        ZapSpacing.lg,
        ZapSpacing.lg + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: ZapColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: ZapSpacing.lg),
          Text(
            'Export Audit Log',
            style: ZapTypography.headlineSmall.copyWith(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            '${widget.totalEvents} events · last 4 days',
            style: ZapTypography.bodySmall.copyWith(
                color: ZapColors.textSecondary),
          ),
          const SizedBox(height: ZapSpacing.lg),
          if (_exporting)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: ZapSpacing.xl),
              child: Column(
                children: [
                  CircularProgressIndicator(color: ZapColors.info),
                  SizedBox(height: ZapSpacing.md),
                  Text('Preparing export…',
                      style: TextStyle(color: ZapColors.textSecondary)),
                ],
              ),
            )
          else ...[
            _ExportOption(
              icon: Icons.table_chart_rounded,
              label: 'Export as CSV',
              description: 'Open in Excel, Google Sheets, or Numbers',
              color: ZapColors.safe,
              onTap: () => _export('CSV'),
            ),
            const SizedBox(height: ZapSpacing.sm),
            _ExportOption(
              icon: Icons.data_object_rounded,
              label: 'Export as JSON',
              description: 'Machine-readable · includes full detail maps',
              color: ZapColors.info,
              onTap: () => _export('JSON'),
            ),
            const SizedBox(height: ZapSpacing.md),
            Text(
              'Exports are encrypted and deleted after 7 days.',
              style: ZapTypography.labelSmall.copyWith(
                  color: ZapColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _ExportOption extends StatelessWidget {
  const _ExportOption({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.onTap,
  });

  final IconData     icon;
  final String       label;
  final String       description;
  final Color        color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
          color: ZapColors.bgSurface,
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: ZapColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(ZapSpacing.sm),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: ZapSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: ZapTypography.labelMedium.copyWith(
                      color: ZapColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    description,
                    style: ZapTypography.bodySmall.copyWith(
                        color: ZapColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: ZapColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}
