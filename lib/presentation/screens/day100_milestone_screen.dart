/// Day 100 — 100-Day Sprint Milestone Review screen.
///
/// Celebrates the completion of the first 100-day frontend sprint.
/// Sections:
///   • Hero banner with trophy + achievement chips
///   • 4 stat boxes (screens / months / AI features / LP defenses)
///   • Monthly breakdown accordion (4 cards, single-open)
///   • Days 101-150 roadmap preview (3 phase cards)
///   • Quick-navigation grid to 4 key screens
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../domain/providers/milestone_providers.dart';
import '../navigation/app_router.dart';

// ─── Month data ───────────────────────────────────────────────────────────────

class _MonthData {
  const _MonthData({
    required this.month,
    required this.days,
    required this.screens,
    required this.cumulative,
    required this.headline,
    required this.accentColor,
    required this.icon,
    required this.features,
  });

  final int          month;
  final String       days;
  final int          screens;
  final int          cumulative;
  final String       headline;
  final Color        accentColor;
  final IconData     icon;
  final List<String> features;
}

const _kMonths = <_MonthData>[
  _MonthData(
    month:       1,
    days:        'Days 1–20',
    screens:     11,
    cumulative:  11,
    headline:    'Foundation',
    accentColor: Color(0xFF3B82F6),
    icon:        Icons.foundation_rounded,
    features: [
      'Design system & dark-theme tokens (WCAG AAA)',
      'Auth flow: phone entry → OTP → PIN setup',
      'SOS trigger button with 15-second countdown',
      'Emergency contacts UI (Tier 1 & 2)',
      'Permissions screen + push-notification wiring',
    ],
  ),
  _MonthData(
    month:       2,
    days:        'Days 21–45',
    screens:     15,
    cumulative:  26,
    headline:    'Core Engine',
    accentColor: Color(0xFF10B981),
    icon:        Icons.settings_input_component_rounded,
    features: [
      'Background service & LP4 watchdog (auto-restart)',
      'TFLite model loader + DCS inference engine',
      'Silent audio capture (Android + iOS pipeline)',
      'IMU / GPS service wiring & fallback states',
      '5-step onboarding flow with heuristic engine',
    ],
  ),
  _MonthData(
    month:       3,
    days:        'Days 46–80',
    screens:     22,
    cumulative:  48,
    headline:    'AI Detection',
    accentColor: Color(0xFFF59E0B),
    icon:        Icons.psychology_rounded,
    features: [
      'Detection settings, ML analytics & model downloads',
      'Safe zones, protection score & check-in timers',
      'Escalation policies, SOS templates & alert thresholds',
      'Do Not Disturb, delivery confirmation & audit log',
      'Alert Pending countdown screen (safety-critical)',
      'Alert Dashboard v2 with charts',
    ],
  ),
  _MonthData(
    month:       4,
    days:        'Days 81–99',
    screens:     19,
    cumulative:  67,
    headline:    'Premium & Settings',
    accentColor: Color(0xFF8B5CF6),
    icon:        Icons.workspace_premium_rounded,
    features: [
      'Evidence vault & contact management v2',
      'Premium subscription tiers + Stripe payment flow',
      'Payment methods & billing history with PDF mock',
      'Language settings (15-language selector UI)',
      'Accessibility settings (WCAG AAA 21:1 contrast)',
      'Profile & account: biometric, sessions, cache',
      'Help & Support: FAQ accordion + contact form',
    ],
  ),
];

// ─── Phase data (Days 101-150 preview) ───────────────────────────────────────

class _PhaseData {
  const _PhaseData({
    required this.days,
    required this.title,
    required this.icon,
    required this.color,
    required this.bullets,
  });

  final String       days;
  final String       title;
  final IconData     icon;
  final Color        color;
  final List<String> bullets;
}

