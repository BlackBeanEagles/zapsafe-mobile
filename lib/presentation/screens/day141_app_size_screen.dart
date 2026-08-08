/// Day 141 — Audit App Size
///
/// First day of the Days 141-150 AWS Migration & Performance phase.
/// Before switching to AWS the team runs a full app-size audit:
///   1. Build release APK and measure total size (target < 50 MB)
///   2. Run `flutter build apk --analyze-size` to get per-package breakdown
///   3. Identify the top 5 largest components
///   4. Produce an optimisation plan for Days 142-144
///
/// Context: the beta app (v0.5-beta-final) currently ships at ~45 MB.
/// The target for production is < 30 MB so the app sits well within
/// Play Store / App Store instant-download thresholds.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _buildStateProvider  = StateProvider<_BuildState>((ref) => _BuildState.idle);
final _activeTabProvider   = StateProvider<int>((ref) => 0);
final _planItemsProvider   = StateProvider<List<bool>>(
  (ref) => List.filled(_kPlanItems.length, false),
);

enum _BuildState { idle, building, analyzing, done }

// ── Data ───────────────────────────────────────────────────────────────────────
class _SizeComponent {
  final String name;
  final double sizeMb;
  final Color  color;
  final String description;
  final String optimisationDay;
  final bool   canOptimise;
  const _SizeComponent({
    required this.name,
    required this.sizeMb,
    required this.color,
    required this.description,
    required this.optimisationDay,
    required this.canOptimise,
  });
}

const _kComponents = [
  _SizeComponent(
    name: 'ML Models (TFLite)',
    sizeMb: 17.4,
    color: Color(0xFFEF4444),
    description: 'Scream (4.2 MB) + Motion (3.8 MB) + Scene (3.1 MB) + '
        'Vocal Stress ×2 (4.9 MB) + NLP (2.4 MB) — stored as raw assets',
    optimisationDay: 'Day 142',
    canOptimise: true,
  ),
  _SizeComponent(
    name: 'Translation JSON (i18n)',
    sizeMb: 8.6,
    color: Color(0xFFF97316),
    description: '15 language packs × ~560 KB each. '
        'All loaded into memory even when user only uses one language.',
    optimisationDay: 'Day 144',
    canOptimise: true,
  ),
  _SizeComponent(
    name: 'Flutter framework',
    sizeMb: 7.8,
    color: Color(0xFF9CA3AF),
    description: 'Dart VM + Flutter engine. Cannot be reduced — '
        'part of the Flutter SDK. Stays at ~8 MB in all Flutter apps.',
    optimisationDay: '—',
    canOptimise: false,
  ),
  _SizeComponent(
    name: 'Image assets',
    sizeMb: 5.2,
    color: Color(0xFFF59E0B),
    description: 'Icons, illustrations, onboarding graphics, map tiles. '
        'Mix of PNG and SVG — some PNGs are oversized for their display size.',
    optimisationDay: 'Day 144',
    canOptimise: true,
  ),
  _SizeComponent(
    name: 'Dart compiled code',
    sizeMb: 4.1,
    color: Color(0xFF8B5CF6),
    description: '140 screens + providers + services compiled to '
        'native ARM64. Minimal reduction possible without removing features.',
    optimisationDay: '—',
    canOptimise: false,
  ),
  _SizeComponent(
    name: 'Font files',
    sizeMb: 1.4,
    color: Color(0xFF3B82F6),
    description: 'ClashDisplay (4 weights) + Syne (3 weights) + '
        'IBM Plex Mono (2 weights) = 9 font files.',
    optimisationDay: 'Day 144',
    canOptimise: true,
  ),
  _SizeComponent(
    name: 'Resources & strings',
    sizeMb: 0.5,
    color: Color(0xFF10B981),
    description: 'AndroidManifest, layouts, colour resources. '
        'Already minimal — nothing to optimise here.',
    optimisationDay: '—',
    canOptimise: false,
  ),
];

