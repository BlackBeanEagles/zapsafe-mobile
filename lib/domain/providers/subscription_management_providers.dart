/// Day 93-94 — Subscription Management state.
///
/// Fully self-contained mock Riverpod state — no API calls.
/// Covers active plan details, billing cycle switch, cancel-at-period-end,
/// and reactivation flow.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';

// ─── Plan status ──────────────────────────────────────────────────────────────

enum PlanStatus { active, cancelledAtPeriodEnd, cancelled }

extension PlanStatusX on PlanStatus {
  String get label {
    switch (this) {
      case PlanStatus.active:              return 'Active';
      case PlanStatus.cancelledAtPeriodEnd: return 'Cancels at period end';
      case PlanStatus.cancelled:           return 'Cancelled';
    }
  }

  Color get color {
    switch (this) {
      case PlanStatus.active:              return ZapColors.safe;
      case PlanStatus.cancelledAtPeriodEnd: return ZapColors.warning;
      case PlanStatus.cancelled:           return ZapColors.danger;
    }
  }

  IconData get icon {
    switch (this) {
      case PlanStatus.active:              return Icons.check_circle_rounded;
      case PlanStatus.cancelledAtPeriodEnd: return Icons.schedule_rounded;
      case PlanStatus.cancelled:           return Icons.cancel_rounded;
    }
  }
}

// ─── Billing cycle ────────────────────────────────────────────────────────────

enum MgmtBillingCycle { monthly, annual }

extension MgmtBillingCycleX on MgmtBillingCycle {
  String get label {
    switch (this) {
      case MgmtBillingCycle.monthly: return 'Monthly';
      case MgmtBillingCycle.annual:  return 'Annual';
    }
  }

  double get monthlyPrice {
    switch (this) {
      case MgmtBillingCycle.monthly: return 4.99;
      case MgmtBillingCycle.annual:  return 3.99;
    }
  }

  double get billedAmount {
    switch (this) {
      case MgmtBillingCycle.monthly: return 4.99;
      case MgmtBillingCycle.annual:  return 47.88;
    }
  }

  String get billedLabel {
    switch (this) {
      case MgmtBillingCycle.monthly: return 'Billed monthly';
      case MgmtBillingCycle.annual:  return 'Billed annually';
    }
  }

  String get switchCtaLabel {
    switch (this) {
      case MgmtBillingCycle.monthly:
        return 'Switch to Annual · Save 20%';
      case MgmtBillingCycle.annual:
        return 'Switch to Monthly · \$4.99/mo';
    }
  }

  MgmtBillingCycle get other {
    switch (this) {
      case MgmtBillingCycle.monthly: return MgmtBillingCycle.annual;
      case MgmtBillingCycle.annual:  return MgmtBillingCycle.monthly;
    }
  }
}

// ─── Cancel reason ────────────────────────────────────────────────────────────

enum CancelReason {
  tooExpensive,
  foundAlternative,
  noLongerNeeded,
  technicalIssues,
  other,
}

extension CancelReasonX on CancelReason {
  String get label {
    switch (this) {
      case CancelReason.tooExpensive:      return 'Too expensive';
      case CancelReason.foundAlternative:  return 'Found a better alternative';
      case CancelReason.noLongerNeeded:    return 'No longer needed';
      case CancelReason.technicalIssues:   return 'Technical issues';
      case CancelReason.other:             return 'Other reason';
    }
  }
}

// ─── Subscription detail model ────────────────────────────────────────────────

class SubscriptionDetail {
  const SubscriptionDetail({
    required this.plan,
    required this.status,
    required this.billingCycle,
    required this.nextBillingDate,
    required this.currentPeriodStart,
    required this.cancelAtPeriodEnd,
  });

  final String           plan;
  final PlanStatus       status;
  final MgmtBillingCycle billingCycle;
  final DateTime         nextBillingDate;
  final DateTime         currentPeriodStart;
  final bool             cancelAtPeriodEnd;

  int get daysRemaining {
    final diff = nextBillingDate.difference(DateTime.now());
    return diff.inDays.clamp(0, 999);
  }

