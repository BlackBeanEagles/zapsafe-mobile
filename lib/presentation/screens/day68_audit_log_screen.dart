/// Day 68 — User Activity Audit Log Screen
///
/// Surfaces the append-only activity trail the backend records for every
/// user-initiated event (screen views, SOS interactions, settings changes,
/// template/contact/check-in mutations, etc.).
///
/// • Summary card — total events, last-30-day count, top-3 event types
/// • Event-type filter dropdown — narrows the list to one event type
/// • Paginated entry list — 50 per page, Load More button
/// • Each card shows event icon + label, optional resource chip,
///   relative timestamp and IP address
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/services/audit_log_service.dart';
import '../../domain/providers/audit_log_providers.dart';

// ─── Event-type metadata ──────────────────────────────────────────────────────

class _EvMeta {
  const _EvMeta(this.slug, this.label, this.icon, this.color);
  final String   slug;
  final String   label;
  final IconData icon;
  final Color    color;
}

const _kAll = _EvMeta('', 'All Events', Icons.list_rounded, ZapColors.textSecondary);

const _kEventMeta = <String, _EvMeta>{
  'app_open':         _EvMeta('app_open',         'App Opened',          Icons.smartphone_rounded,       ZapColors.info),
  'sos_view':         _EvMeta('sos_view',          'SOS Screen',          Icons.sos_rounded,              ZapColors.danger),
  'profile_view':     _EvMeta('profile_view',      'Profile Viewed',      Icons.person_rounded,           ZapColors.textSecondary),
  'contacts_view':    _EvMeta('contacts_view',     'Contacts Screen',     Icons.contacts_rounded,         ZapColors.safe),
  'templates_view':   _EvMeta('templates_view',    'Templates Screen',    Icons.message_rounded,          ZapColors.danger),
  'check_in_view':    _EvMeta('check_in_view',     'Check-in Screen',     Icons.timer_rounded,            ZapColors.safe),
  'safe_zone_view':   _EvMeta('safe_zone_view',    'Safe Zones Screen',   Icons.location_on_rounded,      ZapColors.info),
  'drill_view':       _EvMeta('drill_view',        'Drill Screen',        Icons.fitness_center_rounded,   ZapColors.safe),
  'settings_view':    _EvMeta('settings_view',     'Settings Screen',     Icons.settings_rounded,         ZapColors.textSecondary),
  'settings_changed': _EvMeta('settings_changed',  'Settings Changed',    Icons.edit_rounded,             ZapColors.warning),
  'contact_added':    _EvMeta('contact_added',     'Contact Added',       Icons.person_add_rounded,       ZapColors.safe),
  'contact_removed':  _EvMeta('contact_removed',   'Contact Removed',     Icons.person_remove_rounded,    ZapColors.danger),
  'template_created': _EvMeta('template_created',  'Template Created',    Icons.add_circle_rounded,       ZapColors.safe),
  'template_updated': _EvMeta('template_updated',  'Template Updated',    Icons.edit_rounded,             ZapColors.warning),
  'template_deleted': _EvMeta('template_deleted',  'Template Deleted',    Icons.delete_rounded,           ZapColors.danger),
  'check_in_started':   _EvMeta('check_in_started',   'Check-in Started',   Icons.play_circle_rounded,   ZapColors.safe),
  'check_in_completed': _EvMeta('check_in_completed', 'Check-in Completed', Icons.check_circle_rounded,  ZapColors.safe),
  'check_in_expired':   _EvMeta('check_in_expired',   'Check-in Expired',   Icons.timer_off_rounded,     ZapColors.danger),
  'drill_started':      _EvMeta('drill_started',      'Drill Started',       Icons.fitness_center_rounded, ZapColors.safe),
  'export_requested':   _EvMeta('export_requested',   'Export Requested',    Icons.download_rounded,      ZapColors.info),
};

_EvMeta _meta(String slug) =>
    _kEventMeta[slug] ?? _EvMeta(slug, slug, Icons.circle_rounded, ZapColors.textSecondary);

// ─── Screen ───────────────────────────────────────────────────────────────────

class Day68AuditLogScreen extends ConsumerStatefulWidget {
  const Day68AuditLogScreen({super.key});

  @override
  ConsumerState<Day68AuditLogScreen> createState() =>
      _Day68AuditLogScreenState();
}

class _Day68AuditLogScreenState extends ConsumerState<Day68AuditLogScreen> {
  String  _filterSlug = '';          // '' = all
  int     _loadedLimit = 50;         // grows with "Load More"
  bool    _loadingMore = false;

