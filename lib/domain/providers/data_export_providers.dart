/// Day 69 — Data Export providers.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/data_export_service.dart';
import 'auth_providers.dart';

/// Singleton [DataExportService].
final dataExportServiceProvider = Provider<DataExportService>((ref) {
  final client = ref.watch(apiClientProvider);
  return DataExportService(client);
});

/// List of the authenticated user's past export requests.
final dataExportListProvider =
    FutureProvider<List<DataExportRequest>>((ref) {
  return ref.watch(dataExportServiceProvider).fetchList();
});
