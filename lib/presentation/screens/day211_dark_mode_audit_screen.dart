/// Day 211 — Dark Mode Consistency Audit
///
/// Section A (Days 201-220): manual tracker for auditing screens against
/// OLED dark theme tokens (bgPrimary, bgCard, textPrimary, etc.).
///
/// Tag: 🟢 FRONTEND-ONLY — QA meta-screen, not an automatic scan score.
///
/// Route: [AppRoutes.darkModeAudit] → `/dark-mode-audit`
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';

// ── Models ────────────────────────────────────────────────────────────────────
enum DarkAuditStatus { unchecked, pass, warn, fail }

class DarkAuditEntry {
  final String id;
  final String name;
  final String route;
  final String dayLabel;

  const DarkAuditEntry({
    required this.id,
    required this.name,
    required this.route,
    required this.dayLabel,
  });
}

class DarkAuditSection {
  final String phase;
  final String title;
  final String dayRange;
  final Color accent;
  final List<DarkAuditEntry> entries;

  const DarkAuditSection({
    required this.phase,
    required this.title,
    required this.dayRange,
    required this.accent,
    required this.entries,
  });
}

const _kSections = [
  DarkAuditSection(
    phase: 'A',
    title: 'Foundation',
    dayRange: 'Days 1–40',
    accent: ZapColors.safe,
    entries: [
      DarkAuditEntry(
          id: 'd4',
          name: 'Widgets Showcase',
          route: '/day4',
          dayLabel: 'Day 4'),
      DarkAuditEntry(
          id: 'd5', name: 'Navigation Index', route: '/', dayLabel: 'Day 5'),
      DarkAuditEntry(
          id: 'd6', name: 'Auth Foundation', route: '/day6', dayLabel: 'Day 6'),
      DarkAuditEntry(
          id: 'd11',
          name: 'Permissions',
          route: '/permissions',
          dayLabel: 'Day 11'),
      DarkAuditEntry(
          id: 'd20',
          name: 'Month 1 Review',
          route: '/month1-review',
          dayLabel: 'Day 20'),
      DarkAuditEntry(
          id: 'd37',
          name: 'GPS Service',
          route: '/gps-service',
          dayLabel: 'Day 37'),
      DarkAuditEntry(
          id: 'd39',
          name: 'State Wiring',
          route: '/state-wiring',
          dayLabel: 'Day 39'),
      DarkAuditEntry(
          id: 'dash',
          name: 'Dashboard',
          route: '/dashboard',
          dayLabel: 'Day 46'),
    ],
  ),
  DarkAuditSection(
    phase: 'B',
    title: 'Core Features',
    dayRange: 'Days 41–100',
    accent: ZapColors.info,
    entries: [
      DarkAuditEntry(
          id: 'd41',
          name: 'Onboarding Step 1',
          route: '/onboarding/step1',
          dayLabel: 'Day 41'),
      DarkAuditEntry(
          id: 'd51',
          name: 'Offline Status',
          route: '/offline-status',
          dayLabel: 'Day 51'),
      DarkAuditEntry(
          id: 'd59',
          name: 'Protection Score',
          route: '/protection-score',
          dayLabel: 'Day 59'),
      DarkAuditEntry(
          id: 'd68',
          name: 'Audit Log',
          route: '/audit-log-v2',
          dayLabel: 'Day 68'),
      DarkAuditEntry(
          id: 'd76',
          name: 'SOS Active',
          route: '/sos-active',
          dayLabel: 'Day 76'),
      DarkAuditEntry(
          id: 'd82',
          name: 'Evidence Vault',
          route: '/evidence-vault',
          dayLabel: 'Day 82'),
      DarkAuditEntry(
          id: 'd83',
          name: 'Contacts v2',
          route: '/contacts-v2',
          dayLabel: 'Day 83'),
      DarkAuditEntry(
          id: 'd97',
          name: 'Accessibility',
          route: '/accessibility-settings',
          dayLabel: 'Day 97'),
    ],
  ),
  DarkAuditSection(
    phase: 'C',
    title: 'Beta & AWS',
    dayRange: 'Days 101–150',
    accent: ZapColors.warning,
    entries: [
      DarkAuditEntry(
          id: 'd104',
          name: 'Onboarding i18n',
          route: '/onboarding-i18n',
          dayLabel: 'Day 104'),
      DarkAuditEntry(
          id: 'd112',
          name: 'Beta Onboarding',
          route: '/beta-onboarding',
          dayLabel: 'Day 112'),
      DarkAuditEntry(
          id: 'd120',
          name: 'Beta Launch',
          route: '/beta-launch',
          dayLabel: 'Day 120'),
      DarkAuditEntry(
          id: 'd133',
          name: 'Onboarding Simplify',
          route: '/onboarding-simplify',
          dayLabel: 'Day 133'),
      DarkAuditEntry(
          id: 'd138',
          name: 'Final Polish',
          route: '/final-polish',
          dayLabel: 'Day 138'),
      DarkAuditEntry(
          id: 'd147',
          name: 'AWS Test',
          route: '/aws-test',
          dayLabel: 'Day 147'),
      DarkAuditEntry(
          id: 'd149',
          name: 'Regression Test',
          route: '/regression-test',
          dayLabel: 'Day 149'),
      DarkAuditEntry(
          id: 'd150',
          name: 'Production Release',
          route: '/production-release',
          dayLabel: 'Day 150'),
    ],
  ),
  DarkAuditSection(
    phase: 'D',
    title: 'Launch Prep',
    dayRange: 'Days 151–200',
    accent: ZapColors.danger,
    entries: [
      DarkAuditEntry(
          id: 'd166',
          name: 'Data Export Request',
          route: '/data-export-request',
          dayLabel: 'Day 166'),
      DarkAuditEntry(
          id: 'd176',
          name: 'Data Retention',
          route: '/data-retention-settings',
          dayLabel: 'Day 176'),
      DarkAuditEntry(
          id: 'd183',
          name: 'Biometric Lock',
          route: '/biometric-lock',
          dayLabel: 'Day 183'),
      DarkAuditEntry(
          id: 'd191',
          name: 'Screenshots',
          route: '/screenshots',
          dayLabel: 'Day 191'),
      DarkAuditEntry(
          id: 'd197',
          name: 'Release Checklist',
          route: '/release-checklist',
          dayLabel: 'Day 197'),
      DarkAuditEntry(
          id: 'd199',
          name: 'Final Submission',
          route: '/final-submission',
          dayLabel: 'Day 199'),
      DarkAuditEntry(
          id: 'd200',
          name: 'Grand Finale',
          route: '/grand-finale',
          dayLabel: 'Day 200'),
      DarkAuditEntry(
          id: 'd201',
          name: 'Device QA Harness',
          route: '/device-qa-harness',
          dayLabel: 'Day 201'),
    ],
  ),
];

