/// Day 62 — Incident Report Screen
///
/// • Create a new incident report (POST /api/v1/incidents/)
/// • List past reports with ?days and ?status filters
/// • Tap a report to see its full detail inline
/// • Patch title / notes / status on an existing report
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/services/incident_service.dart';
import '../../domain/providers/incident_providers.dart';

// ─── Formatters ───────────────────────────────────────────────────────────────

final _dateFmt  = DateFormat('MMM d, yyyy · HH:mm');
final _timeFmt  = DateFormat('HH:mm');

String _fmtDuration(int? secs) {
  if (secs == null) return '—';
  if (secs < 60)    return '${secs}s';
  final m = secs ~/ 60;
  final s = secs % 60;
  return s == 0 ? '${m}m' : '${m}m ${s}s';
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class Day62IncidentScreen extends ConsumerStatefulWidget {
  const Day62IncidentScreen({super.key});

  @override
  ConsumerState<Day62IncidentScreen> createState() =>
      _Day62IncidentScreenState();
}

class _Day62IncidentScreenState extends ConsumerState<Day62IncidentScreen> {
  // Create-form state
  final _titleCtrl         = TextEditingController();
  final _locationLabelCtrl = TextEditingController();
  final _notesCtrl         = TextEditingController();

  DateTime  _startedAt = DateTime.now().subtract(const Duration(hours: 1));
  DateTime? _endedAt   = DateTime.now();
  int       _gpsPings  = 0;
  int       _evidenceCount = 0;
  bool      _submitting   = false;
  String?   _submitError;
  String?   _lastId;
  String?   _lastTitle;

  // History filter state
  int    _histDays   = 30;
  String _histStatus = '';          // '' = all

  // Expanded detail state
  String?         _expandedId;
  IncidentDetail? _expandedDetail;
  bool            _loadingDetail = false;
  String?         _detailError;

  // Patch state
  final _patchTitleCtrl = TextEditingController();
  final _patchNotesCtrl = TextEditingController();
  bool    _patching      = false;
  String? _patchError;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locationLabelCtrl.dispose();
    _notesCtrl.dispose();
    _patchTitleCtrl.dispose();
    _patchNotesCtrl.dispose();
    super.dispose();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _createReport() async {
    setState(() { _submitting = true; _submitError = null; });
    try {
      final result = await ref
          .read(incidentServiceProvider)
          .create(
            startedAt:     _startedAt,
            endedAt:       _endedAt,
            title:         _titleCtrl.text.trim(),
            locationLabel: _locationLabelCtrl.text.trim(),
            gpsPointCount: _gpsPings,
            evidenceCount: _evidenceCount,
            notes:         _notesCtrl.text.trim(),
          );
      // Invalidate caches so history refreshes
      ref.invalidate(incidentHistoryProvider);
      setState(() {
        _lastId    = result['id'];
        _lastTitle = result['title'];
        _titleCtrl.clear();
        _locationLabelCtrl.clear();
        _notesCtrl.clear();
        _gpsPings     = 0;
        _evidenceCount = 0;
        _startedAt = DateTime.now().subtract(const Duration(hours: 1));
        _endedAt   = DateTime.now();
      });
    } catch (e) {
      setState(() { _submitError = e.toString(); });
    } finally {
      setState(() { _submitting = false; });
    }
  }

  Future<void> _loadDetail(String id) async {
    if (_expandedId == id) {
      // Collapse
      setState(() { _expandedId = null; _expandedDetail = null; });
      return;
    }
    setState(() {
      _expandedId    = id;
      _expandedDetail = null;
      _loadingDetail  = true;
      _detailError    = null;
    });
    try {
      final detail = await ref.read(incidentServiceProvider).fetchDetail(id);
      _patchTitleCtrl.text = detail.title;
      _patchNotesCtrl.text = detail.notes ?? '';
      setState(() { _expandedDetail = detail; });
    } catch (e) {
      setState(() { _detailError = e.toString(); });
    } finally {
      setState(() { _loadingDetail = false; });
    }
  }

  Future<void> _patchReport(String id) async {
    setState(() { _patching = true; _patchError = null; });
    try {
      final updated = await ref.read(incidentServiceProvider).updateReport(
            id,
            title:  _patchTitleCtrl.text.trim(),
            notes:  _patchNotesCtrl.text.trim(),
            status: _expandedDetail?.status == 'draft' ? 'finalized' : 'draft',
          );
      ref.invalidate(incidentHistoryProvider);
      setState(() { _expandedDetail = updated; });
    } catch (e) {
      setState(() { _patchError = e.toString(); });
    } finally {
      setState(() { _patching = false; });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: ZapColors.bgPrimary,
        title: const Text('Incident Report', style: ZapTypography.headlineSmall),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(ZapSpacing.md),
        children: [
          _CreateCard(
            titleCtrl:         _titleCtrl,
            locationLabelCtrl: _locationLabelCtrl,
            notesCtrl:         _notesCtrl,
            startedAt:         _startedAt,
            endedAt:           _endedAt,
            gpsPings:          _gpsPings,
            evidenceCount:     _evidenceCount,
            submitting:        _submitting,
            onStartedAt:       (dt) => setState(() => _startedAt = dt),
            onEndedAt:         (dt) => setState(() => _endedAt = dt),
            onGpsPings:        (v)  => setState(() => _gpsPings = v),
            onEvidenceCount:   (v)  => setState(() => _evidenceCount = v),
            onSubmit:          _createReport,
          ),
          if (_submitError != null) ...[
            const SizedBox(height: ZapSpacing.sm),
            _ErrorBanner(_submitError!),
          ],
          if (_lastId != null) ...[
            const SizedBox(height: ZapSpacing.sm),
            _SuccessBanner(id: _lastId!, title: _lastTitle ?? ''),
          ],
          const SizedBox(height: ZapSpacing.lg),

          // ── History ───────────────────────────────────────────────────────
          const _SectionLabel('RECENT REPORTS'),
          const SizedBox(height: ZapSpacing.sm),

          // Day filter
          _PeriodChips(
            selected: _histDays,
            onSelect: (d) {
              setState(() { _histDays = d; _expandedId = null; });
            },
          ),
          const SizedBox(height: ZapSpacing.xs),

          // Status filter
          _StatusChips(
            selected: _histStatus,
            onSelect: (s) {
              setState(() { _histStatus = s; _expandedId = null; });
            },
          ),
          const SizedBox(height: ZapSpacing.md),

          _HistorySection(
            days:          _histDays,
            status:        _histStatus,
            expandedId:    _expandedId,
            expandedDetail: _expandedDetail,
            loadingDetail: _loadingDetail,
            detailError:   _detailError,
            patching:      _patching,
            patchError:    _patchError,
            patchTitleCtrl: _patchTitleCtrl,
            patchNotesCtrl: _patchNotesCtrl,
            onTapReport:   _loadDetail,
            onPatch:       _patchReport,
          ),
        ],
      ),
    );
  }
}

