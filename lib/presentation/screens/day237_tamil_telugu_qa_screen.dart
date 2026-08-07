/// Day 237 — India UX · Tamil & Telugu Layout QA
///
/// Section B (Days 221-240): side-by-side EN/TA/TE for 20 critical strings.
/// Flags long-script single-line truncation and multi-line layout breaks.
///
/// Tag: 🟢 FRONTEND-ONLY · ta_IN / te_IN locale QA gate.
///
/// Route: [AppRoutes.tamilTeluguQa] → `/tamil-telugu-qa`
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';
import '../widgets/zap_empty_state.dart';

// ── Catalogue ─────────────────────────────────────────────────────────────────
enum _StringCategory { sos, legal, onboarding, ui }

enum _DravidianLocale { tamil, telugu }

enum _LayoutIssueKind { singleLine, multiLine }

extension _StringCategoryX on _StringCategory {
  String get label => switch (this) {
        _StringCategory.sos => 'SOS',
        _StringCategory.legal => 'Legal',
        _StringCategory.onboarding => 'Onboarding',
        _StringCategory.ui => 'UI',
      };

  Color get color => switch (this) {
        _StringCategory.sos => ZapColors.danger,
        _StringCategory.legal => const Color(0xFF8B5CF6),
        _StringCategory.onboarding => ZapColors.info,
        _StringCategory.ui => ZapColors.textMuted,
      };
}

extension _DravidianLocaleX on _DravidianLocale {
  String get label => switch (this) {
        _DravidianLocale.tamil => 'Tamil',
        _DravidianLocale.telugu => 'Telugu',
      };

  String get localeCode => switch (this) {
        _DravidianLocale.tamil => 'ta_IN',
        _DravidianLocale.telugu => 'te_IN',
      };

  Color get color => switch (this) {
        _DravidianLocale.tamil => const Color(0xFFEC4899),
        _DravidianLocale.telugu => const Color(0xFF14B8A6),
      };
}

class _DravidianStringEntry {
  const _DravidianStringEntry({
    required this.id,
    required this.category,
    required this.context,
    required this.english,
    required this.tamil,
    required this.telugu,
    required this.buttonMaxWidth,
    required this.cardMaxWidth,
    this.fontSize = 12,
  });

  final String id;
  final _StringCategory category;
  final String context;
  final String english;
  final String tamil;
  final String telugu;
  final double buttonMaxWidth;
  final double cardMaxWidth;
  final double fontSize;

  String textFor(_DravidianLocale locale) => switch (locale) {
        _DravidianLocale.tamil => tamil,
        _DravidianLocale.telugu => telugu,
      };
}

class _LayoutFlag {
  const _LayoutFlag({
    required this.entry,
    required this.locale,
    required this.kind,
  });

  final _DravidianStringEntry entry;
  final _DravidianLocale locale;
  final _LayoutIssueKind kind;

  String get key => '${entry.id}_${locale.name}_${kind.name}';
}

