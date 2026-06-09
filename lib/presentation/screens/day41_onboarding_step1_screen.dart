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

/// Day 41 — Onboarding Step 1: Welcome + Terms & Conditions.
///
/// Route: /onboarding/step1
/// Next:  /onboarding/step2 (Day 42)
///
/// "Next" button stays disabled until the user checks the agreement
/// checkbox. Terms text is scrollable inside a bounded card.
class Day41OnboardingStep1Screen extends ConsumerStatefulWidget {
  const Day41OnboardingStep1Screen({super.key});

  @override
  ConsumerState<Day41OnboardingStep1Screen> createState() =>
      _Day41OnboardingStep1ScreenState();
}

class _Day41OnboardingStep1ScreenState
    extends ConsumerState<Day41OnboardingStep1Screen> {
  bool _agreed = false;

  void _onCheckboxChanged(bool? value) {
    final accepted = value ?? false;
    setState(() => _agreed = accepted);
    if (accepted) {
      ref.read(onboardingProvider.notifier).acceptTerms();
    } else {
      ref.read(onboardingProvider.notifier).rejectTerms();
    }
  }

  void _onNext() {
    if (!_agreed) return;
    ref.read(onboardingProvider.notifier).advanceToStep(2);
    context.go(AppRoutes.onboardingStep2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ZapSpacing.lg,
            vertical: ZapSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _StepIndicator(currentStep: 1, totalSteps: 5),
              const SizedBox(height: ZapSpacing.xxxl),

              // Logo + headline
              const _WelcomeHeader(),
              const SizedBox(height: ZapSpacing.xxxl),

              // Scrollable terms
              const Expanded(child: _TermsCard()),
              const SizedBox(height: ZapSpacing.lg),

              // Checkbox
              _AgreementCheckbox(
                agreed: _agreed,
                onChanged: _onCheckboxChanged,
              ),
              const SizedBox(height: ZapSpacing.xl),

              // Next button
              ZapButton(
                label: 'Next',
                onPressed: _agreed ? _onNext : null,
                variant: ZapButtonVariant.elevated,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Step indicator ──────────────────────────────────────────────────────────

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

// ─── Welcome header ──────────────────────────────────────────────────────────

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: ZapColors.danger.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(color: ZapColors.danger, width: 2),
          ),
          child: const Icon(
            Icons.shield_rounded,
            color: ZapColors.danger,
            size: 36,
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Text(
          'Welcome to ZapSafe',
          style: ZapTypography.displaySmall.copyWith(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: ZapSpacing.sm),
        Text(
          'AI-powered personal safety in your pocket.\nLet\'s get you set up.',
          style: ZapTypography.bodyMedium.copyWith(
            color: ZapColors.textSecondary,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ─── Terms card ──────────────────────────────────────────────────────────────

class _TermsCard extends StatelessWidget {
  const _TermsCard();

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Terms & Conditions',
            style: ZapTypography.labelLarge.copyWith(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: ZapSpacing.md),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                _kTermsText,
                style: ZapTypography.bodySmall.copyWith(
                  color: ZapColors.textSecondary,
                  height: 1.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Agreement checkbox ──────────────────────────────────────────────────────

class _AgreementCheckbox extends StatelessWidget {
  const _AgreementCheckbox({
    required this.agreed,
    required this.onChanged,
  });

  final bool agreed;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!agreed),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: ZapSpacing.sm),
        child: Row(
          children: [
            Checkbox(
              value: agreed,
              onChanged: onChanged,
              activeColor: ZapColors.danger,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: ZapSpacing.sm),
            Expanded(
              child: Text(
                'I have read and agree to the Terms & Conditions and Privacy Policy',
                style: ZapTypography.bodySmall.copyWith(
                  color: ZapColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Terms text ──────────────────────────────────────────────────────────────

const _kTermsText = '''
1. ACCEPTANCE OF TERMS

By using ZapSafe, you agree to be bound by these Terms and Conditions. If you do not agree to these terms, please do not use the app.

2. DESCRIPTION OF SERVICE

ZapSafe is a personal safety application that provides AI-powered danger detection, emergency SOS alerts, GPS tracking, and evidence capture features to help protect users in threatening situations.

3. PRIVACY AND DATA

ZapSafe collects location data, audio samples, and device motion data solely for the purpose of detecting danger and enabling SOS alerts. This data is:
- Encrypted end-to-end using AES-256
- Never sold to third parties
- Stored securely and deleted after 90 days
- Accessible only to you and emergency contacts you designate

4. EMERGENCY SERVICES

ZapSafe is not a substitute for calling emergency services directly. Always call your local emergency number (e.g. 112, 999, 911) in a life-threatening situation. ZapSafe supplements but does not replace emergency services.

5. ACCURACY OF AI DETECTION

The AI-powered danger detection system has a target accuracy of 88%+ and may produce false positives or miss genuine threats. ZapSafe cannot guarantee 100% accuracy in all situations.

6. USER RESPONSIBILITIES

You agree to:
- Provide accurate contact information for your emergency contacts
- Not use ZapSafe for any illegal purposes
- Not attempt to tamper with or reverse-engineer the app
- Keep your account credentials secure

7. BIOMETRIC DATA

ZapSafe may use on-device biometric features for verification. Biometric data is processed locally on your device and never transmitted to our servers.

8. LOCATION DATA

ZapSafe requires continuous location access to function correctly during an active SOS event. Location data is only transmitted during active monitoring sessions and SOS events.

9. LIMITATION OF LIABILITY

ZapSafe is provided "as is" without warranty of any kind. To the maximum extent permitted by law, ZapSafe shall not be liable for any indirect, incidental, or consequential damages.

10. CHANGES TO TERMS

ZapSafe reserves the right to update these Terms at any time. Continued use of the app after changes constitutes acceptance of the new Terms.

Last updated: May 2026
''';
