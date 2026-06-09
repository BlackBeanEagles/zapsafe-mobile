import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../domain/providers/onboarding_provider.dart';
import '../navigation/app_router.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';

/// Day 44 — Onboarding Step 4: Accessibility Preferences.
///
/// Route: /onboarding/step4
/// Prev:  /onboarding/step3
/// Next:  /onboarding/step5 (Day 45)
///
/// Optional — Next always enabled.
/// Feeds: LP20 prosodic baseline (language) · accessibility backend (Days 106+).
class Day44OnboardingStep4Screen extends ConsumerWidget {
  const Day44OnboardingStep4Screen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a11y = ref.watch(onboardingProvider).accessibility;
    final notifier = ref.read(onboardingProvider.notifier);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: ZapColors.bgPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: ZapColors.textPrimary),
          onPressed: () {
            notifier.advanceToStep(3);
            context.go(AppRoutes.onboardingStep3);
          },
        ),
        title: const _StepIndicator(currentStep: 4, totalSteps: 5),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: ZapSpacing.lg,
                  vertical: ZapSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _StepHeader(),
                    const SizedBox(height: ZapSpacing.xl),

                    // Language
                    _LanguageSection(
                      selected: a11y.language,
                      onChanged: notifier.setLanguage,
                    ),
                    const SizedBox(height: ZapSpacing.lg),

                    // Display toggles
                    _DisplaySection(
                      simpleMode: a11y.simpleMode,
                      highContrast: a11y.highContrast,
                      onSimpleChanged: notifier.setSimpleMode,
                      onHighContrastChanged: notifier.setHighContrast,
                    ),
                    const SizedBox(height: ZapSpacing.lg),

                    // Font scale
                    _FontScaleSection(
                      scale: a11y.fontScale,
                      onChanged: notifier.setFontScale,
                    ),

                    const SizedBox(height: ZapSpacing.xxxl),
                  ],
                ),
              ),
            ),

            // Bottom nav
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ZapSpacing.lg, 0, ZapSpacing.lg, ZapSpacing.xl,
              ),
              child: ZapButton(
                label: 'Next',
                onPressed: () {
                  notifier.advanceToStep(5);
                  context.go(AppRoutes.onboardingStep5);
                },
                variant: ZapButtonVariant.elevated,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Step indicator ───────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.currentStep, required this.totalSteps});
  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps, (i) {
        final active = i + 1 == currentStep;
        final done = i + 1 < currentStep;
        return Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: i < totalSteps - 1 ? 4 : 0),
            decoration: BoxDecoration(
              color: (active || done) ? ZapColors.danger : ZapColors.bgSurface,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _StepHeader extends StatelessWidget {
  const _StepHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Accessibility',
          style: ZapTypography.displaySmall.copyWith(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Text(
          'Customize ZapSafe to work best for you.\n'
          'All settings can be changed later.',
          style: ZapTypography.bodyMedium.copyWith(
            color: ZapColors.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

// ─── Language section ─────────────────────────────────────────────────────────

class _LanguageSection extends StatelessWidget {
  const _LanguageSection({
    required this.selected,
    required this.onChanged,
  });

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.language_rounded,
                  color: ZapColors.info, size: 20),
              const SizedBox(width: ZapSpacing.sm),
              Text(
                'Language',
                style: ZapTypography.labelLarge.copyWith(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            'Sets the AI voice-stress baseline used to detect danger '
            '(LP20 APAC prosodic model).',
            style: ZapTypography.bodySmall.copyWith(
              color: ZapColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: ZapSpacing.md),
          DropdownButtonFormField<String>(
            key: const Key('language_dropdown'),
            value: selected,
            decoration: InputDecoration(
              filled: true,
              fillColor: ZapColors.bgSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: ZapColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: ZapColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: ZapColors.info),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: ZapSpacing.md,
                vertical: ZapSpacing.sm,
              ),
            ),
            dropdownColor: ZapColors.bgCard,
            style: ZapTypography.bodyMedium
                .copyWith(color: ZapColors.textPrimary),
            items: OnboardingAccessibility.supportedLanguages
                .map((lang) => DropdownMenuItem<String>(
                      value: lang['code'],
                      child: Text(lang['name'] ?? lang['code']!),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ],
      ),
    );
  }
}

// ─── Display section ──────────────────────────────────────────────────────────

class _DisplaySection extends StatelessWidget {
  const _DisplaySection({
    required this.simpleMode,
    required this.highContrast,
    required this.onSimpleChanged,
    required this.onHighContrastChanged,
  });

  final bool simpleMode;
  final bool highContrast;
  final ValueChanged<bool> onSimpleChanged;
  final ValueChanged<bool> onHighContrastChanged;

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.display_settings_rounded,
                  color: ZapColors.warning, size: 20),
              const SizedBox(width: ZapSpacing.sm),
              Text(
                'Display',
                style: ZapTypography.labelLarge.copyWith(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),

          // Simple mode
          _ToggleRow(
            key: const Key('simple_mode_toggle'),
            title: 'Simple mode',
            subtitle:
                'Single large SOS button. Recommended for elderly users.',
            value: simpleMode,
            activeColor: ZapColors.warning,
            onChanged: onSimpleChanged,
          ),
          const Divider(color: ZapColors.border, height: ZapSpacing.xl),

          // High contrast
          _ToggleRow(
            key: const Key('high_contrast_toggle'),
            title: 'High contrast',
            subtitle: 'WCAG AAA colour palette for low-vision users.',
            value: highContrast,
            activeColor: ZapColors.warning,
            onChanged: onHighContrastChanged,
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.activeColor,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final Color activeColor;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: ZapTypography.bodyMedium.copyWith(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: ZapTypography.bodySmall.copyWith(
                  color: ZapColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: ZapSpacing.sm),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: activeColor,
        ),
      ],
    );
  }
}

// ─── Font scale section ───────────────────────────────────────────────────────

class _FontScaleSection extends StatelessWidget {
  const _FontScaleSection({
    required this.scale,
    required this.onChanged,
  });

  final double scale;
  final ValueChanged<double> onChanged;

  String get _label {
    if (scale <= 1.0) return 'Normal (1×)';
    if (scale <= 1.25) return 'Large (1.25×)';
    if (scale <= 1.5) return 'Larger (1.5×)';
    if (scale <= 1.75) return 'X-Large (1.75×)';
    return 'XX-Large (2×)';
  }

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.text_fields_rounded,
                  color: ZapColors.safe, size: 20),
              const SizedBox(width: ZapSpacing.sm),
              Text(
                'Text size',
                style: ZapTypography.labelLarge.copyWith(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                _label,
                style: ZapTypography.labelMedium.copyWith(
                  color: ZapColors.safe,
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),

          // Preview text at current scale
          Center(
            child: Text(
              'ZapSafe',
              style: ZapTypography.bodyLarge.copyWith(
                color: ZapColors.textPrimary,
                fontSize: 16 * scale,
              ),
            ),
          ),
          const SizedBox(height: ZapSpacing.md),

          Slider(
            key: const Key('font_scale_slider'),
            value: scale,
            min: 1.0,
            max: 2.0,
            divisions: 4,
            activeColor: ZapColors.safe,
            inactiveColor: ZapColors.bgSurface,
            onChanged: onChanged,
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('A',
                    style: ZapTypography.bodySmall
                        .copyWith(color: ZapColors.textSecondary)),
                Text('A',
                    style: ZapTypography.bodyLarge.copyWith(
                      color: ZapColors.textSecondary,
                      fontSize: 22,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
