import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;

/// Day 391 — `trac_aggression_v1`: is a message someone sent hostile?
///
/// ## What this is, and what it deliberately is not
///
/// It classifies **text someone else sent the user**, in English and Hindi.
/// It makes no inference about the user's own state. That distinction is
/// the entire reason this ships and `distress_text_v1` does not:
/// `DAY347_DISTRESS_TEXT_DECISION.md` shelved that model because its
/// positive classes are Anxiety, Depression and Suicidal — a clinical
/// inference about the person holding the phone. This one reads a message
/// the way a spam filter reads a message.
///
/// It is also **not M7**. M7 needs victim-perspective distress ("someone is
/// following me"). TRAC is aggressor-perspective: text written *by* the
/// aggressor. M7 stays blocked.
///
/// ## The numbers, and which one to quote
///
///     in-corpus (TRAC dev)                 0.8312   CI [0.8196, 0.8423]
///     cross-corpus (Indo-HateSpeech)       0.7081   CI [0.7028, 0.7134]
///     length-only baseline, in-corpus      0.6177
///     length-only baseline, cross-corpus   0.5223
///
/// **Quote 0.71, not 0.83.** The cross-corpus figure is 58,477 Instagram
/// comments in the same language pair, a different platform and different
/// annotators — and it is the first model in this project to survive that
/// test at all (m3_violence went 0.9126 → 0.4821, scream v3 0.839 → 0.7675).
/// Surviving is not the same as transferring intact.
///
/// One caveat that measurement cannot resolve: Indo-HateSpeech labels *hate
/// speech*, TRAC labels *aggression*. Related constructs, not identical, so
/// part of the 0.12 drop is the definitions differing rather than the model
/// failing. See `DAY353B_FIXTURE_LEGO_REJECTED_TRAC_CROSSCORPUS.md`.
///
/// ## Licence — the only clean one in the project
///
/// TRAC-1 is **Apache-2.0**. Five of the shipped models carry Non-Commercial
/// training data; this is the one that does not.
///
/// ## Bands, not a binary
///
/// Cross-corpus calibration is unknown, so a single threshold would overstate
/// what this can tell you. [classify] returns three bands and the raw score,
/// and the UI shows the score. An empty string scores 0.3322 — the model has
/// a non-zero floor — so [classify] requires at least [kMinTokens] tokens
/// before returning any verdict at all.
class TracAggressionDetector {
  TracAggressionDetector._(this._interpreter, this._vocab);

  final tfl.Interpreter _interpreter;
  final Map<String, int> _vocab;

  static const String kAsset = 'assets/models/trac_aggression_v1.tflite';
  static const String kVocabAsset =
      'assets/models/trac_aggression_v1_vocab.json';

  /// Fixed by the trained model — the input tensor is literally `[1, 60]`.
  static const int kMaxLen = 60;

  /// 0 is pad and 1 is out-of-vocabulary. They are different things and
  /// conflating them is a silent bug: an all-OOV sentence and an empty one
  /// would produce the same vector while meaning opposite things.
  static const int kPadIndex = 0;
  static const int kOovIndex = 1;

  /// Below this, no verdict. "hi" is not enough text to judge.
  static const int kMinTokens = 2;

  /// Favours precision. In-corpus the curve reads recall 0.675 at precision
  /// 0.896 here, versus 0.819/0.855 at 0.50 — and cross-corpus both will be
  /// worse. Telling someone a benign message is a threat is the failure that
  /// costs trust, so the bar sits high.
  static const double kHostileThreshold = 0.60;

  /// Below this, called non-hostile. Between the two, [Verdict.unclear].
  static const double kCalmThreshold = 0.40;

  /// Lowercase first, then split. The second branch is **load-bearing**: a
  /// plain `[a-z0-9']+` deletes every Devanagari character silently and
  /// returns an all-pad vector that the model still scores confidently at
  /// 0.33. That bug was caught during training and this regex is the fix.
  static final RegExp _token = RegExp(r"[a-z0-9']+|[^\u0000-\u007f]+");

