import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/cell_location_service.dart';
import '../../data/services/gps_fallback_coordinator.dart';
import 'gps_providers.dart';

/// Day 38 — singleton [CellLocationService] for the Day 38 screen + the
/// fallback coordinator. The native handler is a stub today; the
/// service degrades to "no estimate" off-platform.
final cellLocationServiceProvider = Provider<CellLocationService>((_) {
  return CellLocationService();
});

/// Day 38 — singleton [GpsFallbackCoordinator]. Attaches itself to the
/// GPS sample stream on first watch via [gpsFallbackBootstrapProvider].
final gpsFallbackCoordinatorProvider =
    Provider<GpsFallbackCoordinator>((ref) {
  final coord = GpsFallbackCoordinator(
    gps:  ref.read(gpsServiceProvider),
    cell: ref.read(cellLocationServiceProvider),
  );
  ref.onDispose(coord.dispose);
  return coord;
});

/// Eager-attach helper. Watching this provider from a screen
/// (`ref.watch(gpsFallbackBootstrapProvider)`) calls `attach()` once and
/// keeps the coordinator alive as long as the screen is mounted.
final gpsFallbackBootstrapProvider = Provider<GpsFallbackCoordinator>((ref) {
  final coord = ref.watch(gpsFallbackCoordinatorProvider);
  coord.attach();
  return coord;
});
