/// Day 217 — Performance Profiling Dashboard
///
/// Section A (Days 201-220): targets vs mock measurements for cold start,
/// DCS first cycle, RAM, and battery — staged benchmark simulation.
///
/// Tag: 🟢 FRONTEND-ONLY — mock profiler, links to Days 129-130 polish.
///
/// Route: [AppRoutes.performanceProfiling] → `/performance-profiling`
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

// ── Metrics ───────────────────────────────────────────────────────────────────
enum PerfMetricId { coldStart, dcsCycle, ramMonitoring, batteryMonitoring }

class PerfMetricSpec {
  final PerfMetricId id;
  final String title;
  final String subtitle;
  final String targetLabel;
  final double targetValue;
  final String unit;
  final bool lowerIsBetter;
  final IconData icon;
  final Color accent;
  final double beforeValue;
  final double afterValue;
  final String day129Link;

  const PerfMetricSpec({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.targetLabel,
    required this.targetValue,
    required this.unit,
    required this.lowerIsBetter,
    required this.icon,
    required this.accent,
    required this.beforeValue,
    required this.afterValue,
    required this.day129Link,
  });

  bool passes(double measured) =>
      lowerIsBetter ? measured < targetValue : measured > targetValue;

  String format(double value) => switch (unit) {
        's' => '${value.toStringAsFixed(1)}s',
        'MB' => '${value.round()} MB',
        '%/hr' => '${value.toStringAsFixed(1)}%/hr',
        _ => value.toStringAsFixed(1),
      };
}

const _kMetrics = [
  PerfMetricSpec(
    id: PerfMetricId.coldStart,
    title: 'Cold start',
    subtitle: 'Time to interactive dashboard',
    targetLabel: '<2s',
    targetValue: 2.0,
    unit: 's',
    lowerIsBetter: true,
    icon: Icons.rocket_launch_rounded,
    accent: ZapColors.info,
    beforeValue: 5.2,
    afterValue: 1.8,
    day129Link: 'Day 129 · defer Hive/TFLite/GPS init',
  ),
  PerfMetricSpec(
    id: PerfMetricId.dcsCycle,
    title: 'DCS first cycle',
    subtitle: 'First distress score inference',
    targetLabel: '<5s',
    targetValue: 5.0,
    unit: 's',
    lowerIsBetter: true,
    icon: Icons.psychology_rounded,
    accent: Color(0xFF8B5CF6),
    beforeValue: 7.4,
    afterValue: 4.1,
    day129Link: 'Day 129 · background isolate model load',
  ),
  PerfMetricSpec(
    id: PerfMetricId.ramMonitoring,
    title: 'RAM (MONITORING)',
    subtitle: 'Peak heap in MONITORING mode',
    targetLabel: '<150 MB',
    targetValue: 150,
    unit: 'MB',
    lowerIsBetter: true,
    icon: Icons.memory_rounded,
    accent: ZapColors.safe,
    beforeValue: 195,
    afterValue: 118,
    day129Link: 'Day 130 · lazy screens + image cache cap',
  ),
  PerfMetricSpec(
    id: PerfMetricId.batteryMonitoring,
    title: 'Battery MONITORING',
    subtitle: 'Drain rate in MONITORING mode',
    targetLabel: '<2%/hr',
    targetValue: 2.0,
    unit: '%/hr',
    lowerIsBetter: true,
    icon: Icons.battery_charging_full_rounded,
    accent: ZapColors.warning,
    beforeValue: 6.2,
    afterValue: 1.9,
    day129Link: 'Day 129 · adaptive GPS + audio batching',
  ),
];

const _kBenchmarkStages = [
  'Initialising profiler…',
  'Measuring cold start waterfall…',
  'Running DCS first inference cycle…',
  'Sampling RAM in MONITORING mode…',
  'Measuring battery drain (10 min extrapolated)…',
  'Compiling results…',
];

enum _BenchmarkState { idle, running, done }

// ── Providers ─────────────────────────────────────────────────────────────────
final _d217TabProvider = StateProvider<int>((ref) => 0);
final _d217BenchmarkStateProvider =
    StateProvider<_BenchmarkState>((ref) => _BenchmarkState.idle);
final _d217StageIndexProvider = StateProvider<int>((ref) => 0);
final _d217ResultsProvider = StateProvider<Map<PerfMetricId, double>>(
  (ref) => {},
);

const _kTabs = ['Benchmark', 'Before / After', 'Spec'];

