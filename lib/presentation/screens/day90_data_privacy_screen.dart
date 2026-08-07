/// Day 90 — Data Export + Privacy Consent v2 screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../domain/providers/data_privacy_providers_v2.dart';

// ─── Root screen ──────────────────────────────────────────────────────────────

class Day90DataPrivacyScreen extends ConsumerStatefulWidget {
  const Day90DataPrivacyScreen({super.key});

  @override
  ConsumerState<Day90DataPrivacyScreen> createState() =>
      _Day90DataPrivacyScreenState();
}

class _Day90DataPrivacyScreenState
    extends ConsumerState<Day90DataPrivacyScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: ZapColors.bgPrimary,
        surfaceTintColor: Colors.transparent,
        title: const Text('Data & Privacy',
            style: ZapTypography.headlineSmall),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: ZapColors.info,
          labelColor: ZapColors.textPrimary,
          unselectedLabelColor: ZapColors.textSecondary,
          dividerColor: ZapColors.divider,
          tabs: const [
            Tab(text: 'Data Export'),
            Tab(text: 'Privacy'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _ExportTab(),
          _PrivacyTab(),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 1 — DATA EXPORT
// ══════════════════════════════════════════════════════════════════════════════

class _ExportTab extends ConsumerWidget {
  const _ExportTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(exportV2Provider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        // ── Section selector ─────────────────────────────────────
        _SectionCard(state: state),
        const SizedBox(height: ZapSpacing.lg),

        // ── Format picker ────────────────────────────────────────
        _FormatCard(state: state),
        const SizedBox(height: ZapSpacing.lg),

        // ── Create button ────────────────────────────────────────
        _CreateButton(state: state),
        const SizedBox(height: ZapSpacing.xxl),

        // ── Past exports ─────────────────────────────────────────
        if (state.requests.isNotEmpty) ...[
          Text('Export History',
              style: ZapTypography.labelMedium
                  .copyWith(color: ZapColors.textSecondary)),
          const SizedBox(height: ZapSpacing.md),
          ...state.requests.map((r) => _ExportRequestCard(request: r)),
        ],
      ],
    );
  }
}

// ── Section selector card ─────────────────────────────────────────────────────

class _SectionCard extends ConsumerWidget {
  const _SectionCard({required this.state});
  final ExportStateV2 state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(exportV2Provider.notifier);
    final allSelected =
        state.selectedSections.length == kExportSections.length;

