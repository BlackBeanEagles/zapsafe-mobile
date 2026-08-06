/// Day 280 — Section D Milestone
///
/// Celebration + summary of Days 261-279: i18n expansion, community,
/// partnerships, analytics, digests, enterprise, and dashboard polish.
/// Launch checklist + Section E (281+) teaser.
///
/// Tag: 🟢 FRONTEND-ONLY · Section D Day 20/20 sign-off.
///
/// Route: [AppRoutes.sectionDMilestone] → `/section-d-milestone`
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

// ── Section D catalogue (261-279) ─────────────────────────────────────────────
class _SectionDDay {
  const _SectionDDay({
    required this.day,
    required this.title,
    required this.route,
    required this.icon,
    required this.color,
    required this.block,
  });

  final int day;
  final String title;
  final String route;
  final IconData icon;
  final Color color;
  final String block;
}

const _kSectionDDays = [
  _SectionDDay(
    day: 261,
    title: 'Language Hub',
    route: AppRoutes.languageExpansionHub,
    icon: Icons.language_rounded,
    color: Color(0xFF2563EB),
    block: 'i18n',
  ),
  _SectionDDay(
    day: 262,
    title: 'Translation Workflow',
    route: AppRoutes.translationWorkflow,
    icon: Icons.account_tree_rounded,
    color: Color(0xFF2563EB),
    block: 'i18n',
  ),
  _SectionDDay(
    day: 263,
    title: 'Persian RTL',
    route: AppRoutes.persianRtl,
    icon: Icons.format_textdirection_r_to_l_rounded,
    color: Color(0xFF2563EB),
    block: 'i18n',
  ),
  _SectionDDay(
    day: 264,
    title: 'Indonesian Pack',
    route: AppRoutes.indonesianPack,
    icon: Icons.flag_rounded,
    color: Color(0xFF2563EB),
    block: 'i18n',
  ),
  _SectionDDay(
    day: 265,
    title: 'Vietnamese Pack',
    route: AppRoutes.vietnamesePack,
    icon: Icons.flag_circle_rounded,
    color: Color(0xFF2563EB),
    block: 'i18n',
  ),
  _SectionDDay(
    day: 266,
    title: 'Japanese Pack',
    route: AppRoutes.japanesePack,
    icon: Icons.font_download_rounded,
    color: Color(0xFF2563EB),
    block: 'i18n',
  ),
  _SectionDDay(
    day: 267,
    title: 'Korean Pack',
    route: AppRoutes.koreanPack,
    icon: Icons.language_rounded,
    color: Color(0xFF2563EB),
    block: 'i18n',
  ),
  _SectionDDay(
    day: 268,
    title: 'Multi-Lang QA',
    route: AppRoutes.multilangQaRunner,
    icon: Icons.replay_circle_filled_rounded,
    color: Color(0xFF2563EB),
    block: 'i18n',
  ),
  _SectionDDay(
    day: 269,
    title: 'Cultural Adaptation',
    route: AppRoutes.culturalAdaptation,
    icon: Icons.public_rounded,
    color: Color(0xFF7C3AED),
    block: 'Community',
  ),
  _SectionDDay(
    day: 270,
    title: 'Community Heatmap',
    route: AppRoutes.communityHeatmap,
    icon: Icons.map_rounded,
    color: Color(0xFF7C3AED),
    block: 'Community',
  ),
  _SectionDDay(
    day: 271,
    title: 'Share Safe Route',
    route: AppRoutes.shareSafeRoute,
    icon: Icons.share_rounded,
    color: Color(0xFF10B981),
    block: 'Partnerships',
  ),
  _SectionDDay(
    day: 272,
    title: 'Insurance Partnership',
    route: AppRoutes.insurancePartnership,
    icon: Icons.health_and_safety_rounded,
    color: Color(0xFF10B981),
    block: 'Partnerships',
  ),
  _SectionDDay(
    day: 273,
    title: 'Personal Analytics',
    route: AppRoutes.personalAnalyticsHub,
    icon: Icons.insights_rounded,
    color: Color(0xFF10B981),
    block: 'Partnerships',
  ),
  _SectionDDay(
    day: 274,
    title: 'Weekly Digest v2',
    route: AppRoutes.weeklyDigestV2,
    icon: Icons.newspaper_rounded,
    color: Color(0xFFA855F7),
    block: 'Recap',
  ),
  _SectionDDay(
    day: 275,
    title: 'Year in Review',
    route: AppRoutes.yearInReview,
    icon: Icons.emoji_events_rounded,
    color: Color(0xFFA855F7),
    block: 'Recap',
  ),
  _SectionDDay(
    day: 276,
    title: 'Reverse Image Search',
    route: AppRoutes.reverseImageSearch,
    icon: Icons.image_search_rounded,
    color: Color(0xFF0EA5E9),
    block: 'Enterprise',
  ),
  _SectionDDay(
    day: 277,
    title: 'Enterprise B2B',
    route: AppRoutes.enterpriseB2bPreview,
    icon: Icons.business_center_rounded,
    color: Color(0xFF0EA5E9),
    block: 'Enterprise',
  ),
  _SectionDDay(
    day: 278,
    title: 'Counselor Queue',
    route: AppRoutes.counselorQueuePolish,
    icon: Icons.support_agent_rounded,
    color: Color(0xFF8B5CF6),
    block: 'Polish',
  ),
  _SectionDDay(
    day: 279,
    title: 'Production Dashboard',
    route: AppRoutes.productionDashboard,
    icon: Icons.dashboard_customize_rounded,
    color: Color(0xFF8B5CF6),
    block: 'Polish',
  ),
];

