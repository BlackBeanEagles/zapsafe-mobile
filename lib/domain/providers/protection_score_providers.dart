/// Day 59 — Protection Score providers.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/protection_score_service.dart';
import 'auth_providers.dart';

/// Singleton [ProtectionScoreService].
final protectionScoreServiceProvider = Provider<ProtectionScoreService>((ref) {
  final client = ref.watch(apiClientProvider);
  return ProtectionScoreService(client);
});

/// Current score — always recalculated by the server on fetch.
/// Invalidate after any action that might change the score:
///   `ref.invalidate(protectionScoreProvider);`
final protectionScoreProvider = FutureProvider<ProtectionScoreResult>((ref) {
  return ref.watch(protectionScoreServiceProvider).fetch();
});

/// 30-day snapshot history.
/// Invalidate alongside [protectionScoreProvider] when refreshing.
final protectionScoreHistoryProvider = FutureProvider<ScoreHistory>((ref) {
  return ref.watch(protectionScoreServiceProvider).fetchHistory(days: 30);
});
