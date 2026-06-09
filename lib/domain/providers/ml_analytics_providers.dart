/// Day 57 — ML Analytics providers.
///
/// [mlAnalyticsServiceProvider]          — singleton service (auth client).
/// [mlAnalyticsProvider]                 — FutureProvider.family<int> keyed by
///                                         period in days (default 30).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/ml_analytics_service.dart';
import 'auth_providers.dart';

/// Singleton [MLAnalyticsService] — rides on [apiClientProvider].
final mlAnalyticsServiceProvider =
    Provider<MLAnalyticsService>((ref) {
  final client = ref.watch(apiClientProvider);
  return MLAnalyticsService(client);
});

/// Fetches ML analytics for a given lookback [days] window.
///
/// Use `.family` so switching the period (7 / 30 / 90) triggers a fresh fetch
/// without sharing stale data across different windows.
///
/// Usage:
///   ref.watch(mlAnalyticsProvider(30))   // last 30 days
///   ref.watch(mlAnalyticsProvider(7))    // last 7 days
final mlAnalyticsProvider =
    FutureProvider.family<MLAnalyticsResult, int>((ref, days) {
  return ref.watch(mlAnalyticsServiceProvider).fetch(days: days);
});
