/// Day 50 — Motion & Fall Detection Validation unit tests.
///
/// Validates the data models and service logic powering the motion screen:
///   - MotionFeatures tensor layout and factory fixtures
///   - FallDetector state machine transitions
///   - FallEvent fields
///   - HeuristicMotionDetector end-to-end via MotionFeatures tensor
///   - Accel magnitude history window (spark-line logic)
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/data/models/fall_event.dart';
import 'package:zapsafe_mobile/data/models/motion_features.dart';
import 'package:zapsafe_mobile/data/services/fall_detector.dart';
import 'package:zapsafe_mobile/data/services/heuristic_motion_detector.dart';

void main() {
  // ── 1. MotionFeatures model ────────────────────────────────────────────
  group('MotionFeatures model', () {
    test('atRest has near-gravity accelMean', () {
      final f = MotionFeatures.atRest(timestampMs: 0);
      expect(f.accelMean, closeTo(9.81, 1.0));
    });

    test('walking has accelPeak > accelMean', () {
      final f = MotionFeatures.walking(timestampMs: 0);
      expect(f.accelPeak, greaterThan(f.accelMean));
    });

    test('impact has accelPeak > 15 m/s²', () {
      final f = MotionFeatures.impact(timestampMs: 0);
      expect(f.accelPeak, greaterThan(15.0));
    });

    test('toFloat32Tensor returns 6-element Float32List', () {
      final t = MotionFeatures.atRest(timestampMs: 0).toFloat32Tensor();
      expect(t, isA<Float32List>());
      expect(t.length, equals(6));
    });

    test('tensor layout: [0]=accelMean [1]=accelVar [2]=accelPeak '
        '[3]=gyroMean [4]=gyroVar [5]=gyroPeak', () {
      final f = MotionFeatures.atRest(timestampMs: 0);
      final t = f.toFloat32Tensor();
      expect(t[0], closeTo(f.accelMean, 0.001));
      expect(t[1], closeTo(f.accelVar,  0.001));
      expect(t[2], closeTo(f.accelPeak, 0.001));
      expect(t[3], closeTo(f.gyroMean,  0.001));
      expect(t[4], closeTo(f.gyroVar,   0.001));
      expect(t[5], closeTo(f.gyroPeak,  0.001));
    });

    test('all fields non-negative', () {
      for (final f in [
        MotionFeatures.atRest(timestampMs: 0),
        MotionFeatures.walking(timestampMs: 0),
        MotionFeatures.impact(timestampMs: 0),
      ]) {
        expect(f.accelMean, greaterThanOrEqualTo(0.0));
        expect(f.accelVar,  greaterThanOrEqualTo(0.0));
        expect(f.accelPeak, greaterThanOrEqualTo(0.0));
        expect(f.gyroMean,  greaterThanOrEqualTo(0.0));
        expect(f.gyroVar,   greaterThanOrEqualTo(0.0));
        expect(f.gyroPeak,  greaterThanOrEqualTo(0.0));
      }
    });
  });

  // ── 2. HeuristicMotionDetector via MotionFeatures tensor ──────────────
  group('HeuristicMotionDetector via MotionFeatures tensor', () {
    const detector = HeuristicMotionDetector();

    test('impact features → threat classScore > 0.5', () async {
      final t = MotionFeatures.impact(timestampMs: 0).toFloat32Tensor();
      final r = await detector.infer(t, timestampMs: 0);
      expect(r.classScores['threat'] ?? 0.0, greaterThan(0.5));
    });

    test('atRest features → threat classScore < 0.5', () async {
      final t = MotionFeatures.atRest(timestampMs: 0).toFloat32Tensor();
      final r = await detector.infer(t, timestampMs: 0);
      expect(r.classScores['threat'] ?? 0.0, lessThan(0.5));
    });

    test('expectedInputSize matches tensor length', () {
      final tensorLen = MotionFeatures.atRest(timestampMs: 0)
          .toFloat32Tensor().length;
      expect(detector.expectedInputSize, equals(tensorLen));
    });

    test('classLabels contains normal and threat', () {
      expect(detector.classLabels, containsAll(['normal', 'threat']));
    });

    test('result has correct timestampMs', () async {
      const ts = 42000;
      final t = MotionFeatures.impact(timestampMs: ts).toFloat32Tensor();
      final r = await detector.infer(t, timestampMs: ts);
      expect(r.timestampMs, equals(ts));
    });
  });

  // ── 3. FallDetector state machine ─────────────────────────────────────
  group('FallDetector state machine', () {
    test('starts in idle', () {
      expect(FallDetector().state, FallDetectorState.idle);
    });

    test('low accel → transitions to possibleFreefall', () {
      final d = FallDetector();
      // Below freefall threshold (~3 m/s² = 0.3 g)
      d.observe(2.5, timestampMs: 0);
      expect(d.state, FallDetectorState.possibleFreefall);
    });

    test('freefall then high accel → impactDetected, returns FallEvent', () {
      final d = FallDetector();
      // Phase 1: enter freefall (magnitude < 2.94 m/s²)
      d.observe(2.0, timestampMs: 0);
      expect(d.state, FallDetectorState.possibleFreefall);

      // Phase 2: sustain low-g for ≥200 ms → awaitingImpact
      d.observe(2.0, timestampMs: 200);
      expect(d.state, FallDetectorState.awaitingImpact);

      // Phase 3: impact spike > 25 m/s² → FallEvent
      final event = d.observe(30.0, timestampMs: 250);
      expect(event, isNotNull);
      expect(event!.peakAccelMagnitude, equals(30.0));
      expect(d.state, FallDetectorState.impactDetected);
    });

    test('reset returns detector to idle', () {
      final d = FallDetector();
      d.observe(2.0, timestampMs: 0);
      expect(d.state, FallDetectorState.possibleFreefall);
      d.reset();
      expect(d.state, FallDetectorState.idle);
    });

    test('normal walking accel does not leave idle', () {
      final d = FallDetector();
      // Walking ≈ 10–13 m/s² — above freefall threshold, below impact
      for (var i = 0; i < 10; i++) {
        d.observe(11.0, timestampMs: i * 50);
      }
      expect(d.state, FallDetectorState.idle);
    });

    test('all FallDetectorState values exist', () {
      expect(FallDetectorState.values, containsAll([
        FallDetectorState.idle,
        FallDetectorState.possibleFreefall,
        FallDetectorState.awaitingImpact,
        FallDetectorState.impactDetected,
      ]));
    });
  });

  // ── 4. FallEvent fields ───────────────────────────────────────────────
  group('FallEvent fields', () {
    FallEvent _event() => FallEvent(
          timestampMs: 12345,
          peakAccelMagnitude: 32.5,
          freefallDurationMs: 90,
        );

    test('timestampMs preserved', () {
      expect(_event().timestampMs, equals(12345));
    });

    test('peakAccelMagnitude preserved', () {
      expect(_event().peakAccelMagnitude, closeTo(32.5, 0.001));
    });

    test('freefallDurationMs preserved', () {
      expect(_event().freefallDurationMs, equals(90));
    });
  });

  // ── 5. Accel history spark-line window logic ──────────────────────────
  group('Accel history spark-line window', () {
    const historyLen = 30;

    test('capped at historyLen items', () {
      final history = <double>[];
      for (var i = 0; i < 40; i++) {
        history.add(i.toDouble());
        if (history.length > historyLen) history.removeAt(0);
      }
      expect(history.length, equals(historyLen));
    });

    test('newest sample is last', () {
      final history = <double>[];
      for (var i = 0; i < 5; i++) {
        history.add(i.toDouble());
        if (history.length > historyLen) history.removeAt(0);
      }
      expect(history.last, equals(4.0));
    });

    test('fraction clamped to [0, 1] for bar heights', () {
      final magnitudes = [0.0, 9.8, 25.0, 35.0, 100.0];
      final fractions  = magnitudes.map((v) => (v / 30.0).clamp(0.0, 1.0));
      for (final f in fractions) {
        expect(f, inInclusiveRange(0.0, 1.0));
      }
    });

    test('accel > 25 m/s² maps to danger bucket, 15–25 warning, else safe', () {
      String bucketFor(double v) {
        if (v > 25) return 'danger';
        if (v > 15) return 'warning';
        return 'safe';
      }

      expect(bucketFor(30.0), equals('danger'));
      expect(bucketFor(18.0), equals('warning'));
      expect(bucketFor(10.0), equals('safe'));
      expect(bucketFor(25.1), equals('danger'));
      expect(bucketFor(15.1), equals('warning'));
    });
  });
}
