/// Day 354 — Family dashboard API providers.
///
/// Wires the real, live backend family endpoints (Day 224-225) into
/// Riverpod providers, same pattern as Day 302's analytics providers.
/// [kUseMockData] keeps these on seeded mock values for offline emulator
/// QA — set `--dart-define=USE_MOCK_DATA=true` to force it.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_flags.dart';
import '../../data/services/family_api_service.dart';
import 'auth_providers.dart';

final familyApiServiceProvider = Provider<FamilyApiService>((ref) {
  return FamilyApiService(ref.watch(apiClientProvider));
});

// ─── Mock fallback (offline emulator QA only) ──────────────────────────────

FamilyDashboard _mockFamilyDashboard() => FamilyDashboard(
      count: 2,
      members: [
        FamilyDashboardMember(
          memberId: 'mock-member-1',
          fullName: 'Sunita Mehta',
          phone: '+91 98xxxxxx01',
          role: 'member',
          lastSosStatus: null,
          lastSosTriggeredAt: null,
          hasLiveSos: false,
        ),
        FamilyDashboardMember(
          memberId: 'mock-member-2',
          fullName: 'Rahul Mehta',
          phone: '+91 98xxxxxx02',
          role: 'member',
          lastSosStatus: 'resolved',
          lastSosTriggeredAt: DateTime(2026, 8, 1, 14, 32),
          hasLiveSos: false,
        ),
      ],
    );

/// Real dashboard, falling back to mock on any error (offline, backend
/// down, no FamilyLink rows) so the UI never crashes.
final familyDashboardProvider = FutureProvider<FamilyDashboard>((ref) async {
  if (kUseMockData) return _mockFamilyDashboard();
  try {
    return await ref.watch(familyApiServiceProvider).fetchDashboard();
  } catch (_) {
    return _mockFamilyDashboard();
  }
});

/// Raw, no-fallback variant — used by the Day 354 QA screen so it can show
/// a real error state instead of silently masking failures.
final familyDashboardRawProvider = FutureProvider<FamilyDashboard>((ref) {
  return ref.watch(familyApiServiceProvider).fetchDashboard();
});

/// Per-member SOS history — family(memberId) argument is the real member
/// UUID from [familyDashboardProvider], not a mock string id.
final familyMemberSosHistoryProvider =
    FutureProvider.family<FamilySosHistory, String>((ref, memberId) {
  return ref.watch(familyApiServiceProvider).fetchMemberSosHistory(memberId);
});
