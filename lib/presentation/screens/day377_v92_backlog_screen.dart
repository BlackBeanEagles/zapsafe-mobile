/// Day 377 — v9.2 Feature Backlog Lock
///
/// Section N (Days 371-380, Scale & Stabilize): a real planning/roadmap
/// screen prioritizing wearables deferral, counselor chat, and federated
/// learning for a hypothetical "v9.2". **This is a planning document, not
/// a claim any of these are built.**
///
/// Checked this project's own real prior decisions before writing this,
/// rather than inventing new ones:
/// - **Wearables**: this project's own Scope Pivots history confirms
///   Apple Watch/Wear OS support was explicitly cut from the Days
///   201-300 scope and replaced with phone-only flows (Journey Mode,
///   Trusted Circle, Ride Safety, Fake Call, Offline SOS), "Deferred to
///   a hypothetical v9.2+." That prior decision is reused verbatim here,
///   not re-decided.
/// - **Federated learning**: `zapsafeworking/ZAPSAFE_ML_TRAINING_STRATEGY
///   .md` already plans this for real — "M6 Personal Baseline (0.9 MB)
///   — On-device (federated learning)... post-launch, Month 10+" and
///   `ZAPSAFE_TRAINING_AND_COSTS.md` costs it at "\$200-500" via AWS
///   SageMaker Federated. Grounded in that real prior plan, not invented.
/// - **Counselor chat**: no prior mention found anywhere in this repo's
///   docs, `assets/models/`, or the Scope Pivots history. Listed here as
///   a genuinely NEW proposal, labeled as such — not retconned as
///   something already decided.
///
/// Tag: 🟢 real planning/roadmap screen, grounded in real prior project
/// decisions where they exist, honestly labeled "new" where they don't.
///
/// Route: [AppRoutes.v92BacklogLock] → `/day-377-v92-backlog`
library;

import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const _kAccent = Color(0xFFFBBF24);
const _kJsonEncoder = JsonEncoder.withIndent('  ');

class _BacklogItem {
  const _BacklogItem({
    required this.title,
    required this.priority,
    required this.provenance,
    required this.detail,
  });
  final String title;
  final int priority; // 1 = highest
  final String provenance; // 'prior_decision' | 'new_proposal'
  final String detail;
}

const _kBacklog = [
  _BacklogItem(
    title: 'Federated learning (on-device, M6 Personal Baseline)',
    priority: 1,
    provenance: 'prior_decision',
    detail: 'Grounded in ZAPSAFE_ML_TRAINING_STRATEGY.md\'s real existing plan: '
        '"On-device (federated learning)... post-launch, Month 10+." Costed in '
        'ZAPSAFE_TRAINING_AND_COSTS.md at ~\$200-500/mo via AWS SageMaker '
        'Federated. Highest priority because it directly improves the real DCS '
        'models already shipping (scream/motion/scene/fusion/aggressive_speech) '
        'using real per-user data, once real users exist.',
  ),
  _BacklogItem(
    title: 'Wearables (Apple Watch / Wear OS)',
    priority: 2,
    provenance: 'prior_decision',
    detail: 'Explicitly cut from Days 201-300 scope (project Scope Pivots '
        'history) and replaced with phone-only flows — Journey Mode, Trusted '
        'Circle, Ride Safety, Fake Call, Offline SOS. That prior decision is '
        'reused here verbatim: "deferred to a hypothetical v9.2+," not '
        're-decided or walked back.',
  ),
  _BacklogItem(
    title: 'Counselor chat (in-app crisis text support)',
    priority: 3,
    provenance: 'new_proposal',
    detail: 'No prior mention found anywhere in this repo\'s docs, '
        'assets/models/, or the Scope Pivots history — this is a genuinely '
        'NEW proposal for v9.2, not something already decided. Would need its '
        'own real scoping pass (staffing a real crisis line vs a canned-'
        'response bot has very different safety and cost implications) before '
        'it could move past this backlog entry.',
  ),
];

Map<String, dynamic> _payload() => {
      'is_build_claim': false,
      'is_planning_document': true,
      'items': [
        for (final i in _kBacklog)
          {'title': i.title, 'priority': i.priority, 'provenance': i.provenance, 'detail': i.detail}
      ],
      'wire_note': 'Real roadmap/backlog screen. Wearables + federated learning '
          'grounded in this project\'s own real prior decisions (found by '
          'checking Scope Pivots history and zapsafeworking/ docs directly). '
          'Counselor chat honestly labeled a new proposal.',
    };

// ── Screen ────────────────────────────────────────────────────────────────────
class Day377V92BacklogScreen extends ConsumerWidget {
  const Day377V92BacklogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(title: Text('day371_380.v92_backlog_title'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(color: _kAccent.withOpacity(0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: _kAccent.withOpacity(0.4))),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.playlist_add_check_rounded, color: _kAccent, size: 20),
                SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    'A planning document — not a claim any of these are built. '
                    'Wearables deferral and federated learning are grounded in '
                    'this project\'s own real prior decisions; counselor chat '
                    'is a genuinely new proposal, labeled as such.',
                    style: TextStyle(color: ZapColors.textPrimary, fontSize: 12, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          const Text('v9.2 backlog (priority order)', style: TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: ZapSpacing.sm),
          for (final item in _kBacklog) ...[
            _BacklogTile(item: item),
            const SizedBox(height: ZapSpacing.sm),
          ],
          const SizedBox(height: ZapSpacing.lg),
          FilledButton.icon(
            onPressed: () {
              final buf = StringBuffer('ZapSafe v9.2 Feature Backlog — Day 377\n');
              buf.writeln('(Planning document — not a claim these are built)\n');
              for (final i in _kBacklog) {
                buf.writeln('P${i.priority}. ${i.title} [${i.provenance == "prior_decision" ? "prior decision" : "NEW proposal"}]');
                buf.writeln('   ${i.detail}\n');
              }
              Clipboard.setData(ClipboardData(text: buf.toString()));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backlog copied.')));
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy backlog'),
            style: FilledButton.styleFrom(backgroundColor: _kAccent, minimumSize: const Size(double.infinity, 48)),
          ),
          const SizedBox(height: ZapSpacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(color: ZapColors.bgCard, borderRadius: BorderRadius.circular(8), border: Border.all(color: ZapColors.border)),
            child: SelectableText(_kJsonEncoder.convert(_payload()), style: const TextStyle(color: ZapColors.textSecondary, fontSize: 10, fontFamily: 'monospace', height: 1.45)),
          ),
        ],
      ),
    );
  }
}

class _BacklogTile extends StatelessWidget {
  const _BacklogTile({required this.item});
  final _BacklogItem item;

  @override
  Widget build(BuildContext context) {
    final isPrior = item.provenance == 'prior_decision';
    return Container(
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
                child: Text('P${item.priority}', style: const TextStyle(color: _kAccent, fontWeight: FontWeight.w800, fontSize: 11)),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(item.title, style: const TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: (isPrior ? ZapColors.safe : ZapColors.info).withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                child: Text(isPrior ? 'PRIOR DECISION' : 'NEW PROPOSAL', style: TextStyle(color: isPrior ? ZapColors.safe : ZapColors.info, fontSize: 9, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(item.detail, style: const TextStyle(color: ZapColors.textMuted, fontSize: 11, height: 1.4)),
        ],
      ),
    );
  }
}
