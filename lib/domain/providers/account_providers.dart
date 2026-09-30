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

/// Who has received this user's personal data — real emergency contacts
/// + 3 fixed platform-level disclosures (DPDP §11(1)(b)).
/// Day 366 — which policy version this user accepted, and whether the server
/// now requires a newer one.
///
/// `autoDispose` is deliberately NOT used: the answer gates whether the app may
/// show a re-consent banner, and re-fetching it on every screen rebuild would
/// put a network call behind a banner.
final policyAcceptanceProvider =
    FutureProvider<PolicyAcceptanceStatus>((ref) {
  return ref.watch(accountServiceProvider).fetchPolicyAcceptance();
});

final thirdPartyAccessProvider = FutureProvider<List<ThirdPartyEntry>>((ref) {
  return ref.watch(accountServiceProvider).fetchThirdPartyAccess();
});

/// Day 366 — session lifetime and security-alert preferences.
///
/// Separate providers because the Day 180 screen saves them independently, and
/// the server keeps them on separate routes for the same reason: changing an
/// alert threshold must not rewrite session expiry.
final sessionConfigProvider = FutureProvider<SessionConfig>((ref) {
  return ref.watch(accountServiceProvider).fetchSessionConfig();
});

final securityAlertsProvider = FutureProvider<SecurityAlerts>((ref) {
  return ref.watch(accountServiceProvider).fetchSecurityAlerts();
});