List<DarkAuditEntry> get _allEntries =>
    _kSections.expand((s) => s.entries).toList();

Map<String, DarkAuditStatus> _initialStatuses() => {
      for (final e in _allEntries) e.id: DarkAuditStatus.unchecked,
    };

// ── Providers ─────────────────────────────────────────────────────────────────
final _d211TabProvider = StateProvider<int>((ref) => 0);
final _d211StatusProvider = StateProvider<Map<String, DarkAuditStatus>>(
  (ref) => _initialStatuses(),
);
final _d211NotesProvider = StateProvider<Map<String, String>>((ref) => {});
final _d211ExpandedProvider = StateProvider<Set<String>>((ref) => {});
final _d211FilterProvider = StateProvider<DarkAuditStatus?>(
  (ref) => null,
);
final _d211SectionOpenProvider = StateProvider<Set<String>>(
  (ref) => {'A', 'B', 'C', 'D'},
);

const _kTabs = ['Checklist', 'Theme Tokens', 'Export'];

// ── Screen ────────────────────────────────────────────────────────────────────
class Day211DarkModeAuditScreen extends ConsumerWidget {
  const Day211DarkModeAuditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d211TabProvider);
    final statuses = ref.watch(_d211StatusProvider);
    final pass = statuses.values.where((s) => s == DarkAuditStatus.pass).length;
    final total = _allEntries.length;

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 211 · Dark Mode Audit'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Text(
                '$pass/$total',
                style: TextStyle(
                  color:
                      pass == total ? ZapColors.safe : ZapColors.textSecondary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
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
            onSelect: (i) => ref.read(_d211TabProvider.notifier).state = i,
          ),
          if (tab == 0) _ProgressHeader(statuses: statuses),
          Expanded(
            child: switch (tab) {
              0 => const _ChecklistTab(),
              1 => const _ThemeTokensTab(),
              _ => _ExportTab(statuses: statuses),
            },
          ),
        ],
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  final Map<String, DarkAuditStatus> statuses;

  const _ProgressHeader({required this.statuses});

  @override
  Widget build(BuildContext context) {
    final pass = statuses.values.where((s) => s == DarkAuditStatus.pass).length;
    final warn = statuses.values.where((s) => s == DarkAuditStatus.warn).length;
    final fail = statuses.values.where((s) => s == DarkAuditStatus.fail).length;
    final total = _allEntries.length;
    final done = pass + warn + fail;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        ZapSpacing.lg,
        ZapSpacing.sm,
        ZapSpacing.lg,
        ZapSpacing.md,
      ),
      color: ZapColors.bgCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CountChip(label: 'Pass', count: pass, color: ZapColors.safe),
              const SizedBox(width: 6),
              _CountChip(label: 'Warn', count: warn, color: ZapColors.warning),
              const SizedBox(width: 6),
              _CountChip(label: 'Fail', count: fail, color: ZapColors.danger),
              const Spacer(),
              Text(
                '$done / $total reviewed',
                style:
                    const TextStyle(color: ZapColors.textMuted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total > 0 ? pass / total : 0,
              minHeight: 6,
              backgroundColor: ZapColors.bgElevated,
              color: ZapColors.safe,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _CountChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        '$label $count',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Tab 0: Checklist ──────────────────────────────────────────────────────────
class _ChecklistTab extends ConsumerWidget {
  const _ChecklistTab();

  void _cycleStatus(WidgetRef ref, String id) {
    ref.read(_d211StatusProvider.notifier).update((map) {
      final current = map[id] ?? DarkAuditStatus.unchecked;
      final next = switch (current) {
        DarkAuditStatus.unchecked => DarkAuditStatus.pass,
        DarkAuditStatus.pass => DarkAuditStatus.warn,
        DarkAuditStatus.warn => DarkAuditStatus.fail,
        DarkAuditStatus.fail => DarkAuditStatus.unchecked,
      };
      return {...map, id: next};
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statuses = ref.watch(_d211StatusProvider);
    final notes = ref.watch(_d211NotesProvider);
    final expanded = ref.watch(_d211ExpandedProvider);
    final filter = ref.watch(_d211FilterProvider);
    final openSections = ref.watch(_d211SectionOpenProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: ZapColors.bgSurface.withOpacity(0.8),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: ZapColors.border),
          ),
          child: const Text(
            '🟢 FRONTEND-ONLY · Section A Day 11/20 · Manual dark-theme QA tracker',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        const Text(
          'Tap status icon to cycle: — → ✅ → ⚠️ → ❌. '
          'Expand a row to add notes. Sample of 32 key screens across 4 phases.',
          style: TextStyle(color: ZapColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: ZapSpacing.md),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(
                label: 'All',
                selected: filter == null,
                onTap: () =>
                    ref.read(_d211FilterProvider.notifier).state = null,
              ),
              ...DarkAuditStatus.values.map(
                (s) => _FilterChip(
                  label: _statusLabel(s),
                  selected: filter == s,
                  color: _statusColor(s),
                  onTap: () => ref.read(_d211FilterProvider.notifier).state = s,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        ..._kSections.map((section) {
          final entries = section.entries.where((e) {
            if (filter == null) return true;
            return statuses[e.id] == filter;
          }).toList();
          if (entries.isEmpty && filter != null) return const SizedBox.shrink();

          final isOpen = openSections.contains(section.phase);
          final sectionPass = section.entries
              .where((e) => statuses[e.id] == DarkAuditStatus.pass)
              .length;

          return Container(
            margin: const EdgeInsets.only(bottom: ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.circular(ZapSpacing.radius),
              border: Border.all(color: section.accent.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Semantics(
                  label: 'Section ${section.phase} ${section.title}',
                  button: true,
                  expanded: isOpen,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: section.accent.withOpacity(0.15),
                      child: Text(
                        section.phase,
                        style: TextStyle(
                          color: section.accent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    title: Text(
                      '${section.title} · ${section.dayRange}',
                      style: const TextStyle(
                        color: ZapColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Text(
                      '$sectionPass/${section.entries.length} pass',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: Icon(
                      isOpen
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                    ),
                    onTap: () {
                      ref.read(_d211SectionOpenProvider.notifier).update((s) {
                        final next = {...s};
                        if (isOpen) {
                          next.remove(section.phase);
                        } else {
                          next.add(section.phase);
                        }
                        return next;
                      });
                    },
                  ),
                ),
                if (isOpen)
                  ...entries.map(
                    (e) => _ScreenRow(
                      entry: e,
                      status: statuses[e.id] ?? DarkAuditStatus.unchecked,
                      note: notes[e.id] ?? '',
                      expanded: expanded.contains(e.id),
                      onToggleExpand: () {
                        ref.read(_d211ExpandedProvider.notifier).update((s) {
                          final next = {...s};
                          if (next.contains(e.id)) {
                            next.remove(e.id);
                          } else {
                            next.add(e.id);
                          }
                          return next;
                        });
                      },
                      onCycleStatus: () => _cycleStatus(ref, e.id),
                      onNoteChanged: (v) {
                        ref.read(_d211NotesProvider.notifier).update(
                              (m) => {...m, e.id: v},
                            );
                      },
                    ),
                  ),
              ],
            ),
          );
        }),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  ref.read(_d211StatusProvider.notifier).state = {
                    for (final e in _allEntries) e.id: DarkAuditStatus.pass,
                  };
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 75),
                ),
                child: const Text('Mark all pass'),
              ),
            ),
            const SizedBox(width: ZapSpacing.md),
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  ref.read(_d211StatusProvider.notifier).state =
                      _initialStatuses();
                  ref.read(_d211NotesProvider.notifier).state = {};
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 75),
                ),
                child: const Text('Reset all'),
              ),
            ),
          ],
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
            'Tomorrow: Day 213 — Animation polish pass (SOS breathe, mode badge morph).',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? ZapColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 11)),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: c.withOpacity(0.2),
        checkmarkColor: c,
      ),
    );
  }
}

