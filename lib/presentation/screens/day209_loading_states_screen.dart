/// Day 209 — Loading States Sweep
///
/// Section A (Days 201-220): standardized shimmer skeleton loaders via
/// reusable [ZapSkeleton] patterns for async data screens.
///
/// Tag: 🟣 POLISH — ships [zap_skeleton.dart] widget library.
///
/// Route: [AppRoutes.loadingStates] → `/loading-states`
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../widgets/zap_skeleton.dart';

// ── Layout catalog ────────────────────────────────────────────────────────────
class _SkeletonLayout {
  final String id;
  final String title;
  final String subtitle;
  final String adoptScreen;
  final String route;
  final Widget skeleton;
  final Widget loaded;

  const _SkeletonLayout({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.adoptScreen,
    required this.route,
    required this.skeleton,
    required this.loaded,
  });
}

Widget _mockLoadedCard(String title, String subtitle, Color accent) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(ZapSpacing.md),
    decoration: BoxDecoration(
      color: accent.withOpacity(0.1),
      borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
      border: Border.all(color: accent.withOpacity(0.35)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: accent,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: ZapSpacing.xs),
        Text(
          subtitle,
          style: const TextStyle(color: ZapColors.textSecondary, fontSize: 12),
        ),
      ],
    ),
  );
}

final _kLayouts = [
  _SkeletonLayout(
    id: 'list_tile',
    title: 'List tile',
    subtitle: 'ZapSkeletonListTile',
    adoptScreen: 'Day 68 Audit Log · Day 82 Vault',
    route: '/audit-log-v2 · /evidence-vault',
    skeleton: const ZapSkeletonList(),
    loaded: _mockLoadedCard(
      'Audit entry loaded',
      'SOS event · 2 min ago · Security',
      ZapColors.info,
    ),
  ),
  _SkeletonLayout(
    id: 'card',
    title: 'Card',
    subtitle: 'ZapSkeletonCard',
    adoptScreen: 'Day 81 Settings · Day 85 Thresholds',
    route: '/settings-v2',
    skeleton: const ZapSkeletonCard(height: 100),
    loaded: _mockLoadedCard(
      'Settings card loaded',
      'Notification preferences · 4 toggles',
      ZapColors.safe,
    ),
  ),
  _SkeletonLayout(
    id: 'chart',
    title: 'Chart / score ring',
    subtitle: 'ZapSkeletonChart',
    adoptScreen: 'Day 59 Protection Score',
    route: '/protection-score',
    skeleton: const ZapSkeletonChart(ring: true),
    loaded: _mockLoadedCard(
      'Score loaded',
      '78 / 100 · Good · updated 2 min ago',
      ZapColors.warning,
    ),
  ),
  _SkeletonLayout(
    id: 'contact',
    title: 'Contact row',
    subtitle: 'ZapSkeletonContactRow',
    adoptScreen: 'Day 83 Contacts v2',
    route: '/contacts-v2',
    skeleton: const Column(
      children: [
        ZapSkeletonContactRow(),
        ZapSkeletonContactRow(),
        ZapSkeletonContactRow(),
      ],
    ),
    loaded: _mockLoadedCard(
      'Contacts loaded',
      'Priya Sharma · Tier 1 · Verified',
      ZapColors.danger,
    ),
  ),
  _SkeletonLayout(
    id: 'dashboard',
    title: 'Dashboard',
    subtitle: 'ZapSkeletonDashboard',
    adoptScreen: 'Dashboard placeholder · Day 204 mode card',
    route: '/dashboard',
    skeleton: const ZapSkeletonDashboard(),
    loaded: _mockLoadedCard(
      'Dashboard loaded',
      'MONITORING · Protection 78 · SOS ready',
      ZapColors.safe,
    ),
  ),
  _SkeletonLayout(
    id: 'messages',
    title: 'Message list',
    subtitle: 'ZapSkeletonMessageList',
    adoptScreen: 'Day 207 Live Chat',
    route: '/chat-offline-queue',
    skeleton: const ZapSkeletonMessageList(count: 5),
    loaded: _mockLoadedCard(
      'Chat loaded',
      '3 messages · counselor online',
      const Color(0xFF8B5CF6),
    ),
  ),
];