  void _applyFilter(String slug) {
    setState(() {
      _filterSlug  = slug;
      _loadedLimit = 50;
    });
  }

  Future<void> _loadMore(int currentCount) async {
    setState(() => _loadingMore = true);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    setState(() {
      _loadedLimit += 50;
      _loadingMore  = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(auditLogSummaryProvider);
    final listAsync    = ref.watch(auditLogListProvider((_filterSlug, _loadedLimit)));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Log'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              setState(() => _loadedLimit = 50);
              ref.invalidate(auditLogSummaryProvider);
              ref.invalidate(auditLogListProvider((_filterSlug, _loadedLimit)));
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          // ── Summary card ───────────────────────────────────────────────
          summaryAsync.when(
            loading: () => const _SummaryShimmer(),
            error:   (e, _) => _ErrorBanner(message: e.toString()),
            data:    (s) => _SummaryCard(summary: s),
          ),
          const SizedBox(height: ZapSpacing.lg),

          // ── Filter row ─────────────────────────────────────────────────
          _FilterRow(
            selected:  _filterSlug,
            onChanged: _applyFilter,
          ),
          const SizedBox(height: ZapSpacing.md),

          // ── Entry list ─────────────────────────────────────────────────
          listAsync.when(
            loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(ZapSpacing.xl),
                  child: CircularProgressIndicator(),
                )),
            error: (e, _) => _ErrorBanner(message: e.toString()),
            data: (page) {
              if (page.entries.isEmpty) {
                return _EmptyState(hasFilter: _filterSlug.isNotEmpty);
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // entry count label
                  Padding(
                    padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
                    child: Text(
                      '${page.count} event${page.count == 1 ? '' : 's'}'
                      '${_filterSlug.isNotEmpty ? ' · filtered' : ''}',
                      style: ZapTypography.labelSmall
                          .copyWith(color: ZapColors.textSecondary),
                    ),
                  ),
                  // entry cards
                  for (final entry in page.entries) ...[
                    _EntryCard(entry: entry),
                    const SizedBox(height: ZapSpacing.sm),
                  ],
                  // Load More button
                  if (page.entries.length < page.count)
                    Padding(
                      padding: const EdgeInsets.only(top: ZapSpacing.sm),
                      child: _loadingMore
                          ? const Center(child: CircularProgressIndicator())
                          : OutlinedButton.icon(
                              onPressed: () => _loadMore(page.entries.length),
                              icon: const Icon(Icons.expand_more_rounded),
                              label: Text(
                                'Load more  (${page.count - page.entries.length} remaining)',
                              ),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(44),
                              ),
                            ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Summary Card ─────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});
  final AuditLogSummary summary;

  @override
  Widget build(BuildContext context) {
    // Top-3 event types by all-time count.
    final sorted = summary.byEventType.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top3 = sorted.take(3).toList();

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
          // ── Stat row ────────────────────────────────────────────────
          Row(
            children: [
              _StatChip(
                label: 'Total',
                value: summary.totalCount.toString(),
                color: ZapColors.info,
              ),
              const SizedBox(width: ZapSpacing.sm),
              _StatChip(
                label: 'Last 30d',
                value: summary.last30Days.toString(),
                color: ZapColors.safe,
              ),
            ],
          ),
          if (top3.isNotEmpty) ...[
            const SizedBox(height: ZapSpacing.sm),
            const Divider(height: 1, color: ZapColors.bgElevated),
            const SizedBox(height: ZapSpacing.sm),
            Text('Top activity',
                style: ZapTypography.labelSmall
                    .copyWith(color: ZapColors.textSecondary)),
            const SizedBox(height: ZapSpacing.xs),
            for (final e in top3)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(_meta(e.key).icon, size: 13, color: _meta(e.key).color),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(_meta(e.key).label,
                          style: ZapTypography.bodySmall),
                    ),
                    Text('${e.value}×',
                        style: ZapTypography.labelSmall
                            .copyWith(color: ZapColors.textSecondary)),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: ZapSpacing.sm, vertical: ZapSpacing.xs),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Text(value,
              style: ZapTypography.labelMedium.copyWith(color: color)),
          Text(label,
              style: ZapTypography.labelSmall
                  .copyWith(color: ZapColors.textSecondary)),
        ],
      ),
    );
  }
}

