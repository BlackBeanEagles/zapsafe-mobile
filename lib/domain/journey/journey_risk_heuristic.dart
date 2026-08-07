/// Day 323 — Journey Mode ML Confidence: local risk heuristic.
///
/// 🟡 MOCK-NOW. The spec's imagined API contract (`POST
/// /api/v1/journey/session/start/`, `GET
/// /api/v1/journey/session/{id}/risk-score/`) does **not** match what
/// `zapsafe_backend/journey/` actually exposes — verified by reading
/// `zapsafe_backend/journey/urls.py` directly. The real routes are:
///   • `POST /api/v1/journey/start/`                    (solo journey start)
///   • `POST /api/v1/journey/<uuid:id>/checkpoint/`      (solo checkpoint)
///   • `POST /api/v1/journey/group/create/` / `join/` / `<id>/panic/` /
///     `<id>/` (group journey — separate feature)
/// None of them return a server-computed risk/confidence score — that
/// endpoint genuinely does not exist yet on either name. So this file
/// computes the 0-100 score **locally** from real, already-in-repo
/// [GpsSample] fields until a real risk-score endpoint ships.
///
/// Heuristic inputs (both real, not fabricated):
///   • Time-of-day — night hours statistically correlate with elevated
///     personal-safety risk; this mirrors the same "LP" mental model the
///     rest of the app uses for e.g. battery tiers, not a new concept.
///   • GPS speed (from real [GpsSample.speedMps] / [GpsSample.accuracyM])
///     — a journey where the user has stopped moving mid-route, is moving
///     erratically (high sample-to-sample speed variance), or the fix
///     quality has degraded, all raise the score.
///
/// This is a heuristic, not a trained model — it does not claim ML
/// provenance. "ML Confidence" in the Day 323 title refers to the future
/// server-side ML risk score this local heuristic stands in for.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../data/models/gps_sample.dart';

/// Below this speed (m/s) a sample counts as "stationary". ~1 km/h.
const double kJourneyStationarySpeedMps = 0.3;

/// Above this speed (m/s) a sample counts as "unusually fast" for a
/// personal-safety journey (~108 km/h — highway speed, plausible in a
/// vehicle but worth a small bump given SOS journeys are usually on foot
/// or in city traffic).
const double kJourneyFastSpeedMps = 30.0;

/// GPS fix accuracy worse than this (metres) is treated as low quality —
/// same LP12 threshold [GpsSample.isHighQuality] already uses elsewhere
/// in this repo.
const double kJourneyLowQualityAccuracyM = 50.0;

/// Sample-to-sample speed standard deviation (m/s) above which a journey
/// is flagged as "erratic".
const double kJourneyErraticSpeedStdDevMps = 5.0;

@immutable
class JourneyRiskResult {
  /// 0 (lowest) – 100 (highest) risk.
  final int riskScore;

  /// `100 - riskScore` — what the dashboard card's confidence meter shows.
  int get confidenceScore => 100 - riskScore;

  /// Human-readable factors that contributed, in the order they were
  /// evaluated — surfaced by the Day 323 screen so the score is never a
  /// black box.
  final List<String> reasons;

  const JourneyRiskResult({required this.riskScore, required this.reasons});

  static const JourneyRiskResult empty =
      JourneyRiskResult(riskScore: 20, reasons: ['No samples yet — baseline']);
}

/// Computes a real 0-100 risk score from [recentSamples] (chronological,
/// oldest first) and [now] (defaults to [DateTime.now]).
///
/// Pure function — no I/O, no randomness, deterministic for a given input,
/// so it's directly unit-testable.
JourneyRiskResult computeJourneyRiskScore({
  required List<GpsSample> recentSamples,
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  var risk = 20; // baseline — a journey in progress is never zero-risk.
  final reasons = <String>['Baseline · 20'];

  // ── Time-of-day ──────────────────────────────────────────────────────
  final hour = clock.hour;
  if (hour >= 22 || hour < 5) {
    risk += 30;
    reasons.add('Night hours (${_hh(hour)}:00) · +30');
  } else if ((hour >= 5 && hour < 8) || (hour >= 18 && hour < 22)) {
    risk += 10;
    reasons.add('Dawn/dusk hours (${_hh(hour)}:00) · +10');
  } else {
    reasons.add('Daytime hours (${_hh(hour)}:00) · +0');
  }

  if (recentSamples.isEmpty) {
    risk += 5;
    reasons.add('No GPS samples yet · +5');
    return JourneyRiskResult(riskScore: risk.clamp(0, 100), reasons: reasons);
  }

  // ── Latest-sample checks ─────────────────────────────────────────────
  final last = recentSamples.last;
  final speed = last.speedMps;
  if (speed == null) {
    risk += 5;
    reasons.add('Speed unavailable from GPS fix · +5');
  } else if (speed < kJourneyStationarySpeedMps) {
    risk += 15;
    reasons.add(
        'Stationary mid-journey (${speed.toStringAsFixed(1)} m/s) · +15');
  } else if (speed > kJourneyFastSpeedMps) {
    risk += 10;
    reasons.add(
        'Unusually fast (${speed.toStringAsFixed(1)} m/s) · +10');
  } else {
    reasons.add('Normal movement (${speed.toStringAsFixed(1)} m/s) · +0');
  }

  if (last.accuracyM > kJourneyLowQualityAccuracyM) {
    risk += 5;
    reasons.add(
        'Low-quality GPS fix (±${last.accuracyM.toStringAsFixed(0)}m) · +5');
  }

  // ── Sample-to-sample speed variability ───────────────────────────────
  if (recentSamples.length >= 3) {
    final speeds = recentSamples.map((s) => s.speedMps ?? 0.0).toList();
    final mean = speeds.reduce((a, b) => a + b) / speeds.length;
    final variance = speeds
            .map((s) => (s - mean) * (s - mean))
            .reduce((a, b) => a + b) /
        speeds.length;
    final stdDev = math.sqrt(variance);
    if (stdDev > kJourneyErraticSpeedStdDevMps) {
      risk += 10;
      reasons.add(
          'Erratic speed pattern (σ=${stdDev.toStringAsFixed(1)} m/s) · +10');
    }
  }

  return JourneyRiskResult(riskScore: risk.clamp(0, 100), reasons: reasons);
}

String _hh(int hour) => hour.toString().padLeft(2, '0');
