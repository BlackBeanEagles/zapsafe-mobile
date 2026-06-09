import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/gps_sample.dart';
import 'cell_location_service.dart';
import 'gps_service.dart';

/// Day 38 — decision policy that merges cell-tower / WiFi estimates into
/// the GPS sample stream whenever the chip's own fixes are unusable.
///
/// Listens to [GpsService.samples]. For each GPS-provider sample it
/// applies the LP12 quality gate:
///   • accuracy ≤ 50 m  → no fallback needed; reset stale timer
///   • accuracy >  50 m → eligible for fallback
/// A separate "stale" timer also fires the fallback if no fix at all has
/// landed within [staleWindow] (90 s by default — long enough for a slow
/// indoor cold-start, short enough for the SOS path to still be useful).
///
/// Cell-provider samples are passively passed through and never trigger
/// further fallback (no recursion).
class GpsFallbackCoordinator {
  /// LP12 accuracy threshold. Identical to [GpsSample.isHighQuality]'s
  /// gate so the contract is enforced in one place.
  static const double accuracyThresholdM = 50;

  /// Default time-without-a-fix that triggers a fallback poll.
  static const Duration defaultStaleWindow = Duration(seconds: 90);

  /// Minimum gap between two fallback attempts. Prevents a thrashing
  /// loop if the cell estimator keeps returning low-quality results.
  static const Duration defaultMinAttemptGap = Duration(seconds: 30);

  final GpsService _gps;
  final CellLocationService _cell;
  final Duration staleWindow;
  final Duration minAttemptGap;
  StreamSubscription<GpsSample>? _sub;
  Timer? _staleTimer;

  GpsFallbackCoordinator({
    required GpsService gps,
    required CellLocationService cell,
    this.staleWindow = defaultStaleWindow,
    this.minAttemptGap = defaultMinAttemptGap,
  })  : _gps = gps,
        _cell = cell;

  int _gpsLowQualityTriggers = 0;
  int _staleTriggers = 0;
  int _gpsRecoveries = 0;
  int _fallbackEmissions = 0;
  GpsSample? _lastEvaluated;
  DateTime? _lastAttemptAt;
  bool _wasLowQuality = false;
  bool _attached = false;

  int get gpsLowQualityTriggers => _gpsLowQualityTriggers;
  int get staleTriggers => _staleTriggers;
  int get gpsRecoveries => _gpsRecoveries;
  int get fallbackEmissions => _fallbackEmissions;
  GpsSample? get lastEvaluated => _lastEvaluated;
  DateTime? get lastAttemptAt => _lastAttemptAt;
  bool get isAttached => _attached;

  /// Begin watching the GPS sample stream. Idempotent — calling again
  /// while attached is a no-op so screens can hot-reload safely.
  void attach() {
    if (_attached) return;
    _attached = true;
    _sub = _gps.samples.listen(_onSample);
    _restartStaleTimer();
  }

  /// Stop watching. Counters survive so the screen can show last-session
  /// stats after a pause.
  void detach() {
    _attached = false;
    _sub?.cancel();
    _sub = null;
    _staleTimer?.cancel();
    _staleTimer = null;
  }

  Future<void> dispose() async {
    detach();
  }

  /// Pure policy check exposed for tests + the demo screen. Returns the
  /// reason the sample would trigger a fallback (or null when fine).
  String? evaluate(GpsSample sample) {
    if (sample.provider != GpsProvider.gps) return null;
    if (sample.isHighQuality) return null;
    return 'accuracy ${sample.accuracyM.toStringAsFixed(0)} m '
        '> ${accuracyThresholdM.toStringAsFixed(0)} m';
  }

  void _onSample(GpsSample sample) {
    _lastEvaluated = sample;
    if (sample.provider != GpsProvider.gps) {
      // Cell / WiFi sample — never recurse.
      _restartStaleTimer();
      return;
    }
    if (sample.isHighQuality) {
      if (_wasLowQuality) _gpsRecoveries++;
      _wasLowQuality = false;
      _restartStaleTimer();
      return;
    }
    _wasLowQuality = true;
    _gpsLowQualityTriggers++;
    _restartStaleTimer();
    _requestFallback(reason: evaluate(sample) ?? 'low quality');
  }

  void _restartStaleTimer() {
    _staleTimer?.cancel();
    _staleTimer = Timer(staleWindow, () {
      _staleTriggers++;
      _requestFallback(reason: 'no fix for ${staleWindow.inSeconds}s');
    });
  }

  /// Caller-driven fallback request. Honours [minAttemptGap] unless
  /// [force] is true. Returns the sample that was injected (if any).
  Future<GpsSample?> requestFallback({bool force = false}) =>
      _requestFallback(reason: 'manual', force: force);

  Future<GpsSample?> _requestFallback({
    required String reason,
    bool force = false,
  }) async {
    final now = DateTime.now();
    if (!force &&
        _lastAttemptAt != null &&
        now.difference(_lastAttemptAt!) < minAttemptGap) {
      if (kDebugMode) {
        debugPrint('[gps-fallback] skipping ($reason) — within '
            '${minAttemptGap.inSeconds}s of last attempt');
      }
      return null;
    }
    _lastAttemptAt = now;
    final est = await _cell.estimate();
    if (est == null) return null;
    _fallbackEmissions++;
    _gps.injectSample(est);
    return est;
  }
}
