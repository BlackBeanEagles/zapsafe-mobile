/// Day 147-158 backend — `/api/v1/account/*` DPDP providers. See
/// account_service.dart's header for the full contract + scope note.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/account_service.dart';
import 'auth_providers.dart';

/// Singleton [AccountService].
final accountServiceProvider = Provider<AccountService>((ref) {
  final client = ref.watch(apiClientProvider);
  return AccountService(client);
});

/// Current user's granular DPDP consent flags.
final userConsentProvider = FutureProvider<UserConsent>((ref) {
  return ref.watch(accountServiceProvider).fetchConsent();
});

/// Current user's active login sessions.
final userSessionsProvider = FutureProvider<List<UserSession>>((ref) {
  return ref.watch(accountServiceProvider).fetchSessions();
});

/// Current user's evidence/GPS retention preference.
final retentionPreferenceProvider = FutureProvider<RetentionPreference>((ref) {
  return ref.watch(accountServiceProvider).fetchRetention();
});
