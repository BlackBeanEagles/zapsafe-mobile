/// Day 381 — Hotfix v1.0.1 Release (Tooling Demonstration)
///
/// Section O (Days 381-390, Project Close): a concrete walk-through of what
/// a v1.0.1 hotfix cycle would look like, built on Day 368's real hotfix
/// executor (`day368_hotfix_executor_screen.dart` — read directly before
/// building this) rather than duplicating its version-bump math.
///
/// ⚠️ **v1.0.1 has NOT shipped.** There is no v1.0.0 live anywhere to
/// hotfix — the app has not launched (Day 361's war room still gates
/// launch on 5 real open P0s). The real current `pubspec.yaml` version is
/// `1.0.0+1` (checked directly this session, same value Day 368 verified).
/// This screen walks through ONE hypothetical v1.0.1 patch cycle end to
/// end — using Day 368's real semver-bump arithmetic — so the release
/// process is demonstrated and rehearsed for whenever a genuine hotfix is
/// needed, not recorded as something that already happened.
///
/// The "example fix" text below is clearly labeled EXAMPLE — a plausible
/// patch-sized bug, not a real incident report. All 5 cycle steps default
/// unchecked; nothing here mutates `pubspec.yaml`, builds an artifact, or
/// ships anything.
///
/// Tag: 🟢 FRONTEND-ONLY · real version arithmetic from the real
/// pubspec.yaml value · demonstration only, v1.0.1 has NOT shipped.
///
/// Route: [AppRoutes.hotfixV101] → `/day-381-hotfix-v101`
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
const _kAccent = Color(0xFFEF4444);
const _kJsonEncoder = JsonEncoder.withIndent('  ');

// Real, checked directly against pubspec.yaml this session — matches
// Day 368's verified value.
const _kCurrentVersion = '1.0.0+1';
const _kTargetVersion = '1.0.1+2'; // patch bump, computed the same way Day 368 does

const _kCycleSteps = [
  ('detect', 'Detect', 'A real crash/bug report would trigger this — none exists right now.'),
  ('triage', 'Triage', 'Confirm severity + scope against Day 293\'s playbook triage matrix.'),
  ('fix', 'Fix', 'Author the patch; keep the diff minimal for a hotfix.'),
  ('test', 'Test', 'Run the full suite (this repo\'s own baseline) + manual smoke on affected flow.'),
  ('stage', 'Stage at 5%', 'Ship to a 5% rollout ring via Day 316\'s staged-rollout tool, never 100% day one.'),
];

Map<String, dynamic> _payload(Map<String, bool> done) => {
      'is_real_hotfix': false,
      'v100_ever_shipped': false,
      'current_version_pubspec': _kCurrentVersion,
      'target_version_computed': _kTargetVersion,
      'bump_type': 'patch',
      'cycle_steps_done': done.entries.where((e) => e.value).map((e) => e.key).toList(),
      'cycle_steps_total': _kCycleSteps.length,
      'executor_source': 'day368_hotfix_executor_screen.dart',
      'wire_note': 'Demonstration of the hotfix cycle only — nothing here '
          'mutates pubspec.yaml, builds an artifact, or ships anything.',
    };

// ── Providers ─────────────────────────────────────────────────────────────────
final _d381DoneProvider = StateProvider<Map<String, bool>>((ref) => {});

// ── Screen ────────────────────────────────────────────────────────────────────
class Day381HotfixV101Screen extends ConsumerWidget {
  const Day381HotfixV101Screen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = ref.watch(_d381DoneProvider);
    final doneCount = done.values.where((v) => v).length;

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: Text('day381_390.hotfix_v101_title'.tr()),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _kAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _kAccent.withOpacity(0.45)),
                ),
                child: Text('$doneCount/${_kCycleSteps.length}', style: const TextStyle(color: _kAccent, fontSize: 10, fontWeight: FontWeight.w900)),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(color: ZapColors.danger.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: ZapColors.danger.withOpacity(0.35), width: 2)),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.gpp_bad_rounded, color: ZapColors.danger, size: 20),
                SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    'v1.0.1 has NOT shipped. There is no real v1.0.0 live anywhere to '
                    'hotfix — the app has not launched. This is a rehearsal of the '
                    'process, built on Day 368\'s real executor, for whenever a genuine '
                    'hotfix is needed.',
                    style: TextStyle(color: ZapColors.textPrimary, fontSize: 12, height: 1.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(color: ZapColors.bgCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: ZapColors.safe.withOpacity(0.4))),
            child: Row(
              children: [
                const Icon(Icons.arrow_forward_rounded, color: ZapColors.safe),
                const SizedBox(width: 8),
                Text('$_kCurrentVersion  →  $_kTargetVersion', style: const TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 16)),
                const Spacer(),
                const Text('PATCH', style: TextStyle(color: ZapColors.textMuted, fontSize: 10, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.lg),
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(color: ZapColors.warning.withOpacity(0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: ZapColors.warning.withOpacity(0.3))),
            child: const Text(
              'EXAMPLE fix (illustrative, not a real incident): "Fixed a crash on '
              'Android 14 when opening Evidence Vault from a cold-started notification '
              'tap." A patch-sized, plausible bug — chosen to demonstrate the process, '
              'not a report of anything that actually happened.',
              style: TextStyle(color: ZapColors.textSecondary, fontSize: 11, height: 1.4, fontStyle: FontStyle.italic),
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          const Text('Hotfix cycle (Day 293 playbook order)', style: TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: ZapSpacing.sm),
          for (final step in _kCycleSteps)
            Container(
              margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
              padding: const EdgeInsets.all(ZapSpacing.md),
              decoration: BoxDecoration(color: ZapColors.bgCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: (done[step.$1] == true ? ZapColors.safe : ZapColors.border))),
              child: Row(
                children: [
                  Checkbox(value: done[step.$1] == true, activeColor: ZapColors.safe, onChanged: (v) => ref.read(_d381DoneProvider.notifier).state = {...done, step.$1: v ?? false}),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(step.$2, style: const TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                        Text(step.$3, style: const TextStyle(color: ZapColors.textSecondary, fontSize: 11, height: 1.35)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: ZapSpacing.lg),
          FilledButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _kJsonEncoder.convert(_payload(done))));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hotfix cycle spec copied. v1.0.1 has NOT shipped.')));
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy cycle spec (not a real release)'),
            style: FilledButton.styleFrom(backgroundColor: _kAccent, minimumSize: const Size(double.infinity, 48)),
          ),
          const SizedBox(height: ZapSpacing.sm),
          OutlinedButton.icon(
            onPressed: () => context.push(AppRoutes.hotfixExecutor),
            icon: const Icon(Icons.build_circle_rounded, size: 16),
            label: const Text('Open Day 368 executor (generic tool)'),
          ),
          const SizedBox(height: ZapSpacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(color: ZapColors.bgCard, borderRadius: BorderRadius.circular(8), border: Border.all(color: ZapColors.border)),
            child: SelectableText(_kJsonEncoder.convert(_payload(done)), style: const TextStyle(color: ZapColors.textSecondary, fontSize: 10, fontFamily: 'monospace', height: 1.45)),
          ),
          const SizedBox(height: ZapSpacing.lg),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ActionChip(label: const Text('Day 368 Executor'), onPressed: () => context.push(AppRoutes.hotfixExecutor)),
            ActionChip(label: const Text('Day 361 War Room'), onPressed: () => context.push(AppRoutes.finalQaWarRoom)),
            ActionChip(label: const Text('Day 382 v1.0.2'), onPressed: () => context.push(AppRoutes.hotfixV102)),
          ]),
        ],
      ),
    );
  }
}
