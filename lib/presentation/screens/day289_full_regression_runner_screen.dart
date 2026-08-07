/// Day 289 — Full App Regression Runner (200+ Screens)
///
/// Section E (Days 281-300): nav-index-linked QA runner for every [AppRoutes]
/// screen — open route, mark pass/fail, export CSV report.
///
/// Tag: 🟢 FRONTEND-ONLY · QA harness · no backend calls.
///
/// Route: [AppRoutes.fullRegressionRunner] → `/full-regression-runner`
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

part 'day289_full_regression_routes.part.dart';

// ── Model ─────────────────────────────────────────────────────────────────────
enum _RouteVerdict { pending, pass, fail }

extension _RouteVerdictX on _RouteVerdict {
  String get label => switch (this) {
        _RouteVerdict.pending => 'pending',
        _RouteVerdict.pass => 'pass',
        _RouteVerdict.fail => 'fail',
      };

  Color get color => switch (this) {
        _RouteVerdict.pending => ZapColors.textMuted,
        _RouteVerdict.pass => ZapColors.safe,
        _RouteVerdict.fail => ZapColors.danger,
      };
}

class RouteRow {
  const RouteRow({
    required this.id,
    required this.title,
    required this.dayRef,
    required this.section,
    required this.route,
  });

  final String id;
  final String title;
  final String dayRef;
  final String section;
  final String route;
}

const _kAccent = Color(0xFF06B6D4);
const _kTabs = ['Runner', 'Progress', 'Export'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');

String _buildCsv(Map<String, _RouteVerdict> verdicts) {
  final buf = StringBuffer('id,title,day,section,route,verdict\n');
  for (final row in kRouteRows) {
    final v = verdicts[row.id] ?? _RouteVerdict.pending;
    final title = row.title.replaceAll(',', ' ');
    buf.writeln(
      '${row.id},$title,${row.dayRef},${row.section},${row.route},${v.label}',
    );
  }
  return buf.toString();
}

String _buildReport(Map<String, _RouteVerdict> verdicts) {
  final pass = verdicts.values.where((v) => v == _RouteVerdict.pass).length;
  final fail = verdicts.values.where((v) => v == _RouteVerdict.fail).length;
  final buf = StringBuffer('ZapSafe Full App Regression — $kRouteCount screens\n\n');
  buf.writeln('Pass: $pass · Fail: $fail · Pending: ${kRouteCount - pass - fail}');
  buf.writeln();
  for (final row in kRouteRows) {
    final v = verdicts[row.id] ?? _RouteVerdict.pending;
    if (v == _RouteVerdict.pending) continue;
    buf.writeln('[${v.label.toUpperCase()}] ${row.title} · ${row.dayRef} · ${row.route}');
  }
  return buf.toString();
}

({int pass, int fail, int pending, int evaluated}) _stats(
  Map<String, _RouteVerdict> verdicts,
) {
  final pass = verdicts.values.where((v) => v == _RouteVerdict.pass).length;
  final fail = verdicts.values.where((v) => v == _RouteVerdict.fail).length;
  return (
    pass: pass,
    fail: fail,
    pending: kRouteCount - pass - fail,
    evaluated: pass + fail,
  );
}

Map<String, dynamic> _runnerPayload(Map<String, _RouteVerdict> verdicts) {
  final s = _stats(verdicts);
  return {
    'endpoint': 'GET /api/v1/qa/full-regression/',
    'screen_count': kRouteCount,
    'pass': s.pass,
    'fail': s.fail,
    'pending': s.pending,
    'launch_ready': s.fail == 0 && s.evaluated == kRouteCount,
    'wire_note': 'Nav-index linked runner · export CSV for CI archive',
  };
}

// ── Providers ───────────────────────────────────────────────────────────────
final _d289TabProvider = StateProvider<int>((ref) => 0);
final _d289VerdictsProvider =
    StateProvider<Map<String, _RouteVerdict>>((ref) => {});
final _d289SectionFilterProvider = StateProvider<String?>((ref) => null);
final _d289SearchProvider = StateProvider<String>((ref) => '');

List<RouteRow> _filteredRows(WidgetRef ref) {
  final section = ref.watch(_d289SectionFilterProvider);
  final q = ref.watch(_d289SearchProvider).toLowerCase().trim();
  return kRouteRows.where((r) {
    if (section != null && r.section != section) return false;
    if (q.isEmpty) return true;
    return r.title.toLowerCase().contains(q) ||
        r.dayRef.toLowerCase().contains(q) ||
        r.route.toLowerCase().contains(q);
  }).toList();
}

List<String> get _kSections =>
    kRouteRows.map((r) => r.section).toSet().toList()..sort();

// ── Screen ──────────────────────────────────────────────────────────────────
class Day289FullRegressionRunnerScreen extends ConsumerWidget {
  const Day289FullRegressionRunnerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = _stats(ref.watch(_d289VerdictsProvider));

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 289 · Full Regression'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _kAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _kAccent.withOpacity(0.45)),
                ),
                child: Text(
                  '${stats.pass}/$kRouteCount',
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
          _ProgressStrip(stats: stats),
          _TabBar(
            tab: ref.watch(_d289TabProvider),
            onSelect: (i) => ref.read(_d289TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (ref.watch(_d289TabProvider)) {
              0 => const _RunnerTab(),
              1 => const _ProgressTab(),
              _ => const _ExportTab(),
            },
          ),
        ],
      ),
    );
  }
}

