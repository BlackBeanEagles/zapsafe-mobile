/// Day 170 — Account Deletion: Grace Period UI
///
/// Second day of the Days 169-172 Account Deletion block.
/// Day 169: Deletion request — warnings, reason, re-auth, submit  ✅
/// Day 170: Grace period UI — countdown ring, account status,
///           emergency contact notifications, cancel flow.
/// Day 171: Permanent deletion confirmation + account wiped state.
/// Day 172: Edge cases — active SOS, evidence hold, DPDP retention.
///
/// 🟡 MOCK-NOW — backend at Day 78. No deletion-status endpoint yet.
///    All state is simulated. Replace _GracePeriodService calls when ready.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _activeTabProvider      = StateProvider<int>((ref) => 0);
final _daysRemainingProvider  = StateProvider<int>((ref) => 18);      // slider
final _cancelStepProvider     = StateProvider<_CancelStep>((ref) => _CancelStep.idle);
final _cancelConfirmProvider  = StateProvider<bool>((ref) => false);
final _cancelStateProvider    = StateProvider<_CancelState>((ref) => _CancelState.idle);
final _expandedNotifProvider  = StateProvider<int?>((ref) => null);

// ── Enums ──────────────────────────────────────────────────────────────────────
enum _CancelStep  { idle, confirm }
enum _CancelState { idle, cancelling, done, error }

// ── Data ───────────────────────────────────────────────────────────────────────
class _ContactNotif {
  final String   name;
  final String   tier;
  final String   phone;
  final DateTime sentAt;
  final bool     delivered;
  final String   message;
  const _ContactNotif({
    required this.name, required this.tier, required this.phone,
    required this.sentAt, required this.delivered, required this.message,
  });
}

final _kNotifications = [
  _ContactNotif(
    name: 'Rahul Sharma', tier: 'Tier 1', phone: '+91 98111 ****',
    sentAt: DateTime(2026, 5, 30, 14, 31),
    delivered: true,
    message: 'Hi Rahul, Priya Sharma has chosen to close their ZapSafe account. '
        'Their account will be permanently deleted on June 29, 2026. '
        'If you have any concerns, please reach out to them directly. '
        'You will be removed from their emergency contact list on that date. '
        '— The ZapSafe Team',
  ),
  _ContactNotif(
    name: 'Aarti Patel', tier: 'Tier 2', phone: '+91 99000 ****',
    sentAt: DateTime(2026, 5, 30, 14, 31),
    delivered: true,
    message: 'Hi Aarti, Priya Sharma has chosen to close their ZapSafe account. '
        'Their account will be permanently deleted on June 29, 2026. '
        'You will be removed from their emergency contact list on that date. '
        '— The ZapSafe Team',
  ),
  _ContactNotif(
    name: 'Sunita Rao', tier: 'Tier 2', phone: '+91 97700 ****',
    sentAt: DateTime(2026, 5, 30, 14, 31),
    delivered: false,  // delivery failure example
    message: 'Hi Sunita, Priya Sharma has chosen to close their ZapSafe account. '
        'Their account will be permanently deleted on June 29, 2026. '
        '— The ZapSafe Team',
  ),
];

class _StatusItem {
  final IconData icon;
  final Color    color;
  final String   label;
  final String   detail;
  final bool     available; // true = green available, false = red blocked
  const _StatusItem({
    required this.icon, required this.color, required this.label,
    required this.detail, required this.available,
  });
}

const _kStatusItems = [
  _StatusItem(
    icon: Icons.download_rounded, color: Color(0xFF10B981),
    label: 'Download My Data', detail: 'Still available — export link valid until deletion',
    available: true,
  ),
  _StatusItem(
    icon: Icons.history_rounded, color: Color(0xFF10B981),
    label: 'View SOS History', detail: 'Read-only access — no new events will be created',
    available: true,
  ),
  _StatusItem(
    icon: Icons.lock_rounded, color: Color(0xFF10B981),
    label: 'Evidence Vault', detail: 'Read-only access — download before day 30',
    available: true,
  ),
  _StatusItem(
    icon: Icons.warning_rounded, color: Color(0xFFEF4444),
    label: 'SOS Protection', detail: 'DISABLED — account is suspended. Uninstall ZapSafe and use emergency services.',
    available: false,
  ),
  _StatusItem(
    icon: Icons.people_rounded, color: Color(0xFFEF4444),
    label: 'Emergency Contacts', detail: 'DISABLED — contacts cannot be notified during grace period',
    available: false,
  ),
  _StatusItem(
    icon: Icons.notifications_rounded, color: Color(0xFFEF4444),
    label: 'Check-in Timers', detail: 'DISABLED — no new timers. Existing timers cancelled.',
    available: false,
  ),
  _StatusItem(
    icon: Icons.settings_rounded, color: Color(0xFFF59E0B),
    label: 'Account Settings', detail: 'LIMITED — only cancel deletion and download data',
    available: true,
  ),
];

