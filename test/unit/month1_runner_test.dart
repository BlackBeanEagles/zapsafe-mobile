import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/domain/integration/month1_runner.dart';

/// Build a synthetic phase that resolves to a chosen status.
IntegrationPhase _phase({
  required String key,
  required PhaseStatus status,
  String detail = '',
  String? expectedFailReason,
}) {
  return IntegrationPhase(
    key: key,
    name: 'Phase $key',
    description: 'synthetic',
    expectedFailReason: expectedFailReason,
    runner: () async => PhaseResult(
      key: key,
      name: 'Phase $key',
      status: status,
      detail: detail,
    ),
  );
}

/// A phase that throws — used to exercise the runner's catch path.
IntegrationPhase _throwing({
  required String key,
  String? expectedFailReason,
}) {
  return IntegrationPhase(
    key: key,
    name: 'Phase $key',
    description: 'throws on purpose',
    expectedFailReason: expectedFailReason,
    runner: () => Future<PhaseResult>.error('boom'),
  );
}

void main() {
  group('runMonth1Integration', () {
    test('emits running + terminal for every phase, in order', () async {
      final phases = [
        _phase(key: 'a', status: PhaseStatus.pass),
        _phase(key: 'b', status: PhaseStatus.pass),
      ];

      final emitted = await runMonth1Integration(phases).toList();

      // Each phase emits 2 events: running, terminal.
      expect(emitted.length, 4);
      expect(emitted[0].key, 'a');
      expect(emitted[0].status, PhaseStatus.running);
      expect(emitted[1].key, 'a');
      expect(emitted[1].status, PhaseStatus.pass);
      expect(emitted[2].key, 'b');
      expect(emitted[2].status, PhaseStatus.running);
      expect(emitted[3].key, 'b');
      expect(emitted[3].status, PhaseStatus.pass);
    });

    test('does not short-circuit on failure — every phase runs', () async {
      final phases = [
        _phase(key: 'a', status: PhaseStatus.pass),
        _throwing(key: 'b'),
        _phase(key: 'c', status: PhaseStatus.pass),
      ];

      final emitted =
          await runMonth1Integration(phases).toList();
      final terminals =
          emitted.where((r) => r.isTerminal).toList();

      expect(terminals.length, 3);
      expect(terminals[0].status, PhaseStatus.pass);
      expect(terminals[1].status, PhaseStatus.fail);
      expect(terminals[1].detail, contains('boom'));
      expect(terminals[2].status, PhaseStatus.pass);
    });

    test('thrown exception becomes expectedFail when reason is set', () async {
      final phases = [
        _throwing(
          key: 'b',
          expectedFailReason: 'backend route not live',
        ),
      ];

      final terminals = await runMonth1Integration(phases)
          .where((r) => r.isTerminal)
          .toList();

      expect(terminals.single.status, PhaseStatus.expectedFail);
      expect(terminals.single.detail, contains('boom'));
      expect(terminals.single.detail, contains('backend route not live'));
    });

    test('records duration on each terminal result', () async {
      final phases = [
        IntegrationPhase(
          key: 'slow',
          name: 'slow',
          description: '',
          runner: () async {
            await Future<void>.delayed(const Duration(milliseconds: 30));
            return const PhaseResult(
              key: 'slow',
              name: 'slow',
              status: PhaseStatus.pass,
              detail: '',
            );
          },
        ),
      ];

      final terminal = await runMonth1Integration(phases)
          .where((r) => r.isTerminal)
          .first;

      expect(terminal.duration.inMilliseconds, greaterThanOrEqualTo(20));
    });
  });

  group('IntegrationSummary', () {
    test('counts only terminal phases', () {
      final results = [
        const PhaseResult(key: 'a', name: 'a', status: PhaseStatus.running, detail: ''),
        const PhaseResult(key: 'b', name: 'b', status: PhaseStatus.pass,    detail: ''),
        const PhaseResult(key: 'c', name: 'c', status: PhaseStatus.pass,    detail: ''),
        const PhaseResult(key: 'd', name: 'd', status: PhaseStatus.fail,    detail: ''),
        const PhaseResult(key: 'e', name: 'e', status: PhaseStatus.expectedFail, detail: ''),
        const PhaseResult(key: 'f', name: 'f', status: PhaseStatus.pending, detail: ''),
      ];

      final s = IntegrationSummary.from(results);
      expect(s.total, 4);
      expect(s.pass, 2);
      expect(s.fail, 1);
      expect(s.expectedFail, 1);
      expect(s.isGreen, isFalse);
    });

    test('isGreen requires zero hard failures', () {
      const allGreen = [
        PhaseResult(key: 'a', name: 'a', status: PhaseStatus.pass, detail: ''),
        PhaseResult(key: 'b', name: 'b', status: PhaseStatus.expectedFail, detail: ''),
      ];
      expect(IntegrationSummary.from(allGreen).isGreen, isTrue);

      const withHardFail = [
        PhaseResult(key: 'a', name: 'a', status: PhaseStatus.pass, detail: ''),
        PhaseResult(key: 'b', name: 'b', status: PhaseStatus.fail, detail: ''),
      ];
      expect(IntegrationSummary.from(withHardFail).isGreen, isFalse);
    });
  });

  group('runIntegrationPhases alias (Day 25)', () {
    test('emits the same events as runMonth1Integration', () async {
      final phases = [
        _phase(key: 'a', status: PhaseStatus.pass),
        _throwing(key: 'b', expectedFailReason: 'platform N/A'),
        _phase(key: 'c', status: PhaseStatus.pass),
      ];
      final aliasOut = await runIntegrationPhases(phases).toList();
      final originalOut = await runMonth1Integration(phases).toList();
      expect(aliasOut.length, originalOut.length);
      for (var i = 0; i < aliasOut.length; i++) {
        expect(aliasOut[i].key, originalOut[i].key);
        expect(aliasOut[i].status, originalOut[i].status);
      }
    });
  });

  group('PhaseResult.copyWith', () {
    test('preserves untouched fields', () {
      const base = PhaseResult(
        key: 'a',
        name: 'a',
        status: PhaseStatus.running,
        detail: 'before',
      );
      final after = base.copyWith(
        status: PhaseStatus.pass,
        detail: 'after',
      );
      expect(after.key, 'a');
      expect(after.name, 'a');
      expect(after.status, PhaseStatus.pass);
      expect(after.detail, 'after');
    });
  });
}
