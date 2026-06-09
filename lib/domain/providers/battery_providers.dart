import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/battery_profile.dart';
import '../../data/services/battery_service.dart';

/// Day 38 — singleton [BatteryService]. Disposed with the provider scope.
final batteryServiceProvider = Provider<BatteryService>((ref) {
  final svc = BatteryService();
  ref.onDispose(svc.dispose);
  return svc;
});

/// Live broadcast of the latest [BatteryProfile]. Resolves to
/// [BatteryProfile.unknown] until the service produces a reading.
final batteryProfileStreamProvider = StreamProvider<BatteryProfile>((ref) {
  return ref.watch(batteryServiceProvider).profiles;
});

/// Sync getter for the most recent profile — useful in builders that
/// can't await an AsyncValue.
final batteryProfileProvider = Provider<BatteryProfile>((ref) {
  final stream = ref.watch(batteryProfileStreamProvider);
  return stream.maybeWhen(
    data: (p) => p,
    orElse: () => ref.read(batteryServiceProvider).latest,
  );
});
