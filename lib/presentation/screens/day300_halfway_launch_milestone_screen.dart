/// Day 300 — Halfway Launch Milestone
///
/// Section E (Days 281-300) finale: 300 days, ~300 screens, sections A-E
/// complete, celebration + stats + Phase 2 (Days 301-365) teaser toward Day 365.
///
/// Tag: 🟢 FRONTEND-ONLY · milestone celebration · confetti + share mock.
///
/// Route: [AppRoutes.day300Milestone] → `/day-300-milestone`
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const _kAccent = Color(0xFFF59E0B);
const _kTabs = ['Celebration', 'Stats', 'Days 301-365'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');

class _SectionEDay {
  const _SectionEDay({
    required this.day,
    required this.title,
    required this.route,
    required this.icon,
    required this.color,
  });

  final int day;
  final String title;
  final String route;
  final IconData icon;
  final Color color;
}

const _kSectionEDays = [
  _SectionEDay(day: 281, title: 'Landing Preview', route: AppRoutes.landingPreview, icon: Icons.web_rounded, color: Color(0xFF3B82F6)),
  _SectionEDay(day: 282, title: 'Press Kit', route: AppRoutes.pressKit, icon: Icons.newspaper_rounded, color: Color(0xFF3B82F6)),
  _SectionEDay(day: 283, title: 'Demo Video Storyboard', route: AppRoutes.demoVideoStoryboard, icon: Icons.movie_rounded, color: Color(0xFF3B82F6)),
  _SectionEDay(day: 284, title: 'Store Review Notes', route: AppRoutes.storeReviewNotes, icon: Icons.description_rounded, color: Color(0xFF0EA5E9)),
  _SectionEDay(day: 285, title: 'Security Pre-Launch', route: AppRoutes.securityPrelaunchAudit, icon: Icons.shield_rounded, color: Color(0xFF10B981)),
  _SectionEDay(day: 286, title: 'Legal Blockers', route: AppRoutes.legalBlockersTracker, icon: Icons.gavel_rounded, color: Color(0xFFEF4444)),
  _SectionEDay(day: 287, title: 'Beta Feedback R3', route: AppRoutes.betaFeedbackRound3, icon: Icons.poll_rounded, color: Color(0xFF8B5CF6)),
  _SectionEDay(day: 288, title: 'Crash-Free Tracker', route: AppRoutes.crashFreeTracker, icon: Icons.bug_report_rounded, color: Color(0xFF6C5CE7)),
  _SectionEDay(day: 289, title: 'Full Regression', route: AppRoutes.fullRegressionRunner, icon: Icons.fact_check_rounded, color: Color(0xFF06B6D4)),
  _SectionEDay(day: 290, title: 'Staged Rollout', route: AppRoutes.stagedRolloutSimulator, icon: Icons.rocket_launch_rounded, color: Color(0xFF34A853)),
  _SectionEDay(day: 291, title: 'Global vs India', route: AppRoutes.globalIndiaCompare, icon: Icons.public_rounded, color: Color(0xFFFF9933)),
  _SectionEDay(day: 292, title: 'Post-Launch Monitor', route: AppRoutes.postLaunchMonitoring, icon: Icons.monitor_heart_rounded, color: Color(0xFFDC2626)),
  _SectionEDay(day: 293, title: 'Hotfix Playbook', route: AppRoutes.hotfixPlaybook, icon: Icons.medical_services_rounded, color: Color(0xFFEF4444)),
  _SectionEDay(day: 294, title: 'Support Macros', route: AppRoutes.supportMacros, icon: Icons.support_agent_rounded, color: Color(0xFF0D9488)),
  _SectionEDay(day: 295, title: 'Phase 2 Roadmap', route: AppRoutes.phase2Roadmap, icon: Icons.map_rounded, color: Color(0xFF7C3AED)),
  _SectionEDay(day: 296, title: 'Platform Parity', route: AppRoutes.platformParityAudit, icon: Icons.devices_rounded, color: Color(0xFF6366F1)),
  _SectionEDay(day: 297, title: 'Battery Soak Log', route: AppRoutes.batterySoakLog, icon: Icons.battery_charging_full_rounded, color: Color(0xFFF97316)),
  _SectionEDay(day: 298, title: 'Go/No-Go Gate', route: AppRoutes.gonogoGate, icon: Icons.gpp_maybe_rounded, color: Color(0xFFDC2626)),
  _SectionEDay(day: 299, title: 'Penultimate Summary', route: AppRoutes.penultimateSummary, icon: Icons.summarize_rounded, color: Color(0xFF0EA5E9)),
  _SectionEDay(day: 300, title: 'Halfway Milestone', route: AppRoutes.day300Milestone, icon: Icons.celebration_rounded, color: Color(0xFFF59E0B)),
];

const _kSections = [
  ('A', 'Privacy & Legal', 'Days 151-165', Color(0xFF3B82F6)),
  ('B', 'Data Rights + Catch-up', 'Days 166-180 · 221-240', Color(0xFF8B5CF6)),
  ('C', 'Security + Advanced', 'Days 181-190 · 241-260', Color(0xFF10B981)),
  ('D', 'i18n & Growth', 'Days 261-280', Color(0xFF7C3AED)),
  ('E', 'Launch Prep', 'Days 281-300', Color(0xFFF59E0B)),
];

const _kStats = [
  ('300', 'Build days', Color(0xFFF59E0B)),
  ('300', 'Screens built', Color(0xFF3B82F6)),
  ('100', 'Days since 200', Color(0xFF0EA5E9)),
  ('18', 'Polish screens', Color(0xFF8B5CF6)),
  ('15+', 'Languages', Color(0xFF10B981)),
  ('5', 'Sections A-E', Color(0xFFEF4444)),
  ('65', 'Phase 2 days', Color(0xFF7C3AED)),
  ('27', 'LP defenses', Color(0xFF06B6D4)),
];

const _kFeatures = [
  'Police dashboard & dispatch (Days 221-223)',
  'Stealth LP24 hidden mode (Days 230-231)',
  'Group journey live map (Days 250-252)',
  'Home widgets SOS + score (Days 256-257)',
  'Siri shortcuts & voice SOS (Days 248-249)',
  '7 language packs + RTL Persian (Days 261-268)',
  'Enterprise B2B preview (Day 277)',
  'Global launch prep stack (Days 281-300)',
];

const _kTimeline = [
  (1, 'Day 1', 'Flutter scaffold · design system'),
  (100, 'Day 100', '67 screens · Month 3 milestone'),
  (200, 'Day 200', 'Grand finale · Store live'),
  (300, 'Day 300', 'Halfway to global launch · you are here'),
  (365, 'Day 365', 'Global launch milestone · Phase 2 target'),
];

const _kPhase2Preview = [
  ('Global launch', 'Days 301-320', 'EU · LATAM · SEA store expansion'),
  ('v9.2 core', 'Days 321-330', 'SOS refactor · journey ML · RC build'),
  ('Platform hardening', 'Days 331-350', 'Parity · soak · go/no-go v2'),
  ('Enterprise live', 'Days 351-360', 'B2B SSO · insurance API'),
  ('Wearables deferred', 'Days 361-365', 'Optional R&D · Day 365 finale'),
];

Map<String, dynamic> _milestonePayload() => {
      'endpoint': 'GET /api/v1/milestones/day-300/',
      'days_total': 300,
      'screens_total': 300,
      'sections_complete': ['A', 'B', 'C', 'D', 'E'],
      'section_e_days': 20,
      'phase_2_range': '301-365',
      'global_launch_target_day': 365,
      'wire_note': 'Halfway launch milestone · lighter than Day 200',
    };

String _shareMessage() => '''
🛡️ ZapSafe — Day 300 Milestone

300 days · 300 screens · Sections A-E complete.
Halfway to global launch (Day 365).

Police · stealth · group journey · 15+ languages.
Phase 2: Days 301-365 ahead.

#ZapSafe #SafetyFirst
''';

// ── Providers ─────────────────────────────────────────────────────────────────
final _d300TabProvider = StateProvider<int>((ref) => 0);
final _d300ConfettiProvider = StateProvider<bool>((ref) => false);
final _d300SharingProvider = StateProvider<bool>((ref) => false);

// ── Screen ────────────────────────────────────────────────────────────────────
class Day300HalfwayLaunchMilestoneScreen extends ConsumerStatefulWidget {
  const Day300HalfwayLaunchMilestoneScreen({super.key});

  @override
  ConsumerState<Day300HalfwayLaunchMilestoneScreen> createState() =>
      _Day300HalfwayLaunchMilestoneScreenState();
}

class _Day300HalfwayLaunchMilestoneScreenState
    extends ConsumerState<Day300HalfwayLaunchMilestoneScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyTabFromRoute());
  }

  void _applyTabFromRoute() {
    if (!mounted) return;
    const tabEnv = String.fromEnvironment('INITIAL_TAB', defaultValue: '');
    final tabQ = GoRouterState.of(context).uri.queryParameters['tab'];
    final tab = int.tryParse(tabQ ?? tabEnv);
    if (tab != null && tab >= 0 && tab < _kTabs.length) {
      ref.read(_d300TabProvider.notifier).state = tab;
    }
  }

  @override
  Widget build(BuildContext context) {
    final confetti = ref.watch(_d300ConfettiProvider);

    return Stack(
      children: [
        Scaffold(
          backgroundColor: ZapColors.bgPrimary,
          appBar: AppBar(
            title: const Text('Day 300 · Halfway Launch'),
            actions: [
              IconButton(
                tooltip: 'Confetti',
                onPressed: () => ref.read(_d300ConfettiProvider.notifier).state =
                    !confetti,
                icon: Icon(
                  confetti
                      ? Icons.celebration_rounded
                      : Icons.celebration_outlined,
                  color: confetti ? _kAccent : ZapColors.textMuted,
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
                          const Color(0xFF10B981).withOpacity(0.85),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'SECTION E ✅',
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
                tab: ref.watch(_d300TabProvider),
                onSelect: (i) => ref.read(_d300TabProvider.notifier).state = i,
              ),
              Expanded(
                child: switch (ref.watch(_d300TabProvider)) {
                  0 => const _CelebrationTab(),
                  1 => const _StatsTab(),
                  _ => const _Phase2Tab(),
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

// ── Tab 0: Celebration ────────────────────────────────────────────────────────
class _CelebrationTab extends ConsumerWidget {
  const _CelebrationTab();

  Future<void> _share(WidgetRef ref, BuildContext context) async {
    if (ref.read(_d300SharingProvider)) return;
    ref.read(_d300SharingProvider.notifier).state = true;
    await Future<void>.delayed(const Duration(milliseconds: 800));
    Clipboard.setData(ClipboardData(text: _shareMessage()));
    ref.read(_d300SharingProvider.notifier).state = false;
    ref.read(_d300ConfettiProvider.notifier).state = true;
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Milestone message copied — share mock.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sharing = ref.watch(_d300SharingProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.xl),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF2A1F08),
                Color(0xFF0F2A1F),
                Color(0xFF0F172A),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kAccent.withOpacity(0.55), width: 2),
            boxShadow: [
              BoxShadow(
                color: _kAccent.withOpacity(0.15),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 88,
                    height: 88,
                    child: CircularProgressIndicator(
                      value: 300 / 365,
                      strokeWidth: 6,
                      backgroundColor: ZapColors.bgPrimary,
                      valueColor: const AlwaysStoppedAnimation<Color>(_kAccent),
                    ),
                  ),
                  const Text('300', style: TextStyle(
                    color: ZapColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  )),
                ],
              ),
              const SizedBox(height: ZapSpacing.md),
              const Text(
                'Day 300 · Halfway to Global Launch',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ZapColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '300 days · 300 screens · Sections A-E complete.\n'
                'Section E (Days 281-300) signed off · 82% to Day 365.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ZapColors.textSecondary,
                  fontSize: 12,
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Sections A-E',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        ..._kSections.map(
          (s) => Container(
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: s.$4.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: s.$4.withOpacity(0.15),
                  child: Text(
                    s.$1,
                    style: TextStyle(
                      color: s.$4,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.$2,
                        style: const TextStyle(
                          color: ZapColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        s.$3,
                        style: const TextStyle(
                          color: ZapColors.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.check_circle_rounded, color: ZapColors.safe, size: 18),
              ],
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        FilledButton.icon(
          onPressed: sharing ? null : () => _share(ref, context),
          icon: sharing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.share_rounded, size: 18),
          label: const Text('Share milestone (mock)'),
          style: FilledButton.styleFrom(
            backgroundColor: _kAccent,
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        OutlinedButton.icon(
          onPressed: () =>
              ref.read(_d300ConfettiProvider.notifier).state = true,
          icon: const Icon(Icons.celebration_rounded, size: 16),
          label: const Text('Launch confetti'),
        ),
      ],
    );
  }
}

// ── Tab 1: Stats ──────────────────────────────────────────────────────────────
class _StatsTab extends ConsumerWidget {
  const _StatsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _SectionTitle(
          title: '300-day stat grid',
          subtitle: 'Lighter than Day 200 · focus on Days 201-300 arc',
        ),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: ZapSpacing.sm,
          crossAxisSpacing: ZapSpacing.sm,
          childAspectRatio: 1.35,
          children: _kStats
              .map(
                (s) => _StatCard(value: s.$1, label: s.$2, color: s.$3),
              )
              .toList(),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const _SectionTitle(
          title: 'Timeline',
          subtitle: 'Day 1 → 100 → 200 → 300 → 365',
        ),
        ..._kTimeline.map((m) {
          final isHere = m.$1 == 300;
          final isFuture = m.$1 > 300;
          return Padding(
            padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isFuture
                        ? ZapColors.textMuted
                        : isHere
                            ? _kAccent
                            : ZapColors.safe,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.$2,
                        style: TextStyle(
                          color: isHere ? _kAccent : ZapColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        m.$3,
                        style: const TextStyle(
                          color: ZapColors.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: ZapSpacing.lg),
        const _SectionTitle(
          title: 'Features since Day 200',
          subtitle: 'Police · stealth · group journey · i18n · launch prep',
        ),
        ..._kFeatures.map(
          (f) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '• $f',
              style: const TextStyle(
                color: ZapColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const _SectionTitle(
          title: 'Section E catalogue (281-300)',
          subtitle: 'Tap to open · 20 launch-prep screens',
        ),
        ..._kSectionEDays.map(
          (d) => ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: d.color.withOpacity(0.15),
              child: Text(
                '${d.day}',
                style: TextStyle(
                  color: d.color,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
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
            trailing: Icon(d.icon, color: d.color, size: 16),
            onTap: () => context.push(d.route),
          ),
        ),
      ],
    );
  }
}

// ── Tab 2: Days 301-365 ───────────────────────────────────────────────────────
class _Phase2Tab extends ConsumerWidget {
  const _Phase2Tab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payload = _milestonePayload();

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _SectionTitle(
          title: 'Phase 2 · Days 301-365',
          subtitle: '65 days to Day 365 global launch · see Day 295 roadmap',
        ),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFF7C3AED).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFF7C3AED).withOpacity(0.35),
            ),
          ),
          child: const Row(
            children: [
              Icon(Icons.flag_rounded, color: Color(0xFF7C3AED)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Day 365 is the global launch milestone — '
                  '65 days remain in Phase 2 after today.',
                  style: TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        ..._kPhase2Preview.map(
          (p) => Container(
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
                Text(
                  p.$1,
                  style: const TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                Text(
                  p.$2,
                  style: const TextStyle(
                    color: _kAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  p.$3,
                  style: const TextStyle(
                    color: ZapColors.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
        FilledButton.icon(
          onPressed: () => context.push(AppRoutes.phase2Roadmap),
          icon: const Icon(Icons.map_rounded, size: 18),
          label: const Text('Open Day 295 Phase 2 Roadmap'),
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
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
            'Next arc: Day 365 — Global Launch Milestone '
            '(Phase 2 finale · worldwide rollout · v9.2 ship).',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
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
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              label: const Text('Day 200 Finale'),
              onPressed: () => context.push(AppRoutes.grandFinale),
            ),
            ActionChip(
              label: const Text('Day 299 Penultimate'),
              onPressed: () => context.push(AppRoutes.penultimateSummary),
            ),
            ActionChip(
              label: const Text('Day 298 Go/No-Go'),
              onPressed: () => context.push(AppRoutes.gonogoGate),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────
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

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ZapColors.textMuted,
              fontSize: 10,
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
                    fontSize: i == 2 ? 10 : 12,
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
  final _rng = math.Random(300);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
    const emojis = ['🎉', '🏆', '✨', '🚀', '🛡️', '300'];
    _particles = List.generate(28, (i) {
      return _Particle(
        x: _rng.nextDouble(),
        phase: _rng.nextDouble(),
        emoji: emojis[i % emojis.length],
        size: 14 + _rng.nextInt(12).toDouble(),
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
          final w = MediaQuery.sizeOf(context).width;
          return Stack(
            children: [
              for (final p in _particles)
                Positioned(
                  left: p.x * w,
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
