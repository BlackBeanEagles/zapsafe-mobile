/// Day 104 — Onboarding Flow i18n Demo
///
/// Interactive 5-step onboarding walkthrough with live locale switching.
/// Demonstrates the onboarding namespace translations for all 15 languages.
/// RTL layout applied automatically for Urdu and Arabic.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';
import '../../domain/providers/i18n_providers.dart';

// Step-specific icons and accent colours
const List<IconData> _kStepIcons = [
  Icons.waving_hand_rounded,
  Icons.people_rounded,
  Icons.location_on_rounded,
  Icons.tune_rounded,
  Icons.check_circle_rounded,
];

const List<Color> _kStepColors = [
  Color(0xFF3B82F6), // blue
  Color(0xFF8B5CF6), // purple
  Color(0xFF10B981), // green
  Color(0xFFF59E0B), // amber
  Color(0xFFEF4444), // red (SOS brand)
];

// Local step-index provider — separate from the global i18nProvider
final _stepIndexProvider = StateProvider<int>((ref) => 0);

class Day104OnboardingI18nScreen extends ConsumerWidget {
  const Day104OnboardingI18nScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i18n  = ref.watch(i18nProvider);
    final step  = ref.watch(_stepIndexProvider);
    final steps = kOnboardingSteps[i18n.selectedCode] ?? kOnboardingSteps['en']!;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: CustomScrollView(
        slivers: [
          _HeroBanner(langInfo: i18n.lang),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.md),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: ZapSpacing.md),
                const _StatsRow(),
                const SizedBox(height: ZapSpacing.lg),
                _LocaleSelector(state: i18n, ref: ref),
                const SizedBox(height: ZapSpacing.lg),
                _OnboardingCard(
                  step:    step,
                  steps:   steps,
                  isRtl:   i18n.isRtl,
                  lang:    i18n.lang,
                  ref:     ref,
                ),
                const SizedBox(height: ZapSpacing.lg),
                _ButtonRow(
                  step:    step,
                  steps:   steps,
                  isRtl:   i18n.isRtl,
                  lang:    i18n.lang,
                  ref:     ref,
                ),
                const SizedBox(height: ZapSpacing.lg),
                const _CoverageNote(),
                const SizedBox(height: ZapSpacing.xl),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Hero ─────────────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.langInfo});
  final LangInfo langInfo;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(ZapSpacing.md),
        padding: const EdgeInsets.all(ZapSpacing.lg),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF92400E), Color(0xFF1C1200)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF59E0B), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('DAY 104', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                ),
                const Spacer(),
                Text(
                  '${langInfo.flag} ${langInfo.nativeName}',
                  style: const TextStyle(color: Color(0xFFFCD34D), fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: ZapSpacing.md),
            const Text(
              'Onboarding Flow\ni18n Applied',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, height: 1.2),
            ),
            const SizedBox(height: ZapSpacing.sm),
            const Text(
              '5 steps · 15 languages · RTL-aware · live switcher',
              style: TextStyle(color: Color(0xFFFCD34D), fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Stats ────────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: _StatBox(value: '5',   label: 'Steps')),
        SizedBox(width: ZapSpacing.sm),
        Expanded(child: _StatBox(value: '15',  label: 'Languages')),
        SizedBox(width: ZapSpacing.sm),
        Expanded(child: _StatBox(value: '2',   label: 'RTL')),
        SizedBox(width: ZapSpacing.sm),
        Expanded(child: _StatBox(value: '13',  label: 'Keys')),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1200),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.35)),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
        ],
      ),
    );
  }
}

// ─── Locale Selector ──────────────────────────────────────────────────────────

