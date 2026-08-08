/// Day 126 — Fix UI Bugs
///
/// Four UI bugs identified from beta tester feedback (Day 121 analysis):
///   Bug 1 — Low contrast colours failing WCAG AA (14 reports)
///   Bug 2 — Hindi/Tamil text overflows buttons (9 reports)
///   Bug 3 — Icons missing / wrong tint on Android API 29 (5 reports)
///   Bug 4 — Button styling inconsistent across screens (6 reports)
///
/// Each bug has: before/after visual preview, root cause, code fix,
/// and an interactive "Apply fix" button.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _activeBugProvider  = StateProvider<int>((ref) => 0);
final _appliedProvider    = StateProvider<List<bool>>(
  (ref) => List.filled(4, false),
);
final _previewLangProvider = StateProvider<_PreviewLang>((ref) => _PreviewLang.en);
final _contrastModeProvider = StateProvider<bool>((ref) => false);

enum _PreviewLang { en, hi, ta }

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day126UiBugsScreen extends ConsumerWidget {
  const Day126UiBugsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active  = ref.watch(_activeBugProvider);
    final applied = ref.watch(_appliedProvider);
    final allDone = applied.every((a) => a);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Day 126 · Fix UI Bugs'),
        elevation: 0,
        actions: [
          if (allDone)
            Padding(
              padding: const EdgeInsets.only(right: ZapSpacing.md),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                  ),
                  child: const Text('All fixed ✅',
                      style: TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Hero(),
            const SizedBox(height: ZapSpacing.xl),

            // Bug selector
            const _SectionLabel('SELECT BUG TO FIX'),
            const SizedBox(height: ZapSpacing.md),
            _BugSelector(active: active, applied: applied),
            const SizedBox(height: ZapSpacing.xl),

            // Bug detail
            if (active == 0) const _ContrastBug(),
            if (active == 1) const _TextOverflowBug(),
            if (active == 2) const _IconTintBug(),
            if (active == 3) const _ButtonStyleBug(),
            const SizedBox(height: ZapSpacing.xl),

            // Apply button
            _ApplyButton(index: active),
            const SizedBox(height: ZapSpacing.xl),

            // Summary
            const _SectionLabel('FIX PROGRESS'),
            const SizedBox(height: ZapSpacing.md),
            _FixSummary(applied: applied),
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
          colors: [Color(0xFF160A1E), Color(0xFF0B050F), Color(0xFF0A0A0A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _badge('⚡  BETA  ·  DAY 126', const Color(0xFF8B5CF6)),
            const SizedBox(width: ZapSpacing.sm),
            _badge('34 reports', const Color(0xFFF59E0B)),
          ]),
          const SizedBox(height: ZapSpacing.md),
          const Text('Fix UI Bugs',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            '4 visual bugs from beta feedback. No crashes — pure polish. '
            'Contrast, overflow, icons, buttons. '
            'Small fixes, big UX difference for 34 affected testers.',
            style: TextStyle(
                color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: ZapSpacing.md),
          const Row(children: [
            _HStat('4',    'UI bugs',          Color(0xFF8B5CF6)),
            _HStat('34',   'Reports',          Color(0xFFF59E0B)),
            _HStat('WCAG', 'AA target',        Color(0xFF3B82F6)),
            _HStat('P2',   'Priority',         Color(0xFF9CA3AF)),
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
                color: color, fontSize: 11, fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
      );
}

class _HStat extends StatelessWidget {
  final String value, label;
  final Color color;
  const _HStat(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 16, fontWeight: FontWeight.w800),
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

// ── Bug selector ───────────────────────────────────────────────────────────────
class _BugSelector extends ConsumerWidget {
  final int active;
  final List<bool> applied;
  const _BugSelector({required this.active, required this.applied});

  static const _data = [
    (Icons.contrast_rounded,       Color(0xFFEF4444), 'Bug 1',  'Contrast'),
    (Icons.text_fields_rounded,    Color(0xFFF97316), 'Bug 2',  'Overflow'),
    (Icons.image_not_supported_rounded, Color(0xFFF59E0B), 'Bug 3', 'Icons'),
    (Icons.crop_square_rounded,    Color(0xFF3B82F6), 'Bug 4',  'Buttons'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: List.generate(4, (i) {
        final (icon, color, label, sub) = _data[i];
        final isActive = i == active;
        final isDone   = applied[i];

        return Expanded(
          child: GestureDetector(
            onTap: () =>
                ref.read(_activeBugProvider.notifier).state = i,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: EdgeInsets.only(right: i < 3 ? ZapSpacing.sm : 0),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isActive
                    ? color.withOpacity(0.12)
                    : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                  color: isActive
                      ? color.withOpacity(0.5)
                      : const Color(0xFF2A2A2A),
                  width: isActive ? 2 : 1,
                ),
              ),
              child: Column(children: [
                Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: isDone
                        ? const Color(0xFF10B981).withOpacity(0.15)
                        : color.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isDone ? Icons.check_rounded : icon,
                    color: isDone ? const Color(0xFF10B981) : color,
                    size: 15,
                  ),
                ),
                const SizedBox(height: 5),
                Text(label,
                    style: TextStyle(
                        color: isActive ? color : const Color(0xFF9CA3AF),
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
                Text(sub,
                    style: const TextStyle(
                        color: Color(0xFF6B7280), fontSize: 9)),
                const SizedBox(height: 3),
                _pill(isDone ? 'Fixed' : 'Open',
                    isDone ? const Color(0xFF10B981) : const Color(0xFF4B5563)),
              ]),
            ),
          ),
        );
      }),
    );
  }

  Widget _pill(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 8, fontWeight: FontWeight.w700)),
      );
}

