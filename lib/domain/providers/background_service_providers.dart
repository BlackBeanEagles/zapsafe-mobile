import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/background_service.dart';
import '../../data/services/ios_background_handler.dart';

/// Singleton wrapper around the native foreground-service channel.
final backgroundServiceProvider =
    Provider<BackgroundService>((_) => BackgroundService());

/// Snapshot of the service's current running state. Polled by the Day 21
/// screen — refresh to re-query the native side.
final backgroundServiceRunningProvider =
    FutureProvider<bool>((ref) async {
  return ref.read(backgroundServiceProvider).refresh();
});

/// Day 22 — iOS BGProcessingTask handler façade.
final iosBackgroundHandlerProvider =
    Provider<IosBackgroundHandler>((_) => IosBackgroundHandler());

/// True when the iOS BGTask handler has been registered by AppDelegate.
/// Off-iOS this resolves to false.
final iosBackgroundRegisteredProvider = FutureProvider<bool>((ref) async {
  return ref.read(iosBackgroundHandlerProvider).isRegistered();
});
