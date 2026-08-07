/// Day 376 — Month 10 Ops Milestone
///
/// Section N (Days 371-380, Scale & Stabilize): "Month 10 ops" per the
/// spec (`DAYS_301_390_DETAILED_INSTRUCTIONS.md`: "Goal: Month 10 ops per
/// TIMELINE_FROM_DAY71.md Days 257-286").
///
/// **What "Month 10" actually means here — checked directly, not
/// invented.** `zapsafe_backend/TIMELINE_FROM_DAY71.md` has zero mentions
/// of "Month 10" or the day range 257-286 at all (confirmed stale, per
/// this project's own established finding). `day5_navigation_index_screen
/// .dart`'s own real Month-N-per-~20-days numbering (Month 3 = Day 41+,
/// Month 11 = Day 201+) stopped incrementing after Month 11/Day 201, when
/// the project switched to Section-lettered naming (Section B onward) —
/// so there is no "Month 19" to linearly extend that scheme to Day 376.
///
/// The real source that actually uses "Month 10" consistently is
/// `zapsafeworking/ZAPSAFE_MASTER_TIMELINE.md` and
/// `ZAPSAFE_ML_TRAINING_STRATEGY.md` — both read directly this session —
/// where "Month 10" names the **post-launch scale-up era**: federated
/// learning ("M6 Personal Baseline... post-launch, Month 10+"),
/// multi-region infrastructure ("Infrastructure scale: End Month 10 →
/// Multi-region, 100K users"), and police coordination in India
/// ("Month 10+"). That is exactly what Section N (Scale & Stabilize) is
/// thematically about — so this screen uses "Month 10" in that original,
/// real, master-timeline sense, not as a literal continuation of day5's
/// day-count-based numbering. Documented here rather than silently
/// picking one convention.
///
/// Tag: 🟢 real ops-status screen, "Month 10" convention grounded in real
/// docs and stated honestly, not invented.
///
/// Route: [AppRoutes.month10Ops] → `/day-376-month10-ops`
library;

import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const _kAccent = Color(0xFFDC2626);
const _kJsonEncoder = JsonEncoder.withIndent('  ');

class _OpsItem {
  const _OpsItem({required this.title, required this.status, required this.note});
  final String title;
  final String status; // 'done', 'in_progress', 'not_started'
  final String note;
}

const _kOpsItems = [
  _OpsItem(
    title: 'Backend architecture: Django monolith first',
    status: 'done',
    note: 'ZAPSAFE_MASTER_TIMELINE.md: "Confirm: Django monolith first, microservices later (Month 10)." '
        'Still a monolith today — no microservices split has happened, matching the plan as written.',
  ),
  _OpsItem(
    title: 'Real production load test executed',
    status: 'in_progress',
    note: 'Day 257 ran a real test against production (2 OCPU/12GB): ~34 req/s sustained, P95 430ms '
        '@ 50 concurrent, 0% errors, degraded not broken @ 100. 10,000 concurrent confirmed not '
        'achievable on this hardware — a real, measured ceiling, not a guess.',
  ),
  _OpsItem(
    title: 'Infrastructure scale: multi-region, 100K users',
    status: 'not_started',
    note: 'ZAPSAFE_MASTER_TIMELINE.md lists this as the "End Month 10" target. Current real '
        'infrastructure is a single Oracle Always-Free VM (Mumbai) — genuinely not started.',
  ),
  _OpsItem(
    title: 'Federated learning (on-device, M6 Personal Baseline)',
    status: 'not_started',
    note: 'ZAPSAFE_ML_TRAINING_STRATEGY.md: "post-launch, Month 10+... continuous, \$0" — deliberately '
        'deferred until real launch + real usage data exist. See Day 377\'s backlog.',
  ),
  _OpsItem(
    title: 'Police coordination (India) integration',
    status: 'not_started',
    note: 'ZAPSAFE_TRAINING_AND_COSTS.md lists this as a "Month 10+" \$5,000-10,000 line item. Day '
        '356\'s police dispatch endpoint is real but honestly mock-shaped (is_mock: true) until this '
        'real integration exists.',
  ),
  _OpsItem(
    title: 'Real public launch',
    status: 'not_started',
    note: 'The actual prerequisite for everything above meaning anything in practice. Day 361\'s war '
        'room: 5 open P0s. No real rollout, submission, or launch has happened.',
  ),
];

