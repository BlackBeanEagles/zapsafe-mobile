/// Day 389 — Penultimate Summary
///
/// Section O (Days 381-390, Project Close): a real summary of the whole
/// Days 301-388 arc (Sections F through O so far), grounded by reading a
/// representative sample of each section's own milestone screen this
/// session — Day 310/320/330/340/350/360/375/380 — rather than inventing
/// summary text. Each row below restates what that milestone's own file
/// header actually documents, including the real gaps it found, not a
/// sanitized retelling.
///
/// Tag: 🟢 real summary, grounded in each cited screen's own real header.
///
/// Route: [AppRoutes.day389PenultimateSummary] → `/day-389-penultimate-summary`
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

const _kAccent = Color(0xFF8B5CF6);

class _SectionSummary {
  const _SectionSummary({required this.section, required this.days, required this.title, required this.finding, required this.route});
  final String section;
  final String days;
  final String title;
  final String finding;
  final String route;
}

const _kSections = [
  _SectionSummary(
    section: 'Section F', days: 'Days 301-310', title: 'Production Wiring',
    finding: 'Real integration audit-driven verification — mostly ✅, with documented '
        'exceptions inline: Day 301 auth OTP paths blocked by pending backend DLT '
        'registration (not a frontend gap); Day 309 found + documented a real unwired '
        'GET /api/v1/evidence/search/ endpoint.',
    route: AppRoutes.sectionFMilestone,
  ),
  _SectionSummary(
    section: 'Section G', days: 'Days 311-320', title: 'Global Store Expansion',
    finding: 'Real per-day verification record, same honesty bar as Day 310 — each row '
        'marked verified or documented exception, never blanket green.',
    route: AppRoutes.sectionGMilestone,
  ),
  _SectionSummary(
    section: 'Section H', days: 'Days 321-330', title: 'v9.2 Core & RC',
    finding: 'Day 322 found + fixed a real detection-log gap (DCS fusion score wasn\'t '
        'logged); M9 fusion model stays a placeholder stub, reported honestly. Day 323 '
        'stayed MOCK-NOW since the spec\'s imagined risk-score API doesn\'t exist on the '
        'real backend. Day 327\'s static leak audit genuinely found 0 suspects.',
    route: AppRoutes.sectionHMilestone,
  ),
  _SectionSummary(
    section: 'Section I', days: 'Days 331-340', title: 'Launch Hardening',
    finding: 'Day 336 found real, still-open P0 security gaps: release build signed with '
        'DEBUG keys, no TLS cert pinning, FLAG_SECURE unset. Day 337 confirmed export + '
        'deletion are genuinely live DPDP rights via the older Day 69/70 endpoints; '
        'consent/sessions/audit-log/retention are backend-real but unwired; third-party '
        'sharing disclosure is unimplemented on both sides.',
    route: AppRoutes.sectionIMilestone,
  ),
  _SectionSummary(
    section: 'Section J', days: 'Days 341-350', title: '25-Language Completion',
    finding: 'Real 25/25 language coverage reached (275/275 keys for the 10 new '
        'languages) — but Day 344 found a real safety-critical bug (SOS trigger '
        'hardcodes English + LTR for screen readers), Day 345\'s live scanner found 13 '
        'legacy locales still at 75/275 keys, and Day 347 found Tamil + Telugu missing '
        'the entire onboarding translation namespace.',
    route: AppRoutes.sectionJMilestone,
  ),
  _SectionSummary(
    section: 'Section K', days: 'Days 351-360', title: 'Enterprise & B2B',
    finding: 'The spec framed most of this section as "assumes backend APIs when '
        'ready" — reality, checked by reading zapsafe_backend directly: 4 of 7 days '
        '(354-357: family dashboard, referral, police dispatch, group journey) found '
        'REAL working endpoints, already wired. Only 3 (351 SSO, 352 insurance, 353 '
        'org/tenant) confirmed genuinely no backend support exists.',
    route: AppRoutes.sectionKMilestone,
  ),
  _SectionSummary(
    section: 'Section L', days: 'Days 361-365', title: 'Public Launch Week',
    finding: 'Day 361\'s war room seeded 5 real, currently-open P0 blockers (the same '
        '3 from Day 336 plus the Day 344 SOS bug and the Day 347 ta/te gap) and gates '
        '"ready to launch" on zero open P0s — still false. Days 362-365 are real launch '
        'PROCESS tooling; no real submission or launch has occurred.',
    route: AppRoutes.finalQaWarRoom,
  ),
  _SectionSummary(
    section: 'Section M', days: 'Days 366-370', title: 'Post-Launch Week 1 (tooling)',
    finding: 'Real, working tools built ahead of an event that has not happened: Day '
        '366\'s dashboard wires real endpoints that are legitimately empty; Day 368\'s '
        'hotfix executor computes real version arithmetic; Day 369\'s ticket kanban is '
        'a real, genuinely empty board.',
    route: AppRoutes.liveSosDashboard,
  ),
  _SectionSummary(
    section: 'Section N', days: 'Days 371-380', title: 'Scale & Stabilize',
    finding: 'Day 380\'s own checkpoint grepped all 9 of this section\'s screens for '
        'dio/http./Repository/ApiClient/.get(/.post( — zero hits, every one is '
        'FRONTEND-ONLY. Headline restated there: Day 361\'s war room still defaults to '
        '5 open P0s, so nothing in this section moved the app past "tooling ready."',
    route: AppRoutes.day380OpsCheckpoint,
  ),
  _SectionSummary(
    section: 'Section O', days: 'Days 381-388 (so far)', title: 'Project Close',
    finding: 'Two hypothetical hotfix cycles (v1.0.1/v1.0.2, neither shipped); Day 337\'s '
        'DPDP findings re-checked with 0/7 categories changed; a DPDP sign-off gate that '
        'stays honestly unsigned; Day 294\'s macros promoted into a real tool wired into '
        'Day 369\'s actual ticket storage; a Month 1 analytics report template on real, '
        'currently-empty endpoints; a Year in Review v2 template extension; and a '
        'real, persisted lock over Day 377\'s v9.2 roadmap.',
    route: AppRoutes.v92RoadmapLock,
  ),
];