class _LocaleSelector extends StatelessWidget {
  const _LocaleSelector({required this.state, required this.ref});
  final I18nState state;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SWITCH LANGUAGE',
          style: TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2),
        ),
        const SizedBox(height: ZapSpacing.sm),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: kSupportedLanguages.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final lang = kSupportedLanguages[i];
              final selected = lang.code == state.selectedCode;
              return GestureDetector(
                onTap: () {
                  ref.read(i18nProvider.notifier).select(lang.code);
                  ref.read(_stepIndexProvider.notifier).state = 0;
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFFF59E0B) : const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: selected ? const Color(0xFFF59E0B) : const Color(0xFF2A2A2A),
                    ),
                  ),
                  child: Text(
                    '${lang.flag} ${lang.code.toUpperCase()}',
                    style: TextStyle(
                      color: selected ? Colors.black : const Color(0xFF9CA3AF),
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w400,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Onboarding Card ──────────────────────────────────────────────────────────

class _OnboardingCard extends StatelessWidget {
  const _OnboardingCard({
    required this.step,
    required this.steps,
    required this.isRtl,
    required this.lang,
    required this.ref,
  });

  final int step;
  final List<List<String>> steps;
  final bool isRtl;
  final LangInfo lang;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final title = steps[step][0];
    final desc  = steps[step][1];
    final icon  = _kStepIcons[step];
    final color = _kStepColors[step];
    final dir   = isRtl ? TextDirection.rtl : TextDirection.ltr;

    return Directionality(
      textDirection: dir,
      child: Container(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // RTL badge
            if (isRtl)
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.4)),
                  ),
                  child: const Text('RTL ←', style: TextStyle(color: Color(0xFFA78BFA), fontSize: 10, fontWeight: FontWeight.w700)),
                ),
              ),
            if (isRtl) const SizedBox(height: ZapSpacing.sm),

            // Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: color.withOpacity(0.3), width: 2),
              ),
              child: Icon(icon, color: color, size: 36),
            ),
            const SizedBox(height: ZapSpacing.lg),

            // Step label
            Text(
              '${lang.flag}  ${lang.nativeName}',
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: ZapSpacing.sm),

            // Title
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, height: 1.3),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: ZapSpacing.sm),

            // Description
            Text(
              desc,
              style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14, height: 1.6),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: ZapSpacing.lg),

            // Step dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final active = i == step;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active ? color : const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),

            // Step counter
            const SizedBox(height: ZapSpacing.sm),
            Text(
              '${step + 1} / 5',
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Button Row ───────────────────────────────────────────────────────────────

class _ButtonRow extends StatelessWidget {
  const _ButtonRow({
    required this.step,
    required this.steps,
    required this.isRtl,
    required this.lang,
    required this.ref,
  });

  final int step;
  final List<List<String>> steps;
  final bool isRtl;
  final LangInfo lang;
  final WidgetRef ref;

  static const Map<String, List<String>> _buttonLabels = {
    'en': ['Next', 'Skip', 'Get Started'],
    'hi': ['अगला', 'छोड़ें', 'शुरू करें'],
    'ta': ['அடுத்து', 'தவிர்', 'தொடங்கு'],
    'te': ['తదుపరి', 'దాటవేయి', 'ప్రారంభించు'],
    'ml': ['അടുത്തത്', 'ഒഴിവാക്കുക', 'ആരംഭിക്കുക'],
    'bn': ['পরবর্তী', 'এড়িয়ে যান', 'শুরু করুন'],
    'mr': ['पुढे', 'वगळा', 'सुरू करा'],
    'gu': ['આગળ', 'છોड़ো', 'શरूआत करो'],
    'pa': ['ਅਗਲਾ', 'ਛੱਡੋ', 'ਸ਼ੁਰੂ ਕਰੋ'],
    'ur': ['اگلا', 'چھوڑیں', 'شروع کریں'],
    'ar': ['التالي', 'تخطي', 'ابدأ'],
    'es': ['Siguiente', 'Omitir', 'Comenzar'],
    'fr': ['Suivant', 'Passer', 'Commencer'],
    'pt': ['Próximo', 'Pular', 'Começar'],
    'de': ['Weiter', 'Überspringen', 'Loslegen'],
  };

  @override
  Widget build(BuildContext context) {
    final code   = lang.code;
    final labels = _buttonLabels[code] ?? _buttonLabels['en']!;
    final nextLabel  = step == 4 ? labels[2] : labels[0];
    final skipLabel  = labels[1];
    final color  = _kStepColors[step];

    void goNext() {
      if (step < 4) {
        ref.read(_stepIndexProvider.notifier).state = step + 1;
      } else {
        ref.read(_stepIndexProvider.notifier).state = 0;
      }
    }

    void goPrev() {
      if (step > 0) ref.read(_stepIndexProvider.notifier).state = step - 1;
    }

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Row(
        children: [
          // Back button
          if (step > 0)
            Expanded(
              flex: 1,
              child: GestureDetector(
                onTap: goPrev,
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF2A2A2A)),
                  ),
                  child: const Icon(Icons.arrow_back_rounded, color: Color(0xFF6B7280)),
                ),
              ),
            ),
          if (step > 0) const SizedBox(width: ZapSpacing.sm),

          // Skip (show if not last step)
          if (step < 4)
            TextButton(
              onPressed: () => ref.read(_stepIndexProvider.notifier).state = 4,
              child: Text(skipLabel, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
            ),
          if (step < 4) const SizedBox(width: ZapSpacing.sm),

          // Primary Next / Get Started
          Expanded(
            flex: 3,
            child: GestureDetector(
              onTap: goNext,
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  nextLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Coverage Note ────────────────────────────────────────────────────────────

class _CoverageNote extends StatelessWidget {
  const _CoverageNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F1F1F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TRANSLATION COVERAGE — DAY 103-104',
            style: TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1),
          ),
          const SizedBox(height: ZapSpacing.sm),
          _coverageRow(Icons.check_circle_rounded, const Color(0xFF10B981),
              'onboarding.*', 'en + hi — full (13 keys each), others via kOnboardingSteps'),
          _coverageRow(Icons.check_circle_rounded, const Color(0xFF10B981),
              'permissions.*', 'en + hi — full (12 keys each)'),
          _coverageRow(Icons.check_circle_rounded, const Color(0xFF10B981),
              'push.*', 'en + hi — full (8 keys each)'),
          _coverageRow(Icons.info_outline_rounded, const Color(0xFF3B82F6),
              '13 other languages', 'Fallback to English for new namespaces via easy_localization'),
          _coverageRow(Icons.language_rounded, const Color(0xFF8B5CF6),
              'RTL', 'Urdu (ur) + Arabic (ar) — Directionality.rtl applied'),
        ],
      ),
    );
  }

  Widget _coverageRow(IconData icon, Color color, String label, String detail) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(text: label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
                  TextSpan(text: '  $detail', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
