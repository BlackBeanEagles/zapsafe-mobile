/// Day 298 — Pre-Launch Go/No-Go Gate
///
/// Section E (Days 281-300): 22-item launch approval checklist extending the
/// Days 197-199 release block — all items must pass for GO decision.
///
/// Tag: 🟢 FRONTEND-ONLY · launch gate · no approval workflow backend.
///
/// Route: [AppRoutes.gonogoGate] → `/gonogo-gate`
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
const _kAccent = Color(0xFFDC2626);
const _kGoGreen = Color(0xFF059669);
const _kTabs = ['Checklist', 'Gate', 'Info'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');
const _kItemCount = 22;

enum _GateCategory { release, sectionE, ops, signoff }

enum _GateStatus { pass, warn, fail, unchecked }

class _GonogoItem {
  const _GonogoItem({
    required this.id,
    required this.number,
    required this.category,
    required this.title,
    required this.criterion,
    required this.dayRef,
    required this.defaultStatus,
    this.route,
  });

  final String id;
  final int number;
  final _GateCategory category;
  final String title;
  final String criterion;
  final String dayRef;
  final _GateStatus defaultStatus;
  final String? route;
}

const _kGonogoItems = [
  _GonogoItem(
    id: 'r197_checklist',
    number: 1,
    category: _GateCategory.release,
    title: 'Release checklist complete',
    criterion: 'Day 197 38-item checklist · all critical items checked.',
    dayRef: 'Day 197',
    defaultStatus: _GateStatus.pass,
    route: AppRoutes.releaseChecklist,
  ),
  _GonogoItem(
    id: 'r198_qa',
    number: 2,
    category: _GateCategory.release,
    title: 'Final QA pass signed',
    criterion: 'Day 198 10 critical flows · build signing · block sign-off.',
    dayRef: 'Day 198',
    defaultStatus: _GateStatus.pass,
    route: AppRoutes.qaPass,
  ),
  _GonogoItem(
    id: 'r199_submit',
    number: 3,
    category: _GateCategory.release,
    title: 'Store submission ready',
    criterion: 'Day 199 AAB + IPA uploaded · Play + App Store metadata live.',
    dayRef: 'Day 199',
    defaultStatus: _GateStatus.pass,
    route: AppRoutes.finalSubmission,
  ),
  _GonogoItem(
    id: 'e281_landing',
    number: 4,
    category: _GateCategory.sectionE,
    title: 'Landing page live',
    criterion: 'GH Pages mock · store CTAs · link audit pass.',
    dayRef: 'Day 281',
    defaultStatus: _GateStatus.pass,
    route: AppRoutes.landingPreview,
  ),
  _GonogoItem(
    id: 'e282_press',
    number: 5,
    category: _GateCategory.sectionE,
    title: 'Press kit assets packaged',
    criterion: 'Logos · screenshots · founder quote · ZIP mock ready.',
    dayRef: 'Day 282',
    defaultStatus: _GateStatus.pass,
    route: AppRoutes.pressKit,
  ),
  _GonogoItem(
    id: 'e283_demo',
    number: 6,
    category: _GateCategory.sectionE,
    title: 'Demo video storyboard approved',
    criterion: '6 scenes · 60s script · scene approve complete.',
    dayRef: 'Day 283',
    defaultStatus: _GateStatus.pass,
    route: AppRoutes.demoVideoStoryboard,
  ),
  _GonogoItem(
    id: 'e284_review',
    number: 7,
    category: _GateCategory.sectionE,
    title: 'Store review notes generated',
    criterion: 'Apple + Google notes · test account · SOS walkthrough.',
    dayRef: 'Day 284',
    defaultStatus: _GateStatus.pass,
    route: AppRoutes.storeReviewNotes,
  ),
  _GonogoItem(
    id: 'e285_security',
    number: 8,
    category: _GateCategory.sectionE,
    title: 'Security pre-launch audit',
    criterion: 'OWASP MASVS L2 · 12 items pass/warn acceptable.',
    dayRef: 'Day 285',
    defaultStatus: _GateStatus.pass,
    route: AppRoutes.securityPrelaunchAudit,
  ),
  _GonogoItem(
    id: 'e286_legal',
    number: 9,
    category: _GateCategory.sectionE,
    title: 'Legal blockers green',
    criterion: '14 GDPR endpoints · no red blockers on launch board.',
    dayRef: 'Day 286',
    defaultStatus: _GateStatus.warn,
    route: AppRoutes.legalBlockersTracker,
  ),
  _GonogoItem(
    id: 'e287_beta',
    number: 10,
    category: _GateCategory.sectionE,
    title: 'Beta feedback Round 3',
    criterion: 'NPS ≥ 40 · polish delta vs Round 2 positive.',
    dayRef: 'Day 287',
    defaultStatus: _GateStatus.pass,
    route: AppRoutes.betaFeedbackRound3,
  ),
  _GonogoItem(
    id: 'e288_crash',
    number: 11,
    category: _GateCategory.ops,
    title: 'Crash-free rate gate',
    criterion: '≥ 99.5% crash-free · Sentry mock green · P0 = 0.',
    dayRef: 'Day 288',
    defaultStatus: _GateStatus.pass,
    route: AppRoutes.crashFreeTracker,
  ),
  _GonogoItem(
    id: 'e289_regression',
    number: 12,
    category: _GateCategory.ops,
    title: 'Full app regression pass',
    criterion: '288 screens · pass/fail runner · zero P0 failures.',
    dayRef: 'Day 289',
    defaultStatus: _GateStatus.pass,
    route: AppRoutes.fullRegressionRunner,
  ),
  _GonogoItem(
    id: 'e290_rollout',
    number: 13,
    category: _GateCategory.ops,
    title: 'Staged rollout plan approved',
    criterion: 'Play 10→25→50→100% · halt criteria documented.',
    dayRef: 'Day 290',
    defaultStatus: _GateStatus.pass,
    route: AppRoutes.stagedRolloutSimulator,
  ),
  _GonogoItem(
    id: 'e291_global',
    number: 14,
    category: _GateCategory.ops,
    title: 'Global vs India compare signed',
    criterion: '14 dimensions reviewed · pricing · SMS · emergency numbers.',
    dayRef: 'Day 291',
    defaultStatus: _GateStatus.pass,
    route: AppRoutes.globalIndiaCompare,
  ),
  _GonogoItem(
    id: 'e292_warroom',
    number: 15,
    category: _GateCategory.ops,
    title: 'Post-launch war room ready',
    criterion: '72h checklist · crash · SOS · FP · support inbox gates.',
    dayRef: 'Day 292',
    defaultStatus: _GateStatus.pass,
    route: AppRoutes.postLaunchMonitoring,
  ),
  _GonogoItem(
    id: 'e293_hotfix',
    number: 16,
    category: _GateCategory.ops,
    title: 'Hotfix playbook documented',
    criterion: 'Days 122-123 pipeline · 8-step flowchart · runbook copy.',
    dayRef: 'Day 293',
    defaultStatus: _GateStatus.pass,
    route: AppRoutes.hotfixPlaybook,
  ),
  _GonogoItem(
    id: 'e294_support',
    number: 17,
    category: _GateCategory.ops,
    title: 'Support macros ready',
    criterion: '9 canned replies · FP · billing · deletion · < 4h SLA.',
    dayRef: 'Day 294',
    defaultStatus: _GateStatus.pass,
    route: AppRoutes.supportMacros,
  ),
  _GonogoItem(
    id: 'e295_roadmap',
    number: 18,
    category: _GateCategory.ops,
    title: 'Phase 2 roadmap published',
    criterion: 'Days 301-365 preview · v9.2 · wearables deferred.',
    dayRef: 'Day 295',
    defaultStatus: _GateStatus.pass,
    route: AppRoutes.phase2Roadmap,
  ),
  _GonogoItem(
    id: 'e296_parity',
    number: 19,
    category: _GateCategory.ops,
    title: 'Platform parity audit',
    criterion: 'Android vs iOS matrix · no unresolved P0 gaps.',
    dayRef: 'Day 296',
    defaultStatus: _GateStatus.pass,
    route: AppRoutes.platformParityAudit,
  ),
  _GonogoItem(
    id: 'e297_soak',
    number: 20,
    category: _GateCategory.ops,
    title: 'Battery soak log pass',
    criterion: '8hr MONITORING soak · drain ≤ 25% · no thermal throttle.',
    dayRef: 'Day 297',
    defaultStatus: _GateStatus.pass,
    route: AppRoutes.batterySoakLog,
  ),
  _GonogoItem(
    id: 'signoff_eng',
    number: 21,
    category: _GateCategory.signoff,
    title: 'Engineering lead sign-off',
    criterion: 'Mobile + backend leads approve GO on all technical gates.',
    dayRef: 'Launch team',
    defaultStatus: _GateStatus.unchecked,
  ),
  _GonogoItem(
    id: 'signoff_launch',
    number: 22,
    category: _GateCategory.signoff,
    title: 'Launch lead final GO',
    criterion: 'All 21 prior items pass · launch window confirmed.',
    dayRef: 'Launch lead',
    defaultStatus: _GateStatus.unchecked,
  ),
];

String _categoryKey(_GateCategory c) => switch (c) {
      _GateCategory.release => 'release',
      _GateCategory.sectionE => 'section_e',
      _GateCategory.ops => 'ops',
      _GateCategory.signoff => 'signoff',
    };

String _categoryLabel(_GateCategory c) => switch (c) {
      _GateCategory.release => 'Days 197-199',
      _GateCategory.sectionE => 'Section E',
      _GateCategory.ops => 'Ops & QA',
      _GateCategory.signoff => 'Sign-off',
    };

Color _categoryColor(_GateCategory c) => switch (c) {
      _GateCategory.release => const Color(0xFF3B82F6),
      _GateCategory.sectionE => const Color(0xFF8B5CF6),
      _GateCategory.ops => const Color(0xFF06B6D4),
      _GateCategory.signoff => _kGoGreen,
    };

_GateStatus _statusFromKey(String? key) => switch (key) {
      'pass' => _GateStatus.pass,
      'warn' => _GateStatus.warn,
      'fail' => _GateStatus.fail,
      _ => _GateStatus.unchecked,
    };

String _statusKey(_GateStatus s) => switch (s) {
      _GateStatus.pass => 'pass',
      _GateStatus.warn => 'warn',
      _GateStatus.fail => 'fail',
      _GateStatus.unchecked => 'unchecked',
    };

Color _statusColor(_GateStatus s) => switch (s) {
      _GateStatus.pass => ZapColors.safe,
      _GateStatus.warn => ZapColors.warning,
      _GateStatus.fail => ZapColors.danger,
      _GateStatus.unchecked => ZapColors.textMuted,
    };

IconData _statusIcon(_GateStatus s) => switch (s) {
      _GateStatus.pass => Icons.check_circle_rounded,
      _GateStatus.warn => Icons.warning_rounded,
      _GateStatus.fail => Icons.cancel_rounded,
      _GateStatus.unchecked => Icons.radio_button_unchecked_rounded,
    };

_GateStatus _cycleStatus(_GateStatus current) => switch (current) {
      _GateStatus.unchecked => _GateStatus.pass,
      _GateStatus.pass => _GateStatus.warn,
      _GateStatus.warn => _GateStatus.fail,
      _GateStatus.fail => _GateStatus.unchecked,
    };

bool _isGoReady(Map<String, String> statuses) {
  for (final item in _kGonogoItems) {
    final st = _statusFromKey(statuses[item.id]);
    if (st != _GateStatus.pass) return false;
  }
  return true;
}

Map<String, dynamic> _gonogoPayload(Map<String, String> statuses) {
  final pass = statuses.values.where((v) => v == 'pass').length;
  final fail = statuses.values.where((v) => v == 'fail').length;
  return {
    'endpoint': 'POST /api/v1/launch/gonogo-gate/',
    'items_total': _kItemCount,
    'items_pass': pass,
    'items_fail': fail,
    'decision': _isGoReady(statuses) ? 'GO' : 'NO_GO',
    'extends': 'Days 197-199 release block',
    'wire_note': 'All 22 items must pass for launch approval',
  };
}

String _buildGonogoReport(Map<String, String> statuses) {
  final buf = StringBuffer('ZapSafe Pre-Launch Go/No-Go Gate\n\n');
  for (final item in _kGonogoItems) {
    final st = _statusFromKey(statuses[item.id]);
    buf.writeln(
      '[${_statusKey(st).toUpperCase()}] ${item.number}. ${item.title} '
      '(${item.dayRef})',
    );
    buf.writeln('    ${item.criterion}');
  }
  buf.writeln();
  buf.writeln('DECISION: ${_isGoReady(statuses) ? 'GO ✅' : 'NO-GO ❌'}');
  return buf.toString();
}

// ── Providers ─────────────────────────────────────────────────────────────────
final _d298TabProvider = StateProvider<int>((ref) => 0);
final _d298CategoryFilterProvider = StateProvider<String>((ref) => 'all');
final _d298StatusesProvider = StateProvider<Map<String, String>>((ref) {
  return {
    for (final item in _kGonogoItems)
      item.id: _statusKey(item.defaultStatus),
  };
});
final _d298ApprovingProvider = StateProvider<bool>((ref) => false);

List<_GonogoItem> _filteredItems(String category) {
  if (category == 'all') return _kGonogoItems;
  return _kGonogoItems
      .where((i) => _categoryKey(i.category) == category)
      .toList();
}

// ── Screen ────────────────────────────────────────────────────────────────────
class Day298GonogoGateScreen extends ConsumerWidget {
  const Day298GonogoGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statuses = ref.watch(_d298StatusesProvider);
    final pass = statuses.values.where((v) => v == 'pass').length;
    final isGo = _isGoReady(statuses);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 298 · Go/No-Go Gate'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (isGo ? _kGoGreen : _kAccent).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: (isGo ? _kGoGreen : _kAccent).withOpacity(0.45),
                  ),
                ),
                child: Text(
                  isGo ? 'GO' : '$pass/$_kItemCount',
                  style: TextStyle(
                    color: isGo ? _kGoGreen : _kAccent,
                    fontSize: 10,
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
            tab: ref.watch(_d298TabProvider),
            onSelect: (i) => ref.read(_d298TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (ref.watch(_d298TabProvider)) {
              0 => const _ChecklistTab(),
              1 => const _GateTab(),
              _ => const _InfoTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Checklist ──────────────────────────────────────────────────────────
class _ChecklistTab extends ConsumerWidget {
  const _ChecklistTab();

  void _cycleItem(WidgetRef ref, String id) {
    final current = _statusFromKey(ref.read(_d298StatusesProvider)[id]);
    ref.read(_d298StatusesProvider.notifier).state = {
      ...ref.read(_d298StatusesProvider),
      id: _statusKey(_cycleStatus(current)),
    };
  }

  void _markAllPass(WidgetRef ref) {
    ref.read(_d298StatusesProvider.notifier).state = {
      for (final item in _kGonogoItems) item.id: 'pass',
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = ref.watch(_d298CategoryFilterProvider);
    final statuses = ref.watch(_d298StatusesProvider);
    final items = _filteredItems(category);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _SectionTitle(
          title: '22-item launch checklist',
          subtitle: 'Extends Days 197-199 · tap status chip to cycle',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _FilterChip(
              label: 'All',
              selected: category == 'all',
              onTap: () =>
                  ref.read(_d298CategoryFilterProvider.notifier).state = 'all',
            ),
            ..._GateCategory.values.map(
              (c) => _FilterChip(
                label: _categoryLabel(c),
                selected: category == _categoryKey(c),
                color: _categoryColor(c),
                onTap: () => ref
                    .read(_d298CategoryFilterProvider.notifier)
                    .state = _categoryKey(c),
              ),
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.md),
        ...items.map((item) {
          final st = _statusFromKey(statuses[item.id]);
          final catColor = _categoryColor(item.category);
          return Padding(
            padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
            child: InkWell(
              onTap: () => _cycleItem(ref, item.id),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(ZapSpacing.md),
                decoration: BoxDecoration(
                  color: ZapColors.bgCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _statusColor(st).withOpacity(0.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: catColor.withOpacity(0.15),
                      child: Text(
                        '${item.number}',
                        style: TextStyle(
                          color: catColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: ZapSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              color: ZapColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            item.criterion,
                            style: const TextStyle(
                              color: ZapColors.textMuted,
                              fontSize: 10,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.dayRef,
                            style: TextStyle(
                              color: catColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(_statusIcon(st), color: _statusColor(st), size: 20),
                  ],
                ),
              ),
            ),
          );
        }),
        OutlinedButton.icon(
          onPressed: () => _markAllPass(ref),
          icon: const Icon(Icons.done_all_rounded, size: 16),
          label: const Text('Mark all pass (mock)'),
        ),
      ],
    );
  }
}

// ── Tab 1: Gate ───────────────────────────────────────────────────────────────
class _GateTab extends ConsumerWidget {
  const _GateTab();

  Future<void> _approveGo(WidgetRef ref, BuildContext context) async {
    if (!_isGoReady(ref.read(_d298StatusesProvider))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot approve — not all 22 items pass.'),
        ),
      );
      return;
    }
    if (ref.read(_d298ApprovingProvider)) return;
    ref.read(_d298ApprovingProvider.notifier).state = true;
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    ref.read(_d298ApprovingProvider.notifier).state = false;
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Launch GO approved — mock sign-off recorded.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statuses = ref.watch(_d298StatusesProvider);
    final approving = ref.watch(_d298ApprovingProvider);
    final pass = statuses.values.where((v) => v == 'pass').length;
    final fail = statuses.values.where((v) => v == 'fail').length;
    final warn = statuses.values.where((v) => v == 'warn').length;
    final isGo = _isGoReady(statuses);
    final progress = pass / _kItemCount;

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _SectionTitle(
          title: 'Launch decision gate',
          subtitle: 'All 22 items must PASS · no warn/fail for GO',
        ),
        Center(
          child: SizedBox(
            width: 160,
            height: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 160,
                  height: 160,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 10,
                    backgroundColor: ZapColors.border,
                    color: isGo ? _kGoGreen : _kAccent,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isGo ? 'GO' : 'NO-GO',
                      style: TextStyle(
                        color: isGo ? _kGoGreen : _kAccent,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '$pass / $_kItemCount pass',
                      style: const TextStyle(
                        color: ZapColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Row(
          children: [
            Expanded(
              child: _StatChip(
                label: 'Pass',
                count: pass,
                color: ZapColors.safe,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatChip(
                label: 'Warn',
                count: warn,
                color: ZapColors.warning,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatChip(
                label: 'Fail',
                count: fail,
                color: ZapColors.danger,
              ),
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.lg),
        if (!isGo)
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            margin: const EdgeInsets.only(bottom: ZapSpacing.md),
            decoration: BoxDecoration(
              color: _kAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kAccent.withOpacity(0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Blocking items',
                  style: TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                ..._kGonogoItems.where((i) {
                  final st = _statusFromKey(statuses[i.id]);
                  return st != _GateStatus.pass;
                }).map(
                  (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• ${i.number}. ${i.title} — '
                      '${_statusKey(_statusFromKey(statuses[i.id])).toUpperCase()}',
                      style: const TextStyle(
                        color: ZapColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        FilledButton.icon(
          onPressed: (isGo && !approving) ? () => _approveGo(ref, context) : null,
          icon: approving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  isGo ? Icons.rocket_launch_rounded : Icons.block_rounded,
                  size: 18,
                ),
          label: Text(isGo ? 'Approve launch GO' : 'Gate blocked'),
          style: FilledButton.styleFrom(
            backgroundColor: isGo ? _kGoGreen : ZapColors.textMuted,
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(
              ClipboardData(text: _buildGonogoReport(statuses)),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Go/No-Go report copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy gate report'),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

// ── Tab 2: Info ───────────────────────────────────────────────────────────────
class _InfoTab extends ConsumerWidget {
  const _InfoTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payload = _gonogoPayload(ref.watch(_d298StatusesProvider));

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _SectionTitle(
          title: 'Pre-launch go/no-go gate',
          subtitle: 'Section E Day 18/20 · extends Days 197-199 release block.',
        ),
        const _PolicyRow(
          icon: Icons.checklist_rounded,
          title: 'Days 197-199 (items 1-3)',
          subtitle: 'Release checklist · QA pass · store submission baseline.',
        ),
        const _PolicyRow(
          icon: Icons.rocket_launch_rounded,
          title: 'Section E (items 4-20)',
          subtitle: 'Marketing · security · legal · ops gates from Days 281-297.',
        ),
        const _PolicyRow(
          icon: Icons.draw_rounded,
          title: 'Sign-off (items 21-22)',
          subtitle: 'Engineering + launch lead must approve when all pass.',
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
            borderRadius: BorderRadius.circular(8),
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
              const SnackBar(content: Text('Gate spec copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy spec JSON'),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.info.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.info.withOpacity(0.3)),
          ),
          child: const Text(
            'Next: Day 365 — Global Launch Milestone '
            '(Phase 2 finale · Day 365 target).',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              label: const Text('Day 197 Checklist'),
              onPressed: () => context.push(AppRoutes.releaseChecklist),
            ),
            ActionChip(
              label: const Text('Day 198 QA Pass'),
              onPressed: () => context.push(AppRoutes.qaPass),
            ),
            ActionChip(
              label: const Text('Day 199 Submission'),
              onPressed: () => context.push(AppRoutes.finalSubmission),
            ),
            ActionChip(
              label: const Text('Day 297 Soak Log'),
              onPressed: () => context.push(AppRoutes.batterySoakLog),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
              color: ZapColors.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
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
          Icon(icon, size: 18, color: _kAccent),
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color = _kAccent,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: color.withOpacity(0.2),
      checkmarkColor: color,
      labelStyle: TextStyle(
        color: selected ? color : ZapColors.textSecondary,
        fontSize: 11,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected ? _kAccent : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  _kTabs[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? _kAccent : ZapColors.textMuted,
                    fontWeight:
                        selected ? FontWeight.w800 : FontWeight.w500,
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
