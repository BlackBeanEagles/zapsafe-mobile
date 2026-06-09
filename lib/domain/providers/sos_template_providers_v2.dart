/// Day 87 — SOS Template state (v2).
///
/// Self-contained mock Riverpod state — no API calls.
/// Supports {{location}}, {{time}}, and {{battery}} runtime placeholders.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Placeholders ─────────────────────────────────────────────────────────────

const kSosPlaceholders = [
  '{{location}}',
  '{{time}}',
  '{{battery}}',
];

/// Mock substitution values shown in the live preview.
const kPreviewValues = {
  '{{location}}': 'Connaught Place, New Delhi',
  '{{time}}':     '14:32 IST, 28 May 2026',
  '{{battery}}':  '42%',
};

// ─── Model ────────────────────────────────────────────────────────────────────

class SosTemplateV2 {
  const SosTemplateV2({
    required this.id,
    required this.title,
    required this.body,
    required this.includeLocation,
    required this.includeBatteryLevel,
    required this.isDefault,
    required this.notes,
    required this.sentCount,
    this.lastUsed,
  });

  final String    id;
  final String    title;
  final String    body;
  final bool      includeLocation;
  final bool      includeBatteryLevel;
  final bool      isDefault;
  final String    notes;
  final int       sentCount;
  final DateTime? lastUsed;

  SosTemplateV2 copyWith({
    String?   title,
    String?   body,
    bool?     includeLocation,
    bool?     includeBatteryLevel,
    bool?     isDefault,
    String?   notes,
    int?      sentCount,
    DateTime? lastUsed,
  }) {
    return SosTemplateV2(
      id:                  id,
      title:               title               ?? this.title,
      body:                body                ?? this.body,
      includeLocation:     includeLocation     ?? this.includeLocation,
      includeBatteryLevel: includeBatteryLevel ?? this.includeBatteryLevel,
      isDefault:           isDefault           ?? this.isDefault,
      notes:               notes               ?? this.notes,
      sentCount:           sentCount           ?? this.sentCount,
      lastUsed:            lastUsed            ?? this.lastUsed,
    );
  }

  /// Body with all placeholders replaced by preview values.
  String get resolvedPreview {
    var text = body;
    kPreviewValues.forEach((key, val) {
      text = text.replaceAll(key, val);
    });
    return text;
  }

  int get charCount => resolvedPreview.length;

  /// Number of SMS segments (160 chars per segment).
  int get smsSegments => ((charCount - 1) ~/ 160) + 1;
}

// ─── Mock data ────────────────────────────────────────────────────────────────

final _mockTemplates = [
  SosTemplateV2(
    id:                  't1',
    title:               'Standard SOS',
    body:                'HELP! I\'m in danger. My location: {{location}}. Time: {{time}}. Battery: {{battery}}.',
    includeLocation:     true,
    includeBatteryLevel: true,
    isDefault:           true,
    notes:               'General emergency. Sent to all active tiers.',
    sentCount:           23,
    lastUsed:            DateTime.now().subtract(const Duration(hours: 2)),
  ),
  SosTemplateV2(
    id:                  't2',
    title:               'Quiet Mode',
    body:                'Need help. {{location}} — {{time}}',
    includeLocation:     true,
    includeBatteryLevel: false,
    isDefault:           false,
    notes:               'Short message for situations requiring discretion.',
    sentCount:           5,
    lastUsed:            DateTime.now().subtract(const Duration(days: 3)),
  ),
  SosTemplateV2(
    id:                  't3',
    title:               'Medical Emergency',
    body:                'MEDICAL EMERGENCY at {{location}}. Please call an ambulance immediately. Time: {{time}}. Battery: {{battery}}.',
    includeLocation:     true,
    includeBatteryLevel: true,
    isDefault:           false,
    notes:               'For situations requiring immediate medical response.',
    sentCount:           1,
    lastUsed:            DateTime.now().subtract(const Duration(days: 14)),
  ),
  const SosTemplateV2(
    id:                  't4',
    title:               'Travel Alert',
    body:                'Travel SOS. I need help at {{location}} ({{time}}). Please contact local authorities.',
    includeLocation:     true,
    includeBatteryLevel: false,
    isDefault:           false,
    notes:               'For international travel or high-risk transit.',
    sentCount:           0,
    lastUsed:            null,
  ),
];

// ─── Notifier ─────────────────────────────────────────────────────────────────

class SosTemplatesNotifier extends StateNotifier<List<SosTemplateV2>> {
  SosTemplatesNotifier() : super(List.from(_mockTemplates));

  void setDefault(String id) {
    state = [
      for (final t in state)
        t.id == id
            ? t.copyWith(isDefault: true)
            : t.copyWith(isDefault: false),
    ];
  }

  void update(SosTemplateV2 updated) {
    state = [for (final t in state) t.id == updated.id ? updated : t];
  }

  void add(SosTemplateV2 template) {
    state = [...state, template];
  }

  void delete(String id) {
    final wasDefault = state.any((t) => t.id == id && t.isDefault);
    state = state.where((t) => t.id != id).toList();
    if (wasDefault && state.isNotEmpty) {
      setDefault(state.first.id);
    }
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final sosTemplatesProvider =
    StateNotifierProvider<SosTemplatesNotifier, List<SosTemplateV2>>(
  (ref) => SosTemplatesNotifier(),
);