// ── Bug 1 — Contrast ───────────────────────────────────────────────────────────
class _ContrastBug extends ConsumerWidget {
  const _ContrastBug();

  static const _colours = [
    // (name, badBg, badFg, goodFg, badRatio, goodRatio, usage)
    ('Muted text', Color(0xFF0F0F0F), Color(0xFF4B5563), Color(0xFF9CA3AF),
        '1.8:1 ❌', '4.6:1 ✅', 'Hints, secondary labels'),
    ('Warning badge', Color(0xFF1A1A1A), Color(0xFFF59E0B), Color(0xFFFBBF24),
        '3.9:1 ❌', '5.5:1 ✅', 'Alert status chips'),
    ('Link text', Color(0xFF0F0F0F), Color(0xFF3B82F6), Color(0xFF60A5FA),
        '3.2:1 ❌', '6.1:1 ✅', 'Tappable text links'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showFixed = ref.watch(_contrastModeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _bugMeta(
          reports: 14,
          priority: 'P2',
          cause: 'Secondary text, warning badges, and link colours were '
              'chosen for aesthetics — not tested against WCAG AA (4.5:1 ratio).',
          fix: 'Lighten muted text from #4B5563 → #9CA3AF, '
              'brighten warning from #F59E0B → #FBBA24, '
              'lighten link from #3B82F6 → #60A5FA on dark backgrounds.',
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Before/after toggle
        const _SectionLabel('COLOUR CONTRAST PREVIEW'),
        const SizedBox(height: ZapSpacing.md),
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: () => ref
                  .read(_contrastModeProvider.notifier)
                  .state = false,
              child: _toggleTab('Before (v0.5)', !showFixed,
                  const Color(0xFFEF4444)),
            ),
          ),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: GestureDetector(
              onTap: () => ref
                  .read(_contrastModeProvider.notifier)
                  .state = true,
              child: _toggleTab('After (v0.5.3)', showFixed,
                  const Color(0xFF10B981)),
            ),
          ),
        ]),
        const SizedBox(height: ZapSpacing.md),

        // Colour swatches
        ..._colours.map((c) {
          final (name, bg, badFg, goodFg, badRatio, goodRatio, usage) = c;
          final fg     = showFixed ? goodFg : badFg;
          final ratio  = showFixed ? goodRatio : badRatio;
          final passes = showFixed;

          return Padding(
            padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
            child: Container(
              padding: const EdgeInsets.all(ZapSpacing.md),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                  color: passes
                      ? const Color(0xFF10B981).withOpacity(0.3)
                      : const Color(0xFFEF4444).withOpacity(0.3),
                ),
              ),
              child: Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: TextStyle(
                              color: fg,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      Text(usage,
                          style: TextStyle(
                              color: fg.withOpacity(0.7), fontSize: 11)),
                    ],
                  ),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(ratio,
                      style: TextStyle(
                          color: passes
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace')),
                  Text('WCAG AA',
                      style: TextStyle(
                          color: passes
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                          fontSize: 9)),
                ]),
              ]),
            ),
          );
        }),

        const SizedBox(height: ZapSpacing.md),
        _codeNote('colors.dart',
            '// Before\n'
            'static const textMuted = Color(0xFF4B5563); // 1.8:1 ❌\n'
            '\n'
            '// After\n'
            'static const textMuted = Color(0xFF9CA3AF); // 4.6:1 ✅'),
      ],
    );
  }
}