const _kCriticalStrings = [
  _DravidianStringEntry(
    id: 'sos_send',
    category: _StringCategory.sos,
    context: 'Primary SOS trigger button',
    english: 'Send SOS',
    tamil: 'SOS அனுப்பு',
    telugu: 'SOS పంపు',
    buttonMaxWidth: 130,
    cardMaxWidth: 160,
    fontSize: 14,
  ),
  _DravidianStringEntry(
    id: 'sos_cancel',
    category: _StringCategory.sos,
    context: 'SOS countdown cancel (Day 126 bug)',
    english: 'Cancel SOS',
    tamil: 'SOS ரத்துசெய்',
    telugu: 'SOS రద్దు చేయి',
    buttonMaxWidth: 95,
    cardMaxWidth: 140,
    fontSize: 13,
  ),
  _DravidianStringEntry(
    id: 'sos_active',
    category: _StringCategory.sos,
    context: 'Active alert banner title',
    english: 'SOS Active',
    tamil: 'SOS செயலில்',
    telugu: 'SOS సక్రియం',
    buttonMaxWidth: 150,
    cardMaxWidth: 170,
  ),
  _DravidianStringEntry(
    id: 'sos_contacts_notified',
    category: _StringCategory.sos,
    context: 'Post-send confirmation toast',
    english: 'Alert sent to contacts',
    tamil: 'தொடர்புகளுக்கு எச்சரிக்கை அனுப்பப்பட்டது',
    telugu: 'సంప్రదింపులకు అలర్ట్ పంపబడింది',
    buttonMaxWidth: 200,
    cardMaxWidth: 210,
  ),
  _DravidianStringEntry(
    id: 'sos_services_notified',
    category: _StringCategory.sos,
    context: 'Emergency services status line',
    english: 'Emergency services notified',
    tamil: 'அவசர சேவைகளுக்கு அறிவிக்கப்பட்டது',
    telugu: 'అత్యవసర సేవలకు తెలియజేయబడింది',
    buttonMaxWidth: 185,
    cardMaxWidth: 200,
  ),
  _DravidianStringEntry(
    id: 'sos_hold_confirm',
    category: _StringCategory.sos,
    context: 'Hold-to-confirm instruction',
    english: 'Hold to confirm SOS',
    tamil: 'SOS உறுதிப்படுத்த அழுத்திப் பிடிக்கவும்',
    telugu: 'SOS నిర్ధారించడానికి నొక్కి పట్టుకోండి',
    buttonMaxWidth: 145,
    cardMaxWidth: 175,
  ),
  _DravidianStringEntry(
    id: 'legal_privacy',
    category: _StringCategory.legal,
    context: 'Settings · legal link',
    english: 'Privacy Policy',
    tamil: 'தனியுரிமைக் கொள்கை',
    telugu: 'గోప్యతా విధానం',
    buttonMaxWidth: 155,
    cardMaxWidth: 165,
  ),
  _DravidianStringEntry(
    id: 'legal_terms',
    category: _StringCategory.legal,
    context: 'Settings · legal link',
    english: 'Terms of Service',
    tamil: 'சேவை விதிமுறைகள்',
    telugu: 'సేవా నిబంధనలు',
    buttonMaxWidth: 155,
    cardMaxWidth: 165,
  ),
  _DravidianStringEntry(
    id: 'legal_agree_continue',
    category: _StringCategory.legal,
    context: 'Onboarding consent footer',
    english: 'By continuing you agree to our Terms',
    tamil: 'தொடர்வதன் மூலம் நீங்கள் விதிமுறைகளை ஒப்புக்கொள்கிறீர்கள்',
    telugu: 'కొనసాగించడం ద్వారా మీరు నిబంధనలకు అంగీకరిస్తారు',
    buttonMaxWidth: 230,
    cardMaxWidth: 240,
  ),
  _DravidianStringEntry(
    id: 'legal_data_encrypted',
    category: _StringCategory.legal,
    context: 'Privacy explainer bullet',
    english: 'Data stored locally encrypted',
    tamil: 'தரவு உள்ளூரில் குறியாக்கம் செய்து சேமிக்கப்படுகிறது',
    telugu: 'డేటా స్థానికంగా గుప్తీకరించి నిల్వ చేయబడుతుంది',
    buttonMaxWidth: 205,
    cardMaxWidth: 220,
  ),
  _DravidianStringEntry(
    id: 'legal_withdraw_consent',
    category: _StringCategory.legal,
    context: 'GDPR / DPDP consent note',
    english: 'You may withdraw consent anytime',
    tamil: 'ஒப்புதலை எப்போது வேண்டுமானாலும் திரும்பப் பெறலாம்',
    telugu: 'మీరు ఎప్పుడైనా సమ్మతిని ఉపసంహరించుకోవచ్చు',
    buttonMaxWidth: 195,
    cardMaxWidth: 210,
  ),
  _DravidianStringEntry(
    id: 'onboard_welcome',
    category: _StringCategory.onboarding,
    context: 'Splash / welcome headline',
    english: 'Welcome to ZapSafe',
    tamil: 'ZapSafe-க்கு வரவேற்கிறோம்',
    telugu: 'ZapSafeకు స్వాగతం',
    buttonMaxWidth: 260,
    cardMaxWidth: 280,
  ),
  _DravidianStringEntry(
    id: 'onboard_add_contacts',
    category: _StringCategory.onboarding,
    context: 'Setup step CTA',
    english: 'Add emergency contacts',
    tamil: 'அவசர தொடர்புகளைச் சேர்க்கவும்',
    telugu: 'అత్యవసర సంప్రదింపులను జోడించండి',
    buttonMaxWidth: 210,
    cardMaxWidth: 225,
  ),
  _DravidianStringEntry(
    id: 'onboard_enable_location',
    category: _StringCategory.onboarding,
    context: 'Permission rationale',
    english: 'Enable location for SOS',
    tamil: 'SOS-க்கு இருப்பிடத்தை இயக்கவும்',
    telugu: 'SOS కోసం స్థానాన్ని ప్రారంభించండి',
    buttonMaxWidth: 210,
    cardMaxWidth: 225,
  ),
  _DravidianStringEntry(
    id: 'onboard_complete_setup',
    category: _StringCategory.onboarding,
    context: 'Setup progress nudge',
    english: 'Complete setup to stay protected',
    tamil: 'பாதுகாப்பாக இருக்க அமைப்பை முடிக்கவும்',
    telugu: 'రక్షించబడటానికి సెటప్ పూర్తి చేయండి',
    buttonMaxWidth: 215,
    cardMaxWidth: 230,
  ),
  _DravidianStringEntry(
    id: 'onboard_skip',
    category: _StringCategory.onboarding,
    context: 'Secondary text button',
    english: 'Skip for now',
    tamil: 'இப்போது தவிர்க்கவும்',
    telugu: 'ఇప్పుడు దాటవేయి',
    buttonMaxWidth: 85,
    cardMaxWidth: 95,
  ),
  _DravidianStringEntry(
    id: 'ui_evidence_vault',
    category: _StringCategory.ui,
    context: 'Nav tab label',
    english: 'Evidence Vault',
    tamil: 'ஆதாரப் பேழை',
    telugu: 'సాక్ష్య ఖజానా',
    buttonMaxWidth: 62,
    cardMaxWidth: 72,
    fontSize: 10,
  ),
  _DravidianStringEntry(
    id: 'ui_protection_score',
    category: _StringCategory.ui,
    context: 'Dashboard card title',
    english: 'Protection Score',
    tamil: 'பாதுகாப்பு மதிப்பெண்',
    telugu: 'రక్షణ స్కోర్',
    buttonMaxWidth: 125,
    cardMaxWidth: 140,
  ),
  _DravidianStringEntry(
    id: 'ui_checkin_timer',
    category: _StringCategory.ui,
    context: 'Feature tile',
    english: 'Check-in Timer',
    tamil: 'செக்-இன் டைமர்',
    telugu: 'చెక్-ఇన్ టైమర్',
    buttonMaxWidth: 120,
    cardMaxWidth: 130,
  ),
  _DravidianStringEntry(
    id: 'ui_settings',
    category: _StringCategory.ui,
    context: 'Bottom nav / drawer',
    english: 'Settings',
    tamil: 'அமைப்புகள்',
    telugu: 'సెట్టింగ్‌లు',
    buttonMaxWidth: 72,
    cardMaxWidth: 82,
    fontSize: 11,
  ),
];

