import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/theme/spacing.dart';

/// Day 2 — Design System Showcase
///
/// Demonstrates that the ZapSafe design system is fully wired:
/// - Color palette (danger/safe/info/warning + backgrounds + text)
/// - Typography (ClashDisplay headings + Syne body + IBMPlexMono technical)
/// - Spacing (4px grid + WCAG AAA 75dp touch targets)
class Day2DesignSystemScreen extends StatelessWidget {
  const Day2DesignSystemScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(ZapSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(),
              SizedBox(height: ZapSpacing.xxxl),
              _Section(title: 'COLORS'),
              SizedBox(height: ZapSpacing.lg),
              _ColorPalette(),
              SizedBox(height: ZapSpacing.xxxl),
              _Section(title: 'TYPOGRAPHY'),
              SizedBox(height: ZapSpacing.lg),
              _TypographyShowcase(),
              SizedBox(height: ZapSpacing.xxxl),
              _Section(title: 'SPACING & TOUCH TARGETS'),
              SizedBox(height: ZapSpacing.lg),
              _SpacingShowcase(),
              SizedBox(height: ZapSpacing.huge),
              _Footer(),
              SizedBox(height: ZapSpacing.xxxl),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Header ─────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: ZapColors.safe,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: ZapSpacing.sm),
            Text(
              'DAY 2 COMPLETE',
              style: ZapTypography.labelSmall.copyWith(
                color: ZapColors.safe,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.md),
        Text(
          'ZapSafe',
          style: ZapTypography.displayLarge.copyWith(color: ZapColors.textPrimary),
        ),
        const SizedBox(height: ZapSpacing.xs),
        Text(
          'Design System Foundation',
          style: ZapTypography.headlineMedium.copyWith(color: ZapColors.textSecondary),
        ),
      ],
    );
  }
}

// ─── Section Header ─────────────────────────────────────────────────────
class _Section extends StatelessWidget {
  final String title;
  const _Section({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: ZapTypography.labelSmall.copyWith(
            color: ZapColors.textSecondary,
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: ZapSpacing.md),
        const Expanded(
          child: Divider(color: ZapColors.border, height: 1),
        ),
      ],
    );
  }
}

// ─── Color Palette ──────────────────────────────────────────────────────
class _ColorPalette extends StatelessWidget {
  const _ColorPalette();

  @override
  Widget build(BuildContext context) {
    final colors = <(String, Color, String)>[
      ('Danger', ZapColors.danger, '#E63946'),
      ('Safe', ZapColors.safe, '#06D6A0'),
      ('Info', ZapColors.info, '#4CC9F0'),
      ('Warning', ZapColors.warning, '#F4A261'),
      ('BG Primary', ZapColors.bgPrimary, '#07070E'),
      ('BG Card', ZapColors.bgCard, '#0D0D16'),
      ('BG Surface', ZapColors.bgSurface, '#16161F'),
      ('Border', ZapColors.border, '#2A2A35'),
    ];

    return Wrap(
      spacing: ZapSpacing.md,
      runSpacing: ZapSpacing.md,
      children: colors.map((c) => _ColorChip(name: c.$1, color: c.$2, hex: c.$3)).toList(),
    );
  }
}

class _ColorChip extends StatelessWidget {
  final String name;
  final Color color;
  final String hex;
  const _ColorChip({required this.name, required this.color, required this.hex});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 72,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(ZapSpacing.radius)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(ZapSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: ZapTypography.labelLarge.copyWith(color: ZapColors.textPrimary)),
                const SizedBox(height: ZapSpacing.xs),
                Text(hex, style: ZapTypography.monoSmall.copyWith(color: ZapColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Typography Showcase ────────────────────────────────────────────────
class _TypographyShowcase extends StatelessWidget {
  const _TypographyShowcase();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.border, width: 1),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TypeRow(label: 'ClashDisplay 48', sample: 'Display Large', style: ZapTypography.displayLarge),
          SizedBox(height: ZapSpacing.lg),
          _TypeRow(label: 'ClashDisplay 36', sample: 'Display Medium', style: ZapTypography.displayMedium),
          SizedBox(height: ZapSpacing.lg),
          _TypeRow(label: 'ClashDisplay 28', sample: 'Display Small', style: ZapTypography.displaySmall),
          SizedBox(height: ZapSpacing.lg),
          _TypeRow(label: 'Syne 24 semibold', sample: 'Headline Large', style: ZapTypography.headlineLarge),
          SizedBox(height: ZapSpacing.lg),
          _TypeRow(label: 'Syne 16 regular', sample: 'Body text in Syne, designed to be readable.', style: ZapTypography.bodyLarge),
          SizedBox(height: ZapSpacing.lg),
          _TypeRow(label: 'Syne 12 medium', sample: 'LABEL TEXT', style: ZapTypography.labelMedium),
          SizedBox(height: ZapSpacing.lg),
          _TypeRow(label: 'IBMPlexMono 13', sample: 'SHA256: a3f2c1d8e9b...', style: ZapTypography.monoLarge),
        ],
      ),
    );
  }
}

