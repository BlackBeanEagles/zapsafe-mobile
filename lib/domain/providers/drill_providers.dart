/// Day 60 — Drill Mode providers.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/drill_service.dart';
import 'auth_providers.dart';

/// Singleton [DrillService].
final drillServiceProvider = Provider<DrillService>((ref) {
  final client = ref.watch(apiClientProvider);
  return DrillService(client);
});

/// 90-day drill history.
/// Invalidate after a drill completes:
///   `ref.invalidate(drillHistoryProvider);`
final drillHistoryProvider = FutureProvider<DrillHistory>((ref) {
  return ref.watch(drillServiceProvider).fetchHistory(days: 90);
});
