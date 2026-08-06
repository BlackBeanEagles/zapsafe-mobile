/// Day 290 — Staged Rollout Simulator
///
/// Section E (Days 281-300): educational Play Store staged rollout UI —
/// advance through 10% → 25% → 50% → 100% with mock install and crash metrics.
///
/// Tag: 🟢 FRONTEND-ONLY · simulator only · no Play Console API.
///
/// Route: [AppRoutes.stagedRolloutSimulator] → `/staged-rollout-simulator`
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
const _kAccent = Color(0xFF34A853);
const _kTabs = ['Rollout', 'Metrics', 'Info'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');

class _RolloutStage {
  const _RolloutStage({
    required this.id,
    required this.pct,
    required this.label,
    required this.durationHint,
    required this.installBase,
    required this.crashFreePct,
    required this.anrRate,
    required this.uninstallPct,
    required this.note,
  });

  final String id;
  final int pct;
  final String label;
  final String durationHint;
  final int installBase;
  final double crashFreePct;
  final double anrRate;
  final double uninstallPct;
  final String note;
}

const _kStages = [
  _RolloutStage(
    id: 's10',
    pct: 10,
    label: 'Canary · 10%',
    durationHint: '24–48h recommended',
    installBase: 2400,
    crashFreePct: 99.71,
    anrRate: 0.08,
    uninstallPct: 1.2,
    note: 'Watch crash-free rate and 1-star spike before advancing.',
  ),
  _RolloutStage(
    id: 's25',
    pct: 25,
    label: 'Early · 25%',
    durationHint: '48h recommended',
    installBase: 6100,
    crashFreePct: 99.65,
    anrRate: 0.09,
    uninstallPct: 1.4,
    note: 'Compare Android 12 vs 14 cohorts · check SOS success.',
  ),
  _RolloutStage(
    id: 's50',
    pct: 50,
    label: 'Half · 50%',
    durationHint: '72h recommended',
    installBase: 12400,
    crashFreePct: 99.62,
    anrRate: 0.07,
    uninstallPct: 1.1,
    note: 'Counselor queue latency and notification delay stable.',
  ),
  _RolloutStage(
    id: 's100',
    pct: 100,
    label: 'Full · 100%',
    durationHint: 'Complete',
    installBase: 24800,
    crashFreePct: 99.60,
    anrRate: 0.06,
    uninstallPct: 0.9,
    note: 'Rollout complete — switch to post-launch monitoring (Day 292).',
  ),
];

_RolloutStage _stageAt(int index) =>
    _kStages[index.clamp(0, _kStages.length - 1)];

Map<String, dynamic> _rolloutPayload({
  required int stageIndex,
  required bool halted,
  required bool advanced,
}) {
  final stage = _stageAt(stageIndex);
  return {
    'endpoint': 'POST /api/v1/release/staged-rollout/simulate/',
    'platform': 'Google Play',
    'current_pct': stage.pct,
    'stage_id': stage.id,
    'halted': halted,
    'advanced': advanced,
    'crash_free_pct': stage.crashFreePct,
    'install_base': stage.installBase,
    'gate_passing': stage.crashFreePct >= 99.5,
    'stages': _kStages.map((s) => {'pct': s.pct, 'id': s.id}).toList(),
    'wire_note': 'Educational simulator · Play Console staged rollout path',
  };
}

String _buildRolloutReport({
  required int stageIndex,
  required bool halted,
}) {
  final stage = _stageAt(stageIndex);
  final buf = StringBuffer('ZapSafe Staged Rollout Report\n\n');
  buf.writeln('Platform: Google Play');
  buf.writeln('Current stage: ${stage.label} (${stage.pct}%)');
  buf.writeln('Status: ${halted ? 'HALTED' : 'ACTIVE'}');
  buf.writeln();
  buf.writeln('Install base: ${stage.installBase}');
  buf.writeln('Crash-free: ${stage.crashFreePct}%');
  buf.writeln('ANR rate: ${stage.anrRate}%');
  buf.writeln('Uninstall (24h): ${stage.uninstallPct}%');
  buf.writeln();
  buf.writeln('Guidance: ${stage.note}');
  return buf.toString();
}

// ── Providers ─────────────────────────────────────────────────────────────────
final _d290TabProvider = StateProvider<int>((ref) => 0);
final _d290StageIndexProvider = StateProvider<int>((ref) => 0);
final _d290HaltedProvider = StateProvider<bool>((ref) => false);
final _d290AdvancingProvider = StateProvider<bool>((ref) => false);

// ── Screen ────────────────────────────────────────────────────────────────────
class Day290StagedRolloutSimulatorScreen extends ConsumerWidget {
  const Day290StagedRolloutSimulatorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stage = _stageAt(ref.watch(_d290StageIndexProvider));
    final halted = ref.watch(_d290HaltedProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 290 · Staged Rollout'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (halted ? ZapColors.danger : _kAccent).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: (halted ? ZapColors.danger : _kAccent).withOpacity(0.45),
                  ),
                ),
                child: Text(
                  halted ? 'HALTED' : '${stage.pct}%',
                  style: TextStyle(
                    color: halted ? ZapColors.danger : _kAccent,
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
            tab: ref.watch(_d290TabProvider),
            onSelect: (i) => ref.read(_d290TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (ref.watch(_d290TabProvider)) {
              0 => const _RolloutTab(),
              1 => const _MetricsTab(),
              _ => const _InfoTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Rollout ────────────────────────────────────────────────────────────
class _RolloutTab extends ConsumerWidget {
  const _RolloutTab();

  Future<void> _advance(WidgetRef ref) async {
    if (ref.read(_d290AdvancingProvider) || ref.read(_d290HaltedProvider)) {
      return;
    }
    final idx = ref.read(_d290StageIndexProvider);
    if (idx >= _kStages.length - 1) return;

    ref.read(_d290AdvancingProvider.notifier).state = true;
    await Future<void>.delayed(const Duration(milliseconds: 700));
    ref.read(_d290StageIndexProvider.notifier).state = idx + 1;
    ref.read(_d290AdvancingProvider.notifier).state = false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stageIndex = ref.watch(_d290StageIndexProvider);
    final stage = _stageAt(stageIndex);
    final halted = ref.watch(_d290HaltedProvider);
    final advancing = ref.watch(_d290AdvancingProvider);
    final atMax = stageIndex >= _kStages.length - 1;

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _SectionTitle(
          title: 'Play Store staged rollout',
          subtitle: 'Educational path: 10% → 25% → 50% → 100%',
        ),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.lg),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ZapColors.border),
          ),
          child: Column(
            children: [
              Row(
                children: _kStages.map((s) {
                  final idx = _kStages.indexOf(s);
                  final active = idx <= stageIndex;
                  final current = idx == stageIndex;
                  return Expanded(
                    child: Column(
                      children: [
                        Container(
                          height: 8,
                          margin: EdgeInsets.only(
                            right: idx < _kStages.length - 1 ? 4 : 0,
                          ),
                          decoration: BoxDecoration(
                            color: active
                                ? (current ? _kAccent : _kAccent.withOpacity(0.5))
                                : ZapColors.border,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${s.pct}%',
                          style: TextStyle(
                            color: current ? _kAccent : ZapColors.textMuted,
                            fontSize: 10,
                            fontWeight:
                                current ? FontWeight.w900 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: ZapSpacing.lg),
              Text(
                stage.label,
                style: const TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
              Text(
                stage.durationHint,
                style: const TextStyle(color: ZapColors.textMuted, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.info.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.info.withOpacity(0.25)),
          ),
          child: Text(
            stage.note,
            style: const TextStyle(
              color: ZapColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: halted || advancing || atMax
                    ? null
                    : () => _advance(ref),
                icon: advancing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.trending_up_rounded, size: 18),
                label: Text(atMax ? 'Rollout complete' : 'Advance stage'),
                style: FilledButton.styleFrom(backgroundColor: _kAccent),
              ),
            ),
            const SizedBox(width: ZapSpacing.sm),
            OutlinedButton.icon(
              onPressed: atMax
                  ? null
                  : () {
                      final h = !ref.read(_d290HaltedProvider);
                      ref.read(_d290HaltedProvider.notifier).state = h;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(h ? 'Rollout halted (mock).' : 'Rollout resumed.'),
                        ),
                      );
                    },
              icon: Icon(
                halted ? Icons.play_arrow_rounded : Icons.pause_rounded,
                size: 18,
              ),
              label: Text(halted ? 'Resume' : 'Halt'),
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.sm),
        OutlinedButton.icon(
          onPressed: () {
            ref.read(_d290StageIndexProvider.notifier).state = 0;
            ref.read(_d290HaltedProvider.notifier).state = false;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Rollout reset to 10%.')),
            );
          },
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Reset simulator'),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const _PolicyRow(
          icon: Icons.warning_amber_rounded,
          title: 'When to halt',
          subtitle:
              'Crash-free < 99.5%, ANR spike, or SOS delivery regression — pause and hotfix.',
        ),
        const _PolicyRow(
          icon: Icons.schedule_rounded,
          title: 'Dwell time',
          subtitle:
              'Stay at each stage long enough for statistically meaningful install volume.',
        ),
      ],
    );
  }
}

// ── Tab 1: Metrics ────────────────────────────────────────────────────────────
class _MetricsTab extends ConsumerWidget {
  const _MetricsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stage = _stageAt(ref.watch(_d290StageIndexProvider));
    final passing = stage.crashFreePct >= 99.5;

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _SectionTitle(
          title: 'Stage metrics (mock)',
          subtitle: 'Play Console vitals at current rollout percentage',
        ),
        _MetricCard(
          label: 'Active installs',
          value: '${stage.installBase}',
          icon: Icons.download_rounded,
          color: _kAccent,
        ),
        _MetricCard(
          label: 'Crash-free sessions',
          value: '${stage.crashFreePct}%',
          icon: Icons.bug_report_rounded,
          color: passing ? ZapColors.safe : ZapColors.danger,
          subtitle: passing ? 'Above 99.5% gate' : 'Below gate — consider halt',
        ),
        _MetricCard(
          label: 'ANR rate',
          value: '${stage.anrRate}%',
          icon: Icons.hourglass_bottom_rounded,
          color: stage.anrRate < 0.1 ? ZapColors.safe : ZapColors.warning,
        ),
        _MetricCard(
          label: 'Uninstall rate (24h)',
          value: '${stage.uninstallPct}%',
          icon: Icons.delete_outline_rounded,
          color: ZapColors.textSecondary,
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.border),
          ),
          child: SelectableText(
            _buildRolloutReport(
              stageIndex: ref.watch(_d290StageIndexProvider),
              halted: ref.watch(_d290HaltedProvider),
            ),
            style: const TextStyle(
              color: ZapColors.textSecondary,
              fontSize: 10,
              fontFamily: 'monospace',
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        FilledButton.icon(
          onPressed: () {
            Clipboard.setData(
              ClipboardData(
                text: _buildRolloutReport(
                  stageIndex: ref.watch(_d290StageIndexProvider),
                  halted: ref.watch(_d290HaltedProvider),
                ),
              ),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Rollout report copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text('Copy rollout report'),
          style: FilledButton.styleFrom(backgroundColor: _kAccent),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: ZapColors.textMuted,
                    fontSize: 10,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: ZapColors.textSecondary,
                      fontSize: 10,
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

// ── Tab 2: Info ───────────────────────────────────────────────────────────────
class _InfoTab extends ConsumerWidget {
  const _InfoTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payload = _rolloutPayload(
      stageIndex: ref.watch(_d290StageIndexProvider),
      halted: ref.watch(_d290HaltedProvider),
      advanced: ref.watch(_d290StageIndexProvider) > 0,
    );

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _SectionTitle(
          title: 'Staged rollout simulator',
          subtitle:
              'Teaches Play Console percentage rollout before full release.',
        ),
        const _PolicyRow(
          icon: Icons.play_circle_rounded,
          title: 'Google Play staged rollout',
          subtitle: '10% canary → expand only if vitals and reviews stay healthy.',
        ),
        const _PolicyRow(
          icon: Icons.apple_rounded,
          title: 'App Store note',
          subtitle:
              'iOS uses phased release over 7 days — different UX, same caution.',
        ),
        const _PolicyRow(
          icon: Icons.link_rounded,
          title: 'Launch gates',
          subtitle: 'Tie to Day 288 crash-free ≥ 99.5% and Day 289 full regression.',
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
              const SnackBar(content: Text('Rollout spec copied.')),
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
            'Tomorrow: Day 291 — Global vs India Release Compare '
            '(languages · SMS · emergency · pricing).',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              label: const Text('Day 288 Crash-Free'),
              onPressed: () => context.push(AppRoutes.crashFreeTracker),
            ),
            ActionChip(
              label: const Text('Day 289 Regression'),
              onPressed: () => context.push(AppRoutes.fullRegressionRunner),
            ),
            ActionChip(
              label: const Text('Day 150 Production'),
              onPressed: () => context.push(AppRoutes.productionRelease),
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
