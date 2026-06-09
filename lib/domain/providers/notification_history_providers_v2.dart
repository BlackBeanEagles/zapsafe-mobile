/// Day 88 — Notification History state (v2).
///
/// Self-contained mock Riverpod state — no API calls.
/// Covers push + SMS history with delivery timeline data.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';

// ─── Enums ────────────────────────────────────────────────────────────────────

enum NotifChannel { push, sms }

extension NotifChannelX on NotifChannel {
  String get label {
    switch (this) {
      case NotifChannel.push: return 'Push';
      case NotifChannel.sms:  return 'SMS';
    }
  }

  IconData get icon {
    switch (this) {
      case NotifChannel.push: return Icons.notifications_rounded;
      case NotifChannel.sms:  return Icons.sms_rounded;
    }
  }

  Color get color {
    switch (this) {
      case NotifChannel.push: return ZapColors.info;
      case NotifChannel.sms:  return ZapColors.warning;
    }
  }
}

enum NotifStatus { sent, delivered, failed, acked }

extension NotifStatusX on NotifStatus {
  String get label {
    switch (this) {
      case NotifStatus.sent:      return 'Sent';
      case NotifStatus.delivered: return 'Delivered';
      case NotifStatus.failed:    return 'Failed';
      case NotifStatus.acked:     return 'Opened';
    }
  }

  Color get color {
    switch (this) {
      case NotifStatus.sent:      return ZapColors.warning;
      case NotifStatus.delivered: return ZapColors.safe;
      case NotifStatus.failed:    return ZapColors.danger;
      case NotifStatus.acked:     return ZapColors.safe;
    }
  }
}

enum NotifType { sosAlert, checkIn, batteryWarning, drillReminder, system }

extension NotifTypeX on NotifType {
  String get label {
    switch (this) {
      case NotifType.sosAlert:       return 'SOS Alert';
      case NotifType.checkIn:        return 'Check-in';
      case NotifType.batteryWarning: return 'Battery Warning';
      case NotifType.drillReminder:  return 'Drill Reminder';
      case NotifType.system:         return 'System';
    }
  }

  IconData get icon {
    switch (this) {
      case NotifType.sosAlert:       return Icons.sos_rounded;
      case NotifType.checkIn:        return Icons.check_circle_outline_rounded;
      case NotifType.batteryWarning: return Icons.battery_alert_rounded;
      case NotifType.drillReminder:  return Icons.fitness_center_rounded;
      case NotifType.system:         return Icons.info_outline_rounded;
    }
  }
}

// ─── Model ────────────────────────────────────────────────────────────────────

class NotifEntry {
  const NotifEntry({
    required this.id,
    required this.recipientName,
    required this.recipientPhone,
    required this.channel,
    required this.status,
    required this.type,
    required this.title,
    required this.body,
    required this.sentAt,
    this.deliveredAt,
    this.ackedAt,
    this.sosEventId,
    this.errorMessage,
  });

  final String       id;
  final String       recipientName;
  final String       recipientPhone;
  final NotifChannel channel;
  final NotifStatus  status;
  final NotifType    type;
  final String       title;
  final String       body;
  final DateTime     sentAt;
  final DateTime?    deliveredAt;
  final DateTime?    ackedAt;
  final String?      sosEventId;
  final String?      errorMessage;

  NotifEntry copyWith({NotifStatus? status, DateTime? deliveredAt}) {
    return NotifEntry(
      id:            id,
      recipientName: recipientName,
      recipientPhone: recipientPhone,
      channel:       channel,
      status:        status        ?? this.status,
      type:          type,
      title:         title,
      body:          body,
      sentAt:        sentAt,
      deliveredAt:   deliveredAt   ?? this.deliveredAt,
      ackedAt:       ackedAt,
      sosEventId:    sosEventId,
      errorMessage:  errorMessage,
    );
  }
}

// ─── Mock data ────────────────────────────────────────────────────────────────

