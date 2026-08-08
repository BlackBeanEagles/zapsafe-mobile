/// Day 206 — Evidence Vault Search & Filter
///
/// Section A (Days 201-220): date range, trigger type, status, tamper filters
/// plus SOS ID / date search on mock vault entries.
///
/// Tag: 🟣 POLISH — ships filter UX for Day 82 Evidence Vault integration.
///
/// Route: [AppRoutes.vaultSearchFilter] → `/vault-search-filter`
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../widgets/zap_empty_state.dart';

// ── Enums & model ─────────────────────────────────────────────────────────────
enum VaultTriggerType { manual, ai, fall, drill }

enum VaultEventStatus { resolved, falsePositive, drill }

enum VaultTamperFilter { all, tamperedOnly, cleanOnly }

class VaultFilterEntry {
  final String sosId;
  final DateTime timestamp;
  final String locationLabel;
  final VaultTriggerType trigger;
  final VaultEventStatus status;
  final bool hasTamperFlag;
  final int streamCount;
  final int daysUntilExpiry;

  const VaultFilterEntry({
    required this.sosId,
    required this.timestamp,
    required this.locationLabel,
    required this.trigger,
    required this.status,
    required this.hasTamperFlag,
    required this.streamCount,
    required this.daysUntilExpiry,
  });

  String get triggerLabel => switch (trigger) {
        VaultTriggerType.manual => 'Manual',
        VaultTriggerType.ai => 'AI',
        VaultTriggerType.fall => 'Fall',
        VaultTriggerType.drill => 'Drill',
      };

  String get statusLabel => switch (status) {
        VaultEventStatus.resolved => 'Resolved',
        VaultEventStatus.falsePositive => 'False positive',
        VaultEventStatus.drill => 'Drill',
      };
}

List<VaultFilterEntry> _buildSeedEntries() {
  final now = DateTime.now();
  return [
    VaultFilterEntry(
      sosId: 'SOS-20260614-001',
      timestamp: now.subtract(const Duration(hours: 2)),
      locationLabel: 'Connaught Place, Delhi',
      trigger: VaultTriggerType.ai,
      status: VaultEventStatus.resolved,
      hasTamperFlag: false,
      streamCount: 6,
      daysUntilExpiry: 28,
    ),
    VaultFilterEntry(
      sosId: 'SOS-20260612-003',
      timestamp: now.subtract(const Duration(days: 2, hours: 5)),
      locationLabel: 'Lajpat Nagar, Delhi',
      trigger: VaultTriggerType.manual,
      status: VaultEventStatus.resolved,
      hasTamperFlag: true,
      streamCount: 6,
      daysUntilExpiry: 5,
    ),
    VaultFilterEntry(
      sosId: 'SOS-20260608-002',
      timestamp: now.subtract(const Duration(days: 6)),
      locationLabel: 'Saket, Delhi',
      trigger: VaultTriggerType.fall,
      status: VaultEventStatus.falsePositive,
      hasTamperFlag: false,
      streamCount: 5,
      daysUntilExpiry: 18,
    ),
    VaultFilterEntry(
      sosId: 'DRILL-20260605-001',
      timestamp: now.subtract(const Duration(days: 9)),
      locationLabel: 'Home · geohash reduced',
      trigger: VaultTriggerType.drill,
      status: VaultEventStatus.drill,
      hasTamperFlag: false,
      streamCount: 4,
      daysUntilExpiry: 30,
    ),
    VaultFilterEntry(
      sosId: 'SOS-20260528-004',
      timestamp: now.subtract(const Duration(days: 17)),
      locationLabel: 'Cyber Hub, Gurugram',
      trigger: VaultTriggerType.ai,
      status: VaultEventStatus.resolved,
      hasTamperFlag: false,
      streamCount: 6,
      daysUntilExpiry: 12,
    ),
    VaultFilterEntry(
      sosId: 'SOS-20260522-001',
      timestamp: now.subtract(const Duration(days: 23)),
      locationLabel: 'Koramangala, Bengaluru',
      trigger: VaultTriggerType.manual,
      status: VaultEventStatus.falsePositive,
      hasTamperFlag: false,
      streamCount: 6,
      daysUntilExpiry: 45,
    ),
    VaultFilterEntry(
      sosId: 'DRILL-20260515-002',
      timestamp: now.subtract(const Duration(days: 30)),
      locationLabel: 'Office · trusted location',
      trigger: VaultTriggerType.drill,
      status: VaultEventStatus.drill,
      hasTamperFlag: false,
      streamCount: 3,
      daysUntilExpiry: 60,
    ),
    VaultFilterEntry(
      sosId: 'SOS-20260510-007',
      timestamp: now.subtract(const Duration(days: 35)),
      locationLabel: 'Bandra West, Mumbai',
      trigger: VaultTriggerType.fall,
      status: VaultEventStatus.resolved,
      hasTamperFlag: true,
      streamCount: 6,
      daysUntilExpiry: 3,
    ),
    VaultFilterEntry(
      sosId: 'SOS-20260428-002',
      timestamp: now.subtract(const Duration(days: 47)),
      locationLabel: 'Indiranagar, Bengaluru',
      trigger: VaultTriggerType.ai,
      status: VaultEventStatus.resolved,
      hasTamperFlag: false,
      streamCount: 6,
      daysUntilExpiry: 7,
    ),
    VaultFilterEntry(
      sosId: 'SOS-20260415-001',
      timestamp: now.subtract(const Duration(days: 60)),
      locationLabel: 'Park Street, Kolkata',
      trigger: VaultTriggerType.manual,
      status: VaultEventStatus.resolved,
      hasTamperFlag: false,
      streamCount: 5,
      daysUntilExpiry: 90,
    ),
  ];
}