const _kPlanItems = [
  // Day 142
  'Day 142: Quantise ML models INT8 → ~40% size reduction (17 MB → 10 MB)',
  'Day 142: Enable NNAPI (Android) + CoreML (iOS) delegation',
  'Day 142: Validate model accuracy after compression (must be ≥ 85% recall)',
  // Day 143
  'Day 143: Audit lazy-loading — confirm non-critical screens deferred',
  'Day 143: Remove any remaining eager imports in app_router.dart',
  // Day 144
  'Day 144: Convert all PNG assets to WebP (50% size reduction)',
  'Day 144: Remove unused font weights (keep 2 per family)',
  'Day 144: Lazy-load i18n JSON — load only active locale on startup',
  'Day 144: Compress oversized images (> 500 KB) to actual display size',
];

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day141AppSizeScreen extends ConsumerWidget {
  const Day141AppSizeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buildState = ref.watch(_buildStateProvider);
    final tab        = ref.watch(_activeTabProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Day 141 · App Size Audit'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Hero(),
            const SizedBox(height: ZapSpacing.xl),

            // Build panel
            const _SectionLabel('STEP 1  ·  BUILD & MEASURE'),
            const SizedBox(height: ZapSpacing.md),
            _BuildPanel(state: buildState),
            const SizedBox(height: ZapSpacing.xl),

            // Only show analysis after build
            if (buildState == _BuildState.done) ...[
              // Tab selector
              const _SectionLabel('STEP 2  ·  ANALYSE'),
              const SizedBox(height: ZapSpacing.md),
              _TabBar(active: tab,
                  onSelect: (t) =>
                      ref.read(_activeTabProvider.notifier).state = t),
              const SizedBox(height: ZapSpacing.xl),

              if (tab == 0) const _BreakdownTab(),
              if (tab == 1) const _ComponentsTab(),
              if (tab == 2) _PlanTab(items: ref.watch(_planItemsProvider)),
            ],
            const SizedBox(height: ZapSpacing.huge),
          ],
        ),
      ),
    );
  }
}

// ── Hero ───────────────────────────────────────────────────────────────────────
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D1520), Color(0xFF070C12), Color(0xFF0A0A0A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _badge('⚡  DAY 141', const Color(0xFF3B82F6)),
            const SizedBox(width: ZapSpacing.sm),
            _badge('AWS Phase · Day 1/10', const Color(0xFF9CA3AF)),
          ]),
          const SizedBox(height: ZapSpacing.md),
          const Text(
            'App Size\nAudit',
            style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                height: 1.2),
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'Beta app ships at ~45 MB. Production target is < 30 MB. '
            'Run analyze-size to find the biggest offenders, '
            'then plan Days 142-144 optimisations.',
            style: TextStyle(
                color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: ZapSpacing.md),
          const Row(children: [
            _HStat('45 MB',  'Current size',  Color(0xFFEF4444)),
            _HStat('< 30 MB','Target',        Color(0xFF10B981)),
            _HStat('−33%',   'Required cut',  Color(0xFFF59E0B)),
            _HStat('D142-44','Fix days',      Color(0xFF8B5CF6)),
          ]),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
      );
}

class _HStat extends StatelessWidget {
  final String value, label;
  final Color  color;
  const _HStat(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 14, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center),
          Text(label,
              style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 9),
              textAlign: TextAlign.center),
        ]),
      );
}

// ── Section label ──────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) => Text(label,
      style: const TextStyle(
          color: Color(0xFF6B7280),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5));
}

// ── Build Panel ────────────────────────────────────────────────────────────────
class _BuildPanel extends ConsumerWidget {
  final _BuildState state;
  const _BuildPanel({required this.state});

