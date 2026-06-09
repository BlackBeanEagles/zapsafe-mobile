import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/fall_event.dart';
import '../../data/models/motion_features.dart';
import '../../data/services/imu_service.dart';

/// Day 36 — singleton [ImuService]. Disposes with the provider scope.
final imuServiceProvider = Provider<ImuService>((ref) {
  final svc = ImuService();
  ref.onDispose(svc.dispose);
  return svc;
});

/// Broadcast stream of [MotionFeatures] from the IMU service. Empty
/// until [ImuService.start] is called.
final motionFeaturesStreamProvider =
    StreamProvider<MotionFeatures>((ref) {
  return ref.watch(imuServiceProvider).features;
});

/// Broadcast stream of [FallEvent]s. Empty until a fall fires.
final fallEventStreamProvider = StreamProvider<FallEvent>((ref) {
  return ref.watch(imuServiceProvider).falls;
});
