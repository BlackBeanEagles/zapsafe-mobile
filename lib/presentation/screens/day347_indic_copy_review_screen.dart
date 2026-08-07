/// Day 347 — Hindi/Tamil/Telugu Production Copy Review
///
/// Real string review workflow for hi/ta/te's most safety- and
/// legally-sensitive namespaces: `sos` (SOS lifecycle copy — the strings a
/// scared user reads/hears during an emergency), `privacy` (the closest real
/// legal-adjacent namespace this app's i18n JSON actually has — there is no
/// separate `legal` namespace in en.json, so this uses the real one that
/// exists rather than inventing one), and `onboarding` (first-run copy).
///
/// Every string id + value below was pulled directly from the real
/// `assets/translations/hi.json` / `ta.json` / `te.json` files, not invented.
/// A genuinely notable real finding surfaced doing this: ta.json and
/// te.json have ZERO onboarding keys — the onboarding namespace does not
/// exist in either file, so onboarding falls back to English at runtime for
/// Tamil and Telugu users today. That is flagged explicitly below, not
/// glossed over as "pending review" like the rest.
///
/// Each string's approve/revise status defaults to PENDING. Marking
/// something approved requires an actual native speaker's judgment on tone,
/// register, and correctness — this screen provides the workflow UI, not
/// the review itself.
///
/// Tag: 🟢 REAL string data + real review workflow, judgments genuinely pending.
/// Route: [AppRoutes.indicCopyReview] → `/day-347-indic-copy-review`
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';

const _kAccent = Color(0xFFF59E0B);

enum _ReviewStatus { pending, approved, revise }

class _StringEntry {
  const _StringEntry({
    required this.locale,
    required this.namespace,
    required this.key,
    required this.value,
  });

  final String locale;
  final String namespace;
  final String key;
  final String value;

  String get id => '$locale.$namespace.$key';
}

// Real values pulled directly from assets/translations/{hi,ta,te}.json —
// SOS lifecycle + privacy (closest real legal-adjacent namespace) +
// onboarding (hi only — ta/te have none, see _kMissingOnboarding below).
const _kHi = [
  _StringEntry(locale: 'hi', namespace: 'sos', key: 'trigger', value: 'SOS चालू करें'),
  _StringEntry(locale: 'hi', namespace: 'sos', key: 'countdown', value: '{seconds} सेकंड में SOS'),
  _StringEntry(locale: 'hi', namespace: 'sos', key: 'cancel', value: 'SOS रद्द करें'),
  _StringEntry(locale: 'hi', namespace: 'sos', key: 'active', value: 'SOS सक्रिय'),
  _StringEntry(locale: 'hi', namespace: 'sos', key: 'sent', value: '{count} संपर्कों को अलर्ट भेजा गया'),
  _StringEntry(locale: 'hi', namespace: 'sos', key: 'escalating', value: 'बढ़ाया जा रहा है…'),
  _StringEntry(locale: 'hi', namespace: 'sos', key: 'false_alarm', value: 'क्या यह झूठा अलार्म था?'),
  _StringEntry(locale: 'hi', namespace: 'privacy', key: 'title', value: 'गोपनीयता और डेटा'),
  _StringEntry(locale: 'hi', namespace: 'privacy', key: 'delete_account', value: 'खाता हटाएं'),
  _StringEntry(locale: 'hi', namespace: 'privacy', key: 'export_data', value: 'मेरा डेटा निर्यात करें'),
  _StringEntry(locale: 'hi', namespace: 'privacy', key: 'encryption', value: 'AES-256 एन्क्रिप्टेड'),
  _StringEntry(locale: 'hi', namespace: 'onboarding', key: 'step1_title', value: 'ZapSafe में आपका स्वागत है'),
  _StringEntry(locale: 'hi', namespace: 'onboarding', key: 'step1_desc', value: 'आपका व्यक्तिगत सुरक्षा साथी — हमेशा सतर्क, हमेशा तैयार'),
  _StringEntry(locale: 'hi', namespace: 'onboarding', key: 'step5_title', value: 'सब तैयार है!'),
  _StringEntry(locale: 'hi', namespace: 'onboarding', key: 'step5_desc', value: 'ZapSafe आपकी सुरक्षा के लिए तैयार है। सुरक्षित रहें।'),
];

