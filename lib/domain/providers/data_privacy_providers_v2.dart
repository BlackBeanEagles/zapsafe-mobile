/// Day 90 — Data Export + Privacy Consent state (v2).
///
/// Fully self-contained mock Riverpod state — no API calls.
/// Covers export section selection, format, request history,
/// consent toggles, and GDPR deletion flow.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';

// ─── Export section metadata ──────────────────────────────────────────────────

class ExportSectionMeta {
  const ExportSectionMeta({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    required this.description,
    required this.itemCount,
  });

  final String   id;
  final String   label;
  final IconData icon;
  final Color    color;
  final String   description;
  final int      itemCount;
}

const kExportSections = <ExportSectionMeta>[
  ExportSectionMeta(
    id: 'profile', label: 'Profile & Settings',
    icon: Icons.person_rounded, color: ZapColors.info,
    description: 'Name, phone, quiet-hours, language', itemCount: 1,
  ),
  ExportSectionMeta(
    id: 'notification_prefs', label: 'Notification Preferences',
    icon: Icons.tune_rounded, color: ZapColors.info,
    description: '5 per-category toggle rows', itemCount: 5,
  ),
  ExportSectionMeta(
    id: 'sos_templates', label: 'SOS Templates',
    icon: Icons.message_rounded, color: ZapColors.danger,
    description: 'All pre-composed emergency messages', itemCount: 4,
  ),
  ExportSectionMeta(
    id: 'check_ins', label: 'Check-in History',
    icon: Icons.timer_rounded, color: ZapColors.safe,
    description: 'All timers — last 90 days', itemCount: 12,
  ),
  ExportSectionMeta(
    id: 'safe_zones', label: 'Safe Zones',
    icon: Icons.location_on_rounded, color: ZapColors.safe,
    description: 'All defined GPS safe zones', itemCount: 3,
  ),
  ExportSectionMeta(
    id: 'incidents', label: 'Incident Reports',
    icon: Icons.article_rounded, color: ZapColors.warning,
    description: 'All SOS event reports + evidence refs', itemCount: 2,
  ),
  ExportSectionMeta(
    id: 'activity_log', label: 'Activity Log',
    icon: Icons.history_rounded, color: ZapColors.textSecondary,
    description: 'Audit trail — last 90 days', itemCount: 32,
  ),
];

// ─── Export enums ─────────────────────────────────────────────────────────────

enum ExportFormat { json, zip }

extension ExportFormatX on ExportFormat {
  String get label {
    switch (this) {
      case ExportFormat.json: return 'JSON';
      case ExportFormat.zip:  return 'ZIP';
    }
  }

  String get description {
    switch (this) {
      case ExportFormat.json: return 'Machine-readable · single file';
      case ExportFormat.zip:  return 'Compressed archive · human-readable';
    }
  }

  IconData get icon {
    switch (this) {
      case ExportFormat.json: return Icons.data_object_rounded;
      case ExportFormat.zip:  return Icons.folder_zip_rounded;
    }
  }
}

enum ExportStatusV2 { processing, ready, failed, expired }

extension ExportStatusV2X on ExportStatusV2 {
  String get label {
    switch (this) {
      case ExportStatusV2.processing: return 'Processing';
      case ExportStatusV2.ready:      return 'Ready';
      case ExportStatusV2.failed:     return 'Failed';
      case ExportStatusV2.expired:    return 'Expired';
    }
  }

  Color get color {
    switch (this) {
      case ExportStatusV2.processing: return ZapColors.info;
      case ExportStatusV2.ready:      return ZapColors.safe;
      case ExportStatusV2.failed:     return ZapColors.danger;
      case ExportStatusV2.expired:    return ZapColors.textSecondary;
    }
  }
}

// ─── Export models ────────────────────────────────────────────────────────────

class ExportRequestV2 {
  const ExportRequestV2({
    required this.id,
    required this.status,
    required this.format,
    required this.requestedAt,
    required this.selectedSections,
    required this.totalItems,
    this.expiresAt,
    this.errorMessage,
  });

  final String             id;
  final ExportStatusV2     status;
  final ExportFormat       format;
  final DateTime           requestedAt;
  final List<String>       selectedSections;
  final int                totalItems;
  final DateTime?          expiresAt;
  final String?            errorMessage;

  bool get isExpired {
    if (status == ExportStatusV2.expired) {
      return true;
    }
    if (expiresAt == null) {
      return false;
    }
    return DateTime.now().isAfter(expiresAt!);
  }

  bool get isViewable => status == ExportStatusV2.ready && !isExpired;

