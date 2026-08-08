/// Day 96-97 — Language Settings & Localization screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../domain/providers/localization_providers.dart';

// ─── Root screen ──────────────────────────────────────────────────────────────

class Day96LanguageSettingsScreen extends ConsumerWidget {
  const Day96LanguageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lState   = ref.watch(localizationProvider);
    final applied  = ref.watch(appliedLanguageProvider);
    final selected = ref.watch(selectedLanguageProvider);
    final stats    = ref.watch(translationStatsProvider);
    final filtered = ref.watch(filteredLanguagesProvider);
    final notifier = ref.read(localizationProvider.notifier);

    // SnackBar on successful apply
    ref.listen(localizationProvider, (prev, next) {
      if (prev?.isApplying == true && !next.isApplying) {
        final lang = kAppLanguages
            .firstWhere((l) => l.code == next.appliedCode);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Language set to ${lang.nativeName} (${lang.englishName})'),
            backgroundColor: ZapColors.safe,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: ZapColors.bgPrimary,
        surfaceTintColor: Colors.transparent,
        title: const Text('Language & Region',
            style: ZapTypography.headlineSmall),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 20, color: ZapColors.textPrimary),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  ZapSpacing.lg, 0, ZapSpacing.lg, ZapSpacing.xxl),
              children: [
                // ── Stats card ────────────────────────────────
                _StatsCard(stats: stats),
                const SizedBox(height: ZapSpacing.lg),

                // ── Current language banner ───────────────────
                _CurrentLanguageBanner(language: applied),
                const SizedBox(height: ZapSpacing.lg),

                // ── Search field ──────────────────────────────
                _SearchField(
                    onChanged: notifier.setSearch),
                const SizedBox(height: ZapSpacing.lg),

                // ── Region groups ─────────────────────────────
                if (filtered.isEmpty)
                  const _EmptyState()
                else
                  _LanguageList(
                    languages:   filtered,
                    lState:      lState,
                    onSelect:    notifier.select,
                  ),

                // ── Live preview ──────────────────────────────
                const SizedBox(height: ZapSpacing.xxl),
                _LivePreview(selected: selected),
                const SizedBox(height: 100), // space for CTA
              ],
            ),
          ),

          // ── Sticky apply bar ──────────────────────────────────
          _ApplyBar(
            lState:   lState,
            selected: selected,
            notifier: notifier,
          ),
        ],
      ),
    );
  }
}

// ─── Stats card ───────────────────────────────────────────────────────────────

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats});
  final TranslationStats stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A2744), Color(0xFF0D1B38)],
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.info.withAlpha(51)),
      ),
      padding: const EdgeInsets.all(ZapSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: _StatCell(
              value: '${stats.total}',
              label: 'Languages',
              color: ZapColors.info,
              icon: Icons.language_rounded,
            ),
          ),
          _Div(),
          Expanded(
            child: _StatCell(
              value: '${stats.complete}',
              label: 'Complete',
              color: ZapColors.safe,
              icon: Icons.check_circle_rounded,
            ),
          ),
          _Div(),
          Expanded(
            child: _StatCell(
              value: '${stats.partial}',
              label: 'Partial',
              color: ZapColors.warning,
              icon: Icons.timelapse_rounded,
            ),
          ),
          _Div(),
          const Expanded(
            child: _StatCell(
              value: '2',
              label: 'RTL',
              color: ZapColors.textSecondary,
              icon: Icons.format_textdirection_r_to_l_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.value,
    required this.label,
    required this.color,
    required this.icon,
  });
  final String   value;
  final String   label;
  final Color    color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: ZapSpacing.xs),
        Text(value,
            style: ZapTypography.labelLarge
                .copyWith(color: ZapColors.textPrimary)),
        const SizedBox(height: 2),
        Text(label,
            style: ZapTypography.bodySmall
                .copyWith(color: ZapColors.textSecondary)),
      ],
    );
  }
}

class _Div extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      margin:
          const EdgeInsets.symmetric(horizontal: ZapSpacing.sm),
      color: ZapColors.divider,
    );
  }
}

// ─── Current language banner ──────────────────────────────────────────────────

