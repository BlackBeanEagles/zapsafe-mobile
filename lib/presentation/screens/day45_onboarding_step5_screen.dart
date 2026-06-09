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

/// Day 45 — Onboarding Step 5: Review + Complete.
///
/// Route: /onboarding/step5
/// Prev:  /onboarding/step4
/// Next:  /dashboard
///
/// Summarises everything collected in Steps 1-4. Always-enabled CTA.
/// Calls completeOnboarding() then navigates to /dashboard.
/// Backend POST wired once /api/v1/onboarding/complete/ is live.
class Day45OnboardingStep5Screen extends ConsumerStatefulWidget {
  const Day45OnboardingStep5Screen({super.key});

  @override
  ConsumerState<Day45OnboardingStep5Screen> createState() =>
      _Day45OnboardingStep5ScreenState();
}

class _Day45OnboardingStep5ScreenState
    extends ConsumerState<Day45OnboardingStep5Screen> {
  bool _syncing = false;

  Future<void> _completeSetup() async {
    setState(() => _syncing = true);
    // Stub delay — real POST to /api/v1/onboarding/complete/ wired Day 46+.
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    ref.read(onboardingProvider.notifier).completeOnboarding();
    if (context.mounted) context.go(AppRoutes.dashboard);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);
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
            notifier.advanceToStep(4);
            context.go(AppRoutes.onboardingStep4);
          },
        ),
        title: const _StepIndicator(currentStep: 5, totalSteps: 5),
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
                    const _ReviewHeader(),
                    const SizedBox(height: ZapSpacing.xl),

                    _ContactsReviewCard(
                      contacts: state.contacts,
                      onEdit: () {
                        notifier.advanceToStep(2);
                        context.go(AppRoutes.onboardingStep2);
                      },
                    ),
                    const SizedBox(height: ZapSpacing.lg),

                    _LocationsReviewCard(
                      locations: state.locations,
                      onEdit: () {
                        notifier.advanceToStep(3);
                        context.go(AppRoutes.onboardingStep3);
                      },
                    ),
                    const SizedBox(height: ZapSpacing.lg),

                    _AccessibilityReviewCard(
                      a11y: state.accessibility,
                      onEdit: () {
                        notifier.advanceToStep(4);
                        context.go(AppRoutes.onboardingStep4);
                      },
                    ),

                    const SizedBox(height: ZapSpacing.xxxl),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                ZapSpacing.lg, 0, ZapSpacing.lg, ZapSpacing.xl,
              ),
              child: ZapButton(
                label: 'Complete Setup',
                onPressed: _syncing ? null : _completeSetup,
                isLoading: _syncing,
                variant: ZapButtonVariant.elevated,
                fullWidth: true,
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

class _ReviewHeader extends StatelessWidget {
  const _ReviewHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Review',
          style: ZapTypography.displaySmall.copyWith(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Text(
          'Everything looks good? Tap Complete Setup to activate ZapSafe.',
          style: ZapTypography.bodyMedium.copyWith(
            color: ZapColors.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

// ─── Contacts review card ─────────────────────────────────────────────────────

class _ContactsReviewCard extends StatelessWidget {
  const _ContactsReviewCard({
    required this.contacts,
    required this.onEdit,
  });

  final List<OnboardingContact> contacts;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      key: const Key('contacts_review_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people_alt_rounded,
                  color: ZapColors.warning, size: 20),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: Text(
                  'Emergency Contacts',
                  style: ZapTypography.labelLarge.copyWith(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: onEdit,
                child: Text(
                  'Edit',
                  style: ZapTypography.labelMedium.copyWith(
                    color: ZapColors.info,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.sm),
          if (contacts.isEmpty)
            Text(
              'No contacts added',
              style: ZapTypography.bodySmall.copyWith(
                color: ZapColors.textSecondary,
              ),
            )
          else
            ...contacts.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: ZapSpacing.xs),
                  child: Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: ZapColors.warning.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'T${c.tier}',
                          style: ZapTypography.bodySmall.copyWith(
                            color: ZapColors.warning,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: ZapSpacing.sm),
                      Expanded(
                        child: Text(
                          c.name.trim().isEmpty ? '(unnamed)' : c.name,
                          style: ZapTypography.bodySmall.copyWith(
                            color: ZapColors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        c.phone,
                        style: ZapTypography.bodySmall.copyWith(
                          color: ZapColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}

// ─── Locations review card ────────────────────────────────────────────────────

class _LocationsReviewCard extends StatelessWidget {
  const _LocationsReviewCard({
    required this.locations,
    required this.onEdit,
  });

  final List<OnboardingLocation> locations;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      key: const Key('locations_review_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.place_rounded,
                  color: ZapColors.safe, size: 20),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: Text(
                  'Trusted Locations',
                  style: ZapTypography.labelLarge.copyWith(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: onEdit,
                child: Text(
                  'Edit',
                  style: ZapTypography.labelMedium.copyWith(
                    color: ZapColors.info,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.sm),
          if (locations.isEmpty)
            Text(
              'No locations added',
              style: ZapTypography.bodySmall.copyWith(
                color: ZapColors.textSecondary,
              ),
            )
          else
            Wrap(
              spacing: ZapSpacing.xs,
              runSpacing: ZapSpacing.xs,
              children: locations
                  .map((l) => Chip(
                        label: Text(
                          l.displayName,
                          style: ZapTypography.bodySmall.copyWith(
                            color: ZapColors.textPrimary,
                          ),
                        ),
                        backgroundColor: ZapColors.bgSurface,
                        side: BorderSide.none,
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

// ─── Accessibility review card ────────────────────────────────────────────────

class _AccessibilityReviewCard extends StatelessWidget {
  const _AccessibilityReviewCard({
    required this.a11y,
    required this.onEdit,
  });

  final OnboardingAccessibility a11y;
  final VoidCallback onEdit;

  String get _fontScaleLabel {
    if (a11y.fontScale <= 1.0) return 'Normal (1×)';
    if (a11y.fontScale <= 1.25) return 'Large (1.25×)';
    if (a11y.fontScale <= 1.5) return 'Larger (1.5×)';
    if (a11y.fontScale <= 1.75) return 'X-Large (1.75×)';
    return 'XX-Large (2×)';
  }

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      key: const Key('accessibility_review_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.accessibility_new_rounded,
                  color: ZapColors.info, size: 20),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: Text(
                  'Accessibility',
                  style: ZapTypography.labelLarge.copyWith(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: onEdit,
                child: Text(
                  'Edit',
                  style: ZapTypography.labelMedium.copyWith(
                    color: ZapColors.info,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.sm),
          _A11yRow(label: 'Language', value: a11y.languageName),
          _A11yRow(
            label: 'Simple mode',
            value: a11y.simpleMode ? 'On' : 'Off',
          ),
          _A11yRow(
            label: 'High contrast',
            value: a11y.highContrast ? 'On' : 'Off',
          ),
          _A11yRow(label: 'Text size', value: _fontScaleLabel),
        ],
      ),
    );
  }
}

class _A11yRow extends StatelessWidget {
  const _A11yRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ZapSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: ZapTypography.bodySmall.copyWith(
                color: ZapColors.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: ZapTypography.bodySmall.copyWith(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
