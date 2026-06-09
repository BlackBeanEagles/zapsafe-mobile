/// Day 61 — Inference Log providers.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/inference_log_service.dart';
import 'auth_providers.dart';

/// Singleton [InferenceLogService].
final inferenceLogServiceProvider = Provider<InferenceLogService>((ref) {
  final client = ref.watch(apiClientProvider);
  return InferenceLogService(client);
});

/// Recent inference log entries — 7-day default window.
/// Keyed by (days, modelType) so different filter combos don't share cache.
final inferenceLogHistoryProvider = FutureProvider.family<
    InferenceLogHistory, ({int days, String modelType})>((ref, args) {
  return ref.watch(inferenceLogServiceProvider).fetchHistory(
        days:      args.days,
        modelType: args.modelType,
      );
});

/// Latency stats — keyed by (days, modelType).
final inferenceLogStatsProvider = FutureProvider.family<
    InferenceLogStats, ({int days, String modelType})>((ref, args) {
  return ref.watch(inferenceLogServiceProvider).fetchStats(
        days:      args.days,
        modelType: args.modelType,
      );
});
