/// Day 366 — police connection status and request.
///
/// `police_dispatch_api_service.dart` covers GET /api/v1/police/dispatch/<id>/,
/// which is about ONE dispatched SOS. These two endpoints are about the
/// account's standing relationship with a police department, and had no client
/// at all — `day221_police_dashboard_screen.dart` named both paths in its copy
/// while running on local state.
///
///   GET  /api/v1/police/connection/          -> status (200)
///   POST /api/v1/police/connection/request/  -> {request_id, status} (202)
///
/// Both sit behind the `police` feature flag server-side. When it is off, GET
/// returns `{"connected": false}` with no other fields and POST returns 403
/// FEATURE_DISABLED. That is a real, expected state rather than an error — the
/// feature genuinely is not live yet — so it is modelled explicitly instead of
/// surfacing as a failure the user is asked to retry.
library;

import 'package:dio/dio.dart';

import '../../core/constants/api_config.dart';
import 'api_client.dart';

/// The account's police-connection status.
class PoliceConnection {
  const PoliceConnection({
    required this.connected,
    this.status = '',
    this.departmentName = '',
    this.connectedAt,
    this.featureEnabled = true,
  });

  factory PoliceConnection.fromJson(Map<String, dynamic> j) {
    // The flag-off response is exactly {"connected": false} — no `status` key.
    // Its absence is how the client can tell "feature off" from "not yet
    // connected", which the two states otherwise look identical for.
    final hasStatus = j.containsKey('status');
    return PoliceConnection(
      connected: j['connected'] == true,
      status: (j['status'] ?? '').toString(),
      departmentName: (j['department_name'] ?? '').toString(),
      connectedAt: j['connected_at'] == null
          ? null
          : DateTime.tryParse(j['connected_at'].toString())?.toLocal(),
      featureEnabled: hasStatus,
    );
  }

  final bool connected;

  /// `pending` | `connected` | ... — empty when the feature flag is off.
  final String status;

  final String departmentName;
  final DateTime? connectedAt;

  /// False when the server answered with the feature-flag-off shape.
  final bool featureEnabled;
}

/// The feature flag is off server-side. Not a failure — the feature is not live.
class PoliceFeatureDisabledException implements Exception {
  const PoliceFeatureDisabledException([this.message = 'Police connection is not available yet.']);
  final String message;
  @override
  String toString() => message;
}

class PoliceConnectionApiService {
  const PoliceConnectionApiService(this._client);

  final ApiClient _client;

  /// GET /api/v1/police/connection/
  Future<PoliceConnection> fetchConnection() async {
    final res = await _client.dio
        .get<Map<String, dynamic>>(ApiConfig.policeConnection);
    return PoliceConnection.fromJson(res.data ?? const {});
  }

  /// POST /api/v1/police/connection/request/ — 202 Accepted.
  ///
  /// Throws [PoliceFeatureDisabledException] on the 403 the server returns when
  /// the flag is off, so the UI can say "not available yet" rather than
  /// "something went wrong" and invite a pointless retry.
  Future<String> requestConnection({String departmentName = ''}) async {
    try {
      final res = await _client.dio.post<Map<String, dynamic>>(
        ApiConfig.policeConnectionRequest,
        data: <String, dynamic>{
          if (departmentName.trim().isNotEmpty)
            'department_name': departmentName.trim(),
        },
      );
      return (res.data?['request_id'] ?? '').toString();
    } on DioException catch (e) {
      final body = e.response?.data;
      if (e.response?.statusCode == 403 &&
          body is Map &&
          body['code'] == 'FEATURE_DISABLED') {
        throw const PoliceFeatureDisabledException();
      }
      rethrow;
    }
  }
}
