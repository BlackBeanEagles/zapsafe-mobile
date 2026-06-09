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

/// Day 43 — Onboarding Step 3: Location Trust Setup.
///
/// Route: /onboarding/step3
/// Prev:  /onboarding/step2
/// Next:  /onboarding/step4 (Day 44)
///
/// Optional step — Next is always enabled (user can skip).
/// Pre-seeds TrustedLocation data that LP24 auto-learn will use.
/// Max 5 locations. Preset quick-add chips + custom text field option.
class Day43OnboardingStep3Screen extends ConsumerWidget {
  const Day43OnboardingStep3Screen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);
    final atCap = state.locations.length >= OnboardingState.maxLocations;

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: ZapColors.bgPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: ZapColors.textPrimary),
          onPressed: () {
            notifier.advanceToStep(2);
            context.go(AppRoutes.onboardingStep2);
          },
        ),
        title: const _StepIndicator(currentStep: 3, totalSteps: 5),
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

                    // Quick-add chips
                    if (!atCap) ...[
                      _QuickAddSection(
                        state: state,
                        notifier: notifier,
                      ),
                      const SizedBox(height: ZapSpacing.xl),
                    ],

                    // Added locations list
                    if (state.locations.isNotEmpty) ...[
                      _LocationList(
                        locations: state.locations,
                        notifier: notifier,
                      ),
                      const SizedBox(height: ZapSpacing.xl),
                    ],

                    // Skip hint
                    if (state.locations.isEmpty)
                      Center(
                        child: Text(
                          'This step is optional — you can skip it.\n'
                          'ZapSafe will learn your safe locations automatically.',
                          style: ZapTypography.bodySmall.copyWith(
                            color: ZapColors.textSecondary,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
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
                // Always enabled — this step is optional
                label: state.locations.isEmpty ? 'Skip' : 'Next',
                onPressed: () {
                  notifier.advanceToStep(4);
                  context.go(AppRoutes.onboardingStep4);
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
          'Trusted Locations',
          style: ZapTypography.displaySmall.copyWith(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Text(
          'Mark places where you feel safe. ZapSafe will verify '
          'your location patterns and auto-learn over time.',
          style: ZapTypography.bodyMedium.copyWith(
            color: ZapColors.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

// ─── Quick-add chips ──────────────────────────────────────────────────────────

class _QuickAddSection extends StatelessWidget {
  const _QuickAddSection({required this.state, required this.notifier});
  final OnboardingState state;
  final OnboardingNotifier notifier;

  static const _icons = {
    'Home': Icons.home_rounded,
    'Work': Icons.work_rounded,
    'Gym': Icons.fitness_center_rounded,
    'School': Icons.school_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick add',
            style: ZapTypography.labelLarge.copyWith(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: ZapSpacing.md),
          Wrap(
            spacing: ZapSpacing.sm,
            runSpacing: ZapSpacing.sm,
            children: [
              ...OnboardingLocation.presets.map((label) {
                final added = state.hasLocation(label);
                return _PresetChip(
                  label: label,
                  icon: _icons[label] ?? Icons.place_rounded,
                  added: added,
                  onTap: added ? null : () => notifier.addPresetLocation(label),
                );
              }),
              _PresetChip(
                label: 'Custom',
                icon: Icons.add_location_rounded,
                added: false,
                onTap: () => notifier.addCustomLocation(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.icon,
    required this.added,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool added;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: ZapSpacing.md,
          vertical: ZapSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: added ? ZapColors.safe.withOpacity(0.15) : ZapColors.bgSurface,
          border: Border.all(
            color: added ? ZapColors.safe : ZapColors.border,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              added ? Icons.check_rounded : icon,
              size: 16,
              color: added ? ZapColors.safe : ZapColors.textSecondary,
            ),
            const SizedBox(width: ZapSpacing.xs),
            Text(
              label,
              style: ZapTypography.labelMedium.copyWith(
                color: added ? ZapColors.safe : ZapColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Added locations list ─────────────────────────────────────────────────────

class _LocationList extends StatelessWidget {
  const _LocationList({required this.locations, required this.notifier});
  final List<OnboardingLocation> locations;
  final OnboardingNotifier notifier;

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.place_rounded, color: ZapColors.safe, size: 18),
              const SizedBox(width: ZapSpacing.sm),
              Text(
                'Your trusted locations',
                style: ZapTypography.labelLarge.copyWith(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${locations.length} / ${OnboardingState.maxLocations}',
                style: ZapTypography.bodySmall.copyWith(
                  color: ZapColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          ...locations.asMap().entries.map((entry) {
            final idx = entry.key;
            final loc = entry.value;
            return _LocationRow(
              key: ValueKey('loc_$idx'),
              location: loc,
              index: idx,
              notifier: notifier,
            );
          }),
        ],
      ),
    );
  }
}

class _LocationRow extends StatefulWidget {
  const _LocationRow({
    super.key,
    required this.location,
    required this.index,
    required this.notifier,
  });
  final OnboardingLocation location;
  final int index;
  final OnboardingNotifier notifier;

  @override
  State<_LocationRow> createState() => _LocationRowState();
}

class _LocationRowState extends State<_LocationRow> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.location.customName);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCustom = widget.location.label == 'Custom';

    return Padding(
      padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: ZapColors.safe.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.place_rounded, color: ZapColors.safe, size: 16),
          ),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: isCustom
                ? TextField(
                    key: Key('custom_name_${widget.index}'),
                    controller: _ctrl,
                    onChanged: (v) =>
                        widget.notifier.updateLocationName(widget.index, v),
                    style: ZapTypography.bodyMedium
                        .copyWith(color: ZapColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Enter location name',
                      hintStyle: ZapTypography.bodyMedium
                          .copyWith(color: ZapColors.textSecondary),
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
                        borderSide:
                            const BorderSide(color: ZapColors.safe),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: ZapSpacing.md,
                        vertical: ZapSpacing.sm,
                      ),
                    ),
                  )
                : Text(
                    widget.location.displayName,
                    style: ZapTypography.bodyMedium
                        .copyWith(color: ZapColors.textPrimary),
                  ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_rounded,
                color: ZapColors.danger, size: 20),
            tooltip: 'Remove',
            onPressed: () =>
                widget.notifier.removeLocation(widget.index),
          ),
        ],
      ),
    );
  }
}
