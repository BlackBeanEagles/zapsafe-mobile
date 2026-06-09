/// Day 67 — Notification Category Preference providers.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/notification_pref_service.dart';
import 'auth_providers.dart';

/// Singleton [NotificationPrefService].
final notificationPrefServiceProvider = Provider<NotificationPrefService>((ref) {
  final client = ref.watch(apiClientProvider);
  return NotificationPrefService(client);
});

/// All 5 category prefs — server auto-seeds on first GET.
final notificationPrefListProvider =
    FutureProvider<List<NotificationCategoryPref>>((ref) {
  return ref.watch(notificationPrefServiceProvider).fetchAll();
});
