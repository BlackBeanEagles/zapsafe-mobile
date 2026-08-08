/// Day 272 — Insurance Partnership UI (Mock)
///
/// Section D (Days 261-280): partner offer card with 10% discount tied to
/// verified SOS history — mock HDFC ERGO style eligibility and apply flow.
///
/// Tag: 🟡 MOCK-NOW · GET /api/v1/partners/insurance/offers/.
///
/// Route: [AppRoutes.insurancePartnership] → `/insurance-partnership`
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const _kPartnerBlue = Color(0xFF004C8F);
const _kPartnerRed = Color(0xFFED1C24);
const _kTabs = ['Offer', 'Verify', 'Info'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');
const _kDiscountPercent = 10;

class _InsurancePlan {
  const _InsurancePlan({
    required this.id,
    required this.name,
    required this.summary,
    required this.annualPremium,
    required this.discountedPremium,
  });

  final String id;
  final String name;
  final String summary;
  final int annualPremium;
  final int discountedPremium;
}

const _kPlans = [
  _InsurancePlan(
    id: 'women-suraksha',
    name: 'My:Health Women Suraksha',
    summary: 'Hospital cash · personal accident · wellness checks',
    annualPremium: 8499,
    discountedPremium: 7649,
  ),
  _InsurancePlan(
    id: 'pa-shield',
    name: 'Personal Accident Shield',
    summary: 'Accidental death · disability · ambulance cover',
    annualPremium: 2199,
    discountedPremium: 1979,
  ),
  _InsurancePlan(
    id: 'optima-lite',
    name: 'Optima Secure Lite',
    summary: 'OPD + day-care · no room rent cap · family floater',
    annualPremium: 12499,
    discountedPremium: 11249,
  ),
];

class _SosHistoryItem {
  const _SosHistoryItem({
    required this.id,
    required this.label,
    required this.date,
    required this.verified,
    required this.type,
  });

  final String id;
  final String label;
  final String date;
  final bool verified;
  final String type;
}

const _kSosHistory = [
  _SosHistoryItem(
    id: 'drill-042',
    label: 'Safety drill completed',
    date: '12 Feb 2026',
    verified: true,
    type: 'drill',
  ),
  _SosHistoryItem(
    id: 'drill-038',
    label: 'Safety drill completed',
    date: '28 Jan 2026',
    verified: true,
    type: 'drill',
  ),
  _SosHistoryItem(
    id: 'journey-019',
    label: 'Journey mode check-in',
    date: '05 Jan 2026',
    verified: true,
    type: 'journey',
  ),
  _SosHistoryItem(
    id: 'fa-003',
    label: 'False alarm resolved',
    date: '18 Nov 2025',
    verified: true,
    type: 'false_alarm',
  ),
];

const _kEligibilityRules = [
  ('drill_90d', 'At least 1 safety drill in last 90 days'),
  ('account_active', 'Active ZapSafe account 6+ months'),
  ('no_open_sos', 'No unresolved SOS incidents'),
  ('protection_score', 'Protection score 60+'),
];

// ── Providers ─────────────────────────────────────────────────────────────────
final _d272TabProvider = StateProvider<int>((ref) => 0);
final _d272PlanIndexProvider = StateProvider<int>((ref) => 0);
final _d272VerifiedProvider = StateProvider<bool>((ref) => false);
final _d272VerifyingProvider = StateProvider<bool>((ref) => false);
final _d272EligibleProvider = StateProvider<bool>((ref) => false);
final _d272AppliedProvider = StateProvider<bool>((ref) => false);

String _formatInr(int amount) => '₹${amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    )}';

// ── Screen ────────────────────────────────────────────────────────────────────
class Day272InsurancePartnershipScreen extends ConsumerWidget {
  const Day272InsurancePartnershipScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d272TabProvider);
    final eligible = ref.watch(_d272EligibleProvider);
    final applied = ref.watch(_d272AppliedProvider);
    final verified = ref.watch(_d272VerifiedProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 272 · Insurance Partnership'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: ZapSpacing.sm, vertical: ZapSpacing.xs),
                decoration: BoxDecoration(
                  color: (applied
                          ? ZapColors.safe
                          : eligible
                              ? _kPartnerBlue
                              : ZapColors.textMuted)
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: (applied
                            ? ZapColors.safe
                            : eligible
                                ? _kPartnerBlue
                                : ZapColors.textMuted)
                        .withOpacity(0.45),
                  ),
                ),
                child: Text(
                  applied
                      ? 'APPLIED ✅'
                      : eligible
                          ? '$_kDiscountPercent% OFF'
                          : verified
                              ? 'CHECK'
                              : 'MOCK',
                  style: TextStyle(
                    color: applied
                        ? ZapColors.safe
                        : eligible
                            ? _kPartnerBlue
                            : ZapColors.textMuted,
                    fontSize: 11,
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
            onSelect: (i) => ref.read(_d272TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (tab) {
              0 => const _OfferTab(),
              1 => const _VerifyTab(),
              _ => const _InfoTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Offer ──────────────────────────────────────────────────────────────
class _OfferTab extends ConsumerWidget {
  const _OfferTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planIdx = ref.watch(_d272PlanIndexProvider);
    final eligible = ref.watch(_d272EligibleProvider);
    final plan = _kPlans[planIdx];

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _kPartnerBlue.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _kPartnerBlue.withOpacity(0.35)),
          ),
          child: const Text(
            '🟡 MOCK-NOW · Section D Day 12/20 · HDFC ERGO partner offer · verified SOS discount',
            style: TextStyle(color: _kPartnerBlue, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        _PartnerOfferCard(
          plan: plan,
          eligible: eligible,
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Select plan',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        ...List.generate(_kPlans.length, (i) {
          final p = _kPlans[i];
          final selected = planIdx == i;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color:
                  selected ? _kPartnerBlue.withOpacity(0.08) : ZapColors.bgCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? _kPartnerBlue.withOpacity(0.45)
                    : ZapColors.border,
              ),
            ),
            child: ListTile(
              title: Text(
                p.name,
                style: TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              subtitle: Text(
                '${p.summary} · ${_formatInr(p.discountedPremium)}/yr '
                '(${_formatInr(p.annualPremium)} list)',
                style: const TextStyle(
                  color: ZapColors.textSecondary,
                  fontSize: 11,
                ),
              ),
              trailing: selected
                  ? const Icon(Icons.check_circle_rounded, color: _kPartnerBlue)
                  : null,
              onTap: () => ref.read(_d272PlanIndexProvider.notifier).state = i,
            ),
          );
        }),
        const SizedBox(height: ZapSpacing.md),
        FilledButton.icon(
          onPressed: eligible
              ? () => ref.read(_d272TabProvider.notifier).state = 1
              : () {
                  ref.read(_d272TabProvider.notifier).state = 1;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Verify SOS history on the Verify tab to unlock discount.',
                      ),
                    ),
                  );
                },
          icon: Icon(
              eligible ? Icons.verified_rounded : Icons.fact_check_rounded),
          label: Text(eligible ? 'Review verification' : 'Verify eligibility'),
          style: FilledButton.styleFrom(
            backgroundColor: _kPartnerBlue,
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
      ],
    );
  }
}

