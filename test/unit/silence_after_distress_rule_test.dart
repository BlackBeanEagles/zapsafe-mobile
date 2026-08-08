import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/data/models/app_state.dart';
import 'package:zapsafe_mobile/domain/integration/trigger_orchestrator.dart';
import 'package:zapsafe_mobile/domain/providers/app_state_provider.dart';
import 'package:zapsafe_mobile/ml/inference/silence_after_distress_rule.dart';

void main() {
  group('SilenceAfterDistressRule', () {
    const rule = SilenceAfterDistressRule();
    final now = DateTime(2026, 5, 24, 12, 0, 0);

    test('escalates on scream → silence + still 30s', () {
      final result = rule.evaluate(
        SilenceAfterDistressInput(
          now: now,
          lastScreamAt: now.subtract(const Duration(seconds: 45)),
          audioRmsDb: 12,
          motionMagnitude: 0.05,
          motionStillSince: now.subtract(const Duration(seconds: 35)),
        ),
      );
      expect(result.shouldEscalate, isTrue);
      expect(result.possibleUnconscious, isTrue);
      expect(result.cause, contains('unconscious'));
    });

    test('no fire when person keeps talking after scream', () {
      final result = rule.evaluate(
        SilenceAfterDistressInput(
          now: now,
          lastScreamAt: now.subtract(const Duration(seconds: 20)),
          audioRmsDb: 45,
          motionMagnitude: 0.05,
          motionStillSince: now.subtract(const Duration(seconds: 35)),
        ),
      );
      expect(result.shouldEscalate, isFalse);
    });

    test('no fire when person keeps walking after scream', () {
      final result = rule.evaluate(
        SilenceAfterDistressInput(
          now: now,
          lastScreamAt: now.subtract(const Duration(seconds: 20)),
          audioRmsDb: 10,
          motionMagnitude: 1.2,
          motionStillSince: now.subtract(const Duration(seconds: 35)),
        ),
      );
      expect(result.shouldEscalate, isFalse);
    });
  });

  group('TriggerOrchestrator · silence after distress', () {
    test('orchestrator fires escalated cause string', () {
      final notifier = AppStateNotifier();
      final orchestrator = TriggerOrchestrator(notifier: notifier);
      const result = SilenceAfterDistressResult(
        shouldEscalate: true,
        possibleUnconscious: true,
        cause: SilenceAfterDistressRule.defaultCause,
      );

      orchestrator.dispatchSilenceAfterDistress(result);

      expect(notifier.state, AppState.sosActive);
      expect(notifier.possibleUnconscious, isTrue);
      expect(orchestrator.silenceEscalationCount, 1);
      expect(
        notifier.history.last.cause,
        contains('unconscious'),
      );
    });
  });
}