  static const _steps = [
    (Color(0xFF3B82F6), 'flutter build apk --release…'),
    (Color(0xFF8B5CF6), 'flutter build apk --analyze-size…'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color: state == _BuildState.done
            ? const Color(0xFF10B981).withOpacity(0.07)
            : const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(
          color: state == _BuildState.done
              ? const Color(0xFF10B981).withOpacity(0.4)
              : const Color(0xFF2A2A2A),
        ),
      ),
      child: Column(children: [
        _codeNote('terminal',
            '# Build release APK\n'
            'flutter build apk --release\n'
            '\n'
            '# Analyse size breakdown\n'
            'flutter build apk --analyze-size\n'
            '# → Outputs: build/flutter_size_analysis/\n'
            '#   Open in https://devtools.flutter.dev/'),
        const SizedBox(height: ZapSpacing.md),

        if (state == _BuildState.idle)
          _actionButton(
            label: 'Run size analysis',
            icon: Icons.analytics_rounded,
            color: const Color(0xFF3B82F6),
            onTap: () async {
              ref.read(_buildStateProvider.notifier).state = _BuildState.building;
              await Future.delayed(const Duration(milliseconds: 900));
              if (!context.mounted) return;
              ref.read(_buildStateProvider.notifier).state = _BuildState.analyzing;
              await Future.delayed(const Duration(milliseconds: 1100));
              if (!context.mounted) return;
              ref.read(_buildStateProvider.notifier).state = _BuildState.done;
            },
          )
        else if (state == _BuildState.done) ...[
          // Result summary
          Row(children: [
            _resultBox('44.9 MB', 'APK size',        const Color(0xFFEF4444)),
            const SizedBox(width: ZapSpacing.sm),
            _resultBox('7',       'Components found', const Color(0xFFF59E0B)),
            const SizedBox(width: ZapSpacing.sm),
            _resultBox('−15 MB',  'Optimisable',      const Color(0xFF10B981)),
          ]),
          const SizedBox(height: ZapSpacing.md),
          _statusChip(Icons.check_circle_rounded, const Color(0xFF10B981),
              'Analysis complete — scroll down to inspect results'),
        ] else
          ...List.generate(2, (i) {
            final idx     = state == _BuildState.building ? 0 : 1;
            final isDone  = i < idx;
            final isActive= i == idx;
            return Padding(
              padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
              child: Row(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    color: isDone
                        ? const Color(0xFF10B981).withOpacity(0.15)
                        : isActive
                            ? _steps[i].$1.withOpacity(0.15)
                            : const Color(0xFF111111),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDone
                          ? const Color(0xFF10B981).withOpacity(0.5)
                          : isActive
                              ? _steps[i].$1.withOpacity(0.6)
                              : const Color(0xFF2A2A2A),
                    ),
                  ),
                  child: isDone
                      ? const Icon(Icons.check_rounded,
                          color: Color(0xFF10B981), size: 14)
                      : isActive
                          ? Padding(
                              padding: const EdgeInsets.all(5),
                              child: CircularProgressIndicator(
                                  color: _steps[i].$1, strokeWidth: 2))
                          : null,
                ),
                const SizedBox(width: ZapSpacing.md),
                Text(_steps[i].$2,
                    style: TextStyle(
                        color: isDone
                            ? const Color(0xFF6B7280)
                            : isActive
                                ? Colors.white
                                : const Color(0xFF4B5563),
                        fontSize: 13,
                        fontWeight: isActive
                            ? FontWeight.w600
                            : FontWeight.w400)),
              ]),
            );
          }),
      ]),
    );
  }

  Widget _resultBox(String value, String label, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: ZapSpacing.sm),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(children: [
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 18, fontWeight: FontWeight.w900)),
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF9CA3AF), fontSize: 9),
                textAlign: TextAlign.center),
          ]),
        ),
      );
}

