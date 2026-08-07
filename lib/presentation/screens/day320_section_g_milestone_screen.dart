/// Day 320 — Section G Milestone: Global Listings Ready
///
/// Celebration + checklist screen for Section G (Days 311-319, "Global
/// Store Expansion"). Mirrors the Day 310 `Day310SectionFMilestoneScreen`
/// structure (hero, stat grid, per-day checklist with real caveats
/// inline, not blanket green) — Section G has no equivalent to Day 301's
/// `seedIntegrationAudit()` shared function to mirror (this section isn't
/// an integration audit), so the checklist rows below are this session's
/// own real verification record for Days 311-319, written the same way
/// Day 310's were: each row marked ✅ Verified or ⚠ Documented exception
/// with the actual caveat, never silently marked green.
///
/// Tag: 🟢 FRONTEND-ONLY (milestone/checklist screen, not a POLISH edit)
///
/// Route: AppRoutes.sectionGMilestone
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../navigation/app_router.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';

class _ChecklistRow {
  const _ChecklistRow({
    required this.day,
    required this.title,
    required this.verified,
    required this.note,
  });
  final String day;
  final String title;
  final bool verified; // true = clean verify, false = documented exception
  final String note;
}

const _kSectionGChecklist = [
  _ChecklistRow(
    day: 'Day 311',
    title: 'EU Emergency Numbers Pack',
    verified: false,
    note: 'The spec\'s reference file day238_region_emergency_numbers_screen.dart '
        'doesn\'t exist anywhere in this repo or on main — built against the '
        'emergency_numbers.json shape directly instead. Also fixed a pre-existing '
        'pubspec.yaml gap that left that JSON unbundled.',
  ),
  _ChecklistRow(
    day: 'Day 312',
    title: 'LATAM Emergency Numbers Pack',
    verified: false,
    note: '10 countries shipped (5 named in spec + 5 more); countries with no '
        'confidently-verifiable number (e.g. Bolivia) were deliberately omitted, '
        'not guessed.',
  ),
  _ChecklistRow(
    day: 'Day 313',
    title: 'SEA Emergency Numbers Pack',
    verified: true,
    note: 'All 6 spec-named countries, real documented numbers.',
  ),
  _ChecklistRow(
    day: 'Day 314',
    title: 'Play Store EU Listing Copy Generator',
    verified: false,
    note: 'DE/FR/ES copy is a best-effort draft translation, not professionally '
        'reviewed by a native speaker — flagged in-screen as editable drafts. '
        'Correctly cites the real LP27 (Lock Screen Suppression) instead of a '
        'fabricated privacy feature.',
  ),
  _ChecklistRow(
    day: 'Day 315',
    title: 'App Store EU Localization Pack',
    verified: false,
    note: 'Same translation caveat as Day 314. Screenshot pixel sizes are real as '
        'of this session but Apple periodically adds new size classes — flagged '
        'in-screen to re-verify before a real submission.',
  ),
  _ChecklistRow(
    day: 'Day 316',
    title: 'Play Console Staged Rollout Controller',
    verified: false,
    note: 'No Google Play Developer API exists for this — the stage tracker is an '
        'explicit local simulation, not a real Play Console call. Documented as such '
        'in-screen, not disguised as live.',
  ),
  _ChecklistRow(
    day: 'Day 317',
    title: 'App Store Phased Release Controller',
    verified: true,
    note: 'Apple\'s real fixed 7-day schedule (1/2/5/10/20/50/100%), real TestFlight '
        'tiers, real clipboard Markdown export (no share_plus dependency in this repo).',
  ),
  _ChecklistRow(
    day: 'Day 318',
    title: 'Regional Pricing Matrix',
    verified: false,
    note: 'Only India (₹99/₹199, Razorpay) is real, live pricing. EU/LATAM/SEA '
        'figures are this session\'s own proposed placeholders, badged PROPOSED '
        'throughout — not a decided price, no USD/EUR billing exists.',
  ),
  _ChecklistRow(
    day: 'Day 319',
    title: 'GDPR Consent Flow Wire',
    verified: false,
    note: 'MOCK-NOW by design. Discovered GET/PUT /api/v1/account/consent/ is '
        'actually real and live on the backend (contradicting the spec\'s '
        'assumption) — Day 301\'s audit already flags it backend-real/frontend-mock, '
        'and this screen keeps it mock intentionally, not because the API is missing.',
  ),
];

class Day320SectionGMilestoneScreen extends StatelessWidget {
  const Day320SectionGMilestoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final verified = _kSectionGChecklist.where((e) => e.verified).length;
    final exceptions = _kSectionGChecklist.where((e) => !e.verified).length;
    const emergencyPacksShipped = 3; // Days 311, 312, 313
    const listingGeneratorsShipped = 2; // Days 314, 315
    const rolloutRunbooksShipped = 2; // Days 316, 317

