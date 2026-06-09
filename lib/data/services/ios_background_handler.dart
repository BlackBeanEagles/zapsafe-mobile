import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Day 22 — Dart-side façade for the iOS BGProcessingTask scheduler.
///
/// Mirrors `BackgroundProcessingHandler.swift` at the channel name
/// `com.zapsafe/ios_background`. Off-iOS, every call short-circuits and
/// returns a sensible default — same pattern as [BackgroundService].
class IosBackgroundHandler {
  static const String channelName = 'com.zapsafe/ios_background';

  static const String methodScheduleNext   = 'scheduleNext';
  static const String methodCancel         = 'cancel';
  static const String methodTaskIdentifier = 'taskIdentifier';
  static const String methodIsRegistered   = 'isRegistered';

  /// BGTask identifier — kept in sync with the Swift constant and the
  /// Info.plist `BGTaskSchedulerPermittedIdentifiers` entry.
  static const String taskIdentifier = 'com.zapsafe.dcs';

  /// 15 minutes is iOS's documented minimum gap between BGProcessing runs.
  static const Duration minRunGap = Duration(minutes: 15);

  final MethodChannel _channel;

  IosBackgroundHandler({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(channelName);

  /// True when the host platform has a native BGTaskScheduler — iOS only.
  bool get supported => Platform.isIOS;

  /// Asks iOS to schedule another BGProcessingTask. Returns true if the
  /// scheduler accepted the request (it may still defer execution).
  Future<bool> scheduleNext() async {
    if (!supported) return false;
    try {
      return (await _channel.invokeMethod<bool>(methodScheduleNext)) ?? false;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('[ios-bg] scheduleNext failed: ${e.code} · ${e.message}');
      }
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Cancels any pending BGProcessingTask. Idempotent.
  Future<bool> cancel() async {
    if (!supported) return true;
    try {
      return (await _channel.invokeMethod<bool>(methodCancel)) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Returns the registered BGTask identifier, e.g. "com.zapsafe.dcs", or
  /// null off-iOS.
  Future<String?> readTaskIdentifier() async {
    if (!supported) return null;
    try {
      return await _channel.invokeMethod<String>(methodTaskIdentifier);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// True if `BackgroundProcessingHandler.register` has run. Off-iOS: false.
  Future<bool> isRegistered() async {
    if (!supported) return false;
    try {
      return (await _channel.invokeMethod<bool>(methodIsRegistered)) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
