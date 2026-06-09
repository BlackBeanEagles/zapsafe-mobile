/// Day 101 — i18n Setup Screen.
///
/// Displays the Easy Localization infrastructure that was wired up on Days
/// 101-102:  package added, 15 JSON files, main.dart delegates, RTL support.
/// All data is static — no backend needed.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../domain/providers/i18n_providers.dart';
import '../navigation/app_router.dart';

// ─── Setup checklist ──────────────────────────────────────────────────────────

class _SetupItem {
  const _SetupItem({required this.label, required this.sublabel});
  final String label;
  final String sublabel;
}

const _kSetupItems = <_SetupItem>[
  _SetupItem(
    label: 'easy_localization: ^3.0.7',
    sublabel: 'pubspec.yaml — resolved to 3.0.8',
  ),
  _SetupItem(
    label: 'flutter_localizations SDK',
    sublabel: 'pubspec.yaml — intl pinned to 0.18.1',
  ),
  _SetupItem(
    label: 'assets/translations/ directory',
    sublabel: '15 JSON locale files written',
  ),
  _SetupItem(
    label: 'EasyLocalization.ensureInitialized()',
    sublabel: 'main.dart — awaited before runApp',
  ),
  _SetupItem(
    label: 'EasyLocalization wrapper',
    sublabel: 'Wraps ProviderScope(child: ZapSafeApp())',
  ),
  _SetupItem(
    label: 'MaterialApp localization delegates',
    sublabel: 'context.localizationDelegates / supportedLocales / locale',
  ),
  _SetupItem(
    label: 'Fallback locale: English (en)',
    sublabel: 'fallbackLocale: const Locale(\'en\')',
  ),
  _SetupItem(
    label: 'RTL support: Arabic + Urdu',
    sublabel: 'Directionality.RTL demo on Day 102 screen',
  ),
];

// ─── Screen ───────────────────────────────────────────────────────────────────

class Day101I18nSetupScreen extends ConsumerWidget {
  const Day101I18nSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: ZapColors.bgPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: ZapColors.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('i18n Setup — Day 101'),
        titleTextStyle: ZapTypography.headlineSmall
            .copyWith(color: ZapColors.textPrimary),
        centerTitle: false,
      ),
      body: const CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.symmetric(
              horizontal: ZapSpacing.lg,
              vertical: ZapSpacing.md,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate.fixed([
                _HeroBanner(),
                SizedBox(height: ZapSpacing.xl),
                _StatsRow(),
                SizedBox(height: ZapSpacing.xxl),
                _SectionHeader(
                  icon: Icons.checklist_rounded,
                  label: 'SETUP CHECKLIST',
                ),
                SizedBox(height: ZapSpacing.md),
                _SetupChecklist(),
                SizedBox(height: ZapSpacing.xxl),
                _SectionHeader(
                  icon: Icons.translate_rounded,
                  label: '15 SUPPORTED LANGUAGES',
                ),
                SizedBox(height: ZapSpacing.md),
                _LangGrid(),
                SizedBox(height: ZapSpacing.xxl),
                _SectionHeader(
                  icon: Icons.info_outline_rounded,
                  label: 'IMPLEMENTATION NOTES',
                ),
                SizedBox(height: ZapSpacing.md),
                _NotesCard(),
                SizedBox(height: ZapSpacing.xxl),
                _NavToDemo(),
                SizedBox(height: ZapSpacing.xxxl),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Hero Banner ──────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  const _HeroBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.xxl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A5F), Color(0xFF0A1628)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2563EB), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(ZapSpacing.md),
                decoration: BoxDecoration(
                  color: const Color(0xFF1D4ED8).withAlpha(51),
                  borderRadius:
                      BorderRadius.circular(ZapSpacing.radiusSmall),
                ),
                child: const Icon(Icons.translate_rounded,
                    color: Color(0xFF60A5FA), size: 32),
              ),
              const SizedBox(width: ZapSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Day 101',
                      style: ZapTypography.labelSmall
                          .copyWith(color: const Color(0xFF60A5FA)),
                    ),
                    const SizedBox(height: ZapSpacing.xs),
                    Text(
                      'i18n Infrastructure',
                      style: ZapTypography.headlineSmall
                          .copyWith(color: ZapColors.textPrimary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.lg),
          Text(
            'Easy Localization fully wired. 15 languages — 9 Indian scripts, '
            '2 RTL, 4 European — cover 3.5B+ potential users. '
            'Zero backend dependency: all strings ship with the APK.',
            style: ZapTypography.bodyMedium
                .copyWith(color: ZapColors.textSecondary),
          ),
          const SizedBox(height: ZapSpacing.lg),
          const Wrap(
            spacing: ZapSpacing.sm,
            runSpacing: ZapSpacing.sm,
            children: [
              _Chip(label: '15 Locales', color: Color(0xFF3B82F6)),
              _Chip(label: '11 Namespaces', color: Color(0xFF10B981)),
              _Chip(label: '80+ Keys', color: Color(0xFFF59E0B)),
              _Chip(label: '2 RTL', color: Color(0xFF8B5CF6)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: ZapSpacing.md, vertical: ZapSpacing.xs),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Text(label,
          style: ZapTypography.labelSmall.copyWith(color: color)),
    );
  }
}

