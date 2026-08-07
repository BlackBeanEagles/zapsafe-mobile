/// Day 364 — Launch Day Runbook
///
/// Section L (Days 361-365, Public Launch Week): a minute-by-minute launch
/// day schedule from T-24h to T+24h. **This is a planning document — a
/// runbook for a launch day that has not happened yet**, not a record of a
/// real event. No timestamps below are real clock times; they are relative
/// offsets from a hypothetical T-0 "app goes live" moment.
///
/// Roles referenced are the project's own real roles (founder, intern —
/// see `frontend_intern_handoff.md`), and the SOS monitoring escalation
/// path routes through Day 294's real support macros
/// (`day294_support_macros_screen.dart`) rather than inventing new copy.
///
/// Tag: 🟢 FRONTEND-ONLY · planning document · filterable by role/phase.
///
/// Route: [AppRoutes.launchDayRunbook] → `/day-364-launch-day-runbook`
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
const _kAccent = Color(0xFFF97316);
const _kJsonEncoder = JsonEncoder.withIndent('  ');

enum _Phase { preLaunch, launch, postLaunch }
enum _Role { founder, intern, support, oncall }

String _phaseLabel(_Phase p) => switch (p) {
      _Phase.preLaunch => 'Pre-launch',
      _Phase.launch => 'Launch',
      _Phase.postLaunch => 'Post-launch',
    };

Color _phaseColor(_Phase p) => switch (p) {
      _Phase.preLaunch => const Color(0xFF3B82F6),
      _Phase.launch => ZapColors.danger,
      _Phase.postLaunch => ZapColors.safe,
    };

String _roleLabel(_Role r) => switch (r) {
      _Role.founder => 'Founder',
      _Role.intern => 'Intern',
      _Role.support => 'Support',
      _Role.oncall => 'On-call Eng',
    };

class _RunbookItem {
  const _RunbookItem({
    required this.offset,
    required this.phase,
    required this.role,
    required this.action,
    required this.detail,
  });

  final String offset;
  final _Phase phase;
  final _Role role;
  final String action;
  final String detail;
}

const _kItems = [
  _RunbookItem(
    offset: 'T-24h',
    phase: _Phase.preLaunch,
    role: _Role.founder,
    action: 'Final Day 361 war room check',
    detail: 'Confirm zero P0 open in Day 361\'s checklist. If any P0 is '
        'still open, T-0 does not happen — reschedule, do not launch anyway.',
  ),
  _RunbookItem(
    offset: 'T-12h',
    phase: _Phase.preLaunch,
    role: _Role.oncall,
    action: 'Freeze main branch',
    detail: 'No new merges except emergency fixes for launch-blocking issues.',
  ),
  _RunbookItem(
    offset: 'T-2h',
    phase: _Phase.preLaunch,
    role: _Role.founder,
    action: 'Verify store listings are approved',
    detail: 'Confirm Day 362/363 submissions actually show "Approved" — '
        'not just "Submitted" — in both consoles.',
  ),
  _RunbookItem(
    offset: 'T-1h',
    phase: _Phase.preLaunch,
    role: _Role.support,
    action: 'Support macros on standby',
    detail: 'Day 294 macro library open and ready — false-positive SOS, '
        'billing, and deletion replies pre-staged.',
  ),
  _RunbookItem(
    offset: 'T-30m',
    phase: _Phase.preLaunch,
    role: _Role.oncall,
    action: 'Confirm monitoring is live',
    detail: 'Day 338 Sentry wiring, Day 366 SOS dashboard, and Day 367 '
        'reviews monitor all open in separate tabs/devices.',
  ),
  _RunbookItem(
    offset: 'T-0',
    phase: _Phase.launch,
    role: _Role.founder,
    action: 'Flip staged rollout live (5%)',
    detail: 'Day 316\'s staged rollout begins at 5% per its real manual '
        'Play Console steps — not 100% on day one.',
  ),
  _RunbookItem(
    offset: 'T+15m',
    phase: _Phase.launch,
    role: _Role.oncall,
    action: 'Watch crash-free % and first install telemetry',
    detail: 'Any crash-free drop below Day 288\'s 99.5% gate triggers Day '
        '293\'s hotfix playbook immediately.',
  ),
  _RunbookItem(
    offset: 'T+1h',
    phase: _Phase.launch,
    role: _Role.support,
    action: 'First support ticket triage pass',
    detail: 'Day 369\'s kanban board — new tickets get bucketed and '
        'matched to a Day 294 macro if applicable.',
  ),
  _RunbookItem(
    offset: 'T+4h',
    phase: _Phase.postLaunch,
    role: _Role.founder,
    action: 'Go/no-go on advancing rollout %',
    detail: 'Only advance past 5% if crash-free and SOS delivery success '
        '(Day 366) both look healthy — real data, not assumed.',
  ),
  _RunbookItem(
    offset: 'T+12h',
    phase: _Phase.postLaunch,
    role: _Role.intern,
    action: 'First ratings/reviews sweep',
    detail: 'Day 367 manual-paste monitor — log anything that appears on '
        'the real store listings once they are actually live.',
  ),
  _RunbookItem(
    offset: 'T+24h',
    phase: _Phase.postLaunch,
    role: _Role.founder,
    action: 'Day 1 retrospective prep',
    detail: 'Start collecting notes for Day 370\'s Week 1 retrospective '
        'template — what went well, what broke, real user quotes.',
  ),
];

