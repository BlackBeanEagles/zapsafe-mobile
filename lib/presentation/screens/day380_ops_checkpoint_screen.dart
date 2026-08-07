/// Day 380 — Ops Checkpoint (Section N close-out)
///
/// Section N (Days 371-380, Scale & Stabilize): the ops-checkpoint day for
/// this batch. Per the spec's own note, "380 is an ops checkpoint day in
/// this plan — not total project length" — this is NOT a section-end
/// milestone celebration the way Day 310/320/330/340/350/360/375 are; it
/// is a real, honest status roll-up of exactly the 9 screens built in this
/// worktree (Days 371-379), read back from each screen's own file header
/// rather than re-guessed.
///
/// **Headline finding, checked directly this session**: none of the 9
/// screens in Days 371-379 call a real backend endpoint. Grepped every
/// file for `dio`/`http.`/`Repository`/`ApiClient`/`.get(`/`.post(` —
/// zero hits across all 9. That is a real difference from Section M
/// (Day 366's live SOS dashboard and Day 372's cited data DO touch real
/// artifacts — Day 366 wires a real endpoint, Day 372 cites Day 257's
/// real load-test doc) — Section N's own batch (371-379) is entirely
/// FRONTEND-ONLY: real checklists, real logs, real exports, real planning
/// docs, all persisted locally via SharedPreferences where they persist
/// at all, none of them talking to a live server.
///
/// **The app has NOT actually launched.** Day 361's war room still
/// defaults to 5 open P0s (real, currently-open blockers from Day 336/344/
/// 347 audits) — unless someone has manually toggled items in that
/// screen's local checklist, "ready to launch" is FALSE right now. That
/// means every "rollout," "hotfix," and "scale" screen in this batch
/// (371, 372, 376, 379) is real tooling built AHEAD of an event that has
/// not happened yet — this checkpoint does not imply otherwise anywhere
/// below.
///
/// Tag: 🟢 FRONTEND-ONLY · real checkpoint summary of Days 371-379, no
/// backend calls anywhere in this batch, no real launch/rollout/hotfix/
/// scale event claimed.
///
/// Route: [AppRoutes.day380OpsCheckpoint] → `/day-380-ops-checkpoint`
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

enum _Kind { checklist, manualPaste, log, export, milestone, statusDoc, planningDoc, benchmarkDoc, expectationsDoc }

class _CheckRow {
  const _CheckRow({required this.day, required this.title, required this.kind, required this.note});
  final String day;
  final String title;
  final _Kind kind;
  final String note;
}

