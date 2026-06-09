/// Day 56 — Model Download providers.
///
/// [modelDownloadServiceProvider]   — singleton service (auth client).
/// [modelDownloadHistoryProvider]   — FutureProvider for full GET history.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/model_download_service.dart';
import 'auth_providers.dart';

/// Singleton [ModelDownloadService] — rides on [apiClientProvider].
final modelDownloadServiceProvider =
    Provider<ModelDownloadService>((ref) {
  final client = ref.watch(apiClientProvider);
  return ModelDownloadService(client);
});

/// Fetches ALL of the current user's download records (unfiltered).
///
/// The screen applies client-side type/verified filtering so we avoid
/// creating multiple parallel providers.  Invalidate after a successful POST:
///   `ref.invalidate(modelDownloadHistoryProvider);`
final modelDownloadHistoryProvider =
    FutureProvider<ModelDownloadHistory>((ref) {
  return ref.watch(modelDownloadServiceProvider).fetchHistory();
});
