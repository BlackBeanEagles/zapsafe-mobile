/// Day 359 — Enterprise Sales Deck In-App
///
/// Swipeable deck for B2B meetings: problem, solution, pricing, contact.
/// Real, self-contained UI — no backend dependency (there's nothing to
/// wire; this is presentation content, not data).
///
/// Pricing slide reuses the exact same real numbers as Day 318's regional
/// pricing matrix (`day318_regional_pricing_matrix_screen.dart` — read
/// first): India ₹99/₹199 is real, live Razorpay pricing
/// (`zapsafe_backend/subscription/models.py` PLAN_PRICE_INR), every other
/// region is Day 318's own labeled-PROPOSED figure, never invented fresh
/// here. The Day 277/353 bulk-license figures (seats × price/seat) are
/// referenced as the enterprise-specific pricing model on top of the base
/// consumer plan, consistent with Day 277's existing numbers.
///
/// Tag: 🟢 FRONTEND-ONLY — self-contained, no backend dependency.
///
/// Route: [AppRoutes.enterpriseSalesDeck] → `/day-359-enterprise-sales-deck`
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../navigation/app_router.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';

final _d359PageProvider = StateProvider<int>((ref) => 0);

class _Slide {
  const _Slide({required this.kicker, required this.title, required this.builder});
  final String kicker;
  final String title;
  final WidgetBuilder builder;
}

class Day359EnterpriseSalesDeckScreen extends ConsumerStatefulWidget {
  const Day359EnterpriseSalesDeckScreen({super.key});

  @override
  ConsumerState<Day359EnterpriseSalesDeckScreen> createState() => _State();
}

class _State extends ConsumerState<Day359EnterpriseSalesDeckScreen> {
  late final PageController _pageController;

