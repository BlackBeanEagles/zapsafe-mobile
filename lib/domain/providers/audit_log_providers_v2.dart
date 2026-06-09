/// Day 89 — Activity Audit Log state (v2).
///
/// Self-contained mock Riverpod state — no API calls.
/// 32 mock entries across 4 days; category + text-search filtering.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';

// ─── Enums ────────────────────────────────────────────────────────────────────

enum AuditCategory { security, sos, contacts, settings, system }

extension AuditCategoryX on AuditCategory {
  String get label {
    switch (this) {
      case AuditCategory.security: return 'Security';
      case AuditCategory.sos:      return 'SOS';
      case AuditCategory.contacts: return 'Contacts';
      case AuditCategory.settings: return 'Settings';
      case AuditCategory.system:   return 'System';
    }
  }

  IconData get icon {
    switch (this) {
      case AuditCategory.security: return Icons.security_rounded;
      case AuditCategory.sos:      return Icons.sos_rounded;
      case AuditCategory.contacts: return Icons.people_rounded;
      case AuditCategory.settings: return Icons.tune_rounded;
      case AuditCategory.system:   return Icons.smartphone_rounded;
    }
  }

  Color get color {
    switch (this) {
      case AuditCategory.security: return ZapColors.warning;
      case AuditCategory.sos:      return ZapColors.danger;
      case AuditCategory.contacts: return ZapColors.safe;
      case AuditCategory.settings: return ZapColors.info;
      case AuditCategory.system:   return ZapColors.textSecondary;
    }
  }
}

enum AuditSeverity { info, warning, danger }

extension AuditSeverityX on AuditSeverity {
  Color get color {
    switch (this) {
      case AuditSeverity.info:    return ZapColors.info;
      case AuditSeverity.warning: return ZapColors.warning;
      case AuditSeverity.danger:  return ZapColors.danger;
    }
  }

  IconData get dotIcon {
    switch (this) {
      case AuditSeverity.info:    return Icons.circle;
      case AuditSeverity.warning: return Icons.warning_amber_rounded;
      case AuditSeverity.danger:  return Icons.error_rounded;
    }
  }
}

// ─── Model ────────────────────────────────────────────────────────────────────

class AuditEntryV2 {
  const AuditEntryV2({
    required this.id,
    required this.category,
    required this.eventType,
    required this.title,
    required this.timestamp,
    required this.severity,
    this.description,
    this.resourceLabel,
    this.ipAddress,
    this.details = const <String, String>{},
  });

  final String              id;
  final AuditCategory       category;
  final String              eventType;
  final String              title;
  final String?             description;
  final DateTime            timestamp;
  final AuditSeverity       severity;
  final String?             resourceLabel;
  final String?             ipAddress;
  final Map<String, String> details;
}

// ─── Stats model ─────────────────────────────────────────────────────────────

class AuditStatsV2 {
  const AuditStatsV2({
    required this.total,
    required this.today,
    required this.sosEvents,
    required this.critical,
  });
  final int total;
  final int today;
  final int sosEvents;
  final int critical;
}

// ─── Mock data ────────────────────────────────────────────────────────────────