// ── Providers ─────────────────────────────────────────────────────────────────
final _d206TabProvider = StateProvider<int>((ref) => 0);
final _d206SearchProvider = StateProvider<String>((ref) => '');
final _d206DateStartProvider = StateProvider<DateTime?>((ref) => null);
final _d206DateEndProvider = StateProvider<DateTime?>((ref) => null);
final _d206TriggersProvider = StateProvider<Set<VaultTriggerType>>((ref) => {});
final _d206StatusesProvider = StateProvider<Set<VaultEventStatus>>((ref) => {});
final _d206TamperProvider = StateProvider<VaultTamperFilter>(
  (ref) => VaultTamperFilter.all,
);
final _d206ExpandedProvider = StateProvider<String?>((ref) => null);

const _kTabs = ['Vault List', 'Filters', 'Spec'];
final _kSeedEntries = _buildSeedEntries();

List<VaultFilterEntry> filterVaultEntries({
  required List<VaultFilterEntry> entries,
  required String query,
  DateTime? dateStart,
  DateTime? dateEnd,
  required Set<VaultTriggerType> triggers,
  required Set<VaultEventStatus> statuses,
  required VaultTamperFilter tamper,
}) {
  final q = query.trim().toLowerCase();

  bool inDateRange(DateTime ts) {
    if (dateStart != null) {
      final start = DateTime(dateStart.year, dateStart.month, dateStart.day);
      if (ts.isBefore(start)) return false;
    }
    if (dateEnd != null) {
      final end =
          DateTime(dateEnd.year, dateEnd.month, dateEnd.day, 23, 59, 59);
      if (ts.isAfter(end)) return false;
    }
    return true;
  }

  bool matchesSearch(VaultFilterEntry e) {
    if (q.isEmpty) return true;
    if (e.sosId.toLowerCase().contains(q)) return true;
    final formats = [
      DateFormat('dd/MM/yyyy').format(e.timestamp),
      DateFormat('dd/MM').format(e.timestamp),
      DateFormat('d MMM yyyy').format(e.timestamp),
      DateFormat('MMM d').format(e.timestamp).toLowerCase(),
    ];
    return formats.any((f) => f.toLowerCase().contains(q));
  }

  return entries.where((e) {
    if (!matchesSearch(e)) return false;
    if (!inDateRange(e.timestamp)) return false;
    if (triggers.isNotEmpty && !triggers.contains(e.trigger)) return false;
    if (statuses.isNotEmpty && !statuses.contains(e.status)) return false;
    switch (tamper) {
      case VaultTamperFilter.tamperedOnly:
        if (!e.hasTamperFlag) return false;
      case VaultTamperFilter.cleanOnly:
        if (e.hasTamperFlag) return false;
      case VaultTamperFilter.all:
        break;
    }
    return true;
  }).toList()
    ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
}

