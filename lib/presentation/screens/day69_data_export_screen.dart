/// Day 69 — Data Export Screen
///
/// GDPR-style data export. Users can request a full JSON snapshot of all
/// their ZapSafe data — compiled synchronously on the server and ready to
/// view immediately.
///
/// • Info card listing the 7 exported sections
/// • "Request New Export" button
/// • List of past export requests with status badges
/// • READY exports show "View Data" — fetches /download/ and surfaces a
///   bottom sheet with section counts + profile overview
/// • Lazy expiry: expired exports show grey "Expired" badge
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/services/data_export_service.dart';
import '../../domain/providers/data_export_providers.dart';

// ─── Screen ───────────────────────────────────────────────────────────────────

class Day69DataExportScreen extends ConsumerStatefulWidget {
  const Day69DataExportScreen({super.key});

  @override
  ConsumerState<Day69DataExportScreen> createState() =>
      _Day69DataExportScreenState();
}

class _Day69DataExportScreenState
    extends ConsumerState<Day69DataExportScreen> {
  bool    _creating = false;
  String? _createError;

  Future<void> _requestExport() async {
    setState(() { _creating = true; _createError = null; });
    try {
      await ref.read(dataExportServiceProvider).create();
      if (!mounted) return;
      ref.invalidate(dataExportListProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() => _createError = 'Request failed — check your connection');
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _viewExport(String id) async {
    final payload =
        await ref.read(dataExportServiceProvider).download(id);
    if (!mounted) return;
    if (payload == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export not available yet — try again shortly')),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ZapColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _PayloadSheet(payload: payload),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(dataExportListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Export'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(dataExportListProvider),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          // ── What's included ────────────────────────────────────────────
          const _InfoCard(),
          const SizedBox(height: ZapSpacing.lg),

          // ── Request button ─────────────────────────────────────────────
          if (_createError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
              child: _ErrorBanner(message: _createError!),
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _creating ? null : _requestExport,
              icon: _creating
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.download_rounded),
              label: Text(_creating ? 'Compiling…' : 'Request New Export'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ZapColors.danger,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ),
          const SizedBox(height: ZapSpacing.lg),

          // ── Past exports ───────────────────────────────────────────────
          Text('Past Exports',
              style: ZapTypography.labelMedium
                  .copyWith(color: ZapColors.textSecondary)),
          const SizedBox(height: ZapSpacing.sm),

          listAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(ZapSpacing.xl),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => _ErrorBanner(message: e.toString()),
            data: (exports) {
              if (exports.isEmpty) {
                return const _EmptyState();
              }
              return Column(
                children: [
                  for (final e in exports) ...[
                    _ExportCard(
                      export: e,
                      onView: () => _viewExport(e.id),
                    ),
                    const SizedBox(height: ZapSpacing.sm),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Info Card ────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  const _InfoCard();

  static const _kSections = [
    (Icons.person_rounded,         'Profile',             'Settings, quiet hours, caps'),
    (Icons.tune_rounded,           'Notification Prefs',  '5 per-category toggle rows'),
    (Icons.message_rounded,        'SOS Templates',       'All pre-composed messages'),
    (Icons.timer_rounded,          'Check-ins',           'Last 90 days'),
    (Icons.location_on_rounded,    'Safe Zones',          'All defined GPS zones'),
    (Icons.article_rounded,        'Incidents',           'All incident reports'),
    (Icons.history_rounded,        'Activity Log',        'Last 90 days of events'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZapColors.bgElevated),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shield_rounded, size: 15, color: ZapColors.info),
              SizedBox(width: 6),
              Text('What gets exported',
                  style: ZapTypography.labelMedium),
            ],
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Divider(height: 1, color: ZapColors.bgElevated),
          const SizedBox(height: ZapSpacing.sm),
          for (final (icon, label, desc) in _kSections)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(icon, size: 13, color: ZapColors.info),
                  const SizedBox(width: 8),
                  Text('$label  ',
                      style: ZapTypography.bodySmall),
                  Expanded(
                    child: Text(desc,
                        style: ZapTypography.labelSmall
                            .copyWith(color: ZapColors.textSecondary)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: ZapSpacing.xs),
          const Text(
            'Your export is compiled instantly and available for 7 days.',
            style: ZapTypography.labelSmall,
          ),
        ],
      ),
    );
  }
}

// ─── Export Card ──────────────────────────────────────────────────────────────

class _ExportCard extends StatelessWidget {
  const _ExportCard({required this.export, required this.onView});
  final DataExportRequest export;
  final VoidCallback       onView;

  String _fmt(DateTime dt) {
    final d = dt;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}  '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  String? _expiryLabel(DateTime? expiresAt) {
    if (expiresAt == null) return null;
    final diff = expiresAt.difference(DateTime.now());
    if (diff.isNegative) return 'Expired';
    if (diff.inHours < 24) return 'Expires in ${diff.inHours}h';
    return 'Expires in ${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ZapColors.bgElevated),
      ),
      child: Row(
        children: [
          // Status icon
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.sm),
            child: _StatusIcon(status: export.status, isExpired: export.isExpired),
          ),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _StatusBadge(status: export.status, isExpired: export.isExpired),
                    const SizedBox(width: ZapSpacing.sm),
                    Text(_fmt(export.requestedAt),
                        style: ZapTypography.labelSmall
                            .copyWith(color: ZapColors.textSecondary)),
                  ],
                ),
                if (export.isReady && export.expiresAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    _expiryLabel(export.expiresAt) ?? '',
                    style: ZapTypography.labelSmall
                        .copyWith(color: ZapColors.warning),
                  ),
                ],
                if (export.isFailed && export.errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(export.errorMessage,
                      style: ZapTypography.labelSmall
                          .copyWith(color: ZapColors.danger)),
                ],
              ],
            ),
          ),
          // Action button
          if (export.isReady)
            TextButton.icon(
              onPressed: onView,
              icon: const Icon(Icons.open_in_new_rounded, size: 14),
              label: const Text('View'),
            ),
        ],
      ),
    );
  }
}