TextStyle _textStyle(_DravidianStringEntry entry) => TextStyle(
      fontSize: entry.fontSize,
      fontWeight: FontWeight.w600,
      height: 1.35,
    );

bool _singleLineOverflow(_DravidianStringEntry entry, String text) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: _textStyle(entry)),
    maxLines: 1,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: entry.buttonMaxWidth);
  return painter.didExceedMaxLines;
}

bool _multiLineBreakIssue(_DravidianStringEntry entry, String text) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: _textStyle(entry)),
    maxLines: 2,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: entry.cardMaxWidth);
  return painter.didExceedMaxLines;
}

List<_LayoutFlag> _layoutFlagsFor(
  _DravidianStringEntry entry,
  _DravidianLocale locale,
) {
  final text = entry.textFor(locale);
  final flags = <_LayoutFlag>[];
  if (_singleLineOverflow(entry, text)) {
    flags.add(
      _LayoutFlag(
        entry: entry,
        locale: locale,
        kind: _LayoutIssueKind.singleLine,
      ),
    );
  }
  if (_multiLineBreakIssue(entry, text)) {
    flags.add(
      _LayoutFlag(
        entry: entry,
        locale: locale,
        kind: _LayoutIssueKind.multiLine,
      ),
    );
  }
  return flags;
}

