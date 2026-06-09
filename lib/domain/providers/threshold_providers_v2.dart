/// Day 85 — Alert Threshold state (v2).
///
/// Self-contained mock Riverpod state — no API calls.
/// [ThresholdsNotifier] holds all 4 model rules and exposes
/// toggle-active, update, apply-preset, and mock-test-fire.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';

// ─── Model enum ───────────────────────────────────────────────────────────────

enum AlertModelV2 { scream, motion, scene, dcs }

extension AlertModelV2X on AlertModelV2 {
  String get label {
    switch (this) {
      case AlertModelV2.scream: return 'Scream Detection';
      case AlertModelV2.motion: return 'Motion Analysis';
      case AlertModelV2.scene:  return 'Scene Recognition';
      case AlertModelV2.dcs:    return 'DCS Fusion';
    }
  }

  String get description {
    switch (this) {
      case AlertModelV2.scream: return 'Detects distress screams and calls for help';
      case AlertModelV2.motion: return 'Analyses sudden or violent movement patterns';
      case AlertModelV2.scene:  return 'Recognises dangerous environments';
      case AlertModelV2.dcs:    return 'Fuses all model outputs for highest accuracy';
    }
  }

  IconData get icon {
    switch (this) {
      case AlertModelV2.scream: return Icons.mic_rounded;
      case AlertModelV2.motion: return Icons.directions_run_rounded;
      case AlertModelV2.scene:  return Icons.remove_red_eye_rounded;
      case AlertModelV2.dcs:    return Icons.hub_rounded;
    }
  }

  Color get accent {
    switch (this) {
      case AlertModelV2.scream: return ZapColors.danger;
      case AlertModelV2.motion: return ZapColors.warning;
      case AlertModelV2.scene:  return ZapColors.info;
      case AlertModelV2.dcs:    return ZapColors.safe;
    }
  }

  double get recommendedConfidence {
    switch (this) {
      case AlertModelV2.scream: return 0.80;
      case AlertModelV2.motion: return 0.70;
      case AlertModelV2.scene:  return 0.75;
      case AlertModelV2.dcs:    return 0.85;
    }
  }

  int get recommendedConsecutive {
    switch (this) {
      case AlertModelV2.scream: return 1;
      case AlertModelV2.motion: return 2;
      case AlertModelV2.scene:  return 1;
      case AlertModelV2.dcs:    return 1;
    }
  }

  int get recommendedCooldown {
    switch (this) {
      case AlertModelV2.scream: return 30;
      case AlertModelV2.motion: return 60;
      case AlertModelV2.scene:  return 45;
      case AlertModelV2.dcs:    return 30;
    }
  }
}

// ─── Rule model ───────────────────────────────────────────────────────────────

class ThresholdRuleV2 {
  const ThresholdRuleV2({
    required this.model,
    required this.confidence,
    required this.consecutiveTriggers,
    required this.cooldownSeconds,
    required this.autoSos,
    required this.notifyContacts,
    required this.isActive,
    required this.notes,
    this.lastTriggered,
  });

  final AlertModelV2 model;
  final double       confidence;           // 0.40 – 1.00
  final int          consecutiveTriggers;  // 1 – 5
  final int          cooldownSeconds;      // 15 | 30 | 45 | 60 | 90 | 120 | 180 | 300
  final bool         autoSos;
  final bool         notifyContacts;
  final bool         isActive;
  final String       notes;
  final DateTime?    lastTriggered;

  ThresholdRuleV2 copyWith({
    double?    confidence,
    int?       consecutiveTriggers,
    int?       cooldownSeconds,
    bool?      autoSos,
    bool?      notifyContacts,
    bool?      isActive,
    String?    notes,
    DateTime?  lastTriggered,
  }) {
    return ThresholdRuleV2(
      model:               model,
      confidence:          confidence          ?? this.confidence,
      consecutiveTriggers: consecutiveTriggers ?? this.consecutiveTriggers,
      cooldownSeconds:     cooldownSeconds     ?? this.cooldownSeconds,
      autoSos:             autoSos             ?? this.autoSos,
      notifyContacts:      notifyContacts      ?? this.notifyContacts,
      isActive:            isActive            ?? this.isActive,
      notes:               notes               ?? this.notes,
      lastTriggered:       lastTriggered       ?? this.lastTriggered,
    );
  }

  ThresholdRuleV2 applyPreset() {
    return copyWith(
      confidence:          model.recommendedConfidence,
      consecutiveTriggers: model.recommendedConsecutive,
      cooldownSeconds:     model.recommendedCooldown,
    );
  }
}

// ─── Mock data ────────────────────────────────────────────────────────────────

final _mockRules = [
  ThresholdRuleV2(
    model:               AlertModelV2.scream,
    confidence:          0.80,
    consecutiveTriggers: 1,
    cooldownSeconds:     30,
    autoSos:             true,
    notifyContacts:      true,
    isActive:            true,
    notes:               'Primary distress signal. Triggers immediately.',
    lastTriggered:       DateTime.now().subtract(const Duration(hours: 2, minutes: 17)),
  ),
  ThresholdRuleV2(
    model:               AlertModelV2.motion,
    confidence:          0.70,
    consecutiveTriggers: 2,
    cooldownSeconds:     60,
    autoSos:             false,
    notifyContacts:      true,
    isActive:            true,
    notes:               'Requires 2 consecutive hits to reduce false positives.',
    lastTriggered:       DateTime.now().subtract(const Duration(hours: 8)),
  ),
  const ThresholdRuleV2(
    model:               AlertModelV2.scene,
    confidence:          0.75,
    consecutiveTriggers: 1,
    cooldownSeconds:     45,
    autoSos:             false,
    notifyContacts:      false,
    isActive:            false,
    notes:               '',
    lastTriggered:       null,
  ),
  ThresholdRuleV2(
    model:               AlertModelV2.dcs,
    confidence:          0.85,
    consecutiveTriggers: 1,
    cooldownSeconds:     30,
    autoSos:             true,
    notifyContacts:      true,
    isActive:            true,
    notes:               'High-confidence fusion rule. Rarely fires false.',
    lastTriggered:       DateTime.now().subtract(const Duration(days: 3)),
  ),
];

// ─── Notifier ─────────────────────────────────────────────────────────────────

class ThresholdsNotifier extends StateNotifier<List<ThresholdRuleV2>> {
  ThresholdsNotifier() : super(List.from(_mockRules));

  void toggleActive(AlertModelV2 model) {
    state = [
      for (final r in state)
        r.model == model ? r.copyWith(isActive: !r.isActive) : r,
    ];
  }

  void update(AlertModelV2 model, ThresholdRuleV2 updated) {
    state = [for (final r in state) r.model == model ? updated : r];
  }

  void applyPreset(AlertModelV2 model) {
    state = [
      for (final r in state)
        r.model == model ? r.applyPreset() : r,
    ];
  }

  void mockTestFire(AlertModelV2 model) {
    state = [
      for (final r in state)
        r.model == model ? r.copyWith(lastTriggered: DateTime.now()) : r,
    ];
  }

  void resetAll() {
    for (final m in AlertModelV2.values) {
      applyPreset(m);
    }
  }
}

// ─── Providers ────────────────────────────────────────────────────────────────

final thresholdsProvider =
    StateNotifierProvider<ThresholdsNotifier, List<ThresholdRuleV2>>(
  (ref) => ThresholdsNotifier(),
);