  static List<String> tokenize(String text) =>
      _token.allMatches(text.toLowerCase()).map((m) => m[0]!).toList();

  /// Null on any failure, so a device missing the assets simply has no
  /// message check rather than a broken one.
  static Future<TracAggressionDetector?> tryLoad({
    String assetPath = kAsset,
    String vocabPath = kVocabAsset,
  }) async {
    tfl.Interpreter? interpreter;
    try {
      final raw = await rootBundle.loadString(vocabPath);
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final vocab = <String, int>{
        for (final e in decoded.entries) e.key: (e.value as num).toInt(),
      };
      if (vocab.isEmpty) {
        throw StateError('vocab is empty');
      }

      interpreter = await tfl.Interpreter.fromAsset(assetPath);
      final inShape = interpreter.getInputTensor(0).shape;
      if (!listEquals(inShape, const [1, kMaxLen])) {
        throw StateError('input shape $inShape, expected [1, $kMaxLen]');
      }
      final outShape = interpreter.getOutputTensor(0).shape;
      if (outShape.fold<int>(1, (a, b) => a * b) != 1) {
        throw StateError('output shape $outShape, expected a scalar');
      }
      return TracAggressionDetector._(interpreter, vocab);
    } catch (e) {
      try {
        interpreter?.close();
      } catch (_) {}
      if (kDebugMode) {
        debugPrint('[TracAggressionDetector] tryLoad failed: $e');
      }
      return null;
    }
  }

  /// Token ids, padded/truncated to [kMaxLen]. Exposed so the golden test
  /// can pin it separately from the model — if only the score drifts, that
  /// is the runtime; if the ids drift, that is the tokenizer.
  Int32List encode(String text) {
    final ids = Int32List(kMaxLen); // zero-filled == padded
    final toks = tokenize(text);
    final n = toks.length < kMaxLen ? toks.length : kMaxLen;
    for (var i = 0; i < n; i++) {
      ids[i] = _vocab[toks[i]] ?? kOovIndex;
    }
    return ids;
  }

  /// Raw model output in [0, 1]. Higher means more aggressive.
  ///
  /// Note this has a floor: empty input scores ~0.33, not 0. Use
  /// [classify] unless you specifically want the number.
  double score(String text) {
    final input = encode(text).reshape([1, kMaxLen]);
    final output = [Float32List(1)];
    _interpreter.run(input, output);
    return output[0][0].toDouble().clamp(0.0, 1.0);
  }

  /// The banded verdict, plus the score and token count behind it.
  TracVerdict classify(String text) {
    final tokens = tokenize(text);
    if (tokens.length < kMinTokens) {
      return TracVerdict(
        verdict: Verdict.tooShort,
        score: null,
        tokenCount: tokens.length,
        truncated: false,
      );
    }
    final s = score(text);
    final v = s >= kHostileThreshold
        ? Verdict.hostile
        : (s < kCalmThreshold ? Verdict.notHostile : Verdict.unclear);
    return TracVerdict(
      verdict: v,
      score: s,
      tokenCount: tokens.length,
      truncated: tokens.length > kMaxLen,
    );
  }

  void dispose() {
    try {
      _interpreter.close();
    } catch (_) {
      // already closed
    }
  }
}

enum Verdict {
  /// Fewer than [TracAggressionDetector.kMinTokens] tokens — no judgement.
  tooShort,
  notHostile,

  /// Between the two thresholds. Shown as "unclear" rather than rounded to
  /// one side, because the cross-corpus calibration does not support
  /// pretending a 0.5 is informative.
  unclear,
  hostile,
}

@immutable
class TracVerdict {
  const TracVerdict({
    required this.verdict,
    required this.score,
    required this.tokenCount,
    required this.truncated,
  });

  final Verdict verdict;

  /// Null only when [verdict] is [Verdict.tooShort].
  final double? score;
  final int tokenCount;

  /// True when the message was longer than 60 tokens and only the first 60
  /// were read. Surfaced in the UI — a user pasting a long message should
  /// know the tail was not considered.
  final bool truncated;
}