List<_LayoutFlag> _allLayoutFlags({_DravidianLocale? locale}) {
  final flags = <_LayoutFlag>[];
  for (final entry in _kCriticalStrings) {
    final locales = locale == null
        ? _DravidianLocale.values
        : [locale];
    for (final loc in locales) {
      flags.addAll(_layoutFlagsFor(entry, loc));
    }
  }
  return flags;
}

bool _entryHasIssue(_DravidianStringEntry entry) =>
    _DravidianLocale.values.any(
      (loc) => _layoutFlagsFor(entry, loc).isNotEmpty,
    );

// ── Providers ─────────────────────────────────────────────────────────────────
final _d237TabProvider = StateProvider<int>((ref) => 0);
final _d237CategoryProvider =
    StateProvider<_StringCategory?>((ref) => null);
final _d237LocaleFilterProvider =
    StateProvider<_DravidianLocale?>((ref) => null);
final _d237ReviewedProvider = StateProvider<Set<String>>((ref) => {});

const _kTabs = ['Compare', 'Layout', 'Report'];

List<_DravidianStringEntry> _filteredEntries(_StringCategory? category) {
  if (category == null) return _kCriticalStrings;
  return _kCriticalStrings.where((e) => e.category == category).toList();
}

String _buildReport() {
  final flags = _allLayoutFlags();
  final buf = StringBuffer('ZapSafe Tamil/Telugu Layout QA — ta_IN / te_IN\n');
  buf.writeln('Generated: ${DateTime.now().toIso8601String()}');
  buf.writeln('Total strings: ${_kCriticalStrings.length}');
  buf.writeln('Layout flags: ${flags.length}');
  buf.writeln(
    '  Single-line (button): '
    '${flags.where((f) => f.kind == _LayoutIssueKind.singleLine).length}',
  );
  buf.writeln(
    '  Multi-line (card): '
    '${flags.where((f) => f.kind == _LayoutIssueKind.multiLine).length}',
  );
  buf.writeln('');
  for (final e in _kCriticalStrings) {
    for (final loc in _DravidianLocale.values) {
      final locFlags = _layoutFlagsFor(e, loc);
      if (locFlags.isEmpty) {
        buf.writeln('[${e.category.label}] ${e.id} · ${loc.localeCode} · OK');
      } else {
        for (final f in locFlags) {
          final kind =
              f.kind == _LayoutIssueKind.singleLine ? 'BTN_OVERFLOW' : 'LINE_BREAK';
          buf.writeln('[${e.category.label}] ${e.id} · ${loc.localeCode} · $kind');
        }
      }
      buf.writeln('  EN: ${e.english}');
      buf.writeln('  ${loc.label}: ${e.textFor(loc)}');
      buf.writeln(
        '  Context: ${e.context} · btn ${e.buttonMaxWidth.round()}px · '
        'card ${e.cardMaxWidth.round()}px',
      );
      buf.writeln('');
    }
  }
  return buf.toString();
}

