/// Day 228 — SOS History Timeline Polish
///
/// Section B (Days 221-240): full SOS event history with outcome badges,
/// map thumbnails, evidence vault links, and year filter. Mock data today;
/// wired for GET /api/v1/sos/history/ when backend is live.
///
/// Tag: 🟣 POLISH — extends analytics/history UX; mock until API ships.
///
/// Route: [AppRoutes.sosHistoryTimeline] → `/sos-history-timeline`
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';
import '../widgets/zap_empty_state.dart';

// ── Model ─────────────────────────────────────────────────────────────────────
enum SosOutcome {
  resolved,
  falseAlarm,
  cancelled,
  drill,
  expired,
  policeDispatched,
}

extension SosOutcomeX on SosOutcome {
  String get label {
    switch (this) {
      case SosOutcome.resolved:
        return 'Resolved';
      case SosOutcome.falseAlarm:
        return 'False alarm';
      case SosOutcome.cancelled:
        return 'Cancelled';
      case SosOutcome.drill:
        return 'Drill';
      case SosOutcome.expired:
        return 'Expired';
      case SosOutcome.policeDispatched:
        return 'Police dispatched';
    }
  }

  Color get color {
    switch (this) {
      case SosOutcome.resolved:
        return ZapColors.safe;
      case SosOutcome.falseAlarm:
        return ZapColors.warning;
      case SosOutcome.cancelled:
        return ZapColors.textMuted;
      case SosOutcome.drill:
        return ZapColors.info;
      case SosOutcome.expired:
        return ZapColors.textSecondary;
      case SosOutcome.policeDispatched:
        return ZapColors.danger;
    }
  }

  IconData get icon {
    switch (this) {
      case SosOutcome.resolved:
        return Icons.check_circle_rounded;
      case SosOutcome.falseAlarm:
        return Icons.report_gmailerrorred_rounded;
      case SosOutcome.cancelled:
        return Icons.cancel_rounded;
      case SosOutcome.drill:
        return Icons.fitness_center_rounded;
      case SosOutcome.expired:
        return Icons.hourglass_disabled_rounded;
      case SosOutcome.policeDispatched:
        return Icons.local_police_rounded;
    }
  }
}

class SosHistoryEntry {
  const SosHistoryEntry({
    required this.id,
    required this.reference,
    required this.triggeredAt,
    required this.outcome,
    required this.locationLabel,
    required this.lat,
    required this.lng,
    required this.evidenceCount,
    required this.contactsNotified,
    required this.durationMinutes,
    this.resolvedAt,
    this.policeRef,
  });

  final String id;
  final String reference;
  final DateTime triggeredAt;
  final DateTime? resolvedAt;
  final SosOutcome outcome;
  final String locationLabel;
  final double lat;
  final double lng;
  final int evidenceCount;
  final int contactsNotified;
  final int durationMinutes;
  final String? policeRef;

  int get year => triggeredAt.year;
}