// ─── Create card ──────────────────────────────────────────────────────────────

class _CreateCard extends StatelessWidget {
  const _CreateCard({
    required this.titleCtrl,
    required this.locationLabelCtrl,
    required this.notesCtrl,
    required this.startedAt,
    required this.endedAt,
    required this.gpsPings,
    required this.evidenceCount,
    required this.submitting,
    required this.onStartedAt,
    required this.onEndedAt,
    required this.onGpsPings,
    required this.onEvidenceCount,
    required this.onSubmit,
  });

  final TextEditingController titleCtrl;
  final TextEditingController locationLabelCtrl;
  final TextEditingController notesCtrl;
  final DateTime  startedAt;
  final DateTime? endedAt;
  final int  gpsPings;
  final int  evidenceCount;
  final bool submitting;
  final ValueChanged<DateTime>  onStartedAt;
  final ValueChanged<DateTime?> onEndedAt;
  final ValueChanged<int> onGpsPings;
  final ValueChanged<int> onEvidenceCount;
  final VoidCallback onSubmit;

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
          const Row(children: [
            Icon(Icons.add_circle_outline_rounded,
                size: 18, color: ZapColors.danger),
            SizedBox(width: ZapSpacing.xs),
            Text('Create Incident Report',
                style: ZapTypography.labelMedium),
          ]),
          const SizedBox(height: ZapSpacing.md),