// ── Bug 2 — Text Overflow ──────────────────────────────────────────────────────
class _TextOverflowBug extends ConsumerWidget {
  const _TextOverflowBug();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(_previewLangProvider);

    const labels = {
      _PreviewLang.en: ('Cancel SOS', 14),
      _PreviewLang.hi: ('SOS रद्द करें', 13),
      _PreviewLang.ta: ('SOS ரத்துசெய்', 12),
    };

    final (text, fontSize) = labels[lang]!;
    final isFixed = lang != _PreviewLang.en;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _bugMeta(
          reports: 9,
          priority: 'P2',
          cause: 'SOS cancel button uses SizedBox(width: 140) with fixed '
              'English string length. Hindi label is 42 chars vs 10 chars '
              'in English — clips at the right edge.',
          fix: 'Replace SizedBox(width:) with IntrinsicWidth + horizontal '
              'padding. Set softWrap: true, maxLines: 2, overflow: '
              'TextOverflow.visible on all button labels.',
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Language picker
        const _SectionLabel('LANGUAGE PREVIEW'),
        const SizedBox(height: ZapSpacing.md),
        Row(children: [
          ...[_PreviewLang.en, _PreviewLang.hi, _PreviewLang.ta]
              .map((l) => Expanded(
                    child: GestureDetector(
                      onTap: () => ref
                          .read(_previewLangProvider.notifier)
                          .state = l,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.only(right: ZapSpacing.sm),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: lang == l
                              ? const Color(0xFFF97316).withOpacity(0.12)
                              : const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                          border: Border.all(
                            color: lang == l
                                ? const Color(0xFFF97316).withOpacity(0.5)
                                : const Color(0xFF2A2A2A),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            l == _PreviewLang.en
                                ? 'English'
                                : l == _PreviewLang.hi
                                    ? 'हिंदी'
                                    : 'தமிழ்',
                            style: TextStyle(
                              color: lang == l
                                  ? const Color(0xFFF97316)
                                  : const Color(0xFF9CA3AF),
                              fontSize: 12,
                              fontWeight: lang == l
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )),
        ]),
        const SizedBox(height: ZapSpacing.lg),

        // Side-by-side button preview
        Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Before (fixed width)',
                    style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 10,
                        letterSpacing: 1)),
                const SizedBox(height: ZapSpacing.sm),
                // Bug: fixed-width button clips
                Container(
                  width: 140,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                    border: Border.all(
                        color: const Color(0xFFEF4444).withOpacity(0.4)),
                  ),
                  child: Text(
                    text,
                    style: TextStyle(
                        color: const Color(0xFFEF4444),
                        fontSize: fontSize.toDouble(),
                        fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    softWrap: false,
                  ),
                ),
                const SizedBox(height: ZapSpacing.xs),
                if (isFixed)
                  const Text('Text clips off the right ❌',
                      style: TextStyle(
                          color: Color(0xFFEF4444), fontSize: 10)),
              ],
            ),
          ),
          const SizedBox(width: ZapSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('After (IntrinsicWidth)',
                    style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 10,
                        letterSpacing: 1)),
                const SizedBox(height: ZapSpacing.sm),
                // Fix: intrinsic width
                IntrinsicWidth(
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 100),
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: ZapSpacing.md),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                      border: Border.all(
                          color: const Color(0xFFEF4444).withOpacity(0.4)),
                    ),
                    child: Text(
                      text,
                      style: TextStyle(
                          color: const Color(0xFFEF4444),
                          fontSize: fontSize.toDouble(),
                          fontWeight: FontWeight.w700),
                      softWrap: true,
                      maxLines: 2,
                    ),
                  ),
                ),
                const SizedBox(height: ZapSpacing.xs),
                const Text('Wraps cleanly ✅',
                    style: TextStyle(
                        color: Color(0xFF10B981), fontSize: 10)),
              ],
            ),
          ),
        ]),
        const SizedBox(height: ZapSpacing.lg),

        _codeNote('zap_button.dart',
            '// Before\n'
            'SizedBox(width: 140, child: Text(label, maxLines: 1,\n'
            '  overflow: TextOverflow.clip))\n'
            '\n'
            '// After\n'
            'IntrinsicWidth(\n'
            '  child: Container(\n'
            '    constraints: BoxConstraints(minWidth: 100),\n'
            '    padding: EdgeInsets.symmetric(horizontal: 16),\n'
            '    child: Text(label, softWrap: true, maxLines: 2),\n'
            '  ),\n'
            ')'),
      ],
    );
  }
}

