/// Day 346 — Cultural Adaptation QA v2
///
/// Extends Day 269 (`day269_cultural_adaptation_screen.dart` — region
/// presets for date/time/calendar/emergency-number). Day 269 covers 8
/// regions (India, US, UK, Japan, UAE, Germany, Indonesia, Saudi Arabia).
/// Section J (Days 341-350) added 10 more languages, several with no region
/// preset yet: Swahili (Kenya/Tanzania), Vietnamese, Turkey, Poland,
/// Netherlands, Italy, South Korea, Iran (Persian) — this screen does NOT
/// add presets for them (that would mean inventing emergency phone numbers,
/// which is explicitly out of bounds), it flags the gap as a real pending
/// item.
///
/// This screen is a per-region COLOR and ICON appropriateness review
/// checklist — real, useful UI, but the actual judgment calls (does this
/// specific red/green/icon read correctly in this specific culture) need a
/// human cultural reviewer with lived context. Every item defaults to
/// UNREVIEWED. Nothing here is fabricated as "passed" or "reviewed" — that
/// would defeat the purpose of a QA checklist.
///
/// Tag: 🟢 REAL checklist UI, items genuinely pending (needs human review).
/// Route: [AppRoutes.culturalAdaptationV2] → `/day-346-cultural-adaptation-v2`
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';

const _kAccent = Color(0xFF7C3AED);

class _ReviewItem {
  const _ReviewItem({
    required this.id,
    required this.title,
    required this.detail,
    required this.regions,
  });

  final String id;
  final String title;
  final String detail;
  final String regions;
}

// Real checklist grounded in this app's ACTUAL color/icon usage
// (ZapColors.danger/safe/warning/info, real Material icons this codebase
// uses for SOS/permissions/success flows) cross-referenced against the
// real region set: Day 269's 8 presets + the 10 Section J language markets.
const _kColorItems = [
  _ReviewItem(
    id: 'color_danger_red',
    title: 'ZapColors.danger (#E63946, red) for SOS/critical states',
    detail: 'Red reads as danger/stop in most Western and South Asian '
        'contexts (matches India/US/UK/Germany defaults), which covers most '
        'of this app\'s primary markets. Needs review specifically for East '
        'Asian markets (Korean, ko) where red can carry positive/celebratory '
        'connotations in some contexts, which could blunt urgency perception '
        'of the SOS button color.',
    regions: 'Primary: all · Review focus: Korea (ko)',
  ),
  _ReviewItem(
    id: 'color_safe_green',
    title: 'ZapColors.safe (#06D6A0, green) for "you are safe" / success',
    detail: 'Green is broadly positive, but in several Muslim-majority '
        'markets this app now serves (UAE/Saudi presets already, plus new '
        'Turkey/Indonesia-adjacent Section J languages) green also carries '
        'religious association (Islam). Needs a native reviewer to confirm '
        'the specific teal-leaning shade (#06D6A0) reads as neutral '
        '"safe/success" and not as an unintended religious signal.',
    regions: 'UAE (ae), Saudi Arabia (sa), Indonesia (id), Turkey (tr)',
  ),
  _ReviewItem(
    id: 'color_warning_orange',
    title: 'ZapColors.warning (#F4A261, orange) for elevated/caution states',
    detail: 'Orange/amber for caution is close to universal (traffic-light '
        'convention). Lower-priority review item — flagged for completeness, '
        'not because a specific risk is known.',
    regions: 'All',
  ),
  _ReviewItem(
    id: 'color_bg_dark',
    title: 'OLED-dark theme (bgPrimary #07070E near-black) as the only theme',
    detail: 'This app currently ships dark-only (see core/theme/colors.dart). '
        'White-on-black is culturally neutral in most markets, but confirm '
        'there is no expectation of a light/white default in specific '
        'regions (e.g. some markets associate an all-black app chrome with '
        'somber/funerary tone) — needs a broader cultural read, not just '
        'color-by-color.',
    regions: 'All — theme-level, not per-color',
  ),
];

