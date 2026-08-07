/// Day 375 — Section M Milestone: Week 1 Stable
///
/// Celebration + checklist screen for Section M (Days 366-374, "Post-Launch
/// Week 1" + the first 4 days of Section N). Mirrors the Day 310/320/330/
/// 340/350/360 milestone pattern (read Day 360's, the most recent, first)
/// — a real per-day verification record, not hand-waved.
///
/// **Covers Days 366-374**: the Day 366-370 batch (already merged to
/// `main`) plus this session's own Days 371-374. Every row below reflects
/// what each screen's own file header actually documents, not a
/// re-guess. Since there is still no real launch (Day 361's war room: 5
/// open P0s; Day 366's dashboard: real endpoints, legitimately empty),
/// every "REAL TOOL" verdict below means real, working, honestly-empty
/// tooling — never a claim that a real launch/rollout/hotfix has
/// happened.
///
/// Tag: 🟢 milestone, real per-day verification record.
///
/// Route: [AppRoutes.sectionMMilestone] → `/day-375-section-m-milestone`
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

enum _Verdict { realTool, realApiEmpty, frontendOnly }

class _ChecklistRow {
  const _ChecklistRow({required this.day, required this.title, required this.verdict, required this.note});
  final String day;
  final String title;
  final _Verdict verdict;
  final String note;
}

const _kSectionMChecklist = [
  _ChecklistRow(
    day: 'Day 366',
    title: 'Live SOS Success Dashboard',
    verdict: _Verdict.realApiEmpty,
    note: 'Wires REAL Day 302 analytics endpoints (sos-summary, contacts/'
        'response-rate), raw with no mock fallback. Legitimately shows '
        'zero/empty since no real launch exists — the correct honest '
        'state, not a bug.',
  ),
  _ChecklistRow(
    day: 'Day 367',
    title: 'Ratings & Reviews Monitor',
    verdict: _Verdict.frontendOnly,
    note: 'Genuinely 100% manual-paste — neither Play nor App Store expose '
        'an in-app-readable reviews API, so manual entry IS the correct '
        'real workflow, not a placeholder for a future API.',
  ),
  _ChecklistRow(
    day: 'Day 368',
    title: 'Hotfix Release Executor',
    verdict: _Verdict.frontendOnly,
    note: 'Real version-bump arithmetic from the actual pubspec.yaml '
        'version (1.0.0+1). Nothing mutates pubspec.yaml or ships '
        'anything; links to Day 293\'s playbook and Day 316\'s rollout.',
  ),
  _ChecklistRow(
    day: 'Day 369',
    title: 'Support Ticket Triage',
    verdict: _Verdict.frontendOnly,
    note: 'Real, genuinely empty kanban (New/Investigating/Resolved) — no '
        'real tickets exist yet. Persists via SharedPreferences, links '
        'to Day 294\'s real macros.',
  ),
  _ChecklistRow(
    day: 'Day 370',
    title: 'Week 1 Retrospective',
    verdict: _Verdict.frontendOnly,
    note: 'Explicitly a fillable TEMPLATE for a retrospective that has not '
        'happened — every field starts empty, example text clearly '
        'labeled and never pre-filled.',
  ),
  _ChecklistRow(
    day: 'Day 371',
    title: 'Rollout 50% → 100% Checklist',
    verdict: _Verdict.frontendOnly,
    note: 'Real go/no-go checklist for a rollout that has NOT started — '
        '8 real gate items, all default unchecked, backend-headroom '
        'item cites Day 257\'s real production load test.',
  ),
  _ChecklistRow(
    day: 'Day 372',
    title: 'Performance at Scale Report',
    verdict: _Verdict.realApiEmpty,
    note: 'DAU is a clearly-labeled EXAMPLE, not real. Latency/error rate '
        'are real manual-paste fields. Includes Day 257\'s real production '
        'load-test numbers as the one genuinely real data point that '
        'exists today.',
  ),
  _ChecklistRow(
    day: 'Day 373',
    title: 'False Positive Field Analysis',
    verdict: _Verdict.frontendOnly,
    note: 'Real, genuinely empty FP-report categorization tool — no real '
        'users exist yet. Links to Day 329\'s real DCS sensitivity slider '
        'as the downstream consumer of a real FP rate.',
  ),
  _ChecklistRow(
    day: 'Day 374',
    title: 'Model Retrain Feedback Export',
    verdict: _Verdict.frontendOnly,
    note: 'Real CSV/JSON export mechanism, starts genuinely empty — '
        'checked assets/models/DAY2*.md (40+ files): all Kaggle-side '
        'training records, none are on-device field misclassification '
        'logs.',
  ),
];

int get _realApiCount => _kSectionMChecklist.where((r) => r.verdict == _Verdict.realApiEmpty).length;
int get _frontendOnlyCount => _kSectionMChecklist.where((r) => r.verdict == _Verdict.frontendOnly).length;