final _kMockHistory = <SosHistoryEntry>[
  SosHistoryEntry(
    id: 'sos_a8f3c21e-8842',
    reference: 'ZS-2026-0312',
    triggeredAt: DateTime(2026, 3, 12, 10, 41),
    resolvedAt: DateTime(2026, 3, 12, 10, 58),
    outcome: SosOutcome.policeDispatched,
    locationLabel: 'Bandra West, Mumbai · 8m accuracy',
    lat: 19.0760,
    lng: 72.8777,
    evidenceCount: 3,
    contactsNotified: 4,
    durationMinutes: 17,
    policeRef: 'MP-2026-88421',
  ),
  SosHistoryEntry(
    id: 'sos_b2e91f44-1102',
    reference: 'ZS-2026-0204',
    triggeredAt: DateTime(2026, 2, 4, 22, 15),
    resolvedAt: DateTime(2026, 2, 4, 22, 19),
    outcome: SosOutcome.falseAlarm,
    locationLabel: 'Andheri East, Mumbai · 14m accuracy',
    lat: 19.1136,
    lng: 72.8697,
    evidenceCount: 1,
    contactsNotified: 3,
    durationMinutes: 4,
  ),
  SosHistoryEntry(
    id: 'sos_c44d7721-0901',
    reference: 'ZS-2026-0118',
    triggeredAt: DateTime(2026, 1, 18, 8, 30),
    resolvedAt: DateTime(2026, 1, 18, 8, 42),
    outcome: SosOutcome.drill,
    locationLabel: 'Home · scheduled drill',
    lat: 19.0176,
    lng: 72.8562,
    evidenceCount: 0,
    contactsNotified: 2,
    durationMinutes: 12,
  ),
  SosHistoryEntry(
    id: 'sos_d91a0032-1124',
    reference: 'ZS-2025-1124',
    triggeredAt: DateTime(2025, 11, 24, 19, 02),
    resolvedAt: DateTime(2025, 11, 24, 19, 28),
    outcome: SosOutcome.resolved,
    locationLabel: 'Powai Lake trail · 22m accuracy',
    lat: 19.1176,
    lng: 72.9060,
    evidenceCount: 5,
    contactsNotified: 5,
    durationMinutes: 26,
  ),
  SosHistoryEntry(
    id: 'sos_e55b8810-0703',
    reference: 'ZS-2025-0703',
    triggeredAt: DateTime(2025, 7, 3, 14, 55),
    resolvedAt: DateTime(2025, 7, 3, 15, 01),
    outcome: SosOutcome.cancelled,
    locationLabel: 'Phoenix Mall, Lower Parel',
    lat: 18.9965,
    lng: 72.8321,
    evidenceCount: 0,
    contactsNotified: 1,
    durationMinutes: 6,
  ),
  SosHistoryEntry(
    id: 'sos_f33c2290-0410',
    reference: 'ZS-2025-0410',
    triggeredAt: DateTime(2025, 4, 10, 6, 12),
    resolvedAt: DateTime(2025, 4, 10, 6, 45),
    outcome: SosOutcome.resolved,
    locationLabel: 'Juhu Beach · morning jog',
    lat: 19.1000,
    lng: 72.8260,
    evidenceCount: 2,
    contactsNotified: 4,
    durationMinutes: 33,
  ),
  SosHistoryEntry(
    id: 'sos_g77d0041-0822',
    reference: 'ZS-2024-0822',
    triggeredAt: DateTime(2024, 8, 22, 23, 48),
    resolvedAt: DateTime(2024, 8, 23, 0, 12),
    outcome: SosOutcome.expired,
    locationLabel: 'Colaba · GPS drift after 18 min',
    lat: 18.9067,
    lng: 72.8147,
    evidenceCount: 4,
    contactsNotified: 3,
    durationMinutes: 24,
  ),
  SosHistoryEntry(
    id: 'sos_h12e5560-0305',
    reference: 'ZS-2024-0305',
    triggeredAt: DateTime(2024, 3, 5, 17, 20),
    resolvedAt: DateTime(2024, 3, 5, 17, 35),
    outcome: SosOutcome.drill,
    locationLabel: 'Office · quarterly drill',
    lat: 19.0760,
    lng: 72.8777,
    evidenceCount: 0,
    contactsNotified: 2,
    durationMinutes: 15,
  ),
];

const _kApiSample = '''[
  {
    "id": "sos_a8f3c21e-8842",
    "reference": "ZS-2026-0312",
    "triggered_at": "2026-03-12T10:41:00+05:30",
    "resolved_at": "2026-03-12T10:58:00+05:30",
    "outcome": "police_dispatched",
    "location": { "lat": 19.076, "lng": 72.8777, "label": "Bandra West" },
    "evidence_count": 3,
    "contacts_notified": 4,
    "duration_minutes": 17,
    "police_ref": "MP-2026-88421"
  }
]''';

// ── Providers ─────────────────────────────────────────────────────────────────
final _d228TabProvider = StateProvider<int>((ref) => 0);
final _d228YearProvider = StateProvider<int?>((ref) => null);
final _d228ExpandedProvider = StateProvider<Set<String>>((ref) => {});

const _kTabs = ['Timeline', 'Year Filter', 'API Contract'];

List<SosHistoryEntry> _filteredHistory(int? year) {
  final sorted = [..._kMockHistory]
    ..sort((a, b) => b.triggeredAt.compareTo(a.triggeredAt));
  if (year == null) return sorted;
  return sorted.where((e) => e.year == year).toList();
}

List<int> _availableYears() {
  final years = _kMockHistory.map((e) => e.year).toSet().toList()
    ..sort((a, b) => b.compareTo(a));
  return years;
}