const _kThemeBlocks = [
  (
    'i18n expansion',
    'Days 261-268',
    8,
    Color(0xFF2563EB),
    Icons.language_rounded,
    'Language hub, translation workflow, Persian RTL, 4 locale packs, multi-lang QA runner.',
  ),
  (
    'Community & culture',
    'Days 269-270',
    2,
    Color(0xFF7C3AED),
    Icons.groups_rounded,
    'Cultural adaptation presets, anonymous community heatmap with consent opt-in.',
  ),
  (
    'Partnerships & insights',
    'Days 271-273',
    3,
    Color(0xFF10B981),
    Icons.handshake_rounded,
    'Share safe route cards, insurance partnership mock, personal analytics hub.',
  ),
  (
    'Digests & gamification',
    'Days 274-275',
    2,
    Color(0xFFA855F7),
    Icons.auto_graph_rounded,
    'Weekly digest v2 with charts, year-in-review badges and share card.',
  ),
  (
    'Enterprise & privacy',
    'Days 276-277',
    2,
    Color(0xFF0EA5E9),
    Icons.business_rounded,
    'On-device reverse image hash search, night-shift B2B bulk license preview.',
  ),
  (
    'UX polish & integration',
    'Days 278-279',
    2,
    Color(0xFF6366F1),
    Icons.dashboard_customize_rounded,
    'Counselor queue SOS context, production dashboard wiring Days 202-204.',
  ),
];

const _kMetrics = [
  ('20', 'Section D days', '261-280 incl. milestone', ZapColors.safe),
  ('19', 'Feature screens', 'All routes wired', Color(0xFF2563EB)),
  ('5', 'Locale packs', 'id · vi · ja · ko · fa', Color(0xFF7C3AED)),
  ('6', 'Theme blocks', 'i18n · community · B2B · polish', Color(0xFF10B981)),
  ('3', 'Polish screens', '274 · 278 · 279', Color(0xFF6366F1)),
  ('8', '🟡 MOCK-NOW', 'Backend stubs in section', Color(0xFFF59E0B)),
];

