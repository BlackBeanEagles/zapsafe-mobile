/// Day 371 — Staged Rollout: 50% → 100% Checklist
///
/// Section N (Days 371-380, Scale & Stabilize): a checklist tool for
/// advancing a REAL Play/App Store staged rollout from 50% to 100%.
///
/// **There is no real rollout to advance.** Day 316's staged rollout
/// screen (`day316_play_staged_rollout_screen.dart`) is a local-only
/// stage-tracker simulation — it has never called a real Play Console or
/// App Store Connect API, and the app has never actually been submitted
/// for real (Day 362/363's submission checklists are themselves manual
/// checklists that were never executed against a live console either).
/// This screen does not pretend otherwise: every checklist item below
/// defaults to unchecked/not-yet, and the header states plainly that
/// there is currently no rollout in flight to advance at all.
///
/// What this screen actually is: real, working tooling for the future
/// moment a genuine rollout reaches 50% — the real go/no-go checklist to
/// run before pushing to 100%, plus a direct link into Day 316's
/// simulator (to rehearse the stage-advance mechanics) and Day 361's war
/// room (P0 gate — 100% must never ship with an open P0).
///
/// Tag: 🟢 FRONTEND-ONLY · real checklist tool for a rollout that has not
/// started · nothing here calls Play Console / App Store Connect.
///
/// Route: [AppRoutes.rollout100Checklist] → `/day-371-rollout-100`
library;

import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const _kAccent = Color(0xFF06D6A0);
const _kJsonEncoder = JsonEncoder.withIndent('  ');
const _kPrefsKeyPrefix = 'day371_rollout100_item_v1_';

class _ChecklistItem {
  const _ChecklistItem({required this.id, required this.title, required this.detail, required this.platform});
  final String id;
  final String title;
  final String detail;
  final String platform; // 'Play', 'App Store', 'Both'
}

const _kItems = [
  _ChecklistItem(
    id: 'crash_free',
    title: 'Crash-free rate ≥ 99.5% at 50%',
    detail: 'Check Android Vitals (Play Console → Quality → Android Vitals) and Xcode Organizer crash reports for the current 50% cohort over the last 48h.',
    platform: 'Both',
  ),
  _ChecklistItem(
    id: 'anr_rate',
    title: 'ANR rate within Play threshold',
    detail: 'Android Vitals → ANR rate must stay under Google\'s "bad behavior" threshold for the 50% cohort. No equivalent on iOS.',
    platform: 'Play',
  ),
  _ChecklistItem(
    id: 'no_open_p0',
    title: 'Zero open P0 (Day 361 war room)',
    detail: 'Re-check Day 361\'s Final QA War Room — 100% must never ship while any P0 is open. This is a hard gate, not a judgment call.',
    platform: 'Both',
  ),
  _ChecklistItem(
    id: 'dwell_time',
    title: 'Minimum 24-48h dwell time at 50%',
    detail: 'Google/Apple both recommend observing each stage for at least a day before advancing, so slow-to-surface issues (battery drain, background-service kills) have time to show up.',
    platform: 'Both',
  ),
  _ChecklistItem(
    id: 'support_volume',
    title: 'Support ticket volume is manageable',
    detail: 'Check Day 369\'s support triage board — an unexpected spike in new tickets at 50% is a signal to pause, not advance.',
    platform: 'Both',
  ),
  _ChecklistItem(
    id: 'rating_trend',
    title: 'Store rating trend is not declining',
    detail: 'Check Day 367\'s ratings & reviews monitor for the 50% cohort\'s sentiment before widening exposure to 100%.',
    platform: 'Both',
  ),
  _ChecklistItem(
    id: 'infra_headroom',
    title: 'Backend has headroom for 2x traffic',
    detail: 'Per Day 257\'s real production load test, the current single Oracle VM sustains ~34 req/s with graceful (not broken) degradation at 100 concurrent Locust users. Advancing to 100% roughly doubles real registered-user exposure versus 50% — re-check backend capacity before advancing, not after.',
    platform: 'Both',
  ),
  _ChecklistItem(
    id: 'rollback_plan',
    title: 'Rollback / halt plan is ready',
    detail: 'Confirm you know exactly how to hit "Halt rollout" (Play) or reject/pull the build (App Store) before advancing — decide this before you need it, not during an incident.',
    platform: 'Both',
  ),
];

Map<String, dynamic> _payload(Map<String, bool> checked) => {
      'rollout_in_flight': false,
      'current_real_stage_pct': null,
      'target_stage_pct': 100,
      'items_checked': checked.values.where((v) => v).length,
      'items_total': _kItems.length,
      'ready_to_advance': checked.values.every((v) => v) && checked.length == _kItems.length,
      'simulator_source': 'day316_play_staged_rollout_screen.dart',
      'p0_gate_source': 'day361_final_qa_war_room_screen.dart',
      'wire_note': 'Real checklist tool for a rollout that has not started. '
          'Nothing here calls Play Console or App Store Connect.',
    };