  SubscriptionDetail copyWith({
    PlanStatus?       status,
    MgmtBillingCycle? billingCycle,
    DateTime?         nextBillingDate,
    bool?             cancelAtPeriodEnd,
  }) {
    return SubscriptionDetail(
      plan:               plan,
      status:             status             ?? this.status,
      billingCycle:       billingCycle       ?? this.billingCycle,
      nextBillingDate:    nextBillingDate    ?? this.nextBillingDate,
      currentPeriodStart: currentPeriodStart,
      cancelAtPeriodEnd:  cancelAtPeriodEnd  ?? this.cancelAtPeriodEnd,
    );
  }
}

// ─── Management state ─────────────────────────────────────────────────────────

class ManagementState {
  const ManagementState({
    required this.detail,
    required this.isCancelling,
    required this.isSwitchingCycle,
    required this.isReactivating,
    this.lastActionMessage,
  });

  final SubscriptionDetail detail;
  final bool               isCancelling;
  final bool               isSwitchingCycle;
  final bool               isReactivating;
  final String?            lastActionMessage;

  ManagementState copyWith({
    SubscriptionDetail? detail,
    bool?               isCancelling,
    bool?               isSwitchingCycle,
    bool?               isReactivating,
    String?             lastActionMessage,
  }) {
    return ManagementState(
      detail:            detail            ?? this.detail,
      isCancelling:      isCancelling      ?? this.isCancelling,
      isSwitchingCycle:  isSwitchingCycle  ?? this.isSwitchingCycle,
      isReactivating:    isReactivating    ?? this.isReactivating,
      lastActionMessage: lastActionMessage,
    );
  }
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class ManagementNotifier extends StateNotifier<ManagementState> {
  ManagementNotifier()
      : super(ManagementState(
          detail: SubscriptionDetail(
            plan:               'Premium',
            status:             PlanStatus.active,
            billingCycle:       MgmtBillingCycle.annual,
            nextBillingDate:    DateTime.now().add(const Duration(days: 14)),
            currentPeriodStart: DateTime.now().subtract(const Duration(days: 351)),
            cancelAtPeriodEnd:  false,
          ),
          isCancelling:     false,
          isSwitchingCycle: false,
          isReactivating:   false,
        ));

  Future<void> cancelSubscription(CancelReason? reason) async {
    state = state.copyWith(isCancelling: true);
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    state = state.copyWith(
      isCancelling: false,
      detail: state.detail.copyWith(
        status:            PlanStatus.cancelledAtPeriodEnd,
        cancelAtPeriodEnd: true,
      ),
      lastActionMessage:
          'Subscription cancelled. Premium access continues until '
          '${_fmtDate(state.detail.nextBillingDate)}.',
    );
  }

  Future<void> reactivate() async {
    state = state.copyWith(isReactivating: true);
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    state = state.copyWith(
      isReactivating: false,
      detail: state.detail.copyWith(
        status:            PlanStatus.active,
        cancelAtPeriodEnd: false,
      ),
      lastActionMessage: 'Subscription reactivated. Thank you!',
    );
  }

  Future<void> switchBillingCycle() async {
    state = state.copyWith(isSwitchingCycle: true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    final newCycle   = state.detail.billingCycle.other;
    final newNextDate = DateTime.now().add(
      newCycle == MgmtBillingCycle.annual
          ? const Duration(days: 365)
          : const Duration(days: 30),
    );
    state = state.copyWith(
      isSwitchingCycle: false,
      detail: state.detail.copyWith(
        billingCycle:    newCycle,
        nextBillingDate: newNextDate,
      ),
      lastActionMessage:
          'Billing cycle switched to ${newCycle.label}.',
    );
  }

  void clearMessage() {
    state = state.copyWith(lastActionMessage: null);
  }
}

String _fmtDate(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
}

final subscriptionManagementProvider =
    StateNotifierProvider<ManagementNotifier, ManagementState>(
  (ref) => ManagementNotifier(),
);