class _CurrentLanguageBanner extends StatelessWidget {
  const _CurrentLanguageBanner({required this.language});
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.safe.withAlpha(77)),
      ),
      padding: const EdgeInsets.all(ZapSpacing.lg),
      child: Row(
        children: [
          Text(language.flag,
              style: const TextStyle(fontSize: 28)),
          const SizedBox(width: ZapSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Active language',
                        style: ZapTypography.bodySmall
                            .copyWith(
                                color: ZapColors.textSecondary)),
                    const SizedBox(width: ZapSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: ZapSpacing.xs, vertical: 2),
                      decoration: BoxDecoration(
                        color: ZapColors.safe.withAlpha(26),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: ZapColors.safe.withAlpha(77)),
                      ),
                      child: Text('Applied',
                          style: ZapTypography.labelSmall
                              .copyWith(
                                  color: ZapColors.safe,
                                  fontSize: 10)),
                    ),
                  ],
                ),
                const SizedBox(height: ZapSpacing.xs),
                Text(language.nativeName,
                    style: ZapTypography.headlineSmall
                        .copyWith(color: ZapColors.textPrimary)),
                Text(language.englishName,
                    style: ZapTypography.bodySmall
                        .copyWith(color: ZapColors.textSecondary)),
              ],
            ),
          ),
          if (language.isRTL)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: ZapSpacing.sm, vertical: ZapSpacing.xs),
              decoration: BoxDecoration(
                color: ZapColors.warning.withAlpha(26),
                borderRadius:
                    BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                    color: ZapColors.warning.withAlpha(77)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                      Icons.format_textdirection_r_to_l_rounded,
                      size: 12,
                      color: ZapColors.warning),
                  const SizedBox(width: 3),
                  Text('RTL',
                      style: ZapTypography.labelSmall
                          .copyWith(color: ZapColors.warning)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Search field ─────────────────────────────────────────────────────────────

class _SearchField extends StatefulWidget {
  const _SearchField({required this.onChanged});
  final ValueChanged<String> onChanged;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      style: ZapTypography.bodyMedium
          .copyWith(color: ZapColors.textPrimary),
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        hintText: 'Search languages…',
        hintStyle: ZapTypography.bodyMedium
            .copyWith(color: ZapColors.textMuted),
        prefixIcon: const Icon(Icons.search_rounded,
            size: 20, color: ZapColors.textSecondary),
        suffixIcon: _ctrl.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear_rounded,
                    size: 18, color: ZapColors.textSecondary),
                onPressed: () {
                  _ctrl.clear();
                  widget.onChanged('');
                  setState(() {});
                },
              )
            : null,
        filled: true,
        fillColor: ZapColors.bgCard,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: ZapSpacing.lg, vertical: ZapSpacing.md),
        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(ZapSpacing.radius),
          borderSide: const BorderSide(color: ZapColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(ZapSpacing.radius),
          borderSide: const BorderSide(color: ZapColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(ZapSpacing.radius),
          borderSide:
              const BorderSide(color: ZapColors.info),
        ),
      ),
    );
  }
}

// ─── Language list ────────────────────────────────────────────────────────────

class _LanguageList extends StatelessWidget {
  const _LanguageList({
    required this.languages,
    required this.lState,
    required this.onSelect,
  });
  final List<AppLanguage>   languages;
  final LocalizationState   lState;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    // Group by region
    final regions = <String>[];
    final byRegion = <String, List<AppLanguage>>{};
    for (final lang in languages) {
      if (!byRegion.containsKey(lang.region)) {
        regions.add(lang.region);
        byRegion[lang.region] = [];
      }
      byRegion[lang.region]!.add(lang);
    }

