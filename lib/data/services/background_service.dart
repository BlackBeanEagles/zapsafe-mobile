import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Day 21 — Dart-side façade over the native Android foreground service.
///
/// Talks to `ZapSafeService.kt` via a [MethodChannel] named
/// `com.zapsafe/background_service`. The native side is what actually keeps
/// the safety engine alive — this class just brokers start/stop requests
/// and surfaces the running state.
///
/// On platforms without a native counterpart (iOS pre-Day-22, web, desktop),
/// every call returns gracefully: `start()` answers `false`, `stop()`
/// answers `true`, `isRunning()` answers `false`. Callers get a consistent
/// API regardless of the host platform.
class BackgroundService {
  static const String channelName = 'com.zapsafe/background_service';

  /// Method names exchanged with the native side. Mirrored in `MainActivity.kt`.
  static const String methodStart     = 'start';
  static const String methodStop      = 'stop';
  static const String methodIsRunning = 'isRunning';

  final MethodChannel _channel;

  /// Last known running state — refreshed by [refresh] and after each
  /// [start] / [stop]. Stored locally so UIs can render without an extra
  /// awaitable round-trip.
  bool _running = false;
  bool get isRunning => _running;

  BackgroundService({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(channelName);

  /// Returns true when the host platform currently has a native background
  /// service implementation. Today: Android only.
  bool get supported => Platform.isAndroid;

  /// Asks the platform to start the foreground service.
  /// Returns true if the native side acknowledged the start.
  Future<bool> start() async {
    if (!supported) return false;
    try {
      final ok = await _channel.invokeMethod<bool>(methodStart) ?? false;
      _running = ok;
      return ok;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('[bg] start failed: ${e.code} · ${e.message}');
      }
      _running = false;
      return false;
    } on MissingPluginException {
      _running = false;
      return false;
    }
  }

  /// Asks the platform to stop the foreground service. Idempotent.
  Future<bool> stop() async {
    if (!supported) {
      _running = false;
      return true;
    }
    try {
      await _channel.invokeMethod<bool>(methodStop);
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('[bg] stop failed: ${e.code} · ${e.message}');
      }
    } on MissingPluginException {
      // No-op: nothing to stop.
    }
    _running = false;
    return true;
  }

  /// Asks the platform whether the service is currently running. On unsupported
  /// platforms returns false. Caches the result in [isRunning].
  Future<bool> refresh() async {
    if (!supported) {
      _running = false;
      return false;
    }
    try {
      final running =
          await _channel.invokeMethod<bool>(methodIsRunning) ?? false;
      _running = running;
      return running;
    } on PlatformException catch (_) {
      return _running;
    } on MissingPluginException {
      return _running;
    }
  }
}