// ─── Status Icon ──────────────────────────────────────────────────────────────

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status, required this.isExpired});
  final String status;
  final bool   isExpired;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (status) {
      'ready'      when !isExpired => (Icons.check_circle_rounded, ZapColors.safe),
      'failed'                     => (Icons.error_rounded,         ZapColors.danger),
      'expired'                    => (Icons.history_toggle_off_rounded, ZapColors.textSecondary),
      'processing'                 => (Icons.hourglass_top_rounded,  ZapColors.info),
      _                            => (Icons.pending_rounded,         ZapColors.textSecondary),
    };
    if (isExpired && status != 'expired') {
      return const Icon(Icons.history_toggle_off_rounded,
          size: 20, color: ZapColors.textSecondary);
    }
    return Icon(icon, size: 20, color: color);
  }
}

// ─── Status Badge ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.isExpired});
  final String status;
  final bool   isExpired;

  @override
  Widget build(BuildContext context) {
    final (label, color) = (isExpired && status != 'expired')
        ? ('EXPIRED', ZapColors.textSecondary)
        : switch (status) {
            'ready'      => ('READY',      ZapColors.safe),
            'failed'     => ('FAILED',     ZapColors.danger),
            'expired'    => ('EXPIRED',    ZapColors.textSecondary),
            'processing' => ('PROCESSING', ZapColors.info),
            _            => ('PENDING',    ZapColors.textSecondary),
          };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.30)),
      ),
      child: Text(label,
          style: ZapTypography.labelSmall.copyWith(color: color)),
    );
  }
}

// ─── Payload Bottom Sheet ─────────────────────────────────────────────────────

class _PayloadSheet extends StatelessWidget {
  const _PayloadSheet({required this.payload});
  final DataExportPayload payload;

  static const _kSectionLabels = <String, String>{
    'notification_prefs': 'Notification Prefs',
    'sos_templates':      'SOS Templates',
    'check_ins':          'Check-ins',
    'safe_zones':         'Safe Zones',
    'incidents':          'Incidents',
    'activity_log':       'Activity Log',
  };

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      builder: (_, ctrl) => Padding(
        padding: const EdgeInsets.fromLTRB(
            ZapSpacing.lg, ZapSpacing.sm, ZapSpacing.lg, ZapSpacing.lg),
        child: ListView(
          controller: ctrl,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: ZapSpacing.md),
                decoration: BoxDecoration(
                  color: ZapColors.bgElevated,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title
            const Row(
              children: [
                Icon(Icons.download_done_rounded,
                    size: 18, color: ZapColors.safe),
                SizedBox(width: 8),
                Text('Your Data Export',
                    style: ZapTypography.headlineSmall),
              ],
            ),
            const SizedBox(height: ZapSpacing.xs),
            Text(
              'Exported at ${payload.exportedAt.substring(0, 19).replaceAll('T', '  ')}',
              style: ZapTypography.labelSmall
                  .copyWith(color: ZapColors.textSecondary),
            ),
            const SizedBox(height: ZapSpacing.lg),

            // Profile row
            _SheetRow(
              icon:  Icons.person_rounded,
              label: 'Phone',
              value: payload.profilePhone,
              color: ZapColors.info,
            ),
            _SheetRow(
              icon:  Icons.history_rounded,
              label: 'History window',
              value: '${payload.historyDays} days',
              color: ZapColors.textSecondary,
            ),
            const SizedBox(height: ZapSpacing.md),

            // Section counts
            const Divider(color: ZapColors.bgElevated),
            const SizedBox(height: ZapSpacing.sm),
            Text('Section Counts',
                style: ZapTypography.labelMedium
                    .copyWith(color: ZapColors.textSecondary)),
            const SizedBox(height: ZapSpacing.sm),
            for (final section in payload.sections)
              if (section != 'profile')
                _SheetRow(
                  icon:  Icons.list_alt_rounded,
                  label: _kSectionLabels[section] ?? section,
                  value: '${payload.sectionCounts[section] ?? 0} item'
                      '${(payload.sectionCounts[section] ?? 0) == 1 ? '' : 's'}',
                  color: ZapColors.safe,
                ),
            const SizedBox(height: ZapSpacing.lg),

            // Schema
            Container(
              padding: const EdgeInsets.all(ZapSpacing.sm),
              decoration: BoxDecoration(
                color: ZapColors.bgElevated,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 13, color: ZapColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    'Schema v${payload.schemaVersion} · '
                    '${payload.sections.length} sections',
                    style: ZapTypography.labelSmall
                        .copyWith(color: ZapColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String   label;
  final String   value;
  final Color    color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Text(label, style: ZapTypography.bodySmall),
          ),
          Text(value,
              style: ZapTypography.labelSmall
                  .copyWith(color: ZapColors.textSecondary)),
        ],
      ),
    );
  }
}

// ─── Empty state & Error banner ───────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: ZapSpacing.xxxl),
      child: Column(
        children: [
          Icon(Icons.download_outlined,
              size: 48, color: ZapColors.textSecondary),
          SizedBox(height: ZapSpacing.md),
          Text('No exports yet — request one above',
              style: ZapTypography.bodySmall,
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.sm),
      decoration: BoxDecoration(
        color: ZapColors.danger.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ZapColors.danger.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 14, color: ZapColors.danger),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Text(message,
                style: ZapTypography.bodySmall
                    .copyWith(color: ZapColors.danger)),
          ),
        ],
      ),
    );
  }
}
