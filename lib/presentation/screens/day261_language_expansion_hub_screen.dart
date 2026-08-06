/// Day 261 — Language Expansion Hub (25 Target)
///
/// Section D (Days 261-280): roadmap UI for 15 shipped + 10 planned
/// languages with completeness bars, filter, and expansion timeline.
///
/// Tag: 🟢 FRONTEND-ONLY · mock coverage from Day 216 matrix.
///
/// Route: [AppRoutes.languageExpansionHub] → `/language-expansion-hub`
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../domain/providers/i18n_providers.dart';
import '../navigation/app_router.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const _kAccent = Color(0xFF2563EB);
const _kTabs = ['Roadmap', 'Languages', 'Info'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');
const _kTargetLanguages = 25;
const _kTotalKeys = 236;

enum _LangFilter { all, shipped, planned }

class _PlannedLang {
  const _PlannedLang({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.flag,
    required this.completeness,
    required this.stage,
    this.rtl = false,
  });

  final String code;
  final String name;
  final String nativeName;
  final String flag;
  final int completeness;
  final String stage;
  final bool rtl;
}

const _kPlannedLanguages = [
  _PlannedLang(
    code: 'fa',
    name: 'Persian',
    nativeName: 'فارسی',
    flag: '🇮🇷',
    completeness: 8,
    stage: 'Day 263 RTL pack',
    rtl: true,
  ),
  _PlannedLang(
    code: 'id',
    name: 'Indonesian',
    nativeName: 'Bahasa Indonesia',
    flag: '🇮🇩',
    completeness: 5,
    stage: 'Day 264 pack',
  ),
  _PlannedLang(
    code: 'vi',
    name: 'Vietnamese',
    nativeName: 'Tiếng Việt',
    flag: '🇻🇳',
    completeness: 0,
    stage: 'Queued · Section D',
  ),
  _PlannedLang(
    code: 'th',
    name: 'Thai',
    nativeName: 'ไทย',
    flag: '🇹🇭',
    completeness: 0,
    stage: 'Queued · Section D',
  ),
  _PlannedLang(
    code: 'ja',
    name: 'Japanese',
    nativeName: '日本語',
    flag: '🇯🇵',
    completeness: 12,
    stage: 'AI draft · review',
  ),
  _PlannedLang(
    code: 'ko',
    name: 'Korean',
    nativeName: '한국어',
    flag: '🇰🇷',
    completeness: 0,
    stage: 'Queued · Section D',
  ),
  _PlannedLang(
    code: 'tr',
    name: 'Turkish',
    nativeName: 'Türkçe',
    flag: '🇹🇷',
    completeness: 0,
    stage: 'Queued · Section D',
  ),
  _PlannedLang(
    code: 'it',
    name: 'Italian',
    nativeName: 'Italiano',
    flag: '🇮🇹',
    completeness: 0,
    stage: 'Queued · Section D',
  ),
  _PlannedLang(
    code: 'nl',
    name: 'Dutch',
    nativeName: 'Nederlands',
    flag: '🇳🇱',
    completeness: 0,
    stage: 'Queued · Section D',
  ),
  _PlannedLang(
    code: 'sw',
    name: 'Swahili',
    nativeName: 'Kiswahili',
    flag: '🇰🇪',
    completeness: 0,
    stage: 'Queued · Section D',
  ),
];

int _shippedCompleteness(String code) => switch (code) {
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

Color _completenessColor(int pct) {
  if (pct >= 90) return ZapColors.safe;
  if (pct >= 70) return _kAccent;
  if (pct >= 50) return ZapColors.warning;
  if (pct > 0) return ZapColors.danger;
  return ZapColors.textMuted;
}

// ── Providers ─────────────────────────────────────────────────────────────────
final _d261TabProvider = StateProvider<int>((ref) => 0);
final _d261FilterProvider = StateProvider<_LangFilter>((ref) => _LangFilter.all);
final _d261SelectedCodeProvider = StateProvider<String>((ref) => 'en');

// ── Screen ────────────────────────────────────────────────────────────────────
class Day261LanguageExpansionHubScreen extends ConsumerWidget {
  const Day261LanguageExpansionHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d261TabProvider);
    final shippedCount = kSupportedLanguages.length;
    final plannedCount = _kPlannedLanguages.length;
    final avgShipped = kSupportedLanguages
            .map((l) => _shippedCompleteness(l.code))
            .fold<int>(0, (a, b) => a + b) /
        shippedCount;

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 261 · Language Hub'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _kAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _kAccent.withOpacity(0.45)),
                ),
                child: Text(
                  '$shippedCount/$_kTargetLanguages',
                  style: const TextStyle(
                    color: _kAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
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
            onSelect: (i) => ref.read(_d261TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (tab) {
              0 => _RoadmapTab(
                  shippedCount: shippedCount,
                  plannedCount: plannedCount,
                  avgShipped: avgShipped,
                ),
              1 => const _LanguagesTab(),
              _ => const _InfoTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Roadmap ────────────────────────────────────────────────────────────
class _RoadmapTab extends StatelessWidget {
  const _RoadmapTab({
    required this.shippedCount,
    required this.plannedCount,
    required this.avgShipped,
  });

  final int shippedCount;
  final int plannedCount;
  final double avgShipped;

  @override
  Widget build(BuildContext context) {
    final launchPct = (shippedCount / _kTargetLanguages * 100).round();

    return ListView(
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
            '🟢 FRONTEND-ONLY · Section D Day 1/20 · 25-language target',
            style: TextStyle(color: _kAccent, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.lg),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _kAccent.withOpacity(0.18),
                ZapColors.bgCard,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kAccent.withOpacity(0.35)),
          ),
          child: Column(
            children: [
              Text(
                '$launchPct%',
                style: const TextStyle(
                  color: _kAccent,
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Text(
                'Languages live in app',
                style: TextStyle(
                  color: ZapColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: ZapSpacing.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: shippedCount / _kTargetLanguages,
                  minHeight: 10,
                  backgroundColor: ZapColors.border,
                  color: _kAccent,
                ),
              ),
              const SizedBox(height: ZapSpacing.sm),
              Text(
                '$shippedCount shipped · $plannedCount planned · '
                'avg shipped coverage ${avgShipped.round()}%',
                style: const TextStyle(
                  color: ZapColors.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                value: '$shippedCount',
                label: 'Shipped',
                subtitle: 'EasyLocalization active',
                color: ZapColors.safe,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                value: '$plannedCount',
                label: 'Planned',
                subtitle: 'Section D packs',
                color: _kAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Expansion timeline',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        const _TimelineRow(
          phase: 'Phase 1 · Done',
          detail: '15 languages · Days 101-102 + Day 216 audit baseline',
          color: ZapColors.safe,
          done: true,
        ),
        const _TimelineRow(
          phase: 'Phase 2 · In progress',
          detail: 'fa · id · ja starter packs · Days 263-264',
          color: _kAccent,
          done: false,
        ),
        const _TimelineRow(
          phase: 'Phase 3 · Queued',
          detail: 'vi · th · ko · tr · it · nl · sw · remaining Section D',
          color: ZapColors.textMuted,
          done: false,
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Top gaps (shipped langs)',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        ...kSupportedLanguages
            .where((l) => _shippedCompleteness(l.code) < 70)
            .map(
              (l) => _LangBarRow(
                flag: l.flag,
                label: '${l.name} (${l.code})',
                pct: _shippedCompleteness(l.code),
                badge: 'Shipped',
                badgeColor: ZapColors.safe,
              ),
            ),
        const SizedBox(height: ZapSpacing.lg),
        FilledButton.icon(
          onPressed: () => context.push(AppRoutes.i18nCoverageAudit),
          icon: const Icon(Icons.table_chart_rounded, size: 18),
          label: const Text('Open Day 216 coverage audit'),
          style: FilledButton.styleFrom(
            backgroundColor: _kAccent,
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.subtitle,
    required this.color,
  });

  final String value;
  final String label;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(color: ZapColors.textMuted, fontSize: 9),
          ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.phase,
    required this.detail,
    required this.color,
    required this.done,
  });

  final String phase;
  final String detail;
  final Color color;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  phase,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
                Text(
                  detail,
                  style: const TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 10,
                    height: 1.4,
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

// ── Tab 1: Languages ──────────────────────────────────────────────────────────
class _LanguagesTab extends ConsumerWidget {
  const _LanguagesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(_d261FilterProvider);
    final selected = ref.watch(_d261SelectedCodeProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        SegmentedButton<_LangFilter>(
          segments: const [
            ButtonSegment(value: _LangFilter.all, label: Text('All 25')),
            ButtonSegment(value: _LangFilter.shipped, label: Text('Shipped')),
            ButtonSegment(value: _LangFilter.planned, label: Text('Planned')),
          ],
          selected: {filter},
          onSelectionChanged: (s) =>
              ref.read(_d261FilterProvider.notifier).state = s.first,
        ),
        const SizedBox(height: ZapSpacing.lg),
        if (filter == _LangFilter.all || filter == _LangFilter.shipped) ...[
          const Text(
            'Shipped (15)',
            style: TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          ...kSupportedLanguages.map((lang) {
            final pct = _shippedCompleteness(lang.code);
            return _LanguageTile(
              code: lang.code,
              flag: lang.flag,
              name: lang.name,
              nativeName: lang.nativeName,
              pct: pct,
              badge: lang.rtl ? 'RTL · Live' : 'Live',
              badgeColor: ZapColors.safe,
              stage: '$_kTotalKeys keys · EasyLocalization',
              selected: selected == lang.code,
              onTap: () =>
                  ref.read(_d261SelectedCodeProvider.notifier).state = lang.code,
            );
          }),
        ],
        if (filter == _LangFilter.all || filter == _LangFilter.planned) ...[
          if (filter == _LangFilter.all) const SizedBox(height: ZapSpacing.lg),
          const Text(
            'Planned (10)',
            style: TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          ..._kPlannedLanguages.map(
            (lang) => _LanguageTile(
              code: lang.code,
              flag: lang.flag,
              name: lang.name,
              nativeName: lang.nativeName,
              pct: lang.completeness,
              badge: lang.rtl ? 'RTL · Planned' : 'Planned',
              badgeColor: _kAccent,
              stage: lang.stage,
              selected: selected == lang.code,
              onTap: () =>
                  ref.read(_d261SelectedCodeProvider.notifier).state = lang.code,
            ),
          ),
        ],
      ],
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.code,
    required this.flag,
    required this.name,
    required this.nativeName,
    required this.pct,
    required this.badge,
    required this.badgeColor,
    required this.stage,
    required this.selected,
    required this.onTap,
  });

  final String code;
  final String flag;
  final String name;
  final String nativeName;
  final int pct;
  final String badge;
  final Color badgeColor;
  final String stage;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _completenessColor(pct);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(ZapSpacing.sm),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.08) : ZapColors.bgCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? color.withOpacity(0.45) : ZapColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(flag, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$name · $code',
                        style: const TextStyle(
                          color: ZapColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        nativeName,
                        style: const TextStyle(
                          color: ZapColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: badgeColor.withOpacity(0.35)),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _LangBarRow(flag: '', label: '', pct: pct, hideLabel: true),
            Text(
              stage,
              style: const TextStyle(
                color: ZapColors.textMuted,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LangBarRow extends StatelessWidget {
  const _LangBarRow({
    required this.flag,
    required this.label,
    required this.pct,
    this.badge,
    this.badgeColor,
    this.hideLabel = false,
  });

  final String flag;
  final String label;
  final int pct;
  final String? badge;
  final Color? badgeColor;
  final bool hideLabel;

  @override
  Widget build(BuildContext context) {
    final color = _completenessColor(pct);
    return Padding(
      padding: EdgeInsets.only(bottom: hideLabel ? 4 : 8),
      child: Row(
        children: [
          if (!hideLabel && flag.isNotEmpty) ...[
            Text(flag, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
          ],
          if (!hideLabel && label.isNotEmpty)
            SizedBox(
              width: 100,
              child: Text(
                label,
                style: const TextStyle(
                  color: ZapColors.textSecondary,
                  fontSize: 10,
                ),
              ),
            ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct / 100,
                minHeight: hideLabel ? 8 : 6,
                backgroundColor: ZapColors.border,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 36,
            child: Text(
              '$pct%',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (badge != null && badgeColor != null) ...[
            const SizedBox(width: 4),
            Text(
              badge!,
              style: TextStyle(color: badgeColor, fontSize: 8),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Tab 2: Info ───────────────────────────────────────────────────────────────
class _InfoTab extends ConsumerWidget {
  const _InfoTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(_d261SelectedCodeProvider);
    final shipped = kSupportedLanguages.any((l) => l.code == selected);
    final pct = shipped
        ? _shippedCompleteness(selected)
        : _kPlannedLanguages
            .firstWhere(
              (l) => l.code == selected,
              orElse: () => _kPlannedLanguages.first,
            )
            .completeness;

    final payload = {
      'endpoint': 'GET /api/v1/i18n/expansion-roadmap/',
      'target_languages': _kTargetLanguages,
      'shipped_count': kSupportedLanguages.length,
      'planned_count': _kPlannedLanguages.length,
      'total_keys': _kTotalKeys,
      'selected_locale': selected,
      'selected_completeness_pct': pct,
      'shipped_locales': [
        for (final l in kSupportedLanguages)
          {
            'code': l.code,
            'rtl': l.rtl,
            'completeness_pct': _shippedCompleteness(l.code),
          },
      ],
      'planned_locales': [
        for (final l in _kPlannedLanguages)
          {
            'code': l.code,
            'rtl': l.rtl,
            'completeness_pct': l.completeness,
            'stage': l.stage,
          },
      ],
    };

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _PolicyRow(
          icon: Icons.translate_rounded,
          title: '25-language target',
          subtitle:
              '15 locales ship today via EasyLocalization · 10 expansion packs '
              'roll out in Section D with completeness tracking.',
        ),
        const _PolicyRow(
          icon: Icons.format_line_spacing_rounded,
          title: 'Completeness bars',
          subtitle:
              'Percentages mirror Day 216 namespace matrix mock — not a live '
              'CI scan. Green ≥90% · blue ≥70% · amber ≥50%.',
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'API contract (mock)',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.border),
          ),
          child: SelectableText(
            _kJsonEncoder.convert(payload),
            style: const TextStyle(
              color: ZapColors.textSecondary,
              fontSize: 10,
              fontFamily: 'monospace',
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(
              ClipboardData(text: _kJsonEncoder.convert(payload)),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Expansion roadmap JSON copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy roadmap JSON'),
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
            'Next: Day 365 — Global Launch Milestone '
            '(Phase 2 finale · worldwide rollout).',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              label: const Text('Day 216 Coverage Audit'),
              onPressed: () => context.push(AppRoutes.i18nCoverageAudit),
            ),
            ActionChip(
              label: const Text('Day 101 i18n Setup'),
              onPressed: () => context.push(AppRoutes.i18nSetup),
            ),
            ActionChip(
              label: const Text('Day 102 Translation Demo'),
              onPressed: () => context.push(AppRoutes.translationDemo),
            ),
            ActionChip(
              label: const Text('Day 260 Section C Milestone'),
              onPressed: () =>
                  context.push(AppRoutes.sectionCAdvancedMilestone),
            ),
          ],
        ),
      ],
    );
  }
}

class _PolicyRow extends StatelessWidget {
  const _PolicyRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ZapSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: _kAccent),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 11,
                    height: 1.4,
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

class _TabBar extends StatelessWidget {
  const _TabBar({required this.tab, required this.onSelect});

  final int tab;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ZapColors.bgCard,
      child: Row(
        children: List.generate(_kTabs.length, (i) {
          final selected = tab == i;
          return Expanded(
            child: InkWell(
              onTap: () => onSelect(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected ? _kAccent : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  _kTabs[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? _kAccent : ZapColors.textMuted,
                    fontWeight:
                        selected ? FontWeight.w800 : FontWeight.w500,
                    fontSize: 12,
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