int _activeFilterCount(WidgetRef ref) {
  var count = 0;
  if (ref.read(_d206DateStartProvider) != null ||
      ref.read(_d206DateEndProvider) != null) {
    count++;
  }
  if (ref.read(_d206TriggersProvider).isNotEmpty) count++;
  if (ref.read(_d206StatusesProvider).isNotEmpty) count++;
  if (ref.read(_d206TamperProvider) != VaultTamperFilter.all) count++;
  return count;
}

void _clearFilters(WidgetRef ref) {
  ref.read(_d206SearchProvider.notifier).state = '';
  ref.read(_d206DateStartProvider.notifier).state = null;
  ref.read(_d206DateEndProvider.notifier).state = null;
  ref.read(_d206TriggersProvider.notifier).state = {};
  ref.read(_d206StatusesProvider.notifier).state = {};
  ref.read(_d206TamperProvider.notifier).state = VaultTamperFilter.all;
}

// ── Screen ────────────────────────────────────────────────────────────────────
class Day206VaultSearchFilterScreen extends ConsumerWidget {
  const Day206VaultSearchFilterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d206TabProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 206 · Vault Search'),
        actions: [
          if (_activeFilterCount(ref) > 0)
            Padding(
              padding: const EdgeInsets.only(right: ZapSpacing.md),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: ZapSpacing.sm, vertical: ZapSpacing.xs),
                  decoration: BoxDecoration(
                    color: ZapColors.info.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ZapColors.info.withOpacity(0.4)),
                  ),
                  child: Text(
                    '${_activeFilterCount(ref)} filters',
                    style: const TextStyle(
                      color: ZapColors.info,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
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
            onSelect: (i) => ref.read(_d206TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (tab) {
              0 => const _VaultListTab(),
              1 => const _FiltersTab(),
              _ => const _SpecTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Vault List ─────────────────────────────────────────────────────────
class _VaultListTab extends ConsumerWidget {
  const _VaultListTab();

  List<VaultFilterEntry> _filtered(WidgetRef ref) {
    return filterVaultEntries(
      entries: _kSeedEntries,
      query: ref.watch(_d206SearchProvider),
      dateStart: ref.watch(_d206DateStartProvider),
      dateEnd: ref.watch(_d206DateEndProvider),
      triggers: ref.watch(_d206TriggersProvider),
      statuses: ref.watch(_d206StatusesProvider),
      tamper: ref.watch(_d206TamperProvider),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtered = _filtered(ref);
    final expanded = ref.watch(_d206ExpandedProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            ZapSpacing.lg,
            ZapSpacing.lg,
            ZapSpacing.lg,
            ZapSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFF8B5CF6).withOpacity(0.35),
                  ),
                ),
                child: const Text(
                  '🟣 POLISH · Section A Day 6/20 · 10 mock vault entries',
                  style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 11),
                ),
              ),
              const SizedBox(height: ZapSpacing.md),
              const _VaultSearchField(),
              const SizedBox(height: ZapSpacing.sm),
              _ActiveFilterChips(),
              const SizedBox(height: ZapSpacing.sm),
              Text(
                '${filtered.length} of ${_kSeedEntries.length} entries',
                style: const TextStyle(
                  color: ZapColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? _EmptyFilterState(onClear: () => _clearFilters(ref))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ZapSpacing.lg,
                    vertical: ZapSpacing.sm,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final entry = filtered[i];
                    return _VaultEntryCard(
                      entry: entry,
                      expanded: expanded == entry.sosId,
                      onTap: () {
                        ref.read(_d206ExpandedProvider.notifier).state =
                            expanded == entry.sosId ? null : entry.sosId;
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _VaultSearchField extends ConsumerStatefulWidget {
  const _VaultSearchField();

  @override
  ConsumerState<_VaultSearchField> createState() => _VaultSearchFieldState();
}

class _VaultSearchFieldState extends ConsumerState<_VaultSearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ref.read(_d206SearchProvider));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(_d206SearchProvider);
    if (_controller.text != search) {
      _controller.text = search;
    }

    return Semantics(
      label: 'Search vault by SOS ID or date',
      textField: true,
      child: TextField(
        controller: _controller,
        onChanged: (v) => ref.read(_d206SearchProvider.notifier).state = v,
        style: const TextStyle(color: ZapColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search SOS ID or date (e.g. 14/06, SOS-2026)',
          hintStyle: const TextStyle(color: ZapColors.textMuted),
          prefixIcon:
              const Icon(Icons.search_rounded, color: ZapColors.textSecondary),
          suffixIcon: search.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded,
                      color: ZapColors.textMuted),
                  onPressed: () {
                    _controller.clear();
                    ref.read(_d206SearchProvider.notifier).state = '';
                  },
                )
              : null,
          filled: true,
          fillColor: ZapColors.bgCard,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            borderSide: const BorderSide(color: ZapColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            borderSide: const BorderSide(color: ZapColors.border),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: ZapSpacing.md,
            vertical: ZapSpacing.md,
          ),
        ),
      ),
    );
  }
}

class _ActiveFilterChips extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final start = ref.watch(_d206DateStartProvider);
    final end = ref.watch(_d206DateEndProvider);
    final triggers = ref.watch(_d206TriggersProvider);
    final statuses = ref.watch(_d206StatusesProvider);
    final tamper = ref.watch(_d206TamperProvider);

    final chips = <Widget>[];

    if (start != null || end != null) {
      final fmt = DateFormat('d MMM');
      final label = start != null && end != null
          ? '${fmt.format(start)} – ${fmt.format(end)}'
          : start != null
              ? 'From ${fmt.format(start)}'
              : 'Until ${fmt.format(end!)}';
      chips.add(_FilterChip(
        label: label,
        onRemove: () {
          ref.read(_d206DateStartProvider.notifier).state = null;
          ref.read(_d206DateEndProvider.notifier).state = null;
        },
      ));
    }

    for (final t in triggers) {
      chips.add(_FilterChip(
        label: t.name.toUpperCase(),
        onRemove: () {
          ref.read(_d206TriggersProvider.notifier).update((s) {
            final next = {...s}..remove(t);
            return next;
          });
        },
      ));
    }

    for (final s in statuses) {
      chips.add(_FilterChip(
        label: switch (s) {
          VaultEventStatus.resolved => 'Resolved',
          VaultEventStatus.falsePositive => 'FP',
          VaultEventStatus.drill => 'Drill',
        },
        onRemove: () {
          ref.read(_d206StatusesProvider.notifier).update((set) {
            final next = {...set}..remove(s);
            return next;
          });
        },
      ));
    }

    if (tamper != VaultTamperFilter.all) {
      chips.add(_FilterChip(
        label: tamper == VaultTamperFilter.tamperedOnly ? 'Tampered' : 'Clean',
        onRemove: () => ref.read(_d206TamperProvider.notifier).state =
            VaultTamperFilter.all,
      ));
    }

    if (chips.isEmpty) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'No filters active — use Filters tab',
          style: TextStyle(color: ZapColors.textMuted, fontSize: 11),
        ),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: chips,
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _FilterChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      deleteIcon: const Icon(Icons.close_rounded, size: 14),
      onDeleted: onRemove,
      backgroundColor: ZapColors.bgElevated,
      side: const BorderSide(color: ZapColors.border),
      labelStyle: const TextStyle(color: ZapColors.textPrimary),
    );
  }
}