// ── Providers ─────────────────────────────────────────────────────────────────
class _ChecklistNotifier extends StateNotifier<Map<String, bool>> {
  _ChecklistNotifier() : super({for (final i in _kItems) i.id: false}) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final loaded = <String, bool>{};
      for (final i in _kItems) {
        loaded[i.id] = prefs.getBool('$_kPrefsKeyPrefix${i.id}') ?? false;
      }
      state = loaded;
    } catch (_) {}
  }

  Future<void> toggle(String id) async {
    state = {...state, id: !(state[id] ?? false)};
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_kPrefsKeyPrefix$id', state[id]!);
    } catch (_) {}
  }

  Future<void> reset() async {
    state = {for (final i in _kItems) i.id: false};
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final i in _kItems) {
        await prefs.setBool('$_kPrefsKeyPrefix${i.id}', false);
      }
    } catch (_) {}
  }
}

final _d371ChecklistProvider = StateNotifierProvider<_ChecklistNotifier, Map<String, bool>>((ref) => _ChecklistNotifier());

// ── Screen ────────────────────────────────────────────────────────────────────
class Day371Rollout100Screen extends ConsumerWidget {
  const Day371Rollout100Screen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checked = ref.watch(_d371ChecklistProvider);
    final doneCount = checked.values.where((v) => v).length;
    final allDone = doneCount == _kItems.length;

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(title: Text('day371_380.rollout100_title'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(color: ZapColors.warning.withOpacity(0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: ZapColors.warning.withOpacity(0.35))),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_rounded, color: ZapColors.warning, size: 20),
                SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    'There is no real rollout in flight right now — Day 316\'s '
                    'simulator is local-only and has never called Play Console '
                    'or App Store Connect. This is real go/no-go tooling for the '
                    'future moment a genuine rollout genuinely reaches 50%.',
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
            decoration: BoxDecoration(
              color: (allDone ? ZapColors.safe : ZapColors.bgCard).withOpacity(allDone ? 0.12 : 1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: allDone ? ZapColors.safe : ZapColors.border),
            ),
            child: Row(
              children: [
                Icon(allDone ? Icons.check_circle_rounded : Icons.pending_rounded, color: allDone ? ZapColors.safe : ZapColors.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    allDone ? 'All items checked — ready to advance when a real rollout exists' : '$doneCount / ${_kItems.length} checked',
                    style: const TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          for (final item in _kItems) ...[
            _ChecklistTile(item: item, checked: checked[item.id] ?? false, onToggle: () => ref.read(_d371ChecklistProvider.notifier).toggle(item.id)),
            const SizedBox(height: ZapSpacing.sm),
          ],
          const SizedBox(height: ZapSpacing.md),
          OutlinedButton.icon(
            onPressed: () => ref.read(_d371ChecklistProvider.notifier).reset(),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Reset checklist'),
          ),
          const SizedBox(height: ZapSpacing.xl),
          FilledButton.icon(
            onPressed: () {
              final buf = StringBuffer('ZapSafe Rollout 50% → 100% Checklist — Day 371\n');
              buf.writeln('(No real rollout is in flight — this is a readiness checklist)\n');
              for (final item in _kItems) {
                buf.writeln('[${(checked[item.id] ?? false) ? "x" : " "}] ${item.title} (${item.platform})');
              }
              Clipboard.setData(ClipboardData(text: buf.toString()));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Checklist copied.')));
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy checklist'),
            style: FilledButton.styleFrom(backgroundColor: _kAccent, minimumSize: const Size(double.infinity, 48)),
          ),
          const SizedBox(height: ZapSpacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(color: ZapColors.bgCard, borderRadius: BorderRadius.circular(8), border: Border.all(color: ZapColors.border)),
            child: SelectableText(_kJsonEncoder.convert(_payload(checked)), style: const TextStyle(color: ZapColors.textSecondary, fontSize: 10, fontFamily: 'monospace', height: 1.45)),
          ),
          const SizedBox(height: ZapSpacing.lg),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ActionChip(label: const Text('Day 316 Rollout Simulator'), onPressed: () => context.push(AppRoutes.playStagedRollout)),
            ActionChip(label: const Text('Day 361 War Room'), onPressed: () => context.push(AppRoutes.finalQaWarRoom)),
            ActionChip(label: const Text('Day 369 Support Triage'), onPressed: () => context.push(AppRoutes.supportTriage)),
            ActionChip(label: const Text('Day 367 Ratings Monitor'), onPressed: () => context.push(AppRoutes.ratingsReviewsMonitor)),
          ]),
        ],
      ),
    );
  }
}

class _ChecklistTile extends StatelessWidget {
  const _ChecklistTile({required this.item, required this.checked, required this.onToggle});
  final _ChecklistItem item;
  final bool checked;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
          color: ZapColors.bgCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: checked ? ZapColors.safe.withOpacity(0.5) : ZapColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(value: checked, onChanged: (_) => onToggle(), activeColor: ZapColors.safe),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(item.title, style: const TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: ZapColors.info.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                        child: Text(item.platform, style: const TextStyle(color: ZapColors.info, fontSize: 9, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(item.detail, style: const TextStyle(color: ZapColors.textMuted, fontSize: 11, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