class _TypeRow extends StatelessWidget {
  final String label;
  final String sample;
  final TextStyle style;
  const _TypeRow({required this.label, required this.sample, required this.style});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: ZapTypography.labelSmall.copyWith(color: ZapColors.textSecondary)),
        const SizedBox(height: ZapSpacing.xs),
        Text(sample, style: style.copyWith(color: ZapColors.textPrimary)),
      ],
    );
  }
}

// ─── Spacing & Touch Targets ────────────────────────────────────────────
class _SpacingShowcase extends StatelessWidget {
  const _SpacingShowcase();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('4px Grid', style: ZapTypography.labelLarge.copyWith(color: ZapColors.textPrimary)),
          const SizedBox(height: ZapSpacing.md),
          const Wrap(
            spacing: ZapSpacing.md,
            runSpacing: ZapSpacing.md,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              _SpacingBox(size: ZapSpacing.xs, label: '4'),
              _SpacingBox(size: ZapSpacing.sm, label: '8'),
              _SpacingBox(size: ZapSpacing.md, label: '12'),
              _SpacingBox(size: ZapSpacing.lg, label: '16'),
              _SpacingBox(size: ZapSpacing.xl, label: '20'),
              _SpacingBox(size: ZapSpacing.xxl, label: '24'),
              _SpacingBox(size: ZapSpacing.xxxl, label: '32'),
              _SpacingBox(size: ZapSpacing.huge, label: '48'),
            ],
          ),
          const SizedBox(height: ZapSpacing.xxl),
          Row(
            children: [
              Text('WCAG AAA Touch Target ', style: ZapTypography.labelLarge.copyWith(color: ZapColors.textPrimary)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.sm, vertical: 2),
                decoration: BoxDecoration(
                  color: ZapColors.safe.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                ),
                child: Text('75 × 75dp', style: ZapTypography.monoSmall.copyWith(color: ZapColors.safe)),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          Container(
            width: ZapSpacing.minTouchTarget,
            height: ZapSpacing.minTouchTarget,
            decoration: BoxDecoration(
              color: ZapColors.danger,
              borderRadius: BorderRadius.circular(ZapSpacing.radius),
            ),
            child: const Icon(Icons.warning_rounded, color: Colors.white, size: 32),
          ),
        ],
      ),
    );
  }
}

class _SpacingBox extends StatelessWidget {
  final double size;
  final String label;
  const _SpacingBox({required this.size, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: ZapColors.info.withOpacity(0.3),
            border: Border.all(color: ZapColors.info, width: 1),
          ),
        ),
        const SizedBox(height: ZapSpacing.xs),
        Text(label, style: ZapTypography.monoSmall.copyWith(color: ZapColors.textSecondary)),
      ],
    );
  }
}

// ─── Footer ─────────────────────────────────────────────────────────────
class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color: ZapColors.safe.withOpacity(0.08),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.safe.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: ZapColors.safe, size: 28),
          const SizedBox(width: ZapSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Frontend Day 2 ✅',
                    style: ZapTypography.headlineSmall.copyWith(color: ZapColors.safe)),
                const SizedBox(height: ZapSpacing.xs),
                Text(
                  'Colors • Typography • Spacing wired up. Ready for Day 3.',
                  style: ZapTypography.bodySmall.copyWith(color: ZapColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
