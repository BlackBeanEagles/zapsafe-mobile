/// Day 358 — Premium Tier Production Polish
///
/// Meta-screen documenting the real premium/free-tier badge and
/// contact-limit-message audit for this day, per the Day 351-360 spec.
///
/// AUDIT METHOD: grepped `premium`/`free tier`/`contact limit` (case-
/// insensitive) across every file under `lib/presentation/`, then read
/// each real hit to classify it.
///
/// REAL FINDING: before this day, "what tier am I on" was rendered by
/// FOUR independent systems that never talked to each other:
///   1. Day 91 (`day91_premium_subscription_screen.dart`) — own local
///      mock `subscriptionProvider` (`subscription_providers.dart`).
///   2. Day 92 (`day92_premium_features_screen.dart`) — own local mock
///      `subscriptionUsageProvider` (`premium_features_providers.dart`),
///      hardcoded `isPremium: false, contactsUsed: 2, contactsLimit: 3`
///      forever, never read anything real.
///   3. Day 93 (`day93_subscription_management_screen.dart`) — own local
///      mock `subscriptionManagementProvider`
///      (`subscription_management_providers.dart`).
///   4. Day 308's persistent status card (`persistent_status_card.dart`)
///      — the ONLY one of the four actually wired to the real Day 303
///      `subscriptionStatusProvider` (live Razorpay backend).
///
/// WHAT WAS UNIFIED THIS DAY (real, bounded changes — not a full rewrite):
///   • New shared `PremiumTierBadge` widget
///     (`lib/presentation/widgets/premium_tier_badge.dart`) standardizing
///     on Day 308's real-data visual pattern (uppercase label, safe/
///     neutral intent, icon only when actually premium). Applied to Day
///     308 (replacing its inline ZapBadge, same visuals) and additively
///     to Day 92's usage-card header.
///   • `subscriptionUsageProvider` (Day 92's data source) was rewired to
///     read the REAL Day 303 `subscriptionStatusProvider` for
///     isPremium/contactsLimit/storage, and the REAL Day 83
///     `contactsProvider` for the actual contact count — falling back to
///     the original mock only while real data is loading or unavailable
///     offline. This directly fixes a contact-limit CTA that was
///     silently lying (`contactsLimit: 3` hardcoded regardless of actual
///     plan) whenever the real Day 303 wire is reachable.
///
/// WHAT WAS **NOT** UNIFIED (explicitly, not silently skipped):
///   • Day 91's `subscriptionProvider` and Day 93's
///     `subscriptionManagementProvider` remain fully separate, self-
///     contained mock systems — NOT wired to Day 303's real status.
///     Fully consolidating all 4 systems into one real provider is a
///     genuine architecture change (differing state shapes: Day 91/93
///     model purchase-flow/cancel-flow local state that has no real Day
///     303 equivalent yet — e.g. `purchaseComplete`, billing history)
///     that is out of scope for one polish day and would risk
///     regressing two screens with no test coverage protecting them.
///   • `activeTimers`/`timersLimit`/`safeZones`/`safeZonesLimit` in Day
///     92's usage card stay hardcoded mock — no real backend
///     usage-*count* endpoint exists for either check-in timers (Day 65
///     only has CRUD) or safe zones (Day 58, same).
///   • Contacts screen's Tier 1/2/3 (`day83_contact_management_screen.dart`,
///     `kTier1Max`/`kTier2Max`) is a DIFFERENT axis entirely — escalation
///     priority tiers, not subscription plan tiers — confirmed by reading
///     `contacts_providers.dart`. The shared word "Tier" is a real
///     potential naming confusion for users but is out of scope to rename
///     here (would touch onboarding copy across 25 languages).
///
/// Tag: 🟣 polish — real code changes + honest audit, not a new mock UI.
///
/// Route: [AppRoutes.premiumPolish] → `/day-358-premium-polish`
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../navigation/app_router.dart';
import '../widgets/premium_tier_badge.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';

class _AuditRow {
  const _AuditRow({required this.title, required this.finding, required this.done});
  final String title;
  final String finding;
  final bool done; // true = unified this day, false = documented as remaining
}

