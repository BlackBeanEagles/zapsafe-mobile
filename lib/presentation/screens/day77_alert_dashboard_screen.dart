/// Day 77-78 — Alert Dashboard (Day 78: safety score, detection breakdown, empty state)
///
/// Aggregated statistics and trend charts for the user's SOS activity.
///
/// ── What it shows ─────────────────────────────────────────────────────────────
///   • Period selector: 7-day / 30-day / 90-day
///   • Stats row: total events · false-alarm % · avg contact-response time
///   • Bar chart: events by day of week (Mon–Sun)
///   • Line chart: event count trend over the selected period
///   • Peak-hours panel: top 3 times of day with most alerts
///   • Response breakdown: horizontal bars for Tier 1 / Tier 2 / No response
///
/// ── Data source ───────────────────────────────────────────────────────────────
///   Backend dashboard API is scheduled for Days 81-85.  Until then the
///   screen renders realistic sample data so the full layout is testable.
///   A `_DashboardData` model is ready to receive real API responses; swap
///   `_sampleData()` for an API call when the endpoint is live.
///
/// ── Dependencies ──────────────────────────────────────────────────────────────
///   fl_chart ^0.63.0  — already in pubspec.yaml
library;

import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';

// ─── Period selector ──────────────────────────────────────────────────────────

enum _Period { week, month, quarter }

extension _PeriodLabel on _Period {
  String get label {
    switch (this) {
      case _Period.week:    return '7 days';
      case _Period.month:   return '30 days';
      case _Period.quarter: return '90 days';
    }
  }
}

// ─── Data model ───────────────────────────────────────────────────────────────

class _DashboardData {
  const _DashboardData({
    required this.totalEvents,
    required this.falseAlarmPct,
    required this.avgResponseSec,
    required this.byDayOfWeek,     // Mon=0 … Sun=6, count per day
    required this.trendPoints,     // ordered time-series counts
    required this.peakHours,       // [(hourLabel, count), ...]
    required this.tier1Pct,
    required this.tier2Pct,
    // Day 78 additions ─────────────────────────────────
    required this.safetyScore,     // 0–100 composite score
    required this.screamCount,     // detection events by type
    required this.motionCount,
    required this.sceneCount,
  });

  final int      totalEvents;
  final double   falseAlarmPct;    // 0–100
  final int      avgResponseSec;
  final List<double> byDayOfWeek;  // 7 values
  final List<double> trendPoints;  // N values for the selected period
  final List<(String, int)> peakHours;
  final double   tier1Pct;         // responded at tier 1
  final double   tier2Pct;         // escalated to tier 2
  // Day 78
  final double   safetyScore;
  final int      screamCount;
  final int      motionCount;
  final int      sceneCount;
}

// ─── Sample data factory ──────────────────────────────────────────────────────