// SOS monitoring escalation — safety-critical, kept separate from the
// generic timeline above.
class _EscalationStep {
  const _EscalationStep(this.trigger, this.action, this.owner);
  final String trigger;
  final String action;
  final String owner;
}

const _kEscalation = [
  _EscalationStep('SOS delivery success % drops below 95% (Day 366)', 'Page on-call eng immediately — this is safety-critical, not a normal bug.', 'On-call Eng'),
  _EscalationStep('A single SOS session shows failed contact delivery', 'Manually verify via backend logs; do not wait for aggregate stats to move.', 'On-call Eng'),
  _EscalationStep('User reports SOS did not alert anyone (support ticket)', 'Escalate above Day 294\'s normal false-positive macro — treat as a possible real safety failure until proven otherwise.', 'Founder + On-call Eng'),
  _EscalationStep('Crash-free % drops below 99.5% gate (Day 288)', 'Trigger Day 293\'s hotfix playbook; consider halting staged rollout via Day 316.', 'On-call Eng'),
];

Map<String, dynamic> _runbookPayload() => {
      'is_real_launch_record': false,
      'items_total': _kItems.length,
      'escalation_steps': _kEscalation.length,
      'wire_note': 'Planning document only — T-0 has not occurred',
    };

String _buildExportReport() {
  final buf = StringBuffer('ZapSafe Launch Day Runbook — Day 364 (PLANNING DOCUMENT)\n\n');
  for (final i in _kItems) {
    buf.writeln('${i.offset} [${_phaseLabel(i.phase)} · ${_roleLabel(i.role)}] ${i.action}');
    buf.writeln('    ${i.detail}');
  }
  buf.writeln('\n── SOS monitoring escalation ──');
  for (final e in _kEscalation) {
    buf.writeln('IF: ${e.trigger}');
    buf.writeln('THEN: ${e.action} (${e.owner})');
  }
  return buf.toString();
}

// ── Providers ─────────────────────────────────────────────────────────────────
final _d364FilterProvider = StateProvider<_Phase?>((ref) => null);

