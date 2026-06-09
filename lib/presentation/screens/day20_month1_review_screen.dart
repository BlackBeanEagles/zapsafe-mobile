import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../navigation/app_router.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';

/// Day 20 — Month 1 milestone review.
///
/// Consolidates the six Month 1 milestones into one shareable surface.
/// Each milestone tile deep-links to the live screen that proves the
/// milestone is real — tap "Auth flow" and you land on the phone-entry
/// screen with a working OTP flow, etc.
class Day20Month1ReviewScreen extends StatelessWidget {
  const Day20Month1ReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Day 20 · Month 1 Review'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(ZapSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeroBanner(),
              const SizedBox(height: ZapSpacing.xl),

              const _SectionLabel('SIX MILESTONES · ALL GREEN'),
              const SizedBox(height: ZapSpacing.md),
              for (final m in _milestones)
                _MilestoneTile(milestone: m),

              const SizedBox(height: ZapSpacing.xl),

              const _SectionLabel('BY THE NUMBERS'),
              const SizedBox(height: ZapSpacing.md),
              _StatsCard(),

              const SizedBox(height: ZapSpacing.xl),

              _MonthTwoCard(),

              const SizedBox(height: ZapSpacing.xxl),

              ZapButton.outlined(
                label: 'BACK TO INDEX',
                icon: Icons.arrow_back_rounded,
                fullWidth: true,
                onPressed: () => context.go('/'),
              ),
              const SizedBox(height: ZapSpacing.huge),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Milestone data ──────────────────────────────────────────────────────────

class _Milestone {
  final String title;
  final String summary;
  final String days;
  final IconData icon;
  final Color accent;
  final String route;
  const _Milestone({
    required this.title,
    required this.summary,
    required this.days,
    required this.icon,
    required this.accent,
    required this.route,
  });
}

const _milestones = <_Milestone>[
  _Milestone(
    title: 'Design system',
    summary: '22 colours · 14 type styles · 4dp grid · 10+ ZapWidgets · OLED dark theme · WCAG-AAA high contrast',
    days: 'Days 1–5',
    icon: Icons.palette_rounded,
    accent: ZapColors.info,
    route: '/', // No dedicated day-1 screen; index showcases the system.
  ),
  _Milestone(
    title: 'Auth flow',
    summary: 'Phone entry → OTP verify → JWT pair stored in Keystore/Keychain · proactive refresh · cold-start hydration',
    days: 'Days 6–10',
    icon: Icons.lock_rounded,
    accent: ZapColors.safe,
    route: AppRoutes.phoneEntry,
  ),
  _Milestone(
    title: 'Permissions onboarding',
    summary: '5 safety-critical permissions · one-at-a-time UX · "Why we need this" expandables · deniedForever → Settings',
    days: 'Days 11–12',
    icon: Icons.security_rounded,
    accent: ZapColors.warning,
    route: AppRoutes.onboardingPermissions,
  ),
  _Milestone(
    title: 'Device tier detection',
    summary: 'Tier A / B / C from OS API level · SharedPreferences cache · feature flags driven by tier · upgrade tooltips',
    days: 'Days 13–14',
    icon: Icons.memory_rounded,
    accent: ZapColors.info,
    route: AppRoutes.deviceTier,
  ),
  _Milestone(
    title: 'FCM push notifications',
    summary: '4 categories · Android SOS bypass-DND channel · iOS + Android action buttons · scheduled + silent + drill mode',
    days: 'Days 16–18',
    icon: Icons.notifications_active_rounded,
    accent: ZapColors.info,
    route: AppRoutes.pushRouting,
  ),
  _Milestone(
    title: 'Navigation structure',
    summary: 'go_router with 14 routes · onboarding redirect · push-driven deep-link routing · cold-start payload routing',
    days: 'Days 5 + 7 + 17',
    icon: Icons.alt_route_rounded,
    accent: ZapColors.safe,
    route: '/',
  ),
];

// ─── Hero ────────────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ZapColors.safe.withOpacity(0.18),
            ZapColors.info.withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.safe.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(ZapSpacing.sm),
                decoration: BoxDecoration(
                  color: ZapColors.safe.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.emoji_events_rounded,
                    color: ZapColors.safe, size: 22),
              ),
              const SizedBox(width: ZapSpacing.md),
              const ZapBadge(
                label: 'MONTH 1 · DAY 20 OF 20',
                intent: ZapBadgeIntent.safe,
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          Text(
            'Month 1 Complete',
            style: ZapTypography.displaySmall.copyWith(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            'Foundation laid. Twenty days · six milestones · every safety '
            'subsystem from auth to push wired through and live on this index. '
            'Month 2 begins on Day 21 — background engine, audio capture, '
            'TFLite skeleton.',
            style: ZapTypography.bodyMedium.copyWith(
              color: ZapColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Milestone tile ──────────────────────────────────────────────────────────

class _MilestoneTile extends StatelessWidget {
  final _Milestone milestone;
  const _MilestoneTile({required this.milestone});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
      child: ZapCard(
        onTap: () => context.go(milestone.route),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: milestone.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              ),
              child: Icon(milestone.icon, color: milestone.accent, size: 22),
            ),
            const SizedBox(width: ZapSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          milestone.title,
                          style: ZapTypography.headlineSmall.copyWith(
                            color: ZapColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Icon(Icons.check_circle_rounded,
                          color: ZapColors.safe, size: 20),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    milestone.days,
                    style: ZapTypography.labelSmall.copyWith(
                      color: ZapColors.textSecondary,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: ZapSpacing.xs),
                  Text(
                    milestone.summary,
                    style: ZapTypography.bodySmall.copyWith(
                      color: ZapColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Stats card ──────────────────────────────────────────────────────────────

class _StatsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _stat('20', 'days complete', ZapColors.safe),
              _stat('82+', 'tests passing', ZapColors.info),
            ],
          ),
          const SizedBox(height: ZapSpacing.lg),
          Row(
            children: [
              _stat('15', 'live screens', ZapColors.warning),
              _stat('14', 'routes wired', ZapColors.info),
            ],
          ),
          const SizedBox(height: ZapSpacing.lg),
          Row(
            children: [
              _stat('7', 'core services', ZapColors.safe),
              _stat('4', 'push categories', ZapColors.info),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String number, String label, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            number,
            style: ZapTypography.displaySmall.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: ZapTypography.bodySmall.copyWith(
              color: ZapColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Month 2 card ────────────────────────────────────────────────────────────

class _MonthTwoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ZapColors.warning.withOpacity(0.12),
            ZapColors.danger.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.warning.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.rocket_launch_rounded,
                  color: ZapColors.warning, size: 22),
              const SizedBox(width: ZapSpacing.sm),
              Text(
                'UP NEXT · MONTH 2',
                style: ZapTypography.labelSmall.copyWith(
                  color: ZapColors.warning,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.sm),
          Text(
            'Background engine + Audio + TFLite skeleton',
            style: ZapTypography.headlineSmall.copyWith(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            'Always-on background safety engine · audio capture pipeline · '
            'TFLite models loading. Day 21 starts the second four-week sprint.',
            style: ZapTypography.bodySmall.copyWith(
              color: ZapColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section label ───────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: ZapTypography.labelSmall.copyWith(
            color: ZapColors.textSecondary,
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: ZapSpacing.md),
        const Expanded(child: Divider(color: ZapColors.border)),
      ],
    );
  }
}