// ── Mock service ───────────────────────────────────────────────────────────────
class _GracePeriodService {
  /// Simulates DELETE /api/v1/account/deletion-request
  static Future<void> cancelDeletion() =>
      Future.delayed(const Duration(milliseconds: 1400));
}

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day170AccountDeletionGraceScreen extends ConsumerWidget {
  const Day170AccountDeletionGraceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_activeTabProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Account Deletion — Grace Period'),
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: ZapSpacing.md, top: 8, bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
            ),
            child: const Text('GRACE PERIOD ⏳',
                style: TextStyle(color: Color(0xFFF59E0B), fontSize: 10,
                    fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Hero(),
            const SizedBox(height: ZapSpacing.xl),
            const _SectionLabel('SELECT VIEW'),
            const SizedBox(height: ZapSpacing.md),
            _TabBar(
                active: tab,
                onSelect: (t) => ref.read(_activeTabProvider.notifier).state = t),
            const SizedBox(height: ZapSpacing.xl),
            if (tab == 0) const _CountdownTab(),
            if (tab == 1) const _NotificationsTab(),
            if (tab == 2) const _CancelTab(),
            const SizedBox(height: ZapSpacing.huge),
          ],
        ),
      ),
    );
  }
}

// ── Hero ───────────────────────────────────────────────────────────────────────
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF120E05), Color(0xFF0A0805), Color(0xFF0A0A0A)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.55), width: 2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: ZapSpacing.sm, runSpacing: ZapSpacing.sm, children: [
          _badge('⚡  DAY 170',          const Color(0xFFF59E0B)),
          _badge('🟡 MOCK-NOW',          const Color(0xFFF59E0B)),
          _badge('Account Deletion  ·  Day 2/4', const Color(0xFF8B5CF6)),
        ]),
        const SizedBox(height: ZapSpacing.md),
        const Text('30-Day Grace Period\nDashboard',
            style: TextStyle(color: Colors.white, fontSize: 26,
                fontWeight: FontWeight.w900, height: 1.2)),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          'Your account is suspended but data is intact. '
          'SOS protection is disabled. You can still download '
          'your data or cancel the deletion before day 30.',
          style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6)),
        const SizedBox(height: ZapSpacing.md),
        const Row(children: [
          _HStat('30d',  'Grace window',   Color(0xFFF59E0B)),
          _HStat('3',    'Contacts notified', Color(0xFF3B82F6)),
          _HStat('3/7',  'Features available', Color(0xFF10B981)),
          _HStat('↩',    'Cancellable',    Color(0xFF10B981)),
        ]),
      ]),
    );
  }

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.4))),
        child: Text(label, style: TextStyle(color: color, fontSize: 11,
            fontWeight: FontWeight.w700, letterSpacing: 0.5)));
}

class _HStat extends StatelessWidget {
  final String value, label; final Color color;
  const _HStat(this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value, style: TextStyle(color: color, fontSize: 13,
              fontWeight: FontWeight.w800), textAlign: TextAlign.center),
          Text(label, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 9),
              textAlign: TextAlign.center),
        ]));
}

// ── Shared labels / TabBar ─────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);
  @override
  Widget build(BuildContext context) => Text(label,
      style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10,
          fontWeight: FontWeight.w700, letterSpacing: 1.5));
}