// ── Tab bar ────────────────────────────────────────────────────────────────────
class _TabBar extends StatelessWidget {
  final int active;
  final ValueChanged<int> onSelect;
  const _TabBar({required this.active, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.pie_chart_rounded,   Color(0xFF3B82F6), 'Breakdown'),
      (Icons.view_list_rounded,   Color(0xFFF97316), 'Components'),
      (Icons.event_note_rounded,  Color(0xFF10B981), 'Plan'),
    ];
    return Row(
      children: List.generate(3, (i) {
        final (icon, color, label) = items[i];
        final isActive = i == active;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: EdgeInsets.only(right: i < 2 ? ZapSpacing.sm : 0),
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: isActive
                    ? color.withOpacity(0.12)
                    : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                  color: isActive ? color.withOpacity(0.5) : const Color(0xFF2A2A2A),
                  width: isActive ? 2 : 1,
                ),
              ),
              child: Column(children: [
                Icon(icon,
                    color: isActive ? color : const Color(0xFF6B7280),
                    size: 18),
                const SizedBox(height: ZapSpacing.xs),
                Text(label,
                    style: TextStyle(
                        color: isActive ? color : const Color(0xFF6B7280),
                        fontSize: 10,
                        fontWeight: isActive
                            ? FontWeight.w700
                            : FontWeight.w400)),
              ]),
            ),
          ),
        );
      }),
    );
  }
}

// ── Breakdown Tab ──────────────────────────────────────────────────────────────
class _BreakdownTab extends StatelessWidget {
  const _BreakdownTab();

  @override
  Widget build(BuildContext context) {
    final total = _kComponents.fold(0.0, (s, c) => s + c.sizeMb);
    final optimisable = _kComponents
        .where((c) => c.canOptimise)
        .fold(0.0, (s, c) => s + c.sizeMb);
    final fixed = total - optimisable;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Total gauge
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Column(children: [
            Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total APK size',
                        style: TextStyle(
                            color: Color(0xFF9CA3AF), fontSize: 11)),
                    Text('${total.toStringAsFixed(1)} MB',
                        style: const TextStyle(
                            color: Color(0xFFEF4444),
                            fontSize: 32,
                            fontWeight: FontWeight.w900)),
                    const Text('Target: < 30 MB for production',
                        style: TextStyle(
                            color: Color(0xFF6B7280), fontSize: 11)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _splitBadge('${optimisable.toStringAsFixed(1)} MB',
                      'Optimisable', const Color(0xFF10B981)),
                  const SizedBox(height: ZapSpacing.xs),
                  _splitBadge('${fixed.toStringAsFixed(1)} MB',
                      'Fixed (SDK)', const Color(0xFF4B5563)),
                ],
              ),
            ]),
            const SizedBox(height: ZapSpacing.md),
            // Size bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Row(
                children: _kComponents.map((c) {
                  return Expanded(
                    flex: (c.sizeMb * 10).round(),
                    child: Container(
                      height: 18,
                      color: c.color.withOpacity(c.canOptimise ? 0.75 : 0.35),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: ZapSpacing.sm),
            // Legend row
            Wrap(
              spacing: ZapSpacing.sm,
              runSpacing: 4,
              children: _kComponents.map((c) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                              color: c.color.withOpacity(
                                  c.canOptimise ? 0.75 : 0.35),
                              borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 3),
                      Text(
                        '${c.name.split(' ').first} ${c.sizeMb.toStringAsFixed(1)}',
                        style: const TextStyle(
                            color: Color(0xFF6B7280), fontSize: 9),
                      ),
                    ],
                  )).toList(),
            ),
          ]),
        ),
        const SizedBox(height: ZapSpacing.lg),

        // After optimisation projection
        const _SectionLabel('PROJECTED SIZE AFTER DAYS 142-144'),
        const SizedBox(height: ZapSpacing.md),
        _ProjectionCard(total: total),
      ],
    );
  }

  Widget _splitBadge(String value, String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w800)),
          Text(label,
              style: TextStyle(color: color.withOpacity(0.7), fontSize: 9)),
        ]),
      );
}

class _ProjectionCard extends StatelessWidget {
  final double total;
  const _ProjectionCard({required this.total});

