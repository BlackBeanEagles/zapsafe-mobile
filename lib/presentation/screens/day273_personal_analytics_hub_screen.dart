/// Day 273 — Personal Safety Analytics Hub
///
/// Section D (Days 261-280): personal safety insights — safest areas,
/// riskiest times, weekly score trend — powered by mock analytics data.
///
/// Tag: 🟡 MOCK-NOW · wire to GET /api/v1/analytics/* when backend extends.
///
/// Route: [AppRoutes.personalAnalyticsHub] → `/personal-analytics-hub`
library;

import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const _kAccent = Color(0xFF6366F1);
const _kTabs = ['Insights', 'Trends', 'Info'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');

enum _AnalyticsPeriod { d7, d30, d90 }

class _AreaInsight {
  const _AreaInsight({
    required this.name,
    required this.score,
    required this.visits,
    required this.risk,
  });

  final String name;
  final int score;
  final int visits;
  final String risk;
}

const _kSafestAreas = [
  _AreaInsight(name: 'Indiranagar 100ft Rd', score: 92, visits: 14, risk: 'low'),
  _AreaInsight(name: 'Koramangala 4th Block', score: 89, visits: 11, risk: 'low'),
  _AreaInsight(name: 'Jayanagar 4th Block', score: 87, visits: 9, risk: 'low'),
  _AreaInsight(name: 'HSR Sector 1', score: 84, visits: 8, risk: 'low'),
  _AreaInsight(name: 'Whitefield ITPL', score: 78, visits: 6, risk: 'medium'),
];

const _kRiskiestAreas = [
  _AreaInsight(name: 'Shivajinagar (late night)', score: 41, visits: 2, risk: 'high'),
  _AreaInsight(name: 'Majestic bus stand', score: 48, visits: 3, risk: 'high'),
  _AreaInsight(name: 'Silk Board junction', score: 52, visits: 5, risk: 'medium'),
];

class _TimeRisk {
  const _TimeRisk({
    required this.label,
    required this.window,
    required this.incidents,
    required this.level,
  });

  final String label;
  final String window;
  final int incidents;
  final String level;
}

const _kRiskiestTimes = [
  _TimeRisk(
    label: 'Friday night',
    window: '22:00 – 01:00',
    incidents: 4,
    level: 'high',
  ),
  _TimeRisk(
    label: 'Saturday late',
    window: '23:00 – 02:00',
    incidents: 3,
    level: 'high',
  ),
  _TimeRisk(
    label: 'Wednesday commute',
    window: '19:00 – 21:00',
    incidents: 2,
    level: 'medium',
  ),
  _TimeRisk(
    label: 'Sunday evening',
    window: '18:00 – 20:00',
    incidents: 1,
    level: 'low',
  ),
];

const _kWeeklyScores = [72.0, 74.0, 76.0, 75.0, 78.0, 80.0, 82.0, 84.0];
const _kWeeklyLabels = ['W1', 'W2', 'W3', 'W4', 'W5', 'W6', 'W7', 'W8'];
const _kDayActivity = [3.0, 5.0, 4.0, 6.0, 8.0, 7.0, 2.0];
const _kHourRisk = [
  0.1, 0.1, 0.1, 0.1, 0.2, 0.3, 0.5, 0.7, 0.6, 0.4, 0.3, 0.3,
  0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 0.95, 0.85, 0.75, 0.9, 0.95, 0.8,
];

Map<String, dynamic> _analyticsPayload(_AnalyticsPeriod period) => {
      'endpoint': 'GET /api/v1/analytics/personal-summary/',
      'period': period.name,
      'safest_areas': _kSafestAreas
          .map((a) => {'name': a.name, 'score': a.score, 'visits': a.visits})
          .toList(),
      'riskiest_times': _kRiskiestTimes
          .map((t) => {'label': t.label, 'window': t.window, 'level': t.level})
          .toList(),
      'weekly_safety_score': _kWeeklyScores.last,
      'weekly_trend_delta': '+12 pts (8 wks)',
      'wire_note': 'Extend backend at /api/v1/analytics/* for live data',
    };

// ── Providers ─────────────────────────────────────────────────────────────────
final _d273TabProvider = StateProvider<int>((ref) => 0);
final _d273PeriodProvider =
    StateProvider<_AnalyticsPeriod>((ref) => _AnalyticsPeriod.d30);
final _d273RefreshingProvider = StateProvider<bool>((ref) => false);
final _d273LastRefreshProvider = StateProvider<String?>((ref) => null);

// ── Screen ────────────────────────────────────────────────────────────────────
class Day273PersonalAnalyticsHubScreen extends ConsumerWidget {
  const Day273PersonalAnalyticsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d273TabProvider);
    final period = ref.watch(_d273PeriodProvider);
    final refreshing = ref.watch(_d273RefreshingProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 273 · Personal Analytics'),
        actions: [
          IconButton(
            onPressed: refreshing
                ? null
                : () async {
                    ref.read(_d273RefreshingProvider.notifier).state = true;
                    await Future<void>.delayed(const Duration(milliseconds: 900));
                    ref.read(_d273RefreshingProvider.notifier).state = false;
                    ref.read(_d273LastRefreshProvider.notifier).state =
                        DateTime.now().toIso8601String();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Analytics refreshed (mock).'),
                        ),
                      );
                    }
                  },
            icon: refreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
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
                  period.name.toUpperCase(),
                  style: const TextStyle(
                    color: _kAccent,
                    fontSize: 11,
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
            tab: tab,
            onSelect: (i) => ref.read(_d273TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (tab) {
              0 => const _InsightsTab(),
              1 => const _TrendsTab(),
              _ => const _InfoTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Insights ───────────────────────────────────────────────────────────
class _InsightsTab extends ConsumerWidget {
  const _InsightsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _kAccent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _kAccent.withOpacity(0.35)),
          ),
          child: const Text(
            '🟡 MOCK-NOW · Section D Day 13/20 · personal safety insights · mock analytics',
            style: TextStyle(color: _kAccent, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Row(
          children: [
            _StatCard(label: 'Safety score', value: '84', delta: '+12 pts'),
            SizedBox(width: 8),
            _StatCard(label: 'Journeys', value: '12', delta: '30d'),
            SizedBox(width: 8),
            _StatCard(label: 'Near-miss', value: '2', delta: 'reported'),
          ],
        ),
        const SizedBox(height: ZapSpacing.lg),
        const _SectionHeader(
          title: 'Safest areas',
          subtitle: 'Based on your routes & community heatmap (mock)',
        ),
        ..._kSafestAreas.map((area) => _AreaRow(area: area, safest: true)),
        const SizedBox(height: ZapSpacing.lg),
        const _SectionHeader(
          title: 'Higher-risk areas',
          subtitle: 'Areas to stay alert · fewer visits recommended at night',
        ),
        ..._kRiskiestAreas.map((area) => _AreaRow(area: area, safest: false)),
        const SizedBox(height: ZapSpacing.lg),
        const _SectionHeader(
          title: 'Riskiest times',
          subtitle: 'When incidents cluster in your mobility pattern',
        ),
        ..._kRiskiestTimes.map(_TimeRiskRow.new),
        const SizedBox(height: ZapSpacing.md),
        const _HourRiskStrip(risks: _kHourRisk),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.delta,
  });

  final String label;
  final String value;
  final String delta;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(ZapSpacing.sm),
        decoration: BoxDecoration(
          color: _kAccent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kAccent.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: _kAccent,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: ZapColors.textPrimary, fontSize: 10),
            ),
            Text(
              delta,
              style: const TextStyle(color: ZapColors.textMuted, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

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
            style: const TextStyle(color: ZapColors.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _AreaRow extends StatelessWidget {
  const _AreaRow({required this.area, required this.safest});

  final _AreaInsight area;
  final bool safest;

  @override
  Widget build(BuildContext context) {
    final color = safest
        ? ZapColors.safe
        : area.risk == 'high'
            ? ZapColors.danger
            : ZapColors.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(ZapSpacing.sm),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ZapColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  area.name,
                  style: const TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '${area.visits} visits · ${area.risk} risk',
                  style: const TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 88,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${area.score}',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                LinearProgressIndicator(
                  value: area.score / 100,
                  minHeight: 4,
                  backgroundColor: ZapColors.border,
                  color: color,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeRiskRow extends StatelessWidget {
  const _TimeRiskRow(this.time);

  final _TimeRisk time;

  @override
  Widget build(BuildContext context) {
    final color = switch (time.level) {
      'high' => ZapColors.danger,
      'medium' => ZapColors.warning,
      _ => ZapColors.textMuted,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(ZapSpacing.sm),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule_rounded, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  time.label,
                  style: const TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '${time.window} · ${time.incidents} incident signals',
                  style: const TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Text(
            time.level.toUpperCase(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _HourRiskStrip extends StatelessWidget {
  const _HourRiskStrip({required this.risks});

  final List<double> risks;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.sm),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ZapColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '24h risk intensity',
            style: TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 28,
            child: Row(
              children: List.generate(24, (h) {
                final v = risks[h];
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 0.5),
                    decoration: BoxDecoration(
                      color: Color.lerp(
                        ZapColors.bgSurface,
                        ZapColors.danger,
                        v,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 4),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('00', style: TextStyle(color: ZapColors.textMuted, fontSize: 9)),
              Text('12', style: TextStyle(color: ZapColors.textMuted, fontSize: 9)),
              Text('23', style: TextStyle(color: ZapColors.textMuted, fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Tab 1: Trends ─────────────────────────────────────────────────────────────
class _TrendsTab extends ConsumerWidget {
  const _TrendsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(_d273PeriodProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        SegmentedButton<_AnalyticsPeriod>(
          segments: const [
            ButtonSegment(value: _AnalyticsPeriod.d7, label: Text('7d')),
            ButtonSegment(value: _AnalyticsPeriod.d30, label: Text('30d')),
            ButtonSegment(value: _AnalyticsPeriod.d90, label: Text('90d')),
          ],
          selected: {period},
          onSelectionChanged: (s) =>
              ref.read(_d273PeriodProvider.notifier).state = s.first,
        ),
        const SizedBox(height: ZapSpacing.lg),
        const _SectionHeader(
          title: 'Weekly safety score',
          subtitle: 'Protection score trend · last 8 weeks (mock)',
        ),
        const _WeeklyLineChart(scores: _kWeeklyScores, labels: _kWeeklyLabels),
        const SizedBox(height: ZapSpacing.lg),
        const _SectionHeader(
          title: 'Weekly activity',
          subtitle: 'Journeys + drills by day of week',
        ),
        const _WeeklyBarChart(values: _kDayActivity),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.safe.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ZapColors.safe.withOpacity(0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.trending_up_rounded, color: ZapColors.safe),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your safety score improved 12 points over 8 weeks · '
                  'Friday/Saturday evenings remain your highest-risk windows.',
                  style: TextStyle(color: ZapColors.textSecondary, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WeeklyLineChart extends StatelessWidget {
  const _WeeklyLineChart({required this.scores, required this.labels});

  final List<double> scores;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final minY = scores.reduce((a, b) => a < b ? a : b) - 4;
    final maxY = scores.reduce((a, b) => a > b ? a : b) + 4;
    final spots = List.generate(
      scores.length,
      (i) => FlSpot(i.toDouble(), scores[i]),
    );

    return Container(
      height: 180,
      padding: const EdgeInsets.all(ZapSpacing.sm),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZapColors.border),
      ),
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          lineTouchData: const LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipBgColor: ZapColors.bgElevated,
            ),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= labels.length) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    labels[i],
                    style: const TextStyle(
                      color: ZapColors.textMuted,
                      fontSize: 9,
                    ),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => const FlLine(
              color: ZapColors.border,
              strokeWidth: 0.5,
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: _kAccent,
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: _kAccent.withOpacity(0.15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyBarChart extends StatelessWidget {
  const _WeeklyBarChart({required this.values});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final maxY = values.reduce((a, b) => a > b ? a : b) + 1;

    return Container(
      height: 160,
      padding: const EdgeInsets.all(ZapSpacing.sm),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZapColors.border),
      ),
      child: BarChart(
        BarChartData(
          maxY: maxY,
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (value, meta) => Text(
                  days[value.toInt()],
                  style: const TextStyle(
                    color: ZapColors.textMuted,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => const FlLine(
              color: ZapColors.border,
              strokeWidth: 0.5,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(7, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: values[i],
                  width: 14,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  color: i >= 4 ? _kAccent : _kAccent.withOpacity(0.55),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

// ── Tab 2: Info ───────────────────────────────────────────────────────────────
class _InfoTab extends ConsumerWidget {
  const _InfoTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(_d273PeriodProvider);
    final lastRefresh = ref.watch(_d273LastRefreshProvider);
    final payload = {
      ..._analyticsPayload(period),
      'last_refresh': lastRefresh,
      'related_endpoints': [
        'GET /api/v1/analytics/personal-summary/',
        'GET /api/v1/analytics/areas/',
        'GET /api/v1/analytics/time-risk/',
        'GET /api/v1/analytics/weekly-trend/',
      ],
    };

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _PolicyRow(
          icon: Icons.insights_rounded,
          title: 'Personal safety insights',
          subtitle:
              'Safest vs higher-risk areas · riskiest time windows · 24h intensity '
              'strip · all mock data for Section D.',
        ),
        const _PolicyRow(
          icon: Icons.show_chart_rounded,
          title: 'Weekly trends',
          subtitle:
              '8-week protection score line chart · day-of-week activity bars · '
              '7d/30d/90d period selector (mock).',
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
        const SizedBox(height: ZapSpacing.sm),
        OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(
              ClipboardData(text: _kJsonEncoder.convert(payload)),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Analytics spec copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy analytics spec'),
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
              label: const Text('Day 270 Community Heatmap'),
              onPressed: () => context.push(AppRoutes.communityHeatmap),
            ),
            ActionChip(
              label: const Text('Day 59 Protection Score'),
              onPressed: () => context.push(AppRoutes.protectionScore),
            ),
            ActionChip(
              label: const Text('Day 80 Alert Dashboard'),
              onPressed: () => context.push(AppRoutes.alertDashboardV2),
            ),
          ],
        ),
      ],
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
