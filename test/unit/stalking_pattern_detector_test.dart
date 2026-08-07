import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/ml/safety/stalking_pattern_detector.dart';

void main() {
  group('StalkingPatternDetector', () {
    final base = DateTime(2026, 5, 1, 9, 0);

    List<GpsTrailPoint> trail(
      List<double> lats,
      List<double> lons, {
      int dayOffset = 0,
    }) {
      final start = base.add(Duration(days: dayOffset));
      return List.generate(lats.length, (i) {
        return GpsTrailPoint(
          timestamp: start.add(Duration(minutes: 5 * i)),
          latitude: lats[i],
          longitude: lons[i],
        );
      });
    }

    test('follower pattern raises risk', () {
      final user = <GpsTrailPoint>[];
      final follower = <GpsTrailPoint>[];
      for (var d = 0; d < 3; d++) {
        user.addAll(trail([28.61, 28.62, 28.63], [77.20, 77.21, 77.22], dayOffset: d));
        follower.addAll(
          trail(
            [28.6102, 28.6202, 28.6302],
            [77.2002, 77.2102, 77.2202],
            dayOffset: d,
          ),
        );
      }

      final result = StalkingPatternDetector().analyze(
        userTrail: user,
        otherTrails: {'unknown-1': follower},
      );

      expect(result.incidentCount, greaterThanOrEqualTo(3));
      expect(result.locationDiversity, greaterThanOrEqualTo(2));
      expect(result.riskScore, greaterThanOrEqualTo(0.75));
      expect(result.message, contains('near your route'));
    });

    test('random stranger stays low risk', () {
      final user = trail([28.61, 28.62], [77.20, 77.21]);
      final stranger = trail(
        [28.70, 28.71],
        [77.30, 77.31],
        dayOffset: 2,
      );

      final result = StalkingPatternDetector().analyze(
        userTrail: user,
        otherTrails: {'stranger': stranger},
      );

      expect(result.riskScore, lessThan(0.5));
    });
  });
}