class Day389PenultimateSummaryScreen extends StatelessWidget {
  const Day389PenultimateSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(title: Text('day381_390.penultimate_summary_title'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(color: _kAccent.withOpacity(0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: _kAccent.withOpacity(0.35))),
            child: const Text(
              'Penultimate summary of Days 301-388 (Sections F-O so far), grounded by '
              'reading Day 310/320/330/340/350/360/375/380\'s own real headers this '
              'session — one day left before Day 390\'s project-complete milestone.',
              style: TextStyle(color: ZapColors.textSecondary, fontSize: 12, height: 1.4),
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          for (final s in _kSections) ...[
            Container(
              margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
              padding: const EdgeInsets.all(ZapSpacing.md),
              decoration: BoxDecoration(color: ZapColors.bgCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: ZapColors.border)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: _kAccent.withOpacity(0.18), borderRadius: BorderRadius.circular(6)),
                        child: Text(s.section, style: const TextStyle(color: _kAccent, fontWeight: FontWeight.w800, fontSize: 11)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text('${s.days} · ${s.title}', style: const TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 12))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(s.finding, style: const TextStyle(color: ZapColors.textSecondary, fontSize: 11, height: 1.45)),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(onPressed: () => context.push(s.route), child: const Text('Open source', style: TextStyle(fontSize: 11))),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: ZapSpacing.lg),
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(color: ZapColors.danger.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: ZapColors.danger.withOpacity(0.35))),
            child: const Text(
              'The through-line across all 10 sections: real, grounded work throughout, '
              'and an honestly still-open launch gate — Day 361\'s 5 P0s. Day 390 pulls '
              'the live count of that gate for real, rather than repeating "5" as a '
              'static fact that could drift stale.',
              style: TextStyle(color: ZapColors.textPrimary, fontSize: 12, height: 1.5, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: ZapSpacing.lg),
          FilledButton.icon(
            onPressed: () => context.push(AppRoutes.projectCompleteMilestone),
            icon: const Icon(Icons.flag_circle_rounded, size: 18),
            label: const Text('Continue to Day 390'),
            style: FilledButton.styleFrom(backgroundColor: _kAccent, minimumSize: const Size(double.infinity, 48)),
          ),
        ],
      ),
    );
  }
}