// ─── Stats Row ────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: _StatBox(value: '15', label: 'Languages')),
        SizedBox(width: ZapSpacing.sm),
        Expanded(child: _StatBox(value: '11', label: 'Namespaces')),
        SizedBox(width: ZapSpacing.sm),
        Expanded(child: _StatBox(value: '80+', label: 'Keys')),
        SizedBox(width: ZapSpacing.sm),
        Expanded(child: _StatBox(value: '2', label: 'RTL')),
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
      padding: const EdgeInsets.symmetric(
          vertical: ZapSpacing.md, horizontal: ZapSpacing.sm),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: ZapColors.border),
      ),
      child: Column(
        children: [
          Text(value,
              style: ZapTypography.headlineSmall
                  .copyWith(color: ZapColors.info)),
          const SizedBox(height: 2),
          Text(label,
              style: ZapTypography.labelSmall
                  .copyWith(color: ZapColors.textMuted),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: ZapColors.textMuted, size: 16),
            const SizedBox(width: ZapSpacing.sm),
            Text(label,
                style: ZapTypography.labelSmall
                    .copyWith(color: ZapColors.textMuted,
                        letterSpacing: 1.2)),
          ],
        ),
        const SizedBox(height: ZapSpacing.sm),
        const Divider(color: ZapColors.border, height: 1),
      ],
    );
  }
}

// ─── Setup Checklist ──────────────────────────────────────────────────────────

class _SetupChecklist extends StatelessWidget {
  const _SetupChecklist();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _kSetupItems
          .map((item) => _ChecklistItem(item: item))
          .toList(),
    );
  }
}

class _ChecklistItem extends StatelessWidget {
  const _ChecklistItem({required this.item});
  final _SetupItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: ZapColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: ZapColors.safe.withAlpha(26),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded,
                color: ZapColors.safe, size: 16),
          ),
          const SizedBox(width: ZapSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label,
                    style: ZapTypography.labelMedium
                        .copyWith(color: ZapColors.textPrimary)),
                const SizedBox(height: 2),
                Text(item.sublabel,
                    style: ZapTypography.bodySmall
                        .copyWith(color: ZapColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Language Grid ────────────────────────────────────────────────────────────

class _LangGrid extends StatelessWidget {
  const _LangGrid();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: ZapSpacing.sm,
      runSpacing: ZapSpacing.sm,
      children: kSupportedLanguages
          .map((lang) => _LangChip(lang: lang))
          .toList(),
    );
  }
}

class _LangChip extends StatelessWidget {
  const _LangChip({required this.lang});
  final LangInfo lang;

  @override
  Widget build(BuildContext context) {
    final accentColor =
        lang.rtl ? const Color(0xFF8B5CF6) : const Color(0xFF3B82F6);

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: ZapSpacing.md, vertical: ZapSpacing.sm),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(
            color: lang.rtl
                ? const Color(0xFF8B5CF6).withAlpha(77)
                : ZapColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(lang.flag, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: ZapSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(lang.nativeName,
                  style: ZapTypography.labelMedium
                      .copyWith(color: ZapColors.textPrimary)),
              Text(lang.code.toUpperCase(),
                  style: ZapTypography.labelSmall
                      .copyWith(color: accentColor)),
            ],
          ),
          if (lang.rtl) ...[
            const SizedBox(width: ZapSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withAlpha(26),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('RTL',
                  style: ZapTypography.labelSmall.copyWith(
                      color: const Color(0xFF8B5CF6), fontSize: 9)),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Notes Card ───────────────────────────────────────────────────────────────

class _NotesCard extends StatelessWidget {
  const _NotesCard();

  @override
  Widget build(BuildContext context) {
    const notes = [
      ('easy_localization uses .json files for translation storage. '
          'Keys use dot notation: "sos.trigger", "common.save", etc.'),
      ('EasyLocalization wraps ProviderScope — locale changes call '
          'context.setLocale() and hot-reload the entire widget tree.'),
      ('RTL (Arabic + Urdu) is handled automatically by Flutter\'s '
          'Directionality widget once the locale is set.'),
      ('Fallback locale is English. Any missing key falls back to en.json '
          'automatically — no crash risk on incomplete translations.'),
      ('Translation files ship inside the APK via assets/translations/. '
          'No network request needed to render any language.'),
    ];

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: ZapColors.border),
      ),
      child: Column(
        children: notes
            .map(
              (note) => Padding(
                padding: const EdgeInsets.only(bottom: ZapSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_rounded,
                        color: ZapColors.info, size: 16),
                    const SizedBox(width: ZapSpacing.sm),
                    Expanded(
                      child: Text(note,
                          style: ZapTypography.bodySmall
                              .copyWith(color: ZapColors.textSecondary)),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

// ─── Nav to Demo ──────────────────────────────────────────────────────────────

class _NavToDemo extends ConsumerWidget {
  const _NavToDemo();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => context.go(AppRoutes.translationDemo),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(ZapSpacing.lg),
        decoration: BoxDecoration(
          color: const Color(0xFF1D4ED8).withAlpha(26),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(
              color: const Color(0xFF2563EB).withAlpha(128)),
        ),
        child: Row(
          children: [
            const Icon(Icons.language_rounded,
                color: Color(0xFF60A5FA), size: 24),
            const SizedBox(width: ZapSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Day 102 — Translation Demo →',
                      style: ZapTypography.labelLarge
                          .copyWith(color: ZapColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text('Live locale switcher · RTL demo · key preview table',
                      style: ZapTypography.bodySmall
                          .copyWith(color: ZapColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