  @override
  Widget build(BuildContext context) {
    // Projected savings
    const mlSaved    = 7.0;  // Day 142 quantise
    const imgSaved   = 2.6;  // Day 144 WebP
    const fontSaved  = 0.5;  // Day 144 remove weights
    const i18nSaved  = 3.0;  // Day 144 lazy-load
    const totalSaved = mlSaved + imgSaved + fontSaved + i18nSaved;
    final projected  = total - totalSaved;

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: projected < 30
            ? const Color(0xFF10B981).withOpacity(0.07)
            : const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(
          color: projected < 30
              ? const Color(0xFF10B981).withOpacity(0.35)
              : const Color(0xFF2A2A2A),
        ),
      ),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Projected size',
                    style: TextStyle(
                        color: Color(0xFF9CA3AF), fontSize: 11)),
                Text('${projected.toStringAsFixed(1)} MB',
                    style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 28,
                        fontWeight: FontWeight.w900)),
                Text(
                  projected < 30
                      ? '✅ Under 30 MB target'
                      : '⚠️ Still above 30 MB',
                  style: TextStyle(
                      color: projected < 30
                          ? const Color(0xFF10B981)
                          : const Color(0xFFF59E0B),
                      fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _savingRow('ML models (D142)',    mlSaved,   const Color(0xFFEF4444)),
              _savingRow('Images (D144)',       imgSaved,  const Color(0xFFF59E0B)),
              _savingRow('i18n lazy (D144)',    i18nSaved, const Color(0xFFF97316)),
              _savingRow('Fonts (D144)',        fontSaved, const Color(0xFF3B82F6)),
              const Divider(height: ZapSpacing.md, color: Color(0xFF2A2A2A)),
              _savingRow('Total saved', totalSaved, const Color(0xFF10B981)),
            ],
          ),
        ]),
      ]),
    );
  }

  Widget _savingRow(String label, double mb, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Row(children: [
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF9CA3AF), fontSize: 10)),
          const SizedBox(width: 6),
          Text('−${mb.toStringAsFixed(1)} MB',
              style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w700)),
        ]),
      );
}

// ── Components Tab ─────────────────────────────────────────────────────────────
class _ComponentsTab extends StatefulWidget {
  const _ComponentsTab();

  @override
  State<_ComponentsTab> createState() => _ComponentsTabState();
}

class _ComponentsTabState extends State<_ComponentsTab> {
  int? _expanded;

