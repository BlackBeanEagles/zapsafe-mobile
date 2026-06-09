/// Day 86 — Escalation Policy state (v2).
///
/// Self-contained mock Riverpod state — no API calls.
/// [EscalationNotifier] holds all policies and exposes
/// setDefault, update, add, delete.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Timeout options ──────────────────────────────────────────────────────────

const kTier1TimeoutOptions = [30, 45, 60, 90, 120, 180, 300];
const kTier2TimeoutOptions = [60, 90, 120, 180, 300, 600];

// ─── Model ────────────────────────────────────────────────────────────────────

class EscalationPolicyV2 {
  const EscalationPolicyV2({
    required this.id,
    required this.name,
    required this.isDefault,
    required this.tier1TimeoutSec,
    required this.tier1RetryCount,
    required this.escalateToTier2,
    required this.tier2TimeoutSec,
    required this.autoCallEmergency,
    required this.sendLocationSms,
    required this.loopAudioAlarm,
    required this.notes,
  });

  final String id;
  final String name;
  final bool   isDefault;
  final int    tier1TimeoutSec;   // seconds before escalating
  final int    tier1RetryCount;   // SMS retry attempts
  final bool   escalateToTier2;
  final int    tier2TimeoutSec;
  final bool   autoCallEmergency; // dial 112 if no response
  final bool   sendLocationSms;
  final bool   loopAudioAlarm;
  final String notes;

  EscalationPolicyV2 copyWith({
    String? name,
    bool?   isDefault,
    int?    tier1TimeoutSec,
    int?    tier1RetryCount,
    bool?   escalateToTier2,
    int?    tier2TimeoutSec,
    bool?   autoCallEmergency,
    bool?   sendLocationSms,
    bool?   loopAudioAlarm,
    String? notes,
  }) {
    return EscalationPolicyV2(
      id:                id,
      name:              name              ?? this.name,
      isDefault:         isDefault         ?? this.isDefault,
      tier1TimeoutSec:   tier1TimeoutSec   ?? this.tier1TimeoutSec,
      tier1RetryCount:   tier1RetryCount   ?? this.tier1RetryCount,
      escalateToTier2:   escalateToTier2   ?? this.escalateToTier2,
      tier2TimeoutSec:   tier2TimeoutSec   ?? this.tier2TimeoutSec,
      autoCallEmergency: autoCallEmergency ?? this.autoCallEmergency,
      sendLocationSms:   sendLocationSms   ?? this.sendLocationSms,
      loopAudioAlarm:    loopAudioAlarm    ?? this.loopAudioAlarm,
      notes:             notes             ?? this.notes,
    );
  }

  String get flowSummary {
    String fmt(int s) => s < 60 ? '${s}s' : '${s ~/ 60}m';
    final buf = StringBuffer('T1 ${fmt(tier1TimeoutSec)}×$tier1RetryCount');
    if (escalateToTier2) { buf.write(' → T2 ${fmt(tier2TimeoutSec)}'); }
    if (autoCallEmergency) { buf.write(' → 112'); }
    return buf.toString();
  }
}

// ─── Mock data ────────────────────────────────────────────────────────────────

final _mockPolicies = [
  const EscalationPolicyV2(
    id:                'p1',
    name:              'Quick Response',
    isDefault:         true,
    tier1TimeoutSec:   30,
    tier1RetryCount:   3,
    escalateToTier2:   true,
    tier2TimeoutSec:   60,
    autoCallEmergency: false,
    sendLocationSms:   true,
    loopAudioAlarm:    false,
    notes:             'Best for everyday use. Fast escalation, no auto-call.',
  ),
  const EscalationPolicyV2(
    id:                'p2',
    name:              'Night Mode',
    isDefault:         false,
    tier1TimeoutSec:   60,
    tier1RetryCount:   2,
    escalateToTier2:   true,
    tier2TimeoutSec:   120,
    autoCallEmergency: false,
    sendLocationSms:   true,
    loopAudioAlarm:    true,
    notes:             'Longer timeouts to reduce false alarms during sleep.',
  ),
  const EscalationPolicyV2(
    id:                'p3',
    name:              'High Risk',
    isDefault:         false,
    tier1TimeoutSec:   30,
    tier1RetryCount:   3,
    escalateToTier2:   true,
    tier2TimeoutSec:   60,
    autoCallEmergency: true,
    sendLocationSms:   true,
    loopAudioAlarm:    true,
    notes:             'For travel in high-risk areas. Calls 112 if no one responds.',
  ),
];

// ─── Notifier ─────────────────────────────────────────────────────────────────

class EscalationNotifier extends StateNotifier<List<EscalationPolicyV2>> {
  EscalationNotifier() : super(List.from(_mockPolicies));

  void setDefault(String id) {
    state = [
      for (final p in state)
        p.id == id
            ? p.copyWith(isDefault: true)
            : p.copyWith(isDefault: false),
    ];
  }

  void update(EscalationPolicyV2 updated) {
    state = [for (final p in state) p.id == updated.id ? updated : p];
  }

  void add(EscalationPolicyV2 policy) {
    state = [...state, policy];
  }

  void delete(String id) {
    final wasDefault = state.any((p) => p.id == id && p.isDefault);
    state = state.where((p) => p.id != id).toList();
    if (wasDefault && state.isNotEmpty) {
      setDefault(state.first.id);
    }
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final escalationPoliciesProvider =
    StateNotifierProvider<EscalationNotifier, List<EscalationPolicyV2>>(
  (ref) => EscalationNotifier(),
);
