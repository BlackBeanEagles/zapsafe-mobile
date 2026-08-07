/// Day 355 — Referral API providers.
///
/// Wires the real, live backend referral endpoints (Day 206-207) into
/// Riverpod providers, same pattern as Day 302's analytics providers.
/// [kUseMockData] keeps these on seeded mock values for offline emulator
/// QA — set `--dart-define=USE_MOCK_DATA=true` to force it.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_flags.dart';
import '../../data/services/referral_api_service.dart';
import 'auth_providers.dart';

final referralApiServiceProvider = Provider<ReferralApiService>((ref) {
  return ReferralApiService(ref.watch(apiClientProvider));
});

// ─── Mock fallback (offline emulator QA only) ──────────────────────────────

const _mockReferralCode = ReferralCode(
  code: 'ZAP-MOCK42',
  link: 'https://zapsafe.app/r/ZAP-MOCK42',
);

const _mockReferralStats = ReferralStats(invited: 0, completed: 0, bonusPoints: 0);

/// Real referral code, falling back to mock on any error (offline, backend
/// down, feature flag off) so the UI never crashes.
final referralCodeProvider = FutureProvider<ReferralCode>((ref) async {
  if (kUseMockData) return _mockReferralCode;
  try {
    return await ref.watch(referralApiServiceProvider).fetchCode();
  } catch (_) {
    return _mockReferralCode;
  }
});

final referralStatsProvider = FutureProvider<ReferralStats>((ref) async {
  if (kUseMockData) return _mockReferralStats;
  try {
    return await ref.watch(referralApiServiceProvider).fetchStats();
  } catch (_) {
    return _mockReferralStats;
  }
});

/// Raw, no-fallback variants — used by the Day 355 QA screen so it can show
/// a real error state (incl. FEATURE_DISABLED) instead of silently masking
/// failures.
final referralCodeRawProvider = FutureProvider<ReferralCode>((ref) {
  return ref.watch(referralApiServiceProvider).fetchCode();
});

final referralStatsRawProvider = FutureProvider<ReferralStats>((ref) {
  return ref.watch(referralApiServiceProvider).fetchStats();
});