class _ScreenRow extends StatelessWidget {
  final DarkAuditEntry entry;
  final DarkAuditStatus status;
  final String note;
  final bool expanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onCycleStatus;
  final ValueChanged<String> onNoteChanged;

  const _ScreenRow({
    required this.entry,
    required this.status,
    required this.note,
    required this.expanded,
    required this.onToggleExpand,
    required this.onCycleStatus,
    required this.onNoteChanged,
  });

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);

    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: ZapColors.border)),
      ),
      child: Column(
        children: [
          ListTile(
            dense: true,
            leading: Semantics(
              label: 'Status ${_statusLabel(status)}. Tap to change.',
              button: true,
              child: GestureDetector(
                onTap: onCycleStatus,
                child: Text(
                  _statusEmoji(status),
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
            title: Text(
              entry.name,
              style: const TextStyle(
                color: ZapColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            subtitle: Text(
              '${entry.dayLabel} · ${entry.route}',
              style: TextStyle(
                color: color == ZapColors.textMuted
                    ? ZapColors.textMuted
                    : color.withOpacity(0.85),
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
            trailing: IconButton(
              icon: Icon(
                expanded ? Icons.expand_less : Icons.notes_rounded,
                size: 20,
                color: ZapColors.textMuted,
              ),
              onPressed: onToggleExpand,
            ),
          ),
          if (expanded)
            _NoteField(
              initialNote: note,
              onChanged: onNoteChanged,
            ),
        ],
      ),
    );
  }
}

class _NoteField extends StatefulWidget {
  final String initialNote;
  final ValueChanged<String> onChanged;

  const _NoteField({
    required this.initialNote,
    required this.onChanged,
  });

  @override
  State<_NoteField> createState() => _NoteFieldState();
}

class _NoteFieldState extends State<_NoteField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNote);
  }

  @override
  void didUpdateWidget(covariant _NoteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialNote != oldWidget.initialNote &&
        widget.initialNote != _controller.text) {
      _controller.text = widget.initialNote;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ZapSpacing.lg,
        0,
        ZapSpacing.lg,
        ZapSpacing.md,
      ),
      child: TextField(
        controller: _controller,
        onChanged: widget.onChanged,
        style: const TextStyle(color: ZapColors.textPrimary, fontSize: 12),
        maxLines: 2,
        decoration: InputDecoration(
          hintText: 'Notes — e.g. white flash on cold start',
          hintStyle: const TextStyle(color: ZapColors.textMuted),
          filled: true,
          fillColor: ZapColors.bgElevated,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            borderSide: const BorderSide(color: ZapColors.border),
          ),
          contentPadding: const EdgeInsets.all(ZapSpacing.sm),
        ),
      ),
    );
  }
}

