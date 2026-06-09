/// Day 70 — Privacy & Consent providers.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/privacy_service.dart';
import 'auth_providers.dart';

/// Singleton [PrivacyService].
final privacyServiceProvider = Provider<PrivacyService>((ref) {
  final client = ref.watch(apiClientProvider);
  return PrivacyService(client);
});

/// Current user's privacy settings (3 flags).
final privacySettingsProvider = FutureProvider<PrivacySettings>((ref) {
  return ref.watch(privacyServiceProvider).fetchSettings();
});

/// Active deletion request — null means none exists.
final deletionRequestProvider = FutureProvider<DeletionRequest?>((ref) {
  return ref.watch(privacyServiceProvider).fetchDeletion();
});
