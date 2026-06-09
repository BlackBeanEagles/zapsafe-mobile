/// Day 62 — Incident Report providers.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/incident_service.dart';
import 'auth_providers.dart';

/// Singleton [IncidentService].
final incidentServiceProvider = Provider<IncidentService>((ref) {
  final client = ref.watch(apiClientProvider);
  return IncidentService(client);
});

/// Incident history — keyed by (days, status) so filters don't share cache.
final incidentHistoryProvider = FutureProvider.family<
    IncidentHistory, ({int days, String status})>((ref, args) {
  return ref.watch(incidentServiceProvider).fetchHistory(
        days:   args.days,
        status: args.status,
      );
});