List<AuditEntryV2> _buildMockEntries() {
  final now = DateTime.now();
  DateTime t(int daysAgo, int h, int m) =>
      DateTime(now.year, now.month, now.day - daysAgo, h, m);
  const ip1 = '192.168.1.42';
  const ip2 = '10.0.0.15';

  return [
    // ── Today ─────────────────────────────────────────────────────────────
    AuditEntryV2(
      id: 'a01', category: AuditCategory.system, eventType: 'app_open',
      title: 'App opened', timestamp: t(0, 9, 0),
      severity: AuditSeverity.info, ipAddress: ip1,
      details: const {'platform': 'Android', 'version': '2.4.1', 'build': '240'},
    ),
    AuditEntryV2(
      id: 'a02', category: AuditCategory.security, eventType: 'biometric_success',
      title: 'Biometric auth successful', timestamp: t(0, 9, 1),
      severity: AuditSeverity.info, ipAddress: ip1,
      details: const {'method': 'fingerprint', 'screen': 'vault'},
    ),
    AuditEntryV2(
      id: 'a03', category: AuditCategory.sos, eventType: 'sos_triggered',
      title: 'SOS triggered',
      description: 'Manual SOS — 3-press power button gesture',
      timestamp: t(0, 10, 15),
      severity: AuditSeverity.danger, ipAddress: ip1,
      resourceLabel: 'sos-20260528-001',
      details: const {
        'trigger': 'manual_press',
        'location': 'Connaught Place, New Delhi',
        'battery': '42%',
      },
    ),
    AuditEntryV2(
      id: 'a04', category: AuditCategory.sos, eventType: 'contacts_notified',
      title: 'Emergency contacts notified',
      description: '2 push + 1 SMS dispatched',
      timestamp: t(0, 10, 15),
      severity: AuditSeverity.info, ipAddress: ip1,
      resourceLabel: 'sos-20260528-001',
      details: const {
        'push': '2',
        'sms': '1',
        'recipients': 'Priya Sharma, Rahul Gupta',
      },
    ),
    AuditEntryV2(
      id: 'a05', category: AuditCategory.sos, eventType: 'sos_cancelled',
      title: 'SOS cancelled by user',
      timestamp: t(0, 10, 17),
      severity: AuditSeverity.warning, ipAddress: ip1,
      resourceLabel: 'sos-20260528-001',
      details: const {'cancel_method': 'cancel_button', 'elapsed_seconds': '120'},
    ),
    AuditEntryV2(
      id: 'a06', category: AuditCategory.sos, eventType: 'drill_started',
      title: 'Emergency drill started',
      timestamp: t(0, 11, 30),
      severity: AuditSeverity.info, ipAddress: ip1,
      details: const {'drill_type': 'full', 'contacts_included': 'tier1+tier2'},
    ),
    AuditEntryV2(
      id: 'a07', category: AuditCategory.sos, eventType: 'drill_completed',
      title: 'Emergency drill completed',
      description: 'Score: 84/100 — Grade B',
      timestamp: t(0, 11, 40),
      severity: AuditSeverity.info, ipAddress: ip1,
      details: const {'score': '84', 'grade': 'B', 'duration_seconds': '600'},
    ),
    AuditEntryV2(
      id: 'a08', category: AuditCategory.contacts, eventType: 'contact_tier_changed',
      title: 'Contact tier changed',
      description: 'Priya Sharma promoted to Tier 1',
      timestamp: t(0, 14, 20),
      severity: AuditSeverity.info, ipAddress: ip1,
      resourceLabel: 'contact · Priya Sharma',
      details: const {'from_tier': '2', 'to_tier': '1'},
    ),
    AuditEntryV2(
      id: 'a09', category: AuditCategory.settings, eventType: 'threshold_updated',
      title: 'Alert threshold updated',
      description: 'Scream model confidence set to 78%',
      timestamp: t(0, 15, 45),
      severity: AuditSeverity.info, ipAddress: ip1,
      resourceLabel: 'model · scream',
      details: const {'field': 'confidence', 'old_value': '70', 'new_value': '78'},
    ),
    AuditEntryV2(
      id: 'a10', category: AuditCategory.system, eventType: 'battery_warning',
      title: 'Battery warning notification sent',
      description: 'Battery dropped to 18%',
      timestamp: t(0, 16, 30),
      severity: AuditSeverity.warning, ipAddress: ip1,
      details: const {'battery_level': '18', 'notification_channel': 'push'},
    ),

    // ── Yesterday ─────────────────────────────────────────────────────────
    AuditEntryV2(
      id: 'a11', category: AuditCategory.system, eventType: 'app_open',
      title: 'App opened', timestamp: t(1, 8, 55),
      severity: AuditSeverity.info, ipAddress: ip2,
      details: const {'platform': 'Android', 'version': '2.4.1'},
    ),
    AuditEntryV2(
      id: 'a12', category: AuditCategory.security, eventType: 'export_requested',
      title: 'Data export requested',
      description: 'GDPR snapshot — all 7 data categories',
      timestamp: t(1, 9, 30),
      severity: AuditSeverity.info, ipAddress: ip2,
      details: const {'export_type': 'full', 'format': 'ZIP', 'expires_in': '7 days'},
    ),
    AuditEntryV2(
      id: 'a13', category: AuditCategory.security, eventType: 'pin_changed',
      title: 'Emergency PIN changed',
      timestamp: t(1, 10, 0),
      severity: AuditSeverity.info, ipAddress: ip2,
      details: const {'pin_type': 'emergency_sos', 'biometric_confirmed': 'true'},
    ),
    AuditEntryV2(
      id: 'a14', category: AuditCategory.contacts, eventType: 'contact_added',
      title: 'Emergency contact added',
      description: 'Anjali Mehta added as Tier 2',
      timestamp: t(1, 11, 15),
      severity: AuditSeverity.info, ipAddress: ip2,
      resourceLabel: 'contact · Anjali Mehta',
      details: const {'tier': '2', 'phone': '+919988776655', 'verified': 'false'},
    ),
    AuditEntryV2(
      id: 'a15', category: AuditCategory.sos, eventType: 'sos_triggered',
      title: 'SOS triggered',
      description: 'DCS auto-trigger — 3-window vote threshold exceeded',
      timestamp: t(1, 14, 0),
      severity: AuditSeverity.danger, ipAddress: ip2,
      resourceLabel: 'sos-20260527-003',
      details: const {'trigger': 'dcs_auto', 'dcs_score': '0.81', 'window_votes': '3/3'},
    ),
    AuditEntryV2(
      id: 'a16', category: AuditCategory.sos, eventType: 'sos_escalated',
      title: 'Tier 2 escalation triggered',
      description: 'Tier 1 did not respond within 30s',
      timestamp: t(1, 14, 1),
      severity: AuditSeverity.danger, ipAddress: ip2,
      resourceLabel: 'sos-20260527-003',
      details: const {
        'escalation_tier': '2',
        'timeout_seconds': '30',
        'contacts_added': '2',
      },
    ),
    AuditEntryV2(
      id: 'a17', category: AuditCategory.sos, eventType: 'sos_resolved',
      title: 'SOS resolved',
      description: 'User confirmed safety via PIN',
      timestamp: t(1, 14, 35),
      severity: AuditSeverity.info, ipAddress: ip2,
      resourceLabel: 'sos-20260527-003',
      details: const {
        'resolved_by': 'user_pin',
        'duration_minutes': '35',
        'contacts_confirmed': '2',
      },
    ),
    AuditEntryV2(
      id: 'a18', category: AuditCategory.settings, eventType: 'template_updated',
      title: 'SOS template updated',
      description: '"Standard SOS" body text edited',
      timestamp: t(1, 16, 0),
      severity: AuditSeverity.info, ipAddress: ip2,
      resourceLabel: 'template · Standard SOS',
      details: const {'field': 'body', 'char_count': '142', 'sms_segments': '1'},
    ),
    AuditEntryV2(
      id: 'a19', category: AuditCategory.settings, eventType: 'dnd_enabled',
      title: 'Do Not Disturb enabled',
      timestamp: t(1, 22, 0),
      severity: AuditSeverity.info, ipAddress: ip2,
      details: const {'start_hour': '22', 'end_hour': '7', 'sos_bypass': 'true'},
    ),

    // ── 2 days ago ────────────────────────────────────────────────────────
    AuditEntryV2(
      id: 'a20', category: AuditCategory.system, eventType: 'app_open',
      title: 'App opened', timestamp: t(2, 7, 30),
      severity: AuditSeverity.info, ipAddress: ip1,
      details: const {'platform': 'Android', 'version': '2.4.1'},
    ),
    AuditEntryV2(
      id: 'a21', category: AuditCategory.security, eventType: 'biometric_failed',
      title: 'Biometric authentication failed',
      description: 'Fingerprint not recognised — 1 attempt remaining',
      timestamp: t(2, 7, 31),
      severity: AuditSeverity.warning, ipAddress: ip1,
      details: const {'method': 'fingerprint', 'attempts_remaining': '1', 'screen': 'vault'},
    ),
    AuditEntryV2(
      id: 'a22', category: AuditCategory.security, eventType: 'biometric_success',
      title: 'Biometric auth successful',
      timestamp: t(2, 7, 32),
      severity: AuditSeverity.info, ipAddress: ip1,
      details: const {'method': 'fingerprint', 'screen': 'vault'},
    ),
    AuditEntryV2(
      id: 'a23', category: AuditCategory.contacts, eventType: 'contact_removed',
      title: 'Emergency contact removed',
      description: 'Rahul Gupta removed from Tier 2',
      timestamp: t(2, 9, 0),
      severity: AuditSeverity.warning, ipAddress: ip1,
      resourceLabel: 'contact · Rahul Gupta',
      details: const {'tier': '2', 'confirmed_by': 'biometric'},
    ),
    AuditEntryV2(
      id: 'a24', category: AuditCategory.settings, eventType: 'escalation_policy_changed',
      title: 'Default escalation policy changed',
      description: '"High Risk" set as default policy',
      timestamp: t(2, 10, 30),
      severity: AuditSeverity.info, ipAddress: ip1,
      resourceLabel: 'policy · High Risk',
      details: const {'old_default': 'Quick Response', 'new_default': 'High Risk'},
    ),
    AuditEntryV2(
      id: 'a25', category: AuditCategory.sos, eventType: 'check_in_expired',
      title: 'Check-in timer expired',
      description: "Dead-man's switch triggered — SMS sent to Tier 1",
      timestamp: t(2, 20, 0),
      severity: AuditSeverity.danger, ipAddress: ip1,
      details: const {'timer_minutes': '120', 'sms_sent': 'true', 'contact': 'Priya Sharma'},
    ),
    AuditEntryV2(
      id: 'a26', category: AuditCategory.system, eventType: 'evidence_backup',
      title: 'Evidence vault backup started',
      timestamp: t(2, 23, 0),
      severity: AuditSeverity.info, ipAddress: ip1,
      details: const {'size_mb': '42', 'sos_events': '3', 'destination': 'encrypted_local'},
    ),

    // ── 3 days ago ────────────────────────────────────────────────────────
    AuditEntryV2(
      id: 'a27', category: AuditCategory.system, eventType: 'system_restart',
      title: 'Background service restarted',
      description: 'Auto-restart after device reboot',
      timestamp: t(3, 8, 0),
      severity: AuditSeverity.info, ipAddress: ip1,
      details: const {'reason': 'device_reboot', 'startup_ms': '340'},
    ),
    AuditEntryV2(
      id: 'a28', category: AuditCategory.security, eventType: 'pin_wrong_attempt',
      title: 'Wrong PIN entered',
      description: 'Incorrect emergency PIN — 2 attempts remaining',
      timestamp: t(3, 9, 1),
      severity: AuditSeverity.danger, ipAddress: ip1,
      details: const {'pin_type': 'emergency_sos', 'attempts_remaining': '2'},
    ),
    AuditEntryV2(
      id: 'a29', category: AuditCategory.sos, eventType: 'drill_reminder',
      title: 'Weekly drill reminder sent',
      timestamp: t(3, 9, 30),
      severity: AuditSeverity.info, ipAddress: ip1,
      details: const {'drill_due': 'today', 'last_drill_score': '72'},
    ),
    AuditEntryV2(
      id: 'a30', category: AuditCategory.contacts, eventType: 'contact_added',
      title: 'Emergency contact added',
      description: 'Vikram Nair added as Tier 2',
      timestamp: t(3, 10, 0),
      severity: AuditSeverity.info, ipAddress: ip1,
      resourceLabel: 'contact · Vikram Nair',
      details: const {'tier': '2', 'phone': '+919123456789', 'verified': 'false'},
    ),
    AuditEntryV2(
      id: 'a31', category: AuditCategory.security, eventType: 'export_expired',
      title: 'Export link expired',
      description: 'Previous 7-day export window ended',
      timestamp: t(3, 12, 0),
      severity: AuditSeverity.warning, ipAddress: ip1,
      details: const {'export_date': '3 days prior', 'export_type': 'full'},
    ),
    AuditEntryV2(
      id: 'a32', category: AuditCategory.settings, eventType: 'dnd_disabled',
      title: 'Do Not Disturb disabled',
      timestamp: t(3, 21, 0),
      severity: AuditSeverity.info, ipAddress: ip1,
      details: const {'disabled_by': 'schedule_end'},
    ),
  ];
}

