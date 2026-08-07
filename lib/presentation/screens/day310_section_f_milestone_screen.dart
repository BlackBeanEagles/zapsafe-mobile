/// Day 310 — Section F Milestone: Integration Complete
///
/// Celebration + checklist screen for Section F (Days 301-309,
/// "Production Wiring"). Mirrors [seedIntegrationAudit] from
/// `day301_backend_integration_audit_screen.dart` — the exact same
/// function, not a hand-copied duplicate list, so the counts shown here
/// can never drift from the real Day 301 audit screen.
///
/// Checklist rows below are this session's own real verification record
/// for Days 301-309 — each marked ✅ Verified or ⚠ Documented exception
/// with the real caveat inline, not silently marked green:
///   • Day 301 — audit seed itself; Auth OTP paths blocked by pending
///     backend DLT registration (not a frontend gap).
///   • Day 302-305 — live-wire days, verified in that session (already
///     merged to main before this one started).
///   • Day 306 — notification tiers; ack persisted via SharedPreferences,
///     not literally Hive (see that day's own header for why).
///   • Day 307 — SOS long-press ring; the Day 76 SOS_ACTIVE screen it
///     navigates to doesn't read `appStateProvider` yet (documented,
///     pre-existing, out of this polish day's scope).
///   • Day 308 — persistent status card; subscription tier row degrades
///     to "Unavailable offline" without a reachable backend (by design).
///   • Day 309 — vault search; found + documented a real unwired
///     `GET /api/v1/evidence/search/` endpoint, added to the Day 301
///     audit rather than silently left out.
///
/// Tag: 🔗 (milestone, not a POLISH edit)
///
/// Route: AppRoutes.sectionFMilestone
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
import 'day301_backend_integration_audit_screen.dart';

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

const _kSectionFChecklist = [
  _ChecklistRow(
    day: 'Day 301',
    title: 'Backend Integration Audit Hub',
    verified: false,
    note: 'Auth OTP paths blocked by pending backend DLT registration — '
        'documented, not a frontend gap.',
  ),
  _ChecklistRow(
    day: 'Day 302',
    title: 'Wire Analytics APIs',
    verified: true,
    note: 'GET sos-summary/, detections/, response-rate/, device-health/ — real.',
  ),
  _ChecklistRow(
    day: 'Day 303',
    title: 'Wire Razorpay Premium Flow',
    verified: true,
    note: 'POST create/, GET status/, POST cancel/ — real; checkout is a '
        'documented manual test-mode step.',
  ),
  _ChecklistRow(
    day: 'Day 304',
    title: 'Wire SOS Delivery Status',
    verified: true,
    note: 'GET sos/<id>/delivery-status/ polled — real MSG91/FCM cascade.',
  ),
  _ChecklistRow(
    day: 'Day 305',
    title: 'Accept-Language Header Wiring',
    verified: true,
    note: 'Real Dio interceptor; backend AcceptLanguageMiddleware confirmed live.',
  ),
  _ChecklistRow(
    day: 'Day 306',
    title: 'Production Notification Tiers',
    verified: false,
    note: 'Ack persisted via SharedPreferences, not literally Hive — follows '
        'the Day 37 GpsStorage precedent (main.dart never calls '
        'Hive.initFlutter()).',
  ),
  _ChecklistRow(
    day: 'Day 307',
    title: 'Production SOS Long-Press Ring',
    verified: false,
    note: 'Real trigger dispatch works end-to-end; the Day 76 SOS_ACTIVE '
        'screen it navigates to doesn\'t read appStateProvider yet '
        '(pre-existing, out of scope).',
  ),
  _ChecklistRow(
    day: 'Day 308',
    title: 'Production Persistent Status Card',
    verified: true,
    note: 'Mode/battery/DCS/GPS/tier all real signals; tier degrades to '
        '"Unavailable offline" without a reachable backend, by design.',
  ),
  _ChecklistRow(
    day: 'Day 309',
    title: 'Production Evidence Vault Search',
    verified: false,
    note: 'Filters real + offline; found an unwired real search endpoint '
        '(Day 209) and added it to the Day 301 audit instead of hiding it.',
  ),
];

class Day310SectionFMilestoneScreen extends StatelessWidget {
  const Day310SectionFMilestoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final audit = seedIntegrationAudit();
    final live = audit.where((e) => e.status == AuditStatus.live).length;
    final mock = audit.where((e) => e.status == AuditStatus.mock).length;
    final missing = audit.where((e) => e.status == AuditStatus.missing).length;
    const polishItemsShipped = 4; // Days 306, 307, 308, 309

    return Scaffold(
      appBar: AppBar(title: Text('day306_310.milestone_title'.tr())),
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
              child: const Icon(Icons.flag_circle_rounded, color: ZapColors.safe, size: 56),
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          Center(
            child: Text('day306_310.milestone_heading'.tr(),
                style: ZapTypography.displaySmall
                    .copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center),
          ),
          const SizedBox(height: ZapSpacing.sm),
          Center(
            child: Text(
              'Section F · Production Wiring · Days 301-309',
              style: ZapTypography.bodyMedium.copyWith(color: ZapColors.textSecondary),
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),

          // ─── Stat grid ────────────────────────────────────────────────
          Row(
            children: [
              _StatTile(label: 'APIs wired', value: '$live', color: ZapColors.safe),
              const SizedBox(width: ZapSpacing.sm),
              const _StatTile(label: 'Polish items shipped', value: '$polishItemsShipped', color: ZapColors.info),
            ],
          ),
          const SizedBox(height: ZapSpacing.sm),
          Row(
            children: [
              _StatTile(label: 'Endpoints audited', value: '${audit.length}', color: ZapColors.textSecondary),
              const SizedBox(width: ZapSpacing.sm),
              _StatTile(label: 'Documented exceptions', value: '$mock+$missing', color: ZapColors.warning),
            ],
          ),
          const SizedBox(height: ZapSpacing.xl),

          // ─── Checklist ───────────────────────────────────────────────
          Text('SECTION F CHECKLIST',
              style: ZapTypography.labelLarge.copyWith(color: ZapColors.textSecondary, letterSpacing: 1.2)),
          const SizedBox(height: ZapSpacing.sm),
          for (final row in _kSectionFChecklist)
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
                    'Section F complete → Section G begins.',
                    style: ZapTypography.bodyMedium.copyWith(color: ZapColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: ZapSpacing.xl),
          ZapButton.elevated(
            label: 'Open Day 301 audit (refreshed: $live live / $mock mock / $missing missing)',
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
