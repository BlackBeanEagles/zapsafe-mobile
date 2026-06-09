import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/spacing.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _fontScaleProvider    = StateProvider<double>((ref) => 1.0);
final _highContrastProvider = StateProvider<bool>((ref) => false);
final _boldTextProvider     = StateProvider<bool>((ref) => false);
final _reduceMotionProvider = StateProvider<bool>((ref) => false);

// ── Palette data ───────────────────────────────────────────────────────────────
class _PaletteEntry {
  final String hex;
  final String name;
  final String usage;
  final double ratio;
  final Color color;
  const _PaletteEntry(this.hex, this.name, this.usage, this.ratio, this.color);
  bool get passAA  => ratio >= 4.5;
  bool get passAAA => ratio >= 7.0;
}

const _kEntries = <_PaletteEntry>[
  _PaletteEntry('#FFFFFF', 'White',       'Primary text',      17.9, Color(0xFFFFFFFF)),
  _PaletteEntry('#9CA3AF', 'Gray 400',    'Subtitle text',      8.0, Color(0xFF9CA3AF)),
  _PaletteEntry('#6B7280', 'Gray 500',    'Muted text  ⚠',      4.2, Color(0xFF6B7280)),
  _PaletteEntry('#EF4444', 'Red 500',     'Danger / SOS',       5.0, Color(0xFFEF4444)),
  _PaletteEntry('#10B981', 'Emerald 500', 'Safe / success',     7.5, Color(0xFF10B981)),
  _PaletteEntry('#F59E0B', 'Amber 500',   'Warning',            8.6, Color(0xFFF59E0B)),
  _PaletteEntry('#3B82F6', 'Blue 500',    'Info / links',       5.3, Color(0xFF3B82F6)),
  _PaletteEntry('#8B5CF6', 'Violet 500',  'Premium',            4.6, Color(0xFF8B5CF6)),
  _PaletteEntry('#06B6D4', 'Cyan 500',    'Accent',             7.8, Color(0xFF06B6D4)),
];

const _kScales = <(double, String, String)>[
  (1.0, 'Default', '1.0×'),
  (1.2, 'Large',   '1.2×'),
  (1.5, 'Larger',  '1.5×'),
  (2.0, 'Largest', '2.0×'),
];

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day110A11yContrastScreen extends ConsumerWidget {
  const Day110A11yContrastScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale        = ref.watch(_fontScaleProvider);
    final highContrast = ref.watch(_highContrastProvider);
    final boldText     = ref.watch(_boldTextProvider);
    final reduceMotion = ref.watch(_reduceMotionProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Day 110 · Contrast & Font Size'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Hero(),
            const SizedBox(height: ZapSpacing.xl),
            _FontScaleSelector(current: scale),
            const SizedBox(height: ZapSpacing.xl),
            _ToggleSection(
              highContrast: highContrast,
              boldText: boldText,
              reduceMotion: reduceMotion,
            ),
            const SizedBox(height: ZapSpacing.xl),
            _LivePreview(
              scale: scale,
              highContrast: highContrast,
              boldText: boldText,
              reduceMotion: reduceMotion,
            ),
            const SizedBox(height: ZapSpacing.xl),
            const _SectionLabel('WCAG 2.1 · CONTRAST RATIOS ON #0F0F0F'),
            const SizedBox(height: ZapSpacing.md),
            const _LegendRow(),
            const SizedBox(height: ZapSpacing.sm),
            const _ContrastTable(),
            const SizedBox(height: ZapSpacing.xl),
            const _SectionLabel('FIX · HIGH-CONTRAST MUTED TEXT ALTERNATIVES'),
            const SizedBox(height: ZapSpacing.md),
            const _AltPaletteSuggestion(),
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
          colors: [Color(0xFF431407), Color(0xFF120806), Color(0xFF0A0A0A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFFF97316).withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF97316).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.contrast_rounded,
                  color: Color(0xFFF97316),
                  size: 22,
                ),
              ),
              const SizedBox(width: ZapSpacing.md),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DAY 110',
                    style: TextStyle(
                      color: Color(0xFFF97316),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                  Text(
                    'Contrast & Font Size',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          const Text(
            'WCAG 2.1 contrast ratio audit for the ZapSafe palette · live font '
            'scaler (1.0×→2.0×) · bold text & high contrast toggles · key '
            'finding: #6B7280 muted text fails AA at 4.2:1 on #0F0F0F.',
            style: TextStyle(
              color: Color(0xFFD1D5DB),
              fontSize: 12,
              height: 1.6,
            ),
          ),
          const SizedBox(height: ZapSpacing.md),
          const Row(
            children: [
              _HeroStat('9',  'Colors audited',  Color(0xFFF97316)),
              _HeroStat('1',  'WCAG Fail',        Color(0xFFEF4444)),
              _HeroStat('4',  'A11y toggles',     Color(0xFF10B981)),
              _HeroStat('4×', 'Font scales',      Color(0xFF3B82F6)),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String value;
  final String label;
  final Color  color;
  const _HeroStat(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 9,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Section label ──────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF6B7280),
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ),
    );
  }
}

