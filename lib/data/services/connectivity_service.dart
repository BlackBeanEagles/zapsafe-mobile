import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// What kind of network the device currently has.
enum ConnectivityType {
  /// Connected over WiFi.
  wifi,

  /// Connected over cellular (2G / 3G / 4G / 5G).
  mobile,

  /// No network interface available.
  none,
}

/// Day 51 — thin wrapper around `connectivity_plus`.
///
/// Responsibilities:
///   • Probe the initial connection type on [start].
///   • Emit a new [ConnectivityType] to [stream] on every change.
///   • Keep [current] and [isOnline] up to date for synchronous reads.
///
/// This service does NOT check internet reachability (e.g. ping); it only
/// reads the OS network-interface state. A device behind a captive portal
/// reports [ConnectivityType.wifi] even though HTTP will fail — real
/// reachability probing belongs in a separate layer.
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  final StreamController<ConnectivityType> _controller =
      StreamController<ConnectivityType>.broadcast();

  // connectivity_plus v5 emits single ConnectivityResult values.
  StreamSubscription<ConnectivityResult>? _sub;

  ConnectivityType _current = ConnectivityType.none;

  /// The network type most recently observed.
  ConnectivityType get current => _current;

  /// True when any network interface (WiFi or mobile) is available.
  bool get isOnline => _current != ConnectivityType.none;

  /// Broadcast stream of connectivity changes. New listeners receive the
  /// next change, not a replay of the current state — call [start] first
  /// and read [current] for the initial value.
  Stream<ConnectivityType> get stream => _controller.stream;

  /// Probe initial state and begin watching for changes.
  Future<void> start() async {
    try {
      final initial = await _connectivity.checkConnectivity();
      _current = _fromResult(initial);
    } catch (e) {
      if (kDebugMode) debugPrint('[ConnectivityService] checkConnectivity: $e');
    }

    _sub = _connectivity.onConnectivityChanged.listen(
      (result) {
        final next = _fromResult(result);
        if (next == _current) return;
        _current = next;
        if (!_controller.isClosed) _controller.add(next);
        if (kDebugMode) {
          debugPrint('[ConnectivityService] → ${next.name}');
        }
      },
      onError: (Object e) {
        if (kDebugMode) debugPrint('[ConnectivityService] stream error: $e');
      },
    );
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _controller.close();
    _sub = null;
  }

  ConnectivityType _fromResult(ConnectivityResult result) {
    if (result == ConnectivityResult.wifi ||
        result == ConnectivityResult.ethernet) {
      return ConnectivityType.wifi;
    }
    if (result == ConnectivityResult.mobile) {
      return ConnectivityType.mobile;
    }
    return ConnectivityType.none;
  }
}