const _kIconItems = [
  _ReviewItem(
    id: 'icon_emergency',
    title: 'Icons.emergency_rounded (siren) for emergency-number preview',
    detail: 'Used in day269_cultural_adaptation_screen.dart\'s live-preview '
        'card. Siren iconography is close to universally understood as '
        'emergency/alert. Low risk, included for completeness.',
    regions: 'All',
  ),
  _ReviewItem(
    id: 'icon_check_circle',
    title: 'Icons.check_circle_rounded for "applied/verified/done" states',
    detail: 'A circled checkmark is used across onboarding, permissions, and '
        'this branch\'s Section J screens for "complete". Checkmarks are '
        'broadly positive, but confirm no region reads a green checkmark as '
        'ambiguous with a religious or national symbol at small size — low '
        'confidence concern, flagged for a real reviewer rather than guessed.',
    regions: 'All',
  ),
  _ReviewItem(
    id: 'icon_hand_gestures',
    title: 'No hand-gesture icons (thumbs-up/OK sign) found in this repo',
    detail: 'Grepped for Icons.thumb_up / Icons.thumb_down / "OK hand" style '
        'icons across lib/ — none found in the screens this branch touches. '
        'Thumbs-up and the OK-hand sign are considered offensive gestures in '
        'several Middle Eastern and West African cultures, so their absence '
        'is good. Marked reviewed=false anyway since this was a targeted '
        'grep, not an exhaustive audit of the full 350-day codebase.',
    regions: 'Middle East, West Africa (incl. Swahili-speaking East Africa)',
  ),
  _ReviewItem(
    id: 'icon_owl_animal',
    title: 'No animal/owl mascot iconography found for onboarding/help',
    detail: 'Animal symbolism varies sharply by culture (owls read as wise '
        'in some Western contexts, as an omen of death in several South '
        'Asian and African cultures). This app does not appear to use '
        'animal mascots in the screens reviewed — confirmed absent by grep, '
        'not by design intent, so still flagged pending for a full audit.',
    regions: 'South Asia (hi/ta/te/ml/bn/mr/gu/pa), Swahili-speaking Africa',
  ),
];

final _reviewedProvider = StateProvider<Set<String>>((ref) => <String>{});

class Day346CulturalAdaptationV2Screen extends ConsumerWidget {
  const Day346CulturalAdaptationV2Screen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewed = ref.watch(_reviewedProvider);
    final allItems = [..._kColorItems, ..._kIconItems];
    final reviewedCount = allItems.where((i) => reviewed.contains(i.id)).length;

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: Text('day341_350.cultural_adaptation_v2_title'.tr()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _kAccent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _kAccent.withOpacity(0.35)),
            ),
            child: const Text(
              '🟢 Section J Day 6/10 · extends Day 269 · real pending checklist',
              style: TextStyle(color: _kAccent, fontSize: 11),
            ),
          ),
          const SizedBox(height: ZapSpacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ZapSpacing.lg),
            decoration: BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kAccent.withOpacity(0.35)),
            ),
            child: Column(
              children: [
                Text(
                  '$reviewedCount / ${allItems.length}',
                  style: const TextStyle(
                    color: _kAccent,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Text(
                  'Reviewed by a human cultural reviewer',
                  style: TextStyle(color: ZapColors.textSecondary, fontSize: 11),
                ),
                const SizedBox(height: ZapSpacing.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: allItems.isEmpty ? 0 : reviewedCount / allItems.length,
                    minHeight: 8,
                    backgroundColor: ZapColors.border,
                    color: _kAccent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.lg),
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ZapColors.warning.withOpacity(0.35)),
            ),
            child: const Text(
              'Region gap: Section J added sw/vi/tr/pl/nl/it/ko/fa but Day 269 '
              'has no region preset for Kenya/Tanzania, Vietnam, Turkey, '
              'Poland, Netherlands, Italy, South Korea, or Iran. Adding those '
              'presets requires verified official emergency numbers per '
              'country — deliberately NOT invented here. Flagged as a real '
              'follow-up for Day 269\'s preset list, out of scope for this '
              'color/icon checklist.',
              style: TextStyle(color: ZapColors.warning, fontSize: 11, height: 1.4),
            ),
          ),
          const SizedBox(height: ZapSpacing.lg),
          const Text(
            'Color symbolism review',
            style: TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          for (final item in _kColorItems)
            _ReviewCard(
              item: item,
              reviewed: reviewed.contains(item.id),
              onToggle: () => _toggle(ref, item.id),
            ),
          const SizedBox(height: ZapSpacing.lg),
          const Text(
            'Icon meaning review',
            style: TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          for (final item in _kIconItems)
            _ReviewCard(
              item: item,
              reviewed: reviewed.contains(item.id),
              onToggle: () => _toggle(ref, item.id),
            ),
          const SizedBox(height: ZapSpacing.lg),
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.info.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ZapColors.info.withOpacity(0.3)),
            ),
            child: const Text(
              'Checking a box here means "a human with real cultural context '
              'reviewed this and confirmed it\'s appropriate" — not "this was '
              'automatically judged fine". None are pre-checked.',
              style: TextStyle(color: ZapColors.info, fontSize: 11, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  void _toggle(WidgetRef ref, String id) {
    final current = {...ref.read(_reviewedProvider)};
    if (current.contains(id)) {
      current.remove(id);
    } else {
      current.add(id);
    }
    ref.read(_reviewedProvider.notifier).state = current;
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.item,
    required this.reviewed,
    required this.onToggle,
  });

  final _ReviewItem item;
  final bool reviewed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final color = reviewed ? ZapColors.safe : ZapColors.textMuted;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(ZapSpacing.sm),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: reviewed,
            activeColor: ZapColors.safe,
            onChanged: (_) => onToggle(),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      color: ZapColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.detail,
                    style: const TextStyle(
                      color: ZapColors.textSecondary,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.regions,
                    style: TextStyle(
                      color: ZapColors.info.withOpacity(0.9),
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