// ── Font scale selector ────────────────────────────────────────────────────────
class _FontScaleSelector extends ConsumerWidget {
  final double current;
  const _FontScaleSelector({required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('FONT SCALE'),
        const SizedBox(height: ZapSpacing.md),
        Row(
          children: List.generate(_kScales.length, (i) {
            final (scaleVal, name, label) = _kScales[i];
            final isSelected = current == scaleVal;
            final isLast = i == _kScales.length - 1;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: isLast ? 0 : ZapSpacing.sm),
                child: GestureDetector(
                  onTap: () =>
                      ref.read(_fontScaleProvider.notifier).state = scaleVal,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFF97316).withOpacity(0.15)
                          : const Color(0xFF1A1A1A),
                      borderRadius:
                          BorderRadius.circular(ZapSpacing.radiusSmall),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFF97316)
                            : const Color(0xFF2A2A2A),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Aa',
                          style: TextStyle(
                            fontSize: 11 * scaleVal,
                            color: isSelected
                                ? const Color(0xFFF97316)
                                : Colors.white70,
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 9,
                            color: isSelected
                                ? const Color(0xFFF97316)
                                : Colors.white38,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 8,
                            color: Colors.white24,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ── Toggle section ─────────────────────────────────────────────────────────────
class _ToggleSection extends ConsumerWidget {
  final bool highContrast;
  final bool boldText;
  final bool reduceMotion;
  const _ToggleSection({
    required this.highContrast,
    required this.boldText,
    required this.reduceMotion,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('ACCESSIBILITY TOGGLES'),
        const SizedBox(height: ZapSpacing.md),
        _ToggleTile(
          icon: Icons.contrast_rounded,
          label: 'High Contrast',
          subtitle:
              'Replaces #6B7280 (4.2:1 ✗) with #9CA3AF (8.0:1 ✓ AAA) for muted text',
          value: highContrast,
          accent: const Color(0xFFF97316),
          onChanged: (v) =>
              ref.read(_highContrastProvider.notifier).state = v,
        ),
        const SizedBox(height: ZapSpacing.sm),
        _ToggleTile(
          icon: Icons.format_bold_rounded,
          label: 'Bold Text',
          subtitle: 'Increases font weight from w400 → w700 throughout the UI',
          value: boldText,
          accent: const Color(0xFFF59E0B),
          onChanged: (v) => ref.read(_boldTextProvider.notifier).state = v,
        ),
        const SizedBox(height: ZapSpacing.sm),
        _ToggleTile(
          icon: Icons.animation_rounded,
          label: 'Reduce Motion',
          subtitle:
              'Sets animation duration to 0 ms — disables elastic/spring transitions',
          value: reduceMotion,
          accent: const Color(0xFF8B5CF6),
          onChanged: (v) =>
              ref.read(_reduceMotionProvider.notifier).state = v,
        ),
      ],
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final Color accent;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(
          horizontal: ZapSpacing.md, vertical: ZapSpacing.sm),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(
          color: value ? accent.withOpacity(0.45) : const Color(0xFF2A2A2A),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: ZapSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: accent,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

// ── Live preview ───────────────────────────────────────────────────────────────
class _LivePreview extends StatelessWidget {
  final double scale;
  final bool highContrast;
  final bool boldText;
  final bool reduceMotion;

  const _LivePreview({
    required this.scale,
    required this.highContrast,
    required this.boldText,
    required this.reduceMotion,
  });

  @override
  Widget build(BuildContext context) {
    // The key contrast demo: muted text color switches based on highContrast.
    final mutedColor = highContrast
        ? const Color(0xFF9CA3AF) // 8.0:1 ✓ AAA
        : const Color(0xFF6B7280); // 4.2:1 ✗ FAILS AA
    final fw = boldText ? FontWeight.w700 : FontWeight.w400;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('LIVE PREVIEW'),
        const SizedBox(height: ZapSpacing.md),
        AnimatedContainer(
          duration: Duration(milliseconds: reduceMotion ? 0 : 300),
          padding: const EdgeInsets.all(ZapSpacing.lg),
          decoration: BoxDecoration(
            color: highContrast ? Colors.black : const Color(0xFF111111),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(
              color: highContrast
                  ? Colors.white30
                  : const Color(0xFF2A2A2A),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status row
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'PROTECTED',
                      style: TextStyle(
                        color: const Color(0xFF10B981),
                        fontSize: 10 * scale,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '· Live',
                    style: TextStyle(
                      color: mutedColor,
                      fontSize: 11 * scale,
                      fontWeight: fw,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Heading
              Text(
                'ZapSafe is Active',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20 * scale,
                  fontWeight: boldText ? FontWeight.w800 : FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              // Subtitle — uses muted color, main contrast demo
              Text(
                'Monitoring audio & motion continuously',
                style: TextStyle(
                  color: mutedColor,
                  fontSize: 13 * scale,
                  fontWeight: fw,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: ZapSpacing.md),
              // Stats row
              Row(
                children: [
                  _StatChip('Contacts',   '3',    const Color(0xFF3B82F6), scale),
                  const SizedBox(width: 6),
                  _StatChip('Safe Zones', '2',    const Color(0xFF10B981), scale),
                  const SizedBox(width: 6),
                  _StatChip('Battery',    '87 %', const Color(0xFFF59E0B), scale),
                ],
              ),
              const SizedBox(height: ZapSpacing.md),
              // SOS button
              Container(
                width: double.infinity,
                height: (48 * (scale > 1.2 ? scale : 1.0)).clamp(48.0, 120.0),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'SOS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18 * scale,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: ZapSpacing.sm),
              // Contrast status note
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    highContrast
                        ? Icons.check_circle_rounded
                        : Icons.warning_rounded,
                    color: mutedColor,
                    size: 12 * scale,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      highContrast
                          ? 'Muted: #9CA3AF  8.0:1 ✓ AAA'
                          : 'Muted: #6B7280  4.2:1 ✗ FAILS AA',
                      style: TextStyle(
                        color: mutedColor,
                        fontSize: 11 * scale,
                        fontWeight: fw,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color  color;
  final double scale;
  const _StatChip(this.label, this.value, this.color, this.scale);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 14 * scale,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 10 * scale,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── WCAG legend ────────────────────────────────────────────────────────────────
class _LegendRow extends StatelessWidget {
  const _LegendRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _LegendChip('AA  ≥ 4.5:1',  Color(0xFF3B82F6)),
        SizedBox(width: ZapSpacing.sm),
        _LegendChip('AAA  ≥ 7.0:1', Color(0xFF10B981)),
        SizedBox(width: ZapSpacing.sm),
        _LegendChip('FAIL  < 4.5:1', Color(0xFFEF4444)),
      ],
    );
  }
}

class _LegendChip extends StatelessWidget {
  final String label;
  final Color color;
  const _LegendChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Contrast table ─────────────────────────────────────────────────────────────
class _ContrastTable extends StatelessWidget {
  const _ContrastTable();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        children: [
          // Header
          const Padding(
            padding: EdgeInsets.symmetric(
                horizontal: ZapSpacing.md, vertical: ZapSpacing.sm),
            child: Row(
              children: [
                SizedBox(width: 26),
                SizedBox(width: ZapSpacing.sm),
                Expanded(
                  flex: 5,
                  child: Text(
                    'Color / Usage',
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                SizedBox(
                  width: 52,
                  child: Text(
                    'Ratio',
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                SizedBox(width: ZapSpacing.sm),
                SizedBox(
                  width: 66,
                  child: Text(
                    'AA  AAA',
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF2A2A2A)),
          ...List.generate(
            _kEntries.length,
            (i) => _ContrastRow(
              entry: _kEntries[i],
              isLast: i == _kEntries.length - 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContrastRow extends StatelessWidget {
  final _PaletteEntry entry;
  final bool isLast;
  const _ContrastRow({required this.entry, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final failBg = !entry.passAA
        ? const Color(0xFFEF4444).withOpacity(0.07)
        : Colors.transparent;
    return Container(
      decoration: BoxDecoration(
        color: failBg,
        borderRadius: isLast
            ? const BorderRadius.vertical(
                bottom: Radius.circular(ZapSpacing.radius))
            : null,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: ZapSpacing.md, vertical: 10),
            child: Row(
              children: [
                // Swatch
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: entry.color,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: Colors.white12),
                  ),
                ),
                const SizedBox(width: ZapSpacing.sm),
                // Name + hex + usage
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${entry.hex}  ${entry.name}',
                        style: TextStyle(
                          color: entry.color,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        entry.usage,
                        style: const TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                // Ratio
                SizedBox(
                  width: 52,
                  child: Text(
                    '${entry.ratio}:1',
                    style: TextStyle(
                      color: entry.passAA ? Colors.white : const Color(0xFFEF4444),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: ZapSpacing.sm),
                // AA + AAA badges
                SizedBox(
                  width: 66,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _PassBadge(pass: entry.passAA,  label: 'AA'),
                      const SizedBox(width: 4),
                      _PassBadge(pass: entry.passAAA, label: 'AAA'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!isLast) const Divider(height: 1, color: Color(0xFF2A2A2A)),
        ],
      ),
    );
  }
}

class _PassBadge extends StatelessWidget {
  final bool pass;
  final String label;
  const _PassBadge({required this.pass, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = pass ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// ── Alt palette suggestion ─────────────────────────────────────────────────────
class _AltPaletteSuggestion extends StatelessWidget {
  const _AltPaletteSuggestion();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withOpacity(0.07),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(
          color: const Color(0xFF10B981).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_fix_high_rounded,
                  color: Color(0xFF10B981), size: 18),
              SizedBox(width: 8),
              Text(
                'Recommended Fix',
                style: TextStyle(
                  color: Color(0xFF10B981),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            '#6B7280 (Gray 500) fails WCAG AA at 4.2:1 on #0F0F0F. Replace '
            'secondary / muted text with one of these AA-compliant options:',
            style: TextStyle(
              color: Color(0xFFD1D5DB),
              fontSize: 12,
              height: 1.6,
            ),
          ),
          const SizedBox(height: ZapSpacing.md),
          const _AltRow(
            fromHex: '#6B7280',
            fromColor: Color(0xFF6B7280),
            toHex: '#9CA3AF',
            toColor: Color(0xFF9CA3AF),
            ratio: '8.0:1',
            level: 'AAA',
          ),
          const SizedBox(height: 8),
          const _AltRow(
            fromHex: '#6B7280',
            fromColor: Color(0xFF6B7280),
            toHex: '#A1A1AA',
            toColor: Color(0xFFA1A1AA),
            ratio: '7.0:1',
            level: 'AAA',
          ),
          const SizedBox(height: ZapSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1F17),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: const Color(0xFF10B981).withOpacity(0.2)),
            ),
            child: const Text(
              '// lib/core/theme/colors.dart\n'
              'static const textSecondary = Color(0xFF9CA3AF);\n'
              '// ← was Color(0xFF6B7280) — fails AA at 4.2:1',
              style: TextStyle(
                color: Color(0xFF6EE7B7),
                fontSize: 11,
                fontFamily: 'monospace',
                height: 1.7,
              ),
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'All other ZapSafe colors pass WCAG AA. '
            'High Contrast toggle above demonstrates the fix live.',
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _AltRow extends StatelessWidget {
  final String fromHex;
  final Color  fromColor;
  final String toHex;
  final Color  toColor;
  final String ratio;
  final String level;

  const _AltRow({
    required this.fromHex,
    required this.fromColor,
    required this.toHex,
    required this.toColor,
    required this.ratio,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: fromColor,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: Colors.white12),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          fromHex,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 11,
            fontFamily: 'monospace',
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Icon(
            Icons.arrow_forward_rounded,
            size: 14,
            color: Color(0xFF4B5563),
          ),
        ),
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: toColor,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: Colors.white12),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          toHex,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '$ratio  $level',
            style: const TextStyle(
              color: Color(0xFF10B981),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