class _TabBar extends StatelessWidget {
  final int active; final ValueChanged<int> onSelect;
  const _TabBar({required this.active, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.timer_rounded,          Color(0xFFF59E0B), 'Countdown'),
      (Icons.notifications_rounded,  Color(0xFF3B82F6), 'Notifications'),
      (Icons.undo_rounded,           Color(0xFF10B981), 'Cancel Deletion'),
    ];
    return Row(children: List.generate(3, (i) {
      final (icon, color, label) = items[i];
      final isActive = i == active;
      return Expanded(
        child: GestureDetector(
          onTap: () => onSelect(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: EdgeInsets.only(right: i < 2 ? ZapSpacing.sm : 0),
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
                color: isActive ? color.withOpacity(0.12) : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                    color: isActive ? color.withOpacity(0.5) : const Color(0xFF2A2A2A),
                    width: isActive ? 2 : 1)),
            child: Column(children: [
              Icon(icon, color: isActive ? color : const Color(0xFF6B7280), size: 18),
              const SizedBox(height: ZapSpacing.xs),
              Text(label, style: TextStyle(
                  color: isActive ? color : const Color(0xFF6B7280),
                  fontSize: 9,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w400)),
            ]),
          ),
        ),
      );
    }));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 1 — Countdown
// ══════════════════════════════════════════════════════════════════════════════
class _CountdownTab extends ConsumerWidget {
  const _CountdownTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(_daysRemainingProvider);
    final progress = days / 30.0;

    // Compute urgency color
    final color = days <= 3
        ? const Color(0xFFEF4444)
        : days <= 7
            ? const Color(0xFFF59E0B)
            : const Color(0xFF10B981);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.info_outline_rounded, color: const Color(0xFFF59E0B),
          text: 'Your account is in the 30-day grace period. Data is intact. '
              'SOS is disabled. Drag the slider to preview different day states.'),
      const SizedBox(height: ZapSpacing.lg),

      // ── Big countdown ring ─────────────────────────────────────────
      Center(
        child: _CountdownRing(
            days: days, progress: progress, color: color),
      ),
      const SizedBox(height: ZapSpacing.lg),

      // ── Slider for demo ────────────────────────────────────────────
      const _SectionLabel('DEMO SLIDER  ·  DRAG TO PREVIEW STATES'),
      const SizedBox(height: ZapSpacing.sm),
      Row(children: [
        Text('$days days left',
            style: TextStyle(color: color, fontSize: 12,
                fontWeight: FontWeight.w700)),
        Expanded(child: Slider(
          value: days.toDouble(),
          min: 0, max: 30, divisions: 30,
          activeColor: color,
          inactiveColor: const Color(0xFF2A2A2A),
          onChanged: (v) =>
              ref.read(_daysRemainingProvider.notifier).state = v.round(),
        )),
        const Text('30', style: TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
      ]),
      const SizedBox(height: ZapSpacing.lg),

      // ── Urgency banner ─────────────────────────────────────────────
      _UrgencyBanner(days: days, color: color),
      const SizedBox(height: ZapSpacing.lg),

      // ── Key dates ─────────────────────────────────────────────────
      const _SectionLabel('KEY DATES'),
      const SizedBox(height: ZapSpacing.md),
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A))),
        child: Column(children: [
          _dateRow('Request submitted', 'May 30, 2026', const Color(0xFFEF4444)),
          const Divider(height: 16, color: Color(0xFF2A2A2A)),
          _dateRow('Grace period ends', 'June 29, 2026', color),
          const Divider(height: 16, color: Color(0xFF2A2A2A)),
          _dateRow('Hard delete executes', 'June 29, 2026  23:59', const Color(0xFF6B7280)),
          const Divider(height: 16, color: Color(0xFF2A2A2A)),
          _dateRow('Last export available', 'June 29, 2026', const Color(0xFF8B5CF6)),
        ]),
      ),
      const SizedBox(height: ZapSpacing.xl),

      // ── Feature availability ───────────────────────────────────────
      const _SectionLabel('ACCOUNT STATUS  ·  WHAT\'S AVAILABLE'),
      const SizedBox(height: ZapSpacing.md),
      ..._kStatusItems.map((item) => Container(
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            padding: const EdgeInsets.symmetric(
                horizontal: ZapSpacing.md, vertical: 12),
            decoration: BoxDecoration(
                color: item.available
                    ? item.color.withOpacity(0.06)
                    : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                    color: item.available
                        ? item.color.withOpacity(0.25)
                        : const Color(0xFF2A2A2A))),
            child: Row(children: [
              Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                      color: item.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(item.icon, color: item.color, size: 15)),
              const SizedBox(width: ZapSpacing.md),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.label, style: const TextStyle(
                    color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                Text(item.detail, style: const TextStyle(
                    color: Color(0xFF6B7280), fontSize: 10, height: 1.4)),
              ])),
              Icon(
                item.available ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: item.available ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                size: 16),
            ])),
          ),
      const SizedBox(height: ZapSpacing.xl),

      // ── Export reminder ────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFF8B5CF6).withOpacity(0.07),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.35))),
        child: Row(children: [
          const Icon(Icons.download_rounded, color: Color(0xFF8B5CF6), size: 20),
          const SizedBox(width: ZapSpacing.md),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Download your data before deletion',
                style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 12,
                    fontWeight: FontWeight.w700)),
            const Text(
                'Settings → Download My Data → Request ZIP export.',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
          ])),
          const Icon(Icons.chevron_right_rounded,
              color: Color(0xFF4B5563), size: 18),
        ]),
      ),
    ]);
  }

  static Widget _dateRow(String label, String value, Color color) =>
      Row(children: [
        Container(width: 10, height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: ZapSpacing.md),
        Expanded(child: Text(label, style: const TextStyle(
            color: Color(0xFF9CA3AF), fontSize: 11))),
        Text(value, style: TextStyle(color: color, fontSize: 11,
            fontWeight: FontWeight.w600)),
      ]);
}