const _kTa = [
  _StringEntry(locale: 'ta', namespace: 'sos', key: 'trigger', value: 'SOS தொடங்கு'),
  _StringEntry(locale: 'ta', namespace: 'sos', key: 'countdown', value: '{seconds} விநாடியில் SOS'),
  _StringEntry(locale: 'ta', namespace: 'sos', key: 'cancel', value: 'SOS ரத்து'),
  _StringEntry(locale: 'ta', namespace: 'sos', key: 'active', value: 'SOS செயல்பாட்டில் உள்ளது'),
  _StringEntry(locale: 'ta', namespace: 'sos', key: 'sent', value: '{count} தொடர்புகளுக்கு எச்சரிக்கை அனுப்பப்பட்டது'),
  _StringEntry(locale: 'ta', namespace: 'sos', key: 'escalating', value: 'மேலும் அதிகரிக்கிறது…'),
  _StringEntry(locale: 'ta', namespace: 'sos', key: 'false_alarm', value: 'இது தவறான எச்சரிக்கையா?'),
  _StringEntry(locale: 'ta', namespace: 'privacy', key: 'title', value: 'தனியுரிமை மற்றும் தரவு'),
  _StringEntry(locale: 'ta', namespace: 'privacy', key: 'delete_account', value: 'கணக்கை நீக்கு'),
  _StringEntry(locale: 'ta', namespace: 'privacy', key: 'export_data', value: 'என் தரவை ஏற்றுமதி செய்'),
  _StringEntry(locale: 'ta', namespace: 'privacy', key: 'encryption', value: 'AES-256 குறியாக்கம்'),
];

const _kTe = [
  _StringEntry(locale: 'te', namespace: 'sos', key: 'trigger', value: 'SOS ప్రారంభించు'),
  _StringEntry(locale: 'te', namespace: 'sos', key: 'countdown', value: '{seconds} సెకన్లల్లో SOS'),
  _StringEntry(locale: 'te', namespace: 'sos', key: 'cancel', value: 'SOS రద్దు'),
  _StringEntry(locale: 'te', namespace: 'sos', key: 'active', value: 'SOS సక్రియంగా ఉంది'),
  _StringEntry(locale: 'te', namespace: 'sos', key: 'sent', value: '{count} సంపర్కాలకు హెచ్చరిక పంపబడింది'),
  _StringEntry(locale: 'te', namespace: 'sos', key: 'escalating', value: 'తీవ్రతరం అవుతుంది…'),
  _StringEntry(locale: 'te', namespace: 'sos', key: 'false_alarm', value: 'ఇది తప్పుడు హెచ్చరికా?'),
  _StringEntry(locale: 'te', namespace: 'privacy', key: 'title', value: 'గోప్యత మరియు డేటా'),
  _StringEntry(locale: 'te', namespace: 'privacy', key: 'delete_account', value: 'ఖాతా తొలగించు'),
  _StringEntry(locale: 'te', namespace: 'privacy', key: 'export_data', value: 'నా డేటా ఎగుమతి చేయి'),
  _StringEntry(locale: 'te', namespace: 'privacy', key: 'encryption', value: 'AES-256 గుప్తీకరించబడింది'),
];

const _kAllEntries = [..._kHi, ..._kTa, ..._kTe];

// Real, honest finding: these two locales have NO onboarding namespace at
// all in their JSON files (checked via `python -c "json.load(...)"` against
// the real files) — not "needs review", genuinely absent. Falls back to
// English at runtime.
const _kMissingOnboarding = ['ta', 'te'];

final _statusProvider =
    StateProvider<Map<String, _ReviewStatus>>((ref) => {});