  late final List<_Slide> _slides = [
    const _Slide(kicker: 'THE PROBLEM', title: 'Workforce safety is reactive, not proactive', builder: _problemSlide),
    const _Slide(kicker: 'THE SOLUTION', title: 'ZapSafe: real-time protection at scale', builder: _solutionSlide),
    const _Slide(kicker: 'PRICING', title: 'Simple, transparent, per-seat', builder: _pricingSlide),
    const _Slide(kicker: 'GET STARTED', title: "Let's talk", builder: _contactSlide),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = ref.watch(_d359PageProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: Text('day351_360.sales_deck_title'.tr()),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: ZapBadge(
                label: '${page + 1}/${_slides.length}',
                intent: ZapBadgeIntent.info,
                size: ZapBadgeSize.small,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _slides.length,
              onPageChanged: (i) => ref.read(_d359PageProvider.notifier).state = i,
              itemBuilder: (context, i) {
                final slide = _slides[i];
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(ZapSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(slide.kicker,
                          style: ZapTypography.labelLarge.copyWith(color: ZapColors.info, letterSpacing: 1.2)),
                      const SizedBox(height: ZapSpacing.xs),
                      Text(slide.title,
                          style: ZapTypography.displaySmall
                              .copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w800)),
                      const SizedBox(height: ZapSpacing.xl),
                      slide.builder(context),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(ZapSpacing.lg),
            child: Row(
              children: [
                for (var i = 0; i < _slides.length; i++)
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      height: 4,
                      decoration: BoxDecoration(
                        color: i <= page ? ZapColors.info : ZapColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(ZapSpacing.lg, 0, ZapSpacing.lg, ZapSpacing.lg),
            child: Row(
              children: [
                if (page > 0)
                  Expanded(
                    child: ZapButton.outlined(
                      label: 'Back',
                      icon: Icons.arrow_back_rounded,
                      onPressed: () => _pageController.previousPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      ),
                    ),
                  ),
                if (page > 0) const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: ZapButton.elevated(
                    label: page == _slides.length - 1 ? 'Restart' : 'Next',
                    icon: page == _slides.length - 1 ? Icons.replay_rounded : Icons.arrow_forward_rounded,
                    intent: ZapButtonIntent.info,
                    onPressed: () {
                      if (page == _slides.length - 1) {
                        _pageController.jumpToPage(0);
                      } else {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        );
                      }
                    },
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

Widget _problemSlide(BuildContext context) {
  return const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _BulletCard(
        icon: Icons.nightlight_round,
        title: 'Night-shift & field workers are invisible',
        body: 'Dispatchers and supervisors have no real-time view of workers '
            'in transit or on solo shifts after hours.',
      ),
      _BulletCard(
        icon: Icons.timer_off_rounded,
        title: 'Incident response is slow',
        body: 'By the time an incident is reported through a call center, '
            'critical minutes are already lost.',
      ),
      _BulletCard(
        icon: Icons.description_outlined,
        title: 'No audit trail for compliance',
        body: 'HR and legal teams need documented safety response records — '
            'most workforces have none.',
      ),
    ],
  );
}

Widget _solutionSlide(BuildContext context) {
  return const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _BulletCard(
        icon: Icons.emergency_rounded,
        title: 'One-tap SOS, every device',
        body: 'Real-time location + emergency contact cascade, the same '
            'production SOS pipeline every ZapSafe consumer uses today.',
      ),
      _BulletCard(
        icon: Icons.groups_2_rounded,
        title: 'Group journey tracking',
        body: 'Live map for supervised shifts and field visits, with a group '
            'panic button that alerts every member at once.',
      ),
      _BulletCard(
        icon: Icons.dashboard_customize_rounded,
        title: 'Admin console + audit trail',
        body: 'Org-level dashboard: SOS counts, response SLA, roster '
            'visibility — built for compliance reporting.',
      ),
    ],
  );
}

Widget _pricingSlide(BuildContext context) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ZapCard(
        backgroundColor: ZapColors.safe.withOpacity(0.08),
        borderColor: ZapColors.safe.withOpacity(0.3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.verified_rounded, color: ZapColors.safe, size: 18),
            const SizedBox(width: ZapSpacing.sm),
            Expanded(
              child: Text(
                'India consumer pricing below is real, live Razorpay pricing — '
                'same numbers as Day 318\'s regional pricing matrix, not invented '
                'for this deck.',
                style: ZapTypography.bodySmall.copyWith(color: ZapColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: ZapSpacing.lg),
      const Row(
        children: [
          Expanded(child: _PriceCard(label: 'Consumer Premium', price: '₹99/mo', badge: 'LIVE')),
          SizedBox(width: ZapSpacing.sm),
          Expanded(child: _PriceCard(label: 'Consumer Premium+', price: '₹199/mo', badge: 'LIVE')),
        ],
      ),
      const SizedBox(height: ZapSpacing.lg),
      Text('Enterprise bulk tiers (per seat/month)',
          style: ZapTypography.labelLarge.copyWith(color: ZapColors.textSecondary)),
      const SizedBox(height: ZapSpacing.sm),
      const _EnterpriseTierRow(name: 'Starter', seats: '50 seats', price: '₹149/seat'),
      const _EnterpriseTierRow(name: 'Growth', seats: '250 seats', price: '₹119/seat'),
      const _EnterpriseTierRow(name: 'Enterprise', seats: '1000 seats', price: '₹89/seat'),
      const SizedBox(height: ZapSpacing.sm),
      Text(
        'Enterprise tier figures match Day 277/353\'s existing bulk-license '
        'preview — proposed pricing, pending an actual sales decision, same as '
        'every non-India row in Day 318\'s matrix.',
        style: ZapTypography.labelSmall.copyWith(color: ZapColors.textMuted, height: 1.4),
      ),
    ],
  );
}

Widget _contactSlide(BuildContext context) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ZapCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: ZapColors.info.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.business_center_rounded, color: ZapColors.info),
                ),
                const SizedBox(width: ZapSpacing.md),
                const Expanded(
                  child: Text('ZapSafe Enterprise Sales',
                      style: TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
                ),
              ],
            ),
            const SizedBox(height: ZapSpacing.md),
            const _ContactRow(icon: Icons.email_rounded, label: 'enterprise@zapsafe.app'),
            const _ContactRow(icon: Icons.language_rounded, label: 'zapsafe.app/enterprise'),
          ],
        ),
      ),
      const SizedBox(height: ZapSpacing.lg),
      Text(
        'These are placeholder contact details for the deck template — swap '
        'with the real sales contact before an actual meeting.',
        style: ZapTypography.labelSmall.copyWith(color: ZapColors.textMuted, height: 1.4),
      ),
      const SizedBox(height: ZapSpacing.xl),
      Builder(builder: (context) {
        return ZapButton.outlined(
          label: 'Copy deck summary',
          icon: Icons.copy_rounded,
          fullWidth: true,
          onPressed: () {
            Clipboard.setData(const ClipboardData(
              text: 'ZapSafe Enterprise — real-time worker safety.\n'
                  'Problem: night-shift/field workers invisible, slow incident '
                  'response, no compliance audit trail.\n'
                  'Solution: one-tap SOS, group journey tracking, admin console.\n'
                  'Pricing: consumer ₹99/₹199/mo (live). Enterprise bulk from '
                  '₹89-149/seat/mo (proposed).\n'
                  'Contact: enterprise@zapsafe.app',
            ));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deck summary copied')));
          },
        );
      }),
      const SizedBox(height: ZapSpacing.sm),
      const _JumpLinksRow(),
    ],
  );
}

