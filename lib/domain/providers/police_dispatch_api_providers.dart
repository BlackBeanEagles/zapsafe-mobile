/// Day 356 — Police dispatch status API providers.
///
/// Wires the real, live backend police dispatch endpoint (Day 204) into a
/// Riverpod family provider keyed by sos_id. Unlike Days 302/354/355 this
/// endpoint has no meaningful "seed a mock and fall back on error" shape
/// (the backend itself already falls back to a deterministic simulated
/// timeline server-side, flagged `is_mock: true` — see
/// `police_dispatch_api_service.dart`), so there is no separate mock
/// provider here, only the raw call.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/police_dispatch_api_service.dart';
import 'auth_providers.dart';

final policeDispatchApiServiceProvider = Provider<PoliceDispatchApiService>((ref) {
  return PoliceDispatchApiService(ref.watch(apiClientProvider));
});

/// GET /api/v1/police/dispatch/{sos_id}/ for the given SOS id. No offline
/// mock fallback — a failure (404 SOS_NOT_FOUND, network, 401) is shown to
/// the user as-is so a wrong/foreign sos_id is visibly wrong, not silently
/// replaced with fake data.
final policeDispatchStatusProvider =
    FutureProvider.family<PoliceDispatchStatus, String>((ref, sosId) {
  return ref.watch(policeDispatchApiServiceProvider).fetchDispatchStatus(sosId);
});
