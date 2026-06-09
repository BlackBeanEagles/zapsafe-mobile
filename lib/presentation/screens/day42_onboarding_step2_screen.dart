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

/// Day 42 — Onboarding Step 2: Emergency Contacts.
///
/// Route: /onboarding/step2
/// Prev:  /onboarding/step1
/// Next:  /onboarding/step3 (Day 43)
///
/// Tier 1: 1 required contact (e.g. closest person).
/// Tier 2: up to 2 optional trusted contacts.
/// Tier 3: up to 2 optional backup contacts.
///
/// "Next" is disabled until at least one Tier-1 contact has a valid
/// name (non-empty) and phone (≥ 7 digits).
class Day42OnboardingStep2Screen extends ConsumerWidget {
  const Day42OnboardingStep2Screen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: ZapColors.bgPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: ZapColors.textPrimary),
          onPressed: () {
            notifier.advanceToStep(1);
            context.go(AppRoutes.onboardingStep1);
          },
        ),
        title: const _StepIndicator(currentStep: 2, totalSteps: 5),
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
                    // Header
                    const _StepHeader(),
                    const SizedBox(height: ZapSpacing.xl),

                    // Tier 1
                    _TierSection(
                      tier: 1,
                      label: 'Tier 1 — Primary Contact',
                      subtitle: 'First person alerted when SOS fires.',
                      accentColor: ZapColors.danger,
                      icon: Icons.star_rounded,
                      contacts: state.tier(1),
                      allContacts: state.contacts,
                      notifier: notifier,
                    ),
                    const SizedBox(height: ZapSpacing.xl),

                    // Tier 2
                    _TierSection(
                      tier: 2,
                      label: 'Tier 2 — Trusted Contacts',
                      subtitle: 'Alerted if Tier 1 doesn\'t respond in 2 min.',
                      accentColor: ZapColors.warning,
                      icon: Icons.people_rounded,
                      contacts: state.tier(2),
                      allContacts: state.contacts,
                      notifier: notifier,
                    ),
                    const SizedBox(height: ZapSpacing.xl),

                    // Tier 3
                    _TierSection(
                      tier: 3,
                      label: 'Tier 3 — Backup Contacts',
                      subtitle: 'Final escalation layer.',
                      accentColor: ZapColors.info,
                      icon: Icons.shield_rounded,
                      contacts: state.tier(3),
                      allContacts: state.contacts,
                      notifier: notifier,
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
                onPressed: state.hasRequiredContact
                    ? () {
                        notifier.advanceToStep(3);
                        context.go(AppRoutes.onboardingStep3);
                      }
                    : null,
                variant: ZapButtonVariant.elevated,
              ),
            ),
          ],
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

// ─── Header ──────────────────────────────────────────────────────────────────

class _StepHeader extends StatelessWidget {
  const _StepHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Emergency Contacts',
          style: ZapTypography.displaySmall.copyWith(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Text(
          'Who should ZapSafe call when you need help?\n'
          'Add at least one Tier 1 contact to continue.',
          style: ZapTypography.bodyMedium.copyWith(
            color: ZapColors.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

// ─── Tier section ─────────────────────────────────────────────────────────────

class _TierSection extends StatelessWidget {
  const _TierSection({
    required this.tier,
    required this.label,
    required this.subtitle,
    required this.accentColor,
    required this.icon,
    required this.contacts,
    required this.allContacts,
    required this.notifier,
  });

  final int tier;
  final String label;
  final String subtitle;
  final Color accentColor;
  final IconData icon;
  final List<OnboardingContact> contacts;
  final List<OnboardingContact> allContacts;
  final OnboardingNotifier notifier;

  static const _caps = {1: 1, 2: 2, 3: 2};

  @override
  Widget build(BuildContext context) {
    final cap = _caps[tier] ?? 2;
    final canAdd = contacts.length < cap;

    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tier header
          Row(
            children: [
              Icon(icon, color: accentColor, size: 20),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: ZapTypography.labelLarge.copyWith(
                        color: ZapColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: ZapTypography.bodySmall.copyWith(
                        color: ZapColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Contact rows
          if (contacts.isNotEmpty) ...[
            const SizedBox(height: ZapSpacing.md),
            ...contacts.map((contact) {
              final idx = allContacts.indexOf(contact);
              return _ContactRow(
                key: ValueKey('${tier}_$idx'),
                contact: contact,
                index: idx,
                accentColor: accentColor,
                notifier: notifier,
              );
            }),
          ],

          // Add button
          if (canAdd) ...[
            const SizedBox(height: ZapSpacing.md),
            InkWell(
              onTap: () => notifier.addContact(tier),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: ZapSpacing.sm,
                  horizontal: ZapSpacing.md,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: accentColor.withOpacity(0.4)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, color: accentColor, size: 18),
                    const SizedBox(width: ZapSpacing.xs),
                    Text(
                      'Add contact',
                      style: ZapTypography.labelMedium.copyWith(
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Contact row ─────────────────────────────────────────────────────────────

class _ContactRow extends StatefulWidget {
  const _ContactRow({
    super.key,
    required this.contact,
    required this.index,
    required this.accentColor,
    required this.notifier,
  });

  final OnboardingContact contact;
  final int index;
  final Color accentColor;
  final OnboardingNotifier notifier;

  @override
  State<_ContactRow> createState() => _ContactRowState();
}

class _ContactRowState extends State<_ContactRow> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.contact.name);
    _phoneCtrl = TextEditingController(text: widget.contact.phone);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _onNameChanged(String v) {
    widget.notifier.updateContact(
      widget.index,
      widget.contact.copyWith(name: v),
    );
  }

  void _onPhoneChanged(String v) {
    widget.notifier.updateContact(
      widget.index,
      widget.contact.copyWith(phone: v),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ZapSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: [
                _Field(
                  key: Key('name_${widget.index}'),
                  controller: _nameCtrl,
                  hint: 'Full name',
                  icon: Icons.person_rounded,
                  accentColor: widget.accentColor,
                  onChanged: _onNameChanged,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: ZapSpacing.sm),
                _Field(
                  key: Key('phone_${widget.index}'),
                  controller: _phoneCtrl,
                  hint: 'Phone number',
                  icon: Icons.phone_rounded,
                  accentColor: widget.accentColor,
                  onChanged: _onPhoneChanged,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                ),
              ],
            ),
          ),
          const SizedBox(width: ZapSpacing.sm),
          IconButton(
            icon: const Icon(Icons.remove_circle_rounded, color: ZapColors.danger),
            tooltip: 'Remove',
            onPressed: () => widget.notifier.removeContact(widget.index),
          ),
        ],
      ),
    );
  }
}

// ─── Text field ───────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  const _Field({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    required this.accentColor,
    required this.onChanged,
    this.keyboardType,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final Color accentColor;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      style: ZapTypography.bodyMedium.copyWith(color: ZapColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: ZapTypography.bodyMedium.copyWith(
          color: ZapColors.textSecondary,
        ),
        prefixIcon: Icon(icon, color: accentColor, size: 18),
        filled: true,
        fillColor: ZapColors.bgSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: ZapColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: ZapColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: accentColor),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: ZapSpacing.md,
          vertical: ZapSpacing.sm,
        ),
      ),
    );
  }
}
