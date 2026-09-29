/// Day 366 — Feedback API providers.
///
/// Wires the Day 114 form to the real `POST /api/v1/feedback/submit`, which
/// has been live in `zapsafe_backend/feedback/` since Day 114 while the screen
/// kept a `// Mock POST` and a `Future.delayed`.
///
/// **This deliberately does NOT copy the read-provider fallback pattern.**
/// Providers like `referralCodeProvider` catch every error and return seeded
/// mock data, which is right for a read — a stale referral code is better than
/// a crashed screen. It is wrong for a submit: returning a fake success would
/// tell a tester their bug report was filed when it was discarded, which is
/// the exact failure this wiring exists to end. Errors propagate.
///
/// [kUseMockData] is still honoured, because it is an explicit opt-in for
/// emulator QA without Django running, and every screen has to stay testable
/// from the Day 5 index. In that mode the receipt is visibly marked mock.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_flags.dart';
import '../../data/services/feedback_api_service.dart';
import 'auth_providers.dart';

final feedbackApiServiceProvider = Provider<FeedbackApiService>((ref) {
  return FeedbackApiService(ref.watch(apiClientProvider));
});

/// Submits a report and returns the backend's receipt.
///
/// Throws [FeedbackSubmitException] on rejection or network failure — callers
/// must show that, not a success state.
final submitFeedbackProvider = Provider<
    Future<FeedbackReceipt> Function({
  required int rating,
  required FeedbackCategory category,
  required String message,
  required String appVersion,
})>((ref) {
  return ({
    required int rating,
    required FeedbackCategory category,
    required String message,
    required String appVersion,
  }) async {
    if (kUseMockData) {
      // Offline emulator QA. Marked so a mock receipt can never be mistaken
      // for a real submission id in a bug thread.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      return const FeedbackReceipt(id: 'mock-not-submitted', status: 'received');
    }
    return ref.read(feedbackApiServiceProvider).submit(
          rating: rating,
          category: category,
          message: message,
          appVersion: appVersion,
        );
  };
});

/// Reports whether a completed SOS was a false alarm (Day 115).
///
/// Same rule as [submitFeedbackProvider]: errors propagate. The Day 115 screen
/// tells the user "this trains our model", and a swallowed failure would make
/// that sentence false — these labels are the hard negatives the m1/m2 retrain
/// consumes, so a dropped one is a training row lost, not just a missing UI
/// confirmation.
final reportFalsePositiveProvider = Provider<
    Future<void> Function({
  required String sosId,
  required bool isFalseAlarm,
})>((ref) {
  return ({required String sosId, required bool isFalseAlarm}) async {
    if (kUseMockData) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      return;
    }
    return ref.read(feedbackApiServiceProvider).reportFalsePositive(
          sosId: sosId,
          isFalseAlarm: isFalseAlarm,
        );
  };
});