// ── Bug 3 — Icon Tint ──────────────────────────────────────────────────────────
class _IconTintBug extends ConsumerWidget {
  const _IconTintBug();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applied = ref.watch(_appliedProvider);
    final isFixed = applied[2];

    const icons = [
      (Icons.shield_rounded,       Color(0xFF10B981), 'Protection'),
      (Icons.bolt_rounded,         Color(0xFFEF4444), 'SOS trigger'),
      (Icons.location_on_rounded,  Color(0xFF3B82F6), 'GPS'),
      (Icons.mic_rounded,          Color(0xFF8B5CF6), 'Audio'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _bugMeta(
          reports: 5,
          priority: 'P2',
          cause: 'VectorDrawable tint XML attribute not applied below '
              'Android API 30. Icons render in default black/white '
              'because ImageColor.modulateColor() behaviour changed.',
          fix: 'Apply explicit colorFilter on Image.asset() for API ≤ 30 '
              'devices. Wrap Icon widgets in ColorFiltered where vector '
              'assets are used instead of Material Icons.',
        ),
        const SizedBox(height: ZapSpacing.lg),

        const _SectionLabel('ICON PREVIEW  ·  API 29 SIMULATION'),
        const SizedBox(height: ZapSpacing.md),

        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Column(children: [
            // Device bar
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: ZapSpacing.sm, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius:
                    BorderRadius.circular(ZapSpacing.radiusSmall),
              ),
              child: Row(children: [
                const Icon(Icons.phone_android_rounded,
                    color: Color(0xFF6B7280), size: 14),
                const SizedBox(width: 6),
                Text(
                  isFixed
                      ? 'Pixel 3 · Android 10 (API 29) — Fixed ✅'
                      : 'Pixel 3 · Android 10 (API 29) — Bug ❌',
                  style: TextStyle(
                    color: isFixed
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ]),
            ),
            const SizedBox(height: ZapSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: icons.map((ic) {
                final (icon, color, label) = ic;
                return Column(children: [
                  // Buggy: no tint
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: isFixed
                          ? color.withOpacity(0.12)
                          : const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon,
                        color: isFixed ? color : const Color(0xFF4B5563),
                        size: 24),
                  ),
                  const SizedBox(height: 6),
                  Text(label,
                      style: TextStyle(
                          color: isFixed
                              ? const Color(0xFF9CA3AF)
                              : const Color(0xFF4B5563),
                          fontSize: 10)),
                ]);
              }).toList(),
            ),
            const SizedBox(height: ZapSpacing.md),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(
                  horizontal: ZapSpacing.md, vertical: 8),
              decoration: BoxDecoration(
                color: isFixed
                    ? const Color(0xFF10B981).withOpacity(0.08)
                    : const Color(0xFFEF4444).withOpacity(0.08),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              ),
              child: Text(
                isFixed
                    ? 'Icons render with correct colour tint on API 29 ✅'
                    : 'Icons appear grey/black — tint not applied ❌',
                style: TextStyle(
                    color: isFixed
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                    fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),
          ]),
        ),
        const SizedBox(height: ZapSpacing.lg),

