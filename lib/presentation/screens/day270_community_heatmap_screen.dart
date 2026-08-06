/// Day 270 — Community Heatmap Contributions
///
/// Section D (Days 261-280): visualize anonymous near-miss reports the user
/// contributed to the community heatmap; opt-in tied to consent settings mock.
///
/// Tag: 🟡 MOCK-NOW · GET /api/v1/community/heatmap/contributions/.
///
/// Route: [AppRoutes.communityHeatmap] → `/community-heatmap`
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const _kAccent = Color(0xFFEA580C);
const _kTabs = ['Heatmap', 'Contributions', 'Info'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');
const _kGridCols = 14;
const _kGridRows = 10;

class _NearMissContribution {
  const _NearMissContribution({
    required this.id,
    required this.areaLabel,
    required this.type,
    required this.daysAgo,
    required this.gridCol,
    required this.gridRow,
    required this.anonymizedHash,
  });

  final String id;
  final String areaLabel;
  final String type;
  final int daysAgo;
  final int gridCol;
  final int gridRow;
  final String anonymizedHash;
}

const _kMockContributions = [
  _NearMissContribution(
    id: 'nm-001',
    areaLabel: 'Koramangala 5th Block',
    type: 'Poor lighting',
    daysAgo: 3,
    gridCol: 4,
    gridRow: 6,
    anonymizedHash: 'a7f3…9c2',
  ),
  _NearMissContribution(
    id: 'nm-002',
    areaLabel: 'MG Road Metro exit',
    type: 'Harassment report',
    daysAgo: 12,
    gridCol: 7,
    gridRow: 3,
    anonymizedHash: 'b1e8…4d0',
  ),
  _NearMissContribution(
    id: 'nm-003',
    areaLabel: 'Indiranagar 100ft Rd',
    type: 'Suspicious activity',
    daysAgo: 28,
    gridCol: 9,
    gridRow: 5,
    anonymizedHash: 'c9aa…1f7',
  ),
  _NearMissContribution(
    id: 'nm-004',
    areaLabel: 'HSR Sector 2',
    type: 'Unsafe transit',
    daysAgo: 45,
    gridCol: 11,
    gridRow: 7,
    anonymizedHash: 'd4bc…8e3',
  ),
  _NearMissContribution(
    id: 'nm-005',
    areaLabel: 'Whitefield Main Rd',
    type: 'Poor lighting',
    daysAgo: 67,
    gridCol: 12,
    gridRow: 2,
    anonymizedHash: 'e2de…6b1',
  ),
];

List<List<double>> _buildCommunityHeatmap() {
  final rng = math.Random(270);
  return List.generate(
    _kGridRows,
    (_) => List.generate(_kGridCols, (_) => rng.nextDouble()),
  );
}

Color _heatColor(double intensity) {
  if (intensity < 0.15) return ZapColors.bgCard;
  if (intensity < 0.35) {
    return Color.lerp(ZapColors.warning.withOpacity(0.25), _kAccent, 0.4)!;
  }
  if (intensity < 0.6) {
    return Color.lerp(_kAccent.withOpacity(0.55), _kAccent, 0.8)!;
  }
  return Color.lerp(_kAccent, ZapColors.danger, intensity)!;
}

// ── Providers ─────────────────────────────────────────────────────────────────
final _d270TabProvider = StateProvider<int>((ref) => 0);
final _d270OptInProvider = StateProvider<bool>((ref) => true);
final _d270ShowMineProvider = StateProvider<bool>((ref) => true);
final _d270ShowCommunityProvider = StateProvider<bool>((ref) => true);
final _d270SelectedIdProvider = StateProvider<String?>((ref) => null);

// ── Screen ────────────────────────────────────────────────────────────────────
class Day270CommunityHeatmapScreen extends ConsumerWidget {
  const Day270CommunityHeatmapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d270TabProvider);
    final optIn = ref.watch(_d270OptInProvider);
    final selectedId = ref.watch(_d270SelectedIdProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 270 · Community Heatmap'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (optIn ? ZapColors.safe : ZapColors.warning)
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: (optIn ? ZapColors.safe : ZapColors.warning)
                        .withOpacity(0.45),
                  ),
                ),
                child: Text(
                  optIn ? 'OPT-IN ✅' : 'OPT-OUT',
                  style: TextStyle(
                    color: optIn ? ZapColors.safe : ZapColors.warning,
                    fontSize: 11,
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
            tab: tab,
            onSelect: (i) => ref.read(_d270TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (tab) {
              0 => _HeatmapTab(selectedId: selectedId),
              1 => const _ContributionsTab(),
              _ => const _InfoTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Heatmap ────────────────────────────────────────────────────────────
class _HeatmapTab extends ConsumerWidget {
  const _HeatmapTab({required this.selectedId});

  final String? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final optIn = ref.watch(_d270OptInProvider);
    final showMine = ref.watch(_d270ShowMineProvider);
    final showCommunity = ref.watch(_d270ShowCommunityProvider);
    final heatmap = _buildCommunityHeatmap();

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _kAccent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _kAccent.withOpacity(0.35)),
          ),
          child: const Text(
            '🟡 MOCK-NOW · Section D Day 10/20 · anonymous near-miss tiles · consent opt-in',
            style: TextStyle(color: _kAccent, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        if (!optIn) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ZapColors.warning.withOpacity(0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Heatmap contribution is off',
                  style: TextStyle(
                    color: ZapColors.warning,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Enable opt-in in Privacy Settings to contribute anonymous '
                  'near-miss reports and view your tiles on the community map.',
                  style: TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: ZapSpacing.sm),
                FilledButton.icon(
                  onPressed: () => context.push(AppRoutes.privacySettings),
                  icon: const Icon(Icons.privacy_tip_outlined, size: 16),
                  label: const Text('Open Privacy Settings'),
                  style: FilledButton.styleFrom(backgroundColor: _kAccent),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.lg),
        ],
        Row(
          children: [
            FilterChip(
              label: const Text('Community heat'),
              selected: showCommunity,
              selectedColor: _kAccent.withOpacity(0.2),
              onSelected: optIn ? (v) => ref.read(_d270ShowCommunityProvider.notifier).state = v : null,
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: const Text('Your contributions'),
              selected: showMine,
              selectedColor: ZapColors.safe.withOpacity(0.2),
              onSelected: optIn ? (v) => ref.read(_d270ShowMineProvider.notifier).state = v : null,
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.md),
        Stack(
          children: [
            _HeatmapGrid(
              heatmap: heatmap,
              contributions: optIn && showMine ? _kMockContributions : const [],
              showCommunity: optIn && showCommunity,
              selectedId: selectedId,
              onSelect: (id) =>
                  ref.read(_d270SelectedIdProvider.notifier).state = id,
            ),
            if (!optIn)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: ZapColors.bgPrimary.withOpacity(0.72),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Opt in to view heatmap',
                    style: TextStyle(
                      color: ZapColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: ZapSpacing.sm),
        Row(
          children: [
            const _LegendSwatch(color: ZapColors.bgCard, label: 'Low'),
            const SizedBox(width: 12),
            _LegendSwatch(color: _kAccent.withOpacity(0.6), label: 'Medium'),
            const SizedBox(width: 12),
            const _LegendSwatch(color: ZapColors.danger, label: 'High'),
            const SizedBox(width: 12),
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                border: Border.all(color: ZapColors.safe, width: 2),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              'Your report',
              style: TextStyle(color: ZapColors.textMuted, fontSize: 10),
            ),
          ],
        ),
        if (selectedId != null) ...[
          const SizedBox(height: ZapSpacing.md),
          _SelectedContributionCard(
            contribution: _kMockContributions.firstWhere(
              (c) => c.id == selectedId,
            ),
          ),
        ],
      ],
    );
  }
}

class _HeatmapGrid extends StatelessWidget {
  const _HeatmapGrid({
    required this.heatmap,
    required this.contributions,
    required this.showCommunity,
    required this.selectedId,
    required this.onSelect,
  });

  final List<List<double>> heatmap;
  final List<_NearMissContribution> contributions;
  final bool showCommunity;
  final String? selectedId;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final userCells = {
      for (final c in contributions) '${c.gridCol}:${c.gridRow}': c.id,
    };

    return AspectRatio(
      aspectRatio: 1.35,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: ZapColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ZapColors.border),
        ),
        child: Column(
          children: List.generate(_kGridRows, (row) {
            return Expanded(
              child: Row(
                children: List.generate(_kGridCols, (col) {
                  final key = '$col:$row';
                  final userId = userCells[key];
                  final intensity = heatmap[row][col];
                  final selected = userId != null && userId == selectedId;

                  return Expanded(
                    child: GestureDetector(
                      onTap: userId != null ? () => onSelect(userId) : null,
                      child: Container(
                        margin: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          color: showCommunity
                              ? _heatColor(intensity)
                              : ZapColors.bgCard,
                          borderRadius: BorderRadius.circular(2),
                          border: userId != null
                              ? Border.all(
                                  color: selected
                                      ? ZapColors.safe
                                      : ZapColors.safe.withOpacity(0.7),
                                  width: selected ? 2.5 : 1.5,
                                )
                              : null,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _LegendSwatch extends StatelessWidget {
  const _LegendSwatch({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: ZapColors.border),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: ZapColors.textMuted, fontSize: 10)),
      ],
    );
  }
}

class _SelectedContributionCard extends StatelessWidget {
  const _SelectedContributionCard({required this.contribution});

  final _NearMissContribution contribution;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.safe.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ZapColors.safe.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            contribution.areaLabel,
            style: const TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            '${contribution.type} · ${contribution.daysAgo}d ago · '
            'hash ${contribution.anonymizedHash}',
            style: const TextStyle(color: ZapColors.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ── Tab 1: Contributions ──────────────────────────────────────────────────────
class _ContributionsTab extends ConsumerWidget {
  const _ContributionsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final optIn = ref.watch(_d270OptInProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ZapColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Heatmap contribution',
                          style: TextStyle(
                            color: ZapColors.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Anonymous near-miss reports · no identity attached',
                          style: TextStyle(
                            color: ZapColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: optIn,
                    activeColor: ZapColors.safe,
                    onChanged: (v) {
                      ref.read(_d270OptInProvider.notifier).state = v;
                      HapticFeedback.lightImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            v
                                ? 'Opt-in enabled (mock) · matches Privacy Settings'
                                : 'Opt-out enabled · your reports hidden from heatmap',
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              if (!optIn)
                TextButton.icon(
                  onPressed: () => context.push(AppRoutes.consentManagement),
                  icon: const Icon(Icons.settings_outlined, size: 16),
                  label: const Text('Manage in Consent Management'),
                ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Row(
          children: [
            _StatCard(
              label: 'Reports',
              value: optIn ? '${_kMockContributions.length}' : '0',
              color: _kAccent,
            ),
            const SizedBox(width: 8),
            _StatCard(
              label: 'Areas',
              value: optIn ? '${_kMockContributions.length}' : '0',
              color: ZapColors.info,
            ),
            const SizedBox(width: 8),
            _StatCard(
              label: '90-day reach',
              value: optIn ? '1.2k' : '—',
              color: ZapColors.safe,
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Your anonymous near-miss reports',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        if (!optIn)
          Container(
            padding: const EdgeInsets.all(ZapSpacing.lg),
            decoration: BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ZapColors.border),
            ),
            child: const Text(
              'No contributions visible while opted out. Enable heatmap '
              'contribution to share anonymous near-miss data with the community.',
              style: TextStyle(color: ZapColors.textSecondary, fontSize: 12),
            ),
          )
        else
          ..._kMockContributions.map((c) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: ZapColors.bgCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ZapColors.border),
              ),
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _kAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.place_rounded, color: _kAccent),
                ),
                title: Text(
                  c.areaLabel,
                  style: const TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                subtitle: Text(
                  '${c.type} · ${c.daysAgo} days ago · tile ${c.gridCol},${c.gridRow} · '
                  '${c.anonymizedHash}',
                  style: const TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.map_rounded, color: _kAccent),
                  onPressed: () {
                    ref.read(_d270SelectedIdProvider.notifier).state = c.id;
                    ref.read(_d270TabProvider.notifier).state = 0;
                  },
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(ZapSpacing.sm),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: ZapColors.textMuted, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tab 2: Info ───────────────────────────────────────────────────────────────
class _InfoTab extends ConsumerWidget {
  const _InfoTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final optIn = ref.watch(_d270OptInProvider);

    final payload = {
      'endpoint': 'GET /api/v1/community/heatmap/contributions/',
      'opt_in': optIn,
      'consent_type': 'heatmap_contribution',
      'consent_screen': AppRoutes.privacySettings,
      'contribution_count': optIn ? _kMockContributions.length : 0,
      'anonymization': {
        'identity_stripped': true,
        'location_precision': '~500m grid tile',
        'retention_days': 90,
      },
      'contributions': optIn
          ? _kMockContributions
              .map(
                (c) => {
                  'id': c.id,
                  'type': c.type,
                  'tile': '${c.gridCol},${c.gridRow}',
                  'hash': c.anonymizedHash,
                  'days_ago': c.daysAgo,
                },
              )
              .toList()
          : [],
    };

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _PolicyRow(
          icon: Icons.map_rounded,
          title: 'Community heatmap',
          subtitle:
              'Aggregated anonymous near-miss density on a city grid · helps users '
              'avoid high-risk areas · no names or exact addresses stored.',
        ),
        const _PolicyRow(
          icon: Icons.volunteer_activism_rounded,
          title: 'Your contributions',
          subtitle:
              'Near-miss reports you opted to share · linked from consent gate '
              '(Day 157 Privacy Settings) · toggle mirrors heatmap_contribution flag.',
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
              const SnackBar(content: Text('Heatmap contributions spec copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy contributions spec'),
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
              label: const Text('Day 157 Privacy Settings'),
              onPressed: () => context.push(AppRoutes.privacySettings),
            ),
            ActionChip(
              label: const Text('Day 155 Consent Management'),
              onPressed: () => context.push(AppRoutes.consentManagement),
            ),
            ActionChip(
              label: const Text('Day 269 Cultural Adaptation'),
              onPressed: () => context.push(AppRoutes.culturalAdaptation),
            ),
          ],
        ),
      ],
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
