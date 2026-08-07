/// Day 325 — Model Version Check service.
///
/// 🔵 EXISTING-API. `POST /api/v1/models/get-version/` is real and already
/// live on the backend (`zapsafe_backend/ml/urls_models.py` →
/// `ModelVersionCheckView`, Day 71) — verified by reading the view source
/// directly. It had never been wired into the Flutter app before this day
/// (no `modelsGetVersion` constant, no service, no screen referenced it).
///
/// Backend `ModelType` only has 4 values: `scream`, `motion`, `scene`,
/// `dcs` (`zapsafe_backend/ml/models.py`). That lines up with
/// `kZapsafeModels[0..3]` (the core DCS fusion slots) — but the *key*
/// differs for the fusion slot: the local catalogue calls it `fusion`,
/// the backend calls it `dcs`. [_kLocalToBackendType] makes that mapping
/// explicit rather than assuming a 1:1 string match. The 5th catalogue
/// entry (`aggressive_speech`) has no backend `ModelType` counterpart at
/// all, so it is not sent.
///
/// This repo's models don't carry a semantic-version field — they're
/// versioned by asset filename suffix (e.g. `scream_classifier_v1.tflite`
/// → `v1`, see `model_registry.dart`). [ModelVersionService.checkAll]
/// reports that real, already-existing suffix as the "client version" it
/// sends, rather than inventing a semver scheme this codebase doesn't
/// have.
library;

import '../../core/constants/api_config.dart';
import 'api_client.dart';
import 'model_registry.dart';

/// Maps a `kZapsafeModels` key to the real backend `ModelType` value.
/// Only the 4 core DCS slots have a backend counterpart.
const Map<String, String> kLocalToBackendModelType = {
  'scream': 'scream',
  'motion': 'motion',
  'scene': 'scene',
  'fusion': 'dcs',
};

/// Extracts the `_vN` suffix from an asset filename as this repo's real
/// (if informal) local version string — e.g.
/// `assets/models/scream_classifier_v1.tflite` → `v1`.
String localVersionFor(ModelDefinition def) {
  final match = RegExp(r'_v(\d+)\.tflite$').firstMatch(def.assetPath);
  return match != null ? 'v${match.group(1)}' : 'unknown';
}

class ModelVersionResult {
  const ModelVersionResult({
    required this.modelType,
    required this.clientVersion,
    required this.serverVersion,
    required this.updateAvailable,
  });

  final String modelType;
  final String? clientVersion;
  final String? serverVersion;
  final bool updateAvailable;

  factory ModelVersionResult.fromJson(Map<String, dynamic> j) => ModelVersionResult(
        modelType: j['model_type'] as String,
        clientVersion: j['client_version'] as String?,
        serverVersion: j['server_version'] as String?,
        updateAvailable: (j['update_available'] as bool?) ?? false,
      );
}

class ModelVersionCheckResponse {
  const ModelVersionCheckResponse({
    required this.checkedAt,
    required this.allUpToDate,
    required this.results,
  });

  final String checkedAt;
  final bool allUpToDate;
  final List<ModelVersionResult> results;

  factory ModelVersionCheckResponse.fromJson(Map<String, dynamic> j) =>
      ModelVersionCheckResponse(
        checkedAt: (j['checked_at'] as String?) ?? '',
        allUpToDate: (j['all_up_to_date'] as bool?) ?? true,
        results: ((j['results'] as List?) ?? [])
            .cast<Map<String, dynamic>>()
            .map(ModelVersionResult.fromJson)
            .toList(),
      );

  static const empty =
      ModelVersionCheckResponse(checkedAt: '', allUpToDate: true, results: []);
}

class ModelVersionService {
  const ModelVersionService(this._client);
  final ApiClient _client;

  /// POST /api/v1/models/get-version/ — sends the real local version
  /// (asset filename suffix) for each of the 4 core DCS slots and returns
  /// the server's comparison.
  Future<ModelVersionCheckResponse> checkAll() async {
    final body = {
      'models': [
        for (final def in kZapsafeModels.take(4))
          if (kLocalToBackendModelType.containsKey(def.key))
            {
              'model_type': kLocalToBackendModelType[def.key],
              'version': localVersionFor(def),
            },
      ],
    };

    final r = await _client.dio.post<Map<String, dynamic>>(
      ApiConfig.modelsGetVersion,
      data: body,
    );
    final data = r.data;
    if (data == null) return ModelVersionCheckResponse.empty;
    return ModelVersionCheckResponse.fromJson(data);
  }
}