class _VaultEntryCard extends StatelessWidget {
  final VaultFilterEntry entry;
  final bool expanded;
  final VoidCallback onTap;

  const _VaultEntryCard({
    required this.entry,
    required this.expanded,
    required this.onTap,
  });

  Color get _expiryColor => entry.daysUntilExpiry <= 3
      ? ZapColors.danger
      : entry.daysUntilExpiry <= 10
          ? ZapColors.warning
          : ZapColors.textMuted;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('dd MMM yyyy · HH:mm').format(entry.timestamp);

    return Semantics(
      label:
          '${entry.sosId}, ${entry.triggerLabel} trigger, ${entry.statusLabel}',
      button: true,
      expanded: expanded,
      child: Container(
        margin: const EdgeInsets.only(bottom: ZapSpacing.md),
        decoration: BoxDecoration(
          color: ZapColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: entry.hasTamperFlag
                ? ZapColors.danger.withOpacity(0.5)
                : ZapColors.border,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(ZapSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.sosId,
                          style: const TextStyle(
                            color: ZapColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                            fontSize: 13,
                          ),
                        ),
                      ),
                      _Badge(
                        label: entry.triggerLabel,
                        color: _triggerColor(entry.trigger),
                      ),
                      const SizedBox(width: 6),
                      _Badge(
                        label: entry.statusLabel,
                        color: _statusColor(entry.status),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    time,
                    style: const TextStyle(
                      color: ZapColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: ZapSpacing.xs),
                  Text(
                    entry.locationLabel,
                    style: const TextStyle(
                      color: ZapColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: ZapSpacing.sm),
                  Row(
                    children: [
                      Icon(Icons.folder_zip_rounded,
                          size: 14, color: _expiryColor),
                      const SizedBox(width: ZapSpacing.xs),
                      Text(
                        '${entry.streamCount} streams · expires in ${entry.daysUntilExpiry}d',
                        style: TextStyle(color: _expiryColor, fontSize: 11),
                      ),
                      if (entry.hasTamperFlag) ...[
                        const Spacer(),
                        const Icon(Icons.warning_amber_rounded,
                            size: 14, color: ZapColors.danger),
                        const SizedBox(width: ZapSpacing.xs),
                        const Text(
                          'Tamper flag',
                          style: TextStyle(
                            color: ZapColors.danger,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (expanded) ...[
                    const SizedBox(height: ZapSpacing.md),
                    const Divider(color: ZapColors.border, height: 1),
                    const SizedBox(height: ZapSpacing.sm),
                    const Text(
                      '6 forensic streams · SHA-256 verified · tap opens '
                      'Day 82 detail view in production.',
                      style: TextStyle(
                        color: ZapColors.textSecondary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Color _triggerColor(VaultTriggerType t) => switch (t) {
      VaultTriggerType.manual => ZapColors.info,
      VaultTriggerType.ai => ZapColors.danger,
      VaultTriggerType.fall => ZapColors.warning,
      VaultTriggerType.drill => const Color(0xFF8B5CF6),
    };

Color _statusColor(VaultEventStatus s) => switch (s) {
      VaultEventStatus.resolved => ZapColors.safe,
      VaultEventStatus.falsePositive => ZapColors.warning,
      VaultEventStatus.drill => const Color(0xFF8B5CF6),
    };

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyFilterState extends StatelessWidget {
  final VoidCallback onClear;

  const _EmptyFilterState({required this.onClear});

  @override
  Widget build(BuildContext context) {
    return ZapEmptyInline(
      title: 'No entries match — try a broader date range, fewer filter '
          'chips, or a different search term.',
      actionLabel: 'Clear all filters',
      onAction: onClear,
    );
  }
}

// ── Tab 1: Filters ────────────────────────────────────────────────────────────
class _FiltersTab extends ConsumerWidget {
  const _FiltersTab();

  Future<void> _pickDateRange(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: ref.read(_d206DateStartProvider) ??
            now.subtract(const Duration(days: 30)),
        end: ref.read(_d206DateEndProvider) ?? now,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: ZapColors.safe,
              surface: ZapColors.bgCard,
            ),
          ),
          child: child!,
        );
      },
    );
    if (range == null) return;
    ref.read(_d206DateStartProvider.notifier).state = range.start;
    ref.read(_d206DateEndProvider.notifier).state = range.end;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final start = ref.watch(_d206DateStartProvider);
    final end = ref.watch(_d206DateEndProvider);
    final triggers = ref.watch(_d206TriggersProvider);
    final statuses = ref.watch(_d206StatusesProvider);
    final tamper = ref.watch(_d206TamperProvider);
    final filtered = filterVaultEntries(
      entries: _kSeedEntries,
      query: ref.watch(_d206SearchProvider),
      dateStart: start,
      dateEnd: end,
      triggers: triggers,
      statuses: statuses,
      tamper: tamper,
    );

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        _FilterSection(
          title: 'Date range',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                label: 'Pick date range',
                button: true,
                child: OutlinedButton.icon(
                  onPressed: () => _pickDateRange(context, ref),
                  icon: const Icon(Icons.date_range_rounded, size: 18),
                  label: Text(
                    start != null && end != null
                        ? '${DateFormat('d MMM').format(start)} – ${DateFormat('d MMM yyyy').format(end)}'
                        : 'Select date range',
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 75),
                  ),
                ),
              ),
              if (start != null || end != null)
                TextButton(
                  onPressed: () {
                    ref.read(_d206DateStartProvider.notifier).state = null;
                    ref.read(_d206DateEndProvider.notifier).state = null;
                  },
                  child: const Text('Clear dates'),
                ),
            ],
          ),
        ),
        _FilterSection(
          title: 'Trigger type',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: VaultTriggerType.values.map((t) {
              final selected = triggers.contains(t);
              return FilterChip(
                label: Text(t.name.toUpperCase()),
                selected: selected,
                onSelected: (v) {
                  ref.read(_d206TriggersProvider.notifier).update((s) {
                    final next = {...s};
                    if (v) {
                      next.add(t);
                    } else {
                      next.remove(t);
                    }
                    return next;
                  });
                },
                selectedColor: _triggerColor(t).withOpacity(0.2),
                checkmarkColor: _triggerColor(t),
              );
            }).toList(),
          ),
        ),
        _FilterSection(
          title: 'Status',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusChip(
                label: 'Resolved',
                status: VaultEventStatus.resolved,
                selected: statuses.contains(VaultEventStatus.resolved),
                ref: ref,
              ),
              _StatusChip(
                label: 'False positive',
                status: VaultEventStatus.falsePositive,
                selected: statuses.contains(VaultEventStatus.falsePositive),
                ref: ref,
              ),
              _StatusChip(
                label: 'Drill',
                status: VaultEventStatus.drill,
                selected: statuses.contains(VaultEventStatus.drill),
                ref: ref,
              ),
            ],
          ),
        ),
        _FilterSection(
          title: 'Tamper flag',
          child: SegmentedButton<VaultTamperFilter>(
            segments: const [
              ButtonSegment(
                value: VaultTamperFilter.all,
                label: Text('All', style: TextStyle(fontSize: 11)),
              ),
              ButtonSegment(
                value: VaultTamperFilter.tamperedOnly,
                label: Text('Tampered', style: TextStyle(fontSize: 11)),
              ),
              ButtonSegment(
                value: VaultTamperFilter.cleanOnly,
                label: Text('Clean', style: TextStyle(fontSize: 11)),
              ),
            ],
            selected: {tamper},
            onSelectionChanged: (s) =>
                ref.read(_d206TamperProvider.notifier).state = s.first,
            style: ButtonStyle(
              minimumSize: MaterialStateProperty.all(const Size(0, 48)),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.safe.withOpacity(0.08),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: ZapColors.safe.withOpacity(0.3)),
          ),
          child: Text(
            'Preview: ${filtered.length} matching entries',
            style: const TextStyle(
              color: ZapColors.safe,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.xl),
        Semantics(
          label: 'Clear all filters',
          button: true,
          child: OutlinedButton(
            onPressed: () => _clearFilters(ref),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 75),
            ),
            child: const Text('Clear all filters'),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Semantics(
          label: 'Apply quick demo filter tampered only',
          button: true,
          child: FilledButton(
            onPressed: () {
              ref.read(_d206TamperProvider.notifier).state =
                  VaultTamperFilter.tamperedOnly;
              ref.read(_d206TriggersProvider.notifier).state = {};
              ref.read(_d206StatusesProvider.notifier).state = {};
            },
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 75),
              backgroundColor: ZapColors.danger.withOpacity(0.15),
              foregroundColor: ZapColors.danger,
            ),
            child: const Text('Demo: tampered entries only'),
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final VaultEventStatus status;
  final bool selected;
  final WidgetRef ref;

  const _StatusChip({
    required this.label,
    required this.status,
    required this.selected,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (v) {
        ref.read(_d206StatusesProvider.notifier).update((s) {
          final next = {...s};
          if (v) {
            next.add(status);
          } else {
            next.remove(status);
          }
          return next;
        });
      },
      selectedColor: color.withOpacity(0.2),
      checkmarkColor: color,
    );
  }
}

class _FilterSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _FilterSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: ZapSpacing.lg),
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: ZapColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: ZapSpacing.md),
          child,
        ],
      ),
    );
  }
}

