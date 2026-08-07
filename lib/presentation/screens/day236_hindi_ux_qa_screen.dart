/// Day 236 — India UX · Hindi Copy QA
///
/// Section B (Days 221-240): side-by-side EN/HI for 20 critical strings
/// (SOS, legal, onboarding, UI). Flags truncation in fixed-width previews.
///
/// Tag: 🟢 FRONTEND-ONLY · hi_IN locale QA gate.
///
/// Route: [AppRoutes.hindiUxQa] → `/hindi-ux-qa`
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

// ── String catalogue ──────────────────────────────────────────────────────────
enum _StringCategory { sos, legal, onboarding, ui }

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

class _HindiStringEntry {
  const _HindiStringEntry({
    required this.id,
    required this.category,
    required this.context,
    required this.english,
    required this.hindi,
    required this.previewMaxWidth,
    this.fontSize = 12,
  });

  final String id;
  final _StringCategory category;
  final String context;
  final String english;
  final String hindi;
  final double previewMaxWidth;
  final double fontSize;
}

const _kCriticalStrings = [
  _HindiStringEntry(
    id: 'sos_send',
    category: _StringCategory.sos,
    context: 'Primary SOS trigger button',
    english: 'Send SOS',
    hindi: 'SOS भेजें',
    previewMaxWidth: 140,
    fontSize: 14,
  ),
  _HindiStringEntry(
    id: 'sos_cancel',
    category: _StringCategory.sos,
    context: 'SOS countdown cancel (Day 126 bug)',
    english: 'Cancel SOS',
    hindi: 'SOS रद्द करें',
    previewMaxWidth: 100,
    fontSize: 13,
  ),
  _HindiStringEntry(
    id: 'sos_active',
    category: _StringCategory.sos,
    context: 'Active alert banner title',
    english: 'SOS Active',
    hindi: 'SOS सक्रिय',
    previewMaxWidth: 160,
  ),
  _HindiStringEntry(
    id: 'sos_contacts_notified',
    category: _StringCategory.sos,
    context: 'Post-send confirmation toast',
    english: 'Alert sent to contacts',
    hindi: 'अलर्ट आपातकालीन संपर्कों को भेजा गया',
    previewMaxWidth: 200,
  ),
  _HindiStringEntry(
    id: 'sos_services_notified',
    category: _StringCategory.sos,
    context: 'Emergency services status line',
    english: 'Emergency services notified',
    hindi: 'आपातकालीन सेवाओं को सूचित किया गया',
    previewMaxWidth: 190,
  ),
  _HindiStringEntry(
    id: 'sos_hold_confirm',
    category: _StringCategory.sos,
    context: 'Hold-to-confirm instruction',
    english: 'Hold to confirm SOS',
    hindi: 'SOS की पुष्टि के लिए दबाए रखें',
    previewMaxWidth: 150,
  ),
  _HindiStringEntry(
    id: 'legal_privacy',
    category: _StringCategory.legal,
    context: 'Settings · legal link',
    english: 'Privacy Policy',
    hindi: 'गोपनीयता नीति',
    previewMaxWidth: 160,
  ),
  _HindiStringEntry(
    id: 'legal_terms',
    category: _StringCategory.legal,
    context: 'Settings · legal link',
    english: 'Terms of Service',
    hindi: 'सेवा की शर्तें',
    previewMaxWidth: 160,
  ),
  _HindiStringEntry(
    id: 'legal_agree_continue',
    category: _StringCategory.legal,
    context: 'Onboarding consent footer',
    english: 'By continuing you agree to our Terms',
    hindi: 'जारी रखकर आप हमारी शर्तों से सहमत हैं',
    previewMaxWidth: 240,
  ),
  _HindiStringEntry(
    id: 'legal_data_encrypted',
    category: _StringCategory.legal,
    context: 'Privacy explainer bullet',
    english: 'Data stored locally encrypted',
    hindi: 'डेटा स्थानीय रूप से एन्क्रिप्टेड संग्रहीत होता है',
    previewMaxWidth: 210,
  ),
  _HindiStringEntry(
    id: 'legal_withdraw_consent',
    category: _StringCategory.legal,
    context: 'GDPR / DPDP consent note',
    english: 'You may withdraw consent anytime',
    hindi: 'आप कभी भी सहमति वापस ले सकते हैं',
    previewMaxWidth: 200,
  ),
  _HindiStringEntry(
    id: 'onboard_welcome',
    category: _StringCategory.onboarding,
    context: 'Splash / welcome headline',
    english: 'Welcome to ZapSafe',
    hindi: 'ZapSafe में आपका स्वागत है',
    previewMaxWidth: 280,
  ),
  _HindiStringEntry(
    id: 'onboard_add_contacts',
    category: _StringCategory.onboarding,
    context: 'Setup step CTA',
    english: 'Add emergency contacts',
    hindi: 'आपातकालीन संपर्क जोड़ें',
    previewMaxWidth: 220,
  ),
  _HindiStringEntry(
    id: 'onboard_enable_location',
    category: _StringCategory.onboarding,
    context: 'Permission rationale',
    english: 'Enable location for SOS',
    hindi: 'SOS के लिए स्थान सक्षम करें',
    previewMaxWidth: 220,
  ),
  _HindiStringEntry(
    id: 'onboard_complete_setup',
    category: _StringCategory.onboarding,
    context: 'Setup progress nudge',
    english: 'Complete setup to stay protected',
    hindi: 'सुरक्षित रहने के लिए सेटअप पूरा करें',
    previewMaxWidth: 220,
  ),
  _HindiStringEntry(
    id: 'onboard_skip',
    category: _StringCategory.onboarding,
    context: 'Secondary text button',
    english: 'Skip for now',
    hindi: 'अभी के लिए छोड़ें',
    previewMaxWidth: 88,
  ),
  _HindiStringEntry(
    id: 'ui_evidence_vault',
    category: _StringCategory.ui,
    context: 'Nav tab label',
    english: 'Evidence Vault',
    hindi: 'साक्ष्य वॉल्ट',
    previewMaxWidth: 68,
    fontSize: 10,
  ),
  _HindiStringEntry(
    id: 'ui_protection_score',
    category: _StringCategory.ui,
    context: 'Dashboard card title',
    english: 'Protection Score',
    hindi: 'सुरक्षा स्कोर',
    previewMaxWidth: 140,
  ),
  _HindiStringEntry(
    id: 'ui_checkin_timer',
    category: _StringCategory.ui,
    context: 'Feature tile',
    english: 'Check-in Timer',
    hindi: 'चेक-इन टाइमर',
    previewMaxWidth: 130,
  ),
  _HindiStringEntry(
    id: 'ui_settings',
    category: _StringCategory.ui,
    context: 'Bottom nav / drawer',
    english: 'Settings',
    hindi: 'सेटिंग्स',
    previewMaxWidth: 80,
    fontSize: 11,
  ),
];

