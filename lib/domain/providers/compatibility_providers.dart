import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/compatibility_service.dart';

/// Day 53 — singleton [CompatibilityService].
final compatibilityServiceProvider =
    Provider<CompatibilityService>((_) => CompatibilityService());

/// Fetches the full device compatibility matrix from the backend.
///
/// The endpoint is public so no auth token is attached. The result is
/// cached by Riverpod for the lifetime of the provider; call
/// [ref.invalidate(compatibilityMatrixProvider)] to force a re-fetch.
final compatibilityMatrixProvider =
    FutureProvider<CompatibilityMatrixResult>((ref) {
  return ref.watch(compatibilityServiceProvider).fetch();
});