// ── Screen ────────────────────────────────────────────────────────────────────
class Day217PerformanceProfilingScreen extends ConsumerWidget {
  const Day217PerformanceProfilingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d217TabProvider);
    final results = ref.watch(_d217ResultsProvider);
    final passCount =
        _kMetrics.where((m) => results.containsKey(m.id) && m.passes(results[m.id]!)).length;

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 217 · Performance Profiling'),
        actions: [
          if (results.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: ZapSpacing.md),
              child: Center(
                child: Text(
                  '$passCount/${_kMetrics.length} pass',
                  style: TextStyle(
                    color: passCount == _kMetrics.length
                        ? ZapColors.safe
                        : ZapColors.textSecondary,
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
            onSelect: (i) => ref.read(_d217TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (tab) {
              0 => const _BenchmarkTab(),
              1 => const _BeforeAfterTab(),
              _ => const _SpecTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Benchmark ──────────────────────────────────────────────────────────
class _BenchmarkTab extends ConsumerWidget {
  const _BenchmarkTab();

  Future<void> _runBenchmark(WidgetRef ref, BuildContext context) async {
    if (ref.read(_d217BenchmarkStateProvider) == _BenchmarkState.running) {
      return;
    }
    ref.read(_d217BenchmarkStateProvider.notifier).state =
        _BenchmarkState.running;
    ref.read(_d217StageIndexProvider.notifier).state = 0;
    ref.read(_d217ResultsProvider.notifier).state = {};

    for (var i = 0; i < _kBenchmarkStages.length; i++) {
      ref.read(_d217StageIndexProvider.notifier).state = i;
      await Future<void>.delayed(Duration(milliseconds: 500 + i * 120));
    }

    ref.read(_d217ResultsProvider.notifier).state = {
      for (final m in _kMetrics)
        m.id: m.afterValue + _jitter(m.id),
    };
    ref.read(_d217BenchmarkStateProvider.notifier).state = _BenchmarkState.done;

    if (!context.mounted) return;
    final results = ref.read(_d217ResultsProvider);
    final passed =
        _kMetrics.where((m) => m.passes(results[m.id]!)).length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Benchmark complete — $passed/${_kMetrics.length} targets met',
        ),
      ),
    );
  }

  double _jitter(PerfMetricId id) => switch (id) {
        PerfMetricId.coldStart => 0.05,
        PerfMetricId.dcsCycle => 0.2,
        PerfMetricId.ramMonitoring => 3,
        PerfMetricId.batteryMonitoring => 0.05,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_d217BenchmarkStateProvider);
    final stage = ref.watch(_d217StageIndexProvider);
    final results = ref.watch(_d217ResultsProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: ZapColors.safe.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: ZapColors.safe.withOpacity(0.35)),
          ),
          child: const Text(
            '🟢 FRONTEND-ONLY · Section A Day 17/20 · Mock device profiler',
            style: TextStyle(color: ZapColors.safe, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Run benchmark',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          'Staged simulation on a physical device profile — not a real '
          'Android Profiler trace. Compare results to release targets.',
          style: TextStyle(color: ZapColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Semantics(
          label: 'Run performance benchmark',
          button: true,
          child: FilledButton.icon(
            onPressed: state == _BenchmarkState.running
                ? null
                : () => _runBenchmark(ref, context),
            icon: Icon(
              state == _BenchmarkState.running
                  ? Icons.hourglass_top_rounded
                  : Icons.play_arrow_rounded,
              size: 22,
            ),
            label: Text(
              state == _BenchmarkState.running
                  ? 'Running…'
                  : state == _BenchmarkState.done
                      ? 'Re-run benchmark'
                      : 'Run benchmark',
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 75),
              backgroundColor: ZapColors.info,
            ),
          ),
        ),
        if (state == _BenchmarkState.running) ...[
          const SizedBox(height: ZapSpacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ZapColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _kBenchmarkStages[stage.clamp(0, _kBenchmarkStages.length - 1)],
                  style: const TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: ZapSpacing.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (stage + 1) / _kBenchmarkStages.length,
                    minHeight: 6,
                    backgroundColor: ZapColors.bgElevated,
                    color: ZapColors.info,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Stage ${stage + 1}/${_kBenchmarkStages.length}',
                  style: const TextStyle(color: ZapColors.textMuted, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Target metrics',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        ..._kMetrics.map((metric) {
          final measured = results[metric.id];
          return _ResultCard(
            metric: metric,
            measured: measured,
            showPlaceholder: state != _BenchmarkState.done && measured == null,
          );
        }),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  final PerfMetricSpec metric;
  final double? measured;
  final bool showPlaceholder;

  const _ResultCard({
    required this.metric,
    required this.measured,
    required this.showPlaceholder,
  });

  @override
  Widget build(BuildContext context) {
    final value = measured;
    final pass = value != null && metric.passes(value);
    final fail = value != null && !pass;
    final borderColor = fail
        ? ZapColors.danger
        : pass
            ? ZapColors.safe
            : ZapColors.border;

    return Container(
      margin: const EdgeInsets.only(bottom: ZapSpacing.md),
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: fail || pass ? 2 : 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: metric.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(metric.icon, color: metric.accent, size: 22),
          ),
          const SizedBox(width: ZapSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        metric.title,
                        style: const TextStyle(
                          color: ZapColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (pass)
                      const Icon(Icons.check_circle_rounded,
                          color: ZapColors.safe, size: 18),
                    if (fail)
                      const Icon(Icons.cancel_rounded,
                          color: ZapColors.danger, size: 18),
                  ],
                ),
                Text(
                  metric.subtitle,
                  style: const TextStyle(
                    color: ZapColors.textMuted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: ZapSpacing.sm),
                Row(
                  children: [
                    _MetricPill(
                      label: 'Target',
                      value: metric.targetLabel,
                      color: ZapColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    _MetricPill(
                      label: 'Measured',
                      value: showPlaceholder
                          ? '—'
                          : metric.format(value ?? metric.afterValue),
                      color: pass
                          ? ZapColors.safe
                          : fail
                              ? ZapColors.danger
                              : ZapColors.info,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Tab 1: Before / After ─────────────────────────────────────────────────────
class _BeforeAfterTab extends ConsumerWidget {
  const _BeforeAfterTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text(
          'Before / after comparison',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          'Baseline from pre-Day 129 beta metrics vs current polish track. '
          'Tap Day 129/130 links for optimisation diffs.',
          style: TextStyle(color: ZapColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.border),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: ZapSpacing.md,
                  vertical: ZapSpacing.sm,
                ),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: ZapColors.border)),
                ),
                child: const Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Metric',
                        style: TextStyle(
                          color: ZapColors.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Before',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: ZapColors.danger,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'After',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: ZapColors.safe,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Target',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: ZapColors.info,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ..._kMetrics.map((m) {
                final delta = m.beforeValue - m.afterValue;
                final improved = m.lowerIsBetter ? delta > 0 : delta < 0;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ZapSpacing.md,
                    vertical: ZapSpacing.sm,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: ZapColors.border)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              m.title,
                              style: const TextStyle(
                                color: ZapColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              m.format(m.beforeValue),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: ZapColors.danger,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              m.format(m.afterValue),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: ZapColors.safe,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              m.targetLabel,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: ZapColors.info,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            improved
                                ? Icons.trending_down_rounded
                                : Icons.trending_up_rounded,
                            size: 14,
                            color: improved ? ZapColors.safe : ZapColors.warning,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              m.day129Link,
                              style: const TextStyle(
                                color: ZapColors.textMuted,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Semantics(
          label: 'Open Day 129 performance screen',
          button: true,
          child: OutlinedButton.icon(
            onPressed: () => context.push(AppRoutes.performance),
            icon: const Icon(Icons.speed_rounded, size: 18),
            label: const Text('Open Day 129 · Cold start + battery'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 75),
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Semantics(
          label: 'Open Day 130 memory screen',
          button: true,
          child: OutlinedButton.icon(
            onPressed: () => context.push(AppRoutes.memoryOpt),
            icon: const Icon(Icons.memory_rounded, size: 18),
            label: const Text('Open Day 130 · Memory optimisation'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 75),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Tab 2: Spec ───────────────────────────────────────────────────────────────
class _SpecTab extends ConsumerWidget {
  const _SpecTab();

  String _buildReport(Map<PerfMetricId, double> results) {
    final buf = StringBuffer()
      ..writeln('ZapSafe Performance Profiling — Day 217')
      ..writeln('');
    for (final m in _kMetrics) {
      final measured = results[m.id];
      buf.writeln('${m.title} (target ${m.targetLabel})');
      buf.writeln('  Before: ${m.format(m.beforeValue)}');
      buf.writeln('  After:  ${m.format(m.afterValue)}');
      if (measured != null) {
        buf.writeln(
          '  Measured: ${m.format(measured)} → ${m.passes(measured) ? "PASS" : "FAIL"}',
        );
      }
      buf.writeln('  Fix: ${m.day129Link}');
      buf.writeln('');
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(_d217ResultsProvider);
    final report = _buildReport(results);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text(
          'Release targets (original plan)',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        ..._kMetrics.map(
          (m) => Container(
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ZapColors.border),
            ),
            child: Row(
              children: [
                Icon(m.icon, color: m.accent, size: 20),
                const SizedBox(width: ZapSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.title,
                        style: const TextStyle(
                          color: ZapColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        'Target ${m.targetLabel}',
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
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Semantics(
          label: 'Copy benchmark report',
          button: true,
          child: FilledButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: report));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Report copied')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy report'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 75),
              backgroundColor: ZapColors.bgElevated,
              foregroundColor: ZapColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.info.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.info.withOpacity(0.3)),
          ),
          child: const Text(
            'Tomorrow: Day 219 — Backend integration audit matrix (~50 API contracts).',
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
                        color: selected ? ZapColors.safe : Colors.transparent,
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
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
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
