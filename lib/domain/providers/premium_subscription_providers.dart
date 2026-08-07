/// Day 303 — Razorpay premium subscription providers.
///
/// [subscriptionStatusProvider] drives the tier badge everywhere in the app
/// (dashboard, settings) once wired in; [kUseMockData] keeps it on a free-
/// tier fallback for offline emulator QA.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_flags.dart';
import '../../data/services/premium_subscription_service.dart';
import 'auth_providers.dart';

final premiumSubscriptionServiceProvider = Provider<PremiumSubscriptionService>((ref) {
  return PremiumSubscriptionService(ref.watch(apiClientProvider));
});

/// Real subscription status, falling back to the free-tier default on any
/// error (offline, backend down, Razorpay keys unset server-side) so the
/// UI never crashes on a subscription-status failure — it just shows free.
final subscriptionStatusProvider = FutureProvider<SubscriptionStatus>((ref) async {
  if (kUseMockData) return SubscriptionStatus.fallback;
  try {
    return await ref.watch(premiumSubscriptionServiceProvider).fetchStatus();
  } catch (_) {
    return SubscriptionStatus.fallback;
  }
});

/// Raw variant with no fallback — used by the Day 303 QA screen so failures
/// are visible instead of masked.
final subscriptionStatusRawProvider = FutureProvider<SubscriptionStatus>((ref) {
  return ref.watch(premiumSubscriptionServiceProvider).fetchStatus();
});

/// Controller for the checkout + cancel actions (not a simple FutureProvider
/// since these are user-triggered, one-shot mutations, not auto-fetched data).
class SubscriptionActionController extends StateNotifier<AsyncValue<void>> {
  SubscriptionActionController(this._ref) : super(const AsyncData(null));
  final Ref _ref;

  Future<CheckoutResult?> startCheckout({
    SubscriptionPlan plan = SubscriptionPlan.premium,
  }) async {
    state = const AsyncLoading();
    try {
      final result = await _ref
          .read(premiumSubscriptionServiceProvider)
          .createCheckout(plan: plan);
      state = const AsyncData(null);
      return result;
    } catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }

  Future<bool> cancel() async {
    state = const AsyncLoading();
    try {
      await _ref.read(premiumSubscriptionServiceProvider).cancel();
      state = const AsyncData(null);
      _ref.invalidate(subscriptionStatusProvider);
      _ref.invalidate(subscriptionStatusRawProvider);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

final subscriptionActionProvider =
    StateNotifierProvider<SubscriptionActionController, AsyncValue<void>>((ref) {
  return SubscriptionActionController(ref);
});
