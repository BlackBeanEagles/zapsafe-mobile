/// Day 102 — Translation Demo Screen.
///
/// Live locale selector + translation preview table + RTL demo section.
/// Uses [i18nProvider] for selected locale state.
/// All translations come from [kDemoTranslations] mock data — zero backend.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../domain/providers/i18n_providers.dart';

// ─── Translation table rows ───────────────────────────────────────────────────

const _kTableKeys = [
  ('tagline',     'App Tagline'),
  ('sos.trigger', 'SOS Trigger'),
  ('sos.active',  'SOS Active'),
  ('home.status', 'Home Status'),
  ('common.save', 'Save'),
  ('common.done', 'Done'),
  ('settings',    'Settings'),
  ('premium',     'Premium'),
];

// ─── Screen ───────────────────────────────────────────────────────────────────

class Day102TranslationDemoScreen extends ConsumerWidget {
  const Day102TranslationDemoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(i18nProvider);

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
        title: const Text('Translation Demo — Day 102'),
        titleTextStyle: ZapTypography.headlineSmall
            .copyWith(color: ZapColors.textPrimary),
        centerTitle: false,
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: ZapSpacing.lg,
              vertical: ZapSpacing.md,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate.fixed([
                _HeroBanner(state: state),
                const SizedBox(height: ZapSpacing.xl),
                _LocaleSelector(state: state),
                const SizedBox(height: ZapSpacing.xxl),
                const _SectionHeader(
                  icon: Icons.table_rows_rounded,
                  label: 'TRANSLATION PREVIEW',
                ),
                const SizedBox(height: ZapSpacing.md),
                _TranslationTable(state: state),
                const SizedBox(height: ZapSpacing.xxl),
                if (state.isRtl) ...[
                  const _SectionHeader(
                    icon: Icons.format_textdirection_r_to_l_rounded,
                    label: 'RTL LAYOUT DEMO',
                  ),
                  const SizedBox(height: ZapSpacing.md),
                  _RtlDemo(state: state),
                  const SizedBox(height: ZapSpacing.xxl),
                ],
                const _SectionHeader(
                  icon: Icons.sos_rounded,
                  label: 'LIVE SOS BUTTON PREVIEW',
                ),
                const SizedBox(height: ZapSpacing.md),
                _SosPreview(state: state),
                const SizedBox(height: ZapSpacing.xxl),
                const _CoverageCard(),
                const SizedBox(height: ZapSpacing.xxxl),
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
  const _HeroBanner({required this.state});
  final I18nState state;

  @override
  Widget build(BuildContext context) {
    final lang = state.lang;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.xxl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF064E3B), Color(0xFF022C22)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF059669), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: const Color(0xFF065F46).withAlpha(128),
              borderRadius:
                  BorderRadius.circular(ZapSpacing.radiusSmall),
            ),
            child: Text(lang.flag,
                style: const TextStyle(fontSize: 32)),
          ),
          const SizedBox(width: ZapSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Day 102 — Live Demo',
                  style: ZapTypography.labelSmall
                      .copyWith(color: const Color(0xFF34D399)),
                ),
                const SizedBox(height: ZapSpacing.xs),
                Text(
                  '${lang.flag} ${lang.nativeName}',
                  style: ZapTypography.headlineSmall
                      .copyWith(color: ZapColors.textPrimary),
                ),
                const SizedBox(height: ZapSpacing.xs),
                Text(
                  '${lang.name} · ${lang.code.toUpperCase()}'
                  '${lang.rtl ? ' · RTL' : ''}',
                  style: ZapTypography.bodySmall
                      .copyWith(color: ZapColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Locale Selector ─────────────────────────────────────────────────────────

class _LocaleSelector extends ConsumerWidget {
  const _LocaleSelector({required this.state});
  final I18nState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.language_rounded,
                color: ZapColors.textMuted, size: 16),
            const SizedBox(width: ZapSpacing.sm),
            Text('SELECT LOCALE',
                style: ZapTypography.labelSmall
                    .copyWith(color: ZapColors.textMuted, letterSpacing: 1.2)),
          ],
        ),
        const SizedBox(height: ZapSpacing.sm),
        const Divider(color: ZapColors.border, height: 1),
        const SizedBox(height: ZapSpacing.md),
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: kSupportedLanguages.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: ZapSpacing.sm),
            itemBuilder: (context, i) {
              final lang = kSupportedLanguages[i];
              final selected = lang.code == state.selectedCode;
              return GestureDetector(
                onTap: () =>
                    ref.read(i18nProvider.notifier).select(lang.code),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: ZapSpacing.md, vertical: ZapSpacing.sm),
                  decoration: BoxDecoration(
                    color: selected
                        ? ZapColors.info.withAlpha(26)
                        : ZapColors.bgCard,
                    borderRadius:
                        BorderRadius.circular(ZapSpacing.radiusSmall),
                    border: Border.all(
                      color: selected ? ZapColors.info : ZapColors.border,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(lang.flag,
                          style: const TextStyle(fontSize: 20)),
                      const SizedBox(height: 2),
                      Text(lang.code.toUpperCase(),
                          style: ZapTypography.labelSmall.copyWith(
                            color: selected
                                ? ZapColors.info
                                : ZapColors.textMuted,
                            fontWeight: selected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          )),
                    ],
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
                    .copyWith(color: ZapColors.textMuted, letterSpacing: 1.2)),
          ],
        ),
        const SizedBox(height: ZapSpacing.sm),
        const Divider(color: ZapColors.border, height: 1),
      ],
    );
  }
}

