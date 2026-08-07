/// Day 216 — i18n Coverage Audit (15 Languages)
///
/// Section A (Days 201-220): translation completeness % per language per
/// namespace — mock JSON counts with missing-key drill-down.
///
/// Tag: 🟢 FRONTEND-ONLY — QA meta-screen, not live CI scan.
///
/// Route: [AppRoutes.i18nCoverageAudit] → `/i18n-coverage-audit`
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../domain/providers/i18n_providers.dart';

// ── Namespaces ────────────────────────────────────────────────────────────────
class I18nNamespaceInfo {
  final String id;
  final String label;
  final int totalKeys;

  const I18nNamespaceInfo({
    required this.id,
    required this.label,
    required this.totalKeys,
  });
}

const _kNamespaces = [
  I18nNamespaceInfo(id: 'auth', label: 'auth', totalKeys: 24),
  I18nNamespaceInfo(id: 'sos', label: 'sos', totalKeys: 32),
  I18nNamespaceInfo(id: 'settings', label: 'settings', totalKeys: 28),
  I18nNamespaceInfo(id: 'onboarding', label: 'onboarding', totalKeys: 20),
  I18nNamespaceInfo(id: 'alerts', label: 'alerts', totalKeys: 18),
  I18nNamespaceInfo(id: 'vault', label: 'vault', totalKeys: 22),
  I18nNamespaceInfo(id: 'profile', label: 'profile', totalKeys: 16),
  I18nNamespaceInfo(id: 'common', label: 'common', totalKeys: 40),
  I18nNamespaceInfo(id: 'detection', label: 'detection', totalKeys: 14),
  I18nNamespaceInfo(id: 'drills', label: 'drills', totalKeys: 12),
  I18nNamespaceInfo(id: 'billing', label: 'billing', totalKeys: 10),
];

/// Languages flagged for long-string UI overflow during QA (German, Tamil).
const _kOverflowRiskCodes = {'de', 'ta'};

const _kSampleLongStrings = {
  'de': 'Notfallbenachrichtigungseinstellungen',
  'ta': 'அவசரகால பாதுகாப்பு அறிவிப்பு அமைப்புகள்',
};

class I18nCoverageCell {
  final int translated;
  final int total;

  const I18nCoverageCell({required this.translated, required this.total});

  double get pct => total == 0 ? 0 : translated / total;

  int get missing => total - translated;

  bool get complete => missing == 0;
}

// ── Mock coverage matrix (parse JSON locally pattern) ─────────────────────────
int _langBasePct(String code) => switch (code) {
      'en' || 'hi' => 100,
      'es' => 91,
      'fr' => 88,
      'ta' => 87,
      'de' => 83,
      'te' => 82,
      'bn' => 78,
      'pt' => 76,
      'ml' => 74,
      'mr' => 69,
      'gu' => 61,
      'pa' => 55,
      'ur' => 48,
      'ar' => 43,
      _ => 70,
    };

int _nsModifier(String nsId) => switch (nsId) {
      'sos' => 0,
      'auth' => -1,
      'common' => -2,
      'settings' => -1,
      'onboarding' => 2,
      'alerts' => 1,
      'vault' => 0,
      'profile' => 3,
      'detection' => -3,
      'drills' => -4,
      'billing' => -5,
      _ => 0,
    };

I18nCoverageCell _cellFor(String langCode, I18nNamespaceInfo ns) {
  if (langCode == 'en') {
    return I18nCoverageCell(translated: ns.totalKeys, total: ns.totalKeys);
  }
  final pct = (_langBasePct(langCode) + _nsModifier(ns.id)).clamp(35, 100);
  final translated = (ns.totalKeys * pct / 100).round().clamp(0, ns.totalKeys);
  return I18nCoverageCell(translated: translated, total: ns.totalKeys);
}