  ExportRequestV2 copyWith({
    ExportStatusV2? status,
    DateTime?       expiresAt,
  }) {
    return ExportRequestV2(
      id:               id,
      status:           status      ?? this.status,
      format:           format,
      requestedAt:      requestedAt,
      selectedSections: selectedSections,
      totalItems:       totalItems,
      expiresAt:        expiresAt   ?? this.expiresAt,
      errorMessage:     errorMessage,
    );
  }
}

class ExportStateV2 {
  const ExportStateV2({
    required this.requests,
    required this.selectedSections,
    required this.format,
    required this.isCreating,
  });

  final List<ExportRequestV2> requests;
  final Set<String>           selectedSections;
  final ExportFormat          format;
  final bool                  isCreating;

  int get totalSelectedItems => kExportSections
      .where((s) => selectedSections.contains(s.id))
      .fold(0, (sum, s) => sum + s.itemCount);

  ExportStateV2 copyWith({
    List<ExportRequestV2>? requests,
    Set<String>?           selectedSections,
    ExportFormat?          format,
    bool?                  isCreating,
  }) {
    return ExportStateV2(
      requests:         requests         ?? this.requests,
      selectedSections: selectedSections ?? this.selectedSections,
      format:           format           ?? this.format,
      isCreating:       isCreating       ?? this.isCreating,
    );
  }
}

ExportStateV2 _buildInitialExportState() {
  final now = DateTime.now();
  const allSections = <String>[
    'profile', 'notification_prefs', 'sos_templates',
    'check_ins', 'safe_zones', 'incidents', 'activity_log',
  ];
  return ExportStateV2(
    selectedSections: Set<String>.from(allSections),
    format: ExportFormat.zip,
    isCreating: false,
    requests: [
      ExportRequestV2(
        id: 'e01',
        status: ExportStatusV2.ready,
        format: ExportFormat.zip,
        requestedAt: now.subtract(const Duration(hours: 1)),
        selectedSections: allSections,
        totalItems: 59,
        expiresAt: now.add(const Duration(days: 6)),
      ),
      ExportRequestV2(
        id: 'e02',
        status: ExportStatusV2.expired,
        format: ExportFormat.json,
        requestedAt: now.subtract(const Duration(days: 8)),
        selectedSections: ['profile', 'sos_templates', 'activity_log'],
        totalItems: 37,
      ),
    ],
  );
}

// ─── Export notifier ─────────────────────────────────────────────────────────

class ExportNotifierV2 extends StateNotifier<ExportStateV2> {
  ExportNotifierV2() : super(_buildInitialExportState());

  void toggleSection(String id) {
    final next = Set<String>.from(state.selectedSections);
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }
    state = state.copyWith(selectedSections: next);
  }

  void selectAll() {
    state = state.copyWith(
      selectedSections: kExportSections.map((s) => s.id).toSet(),
    );
  }

  void setFormat(ExportFormat f) {
    state = state.copyWith(format: f);
  }

  Future<void> createExport() async {
    if (state.isCreating || state.selectedSections.isEmpty) {
      return;
    }
    state = state.copyWith(isCreating: true);
    await Future<void>.delayed(const Duration(milliseconds: 1200));

    final now    = DateTime.now();
    final reqId  = 'e${now.millisecondsSinceEpoch}';
    final newReq = ExportRequestV2(
      id:               reqId,
      status:           ExportStatusV2.processing,
      format:           state.format,
      requestedAt:      now,
      selectedSections: state.selectedSections.toList(),
      totalItems:       state.totalSelectedItems,
    );

    state = state.copyWith(
      requests:  [newReq, ...state.requests],
      isCreating: false,
    );

    // Simulate server processing
    await Future<void>.delayed(const Duration(seconds: 3));
    state = state.copyWith(
      requests: state.requests.map((r) {
        if (r.id == reqId) {
          return r.copyWith(
            status:    ExportStatusV2.ready,
            expiresAt: DateTime.now().add(const Duration(days: 7)),
          );
        }
        return r;
      }).toList(),
    );
  }
}

final exportV2Provider =
    StateNotifierProvider<ExportNotifierV2, ExportStateV2>(
  (ref) => ExportNotifierV2(),
);

// ─── Privacy models ───────────────────────────────────────────────────────────

class ConsentFlagV2 {
  const ConsentFlagV2({
    required this.id,
    required this.label,
    required this.description,
    required this.legalBasis,
    required this.enabled,
    this.lastChanged,
  });

  final String    id;
  final String    label;
  final String    description;
  final String    legalBasis;
  final bool      enabled;
  final DateTime? lastChanged;