_DashboardData _sampleData(_Period period) {
  switch (period) {
    case _Period.week:
      return const _DashboardData(
        totalEvents:    4,
        falseAlarmPct:  25,
        avgResponseSec: 38,
        byDayOfWeek:    [0, 0, 1, 0, 1, 1, 1],
        trendPoints:    [0, 1, 0, 0, 1, 1, 1],
        peakHours: [('22:00', 2), ('10:00', 1), ('07:00', 1)],
        tier1Pct:  75,
        tier2Pct:  25,
        safetyScore:  87,
        screamCount:  2,
        motionCount:  1,
        sceneCount:   1,
      );
    case _Period.month:
      return const _DashboardData(
        totalEvents:    11,
        falseAlarmPct:  18,
        avgResponseSec: 45,
        byDayOfWeek:    [1, 2, 1, 0, 2, 3, 2],
        trendPoints:    [1, 0, 2, 1, 1, 0, 1, 2, 1, 0, 1, 1],
        peakHours: [('22:00', 4), ('09:00', 3), ('21:00', 2)],
        tier1Pct:  64,
        tier2Pct:  36,
        safetyScore:  82,
        screamCount:  5,
        motionCount:  4,
        sceneCount:   2,
      );
    case _Period.quarter:
      return const _DashboardData(
        totalEvents:    28,
        falseAlarmPct:  14,
        avgResponseSec: 52,
        byDayOfWeek:    [3, 4, 4, 2, 5, 6, 4],
        trendPoints:    [2, 3, 1, 4, 3, 2, 4, 5, 2, 3, 1, 4, 2, 3, 5, 3],
        peakHours: [('22:00', 9), ('09:00', 7), ('21:00', 5)],
        tier1Pct:  61,
        tier2Pct:  39,
        safetyScore:  78,
        screamCount:  12,
        motionCount:  10,
        sceneCount:   6,
      );
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class Day77AlertDashboardScreen extends StatefulWidget {
  const Day77AlertDashboardScreen({super.key});

  @override
  State<Day77AlertDashboardScreen> createState() =>
      _Day77AlertDashboardScreenState();
}

class _Day77AlertDashboardScreenState
    extends State<Day77AlertDashboardScreen> {

  _Period _period = _Period.week;

  @override
  Widget build(BuildContext context) {
    final data = _sampleData(_period);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: ZapColors.bgPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: const BackButton(color: ZapColors.textPrimary),
        title: Text(
          'Activity Overview',
          style: ZapTypography.headlineSmall.copyWith(color: ZapColors.textPrimary),
        ),
        actions: [
          // Sample-data badge — remove when real API is wired
          Container(
            margin: const EdgeInsets.only(right: ZapSpacing.md),
            padding: const EdgeInsets.symmetric(
              horizontal: ZapSpacing.sm,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: ZapColors.warning.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: ZapColors.warning.withOpacity(0.4),
                width: 0.5,
              ),
            ),
            child: Text(
              'SAMPLE',
              style: ZapTypography.labelSmall.copyWith(
                color: ZapColors.warning,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(
          left: ZapSpacing.lg,
          right: ZapSpacing.lg,
          bottom: ZapSpacing.xxxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: ZapSpacing.md),

            // ── Period selector ─────────────────────────────────────────
            _PeriodSelector(
              selected: _period,
              onChanged: (p) => setState(() => _period = p),
            ),

            const SizedBox(height: ZapSpacing.xl),

            // ── Safety Score (Day 78) ───────────────────────────────────
            _SafetyScoreCard(score: data.safetyScore),

            const SizedBox(height: ZapSpacing.xl),

            // ── Stats row ───────────────────────────────────────────────
            _StatsRow(data: data),

            const SizedBox(height: ZapSpacing.xl),

            if (data.totalEvents == 0) ...[
              // ── Empty state ───────────────────────────────────────────
              const _EmptyDashboard(),
            ] else ...[
              // ── Bar chart: events by day of week ─────────────────────
              const _SectionLabel(
                icon: Icons.bar_chart_rounded,
                text: 'Events by day of week',
              ),
              const SizedBox(height: ZapSpacing.md),
              _DayOfWeekChart(values: data.byDayOfWeek),

              const SizedBox(height: ZapSpacing.xl),

              // ── Line chart: trend ─────────────────────────────────────
              _SectionLabel(
                icon: Icons.show_chart_rounded,
                text: 'Trend — ${_period.label}',
              ),
              const SizedBox(height: ZapSpacing.md),
              _TrendChart(points: data.trendPoints),

              const SizedBox(height: ZapSpacing.xl),

              // ── Peak hours ────────────────────────────────────────────
              const _SectionLabel(
                icon: Icons.access_time_rounded,
                text: 'Peak hours',
              ),
              const SizedBox(height: ZapSpacing.md),
              _PeakHoursPanel(peakHours: data.peakHours, total: data.totalEvents),

              const SizedBox(height: ZapSpacing.xl),

              // ── Response breakdown ────────────────────────────────────
              const _SectionLabel(
                icon: Icons.people_alt_rounded,
                text: 'Contact response',
              ),
              const SizedBox(height: ZapSpacing.md),
              _ResponseBreakdown(tier1Pct: data.tier1Pct, tier2Pct: data.tier2Pct),

              const SizedBox(height: ZapSpacing.xl),

              // ── Detection type breakdown (Day 78) ─────────────────────
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
      ),
    );
  }
}

// ─── Period selector ──────────────────────────────────────────────────────────

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({
    required this.selected,
    required this.onChanged,
  });

  final _Period         selected;
  final void Function(_Period) onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: _Period.values.map((p) {
        final active = p == selected;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: InkWell(
            onTap: () => onChanged(p),
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(
                horizontal: ZapSpacing.md,
                vertical: ZapSpacing.sm,
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
                  width: 1,
                ),
              ),
              child: Text(
                p.label,
                style: ZapTypography.labelMedium.copyWith(
                  color: active ? ZapColors.info : ZapColors.textSecondary,
                  fontWeight:
                      active ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Stats row ────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.data});
  final _DashboardData data;

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

  final String label;
  final String value;
  final Color  accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withOpacity(0.25), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: accent.withOpacity(0.8)),
          const SizedBox(height: ZapSpacing.sm),
          Text(
            value,
            style: ZapTypography.headlineMedium.copyWith(
              color: ZapColors.textPrimary,
              fontFamily: 'ClashDisplay',
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: ZapTypography.bodySmall.copyWith(
              color: ZapColors.textSecondary,
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
            color: ZapColors.textSecondary,
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
  final List<double> values; // 7 entries: Mon=0 … Sun=6

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
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZapColors.border, width: 1),
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
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  rod.toY.toInt().toString(),
                  ZapTypography.labelSmall.copyWith(color: ZapColors.textPrimary),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      _days[i],
                      style: ZapTypography.labelSmall.copyWith(
                        color: _touched == i
                            ? ZapColors.info
                            : ZapColors.textSecondary,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (_) => const FlLine(
              color: ZapColors.border,
              strokeWidth: 0.5,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(7, (i) {
            final touched = _touched == i;
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: widget.values[i],
                  width: 14,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                  color: touched
                      ? ZapColors.info
                      : ZapColors.danger.withOpacity(0.6),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxY,
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
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZapColors.border, width: 1),
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
                  .map(
                    (s) => LineTooltipItem(
                      s.y.toInt().toString(),
                      ZapTypography.labelSmall
                          .copyWith(color: ZapColors.textPrimary),
                    ),
                  )
                  .toList(),
            ),
          ),
          titlesData: const FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1,
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
              curveSmoothness: 0.35,
              color: ZapColors.info,
              barWidth: 2,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                  radius: 3,
                  color: ZapColors.info,
                  strokeWidth: 0,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
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

// ─── Peak hours ───────────────────────────────────────────────────────────────

class _PeakHoursPanel extends StatelessWidget {
  const _PeakHoursPanel({
    required this.peakHours,
    required this.total,
  });

  final List<(String, int)> peakHours;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZapColors.border, width: 1),
      ),
      child: Column(
        children: List.generate(peakHours.length, (i) {
          final (hour, count) = peakHours[i];
          final pct = total > 0 ? count / total : 0.0;
          final isLast = i == peakHours.length - 1;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: ZapSpacing.lg,
                  vertical: ZapSpacing.md,
                ),
                child: Row(
                  children: [
                    // Rank badge
                    Container(
                      width: 24,
                      height: 24,
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
                    // Hour
                    Text(
                      hour,
                      style: ZapTypography.bodyMedium.copyWith(
                        color: ZapColors.textPrimary,
                        fontFamily: 'IBMPlexMono',
                      ),
                    ),
                    const SizedBox(width: ZapSpacing.md),
                    // Frequency bar
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: pct.clamp(0.0, 1.0),
                          minHeight: 6,
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
                    // Count
                    Text(
                      count.toString(),
                      style: ZapTypography.labelMedium.copyWith(
                        color: ZapColors.textSecondary,
                        fontFamily: 'IBMPlexMono',
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                const Divider(
                  color: ZapColors.divider,
                  height: 1,
                  indent: ZapSpacing.lg,
                  endIndent: ZapSpacing.lg,
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
  const _ResponseBreakdown({
    required this.tier1Pct,
    required this.tier2Pct,
  });

  final double tier1Pct;
  final double tier2Pct;

  @override
  Widget build(BuildContext context) {
    final noResponsePct = (100 - tier1Pct - tier2Pct).clamp(0.0, 100.0);

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZapColors.border, width: 1),
      ),
      child: Column(
        children: [
          _BreakdownRow(
            label: 'Tier 1 responded',
            pct: tier1Pct,
            color: ZapColors.safe,
          ),
          const SizedBox(height: ZapSpacing.md),
          _BreakdownRow(
            label: 'Escalated to Tier 2',
            pct: tier2Pct,
            color: ZapColors.warning,
          ),
          const SizedBox(height: ZapSpacing.md),
          _BreakdownRow(
            label: 'No response',
            pct: noResponsePct,
            color: ZapColors.textMuted,
          ),
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
            Text(
              label,
              style: ZapTypography.bodySmall.copyWith(
                color: ZapColors.textSecondary,
              ),
            ),
            Text(
              '${pct.toInt()}%',
              style: ZapTypography.labelMedium.copyWith(
                color: color,
                fontFamily: 'IBMPlexMono',
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: (pct / 100).clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: ZapColors.bgSurface,
            valueColor: AlwaysStoppedAnimation<Color>(
              color.withOpacity(0.75),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Safety Score card (Day 78) ───────────────────────────────────────────────

class _SafetyScoreCard extends StatelessWidget {
  const _SafetyScoreCard({required this.score});
  final double score; // 0–100

  Color get _scoreColor {
    if (score >= 80) return ZapColors.safe;
    if (score >= 60) return ZapColors.warning;
    return ZapColors.danger;
  }

  String get _scoreLabel {
    if (score >= 80) return 'Strong';
    if (score >= 60) return 'Moderate';
    return 'Needs attention';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _scoreColor.withOpacity(0.25),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Circular arc gauge
          SizedBox(
            width: 80,
            height: 80,
            child: CustomPaint(
              painter: _ScoreArcPainter(score: score, color: _scoreColor),
              child: Center(
                child: Text(
                  score.toInt().toString(),
                  style: ZapTypography.headlineMedium.copyWith(
                    color: _scoreColor,
                    fontFamily: 'ClashDisplay',
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: ZapSpacing.lg),
          // Labels
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Safety Score',
                  style: ZapTypography.labelSmall.copyWith(
                    color: ZapColors.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _scoreLabel,
                  style: ZapTypography.headlineSmall.copyWith(
                    color: _scoreColor,
                    fontFamily: 'ClashDisplay',
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Based on contacts, detection settings & response history',
                  style: ZapTypography.bodySmall.copyWith(
                    color: ZapColors.textMuted,
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

// Draws a 270° arc (135° start → 45° end, clockwise) with a fill up to `score`.
class _ScoreArcPainter extends CustomPainter {
  const _ScoreArcPainter({required this.score, required this.color});
  final double score; // 0–100
  final Color  color;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeW  = 7.0;
    final rect     = Rect.fromLTWH(
      strokeW / 2,
      strokeW / 2,
      size.width  - strokeW,
      size.height - strokeW,
    );
    const startRad = 135.0 * math.pi / 180.0;
    const totalRad = 270.0 * math.pi / 180.0;

    final bgPaint = Paint()
      ..color       = ZapColors.bgSurface
      ..style       = PaintingStyle.stroke
      ..strokeCap   = StrokeCap.round
      ..strokeWidth = strokeW;

    final fgPaint = Paint()
      ..color       = color
      ..style       = PaintingStyle.stroke
      ..strokeCap   = StrokeCap.round
      ..strokeWidth = strokeW;

    canvas.drawArc(rect, startRad, totalRad, false, bgPaint);
    canvas.drawArc(rect, startRad, totalRad * (score / 100.0), false, fgPaint);
  }

  @override
  bool shouldRepaint(_ScoreArcPainter old) =>
      old.score != score || old.color != color;
}

// ─── Detection type breakdown (Day 78) ───────────────────────────────────────

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
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZapColors.border, width: 1),
      ),
      child: Column(
        children: [
          _DetectionRow(
            icon: Icons.graphic_eq_rounded,
            label: 'Scream detected',
            count: screamCount,
            total: total,
            color: ZapColors.danger,
          ),
          const SizedBox(height: ZapSpacing.md),
          _DetectionRow(
            icon: Icons.directions_run_rounded,
            label: 'Motion detected',
            count: motionCount,
            total: total,
            color: ZapColors.info,
          ),
          const SizedBox(height: ZapSpacing.md),
          _DetectionRow(
            icon: Icons.panorama_rounded,
            label: 'Scene analyzed',
            count: sceneCount,
            total: total,
            color: ZapColors.warning,
          ),
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
        // Icon badge
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color:        color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: ZapSpacing.md),
        // Label + bar
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: ZapTypography.bodySmall.copyWith(
                      color: ZapColors.textSecondary,
                    ),
                  ),
                  Text(
                    count.toString(),
                    style: ZapTypography.labelMedium.copyWith(
                      color: color,
                      fontFamily: 'IBMPlexMono',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: fraction.clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: ZapColors.bgSurface,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    color.withOpacity(0.65),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Empty state (Day 78) ─────────────────────────────────────────────────────

class _EmptyDashboard extends StatelessWidget {
  const _EmptyDashboard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: ZapSpacing.xxxl * 2,
        horizontal: ZapSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZapColors.border, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: ZapColors.bgSurface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.bar_chart_rounded,
              size: 28,
              color: ZapColors.textMuted,
            ),
          ),
          const SizedBox(height: ZapSpacing.lg),
          Text(
            'No alerts in this period',
            style: ZapTypography.headlineSmall.copyWith(
              color: ZapColors.textPrimary,
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          Text(
            "That's a good sign. Charts will appear\nonce your first alert is recorded.",
            textAlign: TextAlign.center,
            style: ZapTypography.bodyMedium.copyWith(
              color: ZapColors.textMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
