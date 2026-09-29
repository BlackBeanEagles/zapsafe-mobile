/// Day 114 feedback submission — wired to the real API on Day 366.
///
/// The Day 114 screen shipped with `// Mock POST` and a `Future.delayed`, so
/// every beta report a tester typed was discarded by the app that asked for
/// it. `zapsafe_backend/feedback/` has been live the whole time.
///
/// The reason it was left is recorded in the handoff: the form's category enum
/// is camelCase (`falseAlarm`, `uxIssue`) and the backend's `FeedbackCategory`
/// TextChoices are snake_case (`false_alarm`, `ux`), so a naive `.name` would
/// have been rejected as VALIDATION_ERROR — or worse, accepted for the three
/// values that happen to match and silently dropped for the two that don't.
/// That mapping lives here, in one place, with a test over it.
library;

import 'package:dio/dio.dart';

import '../../core/constants/api_config.dart';
import 'api_client.dart';

/// Wire values for `category` on POST /api/v1/feedback/submit.
///
/// These strings are the contract with `FeedbackCategory` in
/// `zapsafe_backend/feedback/models.py`, not display labels. Two of the five
/// differ from their Dart names, which is the whole reason this enum exists
/// rather than passing `.name`:
///
///   falseAlarm  -> false_alarm
///   uxIssue     -> ux            (not "ux_issue" — the backend choice is "ux")
///
/// Changing a wire value here without changing the backend TextChoices breaks
/// submission for that category only, which is the kind of failure that shows
/// up as "some feedback goes missing" rather than as an error.
enum FeedbackCategory {
  crash('crash'),
  falseAlarm('false_alarm'),
  uxIssue('ux'),
  performance('performance'),
  general('general');

  const FeedbackCategory(this.wire);

  /// The exact string the backend accepts.
  final String wire;
}

/// A submission the backend rejected or that never reached it.
///
/// Carries [isValidation] so the UI can distinguish "your input was refused"
/// (don't retry unchanged) from "the network failed" (retry is reasonable).
class FeedbackSubmitException implements Exception {
  const FeedbackSubmitException(this.message, {this.isValidation = false});

  final String message;
  final bool isValidation;

  @override
  String toString() => 'FeedbackSubmitException: $message';
}

/// The id + status the backend assigns an accepted submission.
class FeedbackReceipt {
  const FeedbackReceipt({required this.id, required this.status});

  factory FeedbackReceipt.fromJson(Map<String, dynamic> json) => FeedbackReceipt(
        id: (json['id'] ?? '').toString(),
        status: (json['status'] ?? '').toString(),
      );

  /// `public_id` — the reference a tester can quote in a bug thread.
  final String id;

  /// `received` today; the backend's FeedbackStatus has room for more.
  final String status;
}

class FeedbackApiService {
  const FeedbackApiService(this._client);

  final ApiClient _client;

  /// POST /api/v1/feedback/submit — requires a JWT (IsAuthenticated).
  ///
  /// [rating] must be 1-5 and [message] 1-5000 characters; both are enforced
  /// again by the serializer, so the local guards here exist to fail fast with
  /// a useful message rather than to be the only check.
  Future<FeedbackReceipt> submit({
    required int rating,
    required FeedbackCategory category,
    required String message,
    required String appVersion,
    DateTime? timestamp,
  }) async {
    if (rating < 1 || rating > 5) {
      throw FeedbackSubmitException(
        'Rating must be between 1 and 5 (got $rating).',
        isValidation: true,
      );
    }
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      throw const FeedbackSubmitException(
        'Please write a message before submitting.',
        isValidation: true,
      );
    }

    try {
      final res = await _client.dio.post(
        ApiConfig.feedbackSubmit,
        data: <String, dynamic>{
          'rating': rating,
          'category': category.wire,
          'message': trimmed,
          // Backend caps app_version at 32 chars.
          'app_version': appVersion,
          'timestamp': (timestamp ?? DateTime.now().toUtc()).toIso8601String(),
        },
      );
      final body = res.data;
      if (body is Map) {
        return FeedbackReceipt.fromJson(Map<String, dynamic>.from(body));
      }
      // 201 with a shape we don't recognise: the report was stored, so do not
      // tell the tester it failed and invite a duplicate.
      return const FeedbackReceipt(id: '', status: 'received');
    } on DioException catch (e) {
      throw _describe(e);
    }
  }

  /// POST /api/v1/feedback/false-positive — requires a JWT.
  ///
  /// [sosId] must be a real SOS UUID. The backend field is a `UUIDField`, so
  /// the Day 115 screen's placeholder `sos_mock_001` would have come back as a
  /// flat VALIDATION_ERROR with no hint about which field — hence the local
  /// check, which names the problem.
  ///
  /// [isFalseAlarm] false is not a no-op: "this was a real emergency" is a
  /// label the training set needs as much as the false alarms, so both answers
  /// are submitted.
  Future<void> reportFalsePositive({
    required String sosId,
    required bool isFalseAlarm,
    DateTime? timestamp,
  }) async {
    final id = sosId.trim();
    if (!isUuid(id)) {
      throw FeedbackSubmitException(
        id.isEmpty
            ? 'No SOS id — a false-alarm report has to name which SOS it is about.'
            : '"$id" is not a valid SOS id. The backend expects a UUID.',
        isValidation: true,
      );
    }

    try {
      await _client.dio.post(
        ApiConfig.feedbackFalsePositive,
        data: <String, dynamic>{
          'sos_id': id,
          'is_false_alarm': isFalseAlarm,
          'timestamp': (timestamp ?? DateTime.now().toUtc()).toIso8601String(),
        },
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const FeedbackSubmitException(
          "That SOS doesn't exist or isn't yours.",
          isValidation: true,
        );
      }
      throw _describe(e);
    }
  }

  /// Canonical 8-4-4-4-12 hex form, which is what DRF's UUIDField accepts.
  static bool isUuid(String s) => _uuid.hasMatch(s);

  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  FeedbackSubmitException _describe(DioException e) {
    final code = e.response?.statusCode;
    if (code == 400) {
      return const FeedbackSubmitException(
        'That report was rejected. Check the rating and message and try again.',
        isValidation: true,
      );
    }
    if (code == 401 || code == 403) {
      return const FeedbackSubmitException(
        'Please sign in again to send feedback.',
        isValidation: true,
      );
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError) {
      return const FeedbackSubmitException(
        "Couldn't reach ZapSafe. Your report wasn't sent — try again.",
      );
    }
    return FeedbackSubmitException(
      "Couldn't send that report${code == null ? '' : ' (HTTP $code)'}.",
    );
  }
}
