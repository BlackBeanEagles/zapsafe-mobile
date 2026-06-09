/// Day 65 — Check-in Timer providers.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/check_in_service.dart';
import 'auth_providers.dart';

/// Singleton [CheckInService].
final checkInServiceProvider = Provider<CheckInService>((ref) {
  final client = ref.watch(apiClientProvider);
  return CheckInService(client);
});

/// Check-in list — keyed by status filter string ('', 'active', 'checked_in', etc.)
final checkInListProvider =
    FutureProvider.family<List<CheckInListEntry>, String>((ref, status) {
  return ref.watch(checkInServiceProvider).fetchAll(status: status);
});