bool _textOverflows(_HindiStringEntry entry) {
  final painter = TextPainter(
    text: TextSpan(
      text: entry.hindi,
      style: TextStyle(fontSize: entry.fontSize, fontWeight: FontWeight.w600),
    ),
    maxLines: 1,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: entry.previewMaxWidth);
  return painter.didExceedMaxLines;
}

List<_HindiStringEntry> _truncatedEntries() =>
    _kCriticalStrings.where(_textOverflows).toList(growable: false);

// ── Providers ─────────────────────────────────────────────────────────────────
final _d236TabProvider = StateProvider<int>((ref) => 0);
final _d236CategoryProvider =
    StateProvider<_StringCategory?>((ref) => null);
final _d236ReviewedProvider = StateProvider<Set<String>>((ref) => {});

const _kTabs = ['Compare', 'Truncation', 'Report'];

List<_HindiStringEntry> _filteredEntries(_StringCategory? category) {
  if (category == null) return _kCriticalStrings;
  return _kCriticalStrings.where((e) => e.category == category).toList();
}

String _buildReport() {
  final truncated = _truncatedEntries();
  final buf = StringBuffer('ZapSafe Hindi Copy QA — hi_IN\n');
  buf.writeln('Generated: ${DateTime.now().toIso8601String()}');
  buf.writeln('Total strings: ${_kCriticalStrings.length}');
  buf.writeln('Truncation flags: ${truncated.length}');
  buf.writeln('');
  for (final e in _kCriticalStrings) {
    final flag = _textOverflows(e) ? 'TRUNCATE' : 'OK';
    buf.writeln('[${e.category.label}] ${e.id} · $flag');
    buf.writeln('  EN: ${e.english}');
    buf.writeln('  HI: ${e.hindi}');
    buf.writeln('  Context: ${e.context} · max ${e.previewMaxWidth.round()}px');
    buf.writeln('');
  }
  return buf.toString();
}

