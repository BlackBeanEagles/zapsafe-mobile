/// Day 54 — Capability Report providers.
///
/// [capabilityReportServiceProvider] — singleton service (rides on auth client).
/// [capabilityReportHistoryProvider] — FutureProvider for GET history.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/capability_report_service.dart';
import 'auth_providers.dart';

/// Singleton [CapabilityReportService].
///
/// Rides on [apiClientProvider] so every request carries the JWT.
final capabilityReportServiceProvider =
    Provider<CapabilityReportService>((ref) {
  final client = ref.watch(apiClientProvider);
  return CapabilityReportService(client);
});

/// Fetches the current user's submitted capability reports (newest first).
///
/// After a successful POST, invalidate this to refresh the list:
///   `ref.invalidate(capabilityReportHistoryProvider);`
final capabilityReportHistoryProvider =
    FutureProvider<CapabilityReportHistory>((ref) {
  return ref.watch(capabilityReportServiceProvider).fetchHistory();
});
