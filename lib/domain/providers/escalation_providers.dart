/// Day 64 — Escalation Policy providers.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/escalation_service.dart';
import 'auth_providers.dart';

/// Singleton [EscalationService].
final escalationServiceProvider = Provider<EscalationService>((ref) {
  final client = ref.watch(apiClientProvider);
  return EscalationService(client);
});

/// Full policy list — ordered default-first per backend Meta ordering.
final escalationPolicyListProvider =
    FutureProvider<List<EscalationPolicy>>((ref) {
  return ref.watch(escalationServiceProvider).fetchAll();
});