// ── Countdown ring widget ─────────────────────────────────────────────────────
class _CountdownRing extends StatelessWidget {
  final int days;
  final double progress;
  final Color color;
  const _CountdownRing({required this.days, required this.progress, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200, height: 200,
      child: Stack(alignment: Alignment.center, children: [
        // Background circle
        SizedBox(width: 200, height: 200,
            child: CircularProgressIndicator(
                value: 1.0,
                strokeWidth: 12,
                valueColor: AlwaysStoppedAnimation(
                    const Color(0xFF2A2A2A)))),
        // Progress arc (days elapsed = 1 - progress)
        SizedBox(width: 200, height: 200,
            child: CircularProgressIndicator(
                value: 1 - progress,
                strokeWidth: 12,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation(color))),
        // Inner content
        Column(mainAxisSize: MainAxisSize.min, children: [
          Text('$days',
              style: TextStyle(color: color, fontSize: 54,
                  fontWeight: FontWeight.w900, height: 1.0)),
          Text('days remaining',
              style: TextStyle(color: color.withOpacity(0.8),
                  fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: ZapSpacing.xs),
          Text('of 30', style: const TextStyle(
              color: Color(0xFF4B5563), fontSize: 10)),
          const SizedBox(height: 6),
          // Remaining seconds/hours label
          if (days == 0)
            const Text('🔴 DELETING TODAY',
                style: TextStyle(color: Color(0xFFEF4444), fontSize: 10,
                    fontWeight: FontWeight.w800))
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Text('${30 - days} days elapsed',
                  style: TextStyle(color: color, fontSize: 9,
                      fontWeight: FontWeight.w700))),
        ]),
      ]),
    );
  }
}

// ── Urgency banner ─────────────────────────────────────────────────────────────
class _UrgencyBanner extends StatelessWidget {
  final int days; final Color color;
  const _UrgencyBanner({required this.days, required this.color});

  @override
  Widget build(BuildContext context) {
    if (days == 0) {
      return Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFFEF4444).withOpacity(0.1),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.5), width: 2)),
        child: const Row(children: [
          Icon(Icons.delete_forever_rounded, color: Color(0xFFEF4444), size: 20),
          SizedBox(width: ZapSpacing.md),
          Expanded(child: Text(
              '🔴 DELETION EXECUTING — Account is being permanently deleted.',
              style: TextStyle(color: Color(0xFFEF4444), fontSize: 12,
                  fontWeight: FontWeight.w700))),
        ]));
    }
    if (days <= 3) {
      return Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFFEF4444).withOpacity(0.08),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.45))),
        child: Row(children: [
          const Icon(Icons.warning_rounded, color: Color(0xFFEF4444), size: 18),
          const SizedBox(width: ZapSpacing.md),
          Expanded(child: Text(
              '⚠️ Only $days day${days == 1 ? "" : "s"} left! '
              'Download your data NOW and consider cancelling if this was a mistake.',
              style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12,
                  fontWeight: FontWeight.w600, height: 1.4))),
        ]));
    }
    if (days <= 7) {
      return Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withOpacity(0.07),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4))),
        child: Row(children: [
          const Icon(Icons.schedule_rounded, color: Color(0xFFF59E0B), size: 18),
          const SizedBox(width: ZapSpacing.md),
          Expanded(child: Text(
              '$days days remaining. Your data will be permanently deleted soon. '
              'Remember to download a copy if you want it.',
              style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 12, height: 1.4))),
        ]));
    }
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
          color: const Color(0xFF10B981).withOpacity(0.06),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3))),
      child: Row(children: [
        const Icon(Icons.check_circle_outline_rounded,
            color: Color(0xFF10B981), size: 18),
        const SizedBox(width: ZapSpacing.md),
        Expanded(child: Text(
            '$days days remain. You have plenty of time to cancel or download data.',
            style: const TextStyle(color: Color(0xFF10B981), fontSize: 12))),
      ]));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — Contact Notifications