const _kOpsCheckpointRows = [
  _CheckRow(
    day: 'Day 371',
    title: 'Rollout 50% → 100% Checklist',
    kind: _Kind.checklist,
    note: 'Real 8-item go/no-go checklist, all default unchecked. No real rollout is in flight — '
        'Day 316\'s simulator is local-only and no real Play Console/App Store Connect call exists '
        'anywhere in the repo.',
  ),
  _CheckRow(
    day: 'Day 372',
    title: 'Performance at Scale Report',
    kind: _Kind.manualPaste,
    note: 'Real manual-paste fields for latency/error rate; DAU is a clearly-labeled EXAMPLE, never '
        'real. Cites Day 257\'s real production load test (~34 req/s sustained, P95 430ms @ 50 '
        'concurrent, 0% errors) as the one genuinely real data point in this batch.',
  ),
  _CheckRow(
    day: 'Day 373',
    title: 'False Positive Field Analysis',
    kind: _Kind.log,
    note: 'Real, genuinely empty categorization log (SharedPreferences-backed) — no real users exist '
        'yet to generate a real report. Links to Day 329\'s already-wired DCS sensitivity slider as '
        'the downstream consumer once real data exists.',
  ),
  _CheckRow(
    day: 'Day 374',
    title: 'Model Retrain Feedback Export',
    kind: _Kind.export,
    note: 'Real CSV/JSON export mechanism, genuinely empty — checked 40+ assets/models/DAY2*.md files '
        'directly, all Kaggle-side training records, none are on-device field misclassification logs '
        'to seed this with.',
  ),
  _CheckRow(
    day: 'Day 375',
    title: 'Section M Milestone',
    kind: _Kind.milestone,
    note: 'Real per-day verification record for Days 366-374, mirroring the Day 310/320/330/340/350/'
        '360 pattern. Correctly states no real launch exists and every "current state" is honest '
        'not-yet.',
  ),
  _CheckRow(
    day: 'Day 376',
    title: 'Month 10 Ops Milestone',
    kind: _Kind.statusDoc,
    note: 'Real ops-status screen. "Month 10" convention traced to zapsafeworking/'
        'ZAPSAFE_MASTER_TIMELINE.md\'s real usage (post-launch scale era) since day5\'s own Month-N '
        'numbering stopped incrementing at Month 11/Day 201 — documented honestly rather than '
        'inventing a new scheme.',
  ),
  _CheckRow(
    day: 'Day 377',
    title: 'v9.2 Feature Backlog Lock',
    kind: _Kind.planningDoc,
    note: 'Real planning document, not a claim anything is built. Wearables deferral and federated '
        'learning both reuse this project\'s own prior real decisions (Scope Pivots, ML training '
        'strategy); counselor chat is honestly labeled a NEW proposal with no prior mention found.',
  ),
  _CheckRow(
    day: 'Day 378',
    title: 'Competitor Benchmark Update',
    kind: _Kind.benchmarkDoc,
    note: 'Real feature matrix vs Life360/Noonlight/bSafe. Competitor specifics hedged "needs '
        'verification" where not confidently known; ZapSafe\'s own column is grepped from real shipped '
        'code, not aspirational.',
  ),
  _CheckRow(
    day: 'Day 379',
    title: '10K Users Readiness Gate',
    kind: _Kind.expectationsDoc,
    note: 'Real frontend-expectations document; infra verification explicitly stated as backend\'s '
        'job and NOT done here. Cites real Dio timeout budget (api_config.dart) and Day 257\'s real '
        'load-test ceiling verbatim.',
  ),
];

int get _totalOpsRows => _kOpsCheckpointRows.length;