class _ProgressStrip extends StatelessWidget {
  const _ProgressStrip({required this.stats});

  final ({int pass, int fail, int pending, int evaluated}) stats;

  @override
  Widget build(BuildContext context) {
    final coverage =
        stats.evaluated == 0 ? 0.0 : stats.evaluated / kRouteCount;
    final passRate =
        stats.evaluated == 0 ? 0.0 : stats.pass / stats.evaluated;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.md),
      color: ZapColors.bgCard,
      child: Row(
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: coverage,
                  strokeWidth: 5,
                  backgroundColor: ZapColors.border,
                  color: _kAccent.withOpacity(0.4),
                ),
                CircularProgressIndicator(
                  value: stats.evaluated == 0 ? 0 : passRate,
                  strokeWidth: 5,
                  backgroundColor: Colors.transparent,
                  color: stats.fail > 0 ? ZapColors.warning : ZapColors.safe,
                ),
                Text(
                  '${stats.pass}',
                  style: const TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: ZapSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🟢 FRONTEND-ONLY · $kRouteCount screens · Days 1-331 catalogue '
                  '(extended by Day 332 v2 runner)',
                  style: TextStyle(color: ZapColors.safe, fontSize: 9),
                ),
                Text(
                  '${stats.evaluated} evaluated · ${stats.fail} fail · ${stats.pending} pending',
                  style: const TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
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

// ── Tab 0: Runner ───────────────────────────────────────────────────────────
class _RunnerTab extends ConsumerWidget {
  const _RunnerTab();

  void _setVerdict(WidgetRef ref, String id, _RouteVerdict verdict) {
    ref.read(_d289VerdictsProvider.notifier).state = {
      ...ref.read(_d289VerdictsProvider),
      id: verdict,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = _filteredRows(ref);
    final verdicts = ref.watch(_d289VerdictsProvider);
    final section = ref.watch(_d289SectionFilterProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            ZapSpacing.lg,
            ZapSpacing.md,
            ZapSpacing.lg,
            0,
          ),
          child: TextField(
            onChanged: (v) => ref.read(_d289SearchProvider.notifier).state = v,
            style: const TextStyle(color: ZapColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search route, day, title…',
              hintStyle: const TextStyle(color: ZapColors.textMuted, fontSize: 12),
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              filled: true,
              fillColor: ZapColors.bgCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: ZapColors.border),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: ZapSpacing.lg,
              vertical: 8,
            ),
            children: [
              FilterChip(
                label: const Text('All'),
                selected: section == null,
                onSelected: (_) =>
                    ref.read(_d289SectionFilterProvider.notifier).state = null,
              ),
              const SizedBox(width: 6),
              ..._kSections.map(
                (s) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(s),
                    selected: section == s,
                    onSelected: (_) => ref
                        .read(_d289SectionFilterProvider.notifier)
                        .state = s,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.lg),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${rows.length} of $kRouteCount screens',
              style: const TextStyle(color: ZapColors.textMuted, fontSize: 10),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(ZapSpacing.lg),
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final row = rows[i];
              final verdict = verdicts[row.id] ?? _RouteVerdict.pending;
              return _RouteCard(
                row: row,
                verdict: verdict,
                onPass: () => _setVerdict(ref, row.id, _RouteVerdict.pass),
                onFail: () => _setVerdict(ref, row.id, _RouteVerdict.fail),
                onClear: () {
                  final next = Map<String, _RouteVerdict>.from(verdicts);
                  next.remove(row.id);
                  ref.read(_d289VerdictsProvider.notifier).state = next;
                },
                onOpen: () => context.push(row.route),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.row,
    required this.verdict,
    required this.onPass,
    required this.onFail,
    required this.onClear,
    required this.onOpen,
  });

  final RouteRow row;
  final _RouteVerdict verdict;
  final VoidCallback onPass;
  final VoidCallback onFail;
  final VoidCallback onClear;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: verdict.color.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.title,
                      style: const TextStyle(
                        color: ZapColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '${row.dayRef} · ${row.section}',
                      style: const TextStyle(
                        color: ZapColors.textMuted,
                        fontSize: 9,
                      ),
                    ),
                    Text(
                      row.route,
                      style: const TextStyle(
                        color: ZapColors.textSecondary,
                        fontSize: 9,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                color: ZapColors.info,
                tooltip: 'Open screen',
                onPressed: onOpen,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _VerdictBtn(
                label: 'Pass',
                selected: verdict == _RouteVerdict.pass,
                color: ZapColors.safe,
                onTap: onPass,
              ),
              const SizedBox(width: 6),
              _VerdictBtn(
                label: 'Fail',
                selected: verdict == _RouteVerdict.fail,
                color: ZapColors.danger,
                onTap: onFail,
              ),
              const Spacer(),
              if (verdict != _RouteVerdict.pending)
                TextButton(
                  onPressed: onClear,
                  child: const Text('Clear', style: TextStyle(fontSize: 10)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VerdictBtn extends StatelessWidget {
  const _VerdictBtn({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.18) : ZapColors.bgElevated,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: selected ? color : ZapColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : ZapColors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ── Tab 1: Progress ─────────────────────────────────────────────────────────
class _ProgressTab extends ConsumerWidget {
  const _ProgressTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final verdicts = ref.watch(_d289VerdictsProvider);
    final stats = _stats(verdicts);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        if (stats.evaluated == kRouteCount && stats.fail == 0)
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            margin: const EdgeInsets.only(bottom: ZapSpacing.lg),
            decoration: BoxDecoration(
              color: ZapColors.safe.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ZapColors.safe.withOpacity(0.4)),
            ),
            child: const Row(
              children: [
                Icon(Icons.celebration_rounded, color: ZapColors.safe),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'All $kRouteCount screens pass — full regression green ✅',
                    style: TextStyle(
                      color: ZapColors.safe,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ..._kSections.map((section) {
          final sectionRows =
              kRouteRows.where((r) => r.section == section).toList();
          final pass = sectionRows
              .where(
                (r) =>
                    (verdicts[r.id] ?? _RouteVerdict.pending) ==
                    _RouteVerdict.pass,
              )
              .length;
          final fail = sectionRows
              .where(
                (r) =>
                    (verdicts[r.id] ?? _RouteVerdict.pending) ==
                    _RouteVerdict.fail,
              )
              .length;
          final pct =
              sectionRows.isEmpty ? 0.0 : pass / sectionRows.length;

          return Container(
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ZapColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        section,
                        style: const TextStyle(
                          color: ZapColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Text(
                      '$pass/${sectionRows.length}',
                      style: const TextStyle(
                        color: ZapColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 6,
                    backgroundColor: ZapColors.border,
                    color: fail > 0 ? ZapColors.warning : _kAccent,
                  ),
                ),
                if (fail > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '$fail failing',
                      style: const TextStyle(
                        color: ZapColors.danger,
                        fontSize: 9,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
        OutlinedButton.icon(
          onPressed: () {
            ref.read(_d289VerdictsProvider.notifier).state = {};
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('All verdicts cleared.')),
            );
          },
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Reset all verdicts'),
        ),
      ],
    );
  }
}

// ── Tab 2: Export ─────────────────────────────────────────────────────────────
class _ExportTab extends ConsumerWidget {
  const _ExportTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final verdicts = ref.watch(_d289VerdictsProvider);
    final stats = _stats(verdicts);
    final csv = _buildCsv(verdicts);
    final payload = _runnerPayload(verdicts);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _SectionTitle(
          title: 'Export regression CSV',
          subtitle: '$kRouteCount rows · id, title, day, section, route, verdict',
        ),
        Text(
          '${stats.pass} pass · ${stats.fail} fail · ${stats.pending} pending',
          style: const TextStyle(color: ZapColors.textMuted, fontSize: 11),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.border),
          ),
          child: SelectableText(
            csv.split('\n').take(12).join('\n'),
            style: const TextStyle(
              color: ZapColors.textSecondary,
              fontFamily: 'monospace',
              fontSize: 9,
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        FilledButton.icon(
          onPressed: stats.evaluated == 0
              ? null
              : () {
                  Clipboard.setData(ClipboardData(text: csv));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'CSV copied ($kRouteCount rows · ${stats.evaluated} evaluated)',
                      ),
                    ),
                  );
                },
          icon: const Icon(Icons.table_chart_rounded, size: 18),
          label: const Text('Copy CSV'),
          style: FilledButton.styleFrom(backgroundColor: _kAccent),
        ),
        const SizedBox(height: ZapSpacing.sm),
        OutlinedButton.icon(
          onPressed: stats.evaluated == 0
              ? null
              : () {
                  Clipboard.setData(
                    ClipboardData(text: _buildReport(verdicts)),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Text report copied.')),
                  );
                },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy text report'),
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
            borderRadius: BorderRadius.circular(8),
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
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.info.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.info.withOpacity(0.3)),
          ),
          child: const Text(
            'Next: Day 365 — Global Launch Milestone '
            '(Phase 2 finale · worldwide rollout).',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              label: const Text('Day 229 Feature Runner'),
              onPressed: () => context.push(AppRoutes.featureRegressionRunner),
            ),
            ActionChip(
              label: const Text('Day 288 Crash-Free'),
              onPressed: () => context.push(AppRoutes.crashFreeTracker),
            ),
            ActionChip(
              label: const Text('Day 300 Milestone'),
              onPressed: () => context.push(AppRoutes.day300Milestone),
            ),
            ActionChip(
              label: const Text('Day 201 QA Harness'),
              onPressed: () => context.push(AppRoutes.deviceQaHarness),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Shared ────────────────────────────────────────────────────────────────────
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
                padding: const EdgeInsets.symmetric(vertical: 12),
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
                    fontWeight:
                        selected ? FontWeight.w800 : FontWeight.w500,
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
