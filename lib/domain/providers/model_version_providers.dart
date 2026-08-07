/// Day 325 — Model Version Check providers.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/model_version_service.dart';
import 'auth_providers.dart';

final modelVersionServiceProvider = Provider<ModelVersionService>((ref) {
  final client = ref.watch(apiClientProvider);
  return ModelVersionService(client);
});

/// One-shot check — call `ref.refresh(modelVersionCheckProvider)` to re-run.
final modelVersionCheckProvider =
    FutureProvider<ModelVersionCheckResponse>((ref) {
  return ref.watch(modelVersionServiceProvider).checkAll();
});