        _codeNote('zap_icon.dart',
            '// Before — tint lost on API 29\n'
            'Icon(icon, color: color)\n'
            '\n'
            '// After — explicit colorFilter fallback\n'
            'ColorFiltered(\n'
            '  colorFilter: ColorFilter.mode(color, BlendMode.srcIn),\n'
            '  child: Icon(icon),\n'
            ')'),
      ],
    );
  }
}

// ── Bug 4 — Button Styling ─────────────────────────────────────────────────────
class _ButtonStyleBug extends ConsumerWidget {
  const _ButtonStyleBug();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _bugMeta(
          reports: 6,
          priority: 'P2',
          cause: 'Buttons built ad-hoc on different screens have inconsistent '
              'border-radius (8, 12, 16 mixed), padding (10–20), '
              'and elevation. No shared ZapButton used consistently.',
          fix: 'Enforce ZapButton across all 120+ screens. '
              'Standard: radius=12, vertical padding=14, '
              'horizontal padding=20. Three variants: primary (gradient), '
              'secondary (outlined), destructive (red).',
        ),
        const SizedBox(height: ZapSpacing.lg),

        const _SectionLabel('BUTTON STYLE AUDIT'),
        const SizedBox(height: ZapSpacing.md),

        // Before: inconsistent buttons
        const Text('Before — inconsistent across screens:',
            style: TextStyle(
                color: Color(0xFF6B7280), fontSize: 11, letterSpacing: 0.5)),
        const SizedBox(height: ZapSpacing.sm),
        Wrap(
          spacing: ZapSpacing.sm,
          runSpacing: ZapSpacing.sm,
          children: [
            _rawButton('Confirm', 8, 10.0, 12.0, const Color(0xFF3B82F6)),
            _rawButton('Cancel SOS', 16, 18.0, 14.0, const Color(0xFFEF4444)),
            _rawButton('Save', 4, 8.0, 13.0, const Color(0xFF10B981)),
            _rawButton('Export', 12, 14.0, 12.0, const Color(0xFF8B5CF6)),
          ],
        ),
        const SizedBox(height: ZapSpacing.lg),

        // After: standardised
        const Text('After — ZapButton design system:',
            style: TextStyle(
                color: Color(0xFF6B7280), fontSize: 11, letterSpacing: 0.5)),
        const SizedBox(height: ZapSpacing.sm),
        Wrap(
          spacing: ZapSpacing.sm,
          runSpacing: ZapSpacing.sm,
          children: [
            _zapButton('Confirm', _ZapVariant.primary),
            _zapButton('Cancel SOS', _ZapVariant.destructive),
            _zapButton('Save', _ZapVariant.primary),
            _zapButton('Export', _ZapVariant.secondary),
          ],
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Design token table
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Column(children: [
            _tokenRow('Border radius', '12 dp', 'Was 4–16 mixed'),
            const Divider(height: 1, color: Color(0xFF2A2A2A)),
            _tokenRow('Vertical padding', '14 dp', 'Was 8–20 mixed'),
            const Divider(height: 1, color: Color(0xFF2A2A2A)),
            _tokenRow('Horizontal padding', '20 dp', 'Was 10–18 mixed'),
            const Divider(height: 1, color: Color(0xFF2A2A2A)),
            _tokenRow('Min height', '48 dp', 'WCAG touch target'),
            const Divider(height: 1, color: Color(0xFF2A2A2A)),
            _tokenRow('Font size', '14 sp', 'Was 12–16 mixed'),
          ]),
        ),
        const SizedBox(height: ZapSpacing.lg),