const _kMissingKeyPools = {
  'auth': [
    'auth.login.title',
    'auth.login.subtitle',
    'auth.signup.phone_hint',
    'auth.otp.resend',
    'auth.biometric.prompt',
  ],
  'sos': [
    'sos.trigger.label',
    'sos.countdown.remaining',
    'sos.cancel.confirm',
    'sos.escalation.tier2',
    'sos.resolved.message',
  ],
  'settings': [
    'settings.dnd.quiet_hours',
    'settings.notifications.sms_fallback',
    'settings.accessibility.font_scale',
    'settings.privacy.data_export',
  ],
  'onboarding': [
    'onboarding.step2.contacts_title',
    'onboarding.step3.location_rationale',
    'onboarding.step5.review_empty',
  ],
  'alerts': [
    'alerts.pending.title',
    'alerts.lifecycle.escalating',
    'alerts.dashboard.empty',
  ],
  'vault': [
    'vault.empty.title',
    'vault.filter.tampered',
    'vault.entry.download',
  ],
  'profile': [
    'profile.edit.display_name',
    'profile.security.sessions',
    'profile.delete.grace_period',
  ],
  'common': [
    'common.save',
    'common.retry',
    'common.offline_banner',
    'common.loading',
  ],
  'detection': [
    'detection.dcs.score_label',
    'detection.model.fall',
  ],
  'drills': [
    'drills.history.empty',
    'drills.schedule.weekly',
  ],
  'billing': [
    'billing.plan.annual',
    'billing.invoice.failed',
  ],
};

List<String> missingKeysFor(String langCode, I18nNamespaceInfo ns) {
  final cell = _cellFor(langCode, ns);
  if (cell.missing <= 0) return const [];
  final pool = _kMissingKeyPools[ns.id] ?? ['${ns.id}.missing_key'];
  final extras = List.generate(
    cell.missing - pool.length,
    (i) => '${ns.id}.key_${i + pool.length + 1}',
  );
  return [...pool.take(cell.missing), ...extras].take(cell.missing).toList();
}

int overallPctFor(String langCode) {
  var translated = 0;
  var total = 0;
  for (final ns in _kNamespaces) {
    final cell = _cellFor(langCode, ns);
    translated += cell.translated;
    total += cell.total;
  }
  return total == 0 ? 0 : ((translated / total) * 100).round();
}

// ── Providers ─────────────────────────────────────────────────────────────────
final _d216TabProvider = StateProvider<int>((ref) => 0);
final _d216SelectedLangProvider = StateProvider<String>((ref) => 'ta');
final _d216ExpandedNsProvider = StateProvider<String?>((ref) => null);
final _d216FilterProvider = StateProvider<_CoverageFilter>(
  (ref) => _CoverageFilter.all,
);

enum _CoverageFilter { all, incomplete, overflowRisk, rtl }

const _kTabs = ['Coverage', 'Missing Keys', 'Export'];

