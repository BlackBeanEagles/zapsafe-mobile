/// Referral service — backend Day 206-207, wired for real Day 355.
///
/// GET /api/v1/referral/code/   -> {code, link}
/// GET /api/v1/referral/stats/  -> {invited, completed, bonus_points}
///
/// Both endpoints are gated behind the `referral` feature flag on the
/// backend (`feature_flags.utils.is_feature_enabled`, see
/// `zapsafe_backend/referral/views.py`) — when off, both return
/// `403 {"error": ..., "code": "FEATURE_DISABLED"}`, surfaced here as
/// [ReferralFeatureDisabledException] so the UI can show a clear message
/// instead of a generic error.
///
/// Response shapes match `zapsafe_backend/referral/serializers.py`
/// field-for-field, verified by reading the view + serializer source
/// directly (Docker unavailable in this sandbox — code-level
/// verification, not a live HTTP round trip).
library;

import 'package:dio/dio.dart';

import '../../core/constants/api_config.dart';
import 'api_client.dart';

class ReferralFeatureDisabledException implements Exception {
  const ReferralFeatureDisabledException();
  @override
  String toString() => 'Referral is not available yet (FEATURE_DISABLED).';
}

class ReferralCode {
  const ReferralCode({required this.code, required this.link});
  final String code;
  final String link;

  factory ReferralCode.fromJson(Map<String, dynamic> j) => ReferralCode(
        code: j['code'] as String? ?? '',
        link: j['link'] as String? ?? '',
      );
}

class ReferralStats {
  const ReferralStats({
    required this.invited,
    required this.completed,
    required this.bonusPoints,
  });
  final int invited;
  final int completed;
  final int bonusPoints;

  factory ReferralStats.fromJson(Map<String, dynamic> j) => ReferralStats(
        invited: (j['invited'] as num?)?.toInt() ?? 0,
        completed: (j['completed'] as num?)?.toInt() ?? 0,
        bonusPoints: (j['bonus_points'] as num?)?.toInt() ?? 0,
      );
}

class ReferralApiService {
  const ReferralApiService(this._client);
  final ApiClient _client;

  Future<T> _unwrapFeatureFlag<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      final data = e.response?.data;
      if (e.response?.statusCode == 403 &&
          data is Map && data['code'] == 'FEATURE_DISABLED') {
        throw const ReferralFeatureDisabledException();
      }
      rethrow;
    }
  }

  /// GET /api/v1/referral/code/
  Future<ReferralCode> fetchCode() => _unwrapFeatureFlag(() async {
        final res = await _client.dio.get(ApiConfig.referralCode);
        return ReferralCode.fromJson(res.data as Map<String, dynamic>);
      });

  /// GET /api/v1/referral/stats/ — bonus_points = completed × 50
  /// (POINTS_PER_COMPLETED_REFERRAL on the backend, not the +10 the Day
  /// 224 mock screen used).
  Future<ReferralStats> fetchStats() => _unwrapFeatureFlag(() async {
        final res = await _client.dio.get(ApiConfig.referralStats);
        return ReferralStats.fromJson(res.data as Map<String, dynamic>);
      });
}
