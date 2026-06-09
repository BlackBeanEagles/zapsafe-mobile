import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';

import '../models/battery_profile.dart';

/// Day 38 — battery threshold handler.
///
/// Wraps `battery_plus` and translates the raw `(level, state)` pair into
/// a [BatteryProfile]. Three breakpoints map to three [BatteryTier]s:
///
/// | Tier            | Battery     | What turns off                          |
/// |-----------------|-------------|------------------------------------------|
/// | normal          | > 20 % or charging | nothing                          |
/// | powerSaver      | ≤ 20 %      | camera + mode-A evidence → mode B       |
/// | proactiveDrop   | ≤ 15 %      | proactive mode drops one level          |
/// | vadOnly         | ≤ 10 %      | every sensor except mic VAD             |
///
/// On the host VM `battery_plus` throws a `MissingPluginException` —
/// the service catches and stays in [BatteryTier.normal] so tests run
/// deterministically. The Day 38 screen has an inject path for tier
/// preview.
class BatteryService {
  final Battery _battery;
  Timer? _pollTimer;
  StreamSubscription<BatteryState>? _stateSub;
  bool _started = false;

  BatteryService({Battery? battery}) : _battery = battery ?? Battery();

  final _profileController = StreamController<BatteryProfile>.broadcast();

  /// Broadcast stream of profile changes. Emits on `start()`, on every
  /// `battery_plus` state change, and on the internal 60 s safety poll.
  Stream<BatteryProfile> get profiles => _profileController.stream;

  BatteryProfile _latest = BatteryProfile.unknown;
  BatteryProfile get latest => _latest;

  bool get isStarted => _started;

  /// How often the service forces a fresh read in addition to listening
  /// to `onBatteryStateChanged`. Some Android OEMs don't emit a state
  /// change for fractional drops (% only), so the timer ensures the
  /// tier flips promptly when the user crosses a threshold.
  static const Duration safetyPollInterval = Duration(seconds: 60);

  /// Begin tracking. Idempotent. Emits an initial reading on first call.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    await refresh();
    _stateSub = _battery.onBatteryStateChanged.listen(
      (_) => unawaited(refresh()),
      onError: (Object e) {
        if (kDebugMode) debugPrint('[battery] state stream error: $e');
      },
    );
    _pollTimer = Timer.periodic(safetyPollInterval, (_) => unawaited(refresh()));
  }

  /// Stop tracking. Latest profile is preserved.
  Future<void> stop() async {
    _started = false;
    await _stateSub?.cancel();
    _stateSub = null;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> dispose() async {
    await stop();
    await _profileController.close();
  }

  /// Force a fresh read. Errors out silently — the [latest] getter keeps
  /// its previous value so subscribers don't see a flicker. Catches
  /// Object (rather than Exception) so platform-level failures
  /// (MissingPluginException · upower not running on Windows · iOS
  /// simulator) never crash the polling loop.
  Future<BatteryProfile> refresh() async {
    try {
      final level = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      final isCharging = state == BatteryState.charging ||
          state == BatteryState.full;
      final next = BatteryProfile.fromLevel(level, isCharging: isCharging);
      _emit(next);
      return next;
    } catch (e) {
      if (kDebugMode) debugPrint('[battery] refresh failed: $e');
      return _latest;
    }
  }

  void _emit(BatteryProfile next) {
    if (_latest == next) return;
    _latest = next;
    if (!_profileController.isClosed) _profileController.add(next);
  }

  /// Day 38 — drive the service from a synthetic level. Used by the
  /// screen + unit tests to walk through the tier table.
  @visibleForTesting
  void injectLevel(int level, {bool isCharging = false}) {
    _emit(BatteryProfile.fromLevel(level, isCharging: isCharging));
  }
}
