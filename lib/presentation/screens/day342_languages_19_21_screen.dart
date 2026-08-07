/// Day 342 — Section J: Languages 19-21 Full JSON
///
/// Completes full-coverage translation files for Vietnamese (vi), Turkish
/// (tr), and Polish (pl). vi.json already had a 20-key starter pack from
/// Day 264; those existing translations were reused as-is and the remaining
/// keys were completed around them. tr.json and pl.json were created fresh.
///
/// Coverage is computed for REAL at runtime (see day341's screen for the
/// shared `lib/core/utils/i18n_coverage.dart` helper) — nothing here is a
/// hardcoded/mock number.
///
/// kSupportedLanguages and main.dart's EasyLocalization `supportedLocales`
/// were both extended with vi/tr/pl, taking the real language selector from
/// 18 to 21 languages.
///
/// Tag: 🟢 REAL · translations are genuine, coverage is a live runtime scan.
/// Route: [AppRoutes.languages19to21] → `/day-342-languages-19-21`
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/utils/i18n_coverage.dart';
import '../../domain/providers/i18n_providers.dart';

const _kAccent = Color(0xFF7C3AED);

const _kBatch = [
  (code: 'vi', name: 'Vietnamese', native: 'Tiếng Việt', flag: '🇻🇳', startedWith: '20 keys from Day 264'),
  (code: 'tr', name: 'Turkish', native: 'Türkçe', flag: '🇹🇷', startedWith: 'new file'),
  (code: 'pl', name: 'Polish', native: 'Polski', flag: '🇵🇱', startedWith: 'new file'),
];

final _en342FlatProvider = FutureProvider<Map<String, String>>((ref) async {
  return loadFlatLocale('en');
});

final _batch342CoverageProvider = FutureProvider<List<LocaleCoverage>>((ref) async {
  final en = await ref.watch(_en342FlatProvider.future);
  final results = <LocaleCoverage>[];
  for (final lang in _kBatch) {
    results.add(await computeCoverage(lang.code, en));
  }
  return results;
});

class Day342Languages19to21Screen extends ConsumerWidget {
  const Day342Languages19to21Screen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coverageAsync = ref.watch(_batch342CoverageProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: Text('day341_350.languages19_21_title'.tr()),
      ),
      body: coverageAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Failed to scan translations: $e',
              style: const TextStyle(color: ZapColors.danger)),
        ),
        data: (coverage) => _Body(coverage: coverage),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.coverage});

  final List<LocaleCoverage> coverage;

  @override
  Widget build(BuildContext context) {
    final allComplete = coverage.every((c) => c.missingCount == 0);
    final totalSupported = kSupportedLanguages.length;

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
            '🟢 Section J Day 2/10 · languages 19-21 of 25',
            style: TextStyle(color: _kAccent, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.lg),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_kAccent.withOpacity(0.18), ZapColors.bgCard],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kAccent.withOpacity(0.35)),
          ),
          child: Column(
            children: [
              Text(
                '$totalSupported / 25',
                style: const TextStyle(
                  color: _kAccent,
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Text(
                'Languages in the real selector '
                '(kSupportedLanguages + EasyLocalization supportedLocales)',
                textAlign: TextAlign.center,
                style: TextStyle(color: ZapColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: ZapSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: totalSupported / 25,
                  minHeight: 10,
                  backgroundColor: ZapColors.border,
                  color: _kAccent,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Batch coverage (live scan of assets/translations/*.json)',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        for (var i = 0; i < coverage.length; i++)
          _CoverageCard(cov: coverage[i], meta: _kBatch[i]),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: (allComplete ? ZapColors.safe : ZapColors.warning)
                .withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: (allComplete ? ZapColors.safe : ZapColors.warning)
                  .withOpacity(0.35),
            ),
          ),
          child: Text(
            allComplete
                ? 'All 3 batch languages have full key coverage vs en.json '
                    '(${coverage.first.totalEnKeys} keys each).'
                : 'Batch is NOT fully covered — see missing-key counts above.',
            style: TextStyle(
              color: allComplete ? ZapColors.safe : ZapColors.warning,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Notes',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        const _NoteRow(
          text: 'vi.json already had a 20-key starter pack (Day 264). '
              'Those existing values were kept unchanged — only the '
              'remaining keys were newly translated.',
        ),
        const _NoteRow(
          text: 'tr.json and pl.json were created fresh — no prior file '
              'existed for either.',
        ),
        const _NoteRow(
          text: 'Next: Day 343 completes nl/it/ko/fa (languages 22-25) — '
              'the final batch.',
        ),
      ],
    );
  }
}

class _CoverageCard extends StatelessWidget {
  const _CoverageCard({required this.cov, required this.meta});

  final LocaleCoverage cov;
  final ({String code, String name, String native, String flag, String startedWith}) meta;

  @override
  Widget build(BuildContext context) {
    final complete = cov.missingCount == 0;
    final color = complete ? ZapColors.safe : ZapColors.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(ZapSpacing.sm),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(meta.flag, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${meta.name} · ${meta.code}',
                      style: const TextStyle(
                        color: ZapColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      meta.native,
                      style: const TextStyle(
                          color: ZapColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Text(
                '${cov.presentCount}/${cov.totalEnKeys} keys',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: cov.totalEnKeys == 0 ? 0 : cov.presentCount / cov.totalEnKeys,
              minHeight: 6,
              backgroundColor: ZapColors.border,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Started with: ${meta.startedWith} · missing now: '
            '${cov.missingCount}',
            style: const TextStyle(color: ZapColors.textMuted, fontSize: 9),
          ),
          if (cov.missingKeys.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: cov.missingKeys
                  .take(8)
                  .map((k) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: ZapColors.danger.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          k,
                          style: const TextStyle(
                              color: ZapColors.danger, fontSize: 8),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _NoteRow extends StatelessWidget {
  const _NoteRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.circle, size: 6, color: ZapColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  color: ZapColors.textSecondary, fontSize: 11, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
