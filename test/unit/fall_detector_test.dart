import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/data/services/fall_detector.dart';

void main() {
  group('FallDetector · constants', () {
    test('thresholds match the published spec', () {
      expect(FallDetector.freefallThreshold, closeTo(2.94, 0.001));
      expect(FallDetector.impactThreshold, 25.0);
      expect(FallDetector.freefallMinMs, 200);
      expect(FallDetector.impactWindowMs, 1000);
    });
  });

  group('FallDetector · state transitions', () {
    test('starts in idle', () {
      final d = FallDetector();
      expect(d.state, FallDetectorState.idle);
    });

    test('high-g sample stays in idle', () {
      final d = FallDetector();
      d.observe(9.81, timestampMs: 0);
      d.observe(10.5, timestampMs: 30);
      expect(d.state, FallDetectorState.idle);
    });

    test('low-g sample transitions to possibleFreefall', () {
      final d = FallDetector();
      d.observe(1.0, timestampMs: 0);
      expect(d.state, FallDetectorState.possibleFreefall);
    });

    test('recovery before 200 ms hold resets to idle', () {
      final d = FallDetector();
      d.observe(1.0, timestampMs: 0);
      d.observe(9.81, timestampMs: 50); // back to gravity at 50 ms
      expect(d.state, FallDetectorState.idle);
    });

    test('200 ms sustained freefall promotes to awaitingImpact', () {
      final d = FallDetector();
      d.observe(0.5, timestampMs: 0);
      d.observe(0.5, timestampMs: 100);
      d.observe(0.5, timestampMs: 200);
      expect(d.state, FallDetectorState.awaitingImpact);
    });

    test('impact spike within window fires FallEvent', () {
      final d = FallDetector();
      d.observe(0.5, timestampMs: 0);
      d.observe(0.5, timestampMs: 100);
      d.observe(0.5, timestampMs: 200); // → awaitingImpact
      final ev = d.observe(30.0, timestampMs: 350);
      expect(ev, isNotNull);
      expect(ev!.peakAccelMagnitude, 30.0);
      expect(ev.freefallDurationMs, 200);
      expect(d.state, FallDetectorState.impactDetected);
    });

    test('no impact within 1 s after freefall returns detector to idle', () {
      final d = FallDetector();
      d.observe(0.5, timestampMs: 0);
      d.observe(0.5, timestampMs: 200);  // → awaitingImpact
      d.observe(9.81, timestampMs: 800); // walking gravity, no spike
      d.observe(9.81, timestampMs: 1300); // > 1 s past freefall end
      expect(d.state, FallDetectorState.idle);
    });

    test('latched impact returns to idle after 2 s', () {
      final d = FallDetector();
      d.observe(0.5, timestampMs: 0);
      d.observe(0.5, timestampMs: 200);
      d.observe(30.0, timestampMs: 350); // fire
      expect(d.state, FallDetectorState.impactDetected);
      d.observe(9.81, timestampMs: 2100); // > 2 s after start
      expect(d.state, FallDetectorState.idle);
    });

    test('reset() returns detector to idle immediately', () {
      final d = FallDetector();
      d.observe(0.5, timestampMs: 0);
      d.observe(0.5, timestampMs: 200);
      expect(d.state, FallDetectorState.awaitingImpact);
      d.reset();
      expect(d.state, FallDetectorState.idle);
      expect(d.lastPeak, 0);
    });
  });

  group('FallDetector · false-alarm rejection', () {
    test('a single hard impact without preceding freefall does NOT fire', () {
      final d = FallDetector();
      // A wrist flick — high impact, no preceding low-g window.
      d.observe(9.81, timestampMs: 0);
      d.observe(30.0, timestampMs: 100);
      expect(d.state, FallDetectorState.idle,
          reason: 'impact without freefall must not fire');
    });

    test('walking gait (varying gravity-ish) stays in idle', () {
      final d = FallDetector();
      for (var i = 0; i < 20; i++) {
        final mag = 9.81 + (i % 3) * 1.5; // 9.81 / 11.3 / 12.8 cycle
        d.observe(mag, timestampMs: i * 30);
      }
      expect(d.state, FallDetectorState.idle);
    });

    test('brief 100 ms zero-g spike (not enough hold) does NOT fire', () {
      final d = FallDetector();
      d.observe(0.5, timestampMs: 0);
      d.observe(0.5, timestampMs: 100);
      // Recovery before the 200 ms minimum hold.
      d.observe(9.81, timestampMs: 150);
      d.observe(30.0, timestampMs: 200); // impact, but no qualifying freefall
      expect(d.state, FallDetectorState.idle);
    });
  });

  group('FallDetector · lastPeak', () {
    test('records peak on impact, clears on reset', () {
      final d = FallDetector();
      d.observe(0.5, timestampMs: 0);
      d.observe(0.5, timestampMs: 200);
      d.observe(28.5, timestampMs: 350);
      expect(d.lastPeak, 28.5);
      d.reset();
      expect(d.lastPeak, 0);
    });
  });
}