    return Container(
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // header
          Padding(
            padding: const EdgeInsets.fromLTRB(
                ZapSpacing.lg, ZapSpacing.lg, ZapSpacing.md, ZapSpacing.sm),
            child: Row(
              children: [
                const Icon(Icons.check_box_rounded,
                    size: 18, color: ZapColors.info),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text('Select Data Sections',
                      style: ZapTypography.labelLarge
                          .copyWith(color: ZapColors.textPrimary)),
                ),
                TextButton(
                  onPressed: allSelected ? null : notifier.selectAll,
                  child: Text(
                    allSelected ? 'All selected' : 'Select all',
                    style: ZapTypography.labelSmall.copyWith(
                      color: allSelected
                          ? ZapColors.textMuted
                          : ZapColors.info,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: ZapColors.divider, height: 1),

          // section rows
          ...kExportSections.map((s) {
            final checked = state.selectedSections.contains(s.id);
            return _SectionRow(
              meta: s,
              checked: checked,
              onTap: () => notifier.toggleSection(s.id),
            );
          }),

          // total
          if (state.selectedSections.isNotEmpty) ...[
            const Divider(color: ZapColors.divider, height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: ZapSpacing.lg, vertical: ZapSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${state.selectedSections.length} section'
                    '${state.selectedSections.length == 1 ? '' : 's'} selected',
                    style: ZapTypography.bodySmall
                        .copyWith(color: ZapColors.textSecondary),
                  ),
                  Text(
                    '${state.totalSelectedItems} items',
                    style: ZapTypography.labelSmall
                        .copyWith(color: ZapColors.info),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({
    required this.meta,
    required this.checked,
    required this.onTap,
  });
  final ExportSectionMeta meta;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: ZapSpacing.lg, vertical: ZapSpacing.md),
        child: Row(
          children: [
            Icon(meta.icon, size: 18, color: meta.color),
            const SizedBox(width: ZapSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(meta.label,
                      style: ZapTypography.bodyMedium
                          .copyWith(color: ZapColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(meta.description,
                      style: ZapTypography.bodySmall
                          .copyWith(color: ZapColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: ZapSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: ZapSpacing.xs, vertical: 2),
              decoration: BoxDecoration(
                color: ZapColors.bgSurface,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('${meta.itemCount}',
                  style: ZapTypography.labelSmall
                      .copyWith(color: ZapColors.textSecondary)),
            ),
            const SizedBox(width: ZapSpacing.md),
            Checkbox(
              value: checked,
              onChanged: (_) => onTap(),
              activeColor: ZapColors.info,
              checkColor: ZapColors.bgPrimary,
              side: const BorderSide(color: ZapColors.border),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Format picker card ────────────────────────────────────────────────────────

class _FormatCard extends ConsumerWidget {
  const _FormatCard({required this.state});
  final ExportStateV2 state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(exportV2Provider.notifier);

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
              const Icon(Icons.folder_rounded,
                  size: 18, color: ZapColors.textSecondary),
              const SizedBox(width: ZapSpacing.sm),
              Text('Export Format',
                  style: ZapTypography.labelLarge
                      .copyWith(color: ZapColors.textPrimary)),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          Row(
            children: ExportFormat.values.map((f) {
              final selected = state.format == f;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                      right: f == ExportFormat.json ? ZapSpacing.sm : 0),
                  child: _FormatChip(
                    format: f,
                    selected: selected,
                    onTap: () => notifier.setFormat(f),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _FormatChip extends StatelessWidget {
  const _FormatChip({
    required this.format,
    required this.selected,
    required this.onTap,
  });
  final ExportFormat format;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
          color: selected ? ZapColors.info.withAlpha(26) : ZapColors.bgSurface,
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(
            color: selected ? ZapColors.info : ZapColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(format.icon,
                size: 20,
                color: selected ? ZapColors.info : ZapColors.textSecondary),
            const SizedBox(width: ZapSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(format.label,
                      style: ZapTypography.labelMedium.copyWith(
                        color: selected
                            ? ZapColors.info
                            : ZapColors.textPrimary,
                      )),
                  Text(format.description,
                      style: ZapTypography.bodySmall
                          .copyWith(color: ZapColors.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Create button ─────────────────────────────────────────────────────────────

class _CreateButton extends ConsumerWidget {
  const _CreateButton({required this.state});
  final ExportStateV2 state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(exportV2Provider.notifier);
    final disabled = state.isCreating || state.selectedSections.isEmpty;

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: disabled ? null : notifier.createExport,
        style: FilledButton.styleFrom(
          backgroundColor: ZapColors.info,
          disabledBackgroundColor: ZapColors.bgElevated,
          padding: const EdgeInsets.symmetric(vertical: ZapSpacing.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
          ),
        ),
        icon: state.isCreating
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.download_rounded, size: 20),
        label: Text(
          state.isCreating
              ? 'Creating export…'
              : state.selectedSections.isEmpty
                  ? 'Select at least one section'
                  : 'Create Export  ·  ${state.totalSelectedItems} items',
          style: ZapTypography.labelLarge.copyWith(
            color: disabled ? ZapColors.textMuted : Colors.white,
          ),
        ),
      ),
    );
  }
}

// ── Export request card ───────────────────────────────────────────────────────

String _fmtDate(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  $h:$m';
}

String _fmtRelative(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 60) {
    return '${diff.inMinutes}m ago';
  }
  if (diff.inHours < 24) {
    return '${diff.inHours}h ago';
  }
  return '${diff.inDays}d ago';
}

String _fmtExpiry(DateTime? dt) {
  if (dt == null) {
    return '—';
  }
  final diff = dt.difference(DateTime.now());
  if (diff.isNegative) {
    return 'Expired';
  }
  if (diff.inDays > 0) {
    return 'Expires in ${diff.inDays}d';
  }
  return 'Expires in ${diff.inHours}h';
}

class _ExportRequestCard extends StatelessWidget {
  const _ExportRequestCard({required this.request});
  final ExportRequestV2 request;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final statusColor = r.status.color;

    return Padding(
      padding: const EdgeInsets.only(bottom: ZapSpacing.md),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // left accent
              Container(width: 4, color: statusColor),

              // card body
              Expanded(
                child: Container(
                  color: ZapColors.bgCard,
                  padding: const EdgeInsets.all(ZapSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // top row: format icon + label + status badge
                      Row(
                        children: [
                          Icon(r.format.icon,
                              size: 16,
                              color: ZapColors.textSecondary),
                          const SizedBox(width: ZapSpacing.xs),
                          Text(r.format.label,
                              style: ZapTypography.labelMedium
                                  .copyWith(color: ZapColors.textPrimary)),
                          const Spacer(),
                          _StatusBadge(status: r.status),
                        ],
                      ),
                      const SizedBox(height: ZapSpacing.sm),

                      // meta row
                      Text(
                        '${r.totalItems} items  ·  ${_fmtRelative(r.requestedAt)}  ·  ${_fmtDate(r.requestedAt)}',
                        style: ZapTypography.bodySmall
                            .copyWith(color: ZapColors.textSecondary),
                      ),

                      // sections chips
                      if (r.selectedSections.isNotEmpty) ...[
                        const SizedBox(height: ZapSpacing.sm),
                        Wrap(
                          spacing: ZapSpacing.xs,
                          runSpacing: ZapSpacing.xs,
                          children: r.selectedSections.map((sid) {
                            final meta = kExportSections
                                .where((s) => s.id == sid)
                                .firstOrNull;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: ZapSpacing.sm, vertical: 2),
                              decoration: BoxDecoration(
                                color: ZapColors.bgSurface,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                meta?.label ?? sid,
                                style: ZapTypography.labelSmall
                                    .copyWith(color: ZapColors.textSecondary),
                              ),
                            );
                          }).toList(),
                        ),
                      ],

                      // expiry + view button
                      if (r.expiresAt != null ||
                          r.status == ExportStatusV2.ready) ...[
                        const SizedBox(height: ZapSpacing.md),
                        Row(
                          children: [
                            Icon(
                              r.isExpired
                                  ? Icons.timer_off_rounded
                                  : Icons.timer_rounded,
                              size: 14,
                              color: r.isExpired
                                  ? ZapColors.textMuted
                                  : ZapColors.textSecondary,
                            ),
                            const SizedBox(width: ZapSpacing.xs),
                            Text(
                              _fmtExpiry(r.expiresAt),
                              style: ZapTypography.bodySmall.copyWith(
                                color: r.isExpired
                                    ? ZapColors.textMuted
                                    : ZapColors.textSecondary,
                              ),
                            ),
                            const Spacer(),
                            if (r.isViewable)
                              TextButton.icon(
                                onPressed: () => _showViewSheet(context, r),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: ZapSpacing.sm,
                                      vertical: ZapSpacing.xs),
                                  visualDensity: VisualDensity.compact,
                                ),
                                icon: const Icon(Icons.open_in_new_rounded,
                                    size: 14, color: ZapColors.info),
                                label: Text('View',
                                    style: ZapTypography.labelSmall
                                        .copyWith(color: ZapColors.info)),
                              ),
                          ],
                        ),
                      ],

                      // processing indicator
                      if (r.status == ExportStatusV2.processing) ...[
                        const SizedBox(height: ZapSpacing.sm),
                        const LinearProgressIndicator(
                          backgroundColor: ZapColors.bgSurface,
                          color: ZapColors.info,
                        ),
                        const SizedBox(height: ZapSpacing.xs),
                        Text('Preparing your export…',
                            style: ZapTypography.bodySmall
                                .copyWith(color: ZapColors.textSecondary)),
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

  void _showViewSheet(BuildContext context, ExportRequestV2 r) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ZapColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(ZapSpacing.radiusSmall)),
      ),
      builder: (_) => _ViewExportSheet(request: r),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final ExportStatusV2 status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: ZapSpacing.sm, vertical: 3),
      decoration: BoxDecoration(
        color: status.color.withAlpha(26),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: status.color.withAlpha(77)),
      ),
      child: Text(
        status.label,
        style: ZapTypography.labelSmall.copyWith(color: status.color),
      ),
    );
  }
}

// ── View export bottom sheet ──────────────────────────────────────────────────

class _ViewExportSheet extends StatefulWidget {
  const _ViewExportSheet({required this.request});
  final ExportRequestV2 request;

  @override
  State<_ViewExportSheet> createState() => _ViewExportSheetState();
}

class _ViewExportSheetState extends State<_ViewExportSheet> {
  bool _downloading = false;

  Future<void> _download() async {
    setState(() => _downloading = true);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
            'Export downloaded — ${widget.request.format.label} file saved'),
        backgroundColor: ZapColors.safe,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(ZapSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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

            Row(
              children: [
                Icon(r.format.icon, size: 24, color: ZapColors.info),
                const SizedBox(width: ZapSpacing.md),
                Expanded(
                  child: Text(
                    'Export  ·  ${r.format.label}',
                    style: ZapTypography.headlineSmall,
                  ),
                ),
                _StatusBadge(status: r.status),
              ],
            ),
            const SizedBox(height: ZapSpacing.lg),

            _InfoRow(label: 'Created',
                value: _fmtDate(r.requestedAt)),
            _InfoRow(label: 'Expires',
                value: _fmtExpiry(r.expiresAt)),
            _InfoRow(label: 'Items',
                value: '${r.totalItems}'),
            _InfoRow(label: 'Sections',
                value: '${r.selectedSections.length}'),
            const SizedBox(height: ZapSpacing.xl),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _downloading ? null : _download,
                style: FilledButton.styleFrom(
                  backgroundColor: ZapColors.info,
                  padding:
                      const EdgeInsets.symmetric(vertical: ZapSpacing.lg),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(ZapSpacing.radius),
                  ),
                ),
                icon: _downloading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.download_rounded, size: 20),
                label: Text(
                  _downloading ? 'Downloading…' : 'Download Export',
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: ZapTypography.bodySmall
                  .copyWith(color: ZapColors.textSecondary)),
          Text(value,
              style: ZapTypography.bodyMedium
                  .copyWith(color: ZapColors.textPrimary)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — PRIVACY & CONSENT
// ══════════════════════════════════════════════════════════════════════════════

class _PrivacyTab extends ConsumerWidget {
  const _PrivacyTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(privacyV2Provider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        // ── Consent flags ────────────────────────────────────────
        Text('Consent Settings',
            style: ZapTypography.labelMedium
                .copyWith(color: ZapColors.textSecondary)),
        const SizedBox(height: ZapSpacing.md),
        ...state.flags.map((f) => _ConsentTile(flag: f)),

        const SizedBox(height: ZapSpacing.xxl),

        // ── GDPR deletion ────────────────────────────────────────
        Text('Account Deletion',
            style: ZapTypography.labelMedium
                .copyWith(color: ZapColors.textSecondary)),
        const SizedBox(height: ZapSpacing.md),
        _DeletionCard(state: state),
      ],
    );
  }
}

// ── Consent toggle tile ───────────────────────────────────────────────────────

class _ConsentTile extends ConsumerWidget {
  const _ConsentTile({required this.flag});
  final ConsentFlagV2 flag;

  String _fmtLastChanged(DateTime? dt) {
    if (dt == null) {
      return 'Never changed';
    }
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) {
      return 'Changed today';
    }
    if (diff.inDays == 1) {
      return 'Changed yesterday';
    }
    return 'Changed ${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(privacyV2Provider.notifier);

    return Padding(
      padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
      child: Container(
        decoration: BoxDecoration(
          color: ZapColors.bgCard,
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          border: Border.all(color: ZapColors.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          onTap: () => notifier.toggleFlag(flag.id),
          child: Padding(
            padding: const EdgeInsets.all(ZapSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(flag.label,
                          style: ZapTypography.labelLarge
                              .copyWith(color: ZapColors.textPrimary)),
                      const SizedBox(height: ZapSpacing.xs),
                      Text(flag.description,
                          style: ZapTypography.bodySmall
                              .copyWith(color: ZapColors.textSecondary)),
                      const SizedBox(height: ZapSpacing.sm),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: ZapSpacing.sm, vertical: 2),
                            decoration: BoxDecoration(
                              color: ZapColors.bgSurface,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(flag.legalBasis,
                                style: ZapTypography.labelSmall.copyWith(
                                    color: ZapColors.textMuted)),
                          ),
                          const SizedBox(width: ZapSpacing.sm),
                          Text(
                            _fmtLastChanged(flag.lastChanged),
                            style: ZapTypography.bodySmall
                                .copyWith(color: ZapColors.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: ZapSpacing.md),
                Switch(
                  value: flag.enabled,
                  onChanged: (_) => notifier.toggleFlag(flag.id),
                  activeColor: ZapColors.safe,
                  inactiveThumbColor: ZapColors.textMuted,
                  inactiveTrackColor: ZapColors.bgSurface,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── GDPR deletion card ────────────────────────────────────────────────────────

class _DeletionCard extends ConsumerWidget {
  const _DeletionCard({required this.state});
  final PrivacyStateV2 state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.deletionRequest != null) {
      return _PendingDeletionCard(state: state);
    }
    return _RequestDeletionCard(state: state);
  }
}

class _RequestDeletionCard extends ConsumerWidget {
  const _RequestDeletionCard({required this.state});
  final PrivacyStateV2 state;

  void _showDeletionDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ZapColors.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(ZapSpacing.radiusSmall)),
      ),
      builder: (_) => _DeletionConfirmSheet(
        onConfirm: (reason) =>
            ref.read(privacyV2Provider.notifier).submitDeletion(reason),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.danger.withAlpha(77)),
      ),
      padding: const EdgeInsets.all(ZapSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.delete_forever_rounded,
                  size: 20, color: ZapColors.danger),
              const SizedBox(width: ZapSpacing.sm),
              Text('Request Account Deletion',
                  style: ZapTypography.labelLarge
                      .copyWith(color: ZapColors.danger)),
            ],
          ),
          const SizedBox(height: ZapSpacing.sm),
          Text(
            'Permanently delete your ZapSafe account and all associated data. '
            'This action cannot be undone. Under GDPR Article 17 you have the '
            'right to erasure.',
            style: ZapTypography.bodySmall
                .copyWith(color: ZapColors.textSecondary),
          ),
          const SizedBox(height: ZapSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: state.isSubmittingDeletion
                  ? null
                  : () => _showDeletionDialog(context, ref),
              style: OutlinedButton.styleFrom(
                foregroundColor: ZapColors.danger,
                side: const BorderSide(color: ZapColors.danger),
                padding:
                    const EdgeInsets.symmetric(vertical: ZapSpacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ZapSpacing.radius),
                ),
              ),
              child: state.isSubmittingDeletion
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: ZapColors.danger,
                      ),
                    )
                  : Text('Request Deletion',
                      style: ZapTypography.labelLarge
                          .copyWith(color: ZapColors.danger)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingDeletionCard extends ConsumerWidget {
  const _PendingDeletionCard({required this.state});
  final PrivacyStateV2 state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final req = state.deletionRequest!;
    final notifier = ref.read(privacyV2Provider.notifier);

    return ClipRRect(
      borderRadius: BorderRadius.circular(ZapSpacing.radius),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: ZapColors.warning),
            Expanded(
              child: Container(
                color: ZapColors.bgCard,
                padding: const EdgeInsets.all(ZapSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.hourglass_top_rounded,
                            size: 18, color: ZapColors.warning),
                        const SizedBox(width: ZapSpacing.sm),
                        Text('Deletion Requested',
                            style: ZapTypography.labelLarge
                                .copyWith(color: ZapColors.warning)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: ZapSpacing.sm, vertical: 3),
                          decoration: BoxDecoration(
                            color: ZapColors.warning.withAlpha(26),
                            borderRadius:
                                BorderRadius.circular(ZapSpacing.radiusSmall),
                            border: Border.all(
                                color: ZapColors.warning.withAlpha(77)),
                          ),
                          child: Text(req.status.toUpperCase(),
                              style: ZapTypography.labelSmall
                                  .copyWith(color: ZapColors.warning)),
                        ),
                      ],
                    ),
                    const SizedBox(height: ZapSpacing.sm),
                    Text(
                      'Your deletion request was submitted on '
                      '${_fmtDate(req.requestedAt)}. '
                      'Processing typically takes up to 30 days.',
                      style: ZapTypography.bodySmall
                          .copyWith(color: ZapColors.textSecondary),
                    ),
                    if (req.reason != null) ...[
                      const SizedBox(height: ZapSpacing.sm),
                      Text('Reason: ${req.reason}',
                          style: ZapTypography.bodySmall
                              .copyWith(color: ZapColors.textMuted)),
                    ],
                    if (req.isCancellable) ...[
                      const SizedBox(height: ZapSpacing.lg),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: state.isCancellingDeletion
                              ? null
                              : notifier.cancelDeletion,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: ZapColors.textSecondary,
                            side:
                                const BorderSide(color: ZapColors.border),
                            padding: const EdgeInsets.symmetric(
                                vertical: ZapSpacing.md),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(ZapSpacing.radius),
                            ),
                          ),
                          child: state.isCancellingDeletion
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: ZapColors.textSecondary,
                                  ),
                                )
                              : Text('Cancel Deletion Request',
                                  style: ZapTypography.labelLarge
                                      .copyWith(
                                          color:
                                              ZapColors.textSecondary)),
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

// ── Deletion confirm bottom sheet ─────────────────────────────────────────────

class _DeletionConfirmSheet extends StatefulWidget {
  const _DeletionConfirmSheet({required this.onConfirm});
  final Future<void> Function(String? reason) onConfirm;

  @override
  State<_DeletionConfirmSheet> createState() => _DeletionConfirmSheetState();
}

class _DeletionConfirmSheetState extends State<_DeletionConfirmSheet> {
  final _ctrl = TextEditingController();
  bool _confirming = false;
  bool _typedConfirm = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _confirming = true);
    final reason = _ctrl.text.trim().isNotEmpty ? _ctrl.text.trim() : null;
    await widget.onConfirm(reason);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          ZapSpacing.xxl, ZapSpacing.xxl, ZapSpacing.xxl,
          ZapSpacing.xxl + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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

          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 22, color: ZapColors.danger),
              const SizedBox(width: ZapSpacing.sm),
              Text('Confirm Account Deletion',
                  style: ZapTypography.headlineSmall
                      .copyWith(color: ZapColors.danger)),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          Text(
            'This will permanently delete all your data. '
            'Type DELETE to confirm.',
            style: ZapTypography.bodyMedium
                .copyWith(color: ZapColors.textSecondary),
          ),
          const SizedBox(height: ZapSpacing.xl),

          // optional reason
          TextField(
            controller: _ctrl,
            style: ZapTypography.bodyMedium
                .copyWith(color: ZapColors.textPrimary),
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Reason for deletion (optional)',
              hintStyle: ZapTypography.bodyMedium
                  .copyWith(color: ZapColors.textMuted),
              filled: true,
              fillColor: ZapColors.bgSurface,
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
                borderSide: const BorderSide(color: ZapColors.danger),
              ),
            ),
          ),
          const SizedBox(height: ZapSpacing.md),

          // confirm word field
          TextField(
            onChanged: (v) {
              setState(() {
                _typedConfirm = v.trim().toUpperCase() == 'DELETE';
              });
            },
            style: ZapTypography.bodyMedium
                .copyWith(color: ZapColors.danger),
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'Type DELETE to confirm',
              hintStyle: ZapTypography.bodyMedium
                  .copyWith(color: ZapColors.textMuted),
              filled: true,
              fillColor: ZapColors.bgSurface,
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
                borderSide: const BorderSide(color: ZapColors.danger),
              ),
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _confirming
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
                          .copyWith(color: ZapColors.textSecondary)),
                ),
              ),
              const SizedBox(width: ZapSpacing.md),
              Expanded(
                child: FilledButton(
                  onPressed:
                      (_typedConfirm && !_confirming) ? _submit : null,
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
                  child: _confirming
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text('Delete Account',
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