          // Title
          const _FieldLabel('Title (optional)'),
          const SizedBox(height: ZapSpacing.xs),
          _TextField(
            controller: titleCtrl,
            hint:       'e.g. Late-night train incident',
          ),
          const SizedBox(height: ZapSpacing.sm),

          // Timestamps row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Started at'),
                    const SizedBox(height: ZapSpacing.xs),
                    _TimeDisplay(dateTime: startedAt),
                  ],
                ),
              ),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Ended at'),
                    const SizedBox(height: ZapSpacing.xs),
                    _TimeDisplay(
                        dateTime: endedAt,
                        placeholder: 'Ongoing'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.sm),

          // Location label
          const _FieldLabel('Location label (optional)'),
          const SizedBox(height: ZapSpacing.xs),
          _TextField(
            controller: locationLabelCtrl,
            hint:       'e.g. Central Park, NYC',
          ),
          const SizedBox(height: ZapSpacing.sm),

          // GPS pings + evidence count row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('GPS pings'),
                    const SizedBox(height: ZapSpacing.xs),
                    _Counter(
                      value: gpsPings,
                      onChanged: onGpsPings,
                      color: ZapColors.info,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Evidence files'),
                    const SizedBox(height: ZapSpacing.xs),
                    _Counter(
                      value: evidenceCount,
                      onChanged: onEvidenceCount,
                      color: ZapColors.warning,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.sm),

          // Notes
          const _FieldLabel('Notes (optional)'),
          const SizedBox(height: ZapSpacing.xs),
          _TextField(
            controller: notesCtrl,
            hint:       'Officer badge #, witness info…',
            maxLines:   3,
          ),
          const SizedBox(height: ZapSpacing.md),

          // Submit
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: submitting ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: ZapColors.danger,
                foregroundColor: ZapColors.textPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: submitting
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: ZapColors.textPrimary),
                    )
                  : const Icon(Icons.save_alt_rounded, size: 18),
              label: Text(
                submitting ? 'Saving…' : 'Save Report',
                style: ZapTypography.labelMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── History section ──────────────────────────────────────────────────────────

class _HistorySection extends ConsumerWidget {
  const _HistorySection({
    required this.days,
    required this.status,
    required this.expandedId,
    required this.expandedDetail,
    required this.loadingDetail,
    required this.detailError,
    required this.patching,
    required this.patchError,
    required this.patchTitleCtrl,
    required this.patchNotesCtrl,
    required this.onTapReport,
    required this.onPatch,
  });

  final int    days;
  final String status;
  final String?         expandedId;
  final IncidentDetail? expandedDetail;
  final bool   loadingDetail;
  final String? detailError;
  final bool   patching;
  final String? patchError;
  final TextEditingController patchTitleCtrl;
  final TextEditingController patchNotesCtrl;
  final Future<void> Function(String) onTapReport;
  final Future<void> Function(String) onPatch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(
      incidentHistoryProvider((days: days, status: status)),
    );

    return async.when(
      loading: () => const _Spinner(),
      error:   (e, _) => _ErrorBanner(e.toString()),
      data: (history) {
        if (history.reports.isEmpty) {
          return const _EmptyBox('No reports in this window.');
        }
        return Column(
          children: history.reports.map((r) => _ReportCard(
            entry:          r,
            isExpanded:     expandedId == r.id,
            detail:         expandedId == r.id ? expandedDetail : null,
            loadingDetail:  expandedId == r.id && loadingDetail,
            detailError:    expandedId == r.id ? detailError : null,
            patching:       expandedId == r.id && patching,
            patchError:     expandedId == r.id ? patchError : null,
            patchTitleCtrl: patchTitleCtrl,
            patchNotesCtrl: patchNotesCtrl,
            onTap:  () => onTapReport(r.id),
            onPatch: () => onPatch(r.id),
          )).toList(),
        );
      },
    );
  }
}

