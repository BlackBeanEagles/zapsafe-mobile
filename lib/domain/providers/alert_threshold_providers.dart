/// Day 63 — Alert Threshold providers.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/alert_threshold_service.dart';
import 'auth_providers.dart';

/// Singleton [AlertThresholdService].
final alertThresholdServiceProvider = Provider<AlertThresholdService>((ref) {
  final client = ref.watch(apiClientProvider);
  return AlertThresholdService(client);
});

/// Full threshold list — keyed by isActive filter string ('', 'true', 'false').
final alertThresholdListProvider =
    FutureProvider.family<List<AlertThreshold>, String>((ref, isActive) {
  return ref
      .watch(alertThresholdServiceProvider)
      .fetchAll(isActive: isActive);
});