// ── Providers ─────────────────────────────────────────────────────────────────
final _d209TabProvider = StateProvider<int>((ref) => 0);
final _d209LayoutIndexProvider = StateProvider<int>((ref) => 0);
final _d209LoadingProvider = StateProvider<bool>((ref) => true);
final _d209SimulatingProvider = StateProvider<bool>((ref) => false);

const _kTabs = ['Gallery', 'Simulate', 'Adoption Spec'];

// ── Screen ────────────────────────────────────────────────────────────────────
class Day209LoadingStatesScreen extends ConsumerWidget {
  const Day209LoadingStatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d209TabProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 209 · Loading States'),
      ),
      body: Column(
        children: [
          _TabBar(
            tab: tab,
            onSelect: (i) => ref.read(_d209TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (tab) {
              0 => const _GalleryTab(),
              1 => const _SimulateTab(),
              _ => const _AdoptionSpecTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Gallery ────────────────────────────────────────────────────────────
class _GalleryTab extends ConsumerWidget {
  const _GalleryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(_d209LayoutIndexProvider);
    final layout = _kLayouts[index];

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: ZapColors.warning.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: ZapColors.warning.withOpacity(0.35)),
          ),
          child: const Text(
            '🟣 POLISH · Section A Day 9/20 · 6 skeleton layouts',
            style: TextStyle(color: ZapColors.warning, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _kLayouts.length,
            separatorBuilder: (_, __) => const SizedBox(width: ZapSpacing.sm),
            itemBuilder: (context, i) {
              final l = _kLayouts[i];
              final selected = i == index;
              return Semantics(
                label: '${l.title} skeleton layout',
                button: true,
                selected: selected,
                child: FilterChip(
                  label: Text(l.title),
                  selected: selected,
                  onSelected: (_) =>
                      ref.read(_d209LayoutIndexProvider.notifier).state = i,
                  selectedColor: ZapColors.info.withOpacity(0.2),
                  checkmarkColor: ZapColors.info,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Text(
          layout.title,
          style: const TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        Text(
          layout.subtitle,
          style: const TextStyle(
            color: ZapColors.textSecondary,
            fontSize: 12,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.lg),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ZapColors.border),
          ),
          child: layout.skeleton,
        ),
        const SizedBox(height: ZapSpacing.md),
        Row(
          children: [
            Semantics(
              label: 'Previous layout',
              button: true,
              child: IconButton(
                onPressed: index > 0
                    ? () => ref.read(_d209LayoutIndexProvider.notifier).state =
                        index - 1
                    : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
            ),
            Expanded(
              child: Text(
                '${index + 1} / ${_kLayouts.length}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: ZapColors.textMuted),
              ),
            ),
            Semantics(
              label: 'Next layout',
              button: true,
              child: IconButton(
                onPressed: index < _kLayouts.length - 1
                    ? () => ref.read(_d209LayoutIndexProvider.notifier).state =
                        index + 1
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Tab 1: Simulate ───────────────────────────────────────────────────────────
class _SimulateTab extends ConsumerWidget {
  const _SimulateTab();

  Future<void> _simulateLoad(WidgetRef ref) async {
    ref.read(_d209SimulatingProvider.notifier).state = true;
    ref.read(_d209LoadingProvider.notifier).state = true;
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    ref.read(_d209LoadingProvider.notifier).state = false;
    ref.read(_d209SimulatingProvider.notifier).state = false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(_d209LayoutIndexProvider);
    final loading = ref.watch(_d209LoadingProvider);
    final simulating = ref.watch(_d209SimulatingProvider);
    final layout = _kLayouts[index];

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text(
          'Skeleton → loaded transition',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          'Mirrors Riverpod AsyncValue.loading → data pattern. '
          'Use skeleton instead of CircularProgressIndicator for layout-heavy screens.',
          style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: ZapSpacing.lg),
        DropdownButtonFormField<int>(
          value: index,
          decoration: InputDecoration(
            labelText: 'Layout',
            filled: true,
            fillColor: ZapColors.bgCard,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              borderSide: const BorderSide(color: ZapColors.border),
            ),
          ),
          dropdownColor: ZapColors.bgCard,
          style: const TextStyle(color: ZapColors.textPrimary),
          items: List.generate(
            _kLayouts.length,
            (i) => DropdownMenuItem(
              value: i,
              child: Text(_kLayouts[i].title),
            ),
          ),
          onChanged: (v) {
            if (v != null) {
              ref.read(_d209LayoutIndexProvider.notifier).state = v;
              ref.read(_d209LoadingProvider.notifier).state = true;
            }
          },
        ),
        const SizedBox(height: ZapSpacing.lg),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          child: Container(
            key: ValueKey('$index-$loading'),
            width: double.infinity,
            padding: const EdgeInsets.all(ZapSpacing.lg),
            decoration: BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ZapColors.border),
            ),
            child: loading ? layout.skeleton : layout.loaded,
          ),
        ),
        const SizedBox(height: ZapSpacing.xl),
        Semantics(
          label: 'Simulate data load',
          button: true,
          child: FilledButton.icon(
            onPressed: simulating ? null : () => _simulateLoad(ref),
            icon: simulating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.play_arrow_rounded, size: 20),
            label: Text(simulating ? 'Loading…' : 'Simulate 1.4s load'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 75),
              backgroundColor: ZapColors.info,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Semantics(
          label: 'Toggle loading state manually',
          button: true,
          child: OutlinedButton(
            onPressed: () =>
                ref.read(_d209LoadingProvider.notifier).state = !loading,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 75),
            ),
            child: Text(loading ? 'Show loaded' : 'Show skeleton'),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgSurface,
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: ZapColors.border),
          ),
          child: const Text(
            '// Riverpod pattern\n'
            'scoreAsync.when(\n'
            '  loading: () => const ZapSkeletonChart(),\n'
            '  error: (e, _) => ZapErrorState(onRetry: …),\n'
            '  data: (score) => ScoreHero(score: score),\n'
            ')',
            style: TextStyle(
              color: ZapColors.textSecondary,
              fontSize: 11,
              fontFamily: 'monospace',
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Tab 2: Adoption Spec ──────────────────────────────────────────────────────
class _AdoptionSpecTab extends StatelessWidget {
  const _AdoptionSpecTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text(
          'Screens to adopt ZapSkeleton',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          'Replace CircularProgressIndicator-only loading UIs on these '
          'data-heavy screens (Days 138/143/145 identified the gap).',
          style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: ZapSpacing.lg),
        ..._kLayouts.map(
          (l) => Container(
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(color: ZapColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.title,
                  style: const TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: ZapSpacing.xs),
                Text(
                  'Widget: ${l.subtitle}',
                  style: const TextStyle(
                    color: ZapColors.info,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: ZapSpacing.xs),
                Text(
                  'Adopt: ${l.adoptScreen}',
                  style: const TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                Text(
                  l.route,
                  style: const TextStyle(
                    color: ZapColors.textMuted,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Widget file: lib/presentation/widgets/zap_skeleton.dart\n'
          '• ZapSkeletonBone — base shimmer\n'
          '• ZapSkeletonListTile / List / Card / Chart\n'
          '• ZapSkeletonContactRow / Dashboard / MessageList',
          style: TextStyle(
            color: ZapColors.textSecondary,
            fontSize: 12,
            fontFamily: 'monospace',
            height: 1.5,
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Semantics(
          label: 'Copy widget import',
          button: true,
          child: OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(
                const ClipboardData(
                  text: "import '../widgets/zap_skeleton.dart';",
                ),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Import copied')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy widget import'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 75),
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.info.withOpacity(0.1),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: ZapColors.info.withOpacity(0.3)),
          ),
          child: const Text(
            'Tomorrow: Day 211 — Dark mode consistency audit.',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _TabBar extends StatelessWidget {
  final int tab;
  final ValueChanged<int> onSelect;

  const _TabBar({required this.tab, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ZapColors.bgCard,
      child: Row(
        children: List.generate(_kTabs.length, (i) {
          final selected = tab == i;
          return Expanded(
            child: Semantics(
              label: '${_kTabs[i]} tab',
              button: true,
              selected: selected,
              child: InkWell(
                onTap: () => onSelect(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: ZapSpacing.md),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color:
                            selected ? ZapColors.warning : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    _kTabs[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected
                          ? ZapColors.textPrimary
                          : ZapColors.textSecondary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 12,
                    ),
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
