import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/app_state.dart';
import '../models/gps_sample.dart';
import 'api_client.dart';
import 'gps_polling_profile.dart';
import 'gps_storage.dart';

/// Day 37 — adaptive-cadence GPS service.
///
/// Polls `geolocator` on a timer whose interval comes from the current
/// [GpsPollingProfile]. Each fix is persisted to [GpsStorage] (survives
/// app kill) and pushed onto the [samples] broadcast stream. A small
/// in-memory buffer accumulates samples for batch upload to
/// `POST /api/v1/gps/batch/` — the route lands in backend Week 4+, so
/// today's calls 404 gracefully without crashing the polling loop.
///
/// The service starts in [AppState.monitoring]. Callers change cadence
/// by calling [setAppState] when their state machine transitions.
class GpsService {
  static const String _backendPath = '/api/v1/gps/batch/';

  /// Buffer fills at the polling cadence and flushes at this size or
  /// on explicit [flushBatch].
  static const int _batchFlushThreshold = 6;

  final GpsStorage _storage;
  final ApiClient? _api;

  GpsService({GpsStorage? storage, ApiClient? api})
      : _storage = storage ?? GpsStorage(),
        _api = api;

  Timer? _timer;
  AppState _appState = AppState.monitoring;
  GpsPollingProfile _profile = GpsPollingProfile.monitoring;

  AppState get appState => _appState;
  GpsPollingProfile get profile => _profile;
  Duration get currentInterval => _profile.interval;

  GpsSample? _latest;
  GpsSample? get latest => _latest;

  final List<GpsSample> _batch = [];
  int get pendingBatchSize => _batch.length;

  int _fixesAttempted = 0;
  int _fixesSucceeded = 0;
  int _fixesFailed = 0;
  int get fixesAttempted => _fixesAttempted;
  int get fixesSucceeded => _fixesSucceeded;
  int get fixesFailed => _fixesFailed;

  final _samplesController = StreamController<GpsSample>.broadcast();
  Stream<GpsSample> get samples => _samplesController.stream;

  bool _running = false;
  bool get isRunning => _running;

  // ─── Lifecycle ─────────────────────────────────────────────────────────

  /// Start polling. Idempotent — calling while running just refreshes
  /// the timer at the current profile's cadence.
  Future<void> start() async {
    _running = true;
    // Hydrate latest from disk so UIs that read the getter see something
    // before the first live fix lands.
    _latest ??= await _storage.read();
    _restartTimer();
  }

  /// Stop polling. Buffered batch stays around so callers can flush on
  /// re-start.
  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
  }

  /// Permanently release resources.
  Future<void> dispose() async {
    stop();
    await _samplesController.close();
  }

  /// Caller-driven state machine signal. Cadence + accuracy update
  /// immediately on transition.
  void setAppState(AppState state) {
    _appState = state;
    final next = GpsPollingProfile.fromAppState(state);
    if (next == _profile) return;
    _profile = next;
    if (_running) _restartTimer();
  }

  /// Force one immediate poll outside the timer cadence. Useful for
  /// "show me where I am right now" buttons.
  Future<GpsSample?> pollOnce() async => _poll();

  /// Push the current batch buffer to the backend. Returns true on a
  /// successful POST; false on any failure (the most common today —
  /// the route 404s until backend Week 4+).
  Future<bool> flushBatch() async {
    if (_batch.isEmpty || _api == null) return false;
    final snapshot = List<Map<String, dynamic>>.from(
      _batch.map((s) => s.toMap()),
    );
    try {
      await _api.dio.post(_backendPath, data: {'samples': snapshot});
      _batch.clear();
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[gps] batch flush failed: $e');
      return false;
    }
  }

  // ─── Internals ──────────────────────────────────────────────────────────

  void _restartTimer() {
    _timer?.cancel();
    if (_profile == GpsPollingProfile.off) return;
    // Fire one fix immediately so callers don't have to wait for the
    // first interval — particularly important when promoting to
    // elevated / sos-time.
    _poll();
    _timer = Timer.periodic(_profile.interval, (_) => _poll());
  }

  Future<GpsSample?> _poll() async {
    _fixesAttempted++;
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: _profile.accuracy,
        timeLimit: const Duration(seconds: 15),
      );
      final sample = GpsSample(
        timestampMs: pos.timestamp.millisecondsSinceEpoch,
        lat: pos.latitude,
        lng: pos.longitude,
        accuracyM: pos.accuracy,
        altitudeM: pos.altitude.isFinite ? pos.altitude : null,
        speedMps: pos.speed.isFinite ? pos.speed : null,
        headingDeg: pos.heading.isFinite ? pos.heading : null,
      );
      _onFix(sample);
      _fixesSucceeded++;
      return sample;
    } catch (e) {
      _fixesFailed++;
      if (kDebugMode) debugPrint('[gps] poll failed: $e');
      return null;
    }
  }

  void _onFix(GpsSample sample) {
    _latest = sample;
    _storage.save(sample);
    if (!_samplesController.isClosed) {
      _samplesController.add(sample);
    }
    _batch.add(sample);
    if (_batch.length >= _batchFlushThreshold) {
      // Fire and forget — don't block the polling loop on a backend
      // call that might 404.
      flushBatch();
    }
  }

  /// Day 37 — directly inject a synthetic sample. Used by the screen
  /// and tests when the host VM has no real GPS.
  @visibleForTesting
  void injectSample(GpsSample sample) {
    _onFix(sample);
  }

  /// Day 37 — explicit reset of the in-memory buffer (without
  /// uploading). Tests use this to verify size tracking.
  @visibleForTesting
  void clearBatch() => _batch.clear();
}