// ─── Providers ────────────────────────────────────────────────────────────────

/// Full immutable log — 32 mock entries.
final auditLogV2Provider = Provider<List<AuditEntryV2>>(
    (ref) => _buildMockEntries());

/// null = all categories.
final auditCategoryFilterV2Provider =
    StateProvider<AuditCategory?>((ref) => null);

/// '' = no search query.
final auditSearchV2Provider = StateProvider<String>((ref) => '');

/// Derived stats from the full (unfiltered) log.
final auditStatsV2Provider = Provider<AuditStatsV2>((ref) {
  final all = ref.watch(auditLogV2Provider);
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  return AuditStatsV2(
    total:     all.length,
    today:     all.where((e) => e.timestamp.isAfter(todayStart)).length,
    sosEvents: all.where((e) => e.category == AuditCategory.sos).length,
    critical:  all.where((e) => e.severity == AuditSeverity.danger).length,
  );
});

/// Filtered + searched list for the UI.
final filteredAuditLogV2Provider = Provider<List<AuditEntryV2>>((ref) {
  final all   = ref.watch(auditLogV2Provider);
  final cat   = ref.watch(auditCategoryFilterV2Provider);
  final query = ref.watch(auditSearchV2Provider).trim().toLowerCase();

  return all.where((e) {
    if (cat != null && e.category != cat) {
      return false;
    }
    if (query.isNotEmpty) {
      final hay =
          '${e.title} ${e.description ?? ''} ${e.eventType}'.toLowerCase();
      if (!hay.contains(query)) {
        return false;
      }
    }
    return true;
  }).toList();
});
