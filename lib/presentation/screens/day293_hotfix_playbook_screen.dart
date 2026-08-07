/// Day 293 — Hotfix Playbook UI
///
/// Section E (Days 281-300): interactive flowchart documenting the hotfix
/// pipeline from Days 122-123 — detect → triage → fix → ship → verify.
///
/// Tag: 🟢 FRONTEND-ONLY · educational playbook · no CI integration.
///
/// Route: [AppRoutes.hotfixPlaybook] → `/hotfix-playbook`
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
const _kAccent = Color(0xFFEF4444);
const _kTabs = ['Flowchart', 'Runbook', 'Info'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');

enum _StepStatus { pending, active, done, skipped }

class _HotfixStep {
  const _HotfixStep({
    required this.id,
    required this.number,
    required this.title,
    required this.subtitle,
    required this.detail,
    required this.owner,
    required this.sla,
    required this.dayLink,
    required this.route,
    required this.icon,
    required this.color,
  });

  final String id;
  final int number;
  final String title;
  final String subtitle;
  final String detail;
  final String owner;
  final String sla;
  final String dayLink;
  final String? route;
  final IconData icon;
  final Color color;
}

const _kHotfixSteps = [
  _HotfixStep(
    id: 'detect',
    number: 1,
    title: 'Detect crash spike',
    subtitle: 'Sentry alert or war room gate',
    detail:
        'Crash-free drops below 99.5% or new P0 fingerprint appears in Sentry.',
    owner: 'On-call Eng',
    sla: '< 15 min',
    dayLink: 'Day 288 / 292',
    route: AppRoutes.crashFreeTracker,
    icon: Icons.sensors_rounded,
    color: Color(0xFFEF4444),
  ),
  _HotfixStep(
    id: 'triage',
    number: 2,
    title: 'Triage severity',
    subtitle: 'P0/P1 assign · repro device',
    detail:
        'Confirm affected OS versions, user %, and whether SOS path is impacted.',
    owner: 'Safety lead',
    sla: '< 30 min',
    dayLink: 'Day 292',
    route: AppRoutes.postLaunchMonitoring,
    icon: Icons.priority_high_rounded,
    color: Color(0xFFF59E0B),
  ),
  _HotfixStep(
    id: 'fix',
    number: 3,
    title: 'Apply code fix',
    subtitle: 'Root cause → patch → unit test',
    detail:
        'Day 122 pattern: stack trace, minimal diff, device-specific test matrix.',
    owner: 'Mobile Eng',
    sla: '< 4 h',
    dayLink: 'Day 122',
    route: AppRoutes.crashFixes,
    icon: Icons.code_rounded,
    color: Color(0xFF3B82F6),
  ),
  _HotfixStep(
    id: 'test',
    number: 4,
    title: 'QA spot-check',
    subtitle: 'Affected devices + SOS smoke',
    detail:
        'Run targeted checklist on repro devices before cutting release build.',
    owner: 'QA',
    sla: '< 2 h',
    dayLink: 'Day 201',
    route: AppRoutes.deviceQaHarness,
    icon: Icons.bug_report_rounded,
    color: Color(0xFF8B5CF6),
  ),
  _HotfixStep(
    id: 'build',
    number: 5,
    title: 'Build signed artefacts',
    subtitle: 'AAB + IPA · version bump',
    detail: 'Increment patch version · CI release lane · code-sign both stores.',
    owner: 'Release Eng',
    sla: '< 1 h',
    dayLink: 'Day 123',
    route: AppRoutes.hotfixRelease,
    icon: Icons.build_rounded,
    color: Color(0xFF06B6D4),
  ),
  _HotfixStep(
    id: 'ship',
    number: 6,
    title: 'Ship to testers',
    subtitle: 'TestFlight + Play internal track',
    detail:
        'Day 123: upload, notify beta cohort, pause staged rollout if needed.',
    owner: 'Release Eng',
    sla: '< 2 h',
    dayLink: 'Day 123',
    route: AppRoutes.hotfixRelease,
    icon: Icons.rocket_launch_rounded,
    color: Color(0xFF10B981),
  ),
  _HotfixStep(
    id: 'verify',
    number: 7,
    title: '24h verification',
    subtitle: 'Sentry fingerprint gone',
    detail:
        'Confirm P0 event count = 0 · crash rate back above gate · tester feedback.',
    owner: 'On-call Eng',
    sla: '24 h',
    dayLink: 'Day 123',
    route: AppRoutes.hotfixRelease,
    icon: Icons.verified_rounded,
    color: Color(0xFF22C55E),
  ),
  _HotfixStep(
    id: 'resume',
    number: 8,
    title: 'Resume rollout',
    subtitle: 'Advance Play % or full release',
    detail: 'Return to Day 290 staged rollout when war_room_clear = true.',
    owner: 'Launch lead',
    sla: 'After verify',
    dayLink: 'Day 290',
    route: AppRoutes.stagedRolloutSimulator,
    icon: Icons.trending_up_rounded,
    color: Color(0xFF34A853),
  ),
];

String _statusKey(_StepStatus s) => switch (s) {
      _StepStatus.pending => 'pending',
      _StepStatus.active => 'active',
      _StepStatus.done => 'done',
      _StepStatus.skipped => 'skipped',
    };

_StepStatus _statusFromKey(String? key) => switch (key) {
      'active' => _StepStatus.active,
      'done' => _StepStatus.done,
      'skipped' => _StepStatus.skipped,
      _ => _StepStatus.pending,
    };

Color _statusColor(_StepStatus s) => switch (s) {
      _StepStatus.pending => ZapColors.textMuted,
      _StepStatus.active => _kAccent,
      _StepStatus.done => ZapColors.safe,
      _StepStatus.skipped => ZapColors.warning,
    };

Map<String, dynamic> _playbookPayload(Map<String, String> statuses) {
  final done = statuses.values.where((v) => v == 'done').length;
  return {
    'endpoint': 'GET /api/v1/ops/hotfix-playbook/',
    'source_days': '122-123',
    'steps_total': _kHotfixSteps.length,
    'steps_done': done,
    'pipeline_complete': done == _kHotfixSteps.length,
    'steps': _kHotfixSteps
        .map(
          (s) => {
            'id': s.id,
            'title': s.title,
            'status': statuses[s.id] ?? 'pending',
            'owner': s.owner,
            'sla': s.sla,
          },
        )
        .toList(),
    'wire_note': 'Interactive flowchart · production hotfix SOP',
  };
}

String _buildPlaybookReport(Map<String, String> statuses) {
  final buf = StringBuffer('ZapSafe Hotfix Playbook Run\n\n');
  for (final step in _kHotfixSteps) {
    final st = _statusFromKey(statuses[step.id]);
    buf.writeln(
      '[${_statusKey(st).toUpperCase()}] ${step.number}. ${step.title} '
      '(${step.owner} · SLA ${step.sla})',
    );
    buf.writeln('    ${step.detail}');
  }
  final p = _playbookPayload(statuses);
  buf.writeln();
  buf.writeln('pipeline_complete=${p['pipeline_complete']}');
  return buf.toString();
}

// ── Providers ─────────────────────────────────────────────────────────────────
final _d293TabProvider = StateProvider<int>((ref) => 0);
final _d293StepIndexProvider = StateProvider<int>((ref) => 0);
final _d293StatusesProvider = StateProvider<Map<String, String>>((ref) {
  return {for (final s in _kHotfixSteps) s.id: 'pending'};
});
final _d293SimulatingProvider = StateProvider<bool>((ref) => false);

// ── Screen ────────────────────────────────────────────────────────────────────
class Day293HotfixPlaybookScreen extends ConsumerWidget {
  const Day293HotfixPlaybookScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = ref
        .watch(_d293StatusesProvider)
        .values
        .where((v) => v == 'done')
        .length;

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 293 · Hotfix Playbook'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _kAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _kAccent.withOpacity(0.45)),
                ),
                child: Text(
                  '$done/${_kHotfixSteps.length}',
                  style: const TextStyle(
                    color: _kAccent,
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
            tab: ref.watch(_d293TabProvider),
            onSelect: (i) => ref.read(_d293TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (ref.watch(_d293TabProvider)) {
              0 => const _FlowchartTab(),
              1 => const _RunbookTab(),
              _ => const _InfoTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Flowchart ──────────────────────────────────────────────────────────
class _FlowchartTab extends ConsumerWidget {
  const _FlowchartTab();

  void _markDone(WidgetRef ref, String id) {
    ref.read(_d293StatusesProvider.notifier).state = {
      ...ref.read(_d293StatusesProvider),
      id: 'done',
    };
  }

  Future<void> _simulatePipeline(WidgetRef ref, BuildContext context) async {
    if (ref.read(_d293SimulatingProvider)) return;
    ref.read(_d293SimulatingProvider.notifier).state = true;
    final statuses = <String, String>{
      for (final s in _kHotfixSteps) s.id: 'pending',
    };
    ref.read(_d293StatusesProvider.notifier).state = statuses;

    for (var i = 0; i < _kHotfixSteps.length; i++) {
      final step = _kHotfixSteps[i];
      ref.read(_d293StepIndexProvider.notifier).state = i;
      statuses[step.id] = 'active';
      ref.read(_d293StatusesProvider.notifier).state = {...statuses};
      await Future<void>.delayed(const Duration(milliseconds: 500));
      statuses[step.id] = 'done';
      ref.read(_d293StatusesProvider.notifier).state = {...statuses};
    }

    ref.read(_d293SimulatingProvider.notifier).state = false;
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hotfix pipeline simulation complete.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(_d293StepIndexProvider);
    final statuses = ref.watch(_d293StatusesProvider);
    final simulating = ref.watch(_d293SimulatingProvider);
    final step = _kHotfixSteps[selected];

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _SectionTitle(
          title: 'Hotfix pipeline flowchart',
          subtitle: 'Days 122-123 SOP · tap step · mark done · simulate run',
        ),
        ...List.generate(_kHotfixSteps.length, (i) {
          final s = _kHotfixSteps[i];
          final st = _statusFromKey(statuses[s.id]);
          final isSelected = i == selected;
          return Column(
            children: [
              InkWell(
                onTap: () =>
                    ref.read(_d293StepIndexProvider.notifier).state = i,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(ZapSpacing.md),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? s.color.withOpacity(0.12)
                        : ZapColors.bgCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? s.color
                          : _statusColor(st).withOpacity(0.35),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: _statusColor(st).withOpacity(0.2),
                        child: Text(
                          '${s.number}',
                          style: TextStyle(
                            color: _statusColor(st),
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: ZapSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.title,
                              style: const TextStyle(
                                color: ZapColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              s.subtitle,
                              style: const TextStyle(
                                color: ZapColors.textMuted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(s.icon, color: s.color, size: 20),
                    ],
                  ),
                ),
              ),
              if (i < _kHotfixSteps.length - 1)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Icon(
                    Icons.arrow_downward_rounded,
                    color: ZapColors.textMuted,
                    size: 16,
                  ),
                ),
            ],
          );
        }),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: step.color.withOpacity(0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Step ${step.number}: ${step.title}',
                style: TextStyle(
                  color: step.color,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                step.detail,
                style: const TextStyle(
                  color: ZapColors.textSecondary,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: ZapSpacing.sm),
              Text(
                '${step.owner} · SLA ${step.sla} · ${step.dayLink}',
                style: const TextStyle(
                  color: ZapColors.textMuted,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: ZapSpacing.sm),
              Row(
                children: [
                  if (step.route != null)
                    ActionChip(
                      label: Text('Open ${step.dayLink}'),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => context.push(step.route!),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _markDone(ref, step.id),
                    child: const Text('Mark done', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        FilledButton.icon(
          onPressed: simulating ? null : () => _simulatePipeline(ref, context),
          icon: simulating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.play_arrow_rounded, size: 18),
          label: const Text('Simulate full pipeline'),
          style: FilledButton.styleFrom(backgroundColor: _kAccent),
        ),
      ],
    );
  }
}

// ── Tab 1: Runbook ────────────────────────────────────────────────────────────
class _RunbookTab extends ConsumerWidget {
  const _RunbookTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statuses = ref.watch(_d293StatusesProvider);
    final done = statuses.values.where((v) => v == 'done').length;

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _SectionTitle(
          title: 'Hotfix runbook',
          subtitle: 'Copy for incident channel · SLA per step',
        ),
        if (done == _kHotfixSteps.length)
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            margin: const EdgeInsets.only(bottom: ZapSpacing.lg),
            decoration: BoxDecoration(
              color: ZapColors.safe.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ZapColors.safe.withOpacity(0.4)),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: ZapColors.safe),
                SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    'All 8 steps complete — hotfix pipeline green ✅',
                    style: TextStyle(
                      color: ZapColors.safe,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ..._kHotfixSteps.map((step) {
          final st = _statusFromKey(statuses[step.id]);
          return Container(
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _statusColor(st).withOpacity(0.35)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_statusIcon(st), color: _statusColor(st), size: 20),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${step.number}. ${step.title}',
                        style: const TextStyle(
                          color: ZapColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '${step.owner} · SLA ${step.sla}',
                        style: const TextStyle(
                          color: ZapColors.textMuted,
                          fontSize: 10,
                        ),
                      ),
                      Text(
                        step.detail,
                        style: const TextStyle(
                          color: ZapColors.textSecondary,
                          fontSize: 10,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
        FilledButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: _buildPlaybookReport(statuses)));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Hotfix runbook copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text('Copy runbook'),
          style: FilledButton.styleFrom(backgroundColor: _kAccent),
        ),
        const SizedBox(height: ZapSpacing.sm),
        OutlinedButton.icon(
          onPressed: () {
            ref.read(_d293StatusesProvider.notifier).state = {
              for (final s in _kHotfixSteps) s.id: 'pending',
            };
            ref.read(_d293StepIndexProvider.notifier).state = 0;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Playbook reset.')),
            );
          },
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Reset playbook'),
        ),
      ],
    );
  }
}

IconData _statusIcon(_StepStatus s) => switch (s) {
      _StepStatus.pending => Icons.radio_button_unchecked_rounded,
      _StepStatus.active => Icons.play_circle_rounded,
      _StepStatus.done => Icons.check_circle_rounded,
      _StepStatus.skipped => Icons.skip_next_rounded,
    };

// ── Tab 2: Info ───────────────────────────────────────────────────────────────
class _InfoTab extends ConsumerWidget {
  const _InfoTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payload = _playbookPayload(ref.watch(_d293StatusesProvider));

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _SectionTitle(
          title: 'Hotfix playbook',
          subtitle: 'Documents Days 122-123 pipeline as interactive flowchart.',
        ),
        const _PolicyRow(
          icon: Icons.bug_report_rounded,
          title: 'Day 122 — Fix crashes',
          subtitle: 'Triage top crashes · root cause · code diff · test matrix.',
        ),
        const _PolicyRow(
          icon: Icons.rocket_launch_rounded,
          title: 'Day 123 — Ship hotfix',
          subtitle: 'Build · TestFlight/Play upload · notify · 24h verify.',
        ),
        const _PolicyRow(
          icon: Icons.monitor_heart_rounded,
          title: 'Post-launch tie-in',
          subtitle: 'War room (Day 292) triggers playbook · rollout resumes Day 290.',
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
              const SnackBar(content: Text('Playbook spec copied.')),
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
            '(Phase 2 finale · worldwide rollout).',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              label: const Text('Day 122 Crash Fixes'),
              onPressed: () => context.push(AppRoutes.crashFixes),
            ),
            ActionChip(
              label: const Text('Day 123 Hotfix Ship'),
              onPressed: () => context.push(AppRoutes.hotfixRelease),
            ),
            ActionChip(
              label: const Text('Day 292 War Room'),
              onPressed: () => context.push(AppRoutes.postLaunchMonitoring),
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