  ConsentFlagV2 copyWith({bool? enabled, DateTime? lastChanged}) {
    return ConsentFlagV2(
      id:          id,
      label:       label,
      description: description,
      legalBasis:  legalBasis,
      enabled:     enabled     ?? this.enabled,
      lastChanged: lastChanged ?? this.lastChanged,
    );
  }
}

class DeletionRequestV2 {
  const DeletionRequestV2({
    required this.id,
    required this.status,
    required this.requestedAt,
    this.reason,
  });

  final String    id;
  final String    status;       // pending | acknowledged | completed
  final DateTime  requestedAt;
  final String?   reason;

  bool get isPending      => status == 'pending';
  bool get isCancellable  => status == 'pending';
}

class PrivacyStateV2 {
  const PrivacyStateV2({
    required this.flags,
    required this.isSubmittingDeletion,
    required this.isCancellingDeletion,
    this.deletionRequest,
  });

  final List<ConsentFlagV2>  flags;
  final DeletionRequestV2?   deletionRequest;
  final bool                 isSubmittingDeletion;
  final bool                 isCancellingDeletion;
}

List<ConsentFlagV2> _buildDefaultFlags() {
  final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));
  return [
    const ConsentFlagV2(
      id: 'analytics', label: 'Analytics & Crash Reports',
      description: 'Share anonymous usage data to improve ZapSafe',
      legalBasis: 'Legitimate interest (opt-in)',
      enabled: false,
    ),
    ConsentFlagV2(
      id: 'evidence_capture', label: 'Evidence Capture',
      description: 'Allow audio & photo capture during active SOS events',
      legalBasis: 'Vital interests (Article 6(1)(d) GDPR)',
      enabled: true,
      lastChanged: threeDaysAgo,
    ),
    const ConsentFlagV2(
      id: 'auto_archive_disabled', label: 'Disable Auto-Archive',
      description: 'Prevent SOS events from auto-archiving after 90 days',
      legalBasis: 'Data minimisation waiver',
      enabled: false,
    ),
    const ConsentFlagV2(
      id: 'location_sharing', label: 'Location History Sharing',
      description: 'Allow ZapSafe to retain GPS history beyond active SOS',
      legalBasis: 'Consent (Article 6(1)(a) GDPR)',
      enabled: false,
    ),
    const ConsentFlagV2(
      id: 'contact_data_sharing', label: 'Contact Data Sharing',
      description: 'Allow emergency contacts to view your protection status',
      legalBasis: 'Consent (Article 6(1)(a) GDPR)',
      enabled: false,
    ),
  ];
}

// ─── Privacy notifier ─────────────────────────────────────────────────────────

class PrivacyNotifierV2 extends StateNotifier<PrivacyStateV2> {
  PrivacyNotifierV2()
      : super(PrivacyStateV2(
          flags:                _buildDefaultFlags(),
          isSubmittingDeletion: false,
          isCancellingDeletion: false,
        ));

  void toggleFlag(String id) {
    state = PrivacyStateV2(
      flags: state.flags.map((f) {
        if (f.id == id) {
          return f.copyWith(enabled: !f.enabled, lastChanged: DateTime.now());
        }
        return f;
      }).toList(),
      deletionRequest:      state.deletionRequest,
      isSubmittingDeletion: state.isSubmittingDeletion,
      isCancellingDeletion: state.isCancellingDeletion,
    );
  }

  Future<void> submitDeletion(String? reason) async {
    state = PrivacyStateV2(
      flags:                state.flags,
      deletionRequest:      state.deletionRequest,
      isSubmittingDeletion: true,
      isCancellingDeletion: false,
    );
    await Future<void>.delayed(const Duration(milliseconds: 900));
    state = PrivacyStateV2(
      flags: state.flags,
      deletionRequest: DeletionRequestV2(
        id:          'del-${DateTime.now().millisecondsSinceEpoch}',
        status:      'pending',
        requestedAt: DateTime.now(),
        reason:      (reason != null && reason.isNotEmpty) ? reason : null,
      ),
      isSubmittingDeletion: false,
      isCancellingDeletion: false,
    );
  }

  Future<void> cancelDeletion() async {
    state = PrivacyStateV2(
      flags:                state.flags,
      deletionRequest:      state.deletionRequest,
      isSubmittingDeletion: false,
      isCancellingDeletion: true,
    );
    await Future<void>.delayed(const Duration(milliseconds: 700));
    state = PrivacyStateV2(
      flags:                state.flags,
      deletionRequest:      null,
      isSubmittingDeletion: false,
      isCancellingDeletion: false,
    );
  }
}

final privacyV2Provider =
    StateNotifierProvider<PrivacyNotifierV2, PrivacyStateV2>(
  (ref) => PrivacyNotifierV2(),
);