const _kLaunchChecklist = [
  ('i18n', 'Persian RTL + 4 locale packs pass QA runner'),
  ('heatmap', 'Community heatmap opt-in linked to Day 157'),
  ('insurance', 'Insurance partnership verify + apply mock'),
  ('analytics', 'Personal analytics 7d/30d/90d refresh mock'),
  ('digest', 'Weekly digest v2 drill reminder snooze works'),
  ('year', 'Year in review share card + confetti mock'),
  ('reverse', 'Reverse image search opt-in + hash-only gate'),
  ('b2b', 'Enterprise B2B bulk quote flow mock'),
  ('counselor', 'Counselor queue SOS context banner wired'),
  ('dashboard', 'Production dashboard integrates 202-204 widgets'),
  ('regression', 'Day 229 runner includes Section D routes'),
  ('docs', 'Section D milestone report copied for release notes'),
];

const _kSectionEBlocks = [
  (
    'Days 281-285',
    Color(0xFFEC4899),
    Icons.campaign_rounded,
    'Marketing landing preview, press kit, demo video storyboard, store listing polish.',
  ),
  (
    'Days 286-290',
    Color(0xFF0891B2),
    Icons.fact_check_rounded,
    'QA harness, accessibility sweep, performance budget, security review mock.',
  ),
  (
    'Days 291-300',
    Color(0xFFF59E0B),
    Icons.rocket_launch_rounded,
    'Launch checklist, beta cohort, go/no-go gate toward Day 365 public launch.',
  ),
];

String _buildReport(Set<String> checked) {
  final buf = StringBuffer('ZapSafe Section D — COMPLETE\n');
  buf.writeln('Generated: ${DateTime.now().toIso8601String()}');
  buf.writeln('Days shipped: 19 feature days + Day 280 milestone');
  buf.writeln('Scope: i18n · community · partnerships · polish');
  buf.writeln('');
  for (final block in _kThemeBlocks) {
    buf.writeln('${block.$1} (${block.$2}) · ${block.$3} screens');
    buf.writeln('  ${block.$6}');
  }
  buf.writeln('');
  buf.writeln('Launch checklist: ${checked.length}/${_kLaunchChecklist.length}');
  for (final item in _kLaunchChecklist) {
    final mark = checked.contains(item.$1) ? '[x]' : '[ ]';
    buf.writeln('  $mark ${item.$2}');
  }
  buf.writeln('');
  buf.writeln('Next: Section E Days 281-300 (launch prep)');
  return buf.toString();
}

// ── Providers ─────────────────────────────────────────────────────────────────
final _d280TabProvider = StateProvider<int>((ref) => 0);
final _d280ConfettiProvider = StateProvider<bool>((ref) => false);
final _d280ExpandedBlockProvider = StateProvider<String?>((ref) => null);
final _d280ChecklistProvider = StateProvider<Set<String>>((ref) => {});

const _kTabs = ['Summary', 'Metrics', 'Section E'];
const _kAccent = Color(0xFF2563EB);

// ── Screen ────────────────────────────────────────────────────────────────────
class Day280SectionDMilestoneScreen extends ConsumerWidget {
  const Day280SectionDMilestoneScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d280TabProvider);
    final confetti = ref.watch(_d280ConfettiProvider);

    return Stack(
      children: [
        Scaffold(
          backgroundColor: ZapColors.bgPrimary,
          appBar: AppBar(
            title: const Text('Day 280 · Section D Complete'),
            actions: [
              IconButton(
                tooltip: 'Confetti',
                onPressed: () =>
                    ref.read(_d280ConfettiProvider.notifier).state = !confetti,
                icon: Icon(
                  confetti
                      ? Icons.celebration_rounded
                      : Icons.celebration_outlined,
                  color: confetti ? ZapColors.warning : ZapColors.textMuted,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: ZapSpacing.md),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _kAccent.withOpacity(0.95),
                          const Color(0xFF7C3AED).withOpacity(0.85),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'SECTION D ✅',
                      style: TextStyle(
                        color: Colors.white,
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
                tab: tab,
                onSelect: (i) => ref.read(_d280TabProvider.notifier).state = i,
              ),
              Expanded(
                child: switch (tab) {
                  0 => const _SummaryTab(),
                  1 => const _MetricsTab(),
                  _ => const _SectionETab(),
                },
              ),
            ],
          ),
        ),
        if (confetti) const _ConfettiOverlay(),
      ],
    );
  }
}