// ─── Translation Table ────────────────────────────────────────────────────────

class _TranslationTable extends StatelessWidget {
  const _TranslationTable({required this.state});
  final I18nState state;

  @override
  Widget build(BuildContext context) {
    final demo = state.demoStrings;
    return Container(
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: ZapColors.border),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: ZapSpacing.md, vertical: ZapSpacing.sm),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(ZapSpacing.radiusSmall),
                topRight: Radius.circular(ZapSpacing.radiusSmall),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text('KEY',
                      style: ZapTypography.labelSmall
                          .copyWith(color: ZapColors.textMuted,
                              letterSpacing: 0.8)),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    state.lang.nativeName.toUpperCase(),
                    style: ZapTypography.labelSmall
                        .copyWith(color: ZapColors.info, letterSpacing: 0.8),
                    textAlign: state.isRtl ? TextAlign.right : TextAlign.left,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: ZapColors.border, height: 1),
          // Rows
          ...List.generate(_kTableKeys.length, (i) {
            final (key, label) = _kTableKeys[i];
            final value = demo[key] ?? '—';
            final isLast = i == _kTableKeys.length - 1;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: ZapSpacing.md, vertical: ZapSpacing.sm),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label,
                                style: ZapTypography.labelMedium
                                    .copyWith(color: ZapColors.textPrimary)),
                            Text(key,
                                style: ZapTypography.labelSmall
                                    .copyWith(
                                        color: ZapColors.textMuted,
                                        fontFamily: 'IBMPlexMono',
                                        fontSize: 10)),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Directionality(
                          textDirection: state.isRtl
                              ? TextDirection.rtl
                              : TextDirection.ltr,
                          child: Text(
                            value,
                            style: ZapTypography.bodyMedium
                                .copyWith(color: ZapColors.textSecondary),
                            textAlign: state.isRtl
                                ? TextAlign.right
                                : TextAlign.left,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast) const Divider(color: ZapColors.border, height: 1),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ─── RTL Demo ────────────────────────────────────────────────────────────────

class _RtlDemo extends StatelessWidget {
  const _RtlDemo({required this.state});
  final I18nState state;

  @override
  Widget build(BuildContext context) {
    final demo = state.demoStrings;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(ZapSpacing.lg),
        decoration: BoxDecoration(
          color: const Color(0xFF4C1D95).withAlpha(26),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(
              color: const Color(0xFF8B5CF6).withAlpha(77)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.format_textdirection_r_to_l_rounded,
                    color: Color(0xFFA78BFA), size: 18),
                const SizedBox(width: ZapSpacing.sm),
                Text('RTL Layout Active',
                    style: ZapTypography.labelMedium
                        .copyWith(color: const Color(0xFFA78BFA))),
              ],
            ),
            const SizedBox(height: ZapSpacing.md),
            Text(
              demo['tagline'] ?? '',
              style: ZapTypography.headlineSmall
                  .copyWith(color: ZapColors.textPrimary),
            ),
            const SizedBox(height: ZapSpacing.sm),
            Text(
              '${state.lang.flag}  ${demo['sos.trigger'] ?? ''}  ←  ${demo['home.status'] ?? ''}',
              style: ZapTypography.bodyMedium
                  .copyWith(color: ZapColors.textSecondary),
            ),
            const SizedBox(height: ZapSpacing.md),
            Container(
              padding: const EdgeInsets.all(ZapSpacing.md),
              decoration: BoxDecoration(
                color: ZapColors.bgCard,
                borderRadius:
                    BorderRadius.circular(ZapSpacing.radiusSmall),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(demo['settings'] ?? '',
                      style: ZapTypography.labelMedium
                          .copyWith(color: ZapColors.textPrimary)),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      color: ZapColors.textMuted, size: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── SOS Preview ─────────────────────────────────────────────────────────────

class _SosPreview extends StatelessWidget {
  const _SosPreview({required this.state});
  final I18nState state;

  @override
  Widget build(BuildContext context) {
    final demo = state.demoStrings;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.xl),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: ZapColors.border),
      ),
      child: Column(
        children: [
          Text('In-app SOS button — ${state.lang.name}',
              style: ZapTypography.labelSmall
                  .copyWith(color: ZapColors.textMuted)),
          const SizedBox(height: ZapSpacing.lg),
          // Mock SOS button
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ZapColors.danger.withAlpha(26),
              border: Border.all(color: ZapColors.danger, width: 3),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sos_rounded,
                      color: ZapColors.danger, size: 28),
                  const SizedBox(height: ZapSpacing.xs),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Directionality(
                      textDirection: state.isRtl
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      child: Text(
                        demo['sos.trigger'] ?? 'TRIGGER SOS',
                        style: ZapTypography.labelSmall.copyWith(
                            color: ZapColors.danger,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: ZapSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(state.lang.flag,
                  style: const TextStyle(fontSize: 16)),
              const SizedBox(width: ZapSpacing.sm),
              Directionality(
                textDirection:
                    state.isRtl ? TextDirection.rtl : TextDirection.ltr,
                child: Text(
                  demo['home.status'] ?? 'You are safe',
                  style: ZapTypography.bodyMedium
                      .copyWith(color: ZapColors.safe),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Coverage Card ────────────────────────────────────────────────────────────

class _CoverageCard extends StatelessWidget {
  const _CoverageCard();

  @override
  Widget build(BuildContext context) {
    const regions = [
      ('🇮🇳', 'Indian Languages', '9 scripts', '1.4B+ users'),
      ('🌍', 'RTL Languages', 'Urdu + Arabic', '450M+ users'),
      ('🌎', 'European', 'ES / FR / PT / DE', '750M+ users'),
    ];

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: ZapColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Language Coverage',
              style: ZapTypography.labelLarge
                  .copyWith(color: ZapColors.textPrimary)),
          const SizedBox(height: ZapSpacing.md),
          ...regions.map((r) {
            final (flag, region, scripts, users) = r;
            return Padding(
              padding: const EdgeInsets.only(bottom: ZapSpacing.md),
              child: Row(
                children: [
                  Text(flag, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: ZapSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(region,
                            style: ZapTypography.labelMedium
                                .copyWith(color: ZapColors.textPrimary)),
                        Text('$scripts · $users',
                            style: ZapTypography.bodySmall
                                .copyWith(color: ZapColors.textMuted)),
                      ],
                    ),
                  ),
                  const Icon(Icons.check_circle_rounded,
                      color: ZapColors.safe, size: 18),
                ],
              ),
            );
          }),
          const Divider(color: ZapColors.border),
          const SizedBox(height: ZapSpacing.sm),
          Row(
            children: [
              const Icon(Icons.lock_rounded,
                  color: ZapColors.safe, size: 16),
              const SizedBox(width: ZapSpacing.sm),
              Text(
                'All strings ship in the APK — no network required',
                style: ZapTypography.bodySmall
                    .copyWith(color: ZapColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
