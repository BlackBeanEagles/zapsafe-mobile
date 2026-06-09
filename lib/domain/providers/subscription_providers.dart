/// Day 91-92 — Premium Subscription state.
///
/// Fully self-contained mock Riverpod state — no API calls.
/// Covers plan selection, billing-cycle toggle, and mock purchase flow.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Enums ────────────────────────────────────────────────────────────────────

enum SubscriptionPlan { free, premium }

extension SubscriptionPlanX on SubscriptionPlan {
  String get label {
    switch (this) {
      case SubscriptionPlan.free:    return 'Free';
      case SubscriptionPlan.premium: return 'Premium';
    }
  }

  String get tagline {
    switch (this) {
      case SubscriptionPlan.free:    return 'Basic protection for individuals';
      case SubscriptionPlan.premium: return 'Complete protection, always on';
    }
  }

  IconData get icon {
    switch (this) {
      case SubscriptionPlan.free:    return Icons.shield_outlined;
      case SubscriptionPlan.premium: return Icons.shield_rounded;
    }
  }
}

enum BillingCycle { monthly, annual }

extension BillingCycleX on BillingCycle {
  String get label {
    switch (this) {
      case BillingCycle.monthly: return 'Monthly';
      case BillingCycle.annual:  return 'Annual';
    }
  }
}

// ─── Plan pricing ─────────────────────────────────────────────────────────────

const double kPremiumMonthlyPrice = 4.99;
const double kPremiumAnnualMonthlyPrice = 3.99; // billed as 47.88/yr
const double kPremiumAnnualTotal = 47.88;
const int kAnnualSavingPct = 20;

// ─── Benefit model ────────────────────────────────────────────────────────────

class PlanBenefit {
  const PlanBenefit({
    required this.id,
    required this.icon,
    required this.label,
    required this.description,
    required this.freeValue,
    required this.premiumValue,
  });

  final String    id;
  final IconData  icon;
  final String    label;
  final String    description;
  final String?   freeValue;     // null = not available on free
  final String    premiumValue;

  bool get availableOnFree => freeValue != null;
}

const kPlanBenefits = <PlanBenefit>[
  PlanBenefit(
    id: 'contacts',
    icon: Icons.people_rounded,
    label: 'Emergency Contacts',
    description: 'Trusted people who receive your SOS alerts',
    freeValue: 'Up to 3',
    premiumValue: 'Unlimited',
  ),
  PlanBenefit(
    id: 'sos_channels',
    icon: Icons.crisis_alert_rounded,
    label: 'SOS Alert Channels',
    description: 'How your emergency alerts are delivered',
    freeValue: 'SMS only',
    premiumValue: 'SMS + Push + Call',
  ),
  PlanBenefit(
    id: 'evidence',
    icon: Icons.folder_rounded,
    label: 'Evidence Storage',
    description: 'Audio/photo evidence captured during SOS events',
    freeValue: '100 MB',
    premiumValue: '5 GB',
  ),
  PlanBenefit(
    id: 'check_ins',
    icon: Icons.timer_rounded,
    label: 'Check-in Timers',
    description: 'Active dead-man\'s switch timers running simultaneously',
    freeValue: '2 active',
    premiumValue: 'Unlimited',
  ),
  PlanBenefit(
    id: 'safe_zones',
    icon: Icons.location_on_rounded,
    label: 'Safe Zones',
    description: 'GPS safe zones that suppress alerts automatically',
    freeValue: '3 zones',
    premiumValue: 'Unlimited',
  ),
  PlanBenefit(
    id: 'response_priority',
    icon: Icons.bolt_rounded,
    label: 'Response Priority',
    description: 'How quickly your alerts are processed by our servers',
    freeValue: 'Standard',
    premiumValue: 'Priority (< 500 ms)',
  ),
  PlanBenefit(
    id: 'offline_mode',
    icon: Icons.wifi_off_rounded,
    label: 'Offline Mode',
    description: 'Full SOS capability with no internet connection',
    freeValue: null,
    premiumValue: 'Included',
  ),
  PlanBenefit(
    id: 'data_retention',
    icon: Icons.history_rounded,
    label: 'Data Retention',
    description: 'How long your activity history and reports are kept',
    freeValue: '30 days',
    premiumValue: '1 year',
  ),
  PlanBenefit(
    id: 'support',
    icon: Icons.headset_mic_rounded,
    label: 'Dedicated Support',
    description: 'Access to priority human support when you need it most',
    freeValue: null,
    premiumValue: '24/7 priority',
  ),
];

