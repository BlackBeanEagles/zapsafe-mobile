import 'dart:collection';

/// Collects a raw 6-channel IMU stream into 128-sample windows.
///
/// Day 336 — extracted from `motion_detector_b.dart` when
/// `m2_motion_b_retrain` was deleted. The model was removed because it
/// returned **exactly 0.0 for every input** across 15 probes spanning six
/// orders of input magnitude (see
/// `assets/models/DAY330_VEHICLE_CRASH_COLLAPSED_AT_SOURCE.md`), but this
/// buffer is ordinary windowing logic with no dependency on it, and
/// `KConfinementFusionPipeline` and `VehicleCrashFusionPipeline` both still
/// use it.
///
/// Kept as a distinct class from `MotionWindowBuffer` in
/// `motion_detector_v2.dart` — same shape, but sized for 128 samples rather
/// than that model's 100, so the two window sizes can never be silently
/// mixed up at a call site.
class MotionWindowBufferB {
  /// Samples per emitted window.
  static const int kWindow = 128;

  /// Channels per sample: acc xyz + gyro xyz.
  static const int kChannels = 6;

  final int hop;

  final Queue<List<double>> _buf = Queue<List<double>>();
  int _sinceEmit = 0;

  MotionWindowBufferB({this.hop = 32});

  int get buffered => _buf.length;

  bool get isWarm => _buf.length >= kWindow;

  List<List<double>>? add(List<double> sample) {
    if (sample.length != kChannels) {
      throw ArgumentError(
        'expected $kChannels channels, got ${sample.length}',
      );
    }
    _buf.addLast(List<double>.unmodifiable(sample));
    while (_buf.length > kWindow) {
      _buf.removeFirst();
    }
    _sinceEmit++;
    if (_buf.length == kWindow && _sinceEmit >= hop) {
      _sinceEmit = 0;
      return _buf.toList(growable: false);
    }
    return null;
  }

  void clear() {
    _buf.clear();
    _sinceEmit = 0;
  }
}
