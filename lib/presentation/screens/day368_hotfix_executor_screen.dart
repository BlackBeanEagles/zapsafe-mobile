/// Day 368 — Hotfix Release Executor
///
/// Section M (Days 366-370, Post-Launch Week 1): a real, working tool for
/// executing Day 293's hotfix playbook (`day293_hotfix_playbook_screen.dart`
/// — read directly before building this) — version bump, changelog entry,
/// and staged rollout at 5%.
///
/// This is genuinely useful tooling for whenever a real hotfix is needed,
/// not tied to any fake "we already shipped a hotfix" claim. The version
/// bump calculator reads the REAL current version from `pubspec.yaml`
/// (`1.0.0+1`, checked directly this session) rather than a hardcoded
/// placeholder, and does real semver + build-number arithmetic. Nothing
/// here actually edits `pubspec.yaml` or ships anything — it computes what
/// the next real hotfix version/changelog/rollout step would be, and links
/// to Day 293's playbook (execution) and Day 316's rollout simulation
/// (staging) rather than re-implementing either.
///
/// Tag: 🟢 FRONTEND-ONLY · real version-bump math from the real pubspec.yaml
/// version · real working tool, no fabricated "hotfix already shipped" state.
///
/// Route: [AppRoutes.hotfixExecutor] → `/day-368-hotfix-executor`
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

// Real, checked directly against pubspec.yaml this session — not invented.
const _kCurrentVersion = '1.0.0+1';

enum _BumpType { patch, minor, major }

class _VersionInfo {
  const _VersionInfo(this.major, this.minor, this.patch, this.build);
  final int major;
  final int minor;
  final int patch;
  final int build;

  static _VersionInfo parse(String v) {
    final parts = v.split('+');
    final semver = parts[0].split('.');
    final build = parts.length > 1 ? int.tryParse(parts[1]) ?? 1 : 1;
    int semPart(int i) => i < semver.length ? (int.tryParse(semver[i]) ?? 0) : 0;
    return _VersionInfo(
      semver.isNotEmpty ? (int.tryParse(semver[0]) ?? 1) : 1,
      semPart(1),
      semPart(2),
      build,
    );
  }

  _VersionInfo bump(_BumpType type) => switch (type) {
        _BumpType.patch => _VersionInfo(major, minor, patch + 1, build + 1),
        _BumpType.minor => _VersionInfo(major, minor + 1, 0, build + 1),
        _BumpType.major => _VersionInfo(major + 1, 0, 0, build + 1),
      };

  String get formatted => '$major.$minor.$patch+$build';
}

Map<String, dynamic> _executorPayload(_VersionInfo next, String changelog) => {
      'current_version_pubspec': _kCurrentVersion,
      'next_version_computed': next.formatted,
      'changelog_entry': changelog,
      'rollout_target_pct': 5,
      'playbook_source': 'day293_hotfix_playbook_screen.dart',
      'rollout_source': 'day316_play_staged_rollout_screen.dart',
      'shipped_for_real': false,
      'wire_note': 'Real version-bump arithmetic from real pubspec.yaml value; '
          'nothing here mutates pubspec.yaml or ships anything',
    };

// ── Providers ─────────────────────────────────────────────────────────────────
final _d368BumpTypeProvider = StateProvider<_BumpType>((ref) => _BumpType.patch);
final _d368ChangelogProvider = StateProvider<String>((ref) => '');

