/// Day 66 — SOS Message Template providers.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/sos_template_service.dart';
import 'auth_providers.dart';

/// Singleton [SosTemplateService].
final sosTemplateServiceProvider = Provider<SosTemplateService>((ref) {
  final client = ref.watch(apiClientProvider);
  return SosTemplateService(client);
});

/// Full template list — ordered default-first per backend Meta ordering.
final sosTemplateListProvider = FutureProvider<List<SosTemplate>>((ref) {
  return ref.watch(sosTemplateServiceProvider).fetchAll();
});