        _codeNote('zap_button.dart',
            '// Standard ZapButton — use everywhere\n'
            'ZapButton(\n'
            '  label: \'Confirm\',\n'
            '  variant: ZapVariant.primary,  // .secondary .destructive\n'
            '  onTap: _onConfirm,\n'
            ')'),
      ],
    );
  }
}

enum _ZapVariant { primary, secondary, destructive }

Widget _zapButton(String label, _ZapVariant variant) {
  Color bg;
  Color fg;
  Color border;
  switch (variant) {
    case _ZapVariant.primary:
      bg = const Color(0xFF3B82F6).withOpacity(0.15);
      fg = const Color(0xFF3B82F6);
      border = const Color(0xFF3B82F6).withOpacity(0.4);
      break;
    case _ZapVariant.secondary:
      bg = const Color(0xFF1A1A1A);
      fg = const Color(0xFF9CA3AF);
      border = const Color(0xFF2A2A2A);
      break;
    case _ZapVariant.destructive:
      bg = const Color(0xFFEF4444).withOpacity(0.15);
      fg = const Color(0xFFEF4444);
      border = const Color(0xFFEF4444).withOpacity(0.4);
      break;
  }
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: border),
    ),
    child: Text(label,
        style: TextStyle(
            color: fg, fontSize: 14, fontWeight: FontWeight.w700)),
  );
}