const _kPhases = <_PhaseData>[
  _PhaseData(
    days:  'Days 101–110',
    title: 'i18n Localization',
    icon:  Icons.translate_rounded,
    color: ZapColors.info,
    bullets: [
      'easy_localization package + 15 JSON files',
      'en · hi · ta · te · ml · bn · mr · gu · pa · ur · ar · es · fr · pt · de',
      'Live language toggle — zero restart',
      'WCAG 2.1 AA Semantics + screen-reader labels',
    ],
  ),
  _PhaseData(
    days:  'Days 111–140',
    title: 'Beta Launch',
    icon:  Icons.science_rounded,
    color: ZapColors.warning,
    bullets: [
      'Beta flavour APK + onboarding screen',
      'In-app feedback form + false-positive report',
      'Sentry crash reporting (auto stack traces)',
      '1 000 real user beta test + iteration',
    ],
  ),
  _PhaseData(
    days:  'Days 141–150',
    title: 'AWS Production',
    icon:  Icons.cloud_upload_rounded,
    color: ZapColors.safe,
    bullets: [
      'APK size < 50 MB (lazy load + model compression)',
      'Cold-start time < 2 seconds',
      'API base URL → AWS migration + regression test',
      'Tag v0.6-aws-production — launch-ready',
    ],
  ),
];

// ─── Screen ───────────────────────────────────────────────────────────────────

class Day100MilestoneScreen extends ConsumerWidget {
  const Day100MilestoneScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: ZapColors.bgPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: ZapColors.textPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Day 100 — Sprint Review'),
        centerTitle: false,
      ),
      body: const CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              ZapSpacing.lg, ZapSpacing.md, ZapSpacing.lg, ZapSpacing.xxxl,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate.fixed([
                _HeroBanner(),
                SizedBox(height: ZapSpacing.xxl),
                _StatsRow(),
                SizedBox(height: ZapSpacing.xxl),
                _SectionHeader(
                  icon:  Icons.calendar_month_rounded,
                  label: 'Monthly Breakdown',
                ),
                SizedBox(height: ZapSpacing.lg),
                _MonthsAccordion(),
                SizedBox(height: ZapSpacing.xxl),
                _SectionHeader(
                  icon:  Icons.rocket_launch_rounded,
                  label: 'Days 101-150 Preview',
                ),
                SizedBox(height: ZapSpacing.lg),
                _PhasesColumn(),
                SizedBox(height: ZapSpacing.xxl),
                _SectionHeader(
                  icon:  Icons.navigation_rounded,
                  label: 'Quick Navigate',
                ),
                SizedBox(height: ZapSpacing.lg),
                _QuickNavGrid(),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Hero banner ──────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  const _HeroBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: ZapSpacing.xxl,
        vertical:   ZapSpacing.xxxl,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
          colors: [Color(0xFF92400E), Color(0xFF451A03)],
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFFB45309)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.emoji_events_rounded,
            size:  64,
            color: Color(0xFFFBBF24),
          ),
          const SizedBox(height: ZapSpacing.md),
          Text(
            'Day 100',
            style: ZapTypography.headlineSmall.copyWith(
              fontSize:   34,
              fontWeight: FontWeight.w900,
              color:      const Color(0xFFFBBF24),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            'Frontend Sprint Complete',
            style: ZapTypography.labelLarge.copyWith(
              color: const Color(0xFFFDE68A),
            ),
          ),
          const SizedBox(height: ZapSpacing.lg),
          const Wrap(
            spacing:   ZapSpacing.sm,
            runSpacing: ZapSpacing.sm,
            alignment: WrapAlignment.center,
            children: [
              _AchievementChip(label: 'Month 1 ✓'),
              _AchievementChip(label: 'Month 2 ✓'),
              _AchievementChip(label: 'Month 3 ✓'),
              _AchievementChip(label: 'Month 4 ✓'),
            ],
          ),
          const SizedBox(height: ZapSpacing.lg),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: ZapSpacing.lg,
              vertical:   ZapSpacing.sm,
            ),
            decoration: BoxDecoration(
              color:        const Color(0xFF78350F).withOpacity(0.6),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            ),
            child: Text(
              '4 months · 67+ screens · 44 AI features · 27 loophole defenses',
              textAlign: TextAlign.center,
              style: ZapTypography.bodySmall.copyWith(
                color: const Color(0xFFFDE68A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementChip extends StatelessWidget {
  const _AchievementChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ZapSpacing.md,
        vertical:   ZapSpacing.xs,
      ),
      decoration: BoxDecoration(
        color:        const Color(0xFFFBBF24).withOpacity(0.15),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(
          color: const Color(0xFFFBBF24).withOpacity(0.4),
        ),
      ),
      child: Text(
        label,
        style: ZapTypography.labelSmall.copyWith(
          color:      const Color(0xFFFBBF24),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─── Stats row ────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: _StatBox(
            value: '67+',
            label: 'Screens\nBuilt',
            color: ZapColors.safe,
          ),
        ),
        SizedBox(width: ZapSpacing.md),
        Expanded(
          child: _StatBox(
            value: '4',
            label: 'Months\nComplete',
            color: ZapColors.info,
          ),
        ),
        SizedBox(width: ZapSpacing.md),
        Expanded(
          child: _StatBox(
            value: '44',
            label: 'AI\nFeatures',
            color: ZapColors.warning,
          ),
        ),
        SizedBox(width: ZapSpacing.md),
        Expanded(
          child: _StatBox(
            value: '27',
            label: 'LP\nDefenses',
            color: Color(0xFF8B5CF6),
          ),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical:   ZapSpacing.lg,
        horizontal: ZapSpacing.xs,
      ),
      decoration: BoxDecoration(
        color:        ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: ZapTypography.headlineSmall.copyWith(
              color:      color,
              fontWeight: FontWeight.w800,
              fontSize:   22,
            ),
          ),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            label,
            textAlign: TextAlign.center,
            style: ZapTypography.bodySmall.copyWith(
              color:    ZapColors.textMuted,
              fontSize: 10,
              height:   1.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.label});

  final IconData icon;
  final String   label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: ZapColors.textMuted),
            const SizedBox(width: ZapSpacing.sm),
            Text(
              label.toUpperCase(),
              style: ZapTypography.labelSmall.copyWith(
                color:         ZapColors.textMuted,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.sm),
        const Divider(color: ZapColors.border, height: 1),
      ],
    );
  }
}

