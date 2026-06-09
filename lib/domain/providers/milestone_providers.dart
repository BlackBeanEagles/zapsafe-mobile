/// Day 100 — Sprint Milestone state.
///
/// Tracks which monthly-breakdown accordion card is currently open.
/// All other state on the screen is derived from static data constants.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── State ────────────────────────────────────────────────────────────────────

class MilestoneState {
  const MilestoneState({required this.expandedMonth});

  /// 1-4 = that month's card is open; null = all collapsed.
  final int? expandedMonth;

  MilestoneState copyWith({
    int?  expandedMonth,
    bool  clearExpanded = false,
  }) {
    return MilestoneState(
      expandedMonth: clearExpanded
          ? null
          : (expandedMonth ?? this.expandedMonth),
    );
  }
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class MilestoneNotifier extends StateNotifier<MilestoneState> {
  MilestoneNotifier() : super(const MilestoneState(expandedMonth: null));

  /// Toggle the accordion for [month] (1-4).
  /// Tapping the already-open card collapses it.
  void toggle(int month) {
    final next = state.expandedMonth == month ? null : month;
    state = next == null
        ? state.copyWith(clearExpanded: true)
        : state.copyWith(expandedMonth: next);
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final milestoneProvider =
    StateNotifierProvider<MilestoneNotifier, MilestoneState>(
  (ref) => MilestoneNotifier(),
);