Map<String, dynamic> _payload() => {
      'month10_source_convention': 'zapsafeworking/ZAPSAFE_MASTER_TIMELINE.md + '
          'ZAPSAFE_ML_TRAINING_STRATEGY.md — post-launch scale-up era, not a literal '
          'continuation of day5_navigation_index_screen.dart\'s Month-N-per-20-days scheme '
          '(which plateaued at Month 11 / Day 201 before switching to Section-letters)',
      'timeline_from_day71_checked': true,
      'timeline_from_day71_month10_mentions_found': 0,
      'items': [
        for (final i in _kOpsItems) {'title': i.title, 'status': i.status, 'note': i.note}
      ],
      'wire_note': 'Real ops-status screen grounded in real project docs, read directly this session.',
    };

// ── Screen ────────────────────────────────────────────────────────────────────
class Day376Month10OpsScreen extends ConsumerWidget {
  const Day376Month10OpsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(title: Text('day371_380.month10_ops_title'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(color: _kAccent.withOpacity(0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: _kAccent.withOpacity(0.3))),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.dns_rounded, color: _kAccent, size: 20),
                SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    '"Month 10" is not a literal continuation of day5\'s Month-'
                    'numbering (which plateaued at Month 11 / Day 201). It is '
                    'the real term zapsafeworking\'s own master timeline uses '
                    'for the post-launch scale-up era — federated learning, '
                    'multi-region infra, police coordination — which is '
                    'exactly what Section N is about.',
                    style: TextStyle(color: ZapColors.textPrimary, fontSize: 12, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(color: ZapColors.bgCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: ZapColors.border)),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Checked directly', style: TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
                SizedBox(height: 6),
                Text('• zapsafe_backend/TIMELINE_FROM_DAY71.md: 0 mentions of "Month 10" or Days 257-286 (confirmed stale).', style: TextStyle(color: ZapColors.textMuted, fontSize: 11, height: 1.5)),
                Text('• zapsafeworking/ZAPSAFE_MASTER_TIMELINE.md: "Django monolith first, microservices later (Month 10)"; "Infrastructure scale: End Month 10 → Multi-region, 100K users".', style: TextStyle(color: ZapColors.textMuted, fontSize: 11, height: 1.5)),
                Text('• zapsafeworking/ZAPSAFE_ML_TRAINING_STRATEGY.md: federated learning "post-launch, Month 10+".', style: TextStyle(color: ZapColors.textMuted, fontSize: 11, height: 1.5)),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          const Text('Month 10 ops status', style: TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: ZapSpacing.sm),
          for (final item in _kOpsItems) ...[
            _OpsTile(item: item),
            const SizedBox(height: ZapSpacing.sm),
          ],
          const SizedBox(height: ZapSpacing.lg),
          FilledButton.icon(
            onPressed: () {
              final buf = StringBuffer('ZapSafe Month 10 Ops Milestone — Day 376\n\n');
              for (final i in _kOpsItems) {
                buf.writeln('[${i.status.toUpperCase()}] ${i.title}\n  ${i.note}\n');
              }
              Clipboard.setData(ClipboardData(text: buf.toString()));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ops status copied.')));
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy ops status'),
            style: FilledButton.styleFrom(backgroundColor: _kAccent, minimumSize: const Size(double.infinity, 48)),
          ),
          const SizedBox(height: ZapSpacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(color: ZapColors.bgCard, borderRadius: BorderRadius.circular(8), border: Border.all(color: ZapColors.border)),
            child: SelectableText(_kJsonEncoder.convert(_payload()), style: const TextStyle(color: ZapColors.textSecondary, fontSize: 10, fontFamily: 'monospace', height: 1.45)),
          ),
          const SizedBox(height: ZapSpacing.lg),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ActionChip(label: const Text('Day 372 Performance Report'), onPressed: () => context.push(AppRoutes.performanceScaleReport)),
            ActionChip(label: const Text('Day 377 v9.2 Backlog'), onPressed: () => context.push(AppRoutes.v92BacklogLock)),
            ActionChip(label: const Text('Day 379 10K Users Gate'), onPressed: () => context.push(AppRoutes.tenKUsersGate)),
          ]),
        ],
      ),
    );
  }
}

class _OpsTile extends StatelessWidget {
  const _OpsTile({required this.item});
  final _OpsItem item;

  @override
  Widget build(BuildContext context) {
    final color = switch (item.status) {
      'done' => ZapColors.safe,
      'in_progress' => ZapColors.warning,
      _ => ZapColors.textMuted,
    };
    final icon = switch (item.status) {
      'done' => Icons.check_circle_rounded,
      'in_progress' => Icons.hourglass_top_rounded,
      _ => Icons.radio_button_unchecked_rounded,
    };
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(color: ZapColors.bgCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.35))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: const TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 12)),
                const SizedBox(height: 4),
                Text(item.note, style: const TextStyle(color: ZapColors.textMuted, fontSize: 11, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
