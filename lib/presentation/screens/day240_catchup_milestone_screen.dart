/// Day 240 — Section B Milestone · Catch-Up Complete
///
/// Celebration + summary of Days 221-239 catch-up track: police, referral,
/// polish/regression, stealth LP24, India prep. Teaser Section C/D (241+).
///
/// Tag: 🟢 FRONTEND-ONLY · Section B Day 20/20 sign-off.
///
/// Route: [AppRoutes.sectionBCatchupMilestone] → `/section-b-milestone`
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

// ── Section B catalogue (221-239) ─────────────────────────────────────────────
class _SectionBDay {
  const _SectionBDay({
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

const _kSectionBDays = [
  _SectionBDay(
    day: 221,
    title: 'Police Dashboard',
    route: AppRoutes.policeDashboard,
    icon: Icons.local_police_rounded,
    color: Color(0xFF3B82F6),
    block: 'Police',
  ),
  _SectionBDay(
    day: 222,
    title: 'Police Dispatch Status',
    route: AppRoutes.policeDispatchStatus,
    icon: Icons.timeline_rounded,
    color: Color(0xFF3B82F6),
    block: 'Police',
  ),
  _SectionBDay(
    day: 223,
    title: 'Police Weblink Preview',
    route: AppRoutes.policeWeblinkPreview,
    icon: Icons.link_rounded,
    color: Color(0xFF3B82F6),
    block: 'Police',
  ),
  _SectionBDay(
    day: 224,
    title: 'Referral Invite',
    route: AppRoutes.referralInvite,
    icon: Icons.person_add_rounded,
    color: Color(0xFF10B981),
    block: 'Referral',
  ),
  _SectionBDay(
    day: 225,
    title: 'Referral Rewards',
    route: AppRoutes.referralRewards,
    icon: Icons.emoji_events_rounded,
    color: Color(0xFFF59E0B),
    block: 'Referral',
  ),
  _SectionBDay(
    day: 226,
    title: 'Admin Analytics',
    route: AppRoutes.adminAnalytics,
    icon: Icons.analytics_rounded,
    color: Color(0xFFEF4444),
    block: 'Referral',
  ),
  _SectionBDay(
    day: 227,
    title: 'Notification History v3',
    route: AppRoutes.notificationHistoryV3,
    icon: Icons.notifications_active_rounded,
    color: Color(0xFF3B82F6),
    block: 'Polish',
  ),
  _SectionBDay(
    day: 228,
    title: 'SOS History Timeline',
    route: AppRoutes.sosHistoryTimeline,
    icon: Icons.history_rounded,
    color: Color(0xFFEF4444),
    block: 'Polish',
  ),
  _SectionBDay(
    day: 229,
    title: 'Feature Regression Runner',
    route: AppRoutes.featureRegressionRunner,
    icon: Icons.fact_check_rounded,
    color: Color(0xFF10B981),
    block: 'Polish',
  ),
  _SectionBDay(
    day: 230,
    title: 'Hidden Mode Toggle',
    route: AppRoutes.hiddenModeToggle,
    icon: Icons.visibility_off_rounded,
    color: Color(0xFF8B5CF6),
    block: 'Stealth',
  ),
  _SectionBDay(
    day: 231,
    title: 'Stealth Icon Disguise',
    route: AppRoutes.stealthIconDisguise,
    icon: Icons.app_settings_alt_rounded,
    color: Color(0xFF6B7280),
    block: 'Stealth',
  ),
  _SectionBDay(
    day: 232,
    title: 'Decoy Calculator',
    route: AppRoutes.decoyCalculator,
    icon: Icons.calculate_rounded,
    color: Color(0xFF6B7280),
    block: 'Stealth',
  ),
  _SectionBDay(
    day: 233,
    title: 'Decoy Weather',
    route: AppRoutes.decoyWeather,
    icon: Icons.wb_sunny_rounded,
    color: Color(0xFF3B82F6),
    block: 'Stealth',
  ),
  _SectionBDay(
    day: 234,
    title: 'Secret Gesture Config',
    route: AppRoutes.secretGestureConfig,
    icon: Icons.gesture_rounded,
    color: Color(0xFF8B5CF6),
    block: 'Stealth',
  ),
  _SectionBDay(
    day: 235,
    title: 'Stealth Settings Hub',
    route: AppRoutes.stealthSettingsHub,
    icon: Icons.shield_moon_rounded,
    color: Color(0xFF8B5CF6),
    block: 'Stealth',
  ),
  _SectionBDay(
    day: 236,
    title: 'Hindi Copy QA',
    route: AppRoutes.hindiUxQa,
    icon: Icons.translate_rounded,
    color: Color(0xFFF59E0B),
    block: 'India',
  ),
  _SectionBDay(
    day: 237,
    title: 'Tamil & Telugu QA',
    route: AppRoutes.tamilTeluguQa,
    icon: Icons.language_rounded,
    color: Color(0xFF14B8A6),
    block: 'India',
  ),
  _SectionBDay(
    day: 238,
    title: 'Region Emergency Numbers',
    route: AppRoutes.regionEmergencyNumbers,
    icon: Icons.emergency_rounded,
    color: Color(0xFFEF4444),
    block: 'India',
  ),
  _SectionBDay(
    day: 239,
    title: 'India Launch Readiness',
    route: AppRoutes.indiaLaunchReadiness,
    icon: Icons.rocket_launch_rounded,
    color: Color(0xFF10B981),
    block: 'India',
  ),
];

const _kThemeBlocks = [
  (
    'Police integration',
    'Days 221-223',
    3,
    Color(0xFF3B82F6),
    Icons.local_police_rounded,
    'Victim-side dashboard, dispatch timeline, police weblink preview.',
  ),
  (
    'Referral & admin',
    'Days 224-226',
    3,
    Color(0xFF10B981),
    Icons.card_giftcard_rounded,
    'Invite flow, INR rewards, internal admin analytics gate.',
  ),
  (
    'Polish & regression',
    'Days 227-229',
    3,
    Color(0xFF8B5CF6),
    Icons.history_rounded,
    'Notification history v3, SOS timeline, 53-row regression runner.',
  ),
  (
    'Stealth LP24',
    'Days 230-235',
    6,
    Color(0xFF6E6E82),
    Icons.visibility_off_rounded,
    'Hidden mode, icon disguise, decoy shells, gestures, settings hub.',
  ),
  (
    'India soft launch',
    'Days 236-239',
    4,
    Color(0xFFF59E0B),
    Icons.flag_rounded,
    'Hindi/TA/TE QA, ERSS numbers JSON, launch readiness checklist.',
  ),
];

const _kMetrics = [
  ('20', 'Catch-up days', 'Section B 221-240', ZapColors.info),
  ('3', 'Police screens', 'Gov / enterprise UI', Color(0xFF3B82F6)),
  ('6', 'Stealth layers', 'LP24 decoy chain', Color(0xFF8B5CF6)),
  ('4', 'India UX gates', 'i18n + 112 + launch', Color(0xFFF59E0B)),
  ('53', 'Regression rows', 'Day 229 runner', ZapColors.safe),
  ('18', 'Countries', 'Emergency numbers JSON', ZapColors.danger),
];

const _kSectionCBlocks = [
  (
    'Days 241-245',
    Color(0xFF3B82F6),
    Icons.map_rounded,
    'Journey Mode v2, Trusted Circle, Ride Safety, Fake Call polish.',
  ),
  (
    'Days 246-250',
    Color(0xFF10B981),
    Icons.hearing_rounded,
    'Hearing-impaired mode, voice assistant hooks, offline SOS v2.',
  ),
  (
    'Days 251-255',
    Color(0xFF8B5CF6),
    Icons.groups_rounded,
    'Family hub, group SOS, shared safe zones — phone only.',
  ),
  (
    'Days 256-260',
    Color(0xFFF59E0B),
    Icons.emoji_events_rounded,
    'Advanced phone features + Section C milestone sign-off.',
  ),
];

const _kSectionDTeaser = (
  'Section D · Days 261-280',
  'i18n expansion hub (25 languages), family features, pre-launch marketing.',
  Icons.language_rounded,
  Color(0xFF2563EB),
);

String _buildReport() {
  final buf = StringBuffer('ZapSafe Section B Catch-Up — COMPLETE\n');
  buf.writeln('Generated: ${DateTime.now().toIso8601String()}');
  buf.writeln('Days shipped: 19 feature days + Day 240 milestone');
  buf.writeln('');
  for (final block in _kThemeBlocks) {
    buf.writeln('${block.$1} (${block.$2}) · ${block.$3} screens');
    buf.writeln('  ${block.$6}');
  }
  buf.writeln('');
  buf.writeln('Next: Section C Days 241-260 (phone features + a11y)');
  buf.writeln('Then: Section D Days 261-280 (i18n + family)');
  return buf.toString();
}

// ── Providers ─────────────────────────────────────────────────────────────────
final _d240TabProvider = StateProvider<int>((ref) => 0);
final _d240ConfettiProvider = StateProvider<bool>((ref) => false);
final _d240ExpandedBlockProvider = StateProvider<String?>((ref) => null);

const _kTabs = ['Summary', 'Metrics', 'Section C/D'];

// ── Screen ────────────────────────────────────────────────────────────────────
class Day240CatchupMilestoneScreen extends ConsumerWidget {
  const Day240CatchupMilestoneScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d240TabProvider);
    final confetti = ref.watch(_d240ConfettiProvider);

    return Stack(
      children: [
        Scaffold(
          backgroundColor: ZapColors.bgPrimary,
          appBar: AppBar(
            title: const Text('Day 240 · Section B Complete'),
            actions: [
              IconButton(
                tooltip: 'Confetti',
                onPressed: () =>
                    ref.read(_d240ConfettiProvider.notifier).state = !confetti,
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
                          ZapColors.safe.withOpacity(0.9),
                          ZapColors.info.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'SECTION B ✅',
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
                onSelect: (i) => ref.read(_d240TabProvider.notifier).state = i,
              ),
              Expanded(
                child: switch (tab) {
                  0 => const _SummaryTab(),
                  1 => const _MetricsTab(),
                  _ => const _NextTab(),
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

// ── Tab 0: Summary ──────────────────────────────────────────────────────────
class _SummaryTab extends ConsumerWidget {
  const _SummaryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(_d240ExpandedBlockProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _HeroCard(),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Theme blocks (221-239)',
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
                      .read(_d240ExpandedBlockProvider.notifier)
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
        const Text(
          'All Section B screens',
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
          children: _kSectionBDays.map((d) {
            return ActionChip(
              avatar: Icon(d.icon, size: 14, color: d.color),
              label: Text(
                '${d.day}',
                style: const TextStyle(fontSize: 10),
              ),
              onPressed: () => context.push(d.route),
            );
          }).toList(),
        ),
        const SizedBox(height: ZapSpacing.lg),
        FilledButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: _buildReport()));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Copied Section B report')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text('Copy milestone report'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            backgroundColor: ZapColors.info,
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
            ZapColors.safe.withOpacity(0.2),
            ZapColors.info.withOpacity(0.12),
            ZapColors.bgCard,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZapColors.safe.withOpacity(0.45), width: 2),
      ),
      child: const Column(
        children: [
          Text('🏁', style: TextStyle(fontSize: 48)),
          SizedBox(height: ZapSpacing.sm),
          Text(
            'SECTION B COMPLETE',
            style: TextStyle(
              color: ZapColors.safe,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Catch-Up Milestone',
            style: TextStyle(
              color: ZapColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: ZapSpacing.sm),
          Text(
            'Police · Referral · Stealth LP24 · India prep — '
            '19 feature days shipped in Section B (221-239).',
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
              _Badge('Day 20/20', ZapColors.info),
              _Badge('Section C next →', ZapColors.warning),
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge(this.label, this.color);

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
            color: ZapColors.safe.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: ZapColors.safe.withOpacity(0.35)),
          ),
          child: const Text(
            'Section B catch-up metrics · mock snapshot · Day 240 sign-off',
            style: TextStyle(color: ZapColors.safe, fontSize: 11),
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
                  const Spacer(),
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
        ..._kSectionBDays.map(
          (d) => Container(
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: ZapColors.border),
            ),
            child: ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 14,
                backgroundColor: d.color.withOpacity(0.15),
                child: Text(
                  '${d.day}',
                  style: TextStyle(
                    color: d.color,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              title: Text(
                d.title,
                style: const TextStyle(
                  color: ZapColors.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                d.block,
                style: const TextStyle(
                  color: ZapColors.textMuted,
                  fontSize: 9,
                ),
              ),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: ZapColors.textMuted,
                size: 18,
              ),
              onTap: () => context.push(d.route),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Tab 2: Section C/D ────────────────────────────────────────────────────────
class _NextTab extends StatelessWidget {
  const _NextTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.lg),
          decoration: BoxDecoration(
            color: ZapColors.info.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ZapColors.info.withOpacity(0.35)),
          ),
          child: const Column(
            children: [
              Text('🚀', style: TextStyle(fontSize: 36)),
              SizedBox(height: ZapSpacing.sm),
              Text(
                'Section C starts Day 241',
                style: TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: ZapSpacing.sm),
              Text(
                'Core phone features + accessibility — Journey Mode, Trusted Circle, '
                'Ride Safety, Fake Call, hearing mode, family/group flows. '
                'No wearables.',
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
          'Section C preview (241-260)',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        ..._kSectionCBlocks.map(
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
                const SizedBox(width: ZapSpacing.md),
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
                      const SizedBox(height: ZapSpacing.xs),
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
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kSectionDTeaser.$4.withOpacity(0.35)),
          ),
          child: Row(
            children: [
              Icon(
                _kSectionDTeaser.$3,
                color: _kSectionDTeaser.$4,
                size: 24,
              ),
              const SizedBox(width: ZapSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _kSectionDTeaser.$1,
                      style: TextStyle(
                        color: _kSectionDTeaser.$4,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: ZapSpacing.xs),
                    Text(
                      _kSectionDTeaser.$2,
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
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.warning.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.warning.withOpacity(0.3)),
          ),
          child: const Text(
            'Next: Day 365 — Global Launch Milestone.',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              label: const Text('Day 241 Journey Mode'),
              onPressed: () => context.push(AppRoutes.journeyModeV2),
            ),
            ActionChip(
              label: const Text('Day 220 Section A'),
              onPressed: () => context.push(AppRoutes.polishMilestone),
            ),
            ActionChip(
              label: const Text('Day 239 India launch'),
              onPressed: () => context.push(AppRoutes.indiaLaunchReadiness),
            ),
            ActionChip(
              label: const Text('Day 235 Stealth hub'),
              onPressed: () => context.push(AppRoutes.stealthSettingsHub),
            ),
          ],
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
  final _rng = math.Random(240);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
    const emojis = ['🎉', '✨', '🏁', '⭐', '🇮🇳'];
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
            children: _particles.map((p) {
              final y = (( _controller.value + p.phase) % 1.0) * h;
              return Positioned(
                left: p.x * MediaQuery.sizeOf(context).width,
                top: y,
                child: Opacity(
                  opacity: 0.85,
                  child: Text(
                    p.emoji,
                    style: TextStyle(fontSize: p.size),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _Particle {
  final double x;
  final double phase;
  final String emoji;
  final double size;

  const _Particle({
    required this.x,
    required this.phase,
    required this.emoji,
    required this.size,
  });
}