Widget _rawButton(
    String label, double radius, double vPad, double fontSize, Color color) {
  return Container(
    padding: EdgeInsets.symmetric(vertical: vPad, horizontal: 12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Text(label,
        style: TextStyle(
            color: color, fontSize: fontSize, fontWeight: FontWeight.w700)),
  );
}

Widget _tokenRow(String token, String value, String note) => Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: ZapSpacing.md, vertical: 12),
      child: Row(children: [
        Expanded(child: Text(token,
            style: const TextStyle(color: Colors.white, fontSize: 12))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(value,
              style: const TextStyle(
                  color: Color(0xFF10B981),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace')),
        ),
        const SizedBox(width: ZapSpacing.sm),
        Text(note,
            style: const TextStyle(
                color: Color(0xFF6B7280), fontSize: 10)),
      ]),
    );

// ── Apply button ───────────────────────────────────────────────────────────────
class _ApplyButton extends ConsumerWidget {
  final int index;
  const _ApplyButton({required this.index});

  static const _labels = [
    'Apply contrast fix',
    'Apply overflow fix',
    'Apply icon tint fix',
    'Apply button style fix',
  ];
  static const _colors = [
    Color(0xFFEF4444),
    Color(0xFFF97316),
    Color(0xFFF59E0B),
    Color(0xFF3B82F6),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applied = ref.watch(_appliedProvider);
    final isDone  = applied[index];
    final color   = _colors[index];

    if (isDone) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withOpacity(0.1),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded,
                color: Color(0xFF10B981), size: 18),
            SizedBox(width: ZapSpacing.sm),
            Text('Fix applied & committed',
                style: TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () async {
        await Future.delayed(const Duration(milliseconds: 500));
        if (!context.mounted) return;
        final updated = List<bool>.from(ref.read(_appliedProvider));
        updated[index] = true;
        ref.read(_appliedProvider.notifier).state = updated;
        // Advance to next unfixed bug
        final next = updated.indexWhere((v) => !v);
        if (next != -1) {
          ref.read(_activeBugProvider.notifier).state = next;
        }
      },
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
                blurRadius: 16,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.build_rounded, color: Colors.white, size: 18),
            const SizedBox(width: ZapSpacing.sm),
            Text(_labels[index],
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

// ── Fix summary ────────────────────────────────────────────────────────────────
class _FixSummary extends StatelessWidget {
  final List<bool> applied;
  const _FixSummary({required this.applied});

  static const _bugs = [
    (Color(0xFFEF4444), 'Bug 1 — Low contrast colours (WCAG AA)'),
    (Color(0xFFF97316), 'Bug 2 — Hindi/Tamil text overflow'),
    (Color(0xFFF59E0B), 'Bug 3 — Icon tint missing on API 29'),
    (Color(0xFF3B82F6), 'Bug 4 — Inconsistent button styling'),
  ];

  @override
  Widget build(BuildContext context) {
    final doneCount = applied.where((a) => a).length;
    final allDone   = doneCount == 4;

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: allDone
            ? const Color(0xFF10B981).withOpacity(0.06)
            : const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
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
            Text('$doneCount / 4 fixes applied',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            Text(
              allDone ? '✅ Day 126 complete' : 'Select bugs above',
              style: TextStyle(
                  color: allDone
                      ? const Color(0xFF10B981)
                      : const Color(0xFF6B7280),
                  fontSize: 11,
                  fontWeight:
                      allDone ? FontWeight.w700 : FontWeight.w400),
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: doneCount / 4,
            backgroundColor: const Color(0xFF2A2A2A),
            valueColor: AlwaysStoppedAnimation(
              allDone ? const Color(0xFF10B981) : const Color(0xFF8B5CF6),
            ),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        ..._bugs.asMap().entries.map((e) {
          final i = e.key;
          final (color, label) = e.value;
          final done = applied[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Icon(
                done
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color:
                    done ? const Color(0xFF10B981) : const Color(0xFF4B5563),
                size: 16,
              ),
              const SizedBox(width: ZapSpacing.sm),
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                    color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                      color: done
                          ? const Color(0xFF6B7280)
                          : Colors.white,
                      fontSize: 12,
                      decoration:
                          done ? TextDecoration.lineThrough : null,
                      decorationColor: const Color(0xFF6B7280),
                    )),
              ),
            ]),
          );
        }),
        if (allDone) ...[
          const Divider(height: ZapSpacing.lg, color: Color(0xFF2A2A2A)),
          const Row(children: [
            Icon(Icons.arrow_forward_rounded,
                color: Color(0xFF8B5CF6), size: 14),
            SizedBox(width: ZapSpacing.sm),
            Expanded(
              child: Text(
                'Next: Days 127-128 — Fix Samsung Android 13 notification delay',
                style: TextStyle(
                    color: Color(0xFF9CA3AF), fontSize: 11),
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}

// ── Shared helpers ─────────────────────────────────────────────────────────────
Widget _bugMeta({
  required int reports,
  required String priority,
  required String cause,
  required String fix,
}) =>
    Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(children: [
        Row(children: [
          _metaChip('$reports reports', const Color(0xFFF59E0B)),
          const SizedBox(width: ZapSpacing.sm),
          _metaChip(priority, const Color(0xFF8B5CF6)),
        ]),
        const SizedBox(height: ZapSpacing.md),
        _metaRow(Icons.search_rounded, const Color(0xFFEF4444),
            'Root cause', cause),
        const SizedBox(height: ZapSpacing.sm),
        _metaRow(Icons.build_rounded, const Color(0xFF10B981), 'Fix', fix),
      ]),
    );

Widget _metaChip(String label, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );

Widget _metaRow(
        IconData icon, Color color, String label, String text) =>
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 14),
      const SizedBox(width: ZapSpacing.sm),
      Text('$label: ',
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      Expanded(
        child: Text(text,
            style: const TextStyle(
                color: Color(0xFFD1D5DB), fontSize: 11, height: 1.5)),
      ),
    ]);

Widget _toggleTab(String label, bool active, Color color) => Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: active ? color.withOpacity(0.12) : const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(
          color: active ? color.withOpacity(0.5) : const Color(0xFF2A2A2A),
          width: active ? 2 : 1,
        ),
      ),
      child: Center(
        child: Text(label,
            style: TextStyle(
                color: active ? color : const Color(0xFF6B7280),
                fontSize: 12,
                fontWeight:
                    active ? FontWeight.w700 : FontWeight.w400)),
      ),
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
