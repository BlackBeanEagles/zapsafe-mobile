/// Day 55 — Detection Event providers.
///
/// [detectionEventServiceProvider]   — singleton service (auth client).
/// [detectionEventHistoryProvider]   — FutureProvider for full GET history.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/detection_event_service.dart';
import 'auth_providers.dart';

/// Singleton [DetectionEventService] — rides on [apiClientProvider].
final detectionEventServiceProvider =
    Provider<DetectionEventService>((ref) {
  final client = ref.watch(apiClientProvider);
  return DetectionEventService(client);
});

/// Fetches ALL of the current user's detection events (unfiltered).
///
/// The screen applies client-side type filtering so we avoid creating
/// multiple parallel providers.  Invalidate after a successful POST:
///   `ref.invalidate(detectionEventHistoryProvider);`
final detectionEventHistoryProvider =
    FutureProvider<DetectionEventHistory>((ref) {
  return ref.watch(detectionEventServiceProvider).fetchHistory();
});
