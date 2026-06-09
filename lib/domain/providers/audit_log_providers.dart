/// Day 68 — User Activity Audit Log providers.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/audit_log_service.dart';
import 'auth_providers.dart';

/// Singleton [AuditLogService].
final auditLogServiceProvider = Provider<AuditLogService>((ref) {
  final client = ref.watch(apiClientProvider);
  return AuditLogService(client);
});

/// Summary (total count + last-30-day breakdown).
final auditLogSummaryProvider = FutureProvider<AuditLogSummary>((ref) {
  return ref.watch(auditLogServiceProvider).fetchSummary();
});

/// Paged list — family key is (event_type_slug, limit).
/// Empty slug = all events.  limit grows with each "Load More" tap.
final auditLogListProvider =
    FutureProvider.family<AuditLogPage, (String, int)>((ref, params) {
  final (eventType, limit) = params;
  return ref.watch(auditLogServiceProvider).fetchList(
        eventType: eventType.isEmpty ? null : eventType,
        limit: limit,
      );
});
