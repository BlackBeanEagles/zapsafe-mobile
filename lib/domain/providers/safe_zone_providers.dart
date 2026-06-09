/// Day 58 — Safe Zone providers.
///
/// [safeZoneServiceProvider]   — singleton service (auth client).
/// [safeZoneListProvider]      — FutureProvider for the full zone list.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/safe_zone_service.dart';
import 'auth_providers.dart';

/// Singleton [SafeZoneService] — rides on [apiClientProvider].
final safeZoneServiceProvider = Provider<SafeZoneService>((ref) {
  final client = ref.watch(apiClientProvider);
  return SafeZoneService(client);
});

/// Fetches the authenticated user's full zone list (unfiltered).
///
/// Invalidate after any mutating operation (create / patch / delete):
///   `ref.invalidate(safeZoneListProvider);`
final safeZoneListProvider = FutureProvider<SafeZoneList>((ref) {
  return ref.watch(safeZoneServiceProvider).fetchAll();
});
