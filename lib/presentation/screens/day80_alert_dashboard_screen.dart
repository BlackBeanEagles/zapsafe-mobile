/// Day 80 — Alert Dashboard (Riverpod refactor + 24-hour heatmap)
///
/// Refinement of the Day 77-78 prototype:
///   • State management via [dashboardPeriodProvider] + [dashboardDataProvider]
///   • Period switch triggers provider recompute — no manual setState
///   • New panel: 24-hour alert heatmap (7 days × 24 hours color grid)
///   • All Day 77-78 charts retained: safety score, stats, bar, line, peaks,
///     response breakdown, detection type
///
/// Data source: [_mockData] in dashboard_providers.dart.
/// Swap for real API when /api/v1/dashboard/ is live (Day 81+).
library;

import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../domain/providers/dashboard_providers.dart';

// ─── Screen ───────────────────────────────────────────────────────────────────

class Day80AlertDashboardScreen extends ConsumerWidget {
  const Day80AlertDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(dashboardPeriodProvider);
    final async  = ref.watch(dashboardDataProvider(period));

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        backgroundColor:   ZapColors.bgPrimary,
        elevation:         0,
        surfaceTintColor:  Colors.transparent,
        leading: const BackButton(color: ZapColors.textPrimary),
        title: Text(
          'Activity Overview',
          style: ZapTypography.headlineSmall.copyWith(color: ZapColors.textPrimary),
        ),
        actions: [
          Container(
            margin:  const EdgeInsets.only(right: ZapSpacing.md),
            padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.sm, vertical: 3),
            decoration: BoxDecoration(
              color:        ZapColors.warning.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
              border:       Border.all(color: ZapColors.warning.withOpacity(0.4), width: 0.5),
            ),
            child: Text(
              'SAMPLE',
              style: ZapTypography.labelSmall.copyWith(
                color:         ZapColors.warning,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(
          child: Text(
            'Failed to load dashboard',
            style: ZapTypography.bodyMedium.copyWith(color: ZapColors.danger),
          ),
        ),
        data: (data) => _DashboardBody(period: period, data: data),
      ),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({required this.period, required this.data});

  final DashboardPeriod period;
  final DashboardData   data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(
        left: ZapSpacing.lg, right: ZapSpacing.lg, bottom: ZapSpacing.xxxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: ZapSpacing.md),

          // ── Period selector ─────────────────────────────────────────────
          _PeriodSelector(
            selected:  period,
            onChanged: (p) =>
                ref.read(dashboardPeriodProvider.notifier).state = p,
          ),

          const SizedBox(height: ZapSpacing.xl),

          // ── Safety score ────────────────────────────────────────────────
          _SafetyScoreCard(score: data.safetyScore),

          const SizedBox(height: ZapSpacing.xl),

          // ── Stats row ───────────────────────────────────────────────────
          _StatsRow(data: data),

          if (data.totalEvents == 0) ...[
            const SizedBox(height: ZapSpacing.xl),
            const _EmptyDashboard(),
          ] else ...[

            const SizedBox(height: ZapSpacing.xl),

            // ── Bar chart ─────────────────────────────────────────────────
            const _SectionLabel(
              icon: Icons.bar_chart_rounded,
              text: 'Events by day of week',
            ),
            const SizedBox(height: ZapSpacing.md),
            _DayOfWeekChart(values: data.byDayOfWeek),

            const SizedBox(height: ZapSpacing.xl),

            // ── Trend line ────────────────────────────────────────────────
            _SectionLabel(
              icon: Icons.show_chart_rounded,
              text: 'Trend — ${period.label}',
            ),
            const SizedBox(height: ZapSpacing.md),
            _TrendChart(points: data.trendPoints),

            const SizedBox(height: ZapSpacing.xl),

            // ── 24-hour heatmap (Day 80 addition) ─────────────────────────
            const _SectionLabel(
              icon: Icons.grid_view_rounded,
              text: 'Alert heatmap · hour of day',
            ),
            const SizedBox(height: ZapSpacing.md),
            _HeatmapPanel(heatmap: data.heatmap),

            const SizedBox(height: ZapSpacing.xl),

            // ── Peak hours ────────────────────────────────────────────────
            const _SectionLabel(
              icon: Icons.access_time_rounded,
              text: 'Peak hours',
            ),
            const SizedBox(height: ZapSpacing.md),
            _PeakHoursPanel(
              peakHours: data.peakHours,
              total:     data.totalEvents,
            ),

            const SizedBox(height: ZapSpacing.xl),

            // ── Response breakdown ────────────────────────────────────────
            const _SectionLabel(
              icon: Icons.people_alt_rounded,
              text: 'Contact response',
            ),
            const SizedBox(height: ZapSpacing.md),
            _ResponseBreakdown(
              tier1Pct: data.tier1Pct,
              tier2Pct: data.tier2Pct,
            ),

            const SizedBox(height: ZapSpacing.xl),

            // ── Detection type ────────────────────────────────────────────
            const _SectionLabel(
              icon: Icons.sensors_rounded,
              text: 'Detection type',
            ),
            const SizedBox(height: ZapSpacing.md),
            _DetectionTypeBreakdown(
              screamCount: data.screamCount,
              motionCount: data.motionCount,
              sceneCount:  data.sceneCount,
              total:       data.totalEvents,
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Period selector ──────────────────────────────────────────────────────────

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.selected, required this.onChanged});

  final DashboardPeriod              selected;
  final void Function(DashboardPeriod) onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: DashboardPeriod.values.map((p) {
        final active = p == selected;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: InkWell(
            onTap: () => onChanged(p),
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(
                horizontal: ZapSpacing.md, vertical: ZapSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: active
                    ? ZapColors.info.withOpacity(0.18)
                    : ZapColors.bgSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active
                      ? ZapColors.info.withOpacity(0.5)
                      : ZapColors.border,
                ),
              ),
              child: Text(
                p.label,
                style: ZapTypography.labelMedium.copyWith(
                  color:      active ? ZapColors.info : ZapColors.textSecondary,
                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Safety score card ────────────────────────────────────────────────────────

class _SafetyScoreCard extends StatelessWidget {
  const _SafetyScoreCard({required this.score});
  final double score;

  Color get _color {
    if (score >= 80) return ZapColors.safe;
    if (score >= 60) return ZapColors.warning;
    return ZapColors.danger;
  }

  String get _label {
    if (score >= 80) return 'Strong';
    if (score >= 60) return 'Moderate';
    return 'Needs attention';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color:        ZapColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: _color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80, height: 80,
            child: CustomPaint(
              painter: _ArcPainter(score: score, color: _color),
              child: Center(
                child: Text(
                  score.toInt().toString(),
                  style: ZapTypography.headlineMedium.copyWith(
                    color:      _color,
                    fontFamily: 'ClashDisplay',
                    height:     1,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: ZapSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SAFETY SCORE',
                  style: ZapTypography.labelSmall.copyWith(
                    color:         ZapColors.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _label,
                  style: ZapTypography.headlineSmall.copyWith(
                    color:      _color,
                    fontFamily: 'ClashDisplay',
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Contacts · detection settings · response history',
                  style: ZapTypography.bodySmall.copyWith(
                    color:  ZapColors.textMuted,
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

class _ArcPainter extends CustomPainter {
  const _ArcPainter({required this.score, required this.color});
  final double score;
  final Color  color;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeW = 7.0;
    final rect    = Rect.fromLTWH(
      strokeW / 2, strokeW / 2,
      size.width - strokeW, size.height - strokeW,
    );
    const startRad = 135.0 * math.pi / 180.0;
    const totalRad = 270.0 * math.pi / 180.0;

    canvas.drawArc(rect, startRad, totalRad, false,
        Paint()
          ..color       = ZapColors.bgSurface
          ..style       = PaintingStyle.stroke
          ..strokeCap   = StrokeCap.round
          ..strokeWidth = strokeW);
    canvas.drawArc(rect, startRad, totalRad * (score / 100.0), false,
        Paint()
          ..color       = color
          ..style       = PaintingStyle.stroke
          ..strokeCap   = StrokeCap.round
          ..strokeWidth = strokeW);
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.score != score || old.color != color;
}

// ─── Stats row ────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.data});
  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Total\nevents',
            value: data.totalEvents.toString(),
            accent: ZapColors.danger,
            icon: Icons.crisis_alert_rounded,
          ),
        ),
        const SizedBox(width: ZapSpacing.sm),
        Expanded(
          child: _StatCard(
            label: 'False\nalarms',
            value: '${data.falseAlarmPct.toInt()}%',
            accent: ZapColors.warning,
            icon: Icons.do_not_disturb_on_rounded,
          ),
        ),
        const SizedBox(width: ZapSpacing.sm),
        Expanded(
          child: _StatCard(
            label: 'Avg response',
            value: '${data.avgResponseSec}s',
            accent: ZapColors.safe,
            icon: Icons.electric_bolt_rounded,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.accent,
    required this.icon,
  });
  final String   label;
  final String   value;
  final Color    accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color:        ZapColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: accent.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: accent.withOpacity(0.8)),
          const SizedBox(height: ZapSpacing.sm),
          Text(
            value,
            style: ZapTypography.headlineMedium.copyWith(
              color:      ZapColors.textPrimary,
              fontFamily: 'ClashDisplay',
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: ZapTypography.bodySmall.copyWith(
              color:  ZapColors.textSecondary,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.text});
  final IconData icon;
  final String   text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: ZapColors.textSecondary),
        const SizedBox(width: ZapSpacing.xs),
        Text(
          text.toUpperCase(),
          style: ZapTypography.labelSmall.copyWith(
            color:         ZapColors.textSecondary,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }
}

// ─── Day-of-week bar chart ────────────────────────────────────────────────────

class _DayOfWeekChart extends StatefulWidget {
  const _DayOfWeekChart({required this.values});
  final List<double> values;

  @override
  State<_DayOfWeekChart> createState() => _DayOfWeekChartState();
}

class _DayOfWeekChartState extends State<_DayOfWeekChart> {
  int _touched = -1;
  static const _days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final peak = widget.values.reduce((a, b) => a > b ? a : b) + 1.0;
    final maxY = peak < 2.0 ? 2.0 : peak;

    return Container(
      height: 160,
      padding: const EdgeInsets.fromLTRB(
        ZapSpacing.sm, ZapSpacing.md, ZapSpacing.sm, ZapSpacing.md,
      ),
      decoration: BoxDecoration(
        color:        ZapColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: ZapColors.border),
      ),
      child: BarChart(
        BarChartData(
          maxY: maxY,
          barTouchData: BarTouchData(
            touchCallback: (event, response) {
              setState(() {
                if (response?.spot != null &&
                    event is! FlTapUpEvent &&
                    event is! FlPanEndEvent) {
                  _touched = response!.spot!.touchedBarGroupIndex;
                } else {
                  _touched = -1;
                }
              });
            },
            touchTooltipData: BarTouchTooltipData(
              tooltipBgColor: ZapColors.bgElevated,
              getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                rod.toY.toInt().toString(),
                ZapTypography.labelSmall.copyWith(color: ZapColors.textPrimary),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles:   true,
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      _days[i],
                      style: ZapTypography.labelSmall.copyWith(
                        color: _touched == i ? ZapColors.info : ZapColors.textSecondary,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          gridData: FlGridData(
            show:               true,
            drawVerticalLine:   false,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (_) => const FlLine(
              color: ZapColors.border, strokeWidth: 0.5,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(7, (i) {
            final touched = _touched == i;
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY:          widget.values[i],
                  width:        14,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  color:        touched
                      ? ZapColors.info
                      : ZapColors.danger.withOpacity(0.6),
                  backDrawRodData: BackgroundBarChartRodData(
                    show:  true,
                    toY:   maxY,
                    color: ZapColors.bgSurface,
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

// ─── Trend line chart ─────────────────────────────────────────────────────────

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.points});
  final List<double> points;

  @override
  Widget build(BuildContext context) {
    final peak = points.reduce((a, b) => a > b ? a : b) + 1.0;
    final maxY = peak < 2.0 ? 2.0 : peak;
    final spots = List.generate(
      points.length,
      (i) => FlSpot(i.toDouble(), points[i]),
    );

    return Container(
      height: 140,
      padding: const EdgeInsets.fromLTRB(
        ZapSpacing.sm, ZapSpacing.md, ZapSpacing.sm, ZapSpacing.md,
      ),
      decoration: BoxDecoration(
        color:        ZapColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: ZapColors.border),
      ),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY,
          clipData: const FlClipData.all(),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipBgColor: ZapColors.bgElevated,
              getTooltipItems: (spots) => spots
                  .map((s) => LineTooltipItem(
                        s.y.toInt().toString(),
                        ZapTypography.labelSmall
                            .copyWith(color: ZapColors.textPrimary),
                      ))
                  .toList(),
            ),
          ),
          titlesData: const FlTitlesData(
            leftTitles:   AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:  AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:    AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show:               true,
            drawVerticalLine:   false,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (_) => const FlLine(
              color: ZapColors.border, strokeWidth: 0.5,
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots:           spots,
              isCurved:        true,
              curveSmoothness: 0.35,
              color:           ZapColors.info,
              barWidth:        2,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                  radius:      3,
                  color:       ZapColors.info,
                  strokeWidth: 0,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin:  Alignment.topCenter,
                  end:    Alignment.bottomCenter,
                  colors: [
                    ZapColors.info.withOpacity(0.18),
                    ZapColors.info.withOpacity(0.02),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 24-hour heatmap (Day 80 addition) ───────────────────────────────────────
//
// 7 rows (Mon-Sun) × 24 columns (00–23).
// Each cell is colored from transparent (0 events) → ZapColors.danger (max).
// Column labels: every 4 hours (00 04 08 12 16 20).

class _HeatmapPanel extends StatelessWidget {
  const _HeatmapPanel({required this.heatmap});

  final List<List<int>> heatmap; // [dayIndex][hourIndex]

  static const _dayLabels  = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _hourLabels = ['00', '04', '08', '12', '16', '20'];

  int get _maxVal {
    int m = 1;
    for (final row in heatmap) {
      for (final v in row) {
        if (v > m) m = v;
      }
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    final maxV = _maxVal;

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color:        ZapColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: ZapColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hour axis labels
          Padding(
            padding: const EdgeInsets.only(left: 20, bottom: 4),
            child: Row(
              children: List.generate(24, (h) {
                final showLabel = h % 4 == 0;
                return Expanded(
                  child: Text(
                    showLabel ? _hourLabels[h ~/ 4] : '',
                    style: ZapTypography.labelSmall.copyWith(
                      color:    ZapColors.textMuted,
                      fontSize: 8,
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              }),
            ),
          ),

          // Grid rows
          ...List.generate(7, (dayIdx) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 1.5),
              child: Row(
                children: [
                  // Day label
                  SizedBox(
                    width: 20,
                    child: Text(
                      _dayLabels[dayIdx],
                      style: ZapTypography.labelSmall.copyWith(
                        color:    ZapColors.textSecondary,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  // 24 cells
                  ...List.generate(24, (hourIdx) {
                    final val       = heatmap[dayIdx][hourIdx];
                    final intensity = maxV > 0 ? val / maxV : 0.0;
                    return Expanded(
                      child: Container(
                        height:  18,
                        margin:  const EdgeInsets.symmetric(horizontal: 0.5),
                        decoration: BoxDecoration(
                          color: _cellColor(intensity),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          }),

          // Legend
          const SizedBox(height: ZapSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'None',
                style: ZapTypography.labelSmall.copyWith(
                  color: ZapColors.textMuted, fontSize: 9,
                ),
              ),
              const SizedBox(width: 4),
              ...List.generate(5, (i) {
                return Container(
                  width:  12,
                  height: 10,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color:        _cellColor(i / 4.0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
              const SizedBox(width: 4),
              Text(
                'High',
                style: ZapTypography.labelSmall.copyWith(
                  color: ZapColors.textMuted, fontSize: 9,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Color _cellColor(double intensity) {
    if (intensity <= 0) return ZapColors.bgSurface;
    // Low → info tint, high → danger
    if (intensity < 0.4) {
      return ZapColors.info.withOpacity(0.15 + intensity * 0.6);
    }
    return ZapColors.danger.withOpacity(0.2 + intensity * 0.7);
  }
}

// ─── Peak hours ───────────────────────────────────────────────────────────────

class _PeakHoursPanel extends StatelessWidget {
  const _PeakHoursPanel({required this.peakHours, required this.total});

  final List<(String, int)> peakHours;
  final int                 total;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        ZapColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: ZapColors.border),
      ),
      child: Column(
        children: List.generate(peakHours.length, (i) {
          final (hour, count) = peakHours[i];
          final pct    = total > 0 ? count / total : 0.0;
          final isLast = i == peakHours.length - 1;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: ZapSpacing.lg, vertical: ZapSpacing.md,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 24, height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: i == 0
                            ? ZapColors.warning.withOpacity(0.2)
                            : ZapColors.bgSurface,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${i + 1}',
                        style: ZapTypography.labelSmall.copyWith(
                          color: i == 0
                              ? ZapColors.warning
                              : ZapColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: ZapSpacing.md),
                    Text(
                      hour,
                      style: ZapTypography.bodyMedium.copyWith(
                        color:      ZapColors.textPrimary,
                        fontFamily: 'IBMPlexMono',
                      ),
                    ),
                    const SizedBox(width: ZapSpacing.md),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value:      pct.clamp(0.0, 1.0),
                          minHeight:  6,
                          backgroundColor: ZapColors.bgSurface,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            i == 0
                                ? ZapColors.warning.withOpacity(0.8)
                                : ZapColors.danger.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: ZapSpacing.md),
                    Text(
                      count.toString(),
                      style: ZapTypography.labelMedium.copyWith(
                        color:      ZapColors.textSecondary,
                        fontFamily: 'IBMPlexMono',
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                const Divider(
                  color:      ZapColors.divider,
                  height:     1,
                  indent:     ZapSpacing.lg,
                  endIndent:  ZapSpacing.lg,
                ),
            ],
          );
        }),
      ),
    );
  }
}

// ─── Response breakdown ───────────────────────────────────────────────────────

class _ResponseBreakdown extends StatelessWidget {
  const _ResponseBreakdown({required this.tier1Pct, required this.tier2Pct});

  final double tier1Pct;
  final double tier2Pct;

  @override
  Widget build(BuildContext context) {
    final noResponsePct = (100 - tier1Pct - tier2Pct).clamp(0.0, 100.0);
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color:        ZapColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: ZapColors.border),
      ),
      child: Column(
        children: [
          _BreakdownRow(label: 'Tier 1 responded',    pct: tier1Pct,       color: ZapColors.safe),
          const SizedBox(height: ZapSpacing.md),
          _BreakdownRow(label: 'Escalated to Tier 2', pct: tier2Pct,       color: ZapColors.warning),
          const SizedBox(height: ZapSpacing.md),
          _BreakdownRow(label: 'No response',          pct: noResponsePct,  color: ZapColors.textMuted),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,
    required this.pct,
    required this.color,
  });
  final String label;
  final double pct;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: ZapTypography.bodySmall.copyWith(color: ZapColors.textSecondary)),
            Text(
              '${pct.toInt()}%',
              style: ZapTypography.labelMedium.copyWith(
                color: color, fontFamily: 'IBMPlexMono',
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value:           (pct / 100).clamp(0.0, 1.0),
            minHeight:       8,
            backgroundColor: ZapColors.bgSurface,
            valueColor:      AlwaysStoppedAnimation<Color>(color.withOpacity(0.75)),
          ),
        ),
      ],
    );
  }
}

// ─── Detection type breakdown ─────────────────────────────────────────────────

class _DetectionTypeBreakdown extends StatelessWidget {
  const _DetectionTypeBreakdown({
    required this.screamCount,
    required this.motionCount,
    required this.sceneCount,
    required this.total,
  });
  final int screamCount;
  final int motionCount;
  final int sceneCount;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color:        ZapColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: ZapColors.border),
      ),
      child: Column(
        children: [
          _DetectionRow(icon: Icons.graphic_eq_rounded,    label: 'Scream detected', count: screamCount, total: total, color: ZapColors.danger),
          const SizedBox(height: ZapSpacing.md),
          _DetectionRow(icon: Icons.directions_run_rounded, label: 'Motion detected', count: motionCount, total: total, color: ZapColors.info),
          const SizedBox(height: ZapSpacing.md),
          _DetectionRow(icon: Icons.panorama_rounded,       label: 'Scene analyzed',  count: sceneCount,  total: total, color: ZapColors.warning),
        ],
      ),
    );
  }
}

class _DetectionRow extends StatelessWidget {
  const _DetectionRow({
    required this.icon,
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });
  final IconData icon;
  final String   label;
  final int      count;
  final int      total;
  final Color    color;

  @override
  Widget build(BuildContext context) {
    final fraction = total > 0 ? count / total : 0.0;
    return Row(
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color:        color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: ZapSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label, style: ZapTypography.bodySmall.copyWith(color: ZapColors.textSecondary)),
                  Text(
                    count.toString(),
                    style: ZapTypography.labelMedium.copyWith(
                      color: color, fontFamily: 'IBMPlexMono',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value:           fraction.clamp(0.0, 1.0),
                  minHeight:       6,
                  backgroundColor: ZapColors.bgSurface,
                  valueColor:      AlwaysStoppedAnimation<Color>(color.withOpacity(0.65)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyDashboard extends StatelessWidget {
  const _EmptyDashboard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: ZapSpacing.xxxl * 2, horizontal: ZapSpacing.xl,
      ),
      decoration: BoxDecoration(
        color:        ZapColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: ZapColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color:        ZapColors.bgSurface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.bar_chart_rounded, size: 28, color: ZapColors.textMuted),
          ),
          const SizedBox(height: ZapSpacing.lg),
          Text(
            'No alerts in this period',
            style: ZapTypography.headlineSmall.copyWith(color: ZapColors.textPrimary),
          ),
          const SizedBox(height: ZapSpacing.sm),
          Text(
            "That's a good sign. Charts appear once\nyour first alert is recorded.",
            textAlign: TextAlign.center,
            style: ZapTypography.bodyMedium.copyWith(
              color: ZapColors.textMuted, height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
