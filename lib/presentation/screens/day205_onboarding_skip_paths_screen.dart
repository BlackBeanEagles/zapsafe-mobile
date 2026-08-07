/// Day 205 — Onboarding Skip Paths
///
/// Section A (Days 201-220): Medical Card and Tier 2 contact are skippable
/// with "Skip for now" — Protection Score reflects incomplete setup.
///
/// Tag: 🟣 POLISH — interactive 5-step onboarding mock + score deltas.
///
/// Route: [AppRoutes.onboardingSkipPaths] → `/onboarding-skip-paths`
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';

// ── Score model ───────────────────────────────────────────────────────────────
/// Onboarding Protection Score — mirrors backend weighting (mock).
int onboardingProtectionScore({
  required bool termsAccepted,
  required bool tier1Added,
  required bool tier2Added,
  required bool medicalAdded,
}) {
  if (!termsAccepted) return 0;
  var score = 15; // welcome + terms
  if (tier1Added) score += 25;
  if (tier2Added) score += 10;
  if (medicalAdded) score += 15;
  return score;
}

const _kTier2Delta = 10;
const _kMedicalDelta = 15;
const _kMaxOnboardingScore = 65;

// ── Providers ─────────────────────────────────────────────────────────────────
final _d205TabProvider = StateProvider<int>((ref) => 0);
final _d205StepProvider = StateProvider<int>((ref) => 0);
final _d205TermsProvider = StateProvider<bool>((ref) => false);
final _d205Tier1NameProvider = StateProvider<String>((ref) => '');
final _d205Tier1PhoneProvider = StateProvider<String>((ref) => '');
final _d205Tier2SkippedProvider = StateProvider<bool>((ref) => false);
final _d205Tier2NameProvider = StateProvider<String>((ref) => '');
final _d205Tier2PhoneProvider = StateProvider<String>((ref) => '');
final _d205MedicalSkippedProvider = StateProvider<bool>((ref) => false);
final _d205BloodTypeProvider = StateProvider<String>((ref) => '');
final _d205AllergiesProvider = StateProvider<String>((ref) => '');
final _d205CompletedProvider = StateProvider<bool>((ref) => false);

const _kTabs = ['Live Flow', 'Score Breakdown', 'Spec'];

const _kSteps = [
  _OnboardingStep(
    title: 'Welcome',
    subtitle: 'Terms & value prop',
    icon: Icons.waving_hand_rounded,
    color: ZapColors.safe,
  ),
  _OnboardingStep(
    title: 'Tier 1 Contact',
    subtitle: 'Required — your primary responder',
    icon: Icons.person_pin_rounded,
    color: ZapColors.danger,
  ),
  _OnboardingStep(
    title: 'Tier 2 Contact',
    subtitle: 'Optional — backup trusted contact',
    icon: Icons.people_alt_rounded,
    color: ZapColors.warning,
    skippable: true,
    scoreDelta: _kTier2Delta,
  ),
  _OnboardingStep(
    title: 'Medical Card',
    subtitle: 'Optional — shared during SOS',
    icon: Icons.medical_information_rounded,
    color: ZapColors.info,
    skippable: true,
    scoreDelta: _kMedicalDelta,
  ),
  _OnboardingStep(
    title: 'Review',
    subtitle: 'Protection Score summary',
    icon: Icons.check_circle_outline_rounded,
    color: ZapColors.safe,
  ),
];

class _OnboardingStep {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool skippable;
  final int scoreDelta;

  const _OnboardingStep({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.skippable = false,
    this.scoreDelta = 0,
  });
}