class Day375SectionMMilestoneScreen extends ConsumerWidget {
  const Day375SectionMMilestoneScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(title: Text('day371_380.section_m_milestone_title'.tr())),
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
            child: Text('Section M · Week 1 Stable',
                style: ZapTypography.displaySmall.copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center),
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Center(
            child: Text('Post-Launch Week 1 + Section N start · Days 366-374',
                style: TextStyle(color: ZapColors.textSecondary, fontSize: 14)),
          ),
          const SizedBox(height: ZapSpacing.xl),
          ZapCard(
            backgroundColor: ZapColors.warning.withOpacity(0.08),
            borderColor: ZapColors.warning.withOpacity(0.3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_rounded, color: ZapColors.warning, size: 20),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    'No real launch has happened (Day 361: 5 open P0s). Every '
                    'row below is real, working tooling — a real API wire that '
                    'legitimately shows empty data, or a real frontend-only '
                    'tool — never a claim that a real rollout, hotfix, or '
                    'launch event has occurred.',
                    style: ZapTypography.bodySmall.copyWith(color: ZapColors.textPrimary, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          Row(
            children: [
              _StatTile(label: 'Real API (empty)', value: '$_realApiCount/9', color: ZapColors.info),
              const SizedBox(width: ZapSpacing.sm),
              _StatTile(label: 'Frontend-only tools', value: '$_frontendOnlyCount/9', color: ZapColors.safe),
            ],
          ),
          const SizedBox(height: ZapSpacing.xl),
          Text('SECTION M CHECKLIST (366-374)', style: ZapTypography.labelLarge.copyWith(color: ZapColors.textSecondary, letterSpacing: 1.2)),
          const SizedBox(height: ZapSpacing.sm),
          for (final row in _kSectionMChecklist)
            ZapCard(
              margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_iconFor(row.verdict), color: _colorFor(row.verdict), size: 18),
                      const SizedBox(width: ZapSpacing.sm),
                      Expanded(
                        child: Text('${row.day} · ${row.title}',
                            style: ZapTypography.bodyMedium.copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w600)),
                      ),
                      ZapBadge(label: _labelFor(row.verdict), intent: _intentFor(row.verdict), size: ZapBadgeSize.small),
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
                  '• The real launch itself — Day 361\'s war room still lists 5 '
                  'open P0s, so nothing in this section can move past "tooling '
                  'ready" until that gate clears.\n'
                  '• Day 366/372\'s real API wires stay legitimately empty until '
                  'real traffic exists — this is correct, not a follow-up task.\n'
                  '• Day 373/374\'s field-data tools have nothing to show until '
                  'real users generate real reports/misclassifications.\n'
                  '• Day 379\'s 10K-users gate (later in Section N) will need to '
                  're-confirm Day 257\'s production ceiling once real traffic '
                  'patterns exist.',
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
                    'Section N (Scale & Stabilize, Days 376-385) continues next '
                    '— Days 376-380 land in this same session.',
                    style: ZapTypography.bodyMedium.copyWith(color: ZapColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          ZapButton.elevated(
            label: 'Open Day 361 war room (the real launch gate)',
            intent: ZapButtonIntent.danger,
            fullWidth: true,
            onPressed: () => context.go(AppRoutes.finalQaWarRoom),
          ),
          const SizedBox(height: ZapSpacing.sm),
          ZapButton.outlined(
            label: 'Open Day 366 (Section M start)',
            fullWidth: true,
            onPressed: () => context.go(AppRoutes.liveSosDashboard),
          ),
          const SizedBox(height: ZapSpacing.huge),
        ],
      ),
    );
  }
}

IconData _iconFor(_Verdict v) => switch (v) {
      _Verdict.realTool => Icons.verified_rounded,
      _Verdict.realApiEmpty => Icons.hourglass_empty_rounded,
      _Verdict.frontendOnly => Icons.smartphone_rounded,
    };

Color _colorFor(_Verdict v) => switch (v) {
      _Verdict.realTool => ZapColors.safe,
      _Verdict.realApiEmpty => ZapColors.info,
      _Verdict.frontendOnly => ZapColors.textSecondary,
    };

String _labelFor(_Verdict v) => switch (v) {
      _Verdict.realTool => 'REAL TOOL',
      _Verdict.realApiEmpty => 'REAL API · EMPTY',
      _Verdict.frontendOnly => 'FRONTEND-ONLY',
    };

ZapBadgeIntent _intentFor(_Verdict v) => switch (v) {
      _Verdict.realTool => ZapBadgeIntent.safe,
      _Verdict.realApiEmpty => ZapBadgeIntent.info,
      _Verdict.frontendOnly => ZapBadgeIntent.neutral,
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
