import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/spacing.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _acknowledgedProvider = StateProvider<bool>((ref) => false);
final _expandedProvider     = StateProvider.family<bool, int>((ref, _) => false);

// ── Static data ────────────────────────────────────────────────────────────────
const _kExpectations = <(IconData, String, Color, String)>[
  (
    Icons.bug_report_rounded,
    'Bugs & Rough Edges',
    Color(0xFFEF4444),
    'Beta builds contain unfinished features and known issues. '
        'Some screens may crash or behave unexpectedly — that\'s why you\'re here.',
  ),
  (
    Icons.construction_rounded,
    'Incomplete Features',
    Color(0xFFF59E0B),
    'Several screens are still under development. You may see placeholder '
        'content, mock data, or "coming soon" states throughout the app.',
  ),
  (
    Icons.system_update_rounded,
    'Frequent Build Updates',
    Color(0xFF3B82F6),
    'Beta builds are updated often — sometimes daily. Your feedback directly '
        'shapes what gets fixed or shipped next.',
  ),
  (
    Icons.feedback_rounded,
    'Your Feedback Matters',
    Color(0xFF10B981),
    'Every screen has a feedback button. Tap it any time to report a bug, '
        'flag a false alarm, or suggest an improvement.',
  ),
];

const _kResponsibilities = <(IconData, String)>[
  (Icons.report_rounded,       'Report bugs using the in-app feedback button'),
  (Icons.lock_rounded,         'Do not share beta builds or screenshots publicly'),
  (Icons.smartphone_rounded,   'Use a secondary device if possible — builds can be unstable'),
  (Icons.update_rounded,       'Accept app updates promptly when prompted'),
  (Icons.science_rounded,      'Test real scenarios — SOS, contacts, drills, audio'),
  (Icons.stars_rounded,        'Rate feature quality in the feedback form (1–5 stars)'),
];

const _kBetaFeatures = <(String, Color)>[
  ('In-app feedback button',    Color(0xFF06B6D4)),
  ('Feedback form (Day 114)',   Color(0xFF3B82F6)),
  ('False positive reporting',  Color(0xFFEF4444)),
  ('Beta environment banner',   Color(0xFFF97316)),
  ('110+ screens built',        Color(0xFF10B981)),
  ('15 language i18n',          Color(0xFF8B5CF6)),
  ('WCAG 2.1 accessibility',    Color(0xFFF59E0B)),
  ('Semantics / TalkBack',      Color(0xFF06B6D4)),
];

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day112BetaOnboardingScreen extends ConsumerWidget {
  const Day112BetaOnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final acknowledged = ref.watch(_acknowledgedProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Day 112 · Beta Onboarding'),
        elevation: 0,
        actions: [
          if (acknowledged)
            Padding(
              padding: const EdgeInsets.only(right: ZapSpacing.md),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF10B981).withOpacity(0.5),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_rounded,
                        color: Color(0xFF10B981), size: 14),
                    SizedBox(width: ZapSpacing.xs),
                    Text(
                      'Acknowledged',
                      style: TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: acknowledged
            ? _SuccessView(
                key: const ValueKey('success'),
                onReset: () =>
                    ref.read(_acknowledgedProvider.notifier).state = false,
              )
            : const _OnboardingContent(key: ValueKey('onboarding')),
      ),
    );
  }
}