// ══════════════════════════════════════════════════════════════════════════════
class _NotificationsTab extends ConsumerWidget {
  const _NotificationsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(_expandedNotifProvider);

    final delivered = _kNotifications.where((n) => n.delivered).length;
    final failed    = _kNotifications.length - delivered;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.notifications_rounded, color: const Color(0xFF3B82F6),
          text: 'When you submitted the deletion request, ZapSafe automatically '
              'emailed all your emergency contacts. This log shows what was sent '
              'and delivery status.'),
      const SizedBox(height: ZapSpacing.lg),

      // Stats strip
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A))),
        child: Row(children: [
          _stat('${_kNotifications.length}', 'Contacts', const Color(0xFF3B82F6)),
          _stat('$delivered',               'Delivered ✅', const Color(0xFF10B981)),
          _stat('$failed',                  'Failed ❌', const Color(0xFFEF4444)),
          _stat('May 30',                   'Sent on',  const Color(0xFF6B7280)),
        ]),
      ),
      const SizedBox(height: ZapSpacing.lg),

      // Notification sent to account email
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFF8B5CF6).withOpacity(0.07),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.email_rounded, color: Color(0xFF8B5CF6), size: 16),
            SizedBox(width: ZapSpacing.sm),
            Text('Confirmation sent to your email',
                style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          const Text(
            'A confirmation email with your deletion ID and the grace period '
            'end date was sent to the email on your account.',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11, height: 1.5)),
          const SizedBox(height: ZapSpacing.sm),
          _kvRow('Deletion ID', 'del_20260530_xyz123'),
          _kvRow('Sent to',     'p***a@gmail.com'),
          _kvRow('Delivered',   'May 30, 2026  14:31'),
        ]),
      ),
      const SizedBox(height: ZapSpacing.lg),

      const _SectionLabel('EMERGENCY CONTACT NOTIFICATIONS  ·  TAP TO READ'),
      const SizedBox(height: ZapSpacing.md),

      ..._kNotifications.asMap().entries.map((e) {
        final i    = e.key;
        final notif= e.value;
        final isExp= expanded == i;
        final deliveredColor = notif.delivered
            ? const Color(0xFF10B981) : const Color(0xFFEF4444);

        return GestureDetector(
          onTap: () => ref.read(_expandedNotifProvider.notifier).state =
              isExp ? null : i,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            decoration: BoxDecoration(
                color: isExp
                    ? const Color(0xFF3B82F6).withOpacity(0.06)
                    : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                    color: isExp
                        ? const Color(0xFF3B82F6).withOpacity(0.4)
                        : const Color(0xFF2A2A2A),
                    width: isExp ? 2 : 1)),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(ZapSpacing.md),
                child: Row(children: [
                  // Avatar
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFF3B82F6).withOpacity(0.3))),
                    child: Center(child: Text(notif.name[0],
                        style: const TextStyle(color: Color(0xFF3B82F6),
                            fontSize: 16, fontWeight: FontWeight.w800)))),
                  const SizedBox(width: ZapSpacing.md),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(notif.name, style: const TextStyle(color: Colors.white,
                        fontSize: 12, fontWeight: FontWeight.w600)),
                    Text('${notif.tier}  ·  ${notif.phone}',
                        style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10)),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                          color: deliveredColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(notif.delivered ? 'Delivered ✅' : 'Failed ❌',
                          style: TextStyle(color: deliveredColor, fontSize: 9,
                              fontWeight: FontWeight.w700))),
                    const SizedBox(height: ZapSpacing.xs),
                    Text(_fmtTime(notif.sentAt),
                        style: const TextStyle(color: Color(0xFF4B5563), fontSize: 9)),
                  ]),
                  const SizedBox(width: ZapSpacing.sm),
                  Icon(isExp ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                      color: const Color(0xFF4B5563), size: 14),
                ]),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: isExp ? Padding(
                  padding: const EdgeInsets.fromLTRB(
                      ZapSpacing.md, 0, ZapSpacing.md, ZapSpacing.md),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Failed delivery detail
                    if (!notif.delivered)
                      Container(
                        margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
                        padding: const EdgeInsets.all(ZapSpacing.sm),
                        decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withOpacity(0.07),
                            borderRadius:
                                BorderRadius.circular(ZapSpacing.radiusSmall),
                            border: Border.all(
                                color: const Color(0xFFEF4444).withOpacity(0.3))),
                        child: const Text(
                          '⚠️ Email delivery failed — phone number may not have '
                          'an associated email. ZapSafe will retry once.',
                          style: TextStyle(color: Color(0xFFEF4444),
                              fontSize: 11, height: 1.4))),
                    // Email preview
                    Container(
                      padding: const EdgeInsets.all(ZapSpacing.md),
                      decoration: BoxDecoration(
                          color: const Color(0xFF111111),
                          borderRadius:
                              BorderRadius.circular(ZapSpacing.radiusSmall),
                          border: Border.all(color: const Color(0xFF2A2A2A))),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const Text('Email message sent:',
                            style: TextStyle(color: Color(0xFF6B7280),
                                fontSize: 9, fontWeight: FontWeight.w700,
                                letterSpacing: 1)),
                        const SizedBox(height: 6),
                        Text(notif.message, style: const TextStyle(
                            color: Color(0xFFD1D5DB), fontSize: 11, height: 1.6)),
                      ])),
                  ]),
                ) : const SizedBox.shrink(),
              ),
            ]),
          ),
        );
      }),

      const SizedBox(height: ZapSpacing.lg),
      _infoBox(icon: Icons.info_outline_rounded, color: const Color(0xFF6B7280),
          text: 'Emergency contacts receive one notification email. If delivery '
              'fails, ZapSafe retries once after 1 hour. ZapSafe does not '
              'send SMS notifications to contacts — email only.'),
    ]);
  }

  Widget _stat(String v, String l, Color c) => Expanded(child: Column(children: [
    Text(v, style: TextStyle(color: c, fontSize: 14, fontWeight: FontWeight.w800),
        textAlign: TextAlign.center),
    Text(l, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 9),
        textAlign: TextAlign.center),
  ]));

  Widget _kvRow(String k, String v) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        SizedBox(width: 80, child: Text(k, style: const TextStyle(
            color: Color(0xFF6B7280), fontSize: 10))),
        Text(v, style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 10,
            fontFamily: 'monospace')),
      ]));

  static String _fmtTime(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return 'May ${d.day}  $h:$m';
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 3 — Cancel Deletion
// ══════════════════════════════════════════════════════════════════════════════
class _CancelTab extends ConsumerWidget {
  const _CancelTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cancelStep  = ref.watch(_cancelStepProvider);
    final cancelState = ref.watch(_cancelStateProvider);
    final confirmed   = ref.watch(_cancelConfirmProvider);

    if (cancelState == _CancelState.done) {
      return _CancelSuccessCard(ref: ref);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.undo_rounded, color: const Color(0xFF10B981),
          text: 'Changed your mind? You can cancel the deletion request at any '
              'time before the grace period ends. Your account will be fully '
              'restored instantly. All data remains intact.'),
      const SizedBox(height: ZapSpacing.lg),

      if (cancelStep == _CancelStep.idle) ...[
        // What gets restored
        const _SectionLabel('WHAT GETS RESTORED'),
        const SizedBox(height: ZapSpacing.md),
        Container(
          decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(color: const Color(0xFF2A2A2A))),
          child: Column(children: [
            _restoreRow(Icons.warning_rounded,         const Color(0xFFEF4444),
                'SOS Protection',      'Re-enabled immediately'),
            const Divider(height: 1, color: Color(0xFF2A2A2A)),
            _restoreRow(Icons.people_rounded,           const Color(0xFF10B981),
                'Emergency Contacts',  'All contacts re-activated'),
            const Divider(height: 1, color: Color(0xFF2A2A2A)),
            _restoreRow(Icons.notifications_rounded,    const Color(0xFF3B82F6),
                'Check-in Timers',     'Re-enabled, schedules restored'),
            const Divider(height: 1, color: Color(0xFF2A2A2A)),
            _restoreRow(Icons.settings_rounded,         const Color(0xFF8B5CF6),
                'Full Settings Access','All restrictions lifted'),
            const Divider(height: 1, color: Color(0xFF2A2A2A)),
            _restoreRow(Icons.lock_rounded,             const Color(0xFFF59E0B),
                'Evidence Vault',      'Full read/write access restored'),
          ]),
        ),
        const SizedBox(height: ZapSpacing.xl),

        // Contacts notified
        _infoBox(icon: Icons.people_rounded, color: const Color(0xFF3B82F6),
            text: 'Your emergency contacts will receive a follow-up email: '
                '"Priya Sharma has cancelled their account deletion. '
                'Your contact status is fully restored."'),
        const SizedBox(height: ZapSpacing.xl),

        _primaryBtn(
          label: 'Cancel My Account Deletion  ↩',
          color: const Color(0xFF10B981),
          onTap: () => ref.read(_cancelStepProvider.notifier).state =
              _CancelStep.confirm,
        ),
      ],

      if (cancelStep == _CancelStep.confirm) ...[
        const _SectionLabel('CONFIRM CANCELLATION'),
        const SizedBox(height: ZapSpacing.md),

        Container(
          padding: const EdgeInsets.all(ZapSpacing.lg),
          decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.07),
              borderRadius: BorderRadius.circular(ZapSpacing.radius),
              border: Border.all(
                  color: const Color(0xFF10B981).withOpacity(0.45), width: 2)),
          child: Column(children: [
            const Icon(Icons.undo_rounded, color: Color(0xFF10B981), size: 36),
            const SizedBox(height: ZapSpacing.md),
            const Text('Cancel account deletion?',
                style: TextStyle(color: Colors.white, fontSize: 16,
                    fontWeight: FontWeight.w800), textAlign: TextAlign.center),
            const SizedBox(height: ZapSpacing.sm),
            const Text(
              'Your account will be immediately restored.\n'
              'The 30-day grace period will be cancelled.\n'
              'All features and data will be re-enabled.',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12, height: 1.6),
              textAlign: TextAlign.center),
          ]),
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Acknowledgement checkbox
        GestureDetector(
          onTap: () => ref.read(_cancelConfirmProvider.notifier).state = !confirmed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
                color: confirmed
                    ? const Color(0xFF10B981).withOpacity(0.08)
                    : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                    color: confirmed
                        ? const Color(0xFF10B981).withOpacity(0.4)
                        : const Color(0xFF2A2A2A),
                    width: confirmed ? 2 : 1)),
            child: Row(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 22, height: 22,
                decoration: BoxDecoration(
                    color: confirmed
                        ? const Color(0xFF10B981) : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: confirmed
                            ? const Color(0xFF10B981) : const Color(0xFF3A3A3A),
                        width: 2)),
                child: confirmed
                    ? const Icon(Icons.check, color: Colors.white, size: 13)
                    : null),
              const SizedBox(width: ZapSpacing.md),
              const Expanded(child: Text(
                'I confirm I want to cancel my account deletion request '
                'and restore my account.',
                style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12, height: 1.4))),
            ]),
          ),
        ),
        const SizedBox(height: ZapSpacing.xl),

        if (cancelState == _CancelState.cancelling)
          _statusCard(Icons.hourglass_top_rounded, const Color(0xFF10B981),
              'Cancelling deletion…',
              'DELETE /api/v1/account/deletion-request\n'
              'Restoring account. Notifying emergency contacts.',
              loading: true)
        else if (cancelState == _CancelState.error)
          _statusCard(Icons.error_outline_rounded, const Color(0xFFEF4444),
              'Cancellation failed',
              'Network error. Your deletion is still active. Try again.',
              loading: false)
        else
          Column(children: [
            _primaryBtn(
              label: confirmed
                  ? 'Confirm — Restore My Account'
                  : 'Check the box above to continue',
              color: confirmed ? const Color(0xFF10B981) : const Color(0xFF2A2A2A),
              onTap: confirmed
                  ? () async {
                      ref.read(_cancelStateProvider.notifier).state =
                          _CancelState.cancelling;
                      try {
                        await _GracePeriodService.cancelDeletion();
                        if (context.mounted) {
                          ref.read(_cancelStateProvider.notifier).state =
                              _CancelState.done;
                        }
                      } catch (_) {
                        if (context.mounted) {
                          ref.read(_cancelStateProvider.notifier).state =
                              _CancelState.error;
                        }
                      }
                    }
                  : null,
            ),
            const SizedBox(height: ZapSpacing.sm),
            _outlineBtn('← Go back', const Color(0xFF6B7280),
                () => ref.read(_cancelStepProvider.notifier).state =
                    _CancelStep.idle),
          ]),
      ],
    ]);
  }

  static Widget _restoreRow(IconData icon, Color color, String label, String detail) =>
      Padding(
        padding: const EdgeInsets.all(ZapSpacing.md),
        child: Row(children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: ZapSpacing.md),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: Colors.white,
                fontSize: 12, fontWeight: FontWeight.w600)),
            Text(detail, style: const TextStyle(
                color: Color(0xFF6B7280), fontSize: 10)),
          ])),
          const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
        ]));
}