String _fmtDate(DateTime dt) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '${dt.day} ${months[dt.month - 1]} ${dt.year} · $h:$m';
}

// ── Screen ────────────────────────────────────────────────────────────────────
class Day228SosHistoryTimelineScreen extends ConsumerWidget {
  const Day228SosHistoryTimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d228TabProvider);
    final year = ref.watch(_d228YearProvider);
    final entries = _filteredHistory(year);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 228 · SOS History Timeline'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: ZapSpacing.sm, vertical: ZapSpacing.xs),
                decoration: BoxDecoration(
                  color: ZapColors.info.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: ZapColors.info.withOpacity(0.35)),
                ),
                child: Text(
                  year == null
                      ? '${entries.length} events'
                      : '$year · ${entries.length}',
                  style: const TextStyle(
                    color: ZapColors.info,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _TabBar(
            tab: tab,
            onSelect: (i) => ref.read(_d228TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (tab) {
              0 => const _TimelineTab(),
              1 => const _YearFilterTab(),
              _ => const _ApiContractTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Timeline ───────────────────────────────────────────────────────────
class _TimelineTab extends ConsumerWidget {
  const _TimelineTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = ref.watch(_d228YearProvider);
    final entries = _filteredHistory(year);
    final expanded = ref.watch(_d228ExpandedProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: ZapColors.info.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: ZapColors.info.withOpacity(0.35)),
          ),
          child: const Text(
            '🟣 POLISH · Section B Day 8/20 · outcome badges · map thumb · evidence link · year filter',
            style: TextStyle(color: ZapColors.info, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              label: const Text('Day 227 Notifications'),
              onPressed: () => context.push(AppRoutes.notificationHistoryV3),
            ),
            ActionChip(
              label: const Text('Evidence Vault'),
              onPressed: () => context.push(AppRoutes.evidenceVault),
            ),
            if (year != null)
              ActionChip(
                avatar: const Icon(Icons.filter_alt_off_rounded, size: 16),
                label: Text('Clear $year filter'),
                onPressed: () =>
                    ref.read(_d228YearProvider.notifier).state = null,
              ),
          ],
        ),
        const SizedBox(height: ZapSpacing.lg),
        if (entries.isEmpty)
          ZapEmptyInline(
            title: 'No SOS events for this year.',
            actionLabel: year != null ? 'Clear $year filter' : null,
            onAction: year != null
                ? () => ref.read(_d228YearProvider.notifier).state = null
                : null,
          )
        else
          ...entries.map((entry) {
            final isExp = expanded.contains(entry.id);
            return _TimelineCard(
              entry: entry,
              expanded: isExp,
              onToggle: () => ref.read(_d228ExpandedProvider.notifier).update(
                (s) {
                  final next = {...s};
                  if (next.contains(entry.id)) {
                    next.remove(entry.id);
                  } else {
                    next.add(entry.id);
                  }
                  return next;
                },
              ),
            );
          }),
      ],
    );
  }
}

class _TimelineCard extends StatelessWidget {
  final SosHistoryEntry entry;
  final bool expanded;
  final VoidCallback onToggle;