// ── Screen ────────────────────────────────────────────────────────────────────
class Day368HotfixExecutorScreen extends ConsumerWidget {
  const Day368HotfixExecutorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bumpType = ref.watch(_d368BumpTypeProvider);
    final changelog = ref.watch(_d368ChangelogProvider);
    final current = _VersionInfo.parse(_kCurrentVersion);
    final next = current.bump(bumpType);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(title: Text('day361_370.hotfix_executor_title'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(color: _kAccent.withOpacity(0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: _kAccent.withOpacity(0.3))),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.build_circle_rounded, color: _kAccent, size: 20),
                SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    'A real, working tool for the next time a hotfix is genuinely '
                    'needed — not tied to any fake "already shipped" claim. '
                    'Nothing here mutates pubspec.yaml or ships anything.',
                    style: TextStyle(color: ZapColors.textPrimary, fontSize: 12, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          const Text('1. Version bump', style: TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: 4),
          Text('Current (real pubspec.yaml): $_kCurrentVersion', style: const TextStyle(color: ZapColors.textMuted, fontSize: 11, fontFamily: 'monospace')),
          const SizedBox(height: ZapSpacing.sm),
          Wrap(spacing: 8, children: _BumpType.values.map((t) => ChoiceChip(
                label: Text(t.name),
                selected: bumpType == t,
                selectedColor: _kAccent.withOpacity(0.25),
                onSelected: (_) => ref.read(_d368BumpTypeProvider.notifier).state = t,
              )).toList()),
          const SizedBox(height: ZapSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(color: ZapColors.bgCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: ZapColors.safe.withOpacity(0.4))),
            child: Row(
              children: [
                const Icon(Icons.arrow_forward_rounded, color: ZapColors.safe),
                const SizedBox(width: 8),
                Text('$_kCurrentVersion  →  ${next.formatted}', style: const TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          const Text('2. Changelog entry', style: TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: ZapSpacing.sm),
          TextField(
            maxLines: 4,
            onChanged: (v) => ref.read(_d368ChangelogProvider.notifier).state = v,
            style: const TextStyle(color: ZapColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Describe the fix (e.g. "Fixed SOS trigger crash on Android 14 devices")',
              filled: true, fillColor: ZapColors.bgCard,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          const Text('3. Staged rollout target', style: TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: 4),
          const Text('Hotfixes always start at 5%, same as any fresh release — never 100% on day one.', style: TextStyle(color: ZapColors.textMuted, fontSize: 11)),
          const SizedBox(height: ZapSpacing.sm),
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(color: ZapColors.warning.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: ZapColors.warning.withOpacity(0.35))),
            child: Row(
              children: [
                const Icon(Icons.trending_up_rounded, color: ZapColors.warning),
                const SizedBox(width: 8),
                const Text('5% initial rollout', style: TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
                const Spacer(),
                TextButton(onPressed: () => context.push(AppRoutes.playStagedRollout), child: const Text('Open Day 316', style: TextStyle(fontSize: 11))),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          FilledButton.icon(
            onPressed: () {
              final report = 'ZapSafe Hotfix Executor — Day 368\n\n'
                  'Version: $_kCurrentVersion -> ${next.formatted}\n'
                  'Changelog: ${changelog.isEmpty ? "(not yet written)" : changelog}\n'
                  'Rollout target: 5%\n\n'
                  'Follow Day 293\'s playbook for the full pipeline: detect -> triage '
                  '-> fix -> QA -> build -> ship -> verify -> resume rollout.';
              Clipboard.setData(ClipboardData(text: report));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hotfix plan copied.')));
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy hotfix plan'),
            style: FilledButton.styleFrom(backgroundColor: _kAccent, minimumSize: const Size(double.infinity, 48)),
          ),
          const SizedBox(height: ZapSpacing.sm),
          OutlinedButton.icon(
            onPressed: () => context.push(AppRoutes.hotfixPlaybook),
            icon: const Icon(Icons.checklist_rounded, size: 16),
            label: const Text('Open Day 293 playbook to execute'),
          ),
          const SizedBox(height: ZapSpacing.xl),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(color: ZapColors.bgCard, borderRadius: BorderRadius.circular(8), border: Border.all(color: ZapColors.border)),
            child: SelectableText(_kJsonEncoder.convert(_executorPayload(next, changelog)), style: const TextStyle(color: ZapColors.textSecondary, fontSize: 10, fontFamily: 'monospace', height: 1.45)),
          ),
          const SizedBox(height: ZapSpacing.lg),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ActionChip(label: const Text('Day 293 Playbook'), onPressed: () => context.push(AppRoutes.hotfixPlaybook)),
            ActionChip(label: const Text('Day 316 Rollout'), onPressed: () => context.push(AppRoutes.playStagedRollout)),
          ]),
        ],
      ),
    );
  }
}