// ─── Report card ──────────────────────────────────────────────────────────────

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.entry,
    required this.isExpanded,
    required this.detail,
    required this.loadingDetail,
    required this.detailError,
    required this.patching,
    required this.patchError,
    required this.patchTitleCtrl,
    required this.patchNotesCtrl,
    required this.onTap,
    required this.onPatch,
  });

  final IncidentListEntry entry;
  final bool   isExpanded;
  final IncidentDetail? detail;
  final bool   loadingDetail;
  final String? detailError;
  final bool   patching;
  final String? patchError;
  final TextEditingController patchTitleCtrl;
  final TextEditingController patchNotesCtrl;
  final VoidCallback onTap;
  final VoidCallback onPatch;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
        decoration: BoxDecoration(
          color: ZapColors.bgCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isExpanded ? ZapColors.danger : ZapColors.bgElevated,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Summary row ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(ZapSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + status badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.title,
                          style: ZapTypography.labelMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: ZapSpacing.sm),
                      _StatusBadge(entry.status),
                    ],
                  ),
                  const SizedBox(height: ZapSpacing.xs),

                  // Timestamps
                  Text(
                    _dateFmt.format(entry.startedAt),
                    style: ZapTypography.bodySmall.copyWith(
                        color: ZapColors.textSecondary),
                  ),
                  const SizedBox(height: ZapSpacing.xs),

                  // Metrics row
                  Wrap(
                    spacing: ZapSpacing.sm,
                    children: [
                      _MetaChip(
                        icon: Icons.timer_outlined,
                        label: _fmtDuration(entry.durationSeconds),
                        color: ZapColors.info,
                      ),
                      _MetaChip(
                        icon: Icons.location_on_outlined,
                        label: (entry.gpsPointCount ?? 0) == 0
                            ? 'No GPS'
                            : '${entry.gpsPointCount} pings',
                        color: ZapColors.safe,
                      ),
                      _MetaChip(
                        icon: Icons.attach_file_rounded,
                        label: '${entry.evidenceCount ?? 0} files',
                        color: ZapColors.warning,
                      ),
                      if ((entry.ackedContactCount ?? 0) > 0)
                        _MetaChip(
                          icon: Icons.check_circle_outline_rounded,
                          label: '${entry.ackedContactCount} acked',
                          color: ZapColors.safe,
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Expanded detail ───────────────────────────────────────────
            if (isExpanded) ...[
              const Divider(height: 1, color: ZapColors.bgElevated),
              if (loadingDetail)
                const Padding(
                  padding: EdgeInsets.all(ZapSpacing.md),
                  child: _Spinner(),
                )
              else if (detailError != null)
                Padding(
                  padding: const EdgeInsets.all(ZapSpacing.md),
                  child: _ErrorBanner(detailError!),
                )
              else if (detail != null)
                _DetailPanel(
                  detail:     detail!,
                  patching:   patching,
                  patchError: patchError,
                  titleCtrl:  patchTitleCtrl,
                  notesCtrl:  patchNotesCtrl,
                  onPatch:    onPatch,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Detail panel (inside expanded card) ──────────────────────────────────────

class _DetailPanel extends StatelessWidget {
  const _DetailPanel({
    required this.detail,
    required this.patching,
    required this.patchError,
    required this.titleCtrl,
    required this.notesCtrl,
    required this.onPatch,
  });

  final IncidentDetail detail;
  final bool   patching;
  final String? patchError;
  final TextEditingController titleCtrl;
  final TextEditingController notesCtrl;
  final VoidCallback onPatch;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(ZapSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Location
          if ((detail.locationLabel ?? '').isNotEmpty) ...[
            _DetailRow(
              icon: Icons.location_on_rounded,
              color: ZapColors.safe,
              label: detail.locationLabel!,
            ),
            const SizedBox(height: ZapSpacing.xs),
          ],

          // Coords
          if (detail.latitude != null && detail.longitude != null) ...[
            _DetailRow(
              icon: Icons.my_location_rounded,
              color: ZapColors.info,
              label:
                  '${detail.latitude!.toStringAsFixed(5)}, ${detail.longitude!.toStringAsFixed(5)}',
            ),
            const SizedBox(height: ZapSpacing.xs),
          ],

          // Contacts
          if (detail.contactsNotified.isNotEmpty) ...[
            const _FieldLabel('Contacts notified'),
            const SizedBox(height: ZapSpacing.xs),
            ...detail.contactsNotified.map((c) => _ContactRow(contact: c)),
            const SizedBox(height: ZapSpacing.xs),
          ],

          // Inference summary
          if (detail.inferenceSummary.isNotEmpty) ...[
            const _FieldLabel('Inference summary'),
            const SizedBox(height: ZapSpacing.xs),
            Container(
              padding: const EdgeInsets.all(ZapSpacing.sm),
              decoration: BoxDecoration(
                color: ZapColors.bgElevated,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                detail.inferenceSummary.entries
                    .map((e) => '${e.key}: ${e.value}')
                    .join('  ·  '),
                style: ZapTypography.bodySmall
                    .copyWith(color: ZapColors.textSecondary),
              ),
            ),
            const SizedBox(height: ZapSpacing.sm),
          ],

          // Updated at
          Text(
            'Updated ${_dateFmt.format(detail.updatedAt)}',
            style: ZapTypography.labelSmall
                .copyWith(color: ZapColors.textSecondary),
          ),
          const SizedBox(height: ZapSpacing.md),

          // Editable title + notes
          const _FieldLabel('Edit title'),
          const SizedBox(height: ZapSpacing.xs),
          _TextField(controller: titleCtrl, hint: 'Incident title'),
          const SizedBox(height: ZapSpacing.sm),
          const _FieldLabel('Edit notes'),
          const SizedBox(height: ZapSpacing.xs),
          _TextField(
            controller: notesCtrl,
            hint:     'Additional notes…',
            maxLines: 3,
          ),
          if (patchError != null) ...[
            const SizedBox(height: ZapSpacing.xs),
            _ErrorBanner(patchError!),
          ],
          const SizedBox(height: ZapSpacing.sm),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: patching ? null : onPatch,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ZapColors.info,
                    side: const BorderSide(color: ZapColors.info),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: patching
                      ? const SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: ZapColors.info),
                        )
                      : const Icon(Icons.save_rounded, size: 16),
                  label: Text(
                    patching ? 'Saving…' : 'Save & Toggle status',
                    style: ZapTypography.labelSmall,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Filter chips ─────────────────────────────────────────────────────────────

class _PeriodChips extends StatelessWidget {
  const _PeriodChips({required this.selected, required this.onSelect});
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: ZapSpacing.xs,
      children: [7, 30, 90, 365].map((d) {
        final active = selected == d;
        return GestureDetector(
          onTap: () => onSelect(d),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: ZapSpacing.sm, vertical: 4),
            decoration: BoxDecoration(
              color: active ? ZapColors.danger : ZapColors.bgCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: active ? ZapColors.danger : ZapColors.bgElevated),
            ),
            child: Text(
              d == 365 ? '1y' : '${d}d',
              style: ZapTypography.labelSmall.copyWith(
                color: active ? ZapColors.textPrimary : ZapColors.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _StatusChips extends StatelessWidget {
  const _StatusChips({required this.selected, required this.onSelect});
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: ZapSpacing.xs,
      children: IncidentStatusFilter.values.map((f) {
        final active = selected == f.value;
        return GestureDetector(
          onTap: () => onSelect(f.value),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: ZapSpacing.sm, vertical: 4),
            decoration: BoxDecoration(
              color: active ? ZapColors.bgElevated : ZapColors.bgCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color:
                      active ? ZapColors.textSecondary : ZapColors.bgElevated),
            ),
            child: Text(
              f.label,
              style: ZapTypography.labelSmall.copyWith(
                color: active ? ZapColors.textPrimary : ZapColors.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Small widgets ────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.status);
  final String status;

  @override
  Widget build(BuildContext context) {
    final isFinalized = status == 'finalized';
    final color = isFinalized ? ZapColors.safe : ZapColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isFinalized ? 'Finalized' : 'Draft',
        style: ZapTypography.labelSmall.copyWith(color: color),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String   label;
  final Color    color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: ZapTypography.labelSmall.copyWith(color: color),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.color,
    required this.label,
  });
  final IconData icon;
  final Color    color;
  final String   label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: ZapSpacing.xs),
        Expanded(
          child: Text(
            label,
            style: ZapTypography.bodySmall.copyWith(color: ZapColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.contact});
  final IncidentContactEntry contact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            contact.acked
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 14,
            color: contact.acked ? ZapColors.safe : ZapColors.textSecondary,
          ),
          const SizedBox(width: ZapSpacing.xs),
          Text(
            contact.name,
            style: ZapTypography.bodySmall,
          ),
          if (contact.tier != null) ...[
            const SizedBox(width: ZapSpacing.xs),
            Text(
              'T${contact.tier}',
              style: ZapTypography.labelSmall
                  .copyWith(color: ZapColors.textSecondary),
            ),
          ],
          if (contact.ackTimeMs != null) ...[
            const Spacer(),
            Text(
              '${contact.ackTimeMs}ms',
              style: ZapTypography.labelSmall
                  .copyWith(color: ZapColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _TimeDisplay extends StatelessWidget {
  const _TimeDisplay({this.dateTime, this.placeholder = '—'});
  final DateTime? dateTime;
  final String    placeholder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: ZapSpacing.sm, vertical: ZapSpacing.xs),
      decoration: BoxDecoration(
        color: ZapColors.bgElevated,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        dateTime == null ? placeholder : _timeFmt.format(dateTime!),
        style: ZapTypography.bodySmall.copyWith(color: ZapColors.textSecondary),
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({
    required this.value,
    required this.onChanged,
    required this.color,
  });
  final int   value;
  final ValueChanged<int> onChanged;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () { if (value > 0) onChanged(value - 1); },
          child: Container(
            width: 28, height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ZapColors.bgElevated,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.remove, size: 14, color: ZapColors.textSecondary),
          ),
        ),
        const SizedBox(width: ZapSpacing.xs),
        Text(
          '$value',
          style: ZapTypography.labelMedium.copyWith(color: color),
        ),
        const SizedBox(width: ZapSpacing.xs),
        GestureDetector(
          onTap: () => onChanged(value + 1),
          child: Container(
            width: 28, height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ZapColors.bgElevated,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.add, size: 14, color: ZapColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: ZapTypography.labelSmall.copyWith(
          color: ZapColors.textSecondary,
          letterSpacing: 1.1,
        ),
      );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: ZapTypography.labelSmall.copyWith(
            color: ZapColors.textSecondary),
      );
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.controller,
    this.hint     = '',
    this.maxLines = 1,
  });
  final TextEditingController controller;
  final String hint;
  final int    maxLines;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        maxLines:   maxLines,
        style:      ZapTypography.bodySmall,
        decoration: InputDecoration(
          filled:    true,
          fillColor: ZapColors.bgElevated,
          hintText:  hint,
          hintStyle: ZapTypography.bodySmall
              .copyWith(color: ZapColors.textSecondary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: ZapSpacing.sm, vertical: ZapSpacing.xs),
        ),
      );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(ZapSpacing.sm),
        decoration: BoxDecoration(
          color: ZapColors.danger.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ZapColors.danger.withOpacity(0.4)),
        ),
        child: Text(
          message,
          style: ZapTypography.bodySmall.copyWith(color: ZapColors.danger),
        ),
      );
}

class _SuccessBanner extends StatelessWidget {
  const _SuccessBanner({required this.id, required this.title});
  final String id;
  final String title;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(ZapSpacing.sm),
        decoration: BoxDecoration(
          color: ZapColors.safe.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ZapColors.safe.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                size: 16, color: ZapColors.safe),
            const SizedBox(width: ZapSpacing.xs),
            Expanded(
              child: Text(
                'Saved: $title (${id.substring(0, 8)}…)',
                style: ZapTypography.bodySmall
                    .copyWith(color: ZapColors.safe),
              ),
            ),
          ],
        ),
      );
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(ZapSpacing.lg),
          child: CircularProgressIndicator(
              color: ZapColors.danger, strokeWidth: 2),
        ),
      );
}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: ZapSpacing.lg),
          child: Text(
            message,
            style: ZapTypography.bodySmall
                .copyWith(color: ZapColors.textSecondary),
          ),
        ),
      );
}
