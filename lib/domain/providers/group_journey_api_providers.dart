/// Day 357 — Group journey session API providers.
///
/// Wires the real, live backend group journey endpoints (Days 221-223)
/// into a Riverpod [StateNotifier] — create/join/panic are user-triggered
/// one-shot mutations (same reasoning as Day 303's
/// `SubscriptionActionController`), not auto-fetched data, so a simple
/// FutureProvider doesn't fit.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/group_journey_api_service.dart';
import 'auth_providers.dart';

final groupJourneyApiServiceProvider = Provider<GroupJourneyApiService>((ref) {
  return GroupJourneyApiService(ref.watch(apiClientProvider));
});

class GroupJourneyWireState {
  const GroupJourneyWireState({
    this.session,
    this.panicResult,
    this.isLoading = false,
    this.error,
  });

  final GroupJourneySession? session;
  final GroupJourneyPanicResult? panicResult;
  final bool isLoading;
  final Object? error;

  GroupJourneyWireState copyWith({
    GroupJourneySession? session,
    GroupJourneyPanicResult? panicResult,
    bool? isLoading,
    Object? error,
    bool clearError = false,
  }) {
    return GroupJourneyWireState(
      session: session ?? this.session,
      panicResult: panicResult ?? this.panicResult,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class GroupJourneyWireController extends StateNotifier<GroupJourneyWireState> {
  GroupJourneyWireController(this._ref) : super(const GroupJourneyWireState());
  final Ref _ref;

  GroupJourneyApiService get _svc => _ref.read(groupJourneyApiServiceProvider);

  Future<void> create({String destinationName = ''}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final session = await _svc.createSession(destinationName: destinationName);
      state = state.copyWith(session: session, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<void> join(String token) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final session = await _svc.joinSession(token);
      state = state.copyWith(session: session, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<void> refreshState() async {
    final id = state.session?.id;
    if (id == null || id.isEmpty) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final session = await _svc.fetchState(id);
      state = state.copyWith(session: session, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<void> panic({double? lat, double? lng, double? accuracyM}) async {
    final id = state.session?.id;
    if (id == null || id.isEmpty) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _svc.triggerPanic(id, lat: lat, lng: lng, accuracyM: accuracyM);
      state = state.copyWith(panicResult: result, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  void reset() => state = const GroupJourneyWireState();
}

final groupJourneyWireProvider =
    StateNotifierProvider<GroupJourneyWireController, GroupJourneyWireState>((ref) {
  return GroupJourneyWireController(ref);
});
