/// Day 212 — Empty States Sweep
///
/// Section A (Days 201-220): standardized empty list UI via [ZapEmptyState] —
/// illustration area, helpful copy, primary CTA.
///
/// Tag: 🟣 POLISH — ships [zap_empty_state.dart] widget library.
///
/// Route: [AppRoutes.emptyStates] → `/empty-states`
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../widgets/zap_empty_state.dart';

// ── Gallery presets ───────────────────────────────────────────────────────────
class _EmptyVariant {
  final ZapEmptyKind kind;
  final String label;
  final String route;

  const _EmptyVariant({
    required this.kind,
    required this.label,
    required this.route,
  });
}

const _kVariants = [
  _EmptyVariant(
    kind: ZapEmptyKind.contacts,
    label: 'Contacts',
    route: '/contacts-v2',
  ),
  _EmptyVariant(
    kind: ZapEmptyKind.vault,
    label: 'Evidence vault',
    route: '/evidence-vault',
  ),
  _EmptyVariant(
    kind: ZapEmptyKind.notifications,
    label: 'Notifications',
    route: '/notification-history-v2',
  ),
  _EmptyVariant(
    kind: ZapEmptyKind.journey,
    label: 'Protection journey',
    route: '/onboarding/step5',
  ),
  _EmptyVariant(
    kind: ZapEmptyKind.chat,
    label: 'Live chat',
    route: '/chat-offline-queue',
  ),
];

// ── Providers ─────────────────────────────────────────────────────────────────
final _d212TabProvider = StateProvider<int>((ref) => 0);
final _d212VariantProvider = StateProvider<int>((ref) => 0);
final _d212CompactProvider = StateProvider<bool>((ref) => false);
final _d212ShowSecondaryProvider = StateProvider<bool>((ref) => false);
final _d212TapCountProvider = StateProvider<int>((ref) => 0);

const _kTabs = ['Live Preview', 'Gallery', 'Spec'];