// ─── Monthly accordion ────────────────────────────────────────────────────────

class _MonthsAccordion extends ConsumerWidget {
  const _MonthsAccordion();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expandedMonth = ref.watch(
      milestoneProvider.select((s) => s.expandedMonth),
    );
    final notifier = ref.read(milestoneProvider.notifier);

    return Column(
      children: [
        for (int i = 0; i < _kMonths.length; i++) ...[
          _MonthCard(
            data:   _kMonths[i],
            isOpen: expandedMonth == _kMonths[i].month,
            onTap:  () => notifier.toggle(_kMonths[i].month),
          ),
          if (i < _kMonths.length - 1) const SizedBox(height: ZapSpacing.sm),
        ],
      ],
    );
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({
    required this.data,
    required this.isOpen,
    required this.onTap,
  });

  final _MonthData   data;
  final bool         isOpen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve:    Curves.easeInOut,
      decoration: BoxDecoration(
        color:        ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(
          color: isOpen
              ? data.accentColor.withOpacity(0.5)
              : ZapColors.border,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        child: Column(
          children: [
            // ── Header row ─────────────────────────────────────────────────
            InkWell(
              onTap:        onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: ZapSpacing.lg,
                  vertical:   ZapSpacing.md,
                ),
                child: Row(
                  children: [
                    Container(
                      width:  36,
                      height: 36,
                      decoration: BoxDecoration(
                        color:        data.accentColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                      ),
                      child: Icon(data.icon, size: 20, color: data.accentColor),
                    ),
                    const SizedBox(width: ZapSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Month ${data.month} — ${data.headline}',
                            style: ZapTypography.labelLarge.copyWith(
                              color: ZapColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${data.days} · ${data.screens} screens · ${data.cumulative} total',
                            style: ZapTypography.bodySmall.copyWith(
                              color: ZapColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      isOpen
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: ZapColors.textMuted,
                      size:  20,
                    ),
                  ],
                ),
              ),
            ),
            // ── Expanded content ───────────────────────────────────────────
            AnimatedCrossFade(
              duration:       const Duration(milliseconds: 200),
              crossFadeState: isOpen
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(
                    color:  data.accentColor.withOpacity(0.2),
                    height: 1,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      ZapSpacing.lg, ZapSpacing.md,
                      ZapSpacing.lg, ZapSpacing.lg,
                    ),
                    child: Column(
                      children: [
                        for (final feature in data.features)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: ZapSpacing.sm,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.check_circle_outline_rounded,
                                  size:  14,
                                  color: data.accentColor,
                                ),
                                const SizedBox(width: ZapSpacing.sm),
                                Expanded(
                                  child: Text(
                                    feature,
                                    style: ZapTypography.bodySmall.copyWith(
                                      color: ZapColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              secondChild: const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Days 101-150 phases ──────────────────────────────────────────────────────

class _PhasesColumn extends StatelessWidget {
  const _PhasesColumn();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < _kPhases.length; i++) ...[
          _PhaseCard(data: _kPhases[i]),
          if (i < _kPhases.length - 1) const SizedBox(height: ZapSpacing.md),
        ],
      ],
    );
  }
}

class _PhaseCard extends StatelessWidget {
  const _PhaseCard({required this.data});

  final _PhaseData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color:        ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: ZapColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon block
          Container(
            width:  44,
            height: 44,
            decoration: BoxDecoration(
              color:        data.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            ),
            child: Icon(data.icon, size: 22, color: data.color),
          ),
          const SizedBox(width: ZapSpacing.lg),
          // Text block
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: ZapSpacing.sm,
                        vertical:   2,
                      ),
                      decoration: BoxDecoration(
                        color:        data.color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        data.days,
                        style: ZapTypography.labelSmall.copyWith(
                          color:      data.color,
                          fontWeight: FontWeight.w600,
                          fontSize:   10,
                        ),
                      ),
                    ),
                    const SizedBox(width: ZapSpacing.sm),
                    Text(
                      data.title,
                      style: ZapTypography.labelLarge.copyWith(
                        color: ZapColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ZapSpacing.sm),
                for (final bullet in data.bullets)
                  Padding(
                    padding: const EdgeInsets.only(bottom: ZapSpacing.xs),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '›  ',
                          style: ZapTypography.bodySmall.copyWith(
                            color: data.color,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            bullet,
                            style: ZapTypography.bodySmall.copyWith(
                              color: ZapColors.textMuted,
                            ),
                          ),
                        ),
                      ],
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

// ─── Quick-navigate grid ──────────────────────────────────────────────────────

class _QuickNavGrid extends StatelessWidget {
  const _QuickNavGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount:   2,
      crossAxisSpacing: ZapSpacing.md,
      mainAxisSpacing:  ZapSpacing.md,
      shrinkWrap:       true,
      physics:          const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.65,
      children: const [
        _NavTile(
          icon:    Icons.crisis_alert_rounded,
          label:   'SOS Active',
          sublabel: 'Day 76',
          color:   ZapColors.danger,
          route:   AppRoutes.sosActive,
        ),
        _NavTile(
          icon:    Icons.security_rounded,
          label:   'Evidence Vault',
          sublabel: 'Day 82',
          color:   ZapColors.warning,
          route:   AppRoutes.evidenceVault,
        ),
        _NavTile(
          icon:    Icons.workspace_premium_rounded,
          label:   'Premium Plans',
          sublabel: 'Day 91',
          color:   Color(0xFFFBBF24),
          route:   AppRoutes.premiumSubscription,
        ),
        _NavTile(
          icon:    Icons.help_outline_rounded,
          label:   'Help & Support',
          sublabel: 'Day 99',
          color:   ZapColors.safe,
          route:   AppRoutes.helpSupport,
        ),
      ],
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.route,
  });

  final IconData icon;
  final String   label;
  final String   sublabel;
  final Color    color;
  final String   route;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap:        () => context.go(route),
      borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
      child: Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
          color:        ZapColors.bgCard,
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment:  MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: color),
                const Spacer(),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size:  11,
                  color: ZapColors.textMuted,
                ),
              ],
            ),
            const SizedBox(height: ZapSpacing.xs),
            Text(
              label,
              style: ZapTypography.labelMedium.copyWith(
                color: ZapColors.textPrimary,
              ),
            ),
            Text(
              sublabel,
              style: ZapTypography.bodySmall.copyWith(
                color:    ZapColors.textMuted,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