    return Scaffold(
      appBar: AppBar(title: Text('day311_320.milestone_title'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(ZapSpacing.xxl),
              decoration: BoxDecoration(
                color: ZapColors.safe.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: ZapColors.safe.withOpacity(0.3), width: 2),
              ),
              child: const Icon(Icons.public_rounded, color: ZapColors.safe, size: 56),
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          Center(
            child: Text('day311_320.milestone_heading'.tr(),
                style: ZapTypography.displaySmall
                    .copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center),
          ),
          const SizedBox(height: ZapSpacing.sm),
          Center(
            child: Text(
              'Section G · Global Store Expansion · Days 311-319',
              style: ZapTypography.bodyMedium.copyWith(color: ZapColors.textSecondary),
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),

          // ─── Stat grid ────────────────────────────────────────────────
          const Row(
            children: [
              _StatTile(label: 'Emergency packs shipped', value: '$emergencyPacksShipped', color: ZapColors.safe),
              SizedBox(width: ZapSpacing.sm),
              _StatTile(label: 'Listing generators shipped', value: '$listingGeneratorsShipped', color: ZapColors.info),
            ],
          ),
          const SizedBox(height: ZapSpacing.sm),
          Row(
            children: [
              const _StatTile(label: 'Rollout runbooks shipped', value: '$rolloutRunbooksShipped', color: ZapColors.warning),
              const SizedBox(width: ZapSpacing.sm),
              _StatTile(label: 'Documented exceptions', value: '$exceptions', color: ZapColors.textSecondary),
            ],
          ),
          const SizedBox(height: ZapSpacing.xl),

          // ─── Checklist ───────────────────────────────────────────────
          Text('SECTION G CHECKLIST',
              style: ZapTypography.labelLarge.copyWith(color: ZapColors.textSecondary, letterSpacing: 1.2)),
          const SizedBox(height: ZapSpacing.sm),
          for (final row in _kSectionGChecklist)
            ZapCard(
              margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        row.verified ? Icons.check_circle_rounded : Icons.info_rounded,
                        color: row.verified ? ZapColors.safe : ZapColors.warning,
                        size: 18,
                      ),
                      const SizedBox(width: ZapSpacing.sm),
                      Expanded(
                        child: Text('${row.day} · ${row.title}',
                            style: ZapTypography.bodyMedium
                                .copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w600)),
                      ),
                      ZapBadge(
                        label: row.verified ? 'VERIFIED' : 'EXCEPTION',
                        intent: row.verified ? ZapBadgeIntent.safe : ZapBadgeIntent.warning,
                        size: ZapBadgeSize.small,
                      ),
                    ],
                  ),
                  const SizedBox(height: ZapSpacing.xs),
                  Padding(
                    padding: const EdgeInsets.only(left: 26),
                    child: Text(row.note,
                        style: ZapTypography.bodySmall.copyWith(color: ZapColors.textSecondary, height: 1.4)),
                  ),
                ],
              ),
            ),

          const SizedBox(height: ZapSpacing.lg),
          ZapCard(
            backgroundColor: ZapColors.info.withOpacity(0.08),
            borderColor: ZapColors.info.withOpacity(0.3),
            child: Row(
              children: [
                const Icon(Icons.timeline_rounded, color: ZapColors.info, size: 20),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    'Section G complete → Section H begins.',
                    style: ZapTypography.bodyMedium.copyWith(color: ZapColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: ZapSpacing.xl),
          ZapButton.elevated(
            label: 'Open Day 301 audit ($verified verified / $exceptions documented exceptions here)',
            intent: ZapButtonIntent.info,
            fullWidth: true,
            onPressed: () => context.go(AppRoutes.integrationAudit),
          ),
          const SizedBox(height: ZapSpacing.sm),
          ZapButton.outlined(
            label: 'Open production dashboard',
            fullWidth: true,
            onPressed: () => context.go(AppRoutes.dashboard),
          ),
          const SizedBox(height: ZapSpacing.huge),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ZapCard(
        backgroundColor: color.withOpacity(0.08),
        borderColor: color.withOpacity(0.3),
        child: Column(
          children: [
            Text(value,
                style: ZapTypography.displaySmall.copyWith(color: color, fontWeight: FontWeight.w800)),
            const SizedBox(height: ZapSpacing.xs),
            Text(label,
                textAlign: TextAlign.center,
                style: ZapTypography.labelMedium.copyWith(color: ZapColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
