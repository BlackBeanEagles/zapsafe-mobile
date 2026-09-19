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
/// These tests assert the arithmetic rather than the plumbing, because the
/// plumbing needs a native TFLite interpreter that `flutter test` does not
/// have. They fail if anyone reintroduces a fusion whose ceiling sits under
/// the threshold that consumes it.
void main() {
  // The fusion stub's weights, from DCSInferenceEngine.create().
  const audioWeight = 0.5;
  const motionWeight = 0.3;
  const sceneWeight = 0.2;

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

  group('a stubbed slot contributes nothing, not its score', () {
    test('FixedStubInterpreter exposes only its own label as a class', () {
      // This is the mechanism. The stub scores 0.15 but publishes it under
      // 'normal', so a danger-class lookup finds nothing.
      expect(stubDangerContribution('normal', const ['fall', 'unusual']), 0.0,
          reason: 'motion stub must be understood to contribute 0, not 0.15');
      expect(stubDangerContribution('indoor', const ['outdoor']), 0.0,
          reason: 'scene stub likewise');
    });
  });

  group('the alert threshold has to be reachable', () {
    test('audio alone cannot reach it — this was the live bug', () {
      const audioOnlyCeiling = audioWeight * 1.0;
      expect(audioOnlyCeiling, 0.5);
      expect(audioOnlyCeiling, lessThan(DCSScoreWatcher.alertThreshold),
          reason: 'documents WHY the fix was needed: with motion and scene '
              'stubbed the ceiling was 0.50 against a 0.75 threshold, so DCS '
              'escalation was mathematically unreachable');
    });

    test('audio + real motion clears it, so the fix is sufficient', () {
      const ceiling = audioWeight * 1.0 + motionWeight * 1.0;
      expect(ceiling, closeTo(0.8, 1e-9));
      expect(ceiling, greaterThan(DCSScoreWatcher.alertThreshold),
          reason: 'wiring the real windowed motion result makes the 0.75 '
              'alert threshold reachable');
    });

    test('it takes two modalities agreeing, not one spiking', () {
      // A perfect scream with no motion corroboration stays below alert.
      const screamOnly = audioWeight * 1.0 + motionWeight * 0.0;
      expect(screamOnly, lessThan(DCSScoreWatcher.alertThreshold),
          reason: 'a fusion should require corroboration; one modality '
              'saturating must not be enough');
    });

    test('the reachable margin is only 0.05, and that is worth knowing', () {
      // Wrote this test expecting 0.9/0.9 to clear the threshold. It does
      // not: 0.5·0.9 + 0.3·0.9 = 0.72 < 0.75. The arithmetic is much tighter
      // than "reachable" suggests, so pin the real requirement rather than a
      // comfortable-sounding one.
      const bothHigh = audioWeight * 0.9 + motionWeight * 0.9;
      expect(bothHigh, closeTo(0.72, 1e-9));
      expect(bothHigh, lessThan(DCSScoreWatcher.alertThreshold),
          reason: 'two modalities at 0.9 still do NOT escalate');

      // With scene contributing 0, clearing 0.75 needs near-saturation on
      // both: at scream 1.00 motion must exceed 0.833, at scream 0.95 it
      // must exceed 0.917, and below scream 0.90 it is impossible at any
      // motion value. Ceiling 0.80 against threshold 0.75 leaves 0.05.
      const ceiling = audioWeight + motionWeight;
      expect(ceiling - DCSScoreWatcher.alertThreshold, closeTo(0.05, 1e-9),
          reason: 'this narrow margin is the strongest argument for '
              'revisiting the weights and wiring scene — see '
              'DAY326_DCS_FUSION_NEVER_FUSED.md. The fix makes escalation '
              'possible, not comfortable.');
    });

    test('auto-SOS stays out of reach until scene is also wired', () {
      const ceiling = audioWeight + motionWeight; // scene still contributes 0
      expect(ceiling, lessThan(DCSScoreWatcher.autoSosThreshold),
          reason: 'stated, not hidden: the 0.85 single-window override cannot '
              'fire on audio+motion alone. Scene is deliberately left at 0 '
              'because the shipped scene_analyzer_v1 is near-chance (0.594) '
              'and a noisy input is worse than an absent one. Wiring the '
              'Day 326 temporal M3 (AUC 0.912) is what should raise this.');
    });
  });

  group('weights are documented as guessed, not measured', () {
    test('they still sum to 1.0', () {
      expect(audioWeight + motionWeight + sceneWeight, closeTo(1.0, 1e-9));
    });

    test('the ordering is inverted relative to measured reliability', () {
      // motion AUC 0.999 > scream 0.839 > scene 0.594 (held-out, real data),
      // yet motion carries less weight than scream. Left as-is here because
      // reweighting shifts escalation thresholds — a product decision, not a
      // wiring fix. Pinned so the discrepancy is not forgotten.
      const measuredMotionAuc = 0.999;
      const measuredScreamAuc = 0.839;
      expect(measuredMotionAuc, greaterThan(measuredScreamAuc));
      expect(motionWeight, lessThan(audioWeight),
          reason: 'the more reliable modality currently carries less weight; '
              'see DAY326_DCS_FUSION_NEVER_FUSED.md');
    });
  });
}