// ── Screen ────────────────────────────────────────────────────────────────────
class Day205OnboardingSkipPathsScreen extends ConsumerWidget {
  const Day205OnboardingSkipPathsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d205TabProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 205 · Onboarding Skip Paths'),
      ),
      body: Column(
        children: [
          _TabBar(
            tab: tab,
            onSelect: (i) => ref.read(_d205TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (tab) {
              0 => const _LiveFlowTab(),
              1 => const _ScoreBreakdownTab(),
              _ => const _SpecTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Live Flow ──────────────────────────────────────────────────────────
class _LiveFlowTab extends ConsumerWidget {
  const _LiveFlowTab();

  bool _tier1Valid(WidgetRef ref) {
    final name = ref.read(_d205Tier1NameProvider).trim();
    final phone = ref.read(_d205Tier1PhoneProvider).trim();
    return name.length >= 2 && phone.length >= 10;
  }

  bool _tier2Valid(WidgetRef ref) {
    final name = ref.read(_d205Tier2NameProvider).trim();
    final phone = ref.read(_d205Tier2PhoneProvider).trim();
    return name.length >= 2 && phone.length >= 10;
  }

  bool _canAdvance(WidgetRef ref, int step) {
    switch (step) {
      case 0:
        return ref.watch(_d205TermsProvider);
      case 1:
        return _tier1Valid(ref);
      case 2:
        final skipped = ref.watch(_d205Tier2SkippedProvider);
        return skipped || _tier2Valid(ref);
      case 3:
        final skipped = ref.watch(_d205MedicalSkippedProvider);
        final blood = ref.watch(_d205BloodTypeProvider).trim();
        return skipped || blood.isNotEmpty;
      case 4:
        return true;
      default:
        return false;
    }
  }

  int _score(WidgetRef ref) {
    final tier2Skipped = ref.watch(_d205Tier2SkippedProvider);
    final medicalSkipped = ref.watch(_d205MedicalSkippedProvider);
    return onboardingProtectionScore(
      termsAccepted: ref.watch(_d205TermsProvider),
      tier1Added: _tier1Valid(ref),
      tier2Added: !tier2Skipped && _tier2Valid(ref),
      medicalAdded:
          !medicalSkipped && ref.watch(_d205BloodTypeProvider).trim().isNotEmpty,
    );
  }

  void _skipTier2(WidgetRef ref) {
    ref.read(_d205Tier2SkippedProvider.notifier).state = true;
    ref.read(_d205Tier2NameProvider.notifier).state = '';
    ref.read(_d205Tier2PhoneProvider.notifier).state = '';
    ref.read(_d205StepProvider.notifier).state = 3;
  }

  void _skipMedical(WidgetRef ref) {
    ref.read(_d205MedicalSkippedProvider.notifier).state = true;
    ref.read(_d205BloodTypeProvider.notifier).state = '';
    ref.read(_d205AllergiesProvider.notifier).state = '';
    ref.read(_d205StepProvider.notifier).state = 4;
  }

  void _reset(WidgetRef ref) {
    ref.read(_d205StepProvider.notifier).state = 0;
    ref.read(_d205TermsProvider.notifier).state = false;
    ref.read(_d205Tier1NameProvider.notifier).state = '';
    ref.read(_d205Tier1PhoneProvider.notifier).state = '';
    ref.read(_d205Tier2SkippedProvider.notifier).state = false;
    ref.read(_d205Tier2NameProvider.notifier).state = '';
    ref.read(_d205Tier2PhoneProvider.notifier).state = '';
    ref.read(_d205MedicalSkippedProvider.notifier).state = false;
    ref.read(_d205BloodTypeProvider.notifier).state = '';
    ref.read(_d205AllergiesProvider.notifier).state = '';
    ref.read(_d205CompletedProvider.notifier).state = false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step = ref.watch(_d205StepProvider);
    final score = _score(ref);
    final completed = ref.watch(_d205CompletedProvider);
    final current = _kSteps[step];

    if (completed) {
      return _CompletionView(
        score: score,
        onRestart: () => _reset(ref),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: ZapColors.info.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: ZapColors.info.withOpacity(0.35)),
          ),
          child: const Text(
            '🟣 POLISH · Section A Day 5/20 · Tier 2 + Medical Card skippable',
            style: TextStyle(color: ZapColors.info, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        _FlowDocHeader(),
        const SizedBox(height: ZapSpacing.lg),
        _ProgressBar(step: step),
        const SizedBox(height: ZapSpacing.md),
        _ScoreStrip(score: score),
        const SizedBox(height: ZapSpacing.lg),
        _StepCard(step: current, index: step),
        const SizedBox(height: ZapSpacing.lg),
        _StepContent(step: step),
        const SizedBox(height: ZapSpacing.xl),
        Row(
          children: [
            if (step > 0)
              Expanded(
                child: Semantics(
                  label: 'Back to previous step',
                  button: true,
                  child: OutlinedButton(
                    onPressed: () =>
                        ref.read(_d205StepProvider.notifier).state = step - 1,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 75),
                    ),
                    child: const Text('Back'),
                  ),
                ),
              ),
            if (step > 0) const SizedBox(width: ZapSpacing.md),
            Expanded(
              flex: 2,
              child: Semantics(
                label: step == 4 ? 'Complete onboarding' : 'Next step',
                button: true,
                child: FilledButton(
                  onPressed: _canAdvance(ref, step)
                      ? () {
                          if (step == 4) {
                            ref.read(_d205CompletedProvider.notifier).state =
                                true;
                          } else {
                            ref.read(_d205StepProvider.notifier).state =
                                step + 1;
                          }
                        }
                      : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 75),
                    backgroundColor: ZapColors.safe,
                    disabledBackgroundColor: ZapColors.bgElevated,
                  ),
                  child: Text(step == 4 ? 'Finish setup' : 'Next'),
                ),
              ),
            ),
          ],
        ),
        if (current.skippable) ...[
          const SizedBox(height: ZapSpacing.md),
          Semantics(
            label: 'Skip for now',
            button: true,
            child: TextButton(
              onPressed: () {
                if (step == 2) {
                  _skipTier2(ref);
                } else if (step == 3) {
                  _skipMedical(ref);
                }
              },
              style: TextButton.styleFrom(
                minimumSize: const Size(double.infinity, 75),
              ),
              child: Text(
                'Skip for now · miss +${current.scoreDelta} score',
                style: const TextStyle(color: ZapColors.textSecondary),
              ),
            ),
          ),
        ],
        const SizedBox(height: ZapSpacing.lg),
        Semantics(
          label: 'Reset onboarding demo',
          button: true,
          child: TextButton(
            onPressed: () => _reset(ref),
            child: const Text(
              'Reset demo',
              style: TextStyle(color: ZapColors.textMuted, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }
}

class _FlowDocHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ZapColors.border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Onboarding flow update (Day 205)',
            style: TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: ZapSpacing.xs),
          Text(
            '5 steps · Tier 1 required · Tier 2 + Medical Card show '
            '"Skip for now" · incomplete items lower Protection Score '
            'and appear as dashboard suggestions (Day 202).',
            style: TextStyle(
              color: ZapColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final int step;

  const _ProgressBar({required this.step});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_kSteps.length, (i) {
        final done = i < step;
        final active = i == step;
        final color = done || active ? ZapColors.safe : ZapColors.disabled;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < _kSteps.length - 1 ? 4 : 0),
            height: 4,
            decoration: BoxDecoration(
              color: color.withOpacity(done ? 1 : active ? 0.8 : 0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}

class _ScoreStrip extends StatelessWidget {
  final int score;

  const _ScoreStrip({required this.score});

  @override
  Widget build(BuildContext context) {
    final band = score >= 60
        ? ZapColors.safe
        : score >= 40
            ? ZapColors.warning
            : ZapColors.danger;

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: band.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: band.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.shield_rounded, color: band, size: 28),
          const SizedBox(width: ZapSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Protection Score: $score / $_kMaxOnboardingScore',
                  style: TextStyle(
                    color: band,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                Text(
                  score < 40
                      ? 'Complete Tier 1 to reach minimum 40'
                      : score < _kMaxOnboardingScore
                          ? 'Add skipped items later from Settings'
                          : 'Maximum onboarding score reached',
                  style: const TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final _OnboardingStep step;
  final int index;

  const _StepCard({required this.step, required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: step.color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: step.color.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: step.color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(step.icon, color: step.color, size: 22),
          ),
          const SizedBox(width: ZapSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Step ${index + 1} · ${step.title}',
                  style: TextStyle(
                    color: step.color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  step.subtitle,
                  style: const TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (step.skippable)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: ZapColors.bgElevated,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: ZapColors.border),
              ),
              child: Text(
                '+${step.scoreDelta}',
                style: TextStyle(
                  color: step.color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StepContent extends ConsumerWidget {
  final int step;

  const _StepContent({required this.step});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (step) {
      0 => _WelcomeStep(),
      1 => _Tier1Step(),
      2 => _Tier2Step(),
      3 => _MedicalStep(),
      _ => _ReviewStep(),
    };
  }
}

class _WelcomeStep extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accepted = ref.watch(_d205TermsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Your safety, always on',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          'ZapSafe listens for distress, alerts your contacts, and shares '
          'your location during emergencies.',
          style: TextStyle(color: ZapColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          height: 120,
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.border),
          ),
          child: const SingleChildScrollView(
            child: Text(
              'Terms & Conditions (excerpt)\n\n'
              'By continuing you agree to ZapSafe processing location and '
              'audio for safety purposes under DPDP §6. You control who '
              'receives SOS alerts. Data is encrypted at rest.',
              style: TextStyle(
                color: ZapColors.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        CheckboxListTile(
          value: accepted,
          onChanged: (v) =>
              ref.read(_d205TermsProvider.notifier).state = v ?? false,
          activeColor: ZapColors.safe,
          title: const Text(
            'I agree to the Terms & Privacy Policy',
            style: TextStyle(color: ZapColors.textPrimary, fontSize: 14),
          ),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        const _ScoreDeltaHint(text: '+15 when you accept terms'),
      ],
    );
  }
}

class _Tier1Step extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _OnboardingField(
          label: 'Tier 1 name',
          hint: 'Primary emergency contact',
          value: ref.watch(_d205Tier1NameProvider),
          onChanged: (v) => ref.read(_d205Tier1NameProvider.notifier).state = v,
        ),
        const SizedBox(height: ZapSpacing.md),
        _OnboardingField(
          label: 'Phone number',
          hint: '+91 98765 43210',
          keyboard: TextInputType.phone,
          value: ref.watch(_d205Tier1PhoneProvider),
          onChanged: (v) =>
              ref.read(_d205Tier1PhoneProvider.notifier).state = v,
        ),
        const SizedBox(height: ZapSpacing.md),
        const _RequiredBanner(text: 'Tier 1 is required — cannot skip'),
        const _ScoreDeltaHint(text: '+25 when Tier 1 contact is valid'),
      ],
    );
  }
}

class _Tier2Step extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skipped = ref.watch(_d205Tier2SkippedProvider);

    if (skipped) {
      return const _SkippedBanner(
        item: 'Tier 2 contact',
        delta: _kTier2Delta,
      );
    }

    return Column(
      children: [
        const Text(
          'Add a backup contact who receives SMS if Tier 1 doesn\'t respond. '
          'You can skip and add later from Contacts.',
          style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: ZapSpacing.md),
        _OnboardingField(
          label: 'Tier 2 name',
          hint: 'Backup contact',
          value: ref.watch(_d205Tier2NameProvider),
          onChanged: (v) => ref.read(_d205Tier2NameProvider.notifier).state = v,
        ),
        const SizedBox(height: ZapSpacing.md),
        _OnboardingField(
          label: 'Phone number',
          hint: '+91 91234 56789',
          keyboard: TextInputType.phone,
          value: ref.watch(_d205Tier2PhoneProvider),
          onChanged: (v) =>
              ref.read(_d205Tier2PhoneProvider.notifier).state = v,
        ),
        const SizedBox(height: ZapSpacing.md),
        const _ScoreDeltaHint(
          text: '+10 if you add Tier 2 · tap Skip for now to defer',
          color: ZapColors.warning,
        ),
      ],
    );
  }
}

class _MedicalStep extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skipped = ref.watch(_d205MedicalSkippedProvider);

    if (skipped) {
      return const _SkippedBanner(
        item: 'Medical card',
        delta: _kMedicalDelta,
      );
    }

    return Column(
      children: [
        const Text(
          'Shared with first responders during SOS. Blood type is the '
          'minimum — allergies and meds are optional.',
          style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: ZapSpacing.md),
        _OnboardingField(
          label: 'Blood type',
          hint: 'e.g. O+',
          value: ref.watch(_d205BloodTypeProvider),
          onChanged: (v) => ref.read(_d205BloodTypeProvider.notifier).state = v,
        ),
        const SizedBox(height: ZapSpacing.md),
        _OnboardingField(
          label: 'Allergies (optional)',
          hint: 'Penicillin, peanuts…',
          value: ref.watch(_d205AllergiesProvider),
          onChanged: (v) =>
              ref.read(_d205AllergiesProvider.notifier).state = v,
          maxLines: 2,
        ),
        const SizedBox(height: ZapSpacing.md),
        const _ScoreDeltaHint(
          text: '+15 if you add medical card · Skip for now OK',
          color: ZapColors.info,
        ),
      ],
    );
  }
}

class _ReviewStep extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tier2Skipped = ref.watch(_d205Tier2SkippedProvider);
    final medicalSkipped = ref.watch(_d205MedicalSkippedProvider);
    final tier1Name = ref.watch(_d205Tier1NameProvider).trim();
    final tier2Name = ref.watch(_d205Tier2NameProvider).trim();
    final blood = ref.watch(_d205BloodTypeProvider).trim();

    final rows = [
      ('Terms accepted', 'Yes', true),
      ('Tier 1 contact', tier1Name.isEmpty ? '—' : tier1Name, true),
      (
        'Tier 2 contact',
        tier2Skipped
            ? 'Skipped'
            : tier2Name.isEmpty
                ? '—'
                : tier2Name,
        !tier2Skipped && tier2Name.isNotEmpty,
      ),
      (
        'Medical card',
        medicalSkipped
            ? 'Skipped'
            : blood.isEmpty
                ? '—'
                : blood,
        !medicalSkipped && blood.isNotEmpty,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Review your setup',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        ...rows.map((r) {
          final (label, value, complete) = r;
          final isSkip = value == 'Skipped';
          return Container(
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSkip
                    ? ZapColors.warning.withOpacity(0.5)
                    : complete
                        ? ZapColors.safe.withOpacity(0.4)
                        : ZapColors.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isSkip
                      ? Icons.schedule_rounded
                      : complete
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                  color: isSkip
                      ? ZapColors.warning
                      : complete
                          ? ZapColors.safe
                          : ZapColors.textMuted,
                  size: 20,
                ),
                const SizedBox(width: ZapSpacing.md),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(color: ZapColors.textPrimary),
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: isSkip ? ZapColors.warning : ZapColors.textSecondary,
                    fontSize: 13,
                    fontWeight: isSkip ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        }),
        if (tier2Skipped || medicalSkipped) ...[
          const SizedBox(height: ZapSpacing.sm),
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ZapColors.warning.withOpacity(0.35)),
            ),
            child: Text(
              'Skipped items will show as dashboard suggestions and '
              'lower your Protection Score until completed.',
              style: TextStyle(
                color: ZapColors.warning.withOpacity(0.9),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _CompletionView extends StatelessWidget {
  final int score;
  final VoidCallback onRestart;

  const _CompletionView({required this.score, required this.onRestart});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ZapSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_rounded, color: ZapColors.safe, size: 72),
            const SizedBox(height: ZapSpacing.lg),
            const Text(
              'Onboarding complete',
              style: TextStyle(
                color: ZapColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: ZapSpacing.sm),
            Text(
              'Protection Score: $score',
              style: const TextStyle(
                color: ZapColors.safe,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: ZapSpacing.md),
            const Text(
              'Skipped items can be added from Settings → Profile. '
              'Dashboard banners will remind you (Day 202).',
              textAlign: TextAlign.center,
              style: TextStyle(color: ZapColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: ZapSpacing.xl),
            FilledButton(
              onPressed: onRestart,
              style: FilledButton.styleFrom(
                minimumSize: const Size(200, 75),
                backgroundColor: ZapColors.safe,
              ),
              child: const Text('Run demo again'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────
class _OnboardingField extends StatefulWidget {
  final String label;
  final String hint;
  final String value;
  final ValueChanged<String> onChanged;
  final TextInputType keyboard;
  final int maxLines;

  const _OnboardingField({
    required this.label,
    required this.hint,
    required this.value,
    required this.onChanged,
    this.keyboard = TextInputType.text,
    this.maxLines = 1,
  });

  @override
  State<_OnboardingField> createState() => _OnboardingFieldState();
}

class _OnboardingFieldState extends State<_OnboardingField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _OnboardingField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: ZapSpacing.xs),
        TextField(
          controller: _controller,
          onChanged: widget.onChanged,
          keyboardType: widget.keyboard,
          maxLines: widget.maxLines,
          style: const TextStyle(color: ZapColors.textPrimary),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: const TextStyle(color: ZapColors.textMuted),
            filled: true,
            fillColor: ZapColors.bgCard,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: ZapColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: ZapColors.border),
            ),
            contentPadding: const EdgeInsets.all(ZapSpacing.md),
          ),
        ),
      ],
    );
  }
}

class _ScoreDeltaHint extends StatelessWidget {
  final String text;
  final Color color;

  const _ScoreDeltaHint({required this.text, this.color = ZapColors.safe});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(Icons.trending_up_rounded, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequiredBanner extends StatelessWidget {
  final String text;

  const _RequiredBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.sm),
      decoration: BoxDecoration(
        color: ZapColors.danger.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ZapColors.danger.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: const TextStyle(color: ZapColors.danger, fontSize: 12),
      ),
    );
  }
}

class _SkippedBanner extends StatelessWidget {
  final String item;
  final int delta;

  const _SkippedBanner({required this.item, required this.delta});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color: ZapColors.warning.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ZapColors.warning.withOpacity(0.35)),
      ),
      child: Column(
        children: [
          const Icon(Icons.skip_next_rounded, color: ZapColors.warning, size: 32),
          const SizedBox(height: ZapSpacing.sm),
          Text(
            '$item skipped',
            style: const TextStyle(
              color: ZapColors.warning,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Protection Score −$delta · add later from Settings',
            style: const TextStyle(color: ZapColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ── Tab 1: Score Breakdown ────────────────────────────────────────────────────
class _ScoreBreakdownTab extends ConsumerWidget {
  const _ScoreBreakdownTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final terms = ref.watch(_d205TermsProvider);
    final tier1 = ref.watch(_d205Tier1NameProvider).trim().length >= 2 &&
        ref.watch(_d205Tier1PhoneProvider).trim().length >= 10;
    final tier2Skipped = ref.watch(_d205Tier2SkippedProvider);
    final tier2 = !tier2Skipped &&
        ref.watch(_d205Tier2NameProvider).trim().length >= 2 &&
        ref.watch(_d205Tier2PhoneProvider).trim().length >= 10;
    final medicalSkipped = ref.watch(_d205MedicalSkippedProvider);
    final medical =
        !medicalSkipped && ref.watch(_d205BloodTypeProvider).trim().isNotEmpty;

    final score = onboardingProtectionScore(
      termsAccepted: terms,
      tier1Added: tier1,
      tier2Added: tier2,
      medicalAdded: medical,
    );

    final components = [
      _ScoreRow('Welcome + terms', 15, terms),
      _ScoreRow('Tier 1 contact', 25, tier1, required: true),
      _ScoreRow('Tier 2 contact', _kTier2Delta, tier2, skipped: tier2Skipped),
      _ScoreRow('Medical card', _kMedicalDelta, medical, skipped: medicalSkipped),
    ];

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        _ScoreStrip(score: score),
        const SizedBox(height: ZapSpacing.xl),
        const Text(
          'Score components',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        ...components.map((c) => _ScoreComponentCard(row: c)),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.border),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Minimum viable onboarding',
                style: TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: ZapSpacing.xs),
              Text(
                'Terms + Tier 1 = 40 points. Users who skip Tier 2 and '
                'Medical Card land at 40 and see "+10" / "+15" next-actions '
                'on the Protection Score screen (Day 59).',
                style: TextStyle(
                  color: ZapColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Semantics(
          label: 'Copy score formula',
          button: true,
          child: OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(
                const ClipboardData(
                  text: 'score = 15 (terms) + 25 (tier1) + 10 (tier2) + 15 (medical)',
                ),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Formula copied')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy score formula'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 75),
            ),
          ),
        ),
      ],
    );
  }
}

class _ScoreRow {
  final String label;
  final int points;
  final bool earned;
  final bool required;
  final bool skipped;

  _ScoreRow(
    this.label,
    this.points,
    this.earned, {
    this.required = false,
    this.skipped = false,
  });
}

class _ScoreComponentCard extends StatelessWidget {
  final _ScoreRow row;

  const _ScoreComponentCard({required this.row});

  @override
  Widget build(BuildContext context) {
    final statusColor = row.earned
        ? ZapColors.safe
        : row.skipped
            ? ZapColors.warning
            : ZapColors.textMuted;

    return Container(
      margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: row.earned
              ? ZapColors.safe.withOpacity(0.4)
              : ZapColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            row.earned
                ? Icons.check_circle_rounded
                : row.skipped
                    ? Icons.schedule_rounded
                    : Icons.radio_button_unchecked_rounded,
            color: statusColor,
            size: 20,
          ),
          const SizedBox(width: ZapSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.label,
                  style: const TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (row.required)
                  const Text(
                    'Required',
                    style: TextStyle(color: ZapColors.danger, fontSize: 11),
                  ),
                if (row.skipped)
                  const Text(
                    'Skipped for now',
                    style: TextStyle(color: ZapColors.warning, fontSize: 11),
                  ),
              ],
            ),
          ),
          Text(
            row.earned ? '+${row.points}' : '+${row.points} available',
            style: TextStyle(
              color: row.earned ? ZapColors.safe : ZapColors.textMuted,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab 2: Spec ───────────────────────────────────────────────────────────────
class _SpecTab extends StatelessWidget {
  const _SpecTab();

  @override
  Widget build(BuildContext context) {
    const rows = [
      ('Step 1 Welcome', 'Required · terms checkbox · +15 score'),
      ('Step 2 Tier 1', 'Required · cannot skip · +25 score'),
      ('Step 3 Tier 2', 'Optional · "Skip for now" · +10 score'),
      ('Step 4 Medical', 'Optional · "Skip for now" · +15 score'),
      ('Step 5 Review', 'Summary + skipped-item warning'),
      ('Min score', '40 — terms + Tier 1 only'),
      ('Max score', '65 — all steps completed'),
      ('Dashboard tie-in', 'Skipped items → Day 202 suggestion banners'),
    ];

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text(
          'Onboarding skip paths (Days 133-134 → Day 205 polish)',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        ...rows.map(
          (r) => Container(
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ZapColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.$1,
                  style: const TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  r.$2,
                  style: const TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Integration:\n'
          '• onboarding_provider.dart — add skippedTier2 / skippedMedical flags\n'
          '• POST /api/v1/onboarding/complete — send partial setup\n'
          '• protection_score_service — weight medical + tier2 components\n'
          '• Day 202 banners — "Add medical card" / "Add Tier 2 contact"',
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
            'Tomorrow: Day 207 — Live chat offline queue.',
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
                        color: selected ? ZapColors.info : Colors.transparent,
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
