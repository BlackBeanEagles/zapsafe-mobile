/// Day 260 — Section C Milestone · Advanced Features
///
/// Celebration + summary of Days 241-259: phone-only safety flows,
/// accessibility, group/family, widgets, fall detection, smart nudges.
/// Launch checklist + Section D (261+) teaser.
///
/// Tag: 🟢 FRONTEND-ONLY · Section C Day 20/20 sign-off.
///
/// Route: [AppRoutes.sectionCAdvancedMilestone] → `/section-c-advanced-milestone`
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

// ── Section C catalogue (241-259) ─────────────────────────────────────────────
class _SectionCDay {
  const _SectionCDay({
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

const _kSectionCDays = [
  _SectionCDay(
    day: 241,
    title: 'Journey Mode v2',
    route: AppRoutes.journeyModeV2,
    icon: Icons.map_rounded,
    color: Color(0xFF3B82F6),
    block: 'Phone safety',
  ),
  _SectionCDay(
    day: 242,
    title: 'Trusted Circle v2',
    route: AppRoutes.trustedCircleV2,
    icon: Icons.group_rounded,
    color: Color(0xFF3B82F6),
    block: 'Phone safety',
  ),
  _SectionCDay(
    day: 243,
    title: 'Ride Safety v2',
    route: AppRoutes.rideSafetyV2,
    icon: Icons.directions_car_rounded,
    color: Color(0xFF3B82F6),
    block: 'Phone safety',
  ),
  _SectionCDay(
    day: 244,
    title: 'Fake Call Polish',
    route: AppRoutes.fakeCallPolish,
    icon: Icons.phone_in_talk_rounded,
    color: Color(0xFF3B82F6),
    block: 'Phone safety',
  ),
  _SectionCDay(
    day: 245,
    title: 'Offline SOS UX',
    route: AppRoutes.offlineSosUx,
    icon: Icons.cloud_off_rounded,
    color: Color(0xFF3B82F6),
    block: 'Phone safety',
  ),
  _SectionCDay(
    day: 246,
    title: 'Hearing Impaired Visual',
    route: AppRoutes.hearingImpairedVisual,
    icon: Icons.visibility_rounded,
    color: Color(0xFF10B981),
    block: 'Accessibility',
  ),
  _SectionCDay(
    day: 247,
    title: 'Haptic Patterns',
    route: AppRoutes.hapticPatterns,
    icon: Icons.vibration_rounded,
    color: Color(0xFF10B981),
    block: 'Accessibility',
  ),
  _SectionCDay(
    day: 248,
    title: 'Siri Shortcuts',
    route: AppRoutes.siriShortcuts,
    icon: Icons.shortcut_rounded,
    color: Color(0xFF10B981),
    block: 'Voice',
  ),
  _SectionCDay(
    day: 249,
    title: 'Voice Assistant Setup',
    route: AppRoutes.voiceAssistantSetup,
    icon: Icons.mic_rounded,
    color: Color(0xFF10B981),
    block: 'Voice',
  ),
  _SectionCDay(
    day: 250,
    title: 'Group Journey Create',
    route: AppRoutes.groupJourneyCreate,
    icon: Icons.group_add_rounded,
    color: Color(0xFF8B5CF6),
    block: 'Group & family',
  ),
  _SectionCDay(
    day: 251,
    title: 'Group Journey Live Map',
    route: AppRoutes.groupJourneyLiveMap,
    icon: Icons.map_outlined,
    color: Color(0xFF8B5CF6),
    block: 'Group & family',
  ),
  _SectionCDay(
    day: 252,
    title: 'Group Panic',
    route: AppRoutes.groupJourneyPanic,
    icon: Icons.emergency_share_rounded,
    color: Color(0xFF8B5CF6),
    block: 'Group & family',
  ),
  _SectionCDay(
    day: 253,
    title: 'Family Alerts Dashboard',
    route: AppRoutes.familyAlertsDashboard,
    icon: Icons.family_restroom_rounded,
    color: Color(0xFF8B5CF6),
    block: 'Group & family',
  ),
  _SectionCDay(
    day: 254,
    title: 'Family SOS History',
    route: AppRoutes.familySosHistory,
    icon: Icons.history_rounded,
    color: Color(0xFF8B5CF6),
    block: 'Group & family',
  ),
  _SectionCDay(
    day: 255,
    title: 'Child Admin Lock',
    route: AppRoutes.childModeAdmin,
    icon: Icons.child_care_rounded,
    color: Color(0xFF8B5CF6),
    block: 'Group & family',
  ),
  _SectionCDay(
    day: 256,
    title: 'Home Widget SOS',
    route: AppRoutes.homeWidgetSos,
    icon: Icons.widgets_rounded,
    color: Color(0xFFF59E0B),
    block: 'Advanced',
  ),
  _SectionCDay(
    day: 257,
    title: 'Home Widget Score',
    route: AppRoutes.homeWidgetScore,
    icon: Icons.shield_rounded,
    color: Color(0xFFF59E0B),
    block: 'Advanced',
  ),
  _SectionCDay(
    day: 258,
    title: 'Fall Detection Tuning',
    route: AppRoutes.fallDetectionTuning,
    icon: Icons.accessibility_new_rounded,
    color: Color(0xFFF59E0B),
    block: 'Advanced',
  ),
  _SectionCDay(
    day: 259,
    title: 'Smart Notifications',
    route: AppRoutes.smartNotifications,
    icon: Icons.notifications_active_rounded,
    color: Color(0xFFF59E0B),
    block: 'Advanced',
  ),
];

const _kThemeBlocks = [
  (
    'Phone safety v2',
    'Days 241-245',
    5,
    Color(0xFF3B82F6),
    Icons.phone_android_rounded,
    'Journey Mode, Trusted Circle, Ride Safety, Fake Call, offline SOS UX.',
  ),
  (
    'Accessibility & voice',
    'Days 246-249',
    4,
    Color(0xFF10B981),
    Icons.hearing_rounded,
    'Visual alerts, haptic patterns, Siri shortcuts, Google/Alexa setup.',
  ),
  (
    'Group & family',
    'Days 250-255',
    6,
    Color(0xFF8B5CF6),
    Icons.groups_rounded,
    'Group journey create/map/panic, family dashboard, SOS history, child admin.',
  ),
  (
    'Widgets & intelligence',
    'Days 256-259',
    4,
    Color(0xFFF59E0B),
    Icons.auto_awesome_rounded,
    'Home screen widgets, IMU fall tuning, smart contextual nudges.',
  ),
];

const _kMetrics = [
  ('20', 'Section C days', '241-260 incl. milestone', ZapColors.safe),
  ('19', 'Feature screens', 'All routes wired', Color(0xFF3B82F6)),
  ('0', 'Wearables', 'Phone-only section', Color(0xFF10B981)),
  ('4', 'Theme blocks', 'Safety · a11y · family · advanced', Color(0xFF8B5CF6)),
  ('6', 'Family flows', 'Group + admin + history', Color(0xFFEC4899)),
  ('5', 'Smart nudge types', 'Day 259 catalog', Color(0xFF6366F1)),
];

const _kLaunchChecklist = [
  ('journey', 'Journey Mode v2 smoke-tested on map mock'),
  ('offline', 'Offline SOS queue UX reviewed'),
  ('a11y', 'Hearing-impaired visual + haptic patterns paired'),
  ('group', 'Group panic dispatches to all member contacts'),
  ('family', 'Family dashboard + SOS history admin gate'),
  ('widgets', 'Home widget SOS + score previews documented'),
  ('fall', 'Fall detection presets + test simulation pass'),
  ('nudges', 'Smart nudges respect quiet hours (Day 73)'),
  ('regression', 'Day 229 runner includes Section C routes'),
  ('docs', 'Section C milestone report copied for release notes'),
];

const _kSectionDBlocks = [
  (
    'Days 261-264',
    Color(0xFF2563EB),
    Icons.language_rounded,
    'Language expansion hub (25 target), translation workflow, RTL audit.',
  ),
  (
    'Days 265-270',
    Color(0xFF10B981),
    Icons.people_rounded,
    'Family features extended — shared zones, member roles, invite flows.',
  ),
  (
    'Days 271-275',
    Color(0xFF8B5CF6),
    Icons.insights_rounded,
    'Personal analytics, usage insights, safety score trends.',
  ),
  (
    'Days 276-280',
    Color(0xFFF59E0B),
    Icons.campaign_rounded,
    'Pre-launch marketing assets, store listings, community beta.',
  ),
];

String _buildReport(Set<String> checked) {
  final buf = StringBuffer('ZapSafe Section C Advanced Features — COMPLETE\n');
  buf.writeln('Generated: ${DateTime.now().toIso8601String()}');
  buf.writeln('Days shipped: 19 feature days + Day 260 milestone');
  buf.writeln('Scope: phone-only · no wearables');
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
  buf.writeln('Next: Section D Days 261-280 (i18n + family + launch)');
  return buf.toString();
}

// ── Providers ─────────────────────────────────────────────────────────────────
final _d260TabProvider = StateProvider<int>((ref) => 0);
final _d260ConfettiProvider = StateProvider<bool>((ref) => false);
final _d260ExpandedBlockProvider = StateProvider<String?>((ref) => null);
final _d260ChecklistProvider = StateProvider<Set<String>>((ref) => {});

const _kTabs = ['Summary', 'Metrics', 'Section D'];
const _kAccent = Color(0xFF8B5CF6);

// ── Screen ────────────────────────────────────────────────────────────────────
class Day260AdvancedFeaturesMilestoneScreen extends ConsumerWidget {
  const Day260AdvancedFeaturesMilestoneScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d260TabProvider);
    final confetti = ref.watch(_d260ConfettiProvider);

    return Stack(
      children: [
        Scaffold(
          backgroundColor: ZapColors.bgPrimary,
          appBar: AppBar(
            title: const Text('Day 260 · Section C Complete'),
            actions: [
              IconButton(
                tooltip: 'Confetti',
                onPressed: () =>
                    ref.read(_d260ConfettiProvider.notifier).state = !confetti,
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
                          ZapColors.safe.withOpacity(0.85),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'SECTION C ✅',
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
                onSelect: (i) => ref.read(_d260TabProvider.notifier).state = i,
              ),
              Expanded(
                child: switch (tab) {
                  0 => const _SummaryTab(),
                  1 => const _MetricsTab(),
                  _ => const _SectionDTab(),
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
    final expanded = ref.watch(_d260ExpandedBlockProvider);
    final checked = ref.watch(_d260ChecklistProvider);
    final allDone = checked.length == _kLaunchChecklist.length;

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _HeroCard(),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Theme blocks (241-259)',
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
                      .read(_d260ExpandedBlockProvider.notifier)
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
              ref.read(_d260ChecklistProvider.notifier).state = next;
            },
          );
        }),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'All Section C screens (241-259)',
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
          children: _kSectionCDays.map((d) {
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
              const SnackBar(content: Text('Copied Section C milestone report')),
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
            ZapColors.safe.withOpacity(0.12),
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
          Text('🚀', style: TextStyle(fontSize: 48)),
          SizedBox(height: ZapSpacing.sm),
          Text(
            'SECTION C COMPLETE',
            style: TextStyle(
              color: _kAccent,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Advanced Phone Features',
            style: TextStyle(
              color: ZapColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'Journey · Trusted Circle · Ride Safety · Accessibility · '
            'Group/Family · Widgets · Fall detection · Smart nudges — '
            '19 feature days · phone only · no wearables.',
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
              _Badge('Section D next →', Color(0xFF2563EB)),
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
            'Section C advanced features metrics · mock snapshot · Day 260 sign-off',
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
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ZapColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.$1,
                    style: TextStyle(
                      color: m.$4,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
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
                  width: 120,
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
                      value: b.$3 / 6,
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

// ── Tab 2: Section D ──────────────────────────────────────────────────────────
class _SectionDTab extends StatelessWidget {
  const _SectionDTab();

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
                const Color(0xFF2563EB).withOpacity(0.15),
                ZapColors.bgCard,
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF2563EB).withOpacity(0.35),
            ),
          ),
          child: const Column(
            children: [
              Icon(Icons.language_rounded, color: Color(0xFF2563EB), size: 36),
              SizedBox(height: ZapSpacing.sm),
              Text(
                'Section D starts Day 261',
                style: TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'i18n expansion to 25 languages, deeper family features, '
                'personal analytics, and pre-launch marketing assets.',
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
          'Section D preview (261-280)',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        ..._kSectionDBlocks.map(
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
              label: const Text('Day 259 Smart Nudges'),
              onPressed: () => context.push(AppRoutes.smartNotifications),
            ),
            ActionChip(
              label: const Text('Day 240 Section B Milestone'),
              onPressed: () =>
                  context.push(AppRoutes.sectionBCatchupMilestone),
            ),
            ActionChip(
              label: const Text('Day 220 Section A Milestone'),
              onPressed: () => context.push(AppRoutes.polishMilestone),
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
                    color: selected
                        ? ZapColors.textPrimary
                        : ZapColors.textSecondary,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 10,
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

// ── Confetti ──────────────────────────────────────────────────────────────────
class _ConfettiOverlay extends StatefulWidget {
  const _ConfettiOverlay();

  @override
  State<_ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<_ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Particle> _particles;
  final _rng = math.Random(260);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
    const emojis = ['🎉', '✨', '🚀', '⭐', '📱'];
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
                  top: (( _controller.value + p.phase) % 1.0) * h,
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