class Day380OpsCheckpointScreen extends ConsumerWidget {
  const Day380OpsCheckpointScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(title: Text('day371_380.ops_checkpoint_title'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(ZapSpacing.xxl),
              decoration: BoxDecoration(
                color: ZapColors.info.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: ZapColors.info.withOpacity(0.3), width: 2),
              ),
              child: const Icon(Icons.fact_check_rounded, color: ZapColors.info, size: 56),
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          Center(
            child: Text('Section N · Ops Checkpoint',
                style: ZapTypography.displaySmall.copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center),
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Center(
            child: Text('Checkpoint, not a section-end milestone · Days 371-379',
                style: TextStyle(color: ZapColors.textSecondary, fontSize: 14)),
          ),
          const SizedBox(height: ZapSpacing.xl),
          ZapCard(
            backgroundColor: ZapColors.danger.withOpacity(0.08),
            borderColor: ZapColors.danger.withOpacity(0.3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.report_rounded, color: ZapColors.danger, size: 20),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    'The app has NOT actually launched. Day 361\'s war room defaults to 5 open P0s — '
                    '"ready to launch" is FALSE right now unless someone has manually resolved those '
                    'items. Every rollout/hotfix/scale screen below is real tooling built ahead of an '
                    'event that has not happened, not a record of one that has.',
                    style: ZapTypography.bodySmall.copyWith(color: ZapColors.textPrimary, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.lg),
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
                    'Headline finding: every one of the 9 screens below is FRONTEND-ONLY — grepped '
                    'each file for dio/http./Repository/ApiClient/.get(/.post(, zero hits across all '
                    '9. None of Days 371-379 talk to a live server, unlike Day 366\'s wired SOS '
                    'dashboard earlier in Section M.',
                    style: ZapTypography.bodySmall.copyWith(color: ZapColors.textPrimary, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          Row(
            children: [
              _StatTile(label: 'Screens checkpointed', value: '$_totalOpsRows/9', color: ZapColors.info),
              const SizedBox(width: ZapSpacing.sm),
              const _StatTile(label: 'Backend calls found', value: '0/9', color: ZapColors.textSecondary),
            ],
          ),
          const SizedBox(height: ZapSpacing.xl),
          Text('DAYS 371-379 CHECKPOINT', style: ZapTypography.labelLarge.copyWith(color: ZapColors.textSecondary, letterSpacing: 1.2)),
          const SizedBox(height: ZapSpacing.sm),
          for (final row in _kOpsCheckpointRows)
            ZapCard(
              margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_iconFor(row.kind), color: ZapColors.textSecondary, size: 18),
                      const SizedBox(width: ZapSpacing.sm),
                      Expanded(
                        child: Text('${row.day} · ${row.title}',
                            style: ZapTypography.bodyMedium.copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w600)),
                      ),
                      ZapBadge(label: _labelFor(row.kind), intent: ZapBadgeIntent.neutral, size: ZapBadgeSize.small),
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
                  '• The real launch itself — Day 361\'s war room still lists 5 open P0s by default; '
                  'nothing in this batch can move past "tooling ready" until that gate clears.\n'
                  '• A real staged rollout to advance past 50% (Day 371) — none exists to advance.\n'
                  '• Real DAU/traffic to replace Day 372\'s labeled example and to re-confirm Day 257\'s '
                  'production ceiling under real usage patterns (also flagged by Day 375/379).\n'
                  '• Real field reports to populate Day 373\'s FP log and Day 374\'s retrain export — '
                  'both start genuinely empty and stay that way until real users exist.\n'
                  '• Backend-side verification of Day 379\'s frontend expectations (general API rate '
                  'limiting beyond OTP_RATE_LIMIT was not found in settings.py — a real gap, not '
                  'invented) — explicitly out of scope for this frontend worktree.',
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
                    'This checkpoint closes out this worktree\'s scope (Days 371-380, branch '
                    'day371-380-scale-stabilize). It is an ops checkpoint per the spec\'s own note — '
                    'not a claim the project or Section N itself is finished.',
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
            label: 'Open Day 375 (Section M milestone)',
            fullWidth: true,
            onPressed: () => context.go(AppRoutes.sectionMMilestone),
          ),
          const SizedBox(height: ZapSpacing.sm),
          ZapButton.outlined(
            label: 'Open Day 371 (Section N start)',
            fullWidth: true,
            onPressed: () => context.go(AppRoutes.rollout100Checklist),
          ),
          const SizedBox(height: ZapSpacing.huge),
        ],
      ),
    );
  }
}

IconData _iconFor(_Kind k) => switch (k) {
      _Kind.checklist => Icons.checklist_rounded,
      _Kind.manualPaste => Icons.edit_note_rounded,
      _Kind.log => Icons.report_problem_rounded,
      _Kind.export => Icons.ios_share_rounded,
      _Kind.milestone => Icons.flag_circle_rounded,
      _Kind.statusDoc => Icons.dns_rounded,
      _Kind.planningDoc => Icons.playlist_add_check_rounded,
      _Kind.benchmarkDoc => Icons.compare_arrows_rounded,
      _Kind.expectationsDoc => Icons.groups_rounded,
    };

String _labelFor(_Kind k) => switch (k) {
      _Kind.checklist => 'CHECKLIST',
      _Kind.manualPaste => 'MANUAL-PASTE',
      _Kind.log => 'EMPTY LOG',
      _Kind.export => 'EXPORT TOOL',
      _Kind.milestone => 'MILESTONE',
      _Kind.statusDoc => 'STATUS DOC',
      _Kind.planningDoc => 'PLANNING DOC',
      _Kind.benchmarkDoc => 'BENCHMARK DOC',
      _Kind.expectationsDoc => 'EXPECTATIONS DOC',
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