class _CancelSuccessCard extends ConsumerWidget {
  final WidgetRef ref;
  const _CancelSuccessCard({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          const Color(0xFF10B981).withOpacity(0.12),
          const Color(0xFF10B981).withOpacity(0.03),
        ]),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.5), width: 2),
      ),
      child: Column(children: [
        const Text('🎉', style: TextStyle(fontSize: 44)),
        const SizedBox(height: ZapSpacing.md),
        const Text('Account Restored!',
            style: TextStyle(color: Color(0xFF10B981), fontSize: 22,
                fontWeight: FontWeight.w900), textAlign: TextAlign.center),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          'Your deletion request has been cancelled.\n'
          'SOS protection is active again.\n'
          'All features and data are restored.',
          style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12, height: 1.6),
          textAlign: TextAlign.center),
        const SizedBox(height: ZapSpacing.lg),
        Wrap(spacing: ZapSpacing.sm, runSpacing: ZapSpacing.sm, children: const [
          _Chip('SOS active ✅',         Color(0xFF10B981)),
          _Chip('Contacts restored ✅',  Color(0xFF10B981)),
          _Chip('All data intact ✅',    Color(0xFF10B981)),
          _Chip('Grace period cancelled ✅', Color(0xFF10B981)),
        ]),
        const SizedBox(height: ZapSpacing.lg),
        GestureDetector(
          onTap: () {
            ref.read(_cancelStepProvider.notifier).state = _CancelStep.idle;
            ref.read(_cancelStateProvider.notifier).state = _CancelState.idle;
            ref.read(_cancelConfirmProvider.notifier).state = false;
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
            decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(color: const Color(0xFF2A2A2A))),
            child: const Text('Reset demo',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 11))),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text('Day 171 → Permanent deletion confirmation',
            style: TextStyle(color: Color(0xFF4B5563), fontSize: 11),
            textAlign: TextAlign.center),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label; final Color color;
  const _Chip(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.35))),
      child: Text(label, style: TextStyle(color: color, fontSize: 10,
          fontWeight: FontWeight.w600)));
}