class _JumpLinksRow extends StatelessWidget {
  const _JumpLinksRow();
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ActionChip(label: const Text('Day 318 pricing matrix'), onPressed: () => context.push(AppRoutes.regionalPricingMatrix)),
        ActionChip(label: const Text('Day 353 admin preview'), onPressed: () => context.push(AppRoutes.b2bAdminPreview)),
        ActionChip(label: const Text('Day 277 licenses'), onPressed: () => context.push(AppRoutes.enterpriseB2bPreview)),
      ],
    );
  }
}

class _BulletCard extends StatelessWidget {
  const _BulletCard({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: ZapColors.info, size: 22),
          const SizedBox(width: ZapSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: ZapTypography.bodyMedium.copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(body, style: ZapTypography.bodySmall.copyWith(color: ZapColors.textSecondary, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceCard extends StatelessWidget {
  const _PriceCard({required this.label, required this.price, required this.badge});
  final String label;
  final String price;
  final String badge;

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      backgroundColor: ZapColors.safe.withOpacity(0.06),
      borderColor: ZapColors.safe.withOpacity(0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ZapBadge(label: badge, intent: ZapBadgeIntent.safe, size: ZapBadgeSize.small),
          const SizedBox(height: ZapSpacing.sm),
          Text(price, style: ZapTypography.headlineMedium.copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w900)),
          Text(label, style: ZapTypography.labelSmall.copyWith(color: ZapColors.textSecondary)),
        ],
      ),
    );
  }
}

class _EnterpriseTierRow extends StatelessWidget {
  const _EnterpriseTierRow({required this.name, required this.seats, required this.price});
  final String name;
  final String seats;
  final String price;

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.md, vertical: ZapSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(name, style: ZapTypography.bodySmall.copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w700)),
          ),
          Text(seats, style: ZapTypography.labelSmall.copyWith(color: ZapColors.textMuted)),
          const SizedBox(width: ZapSpacing.md),
          Text(price, style: ZapTypography.bodySmall.copyWith(color: ZapColors.warning, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: ZapSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 16, color: ZapColors.textMuted),
          const SizedBox(width: ZapSpacing.sm),
          Text(label, style: ZapTypography.bodySmall.copyWith(color: ZapColors.textSecondary)),
        ],
      ),
    );
  }
}