  @override
  Widget build(BuildContext context) {
    final total = _kComponents.fold(0.0, (s, c) => s + c.sizeMb);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(
          icon: Icons.view_list_rounded,
          color: const Color(0xFFF97316),
          text: 'Per-component breakdown from '
              '`flutter build apk --analyze-size`. '
              'Green = cannot optimise (SDK/runtime). '
              'Red/orange = optimisable in Days 142-144.',
        ),
        const SizedBox(height: ZapSpacing.lg),
        ..._kComponents.asMap().entries.map((e) {
          final i    = e.key;
          final comp = e.value;
          final frac = comp.sizeMb / total;
          final isOpen = _expanded == i;

          return GestureDetector(
            onTap: () => setState(
                () => _expanded = isOpen ? null : i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
              decoration: BoxDecoration(
                color: isOpen
                    ? comp.color.withOpacity(0.07)
                    : const Color(0xFF1A1A1A),
                borderRadius:
                    BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                  color: isOpen
                      ? comp.color.withOpacity(0.4)
                      : const Color(0xFF2A2A2A),
                ),
              ),
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.all(ZapSpacing.md),
                  child: Row(children: [
                    // Size ring hint
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: comp.color.withOpacity(0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: comp.color.withOpacity(0.35),
                            width: 2),
                      ),
                      child: Center(
                        child: Text(
                          comp.sizeMb.toStringAsFixed(1),
                          style: TextStyle(
                              color: comp.color,
                              fontSize: 11,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(width: ZapSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(comp.name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: ZapSpacing.xs),
                          // Size bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: frac,
                              backgroundColor: const Color(0xFF2A2A2A),
                              valueColor: AlwaysStoppedAnimation(
                                  comp.color.withOpacity(0.7)),
                              minHeight: 5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text('${(frac * 100).round()}% of total',
                              style: const TextStyle(
                                  color: Color(0xFF6B7280), fontSize: 9)),
                        ],
                      ),
                    ),
                    const SizedBox(width: ZapSpacing.sm),
                    // Can optimise badge
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: comp.canOptimise
                              ? const Color(0xFFEF4444).withOpacity(0.12)
                              : const Color(0xFF10B981).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          comp.canOptimise ? 'Optimise' : 'Fixed',
                          style: TextStyle(
                            color: comp.canOptimise
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF10B981),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (comp.canOptimise) ...[
                        const SizedBox(height: 3),
                        Text(comp.optimisationDay,
                            style: TextStyle(
                                color: comp.color,
                                fontSize: 9,
                                fontWeight: FontWeight.w600)),
                      ],
                    ]),
                    const SizedBox(width: ZapSpacing.sm),
                    Icon(
                      isOpen
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: const Color(0xFF4B5563), size: 16),
                  ]),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  child: isOpen
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(
                              ZapSpacing.md, 0,
                              ZapSpacing.md, ZapSpacing.md),
                          child: Column(children: [
                            const Divider(height: ZapSpacing.md,
                                color: Color(0xFF2A2A2A)),
                            Container(
                              padding: const EdgeInsets.all(ZapSpacing.sm),
                              decoration: BoxDecoration(
                                color: comp.color.withOpacity(0.07),
                                borderRadius: BorderRadius.circular(
                                    ZapSpacing.radiusSmall),
                                border: Border.all(
                                    color: comp.color.withOpacity(0.2)),
                              ),
                              child: Text(comp.description,
                                  style: const TextStyle(
                                      color: Color(0xFFD1D5DB),
                                      fontSize: 12,
                                      height: 1.5)),
                            ),
                          ]),
                        )
                      : const SizedBox.shrink(),
                ),
              ]),
            ),
          );
        }),
      ],
    );
  }
}

// ── Plan Tab ───────────────────────────────────────────────────────────────────
class _PlanTab extends ConsumerWidget {
  final List<bool> items;
  const _PlanTab({required this.items});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doneCount = items.where((i) => i).length;
    final allDone   = doneCount == items.length;