// ── Screen ────────────────────────────────────────────────────────────────────
class Day216I18nCoverageAuditScreen extends ConsumerWidget {
  const Day216I18nCoverageAuditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d216TabProvider);
    final selected = ref.watch(_d216SelectedLangProvider);
    final overall = overallPctFor(selected);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 216 · i18n Coverage'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Text(
                '$overall%',
                style: TextStyle(
                  color: overall >= 100
                      ? ZapColors.safe
                      : overall >= 80
                          ? ZapColors.info
                          : ZapColors.warning,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
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
            onSelect: (i) => ref.read(_d216TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (tab) {
              0 => const _CoverageTab(),
              1 => const _MissingKeysTab(),
              _ => const _ExportTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Coverage table ─────────────────────────────────────────────────────
class _CoverageTab extends ConsumerWidget {
  const _CoverageTab();

  List<LangInfo> _filtered(_CoverageFilter filter) {
    return kSupportedLanguages.where((lang) {
      return switch (filter) {
        _CoverageFilter.all => true,
        _CoverageFilter.incomplete => overallPctFor(lang.code) < 100,
        _CoverageFilter.overflowRisk => _kOverflowRiskCodes.contains(lang.code),
        _CoverageFilter.rtl => lang.rtl,
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(_d216SelectedLangProvider);
    final filter = ref.watch(_d216FilterProvider);

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
            '🟢 FRONTEND-ONLY · Section A Day 16/20 · 15 langs × 11 namespaces',
            style: TextStyle(color: ZapColors.info, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        const Text(
          'Tap a language row to inspect missing keys. Progress bars show '
          'translated key count per namespace (mock JSON audit).',
          style: TextStyle(color: ZapColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: ZapSpacing.md),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(
                label: 'All',
                selected: filter == _CoverageFilter.all,
                onTap: () => ref.read(_d216FilterProvider.notifier).state =
                    _CoverageFilter.all,
              ),
              _FilterChip(
                label: 'Incomplete',
                selected: filter == _CoverageFilter.incomplete,
                onTap: () => ref.read(_d216FilterProvider.notifier).state =
                    _CoverageFilter.incomplete,
              ),
              _FilterChip(
                label: 'Overflow risk',
                selected: filter == _CoverageFilter.overflowRisk,
                onTap: () => ref.read(_d216FilterProvider.notifier).state =
                    _CoverageFilter.overflowRisk,
              ),
              _FilterChip(
                label: 'RTL',
                selected: filter == _CoverageFilter.rtl,
                onTap: () => ref.read(_d216FilterProvider.notifier).state =
                    _CoverageFilter.rtl,
              ),
            ],
          ),
        ),
        if (_kOverflowRiskCodes.isNotEmpty) ...[
          const SizedBox(height: ZapSpacing.md),
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ZapColors.warning.withOpacity(0.35)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: ZapColors.warning, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Long-string overflow risk: German (de) and Tamil (ta) — '
                    'run Day 215 font-scale regression on settings rows.',
                    style: TextStyle(color: ZapColors.textSecondary, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: ZapSpacing.lg),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: _CoverageTable(
            languages: _filtered(filter),
            selectedCode: selected,
            onSelect: (code) {
              ref.read(_d216SelectedLangProvider.notifier).state = code;
              ref.read(_d216TabProvider.notifier).state = 1;
            },
          ),
        ),
      ],
    );
  }
}

class _CoverageTable extends StatelessWidget {
  final List<LangInfo> languages;
  final String selectedCode;
  final ValueChanged<String> onSelect;

  const _CoverageTable({
    required this.languages,
    required this.selectedCode,
    required this.onSelect,
  });

  static const _colLang = 120.0;
  static const _colNs = 72.0;
  static const _rowH = 52.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ZapColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 40,
            child: Row(
              children: [
                const _HeaderCell(width: _colLang, label: 'Language'),
                ..._kNamespaces.map(
                  (ns) => _HeaderCell(width: _colNs, label: ns.label),
                ),
                const _HeaderCell(width: 48, label: 'Σ'),
              ],
            ),
          ),
          const Divider(height: 1, color: ZapColors.border),
          ...languages.map((lang) {
            final selected = lang.code == selectedCode;
            final overflowRisk = _kOverflowRiskCodes.contains(lang.code);
            return Semantics(
              label:
                  '${lang.name}. Overall ${overallPctFor(lang.code)} percent. '
                  'Tap to view missing keys.',
              button: true,
              selected: selected,
              child: Material(
                color: selected
                    ? ZapColors.info.withOpacity(0.08)
                    : Colors.transparent,
                child: InkWell(
                  onTap: () => onSelect(lang.code),
                  child: SizedBox(
                    height: _rowH,
                    child: Row(
                      children: [
                        SizedBox(
                          width: _colLang,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              children: [
                                Text(lang.flag, style: const TextStyle(fontSize: 14)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        lang.code.toUpperCase(),
                                        style: TextStyle(
                                          color: overflowRisk
                                              ? ZapColors.warning
                                              : ZapColors.textPrimary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 10,
                                        ),
                                      ),
                                      Text(
                                        lang.nativeName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: ZapColors.textMuted,
                                          fontSize: 9,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (overflowRisk)
                                  const Icon(
                                    Icons.straighten_rounded,
                                    size: 12,
                                    color: ZapColors.warning,
                                  ),
                                if (lang.rtl)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 2),
                                    child: Text(
                                      'RTL',
                                      style: TextStyle(
                                        color: ZapColors.info,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        ..._kNamespaces.map((ns) {
                          final cell = _cellFor(lang.code, ns);
                          return SizedBox(
                            width: _colNs,
                            child: _NsProgressBar(cell: cell),
                          );
                        }),
                        SizedBox(
                          width: 48,
                          child: Center(
                            child: Text(
                              '${overallPctFor(lang.code)}',
                              style: TextStyle(
                                color: overallPctFor(lang.code) >= 100
                                    ? ZapColors.safe
                                    : ZapColors.textSecondary,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final double width;
  final String label;

  const _HeaderCell({required this.width, required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: ZapColors.textMuted,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _NsProgressBar extends StatelessWidget {
  final I18nCoverageCell cell;

  const _NsProgressBar({required this.cell});

  @override
  Widget build(BuildContext context) {
    final color = cell.complete
        ? ZapColors.safe
        : cell.pct >= 0.8
            ? ZapColors.info
            : cell.pct >= 0.6
                ? ZapColors.warning
                : ZapColors.danger;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: cell.pct,
              minHeight: 6,
              backgroundColor: ZapColors.bgElevated,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${cell.translated}',
            style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: ZapColors.info.withOpacity(0.25),
        checkmarkColor: ZapColors.info,
      ),
    );
  }
}

// ── Tab 1: Missing keys ───────────────────────────────────────────────────────
class _MissingKeysTab extends ConsumerWidget {
  const _MissingKeysTab();

  LangInfo? _lang(String code) {
    for (final l in kSupportedLanguages) {
      if (l.code == code) return l;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = ref.watch(_d216SelectedLangProvider);
    final expanded = ref.watch(_d216ExpandedNsProvider);
    final lang = _lang(code);
    if (lang == null) return const SizedBox.shrink();

    final overall = overallPctFor(code);
    final overflowRisk = _kOverflowRiskCodes.contains(code);
    var totalMissing = 0;

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.border),
          ),
          child: Row(
            children: [
              Text(lang.flag, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: ZapSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang.nativeName,
                      style: const TextStyle(
                        color: ZapColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${lang.name} · ${lang.code} · $overall% overall',
                      style: const TextStyle(
                        color: ZapColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (overflowRisk)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: ZapColors.warning.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: ZapColors.warning.withOpacity(0.4)),
                  ),
                  child: const Text(
                    'OVERFLOW',
                    style: TextStyle(
                      color: ZapColors.warning,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (overflowRisk && _kSampleLongStrings.containsKey(code)) ...[
          const SizedBox(height: ZapSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.warning.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ZapColors.warning.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Long-string sample (UI overflow risk)',
                  style: TextStyle(
                    color: ZapColors.warning,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _kSampleLongStrings[code]!,
                  style: const TextStyle(
                    color: ZapColors.textPrimary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: ZapSpacing.lg),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kSupportedLanguages.map((l) {
            final sel = l.code == code;
            return ActionChip(
              label: Text('${l.flag} ${l.code}'),
              onPressed: () =>
                  ref.read(_d216SelectedLangProvider.notifier).state = l.code,
              backgroundColor:
                  sel ? ZapColors.info.withOpacity(0.2) : ZapColors.bgElevated,
            );
          }).toList(),
        ),
        const SizedBox(height: ZapSpacing.lg),
        ..._kNamespaces.map((ns) {
          final keys = missingKeysFor(code, ns);
          totalMissing += keys.length;
          if (keys.isEmpty) return const SizedBox.shrink();
          final isOpen = expanded == ns.id;
          return Container(
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            decoration: BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ZapColors.border),
            ),
            child: Column(
              children: [
                Semantics(
                  label: '${ns.label} namespace. ${keys.length} missing keys.',
                  button: true,
                  expanded: isOpen,
                  child: ListTile(
                    dense: true,
                    title: Text(
                      ns.label,
                      style: const TextStyle(
                        color: ZapColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Text(
                      '${keys.length} missing · ${ns.totalKeys} total keys',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: Icon(
                      isOpen
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: ZapColors.textMuted,
                    ),
                    onTap: () {
                      ref.read(_d216ExpandedNsProvider.notifier).state =
                          isOpen ? null : ns.id;
                    },
                  ),
                ),
                if (isOpen)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      ZapSpacing.md,
                      0,
                      ZapSpacing.md,
                      ZapSpacing.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: keys.map((key) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: ZapColors.bgSurface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: ZapColors.border),
                          ),
                          child: Text(
                            key,
                            style: const TextStyle(
                              color: ZapColors.danger,
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          );
        }),
        if (totalMissing == 0)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ZapSpacing.lg),
            decoration: BoxDecoration(
              color: ZapColors.safe.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ZapColors.safe.withOpacity(0.4)),
            ),
            child: const Column(
              children: [
                Icon(Icons.check_circle_rounded, color: ZapColors.safe, size: 36),
                SizedBox(height: ZapSpacing.sm),
                Text(
                  '100% coverage — no missing keys',
                  style: TextStyle(
                    color: ZapColors.safe,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ── Tab 2: Export ─────────────────────────────────────────────────────────────
class _ExportTab extends ConsumerWidget {
  const _ExportTab();

  String _buildSummary() {
    final buf = StringBuffer()
      ..writeln('ZapSafe i18n Coverage Audit — Day 216')
      ..writeln('15 languages · ${_kNamespaces.length} namespaces')
      ..writeln('')
      ..writeln('── Per language ──');
    for (final lang in kSupportedLanguages) {
      final overall = overallPctFor(lang.code);
      final risk = _kOverflowRiskCodes.contains(lang.code) ? ' [OVERFLOW RISK]' : '';
      final rtl = lang.rtl ? ' [RTL]' : '';
      buf.writeln(
        '${lang.code.toUpperCase()} ${lang.nativeName}: $overall%$risk$rtl',
      );
    }
    buf.writeln('');
    buf.writeln('── Namespace totals (keys) ──');
    for (final ns in _kNamespaces) {
      buf.writeln('${ns.label}: ${ns.totalKeys} keys');
    }
    return buf.toString();
  }

  String _buildCsv() {
    final buf = StringBuffer()
      ..write('language,code,overall_pct,overflow_risk,rtl');
    for (final ns in _kNamespaces) {
      buf.write(',${ns.id}_pct,${ns.id}_missing');
    }
    buf.writeln('');
    for (final lang in kSupportedLanguages) {
      buf.write(
        '${lang.name},${lang.code},${overallPctFor(lang.code)},'
        '${_kOverflowRiskCodes.contains(lang.code)},${lang.rtl}',
      );
      for (final ns in _kNamespaces) {
        final cell = _cellFor(lang.code, ns);
        buf.write(
          ',${(cell.pct * 100).round()},${cell.missing}',
        );
      }
      buf.writeln('');
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = _buildSummary();
    final csv = _buildCsv();
    final completeLangs = kSupportedLanguages
        .where((l) => overallPctFor(l.code) >= 100)
        .length;

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text(
          'Export coverage audit',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Text(
          '$completeLangs / ${kSupportedLanguages.length} languages at 100% overall',
          style: TextStyle(
            color: completeLangs == kSupportedLanguages.length
                ? ZapColors.safe
                : ZapColors.textSecondary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.border),
          ),
          child: Text(
            summary,
            style: const TextStyle(
              color: ZapColors.textSecondary,
              fontSize: 11,
              fontFamily: 'monospace',
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Semantics(
          label: 'Copy coverage summary',
          button: true,
          child: FilledButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: summary));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Summary copied')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy summary'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 75),
              backgroundColor: ZapColors.info,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Semantics(
          label: 'Copy CSV matrix',
          button: true,
          child: FilledButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: csv));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('CSV copied')),
              );
            },
            icon: const Icon(Icons.table_chart_rounded, size: 18),
            label: const Text('Copy CSV'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 75),
              backgroundColor: ZapColors.bgElevated,
              foregroundColor: ZapColors.textPrimary,
            ),
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
            'Tomorrow: Day 218 — TFLite real model integration checklist (M1–M8).',
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
