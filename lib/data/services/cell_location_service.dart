import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/gps_sample.dart';
import '../../native/platform_channels.dart';

/// Day 38 — cell-tower / WiFi location estimator.
///
/// On Android the native side queries `TelephonyManager.allCellInfo` and
/// returns a coarse lat/lng + ±accuracy (typical 500-2000 m). On iOS
/// `CTTelephonyNetworkInfo` exposes carrier info but not coordinates, so
/// the iOS implementation falls back to a WiFi-RTT / Apple-CoreLocation
/// network provider — the merged result still arrives as a [GpsSample]
/// stamped with [GpsProvider.cell] or [GpsProvider.wifi].
///
/// The native handlers don't ship in this build (real implementation
/// lands together with the Mobile-Country-Code lookup tables in Month 4).
/// Until then [estimate] returns null on real devices and the
/// [@visibleForTesting] [injectEstimate] hook lets the screen + tests
/// drive the fallback coordinator deterministically.
class CellLocationService {
  /// LP12 — accuracy threshold below which a cell sample is "useful".
  /// We don't pretend to be high-quality (≤ 50 m) but a 500 m fix is
  /// vastly better than no fix at all when GPS has dropped out indoors.
  static const double minUsefulAccuracyM = 2000;

  final MethodChannel _channel;
  CellLocationService({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(PlatformChannelNames.cell);

  GpsSample? _stubbed;

  /// Most-recent cell/WiFi estimate returned by [estimate]. Null until
  /// at least one call has succeeded.
  GpsSample? _lastEstimate;
  GpsSample? get lastEstimate => _lastEstimate;

  int _attempts = 0;
  int _successes = 0;
  int _failures = 0;
  int get attempts => _attempts;
  int get successes => _successes;
  int get failures => _failures;

  /// Ask the native side for a coarse estimate. Returns null when:
  ///   • the platform handler isn't registered (host VM, today's build)
  ///   • the device has no cellular registration and no known WiFi APs
  ///   • the result is somehow worse than [minUsefulAccuracyM]
  Future<GpsSample?> estimate() async {
    _attempts++;
    if (_stubbed != null) {
      _lastEstimate = _stubbed;
      _successes++;
      return _stubbed;
    }
    try {
      final raw = await _channel.invokeMethod<Map>('estimate');
      if (raw == null) {
        _failures++;
        return null;
      }
      final map = Map<String, dynamic>.from(raw);
      // Force a provider tag — the native side may forget.
      map.putIfAbsent('prov', () => GpsProvider.cell.wire);
      final sample = GpsSample.fromMap(map);
      if (sample.accuracyM <= 0 || sample.accuracyM > minUsefulAccuracyM) {
        _failures++;
        return null;
      }
      _lastEstimate = sample;
      _successes++;
      return sample;
    } on MissingPluginException {
      _failures++;
      if (kDebugMode) {
        debugPrint('[cell] native handler missing — falling back to null');
      }
      return null;
    } on PlatformException catch (e) {
      _failures++;
      if (kDebugMode) debugPrint('[cell] estimate failed: ${e.code}');
      return null;
    }
  }

  /// Build a deterministic synthetic estimate near [centreLat], [centreLng].
  /// Used by the Day 38 screen + unit tests so the fallback coordinator
  /// has something to merge in even without a Telephony stack.
  GpsSample syntheticEstimate({
    double centreLat = 12.9716,
    double centreLng = 77.5946,
    double radiusM = 800,
    GpsProvider provider = GpsProvider.cell,
    int? timestampMs,
    int seed = 0,
  }) {
    // 1° ≈ 111 km — convert metres → degrees.
    final rng = math.Random(seed == 0
        ? (timestampMs ?? DateTime.now().millisecondsSinceEpoch) & 0xFFFFFFFF
        : seed);
    final degreeOffset = radiusM / 111000;
    final dx = (rng.nextDouble() * 2 - 1) * degreeOffset;
    final dy = (rng.nextDouble() * 2 - 1) * degreeOffset;
    return GpsSample(
      timestampMs: timestampMs ?? DateTime.now().millisecondsSinceEpoch,
      lat: centreLat + dy,
      lng: centreLng + dx,
      accuracyM: radiusM,
      provider: provider,
    );
  }

  /// Force the next call to [estimate] to return [sample]. Resetting
  /// with `null` restores real-channel behaviour. The Day 38 screen
  /// uses this to demo the fallback path without a tower in sight.
  @visibleForTesting
  void stubNext(GpsSample? sample) {
    _stubbed = sample;
  }

  @visibleForTesting
  void resetCounters() {
    _attempts = 0;
    _successes = 0;
    _failures = 0;
  }
}