// ── Tab 2: Spec ───────────────────────────────────────────────────────────────
class _SpecTab extends StatelessWidget {
  const _SpecTab();

  @override
  Widget build(BuildContext context) {
    const rows = [
      ('Search', 'SOS ID substring or date (dd/MM, d MMM yyyy)'),
      ('Date range', 'showDateRangePicker · inclusive end-of-day'),
      ('Trigger', 'Manual · AI · Fall · Drill — multi-select chips'),
      ('Status', 'Resolved · False positive · Drill'),
      ('Tamper', 'All / Tampered only / Clean only'),
      ('Empty state', 'Clear filters CTA when zero matches'),
      ('Mock data', '10 seed entries spanning 60 days'),
      ('Integration', 'Add to Day 82 _VaultBrowser app bar'),
    ];

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text(
          'Evidence Vault search & filter (Day 206 polish)',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        ...rows.map(
          (r) => Container(
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(color: ZapColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.$1,
                  style: const TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: ZapSpacing.xs),
                Text(
                  r.$2,
                  style: const TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Semantics(
          label: 'Copy filter function signature',
          button: true,
          child: OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(
                const ClipboardData(
                  text:
                      'filterVaultEntries(entries, query, dateStart, dateEnd, triggers, statuses, tamper)',
                ),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Signature copied')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy filter signature'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 75),
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.info.withOpacity(0.1),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: ZapColors.info.withOpacity(0.3)),
          ),
          child: const Text(
            'Tomorrow: Day 208 — Design system compliance audit.',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
        ),
      ],
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
                        color: selected
                            ? const Color(0xFF8B5CF6)
                            : Colors.transparent,
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
                      fontSize: 12,
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