// ─── FAQ model ────────────────────────────────────────────────────────────────

class FaqItem {
  const FaqItem({required this.question, required this.answer});
  final String question;
  final String answer;
}

const kSubscriptionFaq = <FaqItem>[
  FaqItem(
    question: 'Can I cancel anytime?',
    answer: 'Yes — you can cancel your Premium subscription at any time from '
        'Settings → Subscription Management. Your plan stays active until the '
        'end of the billing period. No questions asked.',
  ),
  FaqItem(
    question: 'What happens to my data if I downgrade?',
    answer: 'Your data is always yours. If you downgrade to Free, evidence '
        'files beyond 100 MB are preserved for 30 days before deletion. '
        'Contacts beyond 3 remain saved but inactive until you upgrade again.',
  ),
  FaqItem(
    question: 'Is there a free trial?',
    answer: 'New accounts automatically get a 14-day Premium trial. No credit '
        'card required. At the end of the trial your account switches to Free '
        'unless you subscribe.',
  ),
];

// ─── State & notifier ─────────────────────────────────────────────────────────

class SubscriptionState {
  const SubscriptionState({
    required this.currentPlan,
    required this.selectedPlan,
    required this.billingCycle,
    required this.isPurchasing,
    required this.purchaseComplete,
  });

  final SubscriptionPlan currentPlan;
  final SubscriptionPlan selectedPlan;
  final BillingCycle     billingCycle;
  final bool             isPurchasing;
  final bool             purchaseComplete;

  bool get isAlreadyOnSelectedPlan => currentPlan == selectedPlan;

  double get displayMonthlyPrice {
    if (selectedPlan == SubscriptionPlan.free) {
      return 0;
    }
    return billingCycle == BillingCycle.monthly
        ? kPremiumMonthlyPrice
        : kPremiumAnnualMonthlyPrice;
  }

  SubscriptionState copyWith({
    SubscriptionPlan? currentPlan,
    SubscriptionPlan? selectedPlan,
    BillingCycle?     billingCycle,
    bool?             isPurchasing,
    bool?             purchaseComplete,
  }) {
    return SubscriptionState(
      currentPlan:     currentPlan     ?? this.currentPlan,
      selectedPlan:    selectedPlan    ?? this.selectedPlan,
      billingCycle:    billingCycle    ?? this.billingCycle,
      isPurchasing:    isPurchasing    ?? this.isPurchasing,
      purchaseComplete: purchaseComplete ?? this.purchaseComplete,
    );
  }
}

class SubscriptionNotifier extends StateNotifier<SubscriptionState> {
  SubscriptionNotifier()
      : super(const SubscriptionState(
          currentPlan:      SubscriptionPlan.free,
          selectedPlan:     SubscriptionPlan.premium,
          billingCycle:     BillingCycle.annual,
          isPurchasing:     false,
          purchaseComplete: false,
        ));

  void selectPlan(SubscriptionPlan plan) {
    if (state.isPurchasing) {
      return;
    }
    state = state.copyWith(selectedPlan: plan);
  }

  void setBillingCycle(BillingCycle cycle) {
    if (state.isPurchasing) {
      return;
    }
    state = state.copyWith(billingCycle: cycle);
  }

  Future<void> purchase() async {
    if (state.isPurchasing || state.isAlreadyOnSelectedPlan) {
      return;
    }
    state = state.copyWith(isPurchasing: true, purchaseComplete: false);
    await Future<void>.delayed(const Duration(milliseconds: 1800));
    state = state.copyWith(
      isPurchasing:     false,
      purchaseComplete: true,
      currentPlan:      state.selectedPlan,
    );
  }

  void resetPurchaseComplete() {
    state = state.copyWith(purchaseComplete: false);
  }
}

final subscriptionProvider =
    StateNotifierProvider<SubscriptionNotifier, SubscriptionState>(
  (ref) => SubscriptionNotifier(),
);
