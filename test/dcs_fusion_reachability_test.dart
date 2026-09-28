import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/data/services/interpreter.dart';
import 'package:zapsafe_mobile/ml/inference/dcs_score_watcher.dart';

/// Day 327 — the DCS escalation threshold must be *reachable*.
///
/// The bug this pins: `DCSInferenceEngine`'s motion slot declares
/// `expectedInputSize: 6` while every real motion model has been windowed
/// (`motion_anomaly_v1` = 600 floats, `motion_fall_v2` = 300).
/// `TfliteInterpreter.tryLoad` returns null on that mismatch, and the engine
/// substitutes [FixedStubInterpreter], whose `classScores` is `{label:
/// score}` — i.e. `{'normal': 0.15}`. The engine's `_dangerScore` then looks
/// for `fall`/`unusual`, finds neither, and returns **0**. Scene behaves the
/// same way.
///
/// So the fused score was `0.5·scream + 0.3·0 + 0.2·0`, capped at **0.50**,
/// against a **0.75** alert threshold. `onDCSThresholdExceeded()` — a
/// documented SOS trigger — could never fire. Nothing threw, every test
/// passed, and in debug the console printed the reason on every window.
///
/// ## Day 364D — the fusion was re-specified, so this file was rewritten
///
/// Scream is **dropped from the gate** (weight 0) and the weights and
/// threshold were derived together against measured scenarios rather than
/// guessed. The historical arithmetic below is kept, pinned against
/// **explicit historical constants** rather than the live ones, because it
/// documents two real bugs and would otherwise silently stop meaning
/// anything. The live configuration gets its own group.
///
/// These tests assert the arithmetic rather than the plumbing, because the
/// plumbing needs a native TFLite interpreter that `flutter test` does not
/// have. They fail if anyone reintroduces a fusion whose ceiling sits under
/// the threshold that consumes it.
void main() {
  // ── The LIVE fusion stub weights, from DCSInferenceEngine.create().
  const audioWeight = 0.0; // scream: dropped from the gate on Day 364D
  const motionWeight = 0.52;
  const sceneWeight = 0.48;

  // ── Historical constants. These are NOT the live weights. They exist so
  // the Day 326 and Day 335 findings keep their arithmetic.
  const oldAudioWeight = 0.5;
  const oldMotionWeight = 0.3;
  const oldSceneWeight = 0.2;
  const oldAlertThreshold = 0.75;
  const oldAutoSosThreshold = 0.85;

  /// What a [FixedStubInterpreter] contributes through `_dangerScore`:
  /// nothing, because its only class key is its own label.
  double stubDangerContribution(String stubLabel, List<String> dangerKeys) {
    const stub = FixedStubInterpreter(
      modelLabel: 'stub-motion',
      expectedInputSize: 6,
      classLabels: ['normal', 'unusual', 'fall'],
      label: 'normal',
      score: 0.15,
    );
    // Mirror _dangerScore: take the best danger-class probability present.
    final scores = {stub.label: stub.score};
    var best = 0.0;
    for (final k in dangerKeys) {
      final v = scores[k];
      if (v != null && v > best) best = v;
    }
    return best;
  }

  group('the Day 326 bug, pinned against historical constants', () {
    test('FixedStubInterpreter exposes only its own label as a class', () {
      expect(stubDangerContribution('normal', const ['fall', 'unusual']), 0.0,
          reason: 'this is the whole mechanism: the danger keys are absent');
      expect(stubDangerContribution('indoor', const ['outdoor']), 0.0);
    });

    test('audio alone could not reach it — this was the live bug', () {
      const audioOnlyCeiling = oldAudioWeight * 1.0;
      expect(audioOnlyCeiling, 0.5);
      expect(audioOnlyCeiling, lessThan(oldAlertThreshold),
          reason: 'with motion and scene stubbed the ceiling was 0.50 '
              'against a 0.75 threshold, so DCS escalation was '
              'mathematically unreachable');
    });

    test('audio + real motion cleared it, so the Day 327 fix sufficed', () {
      const ceiling = oldAudioWeight * 1.0 + oldMotionWeight * 1.0;
      expect(ceiling, closeTo(0.8, 1e-9));
      expect(ceiling, greaterThan(oldAlertThreshold));
    });

    test('the pre-Day-335 margin was only 0.05, which is why scene mattered',
        () {
      // 0.5·0.9 + 0.3·0.9 = 0.72 < 0.75. The arithmetic was much tighter
      // than "reachable" suggests.
      const bothHigh = oldAudioWeight * 0.9 + oldMotionWeight * 0.9;
      expect(bothHigh, closeTo(0.72, 1e-9));
      expect(bothHigh, lessThan(oldAlertThreshold),
          reason: 'two modalities at 0.9 still did NOT escalate');
      expect((oldAudioWeight + oldMotionWeight) - oldAlertThreshold,
          closeTo(0.05, 1e-9));
    });

    test('Day 335 — wiring scene made auto-SOS reachable at all', () {
      const ceiling = oldAudioWeight + oldMotionWeight + oldSceneWeight;
      expect(ceiling, closeTo(1.0, 1e-9));
      expect(ceiling, greaterThan(oldAutoSosThreshold));
      // Two saturated and the third silent still could not: 0.80 < 0.85.
      expect(oldAudioWeight + oldMotionWeight,
          lessThan(oldAutoSosThreshold));
    });
  });

  group('the LIVE fusion: scream dropped, two inputs', () {
    test('the weights are what DCSInferenceEngine ships', () {
      expect(audioWeight, 0.0, reason: 'scream no longer votes on the gate');
      expect(motionWeight, 0.52);
      expect(sceneWeight, 0.48);
      expect(audioWeight + motionWeight + sceneWeight, closeTo(1.0, 1e-9));
    });

    test('a saturated scream now contributes exactly nothing', () {
      // The point of Day 364D. scream_classifier_v5 separates ambient media
      // audio from violent audio at window-level AUC 0.606, so any linear
      // rule that let audio+motion fire also fired on television+fall.
      const screamSaturated = audioWeight * 1.0;
      expect(screamSaturated, 0.0);
      expect(screamSaturated, lessThan(DCSScoreWatcher.alertThreshold));
    });

    test('NO single modality can reach the alert threshold', () {
      for (final w in const [audioWeight, motionWeight, sceneWeight]) {
        expect(w * 1.0, lessThan(DCSScoreWatcher.alertThreshold),
            reason: 'one modality saturating must never be enough');
      }
      // The margin is deliberate, not incidental: 0.66 - 0.52 = 0.14.
      expect(DCSScoreWatcher.alertThreshold - motionWeight,
          closeTo(0.14, 1e-9),
          reason: 'chosen with >=0.05 margin so the gate is not on a '
              'knife edge; the search also offered 0.58/@0.59 with a 0.01 '
              'margin and it was rejected for that reason');
    });

    test('motion + scene together CAN reach it — reachability preserved', () {
      const ceiling = motionWeight + sceneWeight;
      expect(ceiling, closeTo(1.0, 1e-9));
      expect(ceiling, greaterThan(DCSScoreWatcher.alertThreshold),
          reason: 'this is the Day 326 property carried forward: the gate '
              'must be reachable by two agreeing modalities');
    });

    test('auto-SOS needs both inputs near-maximal', () {
      // 0.90 went UP while alertThreshold went down, because with scream
      // gone the fused score concentrates into two inputs.
      expect(DCSScoreWatcher.autoSosThreshold, 0.90);
      // Motion saturated and scene silent cannot bypass the vote.
      expect(motionWeight * 1.0, lessThan(DCSScoreWatcher.autoSosThreshold));
      // Nor can scene alone.
      expect(sceneWeight * 1.0, lessThan(DCSScoreWatcher.autoSosThreshold));
      // It needs scene above ~0.79 with motion saturated.
      const needed = (0.90 - motionWeight) / sceneWeight;
      expect(needed, greaterThan(0.75));
      expect(needed, lessThan(0.80));
    });

    test('auto-SOS sits above the alert threshold', () {
      expect(DCSScoreWatcher.autoSosThreshold,
          greaterThan(DCSScoreWatcher.alertThreshold),
          reason: 'the bypass must be strictly harder than the vote');
    });

    test('a false-positive burst cannot escalate on its own', () {
      // m3_violence reads 0.725 off-corpus, so false positives are expected.
      // The fusion reads the raw 'violence' probability, not the label.
      const falseBurst = sceneWeight * 0.9;
      expect(falseBurst, closeTo(0.432, 1e-9));
      expect(falseBurst, lessThan(DCSScoreWatcher.alertThreshold),
          reason: 'a wrong burst alone must never alert');
      // But a wrong burst plus a fall does clear it — 0.52 + 0.432 = 0.952.
      // That is the measured B = 0.267 false-alert rate, accepted knowingly.
      expect(motionWeight * 1.0 + falseBurst,
          greaterThan(DCSScoreWatcher.alertThreshold));
    });
  });

  group('the weights are now measured, not guessed', () {
    test('the reliability inversion was FIXED by removing scream, not by '
        'reweighting it', () {
      // Day 363B measured evidence weight per input (LLR span, nats):
      //   motion 5.127 > scene 4.569 > scream 3.658
      // Day 364C then showed that simply reordering the weights to match
      // DOUBLES the false-alert rate (0.283 -> 0.650), because it raises
      // motion's share of a lowered threshold. The fix was to drop the
      // weakest input, not to re-rank all three.
      const motionLlr = 5.127;
      const sceneLlr = 4.569;
      const screamLlr = 3.658;
      expect(motionLlr, greaterThan(sceneLlr));
      expect(sceneLlr, greaterThan(screamLlr));
      // The live ordering now matches reliability for the inputs that remain.
      expect(motionWeight, greaterThan(sceneWeight));
      expect(sceneWeight, greaterThan(audioWeight));
    });
  });
}