// ── Tab 0: Summary ────────────────────────────────────────────────────────────
class _SummaryTab extends ConsumerWidget {
  const _SummaryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(_d280ExpandedBlockProvider);
    final checked = ref.watch(_d280ChecklistProvider);
    final allDone = checked.length == _kLaunchChecklist.length;

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _HeroCard(),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Theme blocks (261-279)',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        ..._kThemeBlocks.map((b) {
          final name = b.$1;
          final isOpen = expanded == name;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ZapColors.border),
            ),
            child: Column(
              children: [
                ListTile(
                  dense: true,
                  leading: Icon(b.$5, color: b.$4, size: 22),
                  title: Text(
                    name,
                    style: const TextStyle(
                      color: ZapColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  subtitle: Text(
                    '${b.$2} · ${b.$3} screens',
                    style: const TextStyle(
                      color: ZapColors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                  trailing: Icon(
                    isOpen
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: ZapColors.textMuted,
                  ),
                  onTap: () => ref
                      .read(_d280ExpandedBlockProvider.notifier)
                      .state = isOpen ? null : name,
                ),
                if (isOpen)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      ZapSpacing.md,
                      0,
                      ZapSpacing.md,
                      ZapSpacing.md,
                    ),
                    child: Text(
                      b.$6,
                      style: const TextStyle(
                        color: ZapColors.textSecondary,
                        fontSize: 11,
                        height: 1.45,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
        const SizedBox(height: ZapSpacing.lg),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Launch checklist',
                style: TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
            Text(
              '${checked.length}/${_kLaunchChecklist.length}',
              style: TextStyle(
                color: allDone ? ZapColors.safe : _kAccent,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.sm),
        ..._kLaunchChecklist.map((item) {
          final id = item.$1;
          final done = checked.contains(id);
          return CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: done,
            activeColor: ZapColors.safe,
            title: Text(
              item.$2,
              style: TextStyle(
                color: done ? ZapColors.textMuted : ZapColors.textPrimary,
                fontSize: 12,
                decoration: done ? TextDecoration.lineThrough : null,
              ),
            ),
            onChanged: (v) {
              final next = {...checked};
              if (v == true) {
                next.add(id);
              } else {
                next.remove(id);
              }
              ref.read(_d280ChecklistProvider.notifier).state = next;
            },
          );
        }),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'All Section D screens (261-279)',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _kSectionDDays.map((d) {
            return ActionChip(
              avatar: Icon(d.icon, size: 14, color: d.color),
              label: Text('${d.day}', style: const TextStyle(fontSize: 10)),
              onPressed: () => context.push(d.route),
            );
          }).toList(),
        ),
        const SizedBox(height: ZapSpacing.lg),
        FilledButton.icon(
          onPressed: () {
            Clipboard.setData(
              ClipboardData(text: _buildReport(checked)),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Copied Section D milestone report')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text('Copy milestone report'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            backgroundColor: _kAccent,
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _kAccent.withOpacity(0.22),
            const Color(0xFF7C3AED).withOpacity(0.12),
            ZapColors.bgCard,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kAccent.withOpacity(0.45), width: 2),
      ),
      child: const Column(
        children: [
          Text('🌍', style: TextStyle(fontSize: 48)),
          SizedBox(height: ZapSpacing.sm),
          Text(
            'SECTION D COMPLETE',
            style: TextStyle(
              color: _kAccent,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'i18n · Community · Launch Polish',
            style: TextStyle(
              color: ZapColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'Language expansion · cultural adaptation · heatmap · partnerships · '
            'analytics · digests · enterprise B2B · counselor queue · '
            'production dashboard — 19 feature days.',
            style: TextStyle(
              color: ZapColors.textSecondary,
              fontSize: 12,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: ZapSpacing.md),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              _Badge('🟢 FRONTEND-ONLY', ZapColors.safe),
              _Badge('Day 20/20', _kAccent),
              _Badge('Section E next →', Color(0xFFEC4899)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, this.color);

  final String label;
  final Color color;

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
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Tab 1: Metrics ────────────────────────────────────────────────────────────
class _MetricsTab extends StatelessWidget {
  const _MetricsTab();

  @override
  Widget build(BuildContext context) {
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
            'Section D metrics · mock snapshot · Day 280 sign-off',
            style: TextStyle(color: _kAccent, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.35,
          children: _kMetrics.map((m) {
            return Container(
              padding: const EdgeInsets.all(ZapSpacing.md),
              decoration: BoxDecoration(
                color: ZapColors.bgCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: m.$4.withOpacity(0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    m.$1,
                    style: TextStyle(
                      color: m.$4,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                    ),
                  ),
                  Text(
                    m.$2,
                    style: const TextStyle(
                      color: ZapColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    m.$3,
                    style: const TextStyle(
                      color: ZapColors.textMuted,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Block breakdown',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        ..._kThemeBlocks.map(
          (b) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 130,
                  child: Text(
                    b.$1,
                    style: TextStyle(
                      color: b.$4,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: b.$3 / 8,
                      minHeight: 8,
                      backgroundColor: ZapColors.border,
                      color: b.$4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${b.$3}',
                  style: const TextStyle(
                    color: ZapColors.textMuted,
                    fontSize: 10,
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

// ── Tab 2: Section E ──────────────────────────────────────────────────────────
class _SectionETab extends StatelessWidget {
  const _SectionETab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.lg),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFEC4899).withOpacity(0.15),
                ZapColors.bgCard,
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFEC4899).withOpacity(0.35),
            ),
          ),
          child: const Column(
            children: [
              Icon(Icons.rocket_launch_rounded,
                  color: Color(0xFFEC4899), size: 36),
              SizedBox(height: ZapSpacing.sm),
              Text(
                'Section E starts Day 281',
                style: TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'International launch prep: marketing assets, press kit, '
                'QA hardening, and go/no-go gate toward Day 365 public launch.',
                textAlign: TextAlign.center,
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
        const Text(
          'Section E preview (281-300)',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        ..._kSectionEBlocks.map(
          (b) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: b.$2.withOpacity(0.35)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(b.$3, color: b.$2, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.$1,
                        style: TextStyle(
                          color: b.$2,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        b.$4,
                        style: const TextStyle(
                          color: ZapColors.textSecondary,
                          fontSize: 10,
                          height: 1.4,
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
              label: const Text('Day 279 Production Dashboard'),
              onPressed: () => context.push(AppRoutes.productionDashboard),
            ),
            ActionChip(
              label: const Text('Day 260 Section C Milestone'),
              onPressed: () =>
                  context.push(AppRoutes.sectionCAdvancedMilestone),
            ),
            ActionChip(
              label: const Text('Day 240 Section B Milestone'),
              onPressed: () =>
                  context.push(AppRoutes.sectionBCatchupMilestone),
            ),
            ActionChip(
              label: const Text('Day 229 Regression Runner'),
              onPressed: () => context.push(AppRoutes.featureRegressionRunner),
            ),
          ],
        ),
      ],
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
  final _rng = math.Random(280);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
    const emojis = ['🎉', '🌍', '✨', '🚀', '🛡️'];
    _particles = List.generate(24, (i) {
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
                  top: ((_controller.value + p.phase) % 1.0) * h,
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