// ── Shared helpers ─────────────────────────────────────────────────────────────
Widget _primaryBtn({required String label, required Color color,
    VoidCallback? onTap}) =>
    GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
            gradient: onTap != null
                ? LinearGradient(colors: [color, color.withOpacity(0.8)])
                : null,
            color: onTap == null ? const Color(0xFF1A1A1A) : null,
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            boxShadow: onTap != null
                ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 14,
                    offset: const Offset(0, 4))]
                : null,
            border: onTap == null
                ? Border.all(color: const Color(0xFF2A2A2A)) : null),
        child: Center(child: Text(label, style: TextStyle(
            color: onTap != null ? Colors.white : const Color(0xFF4B5563),
            fontSize: 13, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center)),
      ));

Widget _outlineBtn(String label, Color color, VoidCallback onTap) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: color.withOpacity(0.4))),
        child: Center(child: Text(label, style: TextStyle(
            color: color, fontSize: 12, fontWeight: FontWeight.w600)))));

Widget _statusCard(IconData icon, Color color, String title, String body,
    {required bool loading}) =>
    Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: color.withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          loading
              ? SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(color: color, strokeWidth: 2))
              : Icon(icon, color: color, size: 16),
          const SizedBox(width: ZapSpacing.sm),
          Text(title, style: TextStyle(color: color, fontSize: 13,
              fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: ZapSpacing.sm),
        Text(body, style: const TextStyle(color: Color(0xFF9CA3AF),
            fontSize: 11, height: 1.5)),
      ]));

Widget _infoBox({required IconData icon, required Color color, required String text}) =>
    Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: color.withOpacity(0.25))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: ZapSpacing.sm),
        Expanded(child: Text(text, style: const TextStyle(
            color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6))),
      ]));
