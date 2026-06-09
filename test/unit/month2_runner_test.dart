// Day 40 — Month 2 acceptance runner tests.
//
// We exercise the `month2PhaseRunners` static helpers directly. Each one
// is a pure-Dart function (no Riverpod, no plugins) so we can probe the
// runner contract on the host VM without a Flutter binding.

import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/domain/integration/month1_runner.dart';
import 'package:zapsafe_mobile/domain/integration/month2_runner.dart';

void main() {
  group('month2PhaseRunners · individual probes', () {
    test('channelRegistry returns PASS with 9 channels', () {
      final r = month2PhaseRunners.channelRegistry();
      expect(r.status, PhaseStatus.pass);
      expect(r.detail, contains('9 unique channels'));
    });

    test('tfliteRegistry returns PASS with 4 model slots', () {
      final r = month2PhaseRunners.tfliteRegistry();
      expect(r.status, PhaseStatus.pass);
      expect(r.detail, contains('4 model slots'));
    });

    test('dcsWatcher returns PASS · vote + autoSos both fire', () {
      final r = month2PhaseRunners.dcsWatcher();
      expect(r.status, PhaseStatus.pass);
      expect(r.detail, contains('vote=3-window'));
      expect(r.detail, contains('autoSos=single'));
    });

    test('imuService returns PASS · construct + atRest synthesis works', () {
      final r = month2PhaseRunners.imuService();
      expect(r.status, PhaseStatus.pass);
    });

    test('gpsProfileMapping returns PASS · all 7 states covered', () {
      final r = month2PhaseRunners.gpsProfileMapping();
      expect(r.status, PhaseStatus.pass);
      expect(r.detail, contains('all 7 AppStates'));
    });

    test('gpsFallbackPolicy returns PASS · LP12 gate behaves', () {
      final r = month2PhaseRunners.gpsFallbackPolicy();
      expect(r.status, PhaseStatus.pass);
      expect(r.detail, contains('good→ok'));
      expect(r.detail, contains('bad'));
    });

    test('batteryTiers returns PASS · 80/18/13/7 + charging', () {
      final r = month2PhaseRunners.batteryTiers();
      expect(r.status, PhaseStatus.pass);
      expect(r.detail, contains('80% → normal'));
      expect(r.detail, contains('charging override'));
    });

    test('stateMachine returns PASS · monitoring → … → monitoring', () {
      final r = month2PhaseRunners.stateMachine();
      expect(r.status, PhaseStatus.pass);
      expect(r.detail, contains('monitoring → alertPending'));
    });

    test('orchestratorWiring returns PASS · DCS + fall route correctly', () {
      final r = month2PhaseRunners.orchestratorWiring();
      expect(r.status, PhaseStatus.pass);
      expect(r.detail, contains('autoSos → sosActive'));
      expect(r.detail, contains('fall → alertPending'));
    });
  });

  group('IntegrationSummary · GREEN gating', () {
    test('Month 2 unit-runnable phases all collapse to PASS', () async {
      // We can't run buildMonth2Phases() here without a WidgetRef, but we
      // can synthesise PhaseResults from each pure runner and confirm the
      // summary collapses to GREEN.
      final results = <PhaseResult>[
        month2PhaseRunners.channelRegistry(),
        month2PhaseRunners.tfliteRegistry(),
        month2PhaseRunners.dcsWatcher(),
        month2PhaseRunners.imuService(),
        month2PhaseRunners.gpsProfileMapping(),
        month2PhaseRunners.gpsFallbackPolicy(),
        month2PhaseRunners.batteryTiers(),
        month2PhaseRunners.stateMachine(),
        month2PhaseRunners.orchestratorWiring(),
      ];
      final summary = IntegrationSummary.from(results);
      expect(summary.total, 9);
      expect(summary.pass, 9);
      expect(summary.fail, 0);
      expect(summary.expectedFail, 0);
      expect(summary.isGreen, isTrue);
    });
  });
}