class _PartnerOfferCard extends StatelessWidget {
  const _PartnerOfferCard({
    required this.plan,
    required this.eligible,
  });

  final _InsurancePlan plan;
  final bool eligible;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kPartnerBlue, Color(0xFF003366)],
        ),
        boxShadow: [
          BoxShadow(
            color: _kPartnerBlue.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: ZapSpacing.sm, vertical: ZapSpacing.xs),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'HDFC ERGO',
                    style: TextStyle(
                      color: _kPartnerRed,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _kPartnerRed,
                    borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                  ),
                  child: Text(
                    eligible
                        ? '$_kDiscountPercent% OFF'
                        : 'UP TO $_kDiscountPercent%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              'ZapSafe Safety Partner Offer',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Text(
              '10% premium discount with verified SOS history',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(ZapSpacing.lg),
            child: Container(
              padding: const EdgeInsets.all(ZapSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: ZapSpacing.sm),
                  Row(
                    children: [
                      Text(
                        _formatInr(plan.discountedPremium),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                        ),
                      ),
                      Text(
                        '/year',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: ZapSpacing.sm),
                      Text(
                        _formatInr(plan.annualPremium),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.55),
                          fontSize: 12,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    eligible
                        ? 'Discount unlocked · verified SOS history'
                        : 'Verify SOS history to apply discount',
                    style: TextStyle(
                      color:
                          eligible ? const Color(0xFF86EFAC) : Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab 1: Verify ───────────────────────────────────────────────────────────
class _VerifyTab extends ConsumerWidget {
  const _VerifyTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final verifying = ref.watch(_d272VerifyingProvider);
    final verified = ref.watch(_d272VerifiedProvider);
    final eligible = ref.watch(_d272EligibleProvider);
    final applied = ref.watch(_d272AppliedProvider);
    final plan = _kPlans[ref.watch(_d272PlanIndexProvider)];

    Future<void> runVerification() async {
      ref.read(_d272VerifyingProvider.notifier).state = true;
      ref.read(_d272VerifiedProvider.notifier).state = false;
      ref.read(_d272EligibleProvider.notifier).state = false;
      ref.read(_d272AppliedProvider.notifier).state = false;
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      ref.read(_d272VerifyingProvider.notifier).state = false;
      ref.read(_d272VerifiedProvider.notifier).state = true;
      ref.read(_d272EligibleProvider.notifier).state = true;
      HapticFeedback.mediumImpact();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'SOS history verified (mock) · $_kDiscountPercent% discount unlocked',
            ),
          ),
        );
      }
    }

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ZapColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Verified SOS history',
                style: TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: ZapSpacing.xs),
              const Text(
                'Mock ledger used to validate partner discount eligibility.',
                style: TextStyle(color: ZapColors.textSecondary, fontSize: 11),
              ),
              const SizedBox(height: ZapSpacing.sm),
              ..._kSosHistory.map((item) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(
                    item.type == 'drill'
                        ? Icons.fitness_center_rounded
                        : item.type == 'journey'
                            ? Icons.directions_walk_rounded
                            : Icons.check_circle_outline_rounded,
                    color: item.verified ? ZapColors.safe : ZapColors.textMuted,
                    size: 20,
                  ),
                  title: Text(
                    item.label,
                    style: const TextStyle(
                      color: ZapColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '${item.date} · ${item.verified ? 'verified' : 'pending'}',
                    style: const TextStyle(
                      color: ZapColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                  trailing: item.verified
                      ? const Icon(Icons.verified_rounded,
                          color: ZapColors.safe, size: 18)
                      : null,
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Eligibility checks',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        ..._kEligibilityRules.map((rule) {
          final pass = verified && eligible;
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: pass ? ZapColors.safe.withOpacity(0.08) : ZapColors.bgCard,
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(
                color:
                    pass ? ZapColors.safe.withOpacity(0.35) : ZapColors.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  pass
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked,
                  color: pass ? ZapColors.safe : ZapColors.textMuted,
                  size: 18,
                ),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    rule.$2,
                    style: TextStyle(
                      color: pass
                          ? ZapColors.textPrimary
                          : ZapColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: ZapSpacing.lg),
        FilledButton.icon(
          onPressed: verifying ? null : runVerification,
          icon: verifying
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.verified_user_rounded),
          label: Text(verifying
              ? 'Verifying SOS history…'
              : 'Verify SOS history (mock)'),
          style: FilledButton.styleFrom(
            backgroundColor: _kPartnerBlue,
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        FilledButton.icon(
          onPressed: !eligible || applied
              ? null
              : () {
                  ref.read(_d272AppliedProvider.notifier).state = true;
                  HapticFeedback.mediumImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Applied ${plan.name} at '
                        '${_formatInr(plan.discountedPremium)}/yr (mock).',
                      ),
                    ),
                  );
                },
          icon: Icon(applied ? Icons.check_rounded : Icons.local_offer_rounded),
          label: Text(
            applied
                ? 'Offer applied'
                : 'Apply $_kDiscountPercent% discount (mock)',
          ),
          style: FilledButton.styleFrom(
            backgroundColor: ZapColors.safe,
            minimumSize: const Size(double.infinity, 48),
          ),
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
    final plan = _kPlans[ref.watch(_d272PlanIndexProvider)];
    final verified = ref.watch(_d272VerifiedProvider);
    final eligible = ref.watch(_d272EligibleProvider);
    final applied = ref.watch(_d272AppliedProvider);

    final payload = {
      'endpoint': 'GET /api/v1/partners/insurance/offers/',
      'partner': 'HDFC ERGO (mock)',
      'discount_percent': _kDiscountPercent,
      'eligibility': 'verified_sos_history',
      'selected_plan': plan.id,
      'verified': verified,
      'eligible': eligible,
      'applied': applied,
      'sos_history_count': _kSosHistory.length,
      'apply_endpoint': 'POST /api/v1/partners/insurance/apply/',
      'disclaimer':
          'Mock UI only · not an insurance solicitation · partner T&C apply',
    };

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _PolicyRow(
          icon: Icons.handshake_rounded,
          title: 'Partner offer card',
          subtitle:
              'HDFC ERGO style branding · 10% premium discount when SOS history '
              'passes verification · 3 selectable plan mocks.',
        ),
        const _PolicyRow(
          icon: Icons.history_rounded,
          title: 'SOS history verification',
          subtitle:
              'Mock drill/journey/false-alarm ledger · eligibility rule checklist · '
              'verify → unlock discount → apply offer flow.',
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
              const SnackBar(
                  content: Text('Insurance partnership spec copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy partnership spec'),
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
              label: const Text('Day 228 SOS History'),
              onPressed: () => context.push(AppRoutes.sosHistoryTimeline),
            ),
            ActionChip(
              label: const Text('Day 59 Protection Score'),
              onPressed: () => context.push(AppRoutes.protectionScore),
            ),
            ActionChip(
              label: const Text('Day 271 Share Safe Route'),
              onPressed: () => context.push(AppRoutes.shareSafeRoute),
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
          Icon(icon, size: 18, color: _kPartnerBlue),
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
                      color: selected ? _kPartnerBlue : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  _kTabs[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? _kPartnerBlue : ZapColors.textMuted,
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
