/// Day 275 — Year in Review (Gamified)
///
/// Section D (Days 261-280): annual safety recap with summary card,
/// gamified badges, and mock share — frontend-only mock data.
///
/// Tag: 🟢 FRONTEND-ONLY · no backend required for demo.
///
/// Route: [AppRoutes.yearInReview] → `/year-in-review`
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const _kAccent = Color(0xFFF59E0B);
const _kTabs = ['Summary', 'Badges', 'Info'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');
const _kYearLabel = '2025';
const _kMonthlyJourneys = [
  2.0, 3.0, 4.0, 5.0, 3.0, 4.0, 6.0, 5.0, 4.0, 3.0, 5.0, 4.0,
];
const _kMonthLabels = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];

class _BadgeInfo {
  const _BadgeInfo({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.earned,
    this.earnedOn,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool earned;
  final String? earnedOn;
}

const _kBadges = [
  _BadgeInfo(
    id: 'first_journey',
    title: 'First Journey',
    subtitle: 'Completed your first tracked journey.',
    icon: Icons.directions_walk_rounded,
    color: ZapColors.safe,
    earned: true,
    earnedOn: '12 Jan 2025',
  ),
  _BadgeInfo(
    id: 'drill_master',
    title: 'Drill Master',
    subtitle: 'Finished 10 safety drills in one year.',
    icon: Icons.fitness_center_rounded,
    color: _kAccent,
    earned: true,
    earnedOn: '3 Mar 2025',
  ),
  _BadgeInfo(
    id: 'night_guardian',
    title: 'Night Guardian',
    subtitle: '5 safe night journeys after 22:00.',
    icon: Icons.nightlight_round_rounded,
    color: Color(0xFF6366F1),
    earned: true,
    earnedOn: '18 Apr 2025',
  ),
  _BadgeInfo(
    id: 'streak_champion',
    title: 'Streak Champion',
    subtitle: '4-week protection score improvement streak.',
    icon: Icons.local_fire_department_rounded,
    color: Color(0xFFEA580C),
    earned: true,
    earnedOn: '9 Jun 2025',
  ),
  _BadgeInfo(
    id: 'community_hero',
    title: 'Community Hero',
    subtitle: 'Contributed anonymous near-miss to heatmap.',
    icon: Icons.groups_rounded,
    color: Color(0xFF10B981),
    earned: true,
    earnedOn: '22 Jul 2025',
  ),
  _BadgeInfo(
    id: 'perfect_month',
    title: 'Perfect Month',
    subtitle: '30 consecutive days with score above 80.',
    icon: Icons.calendar_month_rounded,
    color: Color(0xFF0891B2),
    earned: true,
    earnedOn: '1 Sep 2025',
  ),
  _BadgeInfo(
    id: 'score_90',
    title: 'Score 90+',
    subtitle: 'Reached protection score of 90 or higher.',
    icon: Icons.shield_rounded,
    color: ZapColors.info,
    earned: true,
    earnedOn: '14 Oct 2025',
  ),
  _BadgeInfo(
    id: 'year_one',
    title: 'Year One Guardian',
    subtitle: 'Stayed active on ZapSafe for a full year.',
    icon: Icons.emoji_events_rounded,
    color: _kAccent,
    earned: true,
    earnedOn: '31 Dec 2025',
  ),
  _BadgeInfo(
    id: 'global_citizen',
    title: 'Global Citizen',
    subtitle: 'Use 3+ locale packs in the same month.',
    icon: Icons.language_rounded,
    color: Color(0xFF7C3AED),
    earned: false,
  ),
  _BadgeInfo(
    id: 'family_shield',
    title: 'Family Shield',
    subtitle: 'Enable family alerts for 3+ members.',
    icon: Icons.family_restroom_rounded,
    color: Color(0xFFDC2626),
    earned: false,
  ),
  _BadgeInfo(
    id: 'zero_incidents',
    title: 'Zero Incidents',
    subtitle: '365 days with no SOS activation.',
    icon: Icons.verified_user_rounded,
    color: ZapColors.safe,
    earned: false,
  ),
  _BadgeInfo(
    id: 'legend',
    title: 'Legend Status',
    subtitle: 'Earn all other badges in one year.',
    icon: Icons.military_tech_rounded,
    color: Color(0xFFCA8A04),
    earned: false,
  ),
];

const _kHighlights = [
  '298 days protected · 82 avg protection score (+14 vs 2024).',
  '47 journeys tracked · longest HSR → Airport (58 min).',
  '31 safety drills completed · best streak: 4 weeks.',
  'Zero SOS activations · 2 false alarms resolved quickly.',
  '8 badges earned · 4 more within reach for 2026.',
];

Map<String, dynamic> _yearPayload(bool celebrate) => {
      'endpoint': 'GET /api/v1/digest/yearly/',
      'year': _kYearLabel,
      'days_protected': 298,
      'journeys': 47,
      'avg_protection_score': 82,
      'drills_completed': 31,
      'badges_earned': _kBadges.where((b) => b.earned).length,
      'badges_total': _kBadges.length,
      'celebrate_mode': celebrate,
      'monthly_journeys': _kMonthlyJourneys,
      'badges': _kBadges
          .map((b) => {
                'id': b.id,
                'earned': b.earned,
                if (b.earnedOn != null) 'earned_on': b.earnedOn,
              })
          .toList(),
      'wire_note': 'Frontend-only mock · wire to yearly digest API later',
    };

// ── Providers ─────────────────────────────────────────────────────────────────
final _d275TabProvider = StateProvider<int>((ref) => 0);
final _d275CelebrateProvider = StateProvider<bool>((ref) => false);
final _d275SharedProvider = StateProvider<bool>((ref) => false);

// ── Screen ────────────────────────────────────────────────────────────────────
class Day275YearInReviewScreen extends ConsumerWidget {
  const Day275YearInReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final celebrate = ref.watch(_d275CelebrateProvider);
    final shared = ref.watch(_d275SharedProvider);
    final earnedCount = _kBadges.where((b) => b.earned).length;

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 275 · Year in Review'),
        actions: [
          IconButton(
            tooltip: celebrate ? 'Hide celebration' : 'Celebrate',
            onPressed: () => ref.read(_d275CelebrateProvider.notifier).state =
                !celebrate,
            icon: Icon(
              celebrate ? Icons.celebration_rounded : Icons.celebration_outlined,
              color: celebrate ? _kAccent : ZapColors.textMuted,
            ),
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
                  shared ? 'SHARED ✅' : '$earnedCount/12 BADGES',
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
      body: Stack(
        children: [
          Column(
            children: [
              _TabBar(
                tab: ref.watch(_d275TabProvider),
                onSelect: (i) =>
                    ref.read(_d275TabProvider.notifier).state = i,
              ),
              Expanded(
                child: switch (ref.watch(_d275TabProvider)) {
                  0 => const _SummaryTab(),
                  1 => const _BadgesTab(),
                  _ => const _InfoTab(),
                },
              ),
            ],
          ),
          if (celebrate) const _ConfettiOverlay(),
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
            '🟢 FRONTEND-ONLY · Section D Day 15/20 · annual recap · badges · share card mock',
            style: TextStyle(color: _kAccent, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.lg),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _kAccent.withOpacity(0.28),
                _kAccent.withOpacity(0.06),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kAccent.withOpacity(0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _kAccent.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: _kAccent,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: ZapSpacing.md),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your $_kYearLabel in Safety',
                          style: TextStyle(
                            color: ZapColors.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        SizedBox(height: ZapSpacing.xs),
                        Text(
                          'Gamified annual summary · mock data',
                          style: TextStyle(
                            color: ZapColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ZapSpacing.lg),
              const Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatChip(label: 'Days protected', value: '298'),
                  _StatChip(label: 'Journeys', value: '47'),
                  _StatChip(label: 'Avg score', value: '82'),
                  _StatChip(label: 'Badges', value: '8/12'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const _SectionTitle(
          title: 'Monthly journeys',
          subtitle: 'Tracked journeys per month · mock',
        ),
        const _YearBarChart(values: _kMonthlyJourneys),
        const SizedBox(height: ZapSpacing.lg),
        const _SectionTitle(
          title: 'Year highlights',
          subtitle: 'Top moments from your safety year',
        ),
        ..._kHighlights.map(
          (h) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.star_rounded, size: 14, color: _kAccent),
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
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ZapColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Shareable summary card',
                style: TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Mock export for WhatsApp / Instagram story · no PII beyond stats.',
                style: TextStyle(
                  color: ZapColors.textSecondary,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: ZapSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        ref.read(_d275SharedProvider.notifier).state = true;
                        ref.read(_d275CelebrateProvider.notifier).state = true;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Year summary card copied to clipboard (mock).',
                            ),
                          ),
                        );
                        Clipboard.setData(
                          const ClipboardData(
                            text:
                                'ZapSafe $_kYearLabel: 298 days protected · 47 journeys · 82 avg score · 8 badges 🛡️',
                          ),
                        );
                      },
                      icon: const Icon(Icons.share_rounded, size: 16),
                      label: const Text('Share card'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _kAccent,
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(width: ZapSpacing.sm),
                  OutlinedButton(
                    onPressed: () =>
                        ref.read(_d275TabProvider.notifier).state = 1,
                    child: const Text('View badges'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Tab 1: Badges ───────────────────────────────────────────────────────────────
class _BadgesTab extends StatelessWidget {
  const _BadgesTab();

  @override
  Widget build(BuildContext context) {
    final earned = _kBadges.where((b) => b.earned).length;
    final progress = earned / _kBadges.length;

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ZapColors.border),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 6,
                      backgroundColor: ZapColors.border,
                      color: _kAccent,
                    ),
                    Text(
                      '$earned',
                      style: const TextStyle(
                        color: ZapColors.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
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
                      'Badge collection',
                      style: TextStyle(
                        color: ZapColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '$earned of ${_kBadges.length} earned · '
                      '${((progress) * 100).round()}% complete',
                      style: const TextStyle(
                        color: ZapColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.82,
          ),
          itemCount: _kBadges.length,
          itemBuilder: (context, i) {
            final badge = _kBadges[i];
            return _BadgeTile(
              badge: badge,
              onTap: () => _showBadgeSheet(context, badge),
            );
          },
        ),
      ],
    );
  }

  void _showBadgeSheet(BuildContext context, _BadgeInfo badge) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ZapColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(ZapSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: badge.color.withOpacity(badge.earned ? 0.2 : 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      badge.icon,
                      color: badge.earned ? badge.color : ZapColors.textMuted,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: ZapSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          badge.title,
                          style: const TextStyle(
                            color: ZapColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          badge.earned ? 'Earned' : 'Locked',
                          style: TextStyle(
                            color: badge.earned ? ZapColors.safe : _kAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ZapSpacing.md),
              Text(
                badge.subtitle,
                style: const TextStyle(
                  color: ZapColors.textSecondary,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              if (badge.earnedOn != null) ...[
                const SizedBox(height: ZapSpacing.sm),
                Text(
                  'Unlocked ${badge.earnedOn}',
                  style: const TextStyle(
                    color: ZapColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
              const SizedBox(height: ZapSpacing.lg),
            ],
          ),
        );
      },
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge, required this.onTap});

  final _BadgeInfo badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: badge.earned
                ? badge.color.withOpacity(0.1)
                : ZapColors.bgCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: badge.earned
                  ? badge.color.withOpacity(0.4)
                  : ZapColors.border,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                badge.icon,
                color: badge.earned ? badge.color : ZapColors.textMuted,
                size: 26,
              ),
              const SizedBox(height: 6),
              Text(
                badge.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: badge.earned
                      ? ZapColors.textPrimary
                      : ZapColors.textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ],
          ),
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
    final celebrate = ref.watch(_d275CelebrateProvider);
    final payload = _yearPayload(celebrate);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _PolicyRow(
          icon: Icons.emoji_events_rounded,
          title: 'Gamified year in review',
          subtitle:
              'Annual summary card with days protected, journeys, score, and '
              'badge progress · mock data only · no backend call.',
        ),
        const _PolicyRow(
          icon: Icons.share_rounded,
          title: 'Share card mock',
          subtitle:
              'Copies a privacy-safe stat line to clipboard · simulates '
              'WhatsApp / story export without uploading user data.',
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
              const SnackBar(content: Text('Year in review spec copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy year spec'),
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
              label: const Text('Day 274 Weekly Digest v2'),
              onPressed: () => context.push(AppRoutes.weeklyDigestV2),
            ),
            ActionChip(
              label: const Text('Day 273 Personal Analytics'),
              onPressed: () => context.push(AppRoutes.personalAnalyticsHub),
            ),
            ActionChip(
              label: const Text('Day 59 Protection Score'),
              onPressed: () => context.push(AppRoutes.protectionScore),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────
class _YearBarChart extends StatelessWidget {
  const _YearBarChart({required this.values});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: BarChart(
        BarChartData(
          maxY: 8,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  if (value % 2 != 0) return const SizedBox.shrink();
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(
                      color: ZapColors.textMuted,
                      fontSize: 9,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= _kMonthLabels.length) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    _kMonthLabels[i],
                    style: const TextStyle(
                      color: ZapColors.textMuted,
                      fontSize: 9,
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < values.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: values[i],
                    color: _kAccent,
                    width: 10,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: ZapColors.bgPrimary.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kAccent.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: ZapColors.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
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

class _Particle {
  const _Particle({
    required this.x,
    required this.phase,
    required this.emoji,
    required this.size,
  });

  final double x;
  final double phase;
  final String emoji;
  final double size;
}

class _ConfettiOverlay extends StatefulWidget {
  const _ConfettiOverlay();

  @override
  State<_ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<_ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Particle> _particles;
  final _rng = math.Random(275);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
    const emojis = ['🎉', '🏆', '⭐', '🛡️', '✨'];
    _particles = List.generate(20, (i) {
      return _Particle(
        x: _rng.nextDouble(),
        phase: _rng.nextDouble(),
        emoji: emojis[i % emojis.length],
        size: 14 + _rng.nextInt(10).toDouble(),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final h = MediaQuery.sizeOf(context).height;
          return Stack(
            children: [
              for (final p in _particles)
                Positioned(
                  left: p.x * MediaQuery.sizeOf(context).width,
                  top: (( _controller.value + p.phase) % 1.0) * h * 0.85,
                  child: Text(
                    p.emoji,
                    style: TextStyle(fontSize: p.size),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