const _kAuditRows = [
  _AuditRow(
    title: 'Shared PremiumTierBadge widget',
    finding: 'New widget standardizing Day 308\'s real-data visual pattern '
        '(uppercase label, safe/neutral intent, icon only when premium). '
        'Applied to Day 308 (drop-in replacement, same visuals) and '
        'additively to Day 92\'s usage-card header.',
    done: true,
  ),
  _AuditRow(
    title: 'Day 92 contact-limit data now real',
    finding: 'subscriptionUsageProvider now reads the real Day 303 '
        'subscriptionStatusProvider (contactLimit, storage) and the real '
        'Day 83 contactsProvider (actual contact count), falling back to '
        'the original seeded mock only while loading/offline. Was '
        'previously hardcoded false/2/3 forever.',
    done: true,
  ),
  _AuditRow(
    title: 'Day 91 subscriptionProvider (purchase flow)',
    finding: 'Still a fully separate local mock, not wired to Day 303. '
        'Models purchase-flow state (purchaseComplete, etc.) that has no '
        'real Day 303 equivalent yet — consolidating is a real '
        'architecture change, out of scope for one polish day.',
    done: false,
  ),
  _AuditRow(
    title: 'Day 93 subscriptionManagementProvider (cancel/billing)',
    finding: 'Still a fully separate local mock, not wired to Day 303. '
        'Models cancel-flow + billing-history state with no real backend '
        'equivalent surfaced yet — same reasoning as Day 91.',
    done: false,
  ),
  _AuditRow(
    title: 'Timer / safe-zone usage counts (Day 92)',
    finding: 'Stay hardcoded mock — no real backend usage-count endpoint '
        'exists for check-in timers (Day 65, CRUD only) or safe zones '
        '(Day 58, CRUD only).',
    done: false,
  ),
  _AuditRow(
    title: '"Tier" naming collision (contacts vs. subscription)',
    finding: 'day83_contact_management_screen.dart\'s Tier 1/2/3 = contact '
        'escalation priority, unrelated to subscription free/premium '
        'tiers. Real potential user confusion, but renaming touches '
        'onboarding copy across 25 languages — out of scope here.',
    done: false,
  ),
];

class Day358PremiumPolishScreen extends StatelessWidget {
  const Day358PremiumPolishScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final done = _kAuditRows.where((r) => r.done).length;

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(title: Text('day351_360.premium_polish_title'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          ZapCard(
            backgroundColor: ZapColors.safe.withOpacity(0.08),
            borderColor: ZapColors.safe.withOpacity(0.3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_outline_rounded, color: ZapColors.safe, size: 20),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    '🟣 Section K Day 8/10 · $done/${_kAuditRows.length} audit items '
                    'unified this day — real bounded code changes, honestly documented '
                    'gaps for the rest.',
                    style: ZapTypography.bodySmall.copyWith(color: ZapColors.textPrimary, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          Text('day351_360.premium_polish_heading'.tr(),
              style: ZapTypography.headlineMedium
                  .copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            'Grepped premium/free tier/contact limit across lib/presentation/ — '
            'found 4 independent "what tier am I on" systems that never talked to '
            'each other. Only Day 308 was wired to the real Day 303 status before '
            'today.',
            style: ZapTypography.bodyMedium.copyWith(color: ZapColors.textSecondary),
          ),
          const SizedBox(height: ZapSpacing.xl),
          Text('SHARED BADGE — LIVE PREVIEW',
              style: ZapTypography.labelLarge.copyWith(color: ZapColors.textSecondary, letterSpacing: 1.2)),
          const SizedBox(height: ZapSpacing.sm),
          const ZapCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                PremiumTierBadge(planLabel: 'FREE', isPremium: false),
                PremiumTierBadge(planLabel: 'PREMIUM', isPremium: true),
                PremiumTierBadge(planLabel: 'PREMIUM_PLUS', isPremium: true),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          Text('AUDIT', style: ZapTypography.labelLarge.copyWith(color: ZapColors.textSecondary, letterSpacing: 1.2)),
          const SizedBox(height: ZapSpacing.sm),
          for (final row in _kAuditRows)
            ZapCard(
              margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(row.title,
                            style: ZapTypography.bodyMedium
                                .copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w700)),
                      ),
                      ZapBadge(
                        label: row.done ? 'UNIFIED' : 'DOCUMENTED GAP',
                        intent: row.done ? ZapBadgeIntent.safe : ZapBadgeIntent.warning,
                        size: ZapBadgeSize.small,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(row.finding, style: ZapTypography.bodySmall.copyWith(color: ZapColors.textSecondary, height: 1.45)),
                ],
              ),
            ),
          const SizedBox(height: ZapSpacing.xl),
          ZapButton.tonal(
            label: 'Open Day 92 (real-wired usage card)',
            icon: Icons.open_in_new_rounded,
            fullWidth: true,
            onPressed: () => context.push(AppRoutes.premiumFeatures),
          ),
          const SizedBox(height: ZapSpacing.huge),
        ],
      ),
    );
  }
}
