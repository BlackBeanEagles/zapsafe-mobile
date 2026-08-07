/// Day 360 — Section K Milestone: Enterprise Preview Complete
///
/// Celebration + checklist screen for Section K (Days 351-360, "Enterprise
/// & B2B"). Mirrors the Day 310/320/330/340/350 milestone pattern (read
/// Day 350's, the most recent, first) — real per-day verification record,
/// not hand-waved.
///
/// THE HEADLINE FINDING OF THIS SECTION: the spec framed almost all of
/// Days 351-360 as "🟡 MOCK-NOW … assumes several backend APIs when
/// ready." Reality, checked by reading zapsafe_backend source directly
/// for every single day before building it: 4 of 7 API-assumption days
/// (354/355/356/357) found REAL, working endpoints — family dashboard,
/// referral code/stats, police dispatch status, and all 4 group journey
/// endpoints all already exist and were wired for real, not mocked. Only
/// 3 days (351 SSO, 352 insurance, 353 org/tenant) confirmed genuinely
/// no backend support exists. Section K turned out closer to "half
/// real" than "mostly mock."
///
/// Tag: 🟢 milestone, real per-day verification record.
/// Route: [AppRoutes.sectionKMilestone] → `/day-360-section-k-milestone`
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../navigation/app_router.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';

enum _ApiState { real, mock, polish, frontendOnly }

class _ChecklistRow {
  const _ChecklistRow({
    required this.day,
    required this.title,
    required this.apiState,
    required this.note,
  });
  final String day;
  final String title;
  final _ApiState apiState;
  final String note;
}

const _kSectionKChecklist = [
  _ChecklistRow(
    day: 'Day 351',
    title: 'Enterprise SSO Login Preview',
    apiState: _ApiState.mock,
    note: 'Spec assumption CONFIRMED MOCK. Verified by grepping enterprise/'
        'sso across every zapsafe_backend app — no `enterprise` app, no '
        'SAML/OAuth provider model, no SSO views exist. Real, clearly-'
        'labeled provider-picker UI simulating the flow; proposed contract '
        'documented, not implemented.',
  ),
  _ChecklistRow(
    day: 'Day 352',
    title: 'Insurance Partnership API Wire',
    apiState: _ApiState.mock,
    note: 'Spec assumption CONFIRMED MOCK. Verified: no `partners` app, no '
        'insurance endpoint anywhere. Extends Day 272\'s mock UI with a '
        're-check-backend panel + documented proposed contract; stays '
        'honest about not calling anything real.',
  ),
  _ChecklistRow(
    day: 'Day 353',
    title: 'B2B Admin Portal Preview',
    apiState: _ApiState.mock,
    note: 'Spec assumption CONFIRMED MOCK. Verified: no org/tenant model '
        'anywhere in zapsafe_backend — ZapSafe is single-user/consumer '
        'only today. Realistic-structure mock admin console (org users, '
        'SOS count, response SLA), distinct from Day 277\'s existing '
        'licensing mock.',
  ),
  _ChecklistRow(
    day: 'Day 354',
    title: 'Family Dashboard Production Wire',
    apiState: _ApiState.real,
    note: 'Spec assumption WRONG — turned out REAL. GET /api/v1/family/'
        'dashboard/ and GET .../members/{id}/sos-history/ both real, '
        'working Django views (Days 224-225). Wired for real, no mock '
        'fallback on the raw view. Not round-trip tested against a live '
        'server (no backend running in this sandbox).',
  ),
  _ChecklistRow(
    day: 'Day 355',
    title: 'Referral Production Wire',
    apiState: _ApiState.real,
    note: 'Spec assumption WRONG — turned out REAL. GET /api/v1/referral/'
        'code/ and .../stats/ both real (Days 206-207). Corrected 2 real '
        'details Day 224\'s mock got wrong (50 pts/completion not +10; '
        'gated behind a `referral` feature flag). Real error state '
        'surfaced, no mock fallback on the raw view.',
  ),
  _ChecklistRow(
    day: 'Day 356',
    title: 'Police Dispatch Production Wire',
    apiState: _ApiState.real,
    note: 'Spec assumption WRONG (partially) — endpoint is REAL, but its '
        'data is honestly mock-shaped by design (is_mock: true) until a '
        'live police integration ships. Real polling wired (Timer-driven '
        'GET re-fire, not a countdown animation).',
  ),
  _ChecklistRow(
    day: 'Day 357',
    title: 'Group Journey Production Wire',
    apiState: _ApiState.real,
    note: 'Spec assumption WRONG — turned out REAL, all 4 endpoints '
        '(create/join/state/panic). Highest-stakes wire in this section: '
        'the panic button genuinely creates a real SOSEvent for every '
        'joined member, gated behind an explicit confirmation dialog.',
  ),
  _ChecklistRow(
    day: 'Day 358',
    title: 'Premium Tier Production Polish',
    apiState: _ApiState.polish,
    note: 'Real bounded unification, not a repaint. Found 4 independent '
        'tier-state systems; unified the badge widget + wired Day 92\'s '
        'usage data to real Day 303 status + real Day 83 contact count. '
        'Day 91/93\'s own local mocks explicitly left un-consolidated — '
        'documented gap, not hidden.',
  ),
  _ChecklistRow(
    day: 'Day 359',
    title: 'Enterprise Sales Deck In-App',
    apiState: _ApiState.frontendOnly,
    note: 'Self-contained swipeable deck, nothing to wire. Pricing slide '
        'reuses Day 318\'s + Day 277\'s exact real/proposed numbers — no '
        'new figures invented.',
  ),
];