// ── Screen ────────────────────────────────────────────────────────────────────
class Day364LaunchDayRunbookScreen extends ConsumerWidget {
  const Day364LaunchDayRunbookScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(_d364FilterProvider);
    final items = filter == null ? _kItems : _kItems.where((i) => i.phase == filter).toList();

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(title: Text('day361_370.launch_runbook_title'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: _kAccent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kAccent.withOpacity(0.3)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.event_note_rounded, color: _kAccent, size: 20),
                SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    'This is a PLANNING DOCUMENT for a launch day that has not '
                    'happened. Every offset (T-24h … T+24h) is relative to a '
                    'hypothetical future T-0, not a real timestamp.',
                    style: TextStyle(color: ZapColors.textPrimary, fontSize: 12, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.lg),
          Wrap(
            spacing: 8,
            children: [
              _PhaseChip(label: 'All', selected: filter == null, color: ZapColors.textMuted, onTap: () => ref.read(_d364FilterProvider.notifier).state = null),
              for (final p in _Phase.values)
                _PhaseChip(label: _phaseLabel(p), selected: filter == p, color: _phaseColor(p), onTap: () => ref.read(_d364FilterProvider.notifier).state = p),
            ],
          ),
          const SizedBox(height: ZapSpacing.lg),
          const Text('Timeline (T-24h → T+24h)', style: TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: ZapSpacing.sm),
          ...items.map((i) => Container(
                margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
                padding: const EdgeInsets.all(ZapSpacing.md),
                decoration: BoxDecoration(
                  color: ZapColors.bgCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _phaseColor(i.phase).withOpacity(0.35)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(color: _phaseColor(i.phase).withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                      child: Text(i.offset, textAlign: TextAlign.center, style: TextStyle(color: _phaseColor(i.phase), fontWeight: FontWeight.w900, fontSize: 11)),
                    ),
                    const SizedBox(width: ZapSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(i.action, style: const TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 12))),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: ZapColors.bgSurface, borderRadius: BorderRadius.circular(4)),
                                child: Text(_roleLabel(i.role), style: const TextStyle(color: ZapColors.textMuted, fontSize: 9)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(i.detail, style: const TextStyle(color: ZapColors.textSecondary, fontSize: 10, height: 1.4)),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: ZapSpacing.xl),
          const Text('SOS monitoring escalation path', style: TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: 4),
          const Text('Safety-critical — separate from generic incident response.', style: TextStyle(color: ZapColors.textMuted, fontSize: 11)),
          const SizedBox(height: ZapSpacing.sm),
          ..._kEscalation.map((e) => Container(
                margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
                padding: const EdgeInsets.all(ZapSpacing.md),
                decoration: BoxDecoration(color: ZapColors.danger.withOpacity(0.06), borderRadius: BorderRadius.circular(10), border: Border.all(color: ZapColors.danger.withOpacity(0.3))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.warning_amber_rounded, color: ZapColors.danger, size: 16),
                      const SizedBox(width: 6),
                      Expanded(child: Text('IF: ${e.trigger}', style: const TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 11))),
                    ]),
                    const SizedBox(height: 6),
                    Text('THEN: ${e.action}', style: const TextStyle(color: ZapColors.textSecondary, fontSize: 11, height: 1.4)),
                    const SizedBox(height: 4),
                    Text('Owner: ${e.owner}', style: const TextStyle(color: ZapColors.textMuted, fontSize: 10)),
                  ],
                ),
              )),
          const SizedBox(height: ZapSpacing.lg),
          FilledButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _buildExportReport()));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Runbook copied.')));
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy full runbook'),
            style: FilledButton.styleFrom(backgroundColor: _kAccent, minimumSize: const Size(double.infinity, 48)),
          ),
          const SizedBox(height: ZapSpacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(color: ZapColors.bgCard, borderRadius: BorderRadius.circular(8), border: Border.all(color: ZapColors.border)),
            child: SelectableText(_kJsonEncoder.convert(_runbookPayload()), style: const TextStyle(color: ZapColors.textSecondary, fontSize: 10, fontFamily: 'monospace', height: 1.45)),
          ),
          const SizedBox(height: ZapSpacing.lg),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(label: const Text('Day 294 Support Macros'), onPressed: () => context.push(AppRoutes.supportMacros)),
              ActionChip(label: const Text('Day 293 Hotfix Playbook'), onPressed: () => context.push(AppRoutes.hotfixPlaybook)),
              ActionChip(label: const Text('Day 316 Staged Rollout'), onPressed: () => context.push(AppRoutes.playStagedRollout)),
              ActionChip(label: const Text('Day 361 War Room'), onPressed: () => context.push(AppRoutes.finalQaWarRoom)),
            ],
          ),
        ],
      ),
    );
  }
}

class _PhaseChip extends StatelessWidget {
  const _PhaseChip({required this.label, required this.selected, required this.color, required this.onTap});
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: color.withOpacity(0.2),
      checkmarkColor: color,
      labelStyle: TextStyle(color: selected ? color : ZapColors.textSecondary, fontSize: 11, fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
    );
  }
}