    // Group by day
    final groups = {
      'Day 142 · ML Model Compression':    [0, 1, 2],
      'Day 143 · Lazy Loading Audit':      [3, 4],
      'Day 144 · Image & Asset Optimisation': [5, 6, 7, 8],
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: allDone
                ? const Color(0xFF10B981).withOpacity(0.07)
                : const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(
              color: allDone
                  ? const Color(0xFF10B981).withOpacity(0.35)
                  : const Color(0xFF2A2A2A),
            ),
          ),
          child: Column(children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$doneCount / ${items.length} items planned',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                Text(
                  allDone
                      ? '✅ Plan ready for Day 142'
                      : 'Tap to confirm each item',
                  style: TextStyle(
                      color: allDone
                          ? const Color(0xFF10B981)
                          : const Color(0xFF6B7280),
                      fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: ZapSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: doneCount / items.length,
                backgroundColor: const Color(0xFF2A2A2A),
                valueColor: AlwaysStoppedAnimation(
                  allDone ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
                ),
                minHeight: 6,
              ),
            ),
          ]),
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Groups
        ...groups.entries.map((entry) {
          final title   = entry.key;
          final indices = entry.value;
          final day     = title.split(' ·').first;
          final color   = day == 'Day 142'
              ? const Color(0xFFEF4444)
              : day == 'Day 143'
                  ? const Color(0xFF8B5CF6)
                  : const Color(0xFFF59E0B);
          final doneInGroup =
              indices.where((i) => i < items.length && items[i]).length;

          return Padding(
            padding: const EdgeInsets.only(bottom: ZapSpacing.md),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: ZapSpacing.md, vertical: 10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(ZapSpacing.radiusSmall - 1)),
                  ),
                  child: Row(children: [
                    Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                            color: color, shape: BoxShape.circle)),
                    const SizedBox(width: ZapSpacing.sm),
                    Text(title,
                        style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text('$doneInGroup/${indices.length}',
                        style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ]),
                ),
                ...indices.asMap().entries.map((e) {
                  final ii     = e.key;
                  final idx    = e.value;
                  final done   = idx < items.length && items[idx];
                  final isLast = ii == indices.length - 1;

                  return GestureDetector(
                    onTap: () {
                      final updated = List<bool>.from(
                          ref.read(_planItemsProvider));
                      if (idx < updated.length) {
                        updated[idx] = !updated[idx];
                        ref.read(_planItemsProvider.notifier).state = updated;
                      }
                    },
                    child: Column(children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: ZapSpacing.md, vertical: 12),
                        child: Row(children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 22, height: 22,
                            decoration: BoxDecoration(
                              color: done
                                  ? const Color(0xFF10B981).withOpacity(0.15)
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: done
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFF4B5563)),
                            ),
                            child: done
                                ? const Icon(Icons.check_rounded,
                                    color: Color(0xFF10B981), size: 14)
                                : null,
                          ),
                          const SizedBox(width: ZapSpacing.md),
                          Expanded(
                            child: Text(
                              idx < _kPlanItems.length
                                  ? _kPlanItems[idx]
                                  : '',
                              style: TextStyle(
                                color: done
                                    ? const Color(0xFF6B7280)
                                    : Colors.white,
                                fontSize: 12,
                                decoration: done
                                    ? TextDecoration.lineThrough
                                    : null,
                                decorationColor: const Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        ]),
                      ),
                      if (!isLast)
                        const Divider(height: 1, color: Color(0xFF2A2A2A)),
                    ]),
                  );
                }),
              ]),
            ),
          );
        }),

        // Next
        const SizedBox(height: ZapSpacing.md),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withOpacity(0.07),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(
                color: const Color(0xFF3B82F6).withOpacity(0.3)),
          ),
          child: const Row(children: [
            Icon(Icons.arrow_forward_rounded,
                color: Color(0xFF3B82F6), size: 16),
            SizedBox(width: ZapSpacing.sm),
            Expanded(
              child: Text(
                'Day 142: Start with ML model compression '
                '(biggest single win: −7 MB). '
                'Then images → fonts → i18n lazy-load.',
                style: TextStyle(
                    color: Color(0xFFD1D5DB), fontSize: 12, height: 1.5),
              ),
            ),
          ]),
        ),
      ],
    );
  }
}

// ── Shared helpers ─────────────────────────────────────────────────────────────
Widget _actionButton({
  required String label,
  required IconData icon,
  required Color color,
  required VoidCallback onTap,
}) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [color, color.withOpacity(0.8)]),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 14,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: ZapSpacing.sm),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
        ]),
      ),
    );

Widget _statusChip(IconData icon, Color color, String label,
        {bool loading = false}) =>
    Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        loading
            ? SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(color: color, strokeWidth: 2))
            : Icon(icon, color: color, size: 16),
        const SizedBox(width: ZapSpacing.sm),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    );

Widget _infoBox({
  required IconData icon,
  required Color color,
  required String text,
}) =>
    Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: ZapSpacing.sm),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6)),
        ),
      ]),
    );

Widget _codeNote(String filename, String code) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: const Color(0xFF1C2128),
              borderRadius: BorderRadius.circular(4)),
          child: Text(filename,
              style: const TextStyle(
                  color: Color(0xFF79C0FF),
                  fontSize: 10,
                  fontFamily: 'monospace')),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Text(code,
            style: const TextStyle(
                color: Color(0xFFE6EDF3),
                fontSize: 11,
                fontFamily: 'monospace',
                height: 1.6)),
      ]),
    );