class _SummaryShimmer extends StatelessWidget {
  const _SummaryShimmer();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZapColors.bgElevated),
      ),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}

// ─── Filter Row ───────────────────────────────────────────────────────────────

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.selected, required this.onChanged});
  final String                  selected;
  final ValueChanged<String>    onChanged;

  // Quick-access filter slugs shown as chips.
  static const _kQuick = [
    _kAll,
    _EvMeta('app_open',         'App Open',        Icons.smartphone_rounded,     ZapColors.info),
    _EvMeta('sos_view',         'SOS',             Icons.sos_rounded,            ZapColors.danger),
    _EvMeta('settings_changed', 'Settings',        Icons.edit_rounded,           ZapColors.warning),
    _EvMeta('check_in_started', 'Check-in',        Icons.timer_rounded,          ZapColors.safe),
    _EvMeta('template_created', 'Templates',       Icons.message_rounded,        ZapColors.danger),
    _EvMeta('contact_added',    'Contacts',        Icons.person_add_rounded,     ZapColors.safe),
    _EvMeta('drill_started',    'Drill',           Icons.fitness_center_rounded, ZapColors.safe),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final m in _kQuick)
            Padding(
              padding: const EdgeInsets.only(right: ZapSpacing.xs),
              child: _FilterChip(
                meta:     m,
                selected: selected == m.slug,
                onTap:    () => onChanged(m.slug),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.meta,
    required this.selected,
    required this.onTap,
  });

  final _EvMeta  meta;
  final bool     selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.sm),
        decoration: BoxDecoration(
          color: selected
              ? meta.color.withOpacity(0.15)
              : ZapColors.bgCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? meta.color.withOpacity(0.60) : ZapColors.bgElevated,
          ),
        ),
        child: Row(
          children: [
            Icon(meta.icon,
                size: 13,
                color: selected ? meta.color : ZapColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              meta.label,
              style: ZapTypography.labelSmall.copyWith(
                color: selected ? meta.color : ZapColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Entry Card ───────────────────────────────────────────────────────────────

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});
  final AuditLogEntry entry;

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60)  return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24)  return '${diff.inHours}h ago';
    if (diff.inDays    < 30)  return '${diff.inDays}d ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }

  @override
  Widget build(BuildContext context) {
    final m = _meta(entry.eventType);

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: ZapSpacing.md, vertical: ZapSpacing.sm),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ZapColors.bgElevated),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Padding(
            padding: const EdgeInsets.only(top: 2, right: ZapSpacing.sm),
            child: Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: m.color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(m.icon, size: 15, color: m.color),
            ),
          ),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // event label + timestamp
                Row(
                  children: [
                    Expanded(
                      child: Text(m.label,
                          style: ZapTypography.bodySmall),
                    ),
                    Text(_relativeTime(entry.createdAt),
                        style: ZapTypography.labelSmall
                            .copyWith(color: ZapColors.textSecondary)),
                  ],
                ),
                // resource chip
                if (entry.resourceType.isNotEmpty || entry.resourceId.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: _ResourceChip(
                        type: entry.resourceType, id: entry.resourceId),
                  ),
                // IP address
                if (entry.ipAddress != null && entry.ipAddress!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        const Icon(Icons.router_rounded,
                            size: 11, color: ZapColors.textSecondary),
                        const SizedBox(width: 3),
                        Text(entry.ipAddress!,
                            style: ZapTypography.labelSmall
                                .copyWith(color: ZapColors.textSecondary)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResourceChip extends StatelessWidget {
  const _ResourceChip({required this.type, required this.id});
  final String type;
  final String id;

  @override
  Widget build(BuildContext context) {
    final label = [
      if (type.isNotEmpty) type,
      if (id.isNotEmpty)   id.length > 12 ? '${id.substring(0, 8)}…' : id,
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: ZapColors.bgElevated,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: ZapTypography.labelSmall
              .copyWith(color: ZapColors.textSecondary)),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasFilter});
  final bool hasFilter;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ZapSpacing.xxxl),
      child: Column(
        children: [
          const Icon(Icons.history_rounded,
              size: 48, color: ZapColors.textSecondary),
          const SizedBox(height: ZapSpacing.md),
          Text(
            hasFilter ? 'No events match this filter' : 'No activity recorded yet',
            style: ZapTypography.bodyMedium
                .copyWith(color: ZapColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Error banner ─────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.danger.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ZapColors.danger.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 16, color: ZapColors.danger),
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