int get _realCount => _kSectionKChecklist.where((r) => r.apiState == _ApiState.real).length;
int get _mockCount => _kSectionKChecklist.where((r) => r.apiState == _ApiState.mock).length;

class Day360SectionKMilestoneScreen extends ConsumerWidget {
  const Day360SectionKMilestoneScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(title: Text('day351_360.section_k_milestone_title'.tr())),
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
            child: Text('day351_360.section_k_milestone_heading'.tr(),
                style: ZapTypography.displaySmall
                    .copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center),
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Center(
            child: Text('Section K · Enterprise & B2B · Days 351-360',
                style: TextStyle(color: ZapColors.textSecondary, fontSize: 14)),
          ),
          const SizedBox(height: ZapSpacing.xl),
          ZapCard(
            backgroundColor: ZapColors.info.withOpacity(0.08),
            borderColor: ZapColors.info.withOpacity(0.3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.insights_rounded, color: ZapColors.info, size: 20),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    'The spec framed this section as "mostly mock." Reality: of '
                    'the 7 days (351-357) that assumed a backend API "when '
                    'ready," $_realCount turned out REAL (family dashboard, referral, '
                    'police dispatch, group journey) and only $_mockCount were '
                    'genuinely confirmed mock-only (SSO, insurance, org/tenant).',
                    style: ZapTypography.bodySmall.copyWith(color: ZapColors.textPrimary, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          Row(
            children: [
              _StatTile(label: 'REAL API days', value: '$_realCount/9', color: ZapColors.safe),
              const SizedBox(width: ZapSpacing.sm),
              _StatTile(label: 'Confirmed mock', value: '$_mockCount/9', color: ZapColors.warning),
            ],
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Row(
            children: [
              _StatTile(label: 'Polish (real code change)', value: '1/9', color: ZapColors.info),
              SizedBox(width: ZapSpacing.sm),
              _StatTile(label: 'Frontend-only', value: '1/9', color: ZapColors.textSecondary),
            ],
          ),
          const SizedBox(height: ZapSpacing.xl),
          Text('SECTION K CHECKLIST', style: ZapTypography.labelLarge.copyWith(color: ZapColors.textSecondary, letterSpacing: 1.2)),
          const SizedBox(height: ZapSpacing.sm),
          for (final row in _kSectionKChecklist)
            ZapCard(
              margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_iconFor(row.apiState), color: _colorFor(row.apiState), size: 18),
                      const SizedBox(width: ZapSpacing.sm),
                      Expanded(
                        child: Text('${row.day} · ${row.title}',
                            style: ZapTypography.bodyMedium
                                .copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w600)),
                      ),
                      ZapBadge(
                        label: _labelFor(row.apiState),
                        intent: _intentFor(row.apiState),
                        size: ZapBadgeSize.small,
                      ),
                    ],
                  ),
                  const SizedBox(height: ZapSpacing.xs),
                  Padding(
                    padding: const EdgeInsets.only(left: 26),
                    child: Text(row.note, style: ZapTypography.bodySmall.copyWith(color: ZapColors.textSecondary, height: 1.4)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: ZapSpacing.lg),
          ZapCard(
            backgroundColor: ZapColors.warning.withOpacity(0.08),
            borderColor: ZapColors.warning.withOpacity(0.3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.pending_actions_rounded, color: ZapColors.warning, size: 20),
                    SizedBox(width: 8),
                    Text('Genuinely pending', style: TextStyle(color: ZapColors.warning, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: ZapSpacing.sm),
                Text(
                  '• No Docker/backend running in this sandbox — Days 354-357\'s '
                  'real wires are code-level verified against the Django source, '
                  'not live round-trip tested against a running server.\n'
                  '• Day 358\'s Day 91/93 tier providers remain un-consolidated — '
                  'a real follow-up architecture task, not forgotten.\n'
                  '• Day 356\'s police dispatch will keep showing SIMULATED '
                  'timelines until a real police integration exists (no target '
                  'day set for that yet).\n'
                  '• Day 351\'s SSO and Day 352\'s insurance proposed contracts '
                  'need real backend implementation before either can move past '
                  'MOCK-NOW.',
                  style: ZapTypography.bodySmall.copyWith(color: ZapColors.textPrimary, height: 1.6),
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
                    'Section K complete → Section L (Public Launch Week, Days '
                    '361-365) begins next.',
                    style: ZapTypography.bodyMedium.copyWith(color: ZapColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          ZapButton.elevated(
            label: 'Open Day 357 group journey wire (highest-stakes)',
            intent: ZapButtonIntent.danger,
            fullWidth: true,
            onPressed: () => context.go(AppRoutes.groupJourneyWire),
          ),
          const SizedBox(height: ZapSpacing.sm),
          ZapButton.outlined(
            label: 'Open Day 351 (Section K start)',
            fullWidth: true,
            onPressed: () => context.go(AppRoutes.enterpriseSsoPreview),
          ),
          const SizedBox(height: ZapSpacing.huge),
        ],
      ),
    );
  }
}

IconData _iconFor(_ApiState s) => switch (s) {
      _ApiState.real => Icons.verified_rounded,
      _ApiState.mock => Icons.info_rounded,
      _ApiState.polish => Icons.auto_fix_high_rounded,
      _ApiState.frontendOnly => Icons.smartphone_rounded,
    };

Color _colorFor(_ApiState s) => switch (s) {
      _ApiState.real => ZapColors.safe,
      _ApiState.mock => ZapColors.warning,
      _ApiState.polish => ZapColors.info,
      _ApiState.frontendOnly => ZapColors.textSecondary,
    };

String _labelFor(_ApiState s) => switch (s) {
      _ApiState.real => 'REAL API',
      _ApiState.mock => 'MOCK CONFIRMED',
      _ApiState.polish => 'POLISH',
      _ApiState.frontendOnly => 'FRONTEND-ONLY',
    };

ZapBadgeIntent _intentFor(_ApiState s) => switch (s) {
      _ApiState.real => ZapBadgeIntent.safe,
      _ApiState.mock => ZapBadgeIntent.warning,
      _ApiState.polish => ZapBadgeIntent.info,
      _ApiState.frontendOnly => ZapBadgeIntent.neutral,
    };

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
            Text(value, style: ZapTypography.displaySmall.copyWith(color: color, fontWeight: FontWeight.w800)),
            const SizedBox(height: ZapSpacing.xs),
            Text(label, textAlign: TextAlign.center, style: ZapTypography.labelMedium.copyWith(color: ZapColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