List<NotifEntry> _buildMockEntries() {
  final now = DateTime.now();
  DateTime today(int h, int m) =>
      DateTime(now.year, now.month, now.day, h, m);
  DateTime daysAgo(int d, int h, int m) =>
      DateTime(now.year, now.month, now.day - d, h, m);

  return [
    // ── Today ──────────────────────────────────────────────────────────────
    NotifEntry(
      id:            'n01',
      recipientName: 'Priya Sharma',
      recipientPhone: '+919876543210',
      channel:       NotifChannel.push,
      status:        NotifStatus.acked,
      type:          NotifType.sosAlert,
      title:         'SOS Alert — You triggered an SOS',
      body:          'Your SOS is active. Notifying Priya Sharma. Tap to manage.',
      sentAt:        today(10, 15),
      deliveredAt:   today(10, 15).add(const Duration(seconds: 3)),
      ackedAt:       today(10, 16).add(const Duration(seconds: 12)),
      sosEventId:    'sos-20260528-001',
    ),
    NotifEntry(
      id:            'n02',
      recipientName: 'Priya Sharma',
      recipientPhone: '+919876543210',
      channel:       NotifChannel.sms,
      status:        NotifStatus.delivered,
      type:          NotifType.sosAlert,
      title:         'ZapSafe SOS',
      body:          'HELP! I\'m in danger. My location: Connaught Place, New Delhi. Time: 10:15 IST. Battery: 42%.',
      sentAt:        today(10, 15).add(const Duration(seconds: 1)),
      deliveredAt:   today(10, 15).add(const Duration(seconds: 9)),
      ackedAt:       null,
      sosEventId:    'sos-20260528-001',
    ),
    NotifEntry(
      id:            'n03',
      recipientName: 'Rahul Gupta',
      recipientPhone: '+919812345678',
      channel:       NotifChannel.push,
      status:        NotifStatus.failed,
      type:          NotifType.sosAlert,
      title:         'SOS Alert — Urgent',
      body:          'Push delivery failed.',
      sentAt:        today(10, 15).add(const Duration(seconds: 2)),
      deliveredAt:   null,
      ackedAt:       null,
      sosEventId:    'sos-20260528-001',
      errorMessage:  'FCM token expired — contact has not opened the app recently.',
    ),
    NotifEntry(
      id:            'n04',
      recipientName: 'Priya Sharma',
      recipientPhone: '+919876543210',
      channel:       NotifChannel.push,
      status:        NotifStatus.sent,
      type:          NotifType.batteryWarning,
      title:         'Battery Warning',
      body:          'Your battery is at 18%. ZapSafe protection may stop soon.',
      sentAt:        now.subtract(const Duration(minutes: 45)),
      deliveredAt:   null,
      ackedAt:       null,
    ),

    // ── Yesterday ───────────────────────────────────────────────────────────
    NotifEntry(
      id:            'n05',
      recipientName: 'Priya Sharma',
      recipientPhone: '+919876543210',
      channel:       NotifChannel.push,
      status:        NotifStatus.acked,
      type:          NotifType.drillReminder,
      title:         'Emergency Drill Reminder',
      body:          'Your weekly drill is scheduled for today at 09:00. Tap to start.',
      sentAt:        daysAgo(1, 8, 55),
      deliveredAt:   daysAgo(1, 8, 55).add(const Duration(seconds: 2)),
      ackedAt:       daysAgo(1, 9, 3),
    ),
    NotifEntry(
      id:            'n06',
      recipientName: 'Anjali Mehta',
      recipientPhone: '+919988776655',
      channel:       NotifChannel.sms,
      status:        NotifStatus.delivered,
      type:          NotifType.checkIn,
      title:         'ZapSafe Check-in',
      body:          'Your check-in timer expired. Please confirm you are safe.',
      sentAt:        daysAgo(1, 20, 30),
      deliveredAt:   daysAgo(1, 20, 30).add(const Duration(seconds: 11)),
      ackedAt:       null,
    ),
    NotifEntry(
      id:            'n07',
      recipientName: 'Vikram Nair',
      recipientPhone: '+919123456789',
      channel:       NotifChannel.push,
      status:        NotifStatus.delivered,
      type:          NotifType.sosAlert,
      title:         'SOS Alert — Tier 2 escalation',
      body:          'Tier 1 contact did not respond. Notifying Tier 2 contacts.',
      sentAt:        daysAgo(1, 14, 0),
      deliveredAt:   daysAgo(1, 14, 0).add(const Duration(seconds: 4)),
      ackedAt:       null,
      sosEventId:    'sos-20260527-003',
    ),
    NotifEntry(
      id:            'n08',
      recipientName: 'Priya Sharma',
      recipientPhone: '+919876543210',
      channel:       NotifChannel.push,
      status:        NotifStatus.acked,
      type:          NotifType.system,
      title:         'ZapSafe — Protection resumed',
      body:          'Background service restarted after device reboot.',
      sentAt:        daysAgo(1, 8, 0),
      deliveredAt:   daysAgo(1, 8, 0).add(const Duration(seconds: 1)),
      ackedAt:       daysAgo(1, 8, 2),
    ),

    // ── 2 days ago ──────────────────────────────────────────────────────────
    NotifEntry(
      id:            'n09',
      recipientName: 'Rahul Gupta',
      recipientPhone: '+919812345678',
      channel:       NotifChannel.sms,
      status:        NotifStatus.delivered,
      type:          NotifType.sosAlert,
      title:         'ZapSafe SOS',
      body:          'MEDICAL EMERGENCY at Connaught Place, New Delhi. Please call an ambulance immediately. Time: 11:30 IST.',
      sentAt:        daysAgo(2, 11, 30),
      deliveredAt:   daysAgo(2, 11, 30).add(const Duration(seconds: 14)),
      ackedAt:       null,
      sosEventId:    'sos-20260526-002',
    ),
    NotifEntry(
      id:            'n10',
      recipientName: 'Priya Sharma',
      recipientPhone: '+919876543210',
      channel:       NotifChannel.sms,
      status:        NotifStatus.failed,
      type:          NotifType.batteryWarning,
      title:         'ZapSafe Battery Alert',
      body:          'Battery critical — 8%. GPS tracking may stop.',
      sentAt:        daysAgo(2, 16, 45),
      deliveredAt:   null,
      ackedAt:       null,
      errorMessage:  'Carrier rejected — message flagged as spam.',
    ),

    // ── 3 days ago ──────────────────────────────────────────────────────────
    NotifEntry(
      id:            'n11',
      recipientName: 'Anjali Mehta',
      recipientPhone: '+919988776655',
      channel:       NotifChannel.push,
      status:        NotifStatus.acked,
      type:          NotifType.checkIn,
      title:         'Check-in Confirmation',
      body:          'Anjali confirmed check-in. All contacts notified.',
      sentAt:        daysAgo(3, 22, 0),
      deliveredAt:   daysAgo(3, 22, 0).add(const Duration(seconds: 2)),
      ackedAt:       daysAgo(3, 22, 0).add(const Duration(seconds: 38)),
    ),
    NotifEntry(
      id:            'n12',
      recipientName: 'Vikram Nair',
      recipientPhone: '+919123456789',
      channel:       NotifChannel.push,
      status:        NotifStatus.failed,
      type:          NotifType.sosAlert,
      title:         'SOS Alert — Urgent',
      body:          'Failed to deliver SOS push notification.',
      sentAt:        daysAgo(3, 9, 15),
      deliveredAt:   null,
      ackedAt:       null,
      sosEventId:    'sos-20260525-001',
      errorMessage:  'App not installed on device.',
    ),
  ];
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class NotifHistoryNotifier extends StateNotifier<List<NotifEntry>> {
  NotifHistoryNotifier() : super(_buildMockEntries());

  void retry(String id) {
    state = [
      for (final e in state)
        e.id == id ? e.copyWith(status: NotifStatus.sent) : e,
    ];
  }

  void clearAll() {
    state = [];
  }
}

// ─── Providers ────────────────────────────────────────────────────────────────

final notifHistoryProvider =
    StateNotifierProvider<NotifHistoryNotifier, List<NotifEntry>>(
  (ref) => NotifHistoryNotifier(),
);

/// null = show all channels.
final notifChannelFilterProvider = StateProvider<NotifChannel?>((ref) => null);

/// null = show all statuses.
final notifStatusFilterProvider = StateProvider<NotifStatus?>((ref) => null);

/// Filtered list derived from the two filter providers.
final filteredNotifProvider = Provider<List<NotifEntry>>((ref) {
  final all     = ref.watch(notifHistoryProvider);
  final channel = ref.watch(notifChannelFilterProvider);
  final status  = ref.watch(notifStatusFilterProvider);
  return all.where((e) {
    if (channel != null && e.channel != channel) { return false; }
    if (status  != null && e.status  != status)  { return false; }
    return true;
  }).toList();
});
