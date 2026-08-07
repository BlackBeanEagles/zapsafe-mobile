/// Day 345 — i18n Missing Key Scanner
///
/// A genuinely working scanner, not a mock. On load it:
///   1. Lists every `assets/translations/*.json` file actually bundled with
///      the app via Flutter's AssetManifest (real directory listing, not a
///      hardcoded language list — so it finds drafts like ja.json too, not
///      just the 25 languages in kSupportedLanguages).
///   2. Loads + flattens en.json as the reference key set.
///   3. Loads + flattens every other locale file and diffs its keys against
///      en.json's, via `lib/core/utils/i18n_coverage.dart` (shared with
///      Day 341-343 and Day 350).
///   4. Shows a real missing-key count and percentage per language, sorted
///      worst-first.
///   5. Exports a real text report to the clipboard — actual scan output,
///      not canned text.
///
/// This is pure Dart/JSON diffing against real bundled assets — no device
/// needed, and every number on this screen comes from the live scan that
/// just ran, not a hardcoded table.
///
/// Tag: 🟢 REAL, working scanner.
/// Route: [AppRoutes.i18nMissingKeyScanner] → `/day-345-i18n-missing-key-scanner`
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/utils/i18n_coverage.dart';
import '../../domain/providers/i18n_providers.dart';

const _kAccent = Color(0xFFEC4899);

class _ScanResult {
  const _ScanResult({required this.enTotal, required this.coverages});
  final int enTotal;
  final List<LocaleCoverage> coverages; // sorted worst-first
}

final _scanProvider = FutureProvider<_ScanResult>((ref) async {
  final enFlat = await loadFlatLocale('en');
  final codes = await listTranslationLocaleCodes();
  final results = <LocaleCoverage>[];
  for (final code in codes) {
    results.add(await computeCoverage(code, enFlat));
  }
  results.sort((a, b) => b.missingCount.compareTo(a.missingCount));
  return _ScanResult(enTotal: enFlat.length, coverages: results);
});

String _buildReport(_ScanResult r) {
  final buf = StringBuffer();
  buf.writeln('ZapSafe i18n missing-key scan');
  buf.writeln('en.json reference keys: ${r.enTotal}');
  buf.writeln('Locales scanned: ${r.coverages.length}');
  buf.writeln('');
  for (final c in r.coverages) {
    final pct = c.pct.toStringAsFixed(1);
    buf.writeln(
        '${c.code}: $pct% (${c.presentCount}/${c.totalEnKeys}) — ${c.missingCount} missing');
    if (c.missingKeys.isNotEmpty) {
      buf.writeln('  missing: ${c.missingKeys.join(', ')}');
    }
  }
  return buf.toString();
}

class Day345I18nMissingKeyScannerScreen extends ConsumerWidget {
  const Day345I18nMissingKeyScannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scanAsync = ref.watch(_scanProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: Text('day341_350.missing_key_scanner_title'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Re-scan',
            onPressed: () => ref.invalidate(_scanProvider),
          ),
        ],
      ),
      body: scanAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Scan failed: $e',
              style: const TextStyle(color: ZapColors.danger)),
        ),
        data: (result) => _Body(result: result),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.result});

  final _ScanResult result;

  @override
  Widget build(BuildContext context) {
    final fullyCovered = result.coverages.where((c) => c.missingCount == 0).length;
    final supportedCodes = kSupportedLanguages.map((l) => l.code).toSet();
    final unsupportedButPresent = result.coverages
        .where((c) => !supportedCodes.contains(c.code))
        .toList();

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
            '🟢 Section J Day 5/10 · live AssetManifest scan, real numbers',
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
          child: Row(
            children: [
              Expanded(
                child: _StatBlock(
                  value: '${result.enTotal}',
                  label: 'en.json keys',
                ),
              ),
              Expanded(
                child: _StatBlock(
                  value: '${result.coverages.length}',
                  label: 'locale files scanned',
                ),
              ),
              Expanded(
                child: _StatBlock(
                  value: '$fullyCovered',
                  label: 'fully covered',
                  color: fullyCovered == result.coverages.length
                      ? ZapColors.safe
                      : null,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Per-locale coverage (worst first)',
              style: TextStyle(
                color: ZapColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            TextButton.icon(
              onPressed: () {
                final report = _buildReport(result);
                Clipboard.setData(ClipboardData(text: report));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Full scan report copied to clipboard')),
                );
              },
              icon: const Icon(Icons.copy_rounded, size: 14),
              label: const Text('Export report', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.sm),
        for (final c in result.coverages)
          _LocaleRow(
            cov: c,
            isSupported: supportedCodes.contains(c.code),
          ),
        if (unsupportedButPresent.isNotEmpty) ...[
          const SizedBox(height: ZapSpacing.lg),
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.info.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ZapColors.info.withOpacity(0.3)),
            ),
            child: Text(
              'Note: ${unsupportedButPresent.map((c) => c.code).join(', ')} '
              '${unsupportedButPresent.length == 1 ? 'has' : 'have'} a JSON '
              'file in assets/translations/ but ${unsupportedButPresent.length == 1 ? 'is' : 'are'} not '
              'in kSupportedLanguages yet, so the app\'s real language '
              'selector does not offer ${unsupportedButPresent.length == 1 ? 'it' : 'them'} — '
              'this scanner still finds and reports on it because it reads '
              'the actual asset bundle, not the supported-languages list.',
              style: const TextStyle(
                  color: ZapColors.info, fontSize: 11, height: 1.4),
            ),
          ),
        ],
      ],
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({required this.value, required this.label, this.color});

  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color ?? _kAccent,
            fontSize: 26,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: ZapColors.textSecondary, fontSize: 10),
        ),
      ],
    );
  }
}

class _LocaleRow extends StatelessWidget {
  const _LocaleRow({required this.cov, required this.isSupported});

  final LocaleCoverage cov;
  final bool isSupported;

  @override
  Widget build(BuildContext context) {
    final complete = cov.missingCount == 0;
    final color = complete
        ? ZapColors.safe
        : cov.pct >= 50
            ? ZapColors.warning
            : ZapColors.danger;

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
          SizedBox(
            width: 36,
            child: Text(
              cov.code,
              style: const TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12),
            ),
          ),
          if (!isSupported)
            Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: ZapColors.textMuted.withOpacity(0.15),
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Text('unlisted',
                  style: TextStyle(color: ZapColors.textMuted, fontSize: 7)),
            ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: cov.pct / 100,
                minHeight: 8,
                backgroundColor: ZapColors.border,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 96,
            child: Text(
              '${cov.pct.toStringAsFixed(0)}% (${cov.missingCount} missing)',
              textAlign: TextAlign.right,
              style: TextStyle(
                  color: color, fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
