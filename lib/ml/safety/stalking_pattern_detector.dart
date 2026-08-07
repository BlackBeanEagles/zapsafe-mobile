/// Day 94 — GPS co-location stalking pattern (rules-only v1).
///
/// Detects repeated unknown presence near user routes across days/locations.
/// Privacy: exclude trusted-circle device IDs; optional local-only analysis.
library;

import 'dart:math' as math;

/// Single GPS sample on a trail.
class GpsTrailPoint {
  const GpsTrailPoint({
    required this.timestamp,
    required this.latitude,
    required this.longitude,
  });

  final DateTime timestamp;
  final double latitude;
  final double longitude;
}

/// Tunable thresholds — mirrors backend [StalkingAnalysisConfig].
class StalkingPatternConfig {
  const StalkingPatternConfig({
    this.coLocationRadiusM = 50.0,
    this.timeWindowMinutes = 10.0,
    this.minIncidentsForAlert = 3,
    this.minLocationClusters = 2,
    this.lookbackDays = 7,
    this.gridCellDeg = 0.002,
    this.analyzeOnDevice = false,
  });

  final double coLocationRadiusM;
  final double timeWindowMinutes;
  final int minIncidentsForAlert;
  final int minLocationClusters;
  final int lookbackDays;
  final double gridCellDeg;

  /// Beta: when true, scoring is local-only (no backend trail upload).
  final bool analyzeOnDevice;
}

class StalkingPatternResult {
  const StalkingPatternResult({
    required this.riskScore,
    required this.incidentCount,
    required this.locationDiversity,
    this.message = '',
    this.flaggedDeviceIds = const [],
  });

  final double riskScore;
  final int incidentCount;
  final int locationDiversity;
  final String message;
  final List<String> flaggedDeviceIds;
}

/// Statistical co-location detector — not a neural network.
class StalkingPatternDetector {
  StalkingPatternDetector({StalkingPatternConfig? config})
      : _config = config ?? const StalkingPatternConfig();

  final StalkingPatternConfig _config;

  StalkingPatternResult analyze({
    required List<GpsTrailPoint> userTrail,
    Map<String, List<GpsTrailPoint>>? otherTrails,
    Set<String> excludedDeviceIds = const {},
  }) {
    final cfg = _config;
    final now = userTrail.isEmpty
        ? DateTime.now()
        : userTrail.map((p) => p.timestamp).reduce(
            (a, b) => a.isAfter(b) ? a : b,
          );
    final cutoff = now.subtract(Duration(days: cfg.lookbackDays));
    final user = userTrail.where((p) => p.timestamp.isAfter(cutoff)).toList();

    if (user.length < 2 || otherTrails == null || otherTrails.isEmpty) {
      return const StalkingPatternResult(
        riskScore: 0,
        incidentCount: 0,
        locationDiversity: 0,
        message: 'Insufficient trail data.',
      );
    }

    final incidents = <({DateTime day, (int, int) cell, String deviceId})>[];
    final windowSec = cfg.timeWindowMinutes * 60;

    for (final entry in otherTrails.entries) {
      if (excludedDeviceIds.contains(entry.key)) continue;
      final other =
          entry.value.where((p) => p.timestamp.isAfter(cutoff)).toList();
      if (other.length < 2) continue;

      for (final up in user) {
        for (final op in other) {
          final dt = up.timestamp.difference(op.timestamp).inSeconds.abs();
          if (dt > windowSec) continue;
          final dist = _haversineM(
            up.latitude,
            up.longitude,
            op.latitude,
            op.longitude,
          );
          if (dist <= cfg.coLocationRadiusM) {
            incidents.add((
              day: up.timestamp,
              cell: _gridKey(up.latitude, up.longitude, cfg.gridCellDeg),
              deviceId: entry.key,
            ));
            break;
          }
        }
      }
    }

    if (incidents.isEmpty) {
      return const StalkingPatternResult(
        riskScore: 0,
        incidentCount: 0,
        locationDiversity: 0,
        message: 'No repeated co-location pattern detected.',
      );
    }

    final days = incidents.map((i) => DateTime(
          i.day.year,
          i.day.month,
          i.day.day,
        )).toSet();
    final cells = incidents.map((i) => i.cell).toSet();
    final devices = incidents.map((i) => i.deviceId).toSet();
    final incidentCount = days.length;
    final locationDiversity = cells.length;

    final meets = incidentCount >= cfg.minIncidentsForAlert &&
        locationDiversity >= cfg.minLocationClusters;
    final incidentFactor = math.min(
      1.0,
      incidentCount / cfg.minIncidentsForAlert,
    );
    final diversityFactor = math.min(
      1.0,
      locationDiversity / cfg.minLocationClusters,
    );
    final risk = meets
        ? incidentFactor * diversityFactor
        : 0.15 * incidentFactor;

    final message = meets
        ? 'A device was near your route $incidentCount times this week '
            'at $locationDiversity different locations.'
        : '';

    return StalkingPatternResult(
      riskScore: math.min(1.0, risk),
      incidentCount: incidentCount,
      locationDiversity: locationDiversity,
      message: message,
      flaggedDeviceIds: devices.toList()..sort(),
    );
  }

  double _haversineM(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final p1 = lat1 * math.pi / 180;
    final p2 = lat2 * math.pi / 180;
    final dphi = (lat2 - lat1) * math.pi / 180;
    final dl = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dphi / 2) * math.sin(dphi / 2) +
        math.cos(p1) * math.cos(p2) * math.sin(dl / 2) * math.sin(dl / 2);
    return 2 * r * math.asin(math.min(1.0, math.sqrt(a)));
  }

  (int, int) _gridKey(double lat, double lon, double cellDeg) {
    return ((lat / cellDeg).floor(), (lon / cellDeg).floor());
  }
}