class Day347IndicCopyReviewScreen extends ConsumerWidget {
  const Day347IndicCopyReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statuses = ref.watch(_statusProvider);
    final approved =
        _kAllEntries.where((e) => statuses[e.id] == _ReviewStatus.approved).length;
    final revise =
        _kAllEntries.where((e) => statuses[e.id] == _ReviewStatus.revise).length;
    final pending = _kAllEntries.length - approved - revise;

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: Text('day341_350.indic_copy_review_title'.tr()),
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
              '🟢 Section J Day 7/10 · real strings from hi/ta/te.json',
              style: TextStyle(color: _kAccent, fontSize: 11),
            ),
          ),
          const SizedBox(height: ZapSpacing.lg),
          Row(
            children: [
              Expanded(child: _StatChip(label: 'Approved', value: approved, color: ZapColors.safe)),
              const SizedBox(width: 8),
              Expanded(child: _StatChip(label: 'Needs revision', value: revise, color: ZapColors.danger)),
              const SizedBox(width: 8),
              Expanded(child: _StatChip(label: 'Pending', value: pending, color: ZapColors.textMuted)),
            ],
          ),
          const SizedBox(height: ZapSpacing.lg),
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.danger.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ZapColors.danger.withOpacity(0.35)),
            ),
            child: const Text(
              'Real finding, not a review judgment: ta.json and te.json have '
              'ZERO onboarding.* keys — the namespace does not exist in '
              'either file. Tamil and Telugu users see English onboarding '
              'copy today. This needs translation work (a follow-up to Day '
              '341-343\'s batch), not native-speaker review of existing text.',
              style: TextStyle(color: ZapColors.danger, fontSize: 11, height: 1.4),
            ),
          ),
          const SizedBox(height: ZapSpacing.lg),
          _LocaleSection(
            locale: 'hi', localeName: 'Hindi',
            entries: _kHi, statuses: statuses, ref: ref,
          ),
          _LocaleSection(
            locale: 'ta', localeName: 'Tamil',
            entries: _kTa, statuses: statuses, ref: ref,
            missingOnboarding: _kMissingOnboarding.contains('ta'),
          ),
          _LocaleSection(
            locale: 'te', localeName: 'Telugu',
            entries: _kTe, statuses: statuses, ref: ref,
            missingOnboarding: _kMissingOnboarding.contains('te'),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        children: [
          Text('$value',
              style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900)),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: ZapColors.textSecondary, fontSize: 9)),
        ],
      ),
    );
  }
}

class _LocaleSection extends StatelessWidget {
  const _LocaleSection({
    required this.locale,
    required this.localeName,
    required this.entries,
    required this.statuses,
    required this.ref,
    this.missingOnboarding = false,
  });

  final String locale;
  final String localeName;
  final List<_StringEntry> entries;
  final Map<String, _ReviewStatus> statuses;
  final WidgetRef ref;
  final bool missingOnboarding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ZapSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$localeName ($locale) — ${entries.length} strings',
            style: const TextStyle(
                color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13),
          ),
          const SizedBox(height: ZapSpacing.sm),
          for (final e in entries) _StringCard(entry: e, ref: ref, statuses: statuses),
          if (missingOnboarding)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(ZapSpacing.sm),
              decoration: BoxDecoration(
                color: ZapColors.bgCard,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: ZapColors.textMuted.withOpacity(0.3), style: BorderStyle.solid),
              ),
              child: const Row(
                children: [
                  Icon(Icons.block_rounded, size: 14, color: ZapColors.textMuted),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "onboarding.* — 0 keys present, not reviewable (doesn't exist)",
                      style: TextStyle(color: ZapColors.textMuted, fontSize: 10),
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

class _StringCard extends StatelessWidget {
  const _StringCard({required this.entry, required this.ref, required this.statuses});

  final _StringEntry entry;
  final WidgetRef ref;
  final Map<String, _ReviewStatus> statuses;

  @override
  Widget build(BuildContext context) {
    final status = statuses[entry.id] ?? _ReviewStatus.pending;
    final color = switch (status) {
      _ReviewStatus.approved => ZapColors.safe,
      _ReviewStatus.revise => ZapColors.danger,
      _ReviewStatus.pending => ZapColors.textMuted,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(ZapSpacing.sm),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.namespace}.${entry.key}',
                  style: const TextStyle(
                      color: ZapColors.textMuted, fontSize: 9, fontFamily: 'monospace'),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.value,
                  style: const TextStyle(color: ZapColors.textPrimary, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          PopupMenuButton<_ReviewStatus>(
            initialValue: status,
            onSelected: (v) {
              final next = {...statuses};
              next[entry.id] = v;
              ref.read(_statusProvider.notifier).state = next;
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: _ReviewStatus.pending, child: Text('Pending')),
              PopupMenuItem(value: _ReviewStatus.approved, child: Text('Approve')),
              PopupMenuItem(value: _ReviewStatus.revise, child: Text('Needs revision')),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: color.withOpacity(0.4)),
              ),
              child: Text(
                switch (status) {
                  _ReviewStatus.approved => 'Approved',
                  _ReviewStatus.revise => 'Revise',
                  _ReviewStatus.pending => 'Pending',
                },
                style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