// ── Onboarding content ─────────────────────────────────────────────────────────
class _OnboardingContent extends ConsumerWidget {
  const _OnboardingContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Hero(),
          const SizedBox(height: ZapSpacing.xl),
          const _SectionLabel('WHAT TO EXPECT'),
          const SizedBox(height: ZapSpacing.md),
          ..._kExpectations.indexed.map(
            (pair) => Padding(
              padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
              child: _ExpectationCard(
                index: pair.$1,
                icon: pair.$2.$1,
                title: pair.$2.$2,
                accent: pair.$2.$3,
                body: pair.$2.$4,
              ),
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          const _SectionLabel('YOUR RESPONSIBILITIES'),
          const SizedBox(height: ZapSpacing.md),
          const _ResponsibilitiesList(),
          const SizedBox(height: ZapSpacing.xl),
          const _SectionLabel('FEATURES BEING TESTED'),
          const SizedBox(height: ZapSpacing.md),
          const _BetaFeaturesGrid(),
          const SizedBox(height: ZapSpacing.xl),
          const _PrivacyNote(),
          const SizedBox(height: ZapSpacing.xl),
          _AcknowledgeButton(
            onTap: () =>
                ref.read(_acknowledgedProvider.notifier).state = true,
          ),
          const SizedBox(height: ZapSpacing.huge),
        ],
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
          colors: [Color(0xFF431407), Color(0xFF1C0A02), Color(0xFF0A0A0A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFFF97316).withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Beta badge row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF97316).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFF97316).withOpacity(0.5),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.science_rounded,
                        color: Color(0xFFF97316), size: 13),
                    SizedBox(width: 5),
                    Text(
                      '⚡  BETA BUILD',
                      style: TextStyle(
                        color: Color(0xFFF97316),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: ZapSpacing.sm),
              const Text(
                'DAY 112',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          // Main heading
          const Text(
            'You\'re a Beta\nTester! ⚡',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: ZapSpacing.md),
          const Text(
            'Welcome to the ZapSafe beta programme. You\'re among the first '
            '1,000 people testing this app before public launch. Your feedback '
            'will directly shape the final product.',
            style: TextStyle(
              color: Color(0xFFD1D5DB),
              fontSize: 13,
              height: 1.6,
            ),
          ),
          const SizedBox(height: ZapSpacing.md),
          // Stats row
          const Row(
            children: [
              _HeroStat('1,000', 'Beta testers',  Color(0xFFF97316)),
              _HeroStat('110+',  'Screens built',  Color(0xFF10B981)),
              _HeroStat('15',    'Languages',      Color(0xFF06B6D4)),
              _HeroStat('30',    'Days to launch', Color(0xFF8B5CF6)),
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
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 9),
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

// ── Expectation card (expandable) ──────────────────────────────────────────────
class _ExpectationCard extends ConsumerWidget {
  final int index;
  final IconData icon;
  final String title;
  final Color accent;
  final String body;

  const _ExpectationCard({
    required this.index,
    required this.icon,
    required this.title,
    required this.accent,
    required this.body,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(_expandedProvider(index));

    return GestureDetector(
      onTap: () => ref
          .read(_expandedProvider(index).notifier)
          .state = !expanded,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
          color: expanded ? accent.withOpacity(0.07) : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(
            color: expanded ? accent.withOpacity(0.4) : const Color(0xFF2A2A2A),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: accent, size: 20),
                ),
                const SizedBox(width: ZapSpacing.md),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: Colors.white38,
                  size: 20,
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              child: expanded
                  ? Padding(
                      padding: const EdgeInsets.only(
                          top: ZapSpacing.sm, left: 54),
                      child: Text(
                        body,
                        style: const TextStyle(
                          color: Color(0xFFD1D5DB),
                          fontSize: 12,
                          height: 1.6,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Responsibilities list ──────────────────────────────────────────────────────
class _ResponsibilitiesList extends StatelessWidget {
  const _ResponsibilitiesList();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        children: List.generate(_kResponsibilities.length, (i) {
          final (icon, text) = _kResponsibilities[i];
          final isLast = i == _kResponsibilities.length - 1;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: ZapSpacing.md, vertical: 12),
                child: Row(
                  children: [
                    Icon(icon, color: const Color(0xFFF97316), size: 18),
                    const SizedBox(width: ZapSpacing.md),
                    Expanded(
                      child: Text(
                        text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                const Divider(height: 1, color: Color(0xFF2A2A2A)),
            ],
          );
        }),
      ),
    );
  }
}

// ── Beta features grid ─────────────────────────────────────────────────────────
class _BetaFeaturesGrid extends StatelessWidget {
  const _BetaFeaturesGrid();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: ZapSpacing.sm,
      runSpacing: ZapSpacing.sm,
      children: _kBetaFeatures.map((entry) {
        final (label, color) = entry;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Privacy note ───────────────────────────────────────────────────────────────
class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1005),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(
          color: const Color(0xFFF59E0B).withOpacity(0.35),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              color: Color(0xFFF59E0B), size: 18),
          SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Text(
              'Beta builds may collect additional crash diagnostics and usage '
              'telemetry to help us identify issues. This data is anonymised '
              'and used only to improve ZapSafe before public launch.',
              style: TextStyle(
                color: Color(0xFFD1D5DB),
                fontSize: 12,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Acknowledge button ─────────────────────────────────────────────────────────
class _AcknowledgeButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AcknowledgeButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF97316), Color(0xFFEA580C)],
          ),
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF97316).withOpacity(0.35),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            SizedBox(width: ZapSpacing.sm),
            Text(
              'I understand — Let\'s test ZapSafe',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Success view ───────────────────────────────────────────────────────────────
class _SuccessView extends StatelessWidget {
  final VoidCallback onReset;
  const _SuccessView({super.key, required this.onReset});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      child: Column(
        children: [
          const SizedBox(height: ZapSpacing.xxxl),
          // Success icon
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF10B981).withOpacity(0.5),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Color(0xFF10B981),
              size: 44,
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          const Text(
            'You\'re all set!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'Welcome to the ZapSafe beta programme.\nYour acknowledgement has been recorded.',
            style: TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 14,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: ZapSpacing.xxxl),
          // Next steps
          const _SectionLabel('NEXT STEPS'),
          const SizedBox(height: ZapSpacing.md),
          ..._kNextSteps.map(
            (step) => Padding(
              padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
              child: _NextStepCard(
                icon: step.$1,
                title: step.$2,
                subtitle: step.$3,
                accent: step.$4,
              ),
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          // Quick note
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.08),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(
                color: const Color(0xFF10B981).withOpacity(0.25),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.science_rounded,
                    color: Color(0xFF10B981), size: 18),
                SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    'FlavorConfig.isBeta = true  ·  '
                    'Feedback button active on all screens  ·  '
                    'Build: Day 112',
                    style: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          // Reset demo button
          GestureDetector(
            onTap: onReset,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: const Center(
                child: Text(
                  'Reset demo  →  show onboarding again',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: ZapSpacing.huge),
        ],
      ),
    );
  }
}

const _kNextSteps = <(IconData, String, String, Color)>[
  (
    Icons.feedback_rounded,
    'Use the Feedback Button',
    'Every screen has a floating feedback button (Day 113). '
        'Tap it to report bugs or rate features.',
    Color(0xFFF97316),
  ),
  (
    Icons.explore_rounded,
    'Explore All 110+ Screens',
    'Navigate the index to test every feature — SOS, Evidence Vault, '
        'i18n, Accessibility, and more.',
    Color(0xFF3B82F6),
  ),
  (
    Icons.warning_rounded,
    'Report False Alarms',
    'After an SOS fires, you\'ll be asked "Was this a false alarm?" '
        'Your reports train the detection model.',
    Color(0xFFEF4444),
  ),
  (
    Icons.star_rounded,
    'Rate Your Experience',
    'Weekly in-app surveys help us prioritise fixes and new features '
        'before the public launch.',
    Color(0xFFF59E0B),
  ),
];

class _NextStepCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;

  const _NextStepCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 12,
                    height: 1.5,
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