// ── Screen ────────────────────────────────────────────────────────────────────
class Day236HindiUxQaScreen extends ConsumerWidget {
  const Day236HindiUxQaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d236TabProvider);
    final truncated = _truncatedEntries().length;
    final reviewed = ref.watch(_d236ReviewedProvider).length;

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 236 · Hindi Copy QA'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: truncated == 0
                      ? ZapColors.safe.withOpacity(0.15)
                      : ZapColors.warning.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: truncated == 0
                        ? ZapColors.safe.withOpacity(0.45)
                        : ZapColors.warning.withOpacity(0.45),
                  ),
                ),
                child: Text(
                  truncated == 0 ? '0 TRUNC' : '$truncated TRUNC',
                  style: TextStyle(
                    color: truncated == 0 ? ZapColors.safe : ZapColors.warning,
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
            onSelect: (i) => ref.read(_d236TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (tab) {
              0 => const _CompareTab(),
              1 => const _TruncationTab(),
              _ => _ReportTab(reviewed: reviewed),
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
    final category = ref.watch(_d236CategoryProvider);
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
            '🟢 FRONTEND-ONLY · Section B Day 16/20 · 20 critical hi_IN strings · SOS / legal / onboarding / UI',
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
                  ref.read(_d236CategoryProvider.notifier).state = null,
            ),
            ..._StringCategory.values.map(
              (c) => FilterChip(
                label: Text(c.label, style: const TextStyle(fontSize: 10)),
                selected: category == c,
                onSelected: (_) =>
                    ref.read(_d236CategoryProvider.notifier).state = c,
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
                flex: 4,
                child: Text(
                  'English',
                  style: TextStyle(
                    color: ZapColors.info,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Expanded(
                flex: 5,
                child: Text(
                  'Hindi (Devanagari)',
                  style: TextStyle(
                    color: Color(0xFFF59E0B),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...entries.map(
          (e) => _CompareRow(
            entry: e,
            truncates: _textOverflows(e),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              label: const Text('Day 238 Emergency #s'),
              onPressed: () => context.push(AppRoutes.regionEmergencyNumbers),
            ),
            ActionChip(
              label: const Text('Day 237 TA/TE layout'),
              onPressed: () => context.push(AppRoutes.tamilTeluguQa),
            ),
            ActionChip(
              label: const Text('Day 194 Hindi listing'),
              onPressed: () => context.push(AppRoutes.storeListingExtra),
            ),
          ],
        ),
      ],
    );
  }
}

class _CompareRow extends StatelessWidget {
  final _HindiStringEntry entry;
  final bool truncates;

  const _CompareRow({required this.entry, required this.truncates});

  @override
  Widget build(BuildContext context) {
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
                if (truncates)
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
                  flex: 4,
                  child: Text(
                    entry.english,
                    style: const TextStyle(
                      color: ZapColors.textPrimary,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: Text(
                    entry.hindi,
                    style: const TextStyle(
                      color: Color(0xFFF59E0B),
                      fontSize: 11,
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

// ── Tab 1: Truncation ─────────────────────────────────────────────────────────
class _TruncationTab extends ConsumerWidget {
  const _TruncationTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final truncated = _truncatedEntries();

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
                'Truncation audit',
                style: TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                truncated.isEmpty
                    ? 'All 20 strings fit their preview widths ✅'
                    : '${truncated.length} of ${_kCriticalStrings.length} strings overflow fixed-width previews (TextPainter @ design px).',
                style: const TextStyle(
                  color: ZapColors.textSecondary,
                  fontSize: 11,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        if (truncated.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(ZapSpacing.xl),
              child: Text(
                'No truncation flags — widen previews or add longer HI copy to test.',
                textAlign: TextAlign.center,
                style: TextStyle(color: ZapColors.textMuted, fontSize: 12),
              ),
            ),
          )
        else
          ...truncated.map((e) => _TruncationCard(entry: e)),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.warning.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.warning.withOpacity(0.3)),
          ),
          child: const Text(
            'Fix pattern (Day 126): replace fixed SizedBox(width:) with '
            'IntrinsicWidth + padding · allow maxLines: 2 · avoid ellipsis on SOS actions.',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        ActionChip(
          label: const Text('Day 126 UI bugs'),
          onPressed: () => context.push(AppRoutes.uiBugs),
        ),
      ],
    );
  }
}

class _TruncationCard extends StatelessWidget {
  final _HindiStringEntry entry;

  const _TruncationCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ZapColors.warning.withOpacity(0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.context,
                  style: const TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
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
                child: const Text(
                  'TRUNCATES',
                  style: TextStyle(
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
            'Preview @ ${entry.previewMaxWidth.round()}px',
            style: const TextStyle(color: ZapColors.textMuted, fontSize: 9),
          ),
          const SizedBox(height: 6),
          Container(
            width: entry.previewMaxWidth,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: ZapColors.danger.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ZapColors.danger.withOpacity(0.4)),
            ),
            child: Text(
              entry.hindi,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: TextStyle(
                color: ZapColors.textPrimary,
                fontSize: entry.fontSize,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            entry.hindi,
            style: const TextStyle(
              color: Color(0xFFF59E0B),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab 2: Report ─────────────────────────────────────────────────────────────
class _ReportTab extends ConsumerWidget {
  final int reviewed;

  const _ReportTab({required this.reviewed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewedSet = ref.watch(_d236ReviewedProvider);
    final truncated = _truncatedEntries();
    final allReviewed = reviewedSet.length >= _kCriticalStrings.length;

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        _StatGrid(
          total: _kCriticalStrings.length,
          truncated: truncated.length,
          reviewed: reviewedSet.length,
        ),
        const SizedBox(height: ZapSpacing.lg),
        ..._StringCategory.values.map((c) {
          final catEntries =
              _kCriticalStrings.where((e) => e.category == c).toList();
          final catTrunc =
              catEntries.where(_textOverflows).length;
          return _CategoryStatRow(
            category: c,
            total: catEntries.length,
            truncated: catTrunc,
          );
        }),
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
            value: reviewedSet.contains(e.id),
            onChanged: (v) {
              ref.read(_d236ReviewedProvider.notifier).update((set) {
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
              e.hindi,
              style: const TextStyle(
                color: Color(0xFFF59E0B),
                fontSize: 10,
              ),
            ),
            secondary: _textOverflows(e)
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
                    ref.read(_d236ReviewedProvider.notifier).state = {},
                child: const Text('Clear reviewed'),
              ),
            ),
            const SizedBox(width: ZapSpacing.sm),
            Expanded(
              child: FilledButton(
                onPressed: () {
                  ref.read(_d236ReviewedProvider.notifier).state = {
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
              const SnackBar(content: Text('Copied Hindi QA report')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text('Copy full report'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            backgroundColor: ZapColors.info,
          ),
        ),
        if (allReviewed && truncated.isNotEmpty) ...[
          const SizedBox(height: ZapSpacing.sm),
          Container(
            padding: const EdgeInsets.all(ZapSpacing.sm),
            decoration: BoxDecoration(
              color: ZapColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: ZapColors.warning.withOpacity(0.3)),
            ),
            child: Text(
              'Review complete · ${truncated.length} truncation fix(es) still open before hi_IN ship.',
              style: const TextStyle(
                color: ZapColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
        ],
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

class _StatGrid extends StatelessWidget {
  final int total;
  final int truncated;
  final int reviewed;

  const _StatGrid({
    required this.total,
    required this.truncated,
    required this.reviewed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatBox(
            label: 'Strings',
            value: '$total',
            color: ZapColors.info,
          ),
        ),
        const SizedBox(width: ZapSpacing.sm),
        Expanded(
          child: _StatBox(
            label: 'Truncation',
            value: '$truncated',
            color: truncated == 0 ? ZapColors.safe : ZapColors.warning,
          ),
        ),
        const SizedBox(width: ZapSpacing.sm),
        Expanded(
          child: _StatBox(
            label: 'Reviewed',
            value: '$reviewed/$total',
            color: reviewed == total ? ZapColors.safe : ZapColors.textMuted,
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

class _CategoryStatRow extends StatelessWidget {
  final _StringCategory category;
  final int total;
  final int truncated;

  const _CategoryStatRow({
    required this.category,
    required this.total,
    required this.truncated,
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
              color: category.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              category.label,
              style: const TextStyle(
                color: ZapColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ),
          Text(
            '$total strings',
            style: const TextStyle(color: ZapColors.textMuted, fontSize: 10),
          ),
          const SizedBox(width: ZapSpacing.md),
          Text(
            truncated == 0 ? '0 trunc' : '$truncated trunc',
            style: TextStyle(
              color: truncated == 0 ? ZapColors.safe : ZapColors.warning,
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