    // If search active, flatten (no grouping)
    if (lState.searchQuery.isNotEmpty) {
      return Column(
        children: languages
            .map((l) => _LanguageTile(
                  language: l,
                  isSelected:
                      lState.selectedCode == l.code,
                  isApplied:
                      lState.appliedCode == l.code,
                  onTap: () => onSelect(l.code),
                ))
            .toList(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: regions.map((region) {
        final langs = byRegion[region]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                  bottom: ZapSpacing.sm, top: ZapSpacing.md),
              child: Text(region,
                  style: ZapTypography.labelSmall.copyWith(
                      color: ZapColors.textMuted,
                      letterSpacing: 0.8)),
            ),
            Container(
              decoration: BoxDecoration(
                color: ZapColors.bgCard,
                borderRadius:
                    BorderRadius.circular(ZapSpacing.radius),
                border: Border.all(color: ZapColors.border),
              ),
              child: Column(
                children: langs.asMap().entries.map((e) {
                  final i    = e.key;
                  final lang = e.value;
                  return Column(
                    children: [
                      if (i > 0)
                        const Divider(
                            color: ZapColors.divider, height: 1),
                      _LanguageTile(
                        language:   lang,
                        isSelected:
                            lState.selectedCode == lang.code,
                        isApplied:
                            lState.appliedCode == lang.code,
                        onTap: () => onSelect(lang.code),
                        inCard: true,
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.language,
    required this.isSelected,
    required this.isApplied,
    required this.onTap,
    this.inCard = false,
  });
  final AppLanguage language;
  final bool        isSelected;
  final bool        isApplied;
  final VoidCallback onTap;
  final bool        inCard;

  Color get _completionColor {
    if (language.completePct == 100) {
      return ZapColors.safe;
    }
    if (language.completePct >= 70) {
      return ZapColors.info;
    }
    if (language.completePct >= 40) {
      return ZapColors.warning;
    }
    return ZapColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: inCard
          ? BorderRadius.zero
          : BorderRadius.circular(ZapSpacing.radius),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: inCard
            ? null
            : BoxDecoration(
                color: isSelected
                    ? ZapColors.info.withAlpha(13)
                    : ZapColors.bgCard,
                borderRadius:
                    BorderRadius.circular(ZapSpacing.radius),
                border: Border.all(
                  color: isSelected
                      ? ZapColors.info
                      : ZapColors.border,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
        padding: const EdgeInsets.symmetric(
            horizontal: ZapSpacing.lg,
            vertical: ZapSpacing.md),
        child: Row(
          children: [
            // flag
            Text(language.flag,
                style: const TextStyle(fontSize: 22)),
            const SizedBox(width: ZapSpacing.md),

            // names + completion bar
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(language.nativeName,
                          style: ZapTypography.labelLarge
                              .copyWith(
                                  color: isSelected
                                      ? ZapColors.info
                                      : ZapColors.textPrimary)),
                      if (language.isRTL) ...[
                        const SizedBox(width: ZapSpacing.xs),
                        const Icon(
                          Icons
                              .format_textdirection_r_to_l_rounded,
                          size: 12,
                          color: ZapColors.warning,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${language.englishName}  ·  ${language.region}',
                    style: ZapTypography.bodySmall.copyWith(
                        color: ZapColors.textSecondary),
                  ),
                  const SizedBox(height: ZapSpacing.xs),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: language.completePct / 100,
                            backgroundColor: ZapColors.bgSurface,
                            color: _completionColor,
                            minHeight: 3,
                          ),
                        ),
                      ),
                      const SizedBox(width: ZapSpacing.sm),
                      Text('${language.completePct}%',
                          style: ZapTypography.labelSmall
                              .copyWith(
                                  color: _completionColor,
                                  fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: ZapSpacing.md),

            // applied / selected indicator
            if (isApplied)
              const Icon(Icons.check_circle_rounded,
                  size: 20, color: ZapColors.safe)
            else if (isSelected)
              const Icon(Icons.radio_button_checked_rounded,
                  size: 20, color: ZapColors.info)
            else
              const Icon(Icons.radio_button_unchecked_rounded,
                  size: 20, color: ZapColors.textMuted),
          ],
        ),
      ),
    );
  }
}

// ─── Live preview ─────────────────────────────────────────────────────────────

class _LivePreview extends StatelessWidget {
  const _LivePreview({required this.selected});
  final AppLanguage selected;

  static const _previewKeys = <String>[
    'trigger_sos',
    'im_safe',
    'cancel',
    'emergency_alert',
    'check_in',
    'safe_zone',
  ];

  static const _icons = <String, IconData>{
    'trigger_sos':     Icons.crisis_alert_rounded,
    'im_safe':         Icons.verified_user_rounded,
    'cancel':          Icons.cancel_rounded,
    'emergency_alert': Icons.warning_amber_rounded,
    'check_in':        Icons.timer_rounded,
    'safe_zone':       Icons.location_on_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final isRTL  = selected.isRTL;
    final sample = demoTranslate(selected.code, 'trigger_sos');
    // detect if translated (non-ASCII)
    final isTranslated = sample != 'Trigger SOS';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.preview_rounded,
                size: 16, color: ZapColors.textSecondary),
            const SizedBox(width: ZapSpacing.sm),
            Text('Live Preview',
                style: ZapTypography.labelLarge
                    .copyWith(color: ZapColors.textPrimary)),
            const Spacer(),
            Text(
              '${selected.flag}  ${selected.nativeName}',
              style: ZapTypography.bodySmall
                  .copyWith(color: ZapColors.textSecondary),
            ),
            if (isRTL) ...[
              const SizedBox(width: ZapSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: ZapSpacing.xs, vertical: 2),
                decoration: BoxDecoration(
                  color: ZapColors.warning.withAlpha(26),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: ZapColors.warning.withAlpha(77)),
                ),
                child: Text('RTL',
                    style: ZapTypography.labelSmall
                        .copyWith(
                            color: ZapColors.warning,
                            fontSize: 10)),
              ),
            ],
          ],
        ),
        const SizedBox(height: ZapSpacing.md),

        if (!isTranslated)
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.warning.withAlpha(13),
              borderRadius:
                  BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(
                  color: ZapColors.warning.withAlpha(51)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 14, color: ZapColors.warning),
                const SizedBox(width: ZapSpacing.sm),
                Text('Translation in progress',
                    style: ZapTypography.bodySmall
                        .copyWith(color: ZapColors.warning)),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius:
                  BorderRadius.circular(ZapSpacing.radius),
              border: Border.all(color: ZapColors.border),
            ),
            child: Directionality(
              textDirection:
                  isRTL ? TextDirection.rtl : TextDirection.ltr,
              child: Column(
                children:
                    _previewKeys.asMap().entries.map((entry) {
                  final i   = entry.key;
                  final key = entry.value;
                  final en  = demoTranslate('en', key);
                  final tr  = demoTranslate(selected.code, key);
                  final icon = _icons[key] ??
                      Icons.label_rounded;

                  return Column(
                    children: [
                      if (i > 0)
                        const Divider(
                            color: ZapColors.divider, height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: ZapSpacing.lg,
                            vertical: ZapSpacing.sm),
                        child: Row(
                          children: [
                            Icon(icon,
                                size: 14,
                                color: ZapColors.textSecondary),
                            const SizedBox(width: ZapSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(tr,
                                      style: ZapTypography
                                          .bodyMedium
                                          .copyWith(
                                              color: ZapColors
                                                  .textPrimary)),
                                  if (tr != en)
                                    Text(en,
                                        style: ZapTypography
                                            .bodySmall
                                            .copyWith(
                                                color: ZapColors
                                                    .textMuted)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Apply bar ────────────────────────────────────────────────────────────────

class _ApplyBar extends StatelessWidget {
  const _ApplyBar({
    required this.lState,
    required this.selected,
    required this.notifier,
  });
  final LocalizationState   lState;
  final AppLanguage         selected;
  final LocalizationNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final hasPending   = lState.hasPendingChange;
    final isApplying   = lState.isApplying;

    return Container(
      decoration: const BoxDecoration(
        color: ZapColors.bgPrimary,
        border: Border(top: BorderSide(color: ZapColors.divider)),
      ),
      padding: EdgeInsets.fromLTRB(
        ZapSpacing.lg,
        ZapSpacing.md,
        ZapSpacing.lg,
        ZapSpacing.md + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // selected language summary
          if (hasPending || isApplying)
            Padding(
              padding:
                  const EdgeInsets.only(bottom: ZapSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(selected.flag,
                      style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: ZapSpacing.sm),
                  Text(
                    '${selected.nativeName}  (${selected.englishName})',
                    style: ZapTypography.bodySmall
                        .copyWith(color: ZapColors.textSecondary),
                  ),
                  if (selected.isRTL) ...[
                    const SizedBox(width: ZapSpacing.sm),
                    const Icon(
                        Icons
                            .format_textdirection_r_to_l_rounded,
                        size: 12,
                        color: ZapColors.warning),
                    const SizedBox(width: 2),
                    Text('RTL',
                        style: ZapTypography.labelSmall
                            .copyWith(
                                color: ZapColors.warning,
                                fontSize: 10)),
                  ],
                ],
              ),
            ),

          // apply button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: (!hasPending || isApplying)
                  ? null
                  : notifier.applyLanguage,
              style: FilledButton.styleFrom(
                backgroundColor: ZapColors.info,
                disabledBackgroundColor: ZapColors.bgElevated,
                padding: const EdgeInsets.symmetric(
                    vertical: ZapSpacing.lg),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(ZapSpacing.radius),
                ),
              ),
              child: isApplying
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white),
                    )
                  : Text(
                      hasPending
                          ? 'Apply  ${selected.flag}  ${selected.nativeName}'
                          : 'Language applied ✓',
                      style: ZapTypography.labelLarge.copyWith(
                        color: hasPending
                            ? Colors.white
                            : ZapColors.textMuted,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ZapSpacing.huge),
      child: Column(
        children: [
          const Icon(Icons.search_off_rounded,
              size: 48, color: ZapColors.textMuted),
          const SizedBox(height: ZapSpacing.lg),
          Text('No languages match your search',
              style: ZapTypography.labelLarge
                  .copyWith(color: ZapColors.textSecondary)),
          const SizedBox(height: ZapSpacing.sm),
          Text('Try a different name or language code.',
              style: ZapTypography.bodySmall
                  .copyWith(color: ZapColors.textMuted)),
        ],
      ),
    );
  }
}