  const _TimelineCard({
    required this.entry,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(
          color: entry.outcome == SosOutcome.policeDispatched
              ? ZapColors.danger.withOpacity(0.4)
              : ZapColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            child: Padding(
              padding: const EdgeInsets.all(ZapSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MapThumbnail(lat: entry.lat, lng: entry.lng, compact: true),
                  const SizedBox(width: ZapSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                entry.reference,
                                style: const TextStyle(
                                  color: ZapColors.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            _OutcomeBadge(outcome: entry.outcome),
                          ],
                        ),
                        const SizedBox(height: ZapSpacing.xs),
                        Text(
                          _fmtDate(entry.triggeredAt),
                          style: const TextStyle(
                            color: ZapColors.textMuted,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: ZapSpacing.xs),
                        Text(
                          entry.locationLabel,
                          style: const TextStyle(
                            color: ZapColors.textSecondary,
                            fontSize: 10,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _MetaChip(
                              icon: Icons.timer_outlined,
                              label: '${entry.durationMinutes}m',
                            ),
                            const SizedBox(width: 6),
                            _MetaChip(
                              icon: Icons.people_outline_rounded,
                              label: '${entry.contactsNotified}',
                            ),
                            if (entry.evidenceCount > 0) ...[
                              const SizedBox(width: 6),
                              _MetaChip(
                                icon: Icons.folder_special_outlined,
                                label: '${entry.evidenceCount}',
                                color: ZapColors.warning,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: ZapColors.textMuted,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(color: ZapColors.border, height: 1),
            Padding(
              padding: const EdgeInsets.all(ZapSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _MapThumbnail(lat: entry.lat, lng: entry.lng, compact: false),
                  const SizedBox(height: ZapSpacing.sm),
                  Text(
                    entry.locationLabel,
                    style: const TextStyle(
                      color: ZapColors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: ZapSpacing.md),
                  _DetailRow(label: 'SOS ID', value: entry.id, mono: true),
                  if (entry.policeRef != null)
                    _DetailRow(
                      label: 'Police ref',
                      value: entry.policeRef!,
                      mono: true,
                    ),
                  _DetailRow(
                    label: 'Resolved',
                    value: entry.resolvedAt != null
                        ? _fmtDate(entry.resolvedAt!)
                        : '—',
                  ),
                  const SizedBox(height: ZapSpacing.md),
                  Row(
                    children: [
                      if (entry.evidenceCount > 0)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                context.push(AppRoutes.evidenceVault),
                            icon:
                                const Icon(Icons.folder_open_rounded, size: 16),
                            label: Text(
                              'Evidence (${entry.evidenceCount})',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                      if (entry.evidenceCount > 0 &&
                          entry.outcome == SosOutcome.policeDispatched)
                        const SizedBox(width: ZapSpacing.sm),
                      if (entry.outcome == SosOutcome.policeDispatched)
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () =>
                                context.push(AppRoutes.policeWeblinkPreview),
                            icon: const Icon(Icons.local_police_rounded,
                                size: 16),
                            label: const Text(
                              'Police view',
                              style: TextStyle(fontSize: 11),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: ZapColors.danger,
                            ),
                          ),
                        ),
                    ],
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

class _OutcomeBadge extends StatelessWidget {
  final SosOutcome outcome;

  const _OutcomeBadge({required this.outcome});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: outcome.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: outcome.color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(outcome.icon, size: 10, color: outcome.color),
          const SizedBox(width: 3),
          Text(
            outcome.label,
            style: TextStyle(
              color: outcome.color,
              fontSize: 8,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _MetaChip({
    required this.icon,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? ZapColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: ZapColors.bgElevated,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: ZapColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: c),
          const SizedBox(width: 3),
          Text(
            label,
            style:
                TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;

  const _DetailRow({
    required this.label,
    required this.value,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(color: ZapColors.textMuted, fontSize: 10),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: ZapColors.textSecondary,
                fontSize: 10,
                fontFamily: mono ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapThumbnail extends StatelessWidget {
  final double lat;
  final double lng;
  final bool compact;

  const _MapThumbnail({
    required this.lat,
    required this.lng,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final size = compact ? 56.0 : double.infinity;
    final height = compact ? 56.0 : 120.0;

    return Container(
      width: size,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF1A2332),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ZapColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _MapGridPainter()),
          Center(
            child: Icon(
              Icons.location_pin,
              color: ZapColors.danger.withOpacity(0.9),
              size: compact ? 18 : 28,
            ),
          ),
          if (!compact)
            Positioned(
              bottom: 6,
              left: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontFamily: 'monospace',
                    fontSize: 9,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..strokeWidth = 1;
    const step = 16.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final road = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(0, size.height * 0.4),
      Offset(size.width, size.height * 0.55),
      road,
    );
    canvas.drawLine(
      Offset(size.width * 0.3, 0),
      Offset(size.width * 0.7, size.height),
      road,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Tab 1: Year filter ────────────────────────────────────────────────────────
class _YearFilterTab extends ConsumerWidget {
  const _YearFilterTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(_d228YearProvider);
    final years = _availableYears();

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text(
          'Filter by year',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: ZapSpacing.xs),
        Text(
          selected == null
              ? 'Showing all ${_kMockHistory.length} events'
              : 'Showing ${_filteredHistory(selected).length} events in $selected',
          style: const TextStyle(color: ZapColors.textMuted, fontSize: 11),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              label: const Text('All years'),
              selected: selected == null,
              onSelected: (_) =>
                  ref.read(_d228YearProvider.notifier).state = null,
              selectedColor: ZapColors.info.withOpacity(0.2),
              checkmarkColor: ZapColors.info,
            ),
            for (final y in years)
              FilterChip(
                label: Text('$y (${_filteredHistory(y).length})'),
                selected: selected == y,
                onSelected: (_) =>
                    ref.read(_d228YearProvider.notifier).state = y,
                selectedColor: ZapColors.info.withOpacity(0.2),
                checkmarkColor: ZapColors.info,
              ),
          ],
        ),
        const SizedBox(height: ZapSpacing.xl),
        const Text(
          'Outcome breakdown',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        ...SosOutcome.values.map((outcome) {
          final pool =
              selected == null ? _kMockHistory : _filteredHistory(selected);
          final count = pool.where((e) => e.outcome == outcome).length;
          if (count == 0) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                _OutcomeBadge(outcome: outcome),
                const Spacer(),
                Text(
                  '$count',
                  style: const TextStyle(
                    color: ZapColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: ZapSpacing.lg),
        FilledButton.icon(
          onPressed: selected == null
              ? null
              : () {
                  ref.read(_d228TabProvider.notifier).state = 0;
                },
          icon: const Icon(Icons.timeline_rounded, size: 18),
          label: Text(
            selected == null
                ? 'Select a year above'
                : 'View $selected timeline',
          ),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 75),
            backgroundColor: ZapColors.info,
          ),
        ),
      ],
    );
  }
}

// ── Tab 2: API contract ───────────────────────────────────────────────────────
class _ApiContractTab extends StatelessWidget {
  const _ApiContractTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: ZapColors.warning.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: ZapColors.warning.withOpacity(0.35)),
          ),
          child: const Text(
            '🔵 May use analytics/history endpoints when available',
            style: TextStyle(color: ZapColors.warning, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const _EndpointCard(
          method: 'GET',
          path: '/api/v1/sos/history/',
          description:
              'Paginated SOS event history for the authenticated user. '
              'Supports ?year=2026 and ?outcome=resolved query params.',
        ),
        const SizedBox(height: ZapSpacing.md),
        const _EndpointCard(
          method: 'GET',
          path: '/api/v1/sos/history/{id}/',
          description:
              'Single event detail including evidence manifest IDs and '
              'map snapshot URL.',
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Sample response (truncated)',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: ZapColors.border),
          ),
          child: const SelectableText(
            _kApiSample,
            style: TextStyle(
              color: ZapColors.textSecondary,
              fontFamily: 'monospace',
              fontSize: 10,
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Semantics(
          label: 'Copy API contract',
          button: true,
          child: FilledButton.icon(
            onPressed: () {
              Clipboard.setData(const ClipboardData(text: _kApiSample));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied sample JSON')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy sample JSON'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 75),
              backgroundColor: ZapColors.bgElevated,
              foregroundColor: ZapColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.info.withOpacity(0.1),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: ZapColors.info.withOpacity(0.3)),
          ),
          child: const Text(
            'Tomorrow: Day 231 — Stealth LP24 icon disguise.',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _EndpointCard extends StatelessWidget {
  final String method;
  final String path;
  final String description;

  const _EndpointCard({
    required this.method,
    required this.path,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: ZapColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: ZapColors.safe.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  method,
                  style: const TextStyle(
                    color: ZapColors.safe,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: Text(
                  path,
                  style: const TextStyle(
                    color: ZapColors.textPrimary,
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.sm),
          Text(
            description,
            style: const TextStyle(color: ZapColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  final int tab;
  final ValueChanged<int> onSelect;

  const _TabBar({required this.tab, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ZapColors.bgCard,
      child: Row(
        children: List.generate(_kTabs.length, (i) {
          final selected = tab == i;
          return Expanded(
            child: Semantics(
              label: '${_kTabs[i]} tab',
              button: true,
              selected: selected,
              child: InkWell(
                onTap: () => onSelect(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: ZapSpacing.md),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: selected ? ZapColors.info : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    _kTabs[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected
                          ? ZapColors.textPrimary
                          : ZapColors.textSecondary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
