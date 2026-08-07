/// Day 326 — real cold-start instrumentation.
///
/// A single [Stopwatch] started at the very first line of `main.dart`'s
/// `_bootstrap()`, with named marks recorded at every real bootstrap
/// milestone (`WidgetsFlutterBinding.ensureInitialized`,
/// `EasyLocalization.ensureInitialized`, `Firebase.initializeApp`,
/// `runApp`, first frame, first dashboard build). This is real
/// `Stopwatch`/timestamp instrumentation, not fabricated numbers — see
/// `day326_cold_start_report_screen.dart` for the honest caveat that this
/// sandbox has no device/emulator to actually run the app on, so the
/// report screen documents the target + instrumentation rather than
/// claiming a measured result it never ran.
library;

import 'package:flutter/foundation.dart';

@immutable
class ColdStartMark {
  final String label;
  final int elapsedMs;
  const ColdStartMark({required this.label, required this.elapsedMs});
}

class ColdStartTimings {
  ColdStartTimings._();
  static final ColdStartTimings instance = ColdStartTimings._();

  final Stopwatch _stopwatch = Stopwatch();
  final List<ColdStartMark> _marks = [];
  final Set<String> _onceMarked = {};
  bool _started = false;

  List<ColdStartMark> get marks => List.unmodifiable(_marks);

  /// Starts the stopwatch. Idempotent — a hot-restart in dev mode calling
  /// `main()` again just starts fresh; a second call within the same
  /// process (shouldn't happen) is a no-op.
  void start() {
    if (_started) return;
    _started = true;
    _stopwatch.start();
    _record('process_start');
  }

  /// Records a mark unconditionally. No-op before [start].
  void mark(String label) {
    if (!_started) return;
    _record(label);
  }

  /// Records a mark only the first time it's seen — for marks reachable
  /// from a `build()` method that reruns many times per session (e.g.
  /// first-frame / first-dashboard-build), so the table doesn't fill up
  /// with duplicate rows on every rebuild.
  void markOnce(String label) {
    if (!_started) return;
    if (_onceMarked.contains(label)) return;
    _onceMarked.add(label);
    _record(label);
  }

  void _record(String label) {
    _marks.add(ColdStartMark(label: label, elapsedMs: _stopwatch.elapsedMilliseconds));
  }

  /// ms between two marks by label, or null if either is missing (e.g.
  /// `firebase_ready` is absent when init failed and only
  /// `firebase_failed` was recorded).
  int? deltaMs(String fromLabel, String toLabel) {
    ColdStartMark? from, to;
    for (final m in _marks) {
      if (m.label == fromLabel) from = m;
      if (m.label == toLabel) to = m;
    }
    if (from == null || to == null) return null;
    return to.elapsedMs - from.elapsedMs;
  }

  /// Total elapsed ms from process_start to the given (or last) mark.
  int? totalMs([String? uptoLabel]) {
    if (_marks.isEmpty) return null;
    if (uptoLabel == null) return _marks.last.elapsedMs;
    for (final m in _marks) {
      if (m.label == uptoLabel) return m.elapsedMs;
    }
    return null;
  }

  /// Test-only reset so instrumentation tests don't leak state across
  /// `test()` blocks.
  @visibleForTesting
  void resetForTest() {
    _stopwatch
      ..reset()
      ..stop();
    _marks.clear();
    _onceMarked.clear();
    _started = false;
  }
}
