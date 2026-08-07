/// Day 343 — Section J: Languages 22-25 Full JSON (FINAL batch)
///
/// Completes full-coverage translation files for Dutch (nl), Italian (it),
/// Korean (ko), and Persian (fa). ko.json and fa.json already had 20-key
/// starter packs (Day 264 / Day 263 respectively); those existing
/// translations were reused as-is and the remaining keys were completed
/// around them. nl.json and it.json were created fresh.
///
/// fa (Persian) is RTL — extends the Day 263 `day263_persian_rtl_screen.dart`
/// work. This day only completes fa.json's key coverage; RTL layout
/// regression testing across ar/ur/fa is Day 344's job, not this one.
///
/// After this commit, kSupportedLanguages and main.dart's EasyLocalization
/// `supportedLocales` both reach 25 entries — the full 25-language target
/// for Section J.
///
/// Tag: 🟢 REAL · translations are genuine, coverage is a live runtime scan.
/// Route: [AppRoutes.languages22to25] → `/day-343-languages-22-25`
library;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/utils/i18n_coverage.dart';
import '../../domain/providers/i18n_providers.dart';
import '../widgets/zap_error_state.dart';
import '../widgets/zap_skeleton.dart';

const _kAccent = Color(0xFF10B981);

const _kBatch = [
  (code: 'nl', name: 'Dutch', native: 'Nederlands', flag: '🇳🇱', startedWith: 'new file'),
  (code: 'it', name: 'Italian', native: 'Italiano', flag: '🇮🇹', startedWith: 'new file'),
  (code: 'ko', name: 'Korean', native: '한국어', flag: '🇰🇷', startedWith: '20 keys from Day 264'),
  (code: 'fa', name: 'Persian', native: 'فارسی', flag: '🇮🇷', startedWith: '20 keys from Day 263 (RTL)'),
];

final _en343FlatProvider = FutureProvider<Map<String, String>>((ref) async {
  return loadFlatLocale('en');
});

final _batch343CoverageProvider = FutureProvider<List<LocaleCoverage>>((ref) async {
  final en = await ref.watch(_en343FlatProvider.future);
  final results = <LocaleCoverage>[];
  for (final lang in _kBatch) {
    results.add(await computeCoverage(lang.code, en));
  }
  return results;
});

class Day343Languages22to25Screen extends ConsumerWidget {
  const Day343Languages22to25Screen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coverageAsync = ref.watch(_batch343CoverageProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: Text('day341_350.languages22_25_title'.tr()),
      ),
      body: coverageAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(ZapSpacing.lg),
          child: ZapSkeletonList(count: 4),
        ),
        error: (e, _) => ZapErrorState.fromError(
          error: e,
          onRetry: () => ref.invalidate(_batch343CoverageProvider),
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
    final targetReached = totalSupported >= 25;

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
            '🟢 Section J Day 3/10 · languages 22-25 of 25 · FINAL batch',
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
                style: TextStyle(
                  color: targetReached ? ZapColors.safe : _kAccent,
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                targetReached
                    ? 'Target reached — the real selector now offers all 25 '
                        'languages (kSupportedLanguages + EasyLocalization '
                        'supportedLocales)'
                    : 'Languages in the real selector',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: ZapColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: ZapSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: totalSupported / 25,
                  minHeight: 10,
                  backgroundColor: ZapColors.border,
                  color: targetReached ? ZapColors.safe : _kAccent,
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
          _CoverageCard(
            cov: coverage[i],
            meta: _kBatch[i],
            rtl: _kBatch[i].code == 'fa',
          ),
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
                ? 'All 4 batch languages have full key coverage vs en.json '
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
          text: 'ko.json (20-key Day 264 pack) and fa.json (20-key Day 263 '
              'RTL pack) both had their existing translations kept unchanged '
              '— only the remaining keys were newly translated.',
        ),
        const _NoteRow(
          text: 'nl.json and it.json were created fresh — no prior file '
              'existed for either.',
        ),
        const _NoteRow(
          text: 'fa is flagged RTL in kSupportedLanguages, same as ur/ar. '
              'This day only completes fa.json\'s key coverage — actual RTL '
              'layout regression testing (mirrored icons, text direction, '
              '200% font scale) across ar/ur/fa is Day 344\'s job.',
        ),
        const _NoteRow(
          text: 'Next: Day 344 runs a real RTL static-check + manual QA '
              'checklist across ar/ur/fa on 5 critical screens.',
        ),
      ],
    );
  }
}

class _CoverageCard extends StatelessWidget {
  const _CoverageCard({required this.cov, required this.meta, required this.rtl});

  final LocaleCoverage cov;
  final ({String code, String name, String native, String flag, String startedWith}) meta;
  final bool rtl;

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
                    Row(
                      children: [
                        Text(
                          '${meta.name} · ${meta.code}',
                          style: const TextStyle(
                            color: ZapColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        if (rtl) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: ZapColors.info.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'RTL',
                              style: TextStyle(
                                  color: ZapColors.info,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      meta.native,
                      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
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
