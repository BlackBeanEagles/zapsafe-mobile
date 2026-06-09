import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/connectivity_service.dart';

/// Day 51 — singleton [ConnectivityService].
///
/// Started eagerly so [current] is populated before any UI reads it.
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final svc = ConnectivityService();
  unawaited(svc.start());
  ref.onDispose(svc.dispose);
  return svc;
});

/// Current [ConnectivityType] as a stream. UI watches this to react to
/// online ↔ offline transitions.
///
/// Seeded with the service's current value so widgets get an immediate
/// value instead of waiting for the first change.
final connectivityTypeProvider = StreamProvider<ConnectivityType>((ref) async* {
  final svc = ref.watch(connectivityServiceProvider);
  // Seed with current value so watchers never start in loading state.
  yield svc.current;
  yield* svc.stream;
});

/// Convenience bool — true when any network is available.
final isOnlineProvider = Provider<bool>((ref) {
  final type = ref.watch(connectivityTypeProvider);
  return type.valueOrNull != ConnectivityType.none;
});
