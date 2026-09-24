import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/data/services/trac_aggression_detector.dart';

/// Day 391 — pins the Dart tokenizer against the Python that trained the
/// model.
///
/// `flutter test` cannot execute a `.tflite`, so the scores in the fixture
/// are not asserted here. What IS asserted is everything that leads up to
/// the model: lowercase, the two-branch token regex, vocab lookup, OOV vs
/// pad, and truncation. If those match, the only remaining way to get a
/// wrong answer is the interpreter itself.
///
/// The tokenizer is where the real bug lives. A plain `[a-z0-9']+` deletes
/// every Devanagari character silently — the vector is still the right
/// shape, the model still returns a confident 0.33, and nothing throws.
/// That is this project's recurring failure mode, and
/// `hindi_devanagari` below is the case that catches it.
void main() {
  late Map<String, dynamic> golden;
  late Map<String, dynamic> cases;

  setUpAll(() {
    golden = jsonDecode(
      File('test/fixtures/trac_aggression_golden.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    cases = golden['cases'] as Map<String, dynamic>;
  });

  Map<String, dynamic> caseOf(String n) => cases[n] as Map<String, dynamic>;

  group('fixture agrees with the shipped constants', () {
    test('maxlen, pad and oov indices match the trained model', () {
      expect(golden['_maxlen'], TracAggressionDetector.kMaxLen);
      expect(golden['_pad_index'], TracAggressionDetector.kPadIndex);
      expect(golden['_oov_index'], TracAggressionDetector.kOovIndex);
    });

    test('pad and OOV are different indices', () {
      // Conflating them makes an all-unknown sentence indistinguishable
      // from an empty one while meaning the opposite.
      expect(TracAggressionDetector.kPadIndex,
          isNot(TracAggressionDetector.kOovIndex));
    });
  });

  group('tokenizer matches the training tokenizer exactly', () {
    for (final name in const [
      'english_aggressive',
      'english_calm',
      'hindi_devanagari',
      'hindi_romanised',
      'mixed_script',
      'apostrophe',
      'oov_only',
      'empty',
      'over_maxlen',
      'emoji',
      'uppercase',
    ]) {
      test('case "$name"', () {
        final c = caseOf(name);
        final expected = (c['tokens'] as List).cast<String>();
        final actual = TracAggressionDetector.tokenize(c['text'] as String);
        // the fixture stores tokens already truncated to maxlen
        final trimmed = actual.length > TracAggressionDetector.kMaxLen
            ? actual.sublist(0, TracAggressionDetector.kMaxLen)
            : actual;
        expect(trimmed, expected,
            reason: 'tokenizer disagrees with the trained model on "$name"');
      });
    }
  });

  group('the Devanagari branch is load-bearing', () {
    test('Hindi text produces Hindi tokens, not nothing', () {
      final toks = TracAggressionDetector.tokenize(
          caseOf('hindi_devanagari')['text'] as String);
      expect(toks, isNotEmpty,
          reason: 'a [a-z0-9\']+ -only regex would return [] here and the '
              'model would still score it confidently');
      expect(toks.length, 8);
      expect(toks.first, 'तुम');
    });

    test('a latin-only regex would have destroyed this input', () {
      // the exact bug, reproduced, so the test states what it is guarding
      final naive = RegExp(r"[a-z0-9']+")
          .allMatches((caseOf('hindi_devanagari')['text'] as String)
              .toLowerCase())
          .map((m) => m[0]!)
          .toList();
      expect(naive, isEmpty);
    });

    test('mixed script splits at the ascii boundary', () {
      final toks = TracAggressionDetector.tokenize(
          caseOf('mixed_script')['text'] as String);
      expect(toks, caseOf('mixed_script')['tokens']);
      expect(toks.contains('you'), isTrue);
      expect(toks.any((t) => t.codeUnitAt(0) > 0x7f), isTrue);
    });
  });

  group('tokenizer details that are easy to get wrong', () {
    test('lowercasing happens before tokenizing', () {
      expect(
        TracAggressionDetector.tokenize(
            caseOf('uppercase')['text'] as String),
        TracAggressionDetector.tokenize(
            caseOf('english_aggressive')['text'] as String),
        reason: 'the uppercase and lowercase forms must tokenize identically',
      );
    });

    test("apostrophes stay inside a token", () {
      final toks =
          TracAggressionDetector.tokenize(caseOf('apostrophe')['text'] as String);
      expect(toks.contains("don't"), isTrue);
      expect(toks.contains('don'), isFalse);
    });

    test('empty text yields no tokens', () {
      expect(TracAggressionDetector.tokenize(''), isEmpty);
    });

    test('over-length input is truncated, not wrapped', () {
      final c = caseOf('over_maxlen');
      expect(c['n_tokens_before_truncation'], 80);
      final toks =
          TracAggressionDetector.tokenize(c['text'] as String);
      expect(toks.length, 80);
      // the fixture holds the first 60 in order — not a sample, not the tail
      expect(toks.sublist(0, TracAggressionDetector.kMaxLen), c['tokens']);
    });
  });

  group('thresholds are ordered and above the model floor', () {
    test('calm < hostile', () {
      expect(TracAggressionDetector.kCalmThreshold,
          lessThan(TracAggressionDetector.kHostileThreshold));
    });

    test('the hostile bar sits above the empty-input score', () {
      // Empty text scores 0.3322 — the model has a non-zero floor. A
      // threshold at or below it would call silence hostile.
      final floor = (caseOf('empty')['score'] as num).toDouble();
      expect(TracAggressionDetector.kHostileThreshold, greaterThan(floor));
      expect(TracAggressionDetector.kCalmThreshold, greaterThan(floor));
    });
  });
}