String _statusEmoji(DarkAuditStatus s) => switch (s) {
      DarkAuditStatus.pass => '✅',
      DarkAuditStatus.warn => '⚠️',
      DarkAuditStatus.fail => '❌',
      DarkAuditStatus.unchecked => '—',
    };

String _statusLabel(DarkAuditStatus s) => switch (s) {
      DarkAuditStatus.pass => 'Pass',
      DarkAuditStatus.warn => 'Warn',
      DarkAuditStatus.fail => 'Fail',
      DarkAuditStatus.unchecked => 'Open',
    };

Color _statusColor(DarkAuditStatus s) => switch (s) {
      DarkAuditStatus.pass => ZapColors.safe,
      DarkAuditStatus.warn => ZapColors.warning,
      DarkAuditStatus.fail => ZapColors.danger,
      DarkAuditStatus.unchecked => ZapColors.textMuted,
    };

// ── Tab 1: Theme Tokens ───────────────────────────────────────────────────────
class _ThemeTokensTab extends StatelessWidget {
  const _ThemeTokensTab();

  @override
  Widget build(BuildContext context) {
    const tokens = [
      ('bgPrimary', '#07070E', ZapColors.bgPrimary, 'Scaffold background'),
      ('bgCard', '#0D0D16', ZapColors.bgCard, 'Cards, list tiles'),
      ('bgSurface', '#16161F', ZapColors.bgSurface, 'Nested surfaces'),
      ('bgElevated', '#1D1D2B', ZapColors.bgElevated, 'Elevated panels'),
      ('textPrimary', '#E0E0EE', ZapColors.textPrimary, 'Headings, body'),
      ('textSecondary', '#6E6E82', ZapColors.textSecondary, 'Hints, subtitles'),
      ('textMuted', '#4A4A5E', ZapColors.textMuted, 'Disabled, timestamps'),
      ('border', '#2A2A35', ZapColors.border, 'Card borders, dividers'),
    ];

    const checks = [
      'Scaffold uses ZapColors.bgPrimary — not Colors.black',
      'Cards use bgCard — not white or grey[900]',
      'Text uses textPrimary / textSecondary — not Colors.white',
      'No light-theme Material defaults leaking through',
      'High contrast mode uses hcBackground / hcText when enabled',
      'Status bar / nav bar icon brightness: light icons on dark bg',
    ];

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text(
          'OLED dark theme tokens',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          'lib/core/theme/colors.dart — every screen should use these.',
          style: TextStyle(color: ZapColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: ZapSpacing.lg),
        ...tokens.map((t) {
          final (name, hex, color, usage) = t;
          return Container(
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(color: ZapColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                    border: Border.all(color: ZapColors.border),
                  ),
                ),
                const SizedBox(width: ZapSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ZapColors.$name',
                        style: const TextStyle(
                          color: ZapColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        hex,
                        style: const TextStyle(
                          color: ZapColors.textMuted,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                      Text(
                        usage,
                        style: const TextStyle(
                          color: ZapColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Audit checklist',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        ...checks.map(
          (c) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_box_outline_blank_rounded,
                    size: 16, color: ZapColors.textMuted),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    c,
                    style: const TextStyle(
                      color: ZapColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Tab 2: Export ─────────────────────────────────────────────────────────────
class _ExportTab extends ConsumerWidget {
  final Map<String, DarkAuditStatus> statuses;

  const _ExportTab({required this.statuses});

  String _buildSummary(WidgetRef ref) {
    final notes = ref.read(_d211NotesProvider);
    final pass = statuses.values.where((s) => s == DarkAuditStatus.pass).length;
    final warn = statuses.values.where((s) => s == DarkAuditStatus.warn).length;
    final fail = statuses.values.where((s) => s == DarkAuditStatus.fail).length;
    final open =
        statuses.values.where((s) => s == DarkAuditStatus.unchecked).length;

    final buf = StringBuffer()
      ..writeln('ZapSafe Dark Mode Audit Summary')
      ..writeln('Screens sampled: ${_allEntries.length} across 4 phases')
      ..writeln('Pass: $pass | Warn: $warn | Fail: $fail | Open: $open')
      ..writeln('---');

    for (final section in _kSections) {
      buf.writeln(
          '[Phase ${section.phase}] ${section.title} (${section.dayRange})');
      for (final e in section.entries) {
        final st = statuses[e.id] ?? DarkAuditStatus.unchecked;
        final tag = switch (st) {
          DarkAuditStatus.pass => 'PASS',
          DarkAuditStatus.warn => 'WARN',
          DarkAuditStatus.fail => 'FAIL',
          DarkAuditStatus.unchecked => 'OPEN',
        };
        final note = notes[e.id];
        buf.write('[$tag] ${e.dayLabel} ${e.name} ${e.route}');
        if (note != null && note.trim().isNotEmpty) {
          buf.write(' — ${note.trim()}');
        }
        buf.writeln();
      }
      buf.writeln();
    }

    return buf.toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = _buildSummary(ref);
    final pass = statuses.values.where((s) => s == DarkAuditStatus.pass).length;
    final fail = statuses.values.where((s) => s == DarkAuditStatus.fail).length;

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.all(ZapSpacing.lg),
          decoration: BoxDecoration(
            color: fail > 0
                ? ZapColors.danger.withOpacity(0.08)
                : pass == _allEntries.length
                    ? ZapColors.safe.withOpacity(0.08)
                    : ZapColors.bgCard,
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(
              color: fail > 0
                  ? ZapColors.danger.withOpacity(0.35)
                  : pass == _allEntries.length
                      ? ZapColors.safe.withOpacity(0.35)
                      : ZapColors.border,
            ),
          ),
          child: Column(
            children: [
              Icon(
                fail > 0
                    ? Icons.warning_amber_rounded
                    : pass == _allEntries.length
                        ? Icons.verified_rounded
                        : Icons.summarize_rounded,
                color: fail > 0
                    ? ZapColors.danger
                    : pass == _allEntries.length
                        ? ZapColors.safe
                        : ZapColors.info,
                size: 40,
              ),
              const SizedBox(height: ZapSpacing.sm),
              Text(
                fail > 0
                    ? '$fail screen(s) need dark-mode fixes'
                    : pass == _allEntries.length
                        ? 'All sampled screens pass'
                        : 'Audit in progress',
                style: const TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Export preview',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w600,
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
          child: Text(
            summary,
            style: const TextStyle(
              color: ZapColors.textSecondary,
              fontSize: 11,
              fontFamily: 'monospace',
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.xl),
        Semantics(
          label: 'Copy audit summary to clipboard',
          button: true,
          child: FilledButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: summary));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Audit summary copied')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy audit summary'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 75),
              backgroundColor: ZapColors.safe,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Semantics(
          label: 'Copy CSV format',
          button: true,
          child: OutlinedButton.icon(
            onPressed: () {
              final notes = ref.read(_d211NotesProvider);
              final lines = <String>[
                'phase,day,name,route,status,notes',
              ];
              for (final section in _kSections) {
                for (final e in section.entries) {
                  final st = statuses[e.id] ?? DarkAuditStatus.unchecked;
                  final note = (notes[e.id] ?? '').replaceAll(',', ';');
                  lines.add(
                    '${section.phase},${e.dayLabel},"${e.name}",${e.route},'
                    '${_statusLabel(st)},"$note"',
                  );
                }
              }
              Clipboard.setData(ClipboardData(text: lines.join('\n')));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('CSV copied')),
              );
            },
            icon: const Icon(Icons.table_rows_rounded, size: 18),
            label: const Text('Copy as CSV'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 75),
            ),
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
                            ? ZapColors.textPrimary
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
