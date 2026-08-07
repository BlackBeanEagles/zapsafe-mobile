/// Day 348 — Voice Trigger Keywords: 25 Languages
///
/// Maps a hidden voice-SOS distress phrase per locale, stored in
/// `assets/data/voice_keywords.json` and loaded for real at runtime (not
/// hardcoded into this screen — the JSON file is the source of truth).
///
/// A grep across lib/ for voice + keyword + trigger + hotword + wake-word
/// found NO existing phrase-based voice-trigger precedent in this repo —
/// audio detection here (heuristic_scream_detector.dart etc.) is ML-based
/// scream/glass-break/distress-sound classification, not phrase recognition.
/// So this is a fresh draft, not an extension of prior work, and is labeled
/// as such.
///
/// This is safety-critical-adjacent: a wrong or ambiguous keyword means a
/// voice trigger either never fires (the user is in danger and nothing
/// happens) or fires constantly on ordinary speech (battery drain, false
/// alarms, and eventually the feature gets disabled/ignored). Every entry
/// in the JSON is `"verified": false` — these are genuinely common,
/// dictionary-level distress words chosen in good faith, but NONE of them
/// have been field-tested or confirmed by a native speaker for this
/// specific use case. This screen does not claim otherwise.
///
/// Tag: 🟢 REAL data file, loaded live, verification honestly pending.
/// Route: [AppRoutes.voiceKeywords25Lang] → `/day-348-voice-keywords-25lang`
library;

import 'dart:convert';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../widgets/zap_error_state.dart';
import '../widgets/zap_skeleton.dart';

const _kAccent = Color(0xFFEF4444);
const _kAssetPath = 'assets/data/voice_keywords.json';

class _KeywordEntry {
  const _KeywordEntry({
    required this.code,
    required this.name,
    required this.keywords,
    required this.transliteration,
    required this.rtl,
    required this.verified,
  });

  final String code;
  final String name;
  final List<String> keywords;
  final List<String> transliteration;
  final bool rtl;
  final bool verified;

  factory _KeywordEntry.fromJson(Map<String, dynamic> j) => _KeywordEntry(
        code: j['code'] as String,
        name: j['name'] as String,
        keywords: (j['keywords'] as List).cast<String>(),
        transliteration:
            ((j['transliteration'] as List?) ?? const []).cast<String>(),
        rtl: j['rtl'] as bool? ?? false,
        verified: j['verified'] as bool? ?? false,
      );
}

class _KeywordData {
  const _KeywordData({
    required this.version,
    required this.updatedAt,
    required this.note,
    required this.languages,
  });

  final String version;
  final String updatedAt;
  final String note;
  final List<_KeywordEntry> languages;
}

final _keywordDataProvider = FutureProvider<_KeywordData>((ref) async {
  final raw = await rootBundle.loadString(_kAssetPath);
  final json = jsonDecode(raw) as Map<String, dynamic>;
  return _KeywordData(
    version: json['version'] as String? ?? '?',
    updatedAt: json['updated_at'] as String? ?? '?',
    note: json['note'] as String? ?? '',
    languages: (json['languages'] as List)
        .map((e) => _KeywordEntry.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
});

class Day348VoiceKeywords25LangScreen extends ConsumerWidget {
  const Day348VoiceKeywords25LangScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(_keywordDataProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: Text('day341_350.voice_keywords_title'.tr()),
      ),
      body: dataAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(ZapSpacing.lg),
          child: ZapSkeletonList(count: 4),
        ),
        error: (e, _) => ZapErrorState.fromError(
          error: e,
          onRetry: () => ref.invalidate(_keywordDataProvider),
        ),
        data: (data) => _Body(data: data),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.data});

  final _KeywordData data;

  @override
  Widget build(BuildContext context) {
    final verifiedCount = data.languages.where((l) => l.verified).length;

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
          child: Text(
            '🟢 Section J Day 8/10 · loaded live from $_kAssetPath v${data.version}',
            style: const TextStyle(color: _kAccent, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.lg),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kAccent.withOpacity(0.35)),
          ),
          child: Column(
            children: [
              Text(
                '$verifiedCount / ${data.languages.length}',
                style: const TextStyle(
                    color: _kAccent, fontSize: 32, fontWeight: FontWeight.w900),
              ),
              const Text(
                'Native-speaker field-verified',
                style: TextStyle(color: ZapColors.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.danger.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.danger.withOpacity(0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 16, color: ZapColors.danger),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  data.note,
                  style: const TextStyle(
                      color: ZapColors.danger, fontSize: 11, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Keyword map (25 languages)',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        for (final entry in data.languages) _KeywordCard(entry: entry),
      ],
    );
  }
}

class _KeywordCard extends StatelessWidget {
  const _KeywordCard({required this.entry});

  final _KeywordEntry entry;

  @override
  Widget build(BuildContext context) {
    final color = entry.verified ? ZapColors.safe : ZapColors.textMuted;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(ZapSpacing.sm),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              entry.code,
              style: const TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(entry.name,
                        style: const TextStyle(
                            color: ZapColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12)),
                    if (entry.rtl) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: ZapColors.info.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text('RTL',
                            style: TextStyle(
                                color: ZapColors.info,
                                fontSize: 7,
                                fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  entry.keywords.join('  ·  '),
                  textDirection:
                      entry.rtl ? TextDirection.rtl : TextDirection.ltr,
                  style: const TextStyle(
                      color: ZapColors.textPrimary, fontSize: 14),
                ),
                if (entry.transliteration.isNotEmpty)
                  Text(
                    entry.transliteration.join('  ·  '),
                    style: const TextStyle(
                        color: ZapColors.textMuted,
                        fontSize: 10,
                        fontStyle: FontStyle.italic),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withOpacity(0.4)),
            ),
            child: Text(
              entry.verified ? 'Verified' : 'Unverified',
              style: TextStyle(
                  color: color, fontSize: 8, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