// ── Screen ────────────────────────────────────────────────────────────────────
class Day212EmptyStatesScreen extends ConsumerWidget {
  const Day212EmptyStatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d212TabProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 212 · Empty States'),
      ),
      body: Column(
        children: [
          _TabBar(
            tab: tab,
            onSelect: (i) => ref.read(_d212TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (tab) {
              0 => const _LivePreviewTab(),
              1 => const _GalleryTab(),
              _ => const _SpecTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Live Preview ───────────────────────────────────────────────────────
class _LivePreviewTab extends ConsumerWidget {
  const _LivePreviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(_d212VariantProvider);
    final compact = ref.watch(_d212CompactProvider);
    final showSecondary = ref.watch(_d212ShowSecondaryProvider);
    final tapCount = ref.watch(_d212TapCountProvider);
    final variant = _kVariants[index];
    final accent = ZapEmptyMapper.accent(variant.kind);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF8B5CF6).withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: const Color(0xFF8B5CF6).withOpacity(0.35),
            ),
          ),
          child: const Text(
            '🟣 POLISH · Section A Day 12/20 · Illustration + copy + primary CTA',
            style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Row(
          children: [
            Icon(ZapEmptyMapper.icon(variant.kind), color: accent, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                variant.label,
                style: const TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
            Text(
              variant.route,
              style: const TextStyle(
                color: ZapColors.textMuted,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          constraints: BoxConstraints(minHeight: compact ? 220 : 340),
          width: double.infinity,
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ZapColors.border),
          ),
          child: ZapEmptyState.preset(
            kind: variant.kind,
            compact: compact,
            onPrimaryAction: () {
              ref.read(_d212TapCountProvider.notifier).state = tapCount + 1;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${ZapEmptyMapper.ctaLabel(variant.kind)} tapped '
                    '(${tapCount + 1} total) — would navigate to ${variant.route}',
                  ),
                ),
              );
            },
            secondaryLabel: showSecondary ? 'Clear filters' : null,
            onSecondaryAction: showSecondary
                ? () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Filters cleared (mock)')),
                    );
                  }
                : null,
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        SwitchListTile(
          value: compact,
          onChanged: (v) => ref.read(_d212CompactProvider.notifier).state = v,
          activeColor: ZapColors.info,
          title: const Text(
            'Compact mode',
            style: TextStyle(color: ZapColors.textPrimary),
          ),
          subtitle: const Text(
            'Smaller illustration for nested lists',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 12),
          ),
        ),
        SwitchListTile(
          value: showSecondary,
          onChanged: (v) =>
              ref.read(_d212ShowSecondaryProvider.notifier).state = v,
          activeColor: ZapColors.info,
          title: const Text(
            'Show secondary action',
            style: TextStyle(color: ZapColors.textPrimary),
          ),
          subtitle: const Text(
            'For filter-empty cases (e.g. Day 206 vault search)',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 12),
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mock list shell',
                style: TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: ZapSpacing.sm),
              ...List.generate(2, (i) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  height: 44,
                  decoration: BoxDecoration(
                    color: ZapColors.bgElevated,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: ZapColors.border),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'List row placeholder ${i + 1} (hidden when empty)',
                        style: const TextStyle(
                          color: ZapColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: ZapSpacing.sm),
              ZapEmptyInline(
                title: 'No items match your filters',
                actionLabel: showSecondary ? 'Clear filters' : null,
                onAction: showSecondary ? () {} : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Tab 1: Gallery ────────────────────────────────────────────────────────────
class _GalleryTab extends ConsumerWidget {
  const _GalleryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(_d212VariantProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text(
          '5 standard empty states',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          'ZapEmptyState.preset(kind: …) picks illustration, copy, and CTA.',
          style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: ZapSpacing.lg),
        ...List.generate(_kVariants.length, (i) {
          final v = _kVariants[i];
          final isSelected = selected == i;
          final accent = ZapEmptyMapper.accent(v.kind);
          return Container(
            margin: const EdgeInsets.only(bottom: ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? accent : ZapColors.border,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(ZapEmptyMapper.icon(v.kind), color: accent),
                  title: Text(
                    v.label,
                    style: const TextStyle(
                      color: ZapColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    ZapEmptyMapper.message(v.kind),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ZapColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check_circle_rounded, color: accent)
                      : null,
                  onTap: () =>
                      ref.read(_d212VariantProvider.notifier).state = i,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    ZapSpacing.md,
                    0,
                    ZapSpacing.md,
                    ZapSpacing.md,
                  ),
                  child: Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: ZapColors.bgSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: ZapColors.border),
                    ),
                    child: ZapEmptyState.preset(
                      kind: v.kind,
                      compact: true,
                      onPrimaryAction: () {
                        ref.read(_d212VariantProvider.notifier).state = i;
                        ref.read(_d212TabProvider.notifier).state = 0;
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: ZapSpacing.lg),
        Semantics(
          label: 'Copy ZapEmptyState.preset usage',
          button: true,
          child: FilledButton.icon(
            onPressed: () {
              Clipboard.setData(
                const ClipboardData(
                  text:
                      'if (items.isEmpty)\n'
                      '  ZapEmptyState.preset(\n'
                      '    kind: ZapEmptyKind.contacts,\n'
                      '    onPrimaryAction: () => context.push(AppRoutes.addContact),\n'
                      '    secondaryLabel: hasFilters ? \'Clear filters\' : null,\n'
                      '    onSecondaryAction: hasFilters ? clearFilters : null,\n'
                      '  )',
                ),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Empty state pattern copied')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy list-empty pattern'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 75),
              backgroundColor: ZapColors.bgElevated,
              foregroundColor: ZapColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Tab 2: Spec ───────────────────────────────────────────────────────────────
class _SpecTab extends StatelessWidget {
  const _SpecTab();

  @override
  Widget build(BuildContext context) {
    const rules = [
      ('Illustration', 'Rounded icon box + soft ring — not a blank list'),
      ('Copy', 'Title + 1–2 sentence helpful message (never "Error 404")'),
      ('Primary CTA', 'One clear action — "Add first contact", not "OK"'),
      ('Secondary', 'Optional for filter-empty — "Clear filters"'),
      ('Compact', 'Smaller footprint for nested scroll views'),
    ];

    const adopt = [
      ('Day 83 Contacts v2', '_EmptyContacts → ZapEmptyState.contacts'),
      ('Day 82 Evidence Vault', 'empty vault → ZapEmptyState.vault'),
      ('Day 88 Notification History', '_EmptyState → ZapEmptyState.notifications'),
      ('Day 45 Onboarding Step 5', 'no contacts card → ZapEmptyState.journey'),
      ('Day 207 Live Chat', 'empty thread → ZapEmptyState.chat'),
      ('Day 206 Vault Search', 'zero matches → ZapEmptyInline + Clear filters'),
      ('Day 95 Billing History', '_EmptyState → ZapEmptyState.preset or inline'),
    ];

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text(
          'Empty states sweep (Day 212 polish)',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Rules',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        ...rules.map(
          (r) => Container(
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ZapColors.border),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 100,
                  child: Text(
                    r.$1,
                    style: const TextStyle(
                      color: Color(0xFF8B5CF6),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    r.$2,
                    style: const TextStyle(
                      color: ZapColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Screens to adopt',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        ...adopt.map(
          (a) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.chevron_right_rounded,
                    size: 16, color: ZapColors.textMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        color: ZapColors.textSecondary,
                        fontSize: 12,
                      ),
                      children: [
                        TextSpan(
                          text: '${a.$1}\n',
                          style: const TextStyle(
                            color: ZapColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(text: a.$2),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Widget: lib/presentation/widgets/zap_empty_state.dart\n'
          '• ZapEmptyKind — contacts / vault / notifications / journey / chat\n'
          '• ZapEmptyMapper — title / message / ctaLabel / icon / accent\n'
          '• ZapEmptyState — illustration + copy + primary CTA\n'
          '• ZapEmptyInline — compact filter-empty strip',
          style: TextStyle(
            color: ZapColors.textSecondary,
            fontSize: 12,
            fontFamily: 'monospace',
            height: 1.5,
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.info.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.info.withOpacity(0.3)),
          ),
          child: const Text(
            'Tomorrow: Day 215 — Font scale 200% regression (textScaleFactor 1.0→2.0).',
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
                        color: selected
                            ? const Color(0xFF8B5CF6)
                            : Colors.transparent,
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
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
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
