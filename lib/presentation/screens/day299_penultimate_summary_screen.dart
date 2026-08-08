/// Day 299 — Penultimate Summary
///
/// Section E (Days 281-300): stats since Day 200 — new screens, polish count,
/// section progress, and open launch blockers one day before Day 300.
///
/// Tag: 🟢 FRONTEND-ONLY · retrospective dashboard · mock aggregates.
///
/// Route: [AppRoutes.penultimateSummary] → `/penultimate-summary`
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const _kAccent = Color(0xFF0EA5E9);
const _kTabs = ['Summary', 'Stats', 'Info'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');
const _kSinceDay = 200;
const _kCurrentDay = 299;
const _kNewDaysSince200 = _kCurrentDay - _kSinceDay; // 99

enum _BlockerSeverity { red, yellow, green }

class _SectionProgress {
  const _SectionProgress({
    required this.label,
    required this.range,
    required this.daysBuilt,
    required this.daysTotal,
    required this.color,
    required this.highlight,
  });

  final String label;
  final String range;
  final int daysBuilt;
  final int daysTotal;
  final Color color;
  final String highlight;
}

class _OpenBlocker {
  const _OpenBlocker({
    required this.id,
    required this.title,
    required this.detail,
    required this.severity,
    required this.dayRef,
    this.route,
  });

  final String id;
  final String title;
  final String detail;
  final _BlockerSeverity severity;
  final String dayRef;
  final String? route;
}

const _kSections = [
  _SectionProgress(
    label: 'Catch-up · Section B',
    range: 'Days 221-240',
    daysBuilt: 20,
    daysTotal: 20,
    color: Color(0xFF3B82F6),
    highlight: 'Police · referral · stealth LP24 · India prep',
  ),
  _SectionProgress(
    label: 'Advanced · Section C',
    range: 'Days 241-260',
    daysBuilt: 20,
    daysTotal: 20,
    color: Color(0xFF10B981),
    highlight: 'Group journey · widgets · voice · phone-only milestone',
  ),
  _SectionProgress(
    label: 'i18n & growth · Section D',
    range: 'Days 261-280',
    daysBuilt: 20,
    daysTotal: 20,
    color: Color(0xFF8B5CF6),
    highlight: '7 language packs · enterprise · production dashboard',
  ),
  _SectionProgress(
    label: 'Launch prep · Section E',
    range: 'Days 281-300',
    daysBuilt: 19,
    daysTotal: 20,
    color: Color(0xFFF59E0B),
    highlight: 'Marketing · QA gates · go/no-go · penultimate today',
  ),
];

const _kStats = [
  ('99', 'New days since 200', Color(0xFF0EA5E9)),
  ('299', 'Screens catalogued', Color(0xFF3B82F6)),
  ('18', 'Polish screens', Color(0xFF8B5CF6)),
  ('7', 'Language packs', Color(0xFF10B981)),
  ('20', 'Section E scope', Color(0xFFF59E0B)),
  ('4', 'Open blockers', Color(0xFFEF4444)),
  ('22', 'Go/No-Go items', Color(0xFFDC2626)),
  ('65', 'Phase 2 days planned', Color(0xFF7C3AED)),
];

const _kMilestones = [
  (200, 'Day 200', 'Grand finale · 4 sections A-D complete'),
  (240, 'Day 240', 'Section B catch-up milestone'),
  (260, 'Day 260', 'Advanced features · phone-only'),
  (280, 'Day 280', 'Section D · i18n expansion complete'),
  (299, 'Day 299', 'Penultimate summary · you are here'),
  (300, 'Day 300', 'Halfway to global launch · tomorrow'),
];

const _kOpenBlockers = [
  _OpenBlocker(
    id: 'legal_dlt',
    title: 'MSG91 DLT template pending',
    detail: 'India SMS OTP template awaiting TRAI approval · Day 286 yellow.',
    severity: _BlockerSeverity.yellow,
    dayRef: 'Day 286',
    route: AppRoutes.legalBlockersTracker,
  ),
  _OpenBlocker(
    id: 'gonogo_legal',
    title: 'Go/No-Go legal item WARN',
    detail: 'Item 9 legal blockers not fully green — blocks GO until pass.',
    severity: _BlockerSeverity.yellow,
    dayRef: 'Day 298',
    route: AppRoutes.gonogoGate,
  ),
  _OpenBlocker(
    id: 'signoff_eng',
    title: 'Engineering sign-off pending',
    detail: 'Go/No-Go items 21-22 unchecked · launch lead approval needed.',
    severity: _BlockerSeverity.red,
    dayRef: 'Day 298',
    route: AppRoutes.gonogoGate,
  ),
  _OpenBlocker(
    id: 'day300',
    title: 'Day 300 milestone screen',
    detail: 'Final Section E celebration screen — build tomorrow to close arc.',
    severity: _BlockerSeverity.yellow,
    dayRef: 'Day 300',
  ),
];

const _kPolishHighlights = [
  'Day 227 Notification History v3',
  'Day 228 SOS History Timeline',
  'Day 244 Fake Call Polish',
  'Day 278 Counselor Queue Polish',
  'Day 279 Production Dashboard',
  'Day 287 Beta Feedback Round 3',
];

Color _severityColor(_BlockerSeverity s) => switch (s) {
      _BlockerSeverity.red => ZapColors.danger,
      _BlockerSeverity.yellow => ZapColors.warning,
      _BlockerSeverity.green => ZapColors.safe,
    };

String _severityKey(_BlockerSeverity s) => switch (s) {
      _BlockerSeverity.red => 'red',
      _BlockerSeverity.yellow => 'yellow',
      _BlockerSeverity.green => 'green',
    };

Map<String, dynamic> _summaryPayload() => {
      'endpoint': 'GET /api/v1/milestones/penultimate-summary/',
      'since_day': _kSinceDay,
      'current_day': _kCurrentDay,
      'new_days_since_200': _kNewDaysSince200,
      'screens_catalogued': 299,
      'polish_screens': 18,
      'language_packs': 7,
      'open_blockers': _kOpenBlockers.length,
      'section_e_progress': '19/20',
      'wire_note': 'Penultimate stats · one day before Day 300',
    };

String _buildSummaryReport() {
  final buf = StringBuffer(
    'ZapSafe Penultimate Summary (Day $_kCurrentDay)\n'
    'Stats since Day $_kSinceDay\n\n',
  );
  for (final (value, label, _) in _kStats) {
    buf.writeln('$value — $label');
  }
  buf.writeln();
  buf.writeln('Open blockers:');
  for (final b in _kOpenBlockers) {
    buf.writeln('  [${_severityKey(b.severity).toUpperCase()}] ${b.title}');
    buf.writeln('    ${b.detail}');
  }
  buf.writeln();
  buf.writeln('Section E complete — Day 300 Halfway Launch Milestone built');
  buf.writeln('Next: Day 365 Global Launch Milestone (Phase 2)');
  return buf.toString();
}

// ── Providers ─────────────────────────────────────────────────────────────────
final _d299TabProvider = StateProvider<int>((ref) => 0);
final _d299ResolvedProvider = StateProvider<Set<String>>((ref) => {});

// ── Screen ────────────────────────────────────────────────────────────────────
class Day299PenultimateSummaryScreen extends ConsumerWidget {
  const Day299PenultimateSummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolved = ref.watch(_d299ResolvedProvider).length;
    final open = _kOpenBlockers.length - resolved;

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 299 · Penultimate Summary'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: ZapSpacing.sm, vertical: ZapSpacing.xs),
                decoration: BoxDecoration(
                  color: _kAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _kAccent.withOpacity(0.45)),
                ),
                child: Text(
                  '$open blockers',
                  style: const TextStyle(
                    color: _kAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
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
            tab: ref.watch(_d299TabProvider),
            onSelect: (i) => ref.read(_d299TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (ref.watch(_d299TabProvider)) {
              0 => const _SummaryTab(),
              1 => const _StatsTab(),
              _ => const _InfoTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Summary ────────────────────────────────────────────────────────────
class _SummaryTab extends ConsumerWidget {
  const _SummaryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolved = ref.watch(_d299ResolvedProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.all(ZapSpacing.lg),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _kAccent.withOpacity(0.2),
                const Color(0xFF7C3AED).withOpacity(0.12),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kAccent.withOpacity(0.35)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Day 299 · Penultimate',
                style: TextStyle(
                  color: _kAccent,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              SizedBox(height: ZapSpacing.xs),
              Text(
                'One day before Day 300 — halfway to global launch (Day 365). '
                '$_kNewDaysSince200 new build days since the Day 200 grand finale.',
                style: TextStyle(
                  color: ZapColors.textSecondary,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const _SectionTitle(
          title: 'Section progress since Day 200',
          subtitle: 'Catch-up B · Advanced C · Section D · Section E',
        ),
        ..._kSections.map((sec) {
          final progress = sec.daysBuilt / sec.daysTotal;
          return Padding(
            padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
            child: Container(
              padding: const EdgeInsets.all(ZapSpacing.md),
              decoration: BoxDecoration(
                color: ZapColors.bgCard,
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(color: sec.color.withOpacity(0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          sec.label,
                          style: const TextStyle(
                            color: ZapColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Text(
                        '${sec.daysBuilt}/${sec.daysTotal}',
                        style: TextStyle(
                          color: sec.color,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    sec.range,
                    style: const TextStyle(
                      color: ZapColors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: ZapColors.border,
                      color: sec.color,
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: ZapSpacing.xs),
                  Text(
                    sec.highlight,
                    style: const TextStyle(
                      color: ZapColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: ZapSpacing.md),
        const _SectionTitle(
          title: 'Open blockers',
          subtitle: 'Tap to mark resolved · launch gates',
        ),
        ..._kOpenBlockers.map((blocker) {
          final isResolved = resolved.contains(blocker.id);
          final color =
              isResolved ? ZapColors.safe : _severityColor(blocker.severity);
          return Padding(
            padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
            child: InkWell(
              onTap: () {
                final next = Set<String>.from(resolved);
                if (isResolved) {
                  next.remove(blocker.id);
                } else {
                  next.add(blocker.id);
                }
                ref.read(_d299ResolvedProvider.notifier).state = next;
              },
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              child: Container(
                padding: const EdgeInsets.all(ZapSpacing.md),
                decoration: BoxDecoration(
                  color: ZapColors.bgCard,
                  borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                  border: Border.all(color: color.withOpacity(0.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      isResolved
                          ? Icons.check_circle_rounded
                          : Icons.warning_amber_rounded,
                      color: color,
                      size: 20,
                    ),
                    const SizedBox(width: ZapSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            blocker.title,
                            style: TextStyle(
                              color: isResolved
                                  ? ZapColors.textMuted
                                  : ZapColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              decoration: isResolved
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          Text(
                            blocker.detail,
                            style: const TextStyle(
                              color: ZapColors.textSecondary,
                              fontSize: 10,
                              height: 1.35,
                            ),
                          ),
                          Text(
                            blocker.dayRef,
                            style: TextStyle(
                              color: color,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (blocker.route != null && !isResolved)
                      IconButton(
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        onPressed: () => context.push(blocker.route!),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ── Tab 1: Stats ──────────────────────────────────────────────────────────────
class _StatsTab extends ConsumerWidget {
  const _StatsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _SectionTitle(
          title: 'Stats since Day 200',
          subtitle: 'New screens · polish · languages · Phase 2 preview',
        ),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: ZapSpacing.sm,
          crossAxisSpacing: ZapSpacing.sm,
          childAspectRatio: 1.4,
          children: _kStats
              .map(
                (s) => _StatCard(
                  value: s.$1,
                  label: s.$2,
                  color: s.$3,
                ),
              )
              .toList(),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const _SectionTitle(
          title: 'Milestone timeline',
          subtitle: 'Day 200 → 300 arc',
        ),
        ..._kMilestones.map((m) {
          final isCurrent = m.$1 == _kCurrentDay;
          final isFuture = m.$1 > _kCurrentDay;
          return Padding(
            padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: isFuture
                        ? ZapColors.textMuted
                        : isCurrent
                            ? _kAccent
                            : ZapColors.safe,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.$2,
                        style: TextStyle(
                          color: isCurrent ? _kAccent : ZapColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        m.$3,
                        style: const TextStyle(
                          color: ZapColors.textMuted,
                          fontSize: 10,
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
        const _SectionTitle(
          title: 'Polish highlights',
          subtitle: 'Representative 🟣 POLISH screens since Day 200',
        ),
        ..._kPolishHighlights.map(
          (h) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '• $h',
              style: const TextStyle(
                color: ZapColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        FilledButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: _buildSummaryReport()));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Penultimate report copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text('Copy summary report'),
          style: FilledButton.styleFrom(backgroundColor: _kAccent),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ZapColors.textMuted,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab 2: Info ───────────────────────────────────────────────────────────────
class _InfoTab extends ConsumerWidget {
  const _InfoTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payload = _summaryPayload();
    final resolved = ref.watch(_d299ResolvedProvider).length;

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _SectionTitle(
          title: 'Penultimate summary',
          subtitle:
              'Day 299 of 300 · Section E Day 19/20 · stats since Day 200.',
        ),
        const _PolicyRow(
          icon: Icons.trending_up_rounded,
          title: '99 new build days',
          subtitle: 'Days 201-299 after Day 200 grand finale · 4 section arcs.',
        ),
        const _PolicyRow(
          icon: Icons.auto_fix_high_rounded,
          title: '18 polish screens',
          subtitle:
              'Notification v3 · SOS timeline · counselor · production UI.',
        ),
        const _PolicyRow(
          icon: Icons.gpp_maybe_rounded,
          title: '4 open blockers (mock)',
          subtitle: 'Legal DLT · go/no-go warn · sign-off · Day 300 remaining.',
        ),
        Text(
          'Resolved in session: $resolved / ${_kOpenBlockers.length}',
          style: const TextStyle(
            color: ZapColors.textMuted,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'API contract (mock)',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
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
          child: SelectableText(
            _kJsonEncoder.convert(payload),
            style: const TextStyle(
              color: ZapColors.textSecondary,
              fontSize: 10,
              fontFamily: 'monospace',
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(
              ClipboardData(text: _kJsonEncoder.convert(payload)),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Summary spec copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy spec JSON'),
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
            'Section E complete — Day 300 Halfway Launch Milestone is live. '
            'Next: Day 365 — Global Launch Milestone (Phase 2 finale · worldwide rollout).',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              label: const Text('Day 200 Finale'),
              onPressed: () => context.push(AppRoutes.grandFinale),
            ),
            ActionChip(
              label: const Text('Day 280 Section D'),
              onPressed: () => context.push(AppRoutes.sectionDMilestone),
            ),
            ActionChip(
              label: const Text('Day 298 Go/No-Go'),
              onPressed: () => context.push(AppRoutes.gonogoGate),
            ),
            ActionChip(
              label: const Text('Day 295 Roadmap'),
              onPressed: () => context.push(AppRoutes.phase2Roadmap),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
              color: ZapColors.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicyRow extends StatelessWidget {
  const _PolicyRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ZapSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: _kAccent),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 11,
                    height: 1.4,
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

class _TabBar extends StatelessWidget {
  const _TabBar({required this.tab, required this.onSelect});

  final int tab;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ZapColors.bgCard,
      child: Row(
        children: List.generate(_kTabs.length, (i) {
          final selected = tab == i;
          return Expanded(
            child: InkWell(
              onTap: () => onSelect(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: ZapSpacing.md),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected ? _kAccent : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  _kTabs[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? _kAccent : ZapColors.textMuted,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    fontSize: 12,
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
