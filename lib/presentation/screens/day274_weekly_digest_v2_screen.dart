/// Day 274 — Weekly Digest v2
///
/// Section D (Days 261-280): enhanced weekly safety digest with charts,
/// streak tracking, and drill reminders — polish over Day 19 digest concept.
///
/// Tag: 🟣 POLISH · GET /api/v1/digest/weekly/ (mock).
///
/// Route: [AppRoutes.weeklyDigestV2] → `/weekly-digest-v2`
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
const _kAccent = Color(0xFFA855F7);
const _kTabs = ['Digest', 'Streaks', 'Info'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');

const _kWeekLabel = '3 – 9 Mar 2026';
const _kDailyActivity = [1.0, 2.0, 1.0, 3.0, 2.0, 4.0, 3.0];
const _kDailyScores = [80.0, 81.0, 82.0, 83.0, 84.0, 85.0, 86.0];
const _kDayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

class _StreakInfo {
  const _StreakInfo({
    required this.id,
    required this.label,
    required this.weeks,
    required this.icon,
    required this.color,
  });

  final String id;
  final String label;
  final int weeks;
  final IconData icon;
  final Color color;
}

const _kStreaks = [
  _StreakInfo(
    id: 'drill',
    label: 'Safety drill streak',
    weeks: 4,
    icon: Icons.fitness_center_rounded,
    color: ZapColors.safe,
  ),
  _StreakInfo(
    id: 'journey',
    label: 'Journey check-in streak',
    weeks: 2,
    icon: Icons.directions_walk_rounded,
    color: _kAccent,
  ),
  _StreakInfo(
    id: 'score',
    label: 'Score improvement streak',
    weeks: 3,
    icon: Icons.trending_up_rounded,
    color: ZapColors.info,
  ),
];

const _kHighlights = [
  'Protection score up 5 pts vs last week (81 → 86).',
  '3 journeys completed · longest HSR → Airport (58 min).',
  '2 safety drills finished · 1 drill missed on Wednesday.',
  'Zero SOS activations · 1 false alarm resolved quickly.',
  'Community heatmap: 1 anonymous near-miss contributed.',
];

// ── Providers ─────────────────────────────────────────────────────────────────
final _d274TabProvider = StateProvider<int>((ref) => 0);
final _d274DrillReminderProvider = StateProvider<bool>((ref) => true);
final _d274DrillDoneProvider = StateProvider<bool>((ref) => false);
final _d274DrillSnoozedProvider = StateProvider<bool>((ref) => false);

// ── Screen ────────────────────────────────────────────────────────────────────
class Day274WeeklyDigestV2Screen extends ConsumerWidget {
  const Day274WeeklyDigestV2Screen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drillDone = ref.watch(_d274DrillDoneProvider);
    final drillSnoozed = ref.watch(_d274DrillSnoozedProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 274 · Weekly Digest v2'),
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
                  drillDone
                      ? 'DRILL ✅'
                      : drillSnoozed
                          ? 'SNOOZED'
                          : 'MAR 3-9',
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
            tab: ref.watch(_d274TabProvider),
            onSelect: (i) => ref.read(_d274TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (ref.watch(_d274TabProvider)) {
              0 => const _DigestTab(),
              1 => const _StreaksTab(),
              _ => const _InfoTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Digest ─────────────────────────────────────────────────────────────
class _DigestTab extends ConsumerWidget {
  const _DigestTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drillDone = ref.watch(_d274DrillDoneProvider);
    final drillSnoozed = ref.watch(_d274DrillSnoozedProvider);
    final reminderOn = ref.watch(_d274DrillReminderProvider);

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
            '🟣 POLISH · Section D Day 14/20 · weekly digest v2 · charts · streaks · drill reminders',
            style: TextStyle(color: _kAccent, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_kAccent.withOpacity(0.2), _kAccent.withOpacity(0.05)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kAccent.withOpacity(0.35)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Week of $_kWeekLabel',
                style: TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: ZapSpacing.xs),
              Text(
                'Your safety week at a glance · mock digest',
                style: TextStyle(color: ZapColors.textSecondary, fontSize: 12),
              ),
              SizedBox(height: ZapSpacing.sm),
              Row(
                children: [
                  _MiniStat(label: 'Score', value: '86', color: ZapColors.safe),
                  SizedBox(width: ZapSpacing.sm),
                  _MiniStat(label: 'Journeys', value: '3', color: _kAccent),
                  SizedBox(width: ZapSpacing.sm),
                  _MiniStat(
                      label: 'Drills', value: '2/3', color: ZapColors.warning),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const _SectionTitle(
            title: 'Daily activity', subtitle: 'Journeys + drills'),
        const _DigestBarChart(values: _kDailyActivity),
        const SizedBox(height: ZapSpacing.lg),
        const _SectionTitle(
            title: 'Score trend', subtitle: 'Protection score this week'),
        const _DigestLineChart(values: _kDailyScores),
        const SizedBox(height: ZapSpacing.lg),
        const _SectionTitle(
            title: 'Highlights', subtitle: 'Top moments from your week'),
        ..._kHighlights.map(
          (h) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_outline_rounded,
                    size: 14, color: _kAccent),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    h,
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
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: drillDone
                ? ZapColors.safe.withOpacity(0.08)
                : ZapColors.warning.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: drillDone
                  ? ZapColors.safe.withOpacity(0.35)
                  : ZapColors.warning.withOpacity(0.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    drillDone
                        ? Icons.verified_rounded
                        : Icons.notifications_active_rounded,
                    color: drillDone ? ZapColors.safe : ZapColors.warning,
                  ),
                  const SizedBox(width: ZapSpacing.sm),
                  Expanded(
                    child: Text(
                      drillDone
                          ? 'Weekly drill complete'
                          : drillSnoozed
                              ? 'Drill reminder snoozed until tomorrow'
                              : 'Drill reminder · due this week',
                      style: const TextStyle(
                        color: ZapColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                reminderOn
                    ? 'Push reminder enabled · category digest + drill'
                    : 'Reminders off · enable in notification prefs',
                style: const TextStyle(
                  color: ZapColors.textSecondary,
                  fontSize: 11,
                ),
              ),
              if (!drillDone) ...[
                const SizedBox(height: ZapSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          ref.read(_d274DrillDoneProvider.notifier).state =
                              true;
                          ref.read(_d274DrillSnoozedProvider.notifier).state =
                              false;
                          HapticFeedback.mediumImpact();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Drill marked complete (mock).'),
                            ),
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: ZapColors.safe,
                        ),
                        child: const Text('Mark drill done'),
                      ),
                    ),
                    const SizedBox(width: ZapSpacing.sm),
                    OutlinedButton(
                      onPressed: drillSnoozed
                          ? null
                          : () {
                              ref
                                  .read(_d274DrillSnoozedProvider.notifier)
                                  .state = true;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Drill reminder snoozed 24h (mock).'),
                                ),
                              );
                            },
                      child: const Text('Snooze'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: ZapSpacing.sm),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: ZapColors.textMuted, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

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
            style:
                const TextStyle(color: ZapColors.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _DigestBarChart extends StatelessWidget {
  const _DigestBarChart({required this.values});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    final maxY = values.reduce((a, b) => a > b ? a : b) + 1;

    return Container(
      height: 140,
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
                reservedSize: 20,
                getTitlesWidget: (value, meta) => Text(
                  _kDayLabels[value.toInt()],
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
                  width: 12,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(4)),
                  color: _kAccent.withOpacity(i == 5 ? 1 : 0.65),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _DigestLineChart extends StatelessWidget {
  const _DigestLineChart({required this.values});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    final minY = values.first - 2;
    final maxY = values.last + 2;
    final spots = List.generate(
      values.length,
      (i) => FlSpot(i.toDouble(), values[i]),
    );

    return Container(
      height: 130,
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
          titlesData: const FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
              color: ZapColors.safe,
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: ZapColors.safe.withOpacity(0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tab 1: Streaks ────────────────────────────────────────────────────────────
class _StreaksTab extends ConsumerWidget {
  const _StreaksTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminderOn = ref.watch(_d274DrillReminderProvider);
    final drillDone = ref.watch(_d274DrillDoneProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        ..._kStreaks.map((streak) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: streak.color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: streak.color.withOpacity(0.35)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: streak.color.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(streak.icon, color: streak.color),
                ),
                const SizedBox(width: ZapSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        streak.label,
                        style: const TextStyle(
                          color: ZapColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '${streak.weeks} week streak · keep it going',
                        style: const TextStyle(
                          color: ZapColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${streak.weeks}🔥',
                  style: TextStyle(
                    color: streak.color,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: ZapSpacing.lg),
        const _SectionTitle(
          title: 'Drill calendar',
          subtitle: 'This week · green = completed · grey = missed',
        ),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ZapColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (i) {
              final done = i != 2 && (i != 6 || drillDone);
              final missed = i == 2;
              final color = done
                  ? ZapColors.safe
                  : missed
                      ? ZapColors.danger
                      : ZapColors.textMuted;
              return Column(
                children: [
                  Text(
                    _kDayLabels[i],
                    style: const TextStyle(
                      color: ZapColors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: ZapSpacing.xs),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: color),
                    ),
                    child: Icon(
                      done
                          ? Icons.check_rounded
                          : missed
                              ? Icons.close_rounded
                              : Icons.schedule_rounded,
                      size: 14,
                      color: color,
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Weekly drill reminders',
            style: TextStyle(color: ZapColors.textPrimary),
          ),
          subtitle: const Text(
            'Synced with notification prefs · digest + drill categories',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 11),
          ),
          value: reminderOn,
          activeColor: _kAccent,
          onChanged: (v) {
            ref.read(_d274DrillReminderProvider.notifier).state = v;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  v
                      ? 'Drill reminders enabled (mock).'
                      : 'Drill reminders disabled (mock).',
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ── Tab 2: Info ───────────────────────────────────────────────────────────────
class _InfoTab extends ConsumerWidget {
  const _InfoTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drillDone = ref.watch(_d274DrillDoneProvider);
    final reminderOn = ref.watch(_d274DrillReminderProvider);

    final payload = {
      'endpoint': 'GET /api/v1/digest/weekly/',
      'week': _kWeekLabel,
      'protection_score': 86,
      'score_delta': '+5',
      'journeys': 3,
      'drills_completed': drillDone ? 3 : 2,
      'drill_reminder_enabled': reminderOn,
      'streaks': _kStreaks.map((s) => {'id': s.id, 'weeks': s.weeks}).toList(),
      'enhancements_vs_v1': [
        'fl_chart daily activity + score trend',
        'streak cards with fire counter',
        'drill reminder snooze + mark done',
      ],
      'notification_categories': ['digest', 'drill'],
    };

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _PolicyRow(
          icon: Icons.newspaper_rounded,
          title: 'Weekly digest v2',
          subtitle:
              'Polished recap of journeys, drills, score trend, and highlights · '
              'extends Day 19 digest concept with charts.',
        ),
        const _PolicyRow(
          icon: Icons.local_fire_department_rounded,
          title: 'Streaks & drill reminders',
          subtitle:
              'Multi-streak tracking · weekly drill calendar · snooze/mark done · '
              'toggle synced with Day 67 notification prefs mock.',
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
              const SnackBar(content: Text('Weekly digest spec copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy digest spec'),
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
              label: const Text('Day 273 Personal Analytics'),
              onPressed: () => context.push(AppRoutes.personalAnalyticsHub),
            ),
            ActionChip(
              label: const Text('Day 67 Notification Prefs'),
              onPressed: () => context.push(AppRoutes.notificationPrefs),
            ),
            ActionChip(
              label: const Text('Day 259 Smart Notifications'),
              onPressed: () => context.push(AppRoutes.smartNotifications),
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