// ── Screen ────────────────────────────────────────────────────────────────────
class Day237TamilTeluguQaScreen extends ConsumerWidget {
  const Day237TamilTeluguQaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d237TabProvider);
    final flagCount = _allLayoutFlags().length;

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 237 · TA/TE Layout QA'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: flagCount == 0
                      ? ZapColors.safe.withOpacity(0.15)
                      : ZapColors.warning.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: flagCount == 0
                        ? ZapColors.safe.withOpacity(0.45)
                        : ZapColors.warning.withOpacity(0.45),
                  ),
                ),
                child: Text(
                  flagCount == 0 ? '0 FLAGS' : '$flagCount FLAGS',
                  style: TextStyle(
                    color: flagCount == 0 ? ZapColors.safe : ZapColors.warning,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _TabBar(
            tab: tab,
            onSelect: (i) => ref.read(_d237TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (tab) {
              0 => const _CompareTab(),
              1 => const _LayoutTab(),
              _ => const _ReportTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Compare ────────────────────────────────────────────────────────────
class _CompareTab extends ConsumerWidget {
  const _CompareTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = ref.watch(_d237CategoryProvider);
    final entries = _filteredEntries(category);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: ZapColors.safe.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: ZapColors.safe.withOpacity(0.35)),
          ),
          child: const Text(
            '🟢 FRONTEND-ONLY · Section B Day 17/20 · 20 critical ta_IN / te_IN strings · long-script layout',
            style: TextStyle(color: ZapColors.safe, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            FilterChip(
              label: const Text('All', style: TextStyle(fontSize: 10)),
              selected: category == null,
              onSelected: (_) =>
                  ref.read(_d237CategoryProvider.notifier).state = null,
            ),
            ..._StringCategory.values.map(
              (c) => FilterChip(
                label: Text(c.label, style: const TextStyle(fontSize: 10)),
                selected: category == c,
                onSelected: (_) =>
                    ref.read(_d237CategoryProvider.notifier).state = c,
              ),
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: ZapSpacing.md,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(color: ZapColors.border),
          ),
          child: const Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'English',
                  style: TextStyle(
                    color: ZapColors.info,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  'Tamil',
                  style: TextStyle(
                    color: Color(0xFFEC4899),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  'Telugu',
                  style: TextStyle(
                    color: Color(0xFF14B8A6),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...entries.map((e) => _CompareRow(entry: e)),
        const SizedBox(height: ZapSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              label: const Text('Day 236 Hindi QA'),
              onPressed: () => context.push(AppRoutes.hindiUxQa),
            ),
            ActionChip(
              label: const Text('Day 238 Emergency #s'),
              onPressed: () => context.push(AppRoutes.regionEmergencyNumbers),
            ),
            ActionChip(
              label: const Text('Day 126 UI bugs'),
              onPressed: () => context.push(AppRoutes.uiBugs),
            ),
          ],
        ),
      ],
    );
  }
}

class _CompareRow extends StatelessWidget {
  final _DravidianStringEntry entry;

  const _CompareRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final taFlags = _layoutFlagsFor(entry, _DravidianLocale.tamil);
    final teFlags = _layoutFlagsFor(entry, _DravidianLocale.telugu);
    final hasIssue = taFlags.isNotEmpty || teFlags.isNotEmpty;

    return Container(
      decoration: const BoxDecoration(
        color: ZapColors.bgCard,
        border: Border(
          left: BorderSide(color: ZapColors.border),
          right: BorderSide(color: ZapColors.border),
          bottom: BorderSide(color: ZapColors.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: ZapSpacing.md,
              vertical: 6,
            ),
            color: entry.category.color.withOpacity(0.08),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: entry.category.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    entry.category.label,
                    style: TextStyle(
                      color: entry.category.color,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    entry.context,
                    style: const TextStyle(
                      color: ZapColors.textMuted,
                      fontSize: 9,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasIssue)
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: ZapColors.warning,
                    size: 14,
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: ZapSpacing.md,
              vertical: 10,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    entry.english,
                    style: const TextStyle(
                      color: ZapColors.textPrimary,
                      fontSize: 10,
                      height: 1.4,
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    entry.tamil,
                    style: const TextStyle(
                      color: Color(0xFFEC4899),
                      fontSize: 10,
                      height: 1.4,
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    entry.telugu,
                    style: const TextStyle(
                      color: Color(0xFF14B8A6),
                      fontSize: 10,
                      height: 1.4,
                    ),
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

// ── Tab 1: Layout ─────────────────────────────────────────────────────────────
class _LayoutTab extends ConsumerWidget {
  const _LayoutTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localeFilter = ref.watch(_d237LocaleFilterProvider);
    final flags = _allLayoutFlags(locale: localeFilter);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Long-script layout audit',
                style: TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                flags.isEmpty
                    ? 'No layout flags at current preview widths ✅'
                    : '${flags.length} issue(s): single-line button overflow or '
                        '3+ lines needed in 2-line card slots.',
                style: const TextStyle(
                  color: ZapColors.textSecondary,
                  fontSize: 11,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Wrap(
          spacing: 6,
          children: [
            FilterChip(
              label: const Text('All scripts', style: TextStyle(fontSize: 10)),
              selected: localeFilter == null,
              onSelected: (_) =>
                  ref.read(_d237LocaleFilterProvider.notifier).state = null,
            ),
            ..._DravidianLocale.values.map(
              (l) => FilterChip(
                label: Text(l.label, style: const TextStyle(fontSize: 10)),
                selected: localeFilter == l,
                onSelected: (_) =>
                    ref.read(_d237LocaleFilterProvider.notifier).state = l,
              ),
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.lg),
        if (flags.isEmpty)
          const ZapEmptyInline(title: 'No layout flags for this filter.')
        else
          ...flags.map((f) => _LayoutIssueCard(flag: f)),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.warning.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.warning.withOpacity(0.3)),
          ),
          child: const Text(
            'Fix pattern: allow 2-line button labels · increase min tap height · '
            'use FittedBox only for nav icons · test at 200% font scale (Day 138).',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 11),
          ),
        ),
      ],
    );
  }
}

class _LayoutIssueCard extends StatelessWidget {
  final _LayoutFlag flag;

  const _LayoutIssueCard({required this.flag});

  @override
  Widget build(BuildContext context) {
    final entry = flag.entry;
    final text = entry.textFor(flag.locale);
    final isButton = flag.kind == _LayoutIssueKind.singleLine;
    final width = isButton ? entry.buttonMaxWidth : entry.cardMaxWidth;
    final badge = isButton ? 'BTN 1-LINE' : 'CARD 2-LINE';

    return Container(
      margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: flag.locale.color.withOpacity(0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: flag.locale.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  flag.locale.localeCode,
                  style: TextStyle(
                    color: flag.locale.color,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: Text(
                  entry.context,
                  style: const TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: ZapColors.warning.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    color: ZapColors.warning,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            'EN: ${entry.english}',
            style: const TextStyle(color: ZapColors.textMuted, fontSize: 10),
          ),
          const SizedBox(height: ZapSpacing.sm),
          Text(
            'Preview @ ${width.round()}px · maxLines: ${isButton ? 1 : 2}',
            style: const TextStyle(color: ZapColors.textMuted, fontSize: 9),
          ),
          const SizedBox(height: 6),
          Container(
            width: width,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: flag.locale.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: flag.locale.color.withOpacity(0.4)),
            ),
            child: Text(
              text,
              maxLines: isButton ? 1 : 2,
              overflow: TextOverflow.clip,
              style: _textStyle(entry),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab 2: Report ─────────────────────────────────────────────────────────────
class _ReportTab extends ConsumerWidget {
  const _ReportTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewed = ref.watch(_d237ReviewedProvider);
    final allFlags = _allLayoutFlags();
    final taFlags = _allLayoutFlags(locale: _DravidianLocale.tamil);
    final teFlags = _allLayoutFlags(locale: _DravidianLocale.telugu);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Row(
          children: [
            Expanded(
              child: _StatBox(
                label: 'Strings',
                value: '${_kCriticalStrings.length}',
                color: ZapColors.info,
              ),
            ),
            const SizedBox(width: ZapSpacing.sm),
            Expanded(
              child: _StatBox(
                label: 'Layout flags',
                value: '${allFlags.length}',
                color: allFlags.isEmpty ? ZapColors.safe : ZapColors.warning,
              ),
            ),
            const SizedBox(width: ZapSpacing.sm),
            Expanded(
              child: _StatBox(
                label: 'Reviewed',
                value: '${reviewed.length}/${_kCriticalStrings.length}',
                color: reviewed.length == _kCriticalStrings.length
                    ? ZapColors.safe
                    : ZapColors.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.md),
        _LocaleStatRow(
          locale: _DravidianLocale.tamil,
          flagCount: taFlags.length,
        ),
        _LocaleStatRow(
          locale: _DravidianLocale.telugu,
          flagCount: teFlags.length,
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Mark reviewed',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        ..._kCriticalStrings.map(
          (e) => CheckboxListTile(
            dense: true,
            value: reviewed.contains(e.id),
            onChanged: (v) {
              ref.read(_d237ReviewedProvider.notifier).update((set) {
                final next = Set<String>.from(set);
                if (v == true) {
                  next.add(e.id);
                } else {
                  next.remove(e.id);
                }
                return next;
              });
            },
            title: Text(
              e.english,
              style: const TextStyle(
                color: ZapColors.textPrimary,
                fontSize: 11,
              ),
            ),
            subtitle: Text(
              '${e.tamil} · ${e.telugu}',
              style: const TextStyle(
                color: ZapColors.textMuted,
                fontSize: 9,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            secondary: _entryHasIssue(e)
                ? const Icon(Icons.warning_amber_rounded,
                    color: ZapColors.warning, size: 18)
                : const Icon(Icons.check_circle_outline_rounded,
                    color: ZapColors.safe, size: 18),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () =>
                    ref.read(_d237ReviewedProvider.notifier).state = {},
                child: const Text('Clear reviewed'),
              ),
            ),
            const SizedBox(width: ZapSpacing.sm),
            Expanded(
              child: FilledButton(
                onPressed: () {
                  ref.read(_d237ReviewedProvider.notifier).state = {
                    for (final e in _kCriticalStrings) e.id,
                  };
                },
                style: FilledButton.styleFrom(backgroundColor: ZapColors.safe),
                child: const Text('Mark all reviewed'),
              ),
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.lg),
        FilledButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: _buildReport()));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Copied TA/TE layout report')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text('Copy full report'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            backgroundColor: ZapColors.info,
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.info.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.info.withOpacity(0.3)),
          ),
          child: const Text(
            'Tomorrow: Day 241 — Journey Mode v2 (Section C).',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatBox({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
            label,
            style: const TextStyle(color: ZapColors.textMuted, fontSize: 9),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocaleStatRow extends StatelessWidget {
  final _DravidianLocale locale;
  final int flagCount;

  const _LocaleStatRow({
    required this.locale,
    required this.flagCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(
        horizontal: ZapSpacing.md,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ZapColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: locale.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${locale.label} (${locale.localeCode})',
              style: const TextStyle(
                color: ZapColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ),
          Text(
            flagCount == 0 ? '0 flags' : '$flagCount flags',
            style: TextStyle(
              color: flagCount == 0 ? ZapColors.safe : ZapColors.warning,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
        ],
      ),
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
                      fontSize: 10,
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
