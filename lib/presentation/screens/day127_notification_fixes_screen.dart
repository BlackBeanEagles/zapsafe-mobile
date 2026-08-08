/// Day 127 — Improve Notifications (Part 1)
///
/// Three notification problems identified from beta feedback (Day 121):
///   Problem 1 — SOS notification text unclear ("SOS sent" vs
///               "Emergency alert sent to 5 contacts — tap for status")
///   Problem 2 — 30s+ delay on Samsung Android 13 (Doze mode kills
///               background service before FCM can deliver)
///   Problem 3 — No per-contact delivery confirmation
///               (user can't tell if contacts actually received the alert)
///
/// Day 127 fixes Problems 1 & 2 with code diffs and live demos.
/// Day 128 adds per-contact delivery status UI (Problem 3).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _activeProblemProvider = StateProvider<int>((ref) => 0);
final _appliedProvider       = StateProvider<List<bool>>(
  (ref) => List.filled(2, false),
);
final _notifDemoProvider     = StateProvider<_NotifDemo>((ref) => _NotifDemo.before);
final _delaySimProvider      = StateProvider<_DelayState>((ref) => _DelayState.idle);
final _permStateProvider     = StateProvider<_PermState>((ref) => _PermState.notGranted);

enum _NotifDemo  { before, after }
enum _DelayState { idle, dozeBlocked, fixApplied, delivered }
enum _PermState  { notGranted, requesting, granted }

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day127NotificationFixesScreen extends ConsumerWidget {
  const Day127NotificationFixesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active  = ref.watch(_activeProblemProvider);
    final applied = ref.watch(_appliedProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Day 127 · Notification Fixes'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Hero(),
            const SizedBox(height: ZapSpacing.xl),

            const _SectionLabel('SELECT PROBLEM TO FIX'),
            const SizedBox(height: ZapSpacing.md),
            _ProblemSelector(active: active, applied: applied),
            const SizedBox(height: ZapSpacing.xl),

            if (active == 0) const _ClarityFix(),
            if (active == 1) const _DozeModeFix(),
            const SizedBox(height: ZapSpacing.xl),

            _ApplyButton(index: active),
            const SizedBox(height: ZapSpacing.xl),

            const _SectionLabel('FIX PROGRESS  ·  DAY 127'),
            const SizedBox(height: ZapSpacing.md),
            _ProgressSummary(applied: applied),
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
          colors: [Color(0xFF0C1A30), Color(0xFF060D18), Color(0xFF0A0A0A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _badge('⚡  BETA  ·  DAY 127', const Color(0xFF3B82F6)),
            const SizedBox(width: ZapSpacing.sm),
            _badge('Samsung Doze Fix', const Color(0xFFF59E0B)),
          ]),
          const SizedBox(height: ZapSpacing.md),
          const Text(
            'Improve\nNotifications',
            style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                height: 1.2),
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            '61% of performance reports cite notification delay > 30s on Samsung. '
            'Root cause: Android 13 Doze mode kills background services. '
            'Also fixing unclear notification text.',
            style: TextStyle(
                color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: ZapSpacing.md),
          const Row(children: [
            _HStat('61%',  'Reports',         Color(0xFFEF4444)),
            _HStat('>30s', 'Delay',           Color(0xFFF97316)),
            _HStat('Doze', 'Root cause',      Color(0xFFF59E0B)),
            _HStat('P1',   'Priority',        Color(0xFF3B82F6)),
          ]),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
      );
}

class _HStat extends StatelessWidget {
  final String value, label;
  final Color color;
  const _HStat(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 15, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center),
          Text(label,
              style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 9),
              textAlign: TextAlign.center),
        ]),
      );
}

// ── Section label ──────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) => Text(label,
      style: const TextStyle(
          color: Color(0xFF6B7280),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5));
}

// ── Problem selector ───────────────────────────────────────────────────────────
class _ProblemSelector extends ConsumerWidget {
  final int active;
  final List<bool> applied;
  const _ProblemSelector({required this.active, required this.applied});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const items = [
      (Icons.notifications_rounded,  Color(0xFF3B82F6), 'Fix 1', 'Clarity'),
      (Icons.battery_saver_rounded,  Color(0xFFF59E0B), 'Fix 2', 'Doze Mode'),
    ];

    return Row(
      children: List.generate(2, (i) {
        final (icon, color, label, sub) = items[i];
        final isActive = i == active;
        final isDone   = applied[i];

        return Expanded(
          child: GestureDetector(
            onTap: () =>
                ref.read(_activeProblemProvider.notifier).state = i,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: EdgeInsets.only(right: i == 0 ? ZapSpacing.sm : 0),
              padding: const EdgeInsets.all(ZapSpacing.md),
              decoration: BoxDecoration(
                color: isActive
                    ? color.withOpacity(0.12)
                    : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                  color: isActive
                      ? color.withOpacity(0.5)
                      : const Color(0xFF2A2A2A),
                  width: isActive ? 2 : 1,
                ),
              ),
              child: Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: isDone
                        ? const Color(0xFF10B981).withOpacity(0.15)
                        : color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isDone ? Icons.check_rounded : icon,
                    color: isDone ? const Color(0xFF10B981) : color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: ZapSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: TextStyle(
                              color: isActive ? color : const Color(0xFF9CA3AF),
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                      Text(sub,
                          style: const TextStyle(
                              color: Color(0xFF6B7280), fontSize: 11)),
                      const SizedBox(height: ZapSpacing.xs),
                      _pill(isDone ? 'Fixed' : 'Open',
                          isDone ? const Color(0xFF10B981) : const Color(0xFF4B5563)),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        );
      }),
    );
  }

  Widget _pill(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 9, fontWeight: FontWeight.w700)),
      );
}

// ── Fix 1 — Notification Clarity ──────────────────────────────────────────────
class _ClarityFix extends ConsumerWidget {
  const _ClarityFix();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(_notifDemoProvider);

    const beforeNotifs = [
      (Icons.warning_rounded,       Color(0xFFEF4444), 'SOS',
          'SOS sent', 'Emergency alert'),
      (Icons.check_circle_rounded,  Color(0xFF10B981), 'Update',
          'SOS resolved', 'Status update'),
      (Icons.people_rounded,        Color(0xFF3B82F6), 'Contact',
          'Contact responded', 'Response'),
    ];

    const afterNotifs = [
      (Icons.warning_rounded,       Color(0xFFEF4444), 'ZapSafe Emergency',
          'Emergency alert sent to 5 contacts · Tap for status',
          'Priya, Arjun & 3 others notified'),
      (Icons.check_circle_rounded,  Color(0xFF10B981), 'ZapSafe · Safe',
          'SOS resolved after 4 min 23s · All contacts notified',
          'Tap to view incident report'),
      (Icons.people_rounded,        Color(0xFF3B82F6), 'ZapSafe · Response',
          'Priya Kumar responded: "On my way, 5 min away"',
          'Tap to open chat'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _metaBox(
          reports: 28,
          priority: 'P1',
          cause: 'Notification titles/bodies are generic: "SOS sent", "Contact '
              'responded". Users can\'t scan them in notification tray '
              'without opening the app.',
          fix: 'Rewrite all notification payloads with specific context: '
              'contact count, names, elapsed time, action hint.',
        ),
        const SizedBox(height: ZapSpacing.lg),

        const _SectionLabel('NOTIFICATION PREVIEW'),
        const SizedBox(height: ZapSpacing.md),

        // Toggle
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: () => ref
                  .read(_notifDemoProvider.notifier)
                  .state = _NotifDemo.before,
              child: _tab('Before', demo == _NotifDemo.before,
                  const Color(0xFFEF4444)),
            ),
          ),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: GestureDetector(
              onTap: () => ref
                  .read(_notifDemoProvider.notifier)
                  .state = _NotifDemo.after,
              child: _tab('After', demo == _NotifDemo.after,
                  const Color(0xFF10B981)),
            ),
          ),
        ]),
        const SizedBox(height: ZapSpacing.md),

        // Mock notification shade
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: const Color(0xFF3A3A3C)),
          ),
          child: Column(
            children: [
              // Shade header
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: ZapSpacing.md, vertical: 10),
                child: Row(children: [
                  const Text('Notifications',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text(
                    demo == _NotifDemo.before ? 'v0.5' : 'v0.5.3',
                    style: TextStyle(
                        color: demo == _NotifDemo.before
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF10B981),
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ]),
              ),
              const Divider(height: 1, color: Color(0xFF3A3A3C)),

              ...List.generate(3, (i) {
                if (demo == _NotifDemo.before) {
                  final (icon, color, app, title, sub) = beforeNotifs[i];
                  return _NotifRow(
                    icon: icon,
                    color: color,
                    app: app,
                    title: title,
                    subtitle: sub,
                    time: '${(i + 1) * 2}m ago',
                    isLast: i == 2,
                  );
                } else {
                  final (icon, color, app, title, sub) = afterNotifs[i];
                  return _NotifRow(
                    icon: icon,
                    color: color,
                    app: app,
                    title: title,
                    subtitle: sub,
                    time: '${(i + 1) * 2}m ago',
                    isLast: i == 2,
                  );
                }
              }),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),

        _codeNote('notification_service.dart',
            '// Before\n'
            'title: \'SOS sent\'\n'
            'body:  \'Emergency alert\'\n'
            '\n'
            '// After\n'
            'final names = contacts.take(2).map((c) => c.firstName).join(\', \');\n'
            'title: \'ZapSafe Emergency\'\n'
            'body:  \'Emergency alert sent to \${contacts.length} contacts · \'\n'
            '       \'Tap for status\''),
      ],
    );
  }
}

class _NotifRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String app, title, subtitle, time;
  final bool isLast;
  const _NotifRow({
    required this.icon,
    required this.color,
    required this.app,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(ZapSpacing.md),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: ZapSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(app,
                      style: const TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text(time,
                      style: const TextStyle(
                          color: Color(0xFF6B7280), fontSize: 10)),
                ]),
                const SizedBox(height: 2),
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                Text(subtitle,
                    style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 12,
                        height: 1.3)),
              ],
            ),
          ),
        ]),
      ),
      if (!isLast) const Divider(height: 1, color: Color(0xFF2A2A2A)),
    ]);
  }
}

// ── Fix 2 — Doze Mode ─────────────────────────────────────────────────────────
class _DozeModeFix extends ConsumerWidget {
  const _DozeModeFix();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final delayState = ref.watch(_delaySimProvider);
    final permState  = ref.watch(_permStateProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _metaBox(
          reports: 28,
          priority: 'P1',
          cause: 'Samsung Android 13 introduced aggressive background '
              'app management. When screen is off > 3 min, '
              '"Sleeping apps" policy kills background services — '
              'FCM push can\'t wake the process in time.',
          fix: '1. Request SCHEDULE_EXACT_ALARM permission\n'
              '2. Use setExactAndAllowWhileIdle() alarm as wake-up fallback\n'
              '3. Move SOS escalation to high-priority FCM data message '
              '(bypasses Doze for safety-critical apps)',
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Doze explanation diagram
        const _SectionLabel('HOW DOZE BLOCKS NOTIFICATIONS'),
        const SizedBox(height: ZapSpacing.md),
        const _DozeTimeline(),
        const SizedBox(height: ZapSpacing.xl),

        // Permission request demo
        const _SectionLabel('STEP 1  ·  REQUEST SCHEDULE_EXACT_ALARM'),
        const SizedBox(height: ZapSpacing.md),
        _PermissionDemo(state: permState),
        const SizedBox(height: ZapSpacing.xl),

        // Delay simulation
        const _SectionLabel('STEP 2  ·  SIMULATE NOTIFICATION DELIVERY'),
        const SizedBox(height: ZapSpacing.md),
        _DelaySimulator(state: delayState),
        const SizedBox(height: ZapSpacing.xl),

        // Code fix
        const _SectionLabel('STEP 3  ·  CODE FIX'),
        const SizedBox(height: ZapSpacing.md),
        _codeNote('sos_escalation_service.kt',
            '// Before — plain FCM (blocked by Doze)\n'
            'FirebaseMessaging.getInstance().send(remoteMessage)\n'
            '\n'
            '// After — exact alarm fallback + high-priority FCM\n'
            'val alarmManager = getSystemService(AlarmManager::class.java)\n'
            'if (Build.VERSION.SDK_INT >= 31) {\n'
            '    // Request SCHEDULE_EXACT_ALARM if not granted\n'
            '    if (!alarmManager.canScheduleExactAlarms()) {\n'
            '        requestExactAlarmPermission()\n'
            '    }\n'
            '}\n'
            'alarmManager.setExactAndAllowWhileIdle(\n'
            '    AlarmManager.RTC_WAKEUP,\n'
            '    System.currentTimeMillis() + 500,\n'
            '    createEscalationPendingIntent(sosId)\n'
            ')\n'
            '// Also send high-priority FCM data message\n'
            'message.priority = RemoteMessage.PRIORITY_HIGH'),
      ],
    );
  }
}

class _DozeTimeline extends StatelessWidget {
  const _DozeTimeline();

  @override
  Widget build(BuildContext context) {
    const steps = [
      (Icons.phone_locked_rounded,    Color(0xFF6B7280),
          'Screen off > 3 min', 'Samsung enters Doze mode'),
      (Icons.do_not_disturb_on_rounded, Color(0xFFEF4444),
          'Background killed', 'ZapSafe background service suspended'),
      (Icons.notifications_off_rounded, Color(0xFFEF4444),
          'FCM delayed', 'Push notification queued — not delivered immediately'),
      (Icons.timer_rounded,           Color(0xFFF97316),
          '>30s later', 'Device exits Doze maintenance window'),
      (Icons.notifications_rounded,   Color(0xFF10B981),
          'Finally delivered', 'SOS notification arrives — too late'),
    ];

    const fixSteps = [
      (Icons.alarm_rounded,           Color(0xFF3B82F6),
          'Exact alarm set', 'setExactAndAllowWhileIdle() bypasses Doze'),
      (Icons.bolt_rounded,            Color(0xFF10B981),
          'High-priority FCM', 'DATA message — exempt from Doze restrictions'),
      (Icons.speed_rounded,           Color(0xFF10B981),
          '<2s delivery', 'SOS notification arrives on time'),
    ];

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Before row
          _timelineLabel('WITHOUT FIX', const Color(0xFFEF4444)),
          const SizedBox(height: ZapSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: steps.asMap().entries.map((e) {
                final i = e.key;
                final (icon, color, title, sub) = e.value;
                return Row(children: [
                  _timelineNode(icon, color, title, sub),
                  if (i < steps.length - 1)
                    Container(
                        width: 24, height: 2,
                        color: const Color(0xFF2A2A2A)),
                ]);
              }).toList(),
            ),
          ),
          const Divider(height: ZapSpacing.xl, color: Color(0xFF2A2A2A)),
          // After row
          _timelineLabel('WITH FIX', const Color(0xFF10B981)),
          const SizedBox(height: ZapSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: fixSteps.asMap().entries.map((e) {
                final i = e.key;
                final (icon, color, title, sub) = e.value;
                return Row(children: [
                  _timelineNode(icon, color, title, sub),
                  if (i < fixSteps.length - 1)
                    Container(
                        width: 24, height: 2,
                        color: const Color(0xFF2A2A2A)),
                ]);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timelineLabel(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 9, fontWeight: FontWeight.w800,
                letterSpacing: 1)),
      );

  Widget _timelineNode(
          IconData icon, Color color, String title, String sub) =>
      SizedBox(
        width: 80,
        child: Column(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 6),
          Text(title,
              style: const TextStyle(
                  color: Colors.white, fontSize: 9,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.center),
          Text(sub,
              style: const TextStyle(
                  color: Color(0xFF6B7280), fontSize: 8, height: 1.3),
              textAlign: TextAlign.center),
        ]),
      );
}

class _PermissionDemo extends ConsumerWidget {
  final _PermState state;
  const _PermissionDemo({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(
          color: state == _PermState.granted
              ? const Color(0xFF10B981).withOpacity(0.35)
              : const Color(0xFF2A2A2A),
        ),
      ),
      child: Column(children: [
        // Permission info
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.alarm_rounded,
                color: Color(0xFF3B82F6), size: 20),
          ),
          const SizedBox(width: ZapSpacing.md),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SCHEDULE_EXACT_ALARM',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace')),
                Text(
                    'Required on Android 12+ for precise '
                    'alarm scheduling that bypasses Doze',
                    style: TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 11,
                        height: 1.4)),
              ],
            ),
          ),
        ]),
        const SizedBox(height: ZapSpacing.lg),

        if (state == _PermState.notGranted) ...[
          // Mock system dialog
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2E),
              borderRadius: BorderRadius.circular(ZapSpacing.radius),
              border: Border.all(color: const Color(0xFF3A3A3C)),
            ),
            child: Column(children: [
              const Icon(Icons.alarm_rounded,
                  color: Colors.white, size: 32),
              const SizedBox(height: ZapSpacing.sm),
              const Text('Allow ZapSafe to set\nexact alarms?',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center),
              const SizedBox(height: ZapSpacing.sm),
              const Text(
                  'This allows the app to send emergency '
                  'alerts even when your phone is in power-saving mode.',
                  style: TextStyle(
                      color: Color(0xFF9CA3AF), fontSize: 12, height: 1.5),
                  textAlign: TextAlign.center),
              const SizedBox(height: ZapSpacing.lg),
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => ref
                        .read(_permStateProvider.notifier)
                        .state = _PermState.notGranted,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                      ),
                      child: const Center(
                        child: Text("Don't allow",
                            style: TextStyle(
                                color: Color(0xFF9CA3AF), fontSize: 13)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      ref.read(_permStateProvider.notifier).state =
                          _PermState.requesting;
                      await Future.delayed(
                          const Duration(milliseconds: 600));
                      if (!context.mounted) return;
                      ref.read(_permStateProvider.notifier).state =
                          _PermState.granted;
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF007AFF),
                        borderRadius:
                            BorderRadius.circular(ZapSpacing.radiusSmall),
                      ),
                      child: const Center(
                        child: Text('Allow',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ),
              ]),
            ]),
          ),
        ] else if (state == _PermState.requesting)
          _statusChip(Icons.hourglass_top_rounded,
              const Color(0xFF3B82F6), 'Requesting permission…', loading: true)
        else
          _statusChip(Icons.check_circle_rounded,
              const Color(0xFF10B981),
              'SCHEDULE_EXACT_ALARM granted ✅'),
      ]),
    );
  }
}

class _DelaySimulator extends ConsumerWidget {
  final _DelayState state;
  const _DelaySimulator({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(
          color: state == _DelayState.delivered
              ? const Color(0xFF10B981).withOpacity(0.35)
              : const Color(0xFF2A2A2A),
        ),
      ),
      child: Column(children: [
        if (state == _DelayState.idle) ...[
          // Phone mock
          _phoneMock(
            label: 'Samsung Galaxy S23 · Android 13',
            sleeping: true,
            notifText: null,
          ),
          const SizedBox(height: ZapSpacing.lg),
          Row(children: [
            Expanded(
              child: _simBtn(
                label: 'Without fix (Doze blocks)',
                color: const Color(0xFFEF4444),
                onTap: () async {
                  ref.read(_delaySimProvider.notifier).state =
                      _DelayState.dozeBlocked;
                },
              ),
            ),
            const SizedBox(width: ZapSpacing.sm),
            Expanded(
              child: _simBtn(
                label: 'With fix applied',
                color: const Color(0xFF10B981),
                onTap: () async {
                  ref.read(_delaySimProvider.notifier).state =
                      _DelayState.fixApplied;
                  await Future.delayed(const Duration(milliseconds: 1200));
                  if (!context.mounted) return;
                  ref.read(_delaySimProvider.notifier).state =
                      _DelayState.delivered;
                },
              ),
            ),
          ]),
        ] else if (state == _DelayState.dozeBlocked) ...[
          _phoneMock(
            label: 'Samsung Galaxy S23 · Android 13 · DOZE ACTIVE',
            sleeping: true,
            notifText: null,
          ),
          const SizedBox(height: ZapSpacing.md),
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withOpacity(0.08),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(
                  color: const Color(0xFFEF4444).withOpacity(0.3)),
            ),
            child: const Column(children: [
              Row(children: [
                Icon(Icons.block_rounded, color: Color(0xFFEF4444), size: 16),
                SizedBox(width: ZapSpacing.sm),
                Text('Notification BLOCKED by Doze',
                    style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ]),
              SizedBox(height: ZapSpacing.sm),
              Text(
                'FCM push queued. Will deliver when device exits Doze '
                'maintenance window (~30-90 seconds). SOS response delayed.',
                style: TextStyle(
                    color: Color(0xFF9CA3AF), fontSize: 12, height: 1.5),
              ),
            ]),
          ),
          const SizedBox(height: ZapSpacing.md),
          GestureDetector(
            onTap: () => ref
                .read(_delaySimProvider.notifier)
                .state = _DelayState.idle,
            child: const Center(
              child: Text('Reset',
                  style: TextStyle(
                      color: Color(0xFF6B7280), fontSize: 12)),
            ),
          ),
        ] else if (state == _DelayState.fixApplied) ...[
          _phoneMock(
            label: 'Samsung Galaxy S23 · Exact alarm waking…',
            sleeping: false,
            notifText: null,
          ),
          const SizedBox(height: ZapSpacing.md),
          _statusChip(Icons.alarm_rounded, const Color(0xFF3B82F6),
              'setExactAndAllowWhileIdle() waking device…', loading: true),
        ] else ...[
          _phoneMock(
            label: 'Samsung Galaxy S23 · DELIVERED ✅',
            sleeping: false,
            notifText: 'Emergency alert sent to 5 contacts · Tap for status',
          ),
          const SizedBox(height: ZapSpacing.md),
          _statusChip(Icons.check_circle_rounded, const Color(0xFF10B981),
              'Delivered in < 2s — Doze bypassed ✅'),
          const SizedBox(height: ZapSpacing.md),
          GestureDetector(
            onTap: () => ref
                .read(_delaySimProvider.notifier)
                .state = _DelayState.idle,
            child: const Center(
              child: Text('Reset demo',
                  style: TextStyle(
                      color: Color(0xFF6B7280), fontSize: 12)),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _phoneMock({
    required String label,
    required bool sleeping,
    required String? notifText,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: sleeping ? const Color(0xFF0A0A0A) : const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(
          color: sleeping
              ? const Color(0xFF2A2A2A)
              : notifText != null
                  ? const Color(0xFF10B981).withOpacity(0.4)
                  : const Color(0xFF3B82F6).withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(children: [
        // Status bar
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: ZapSpacing.md, vertical: 8),
          child: Row(children: [
            Text(label,
                style: TextStyle(
                    color: sleeping
                        ? const Color(0xFF4B5563)
                        : const Color(0xFF9CA3AF),
                    fontSize: 9,
                    fontFamily: 'monospace')),
            const Spacer(),
            Icon(
              sleeping
                  ? Icons.bedtime_rounded
                  : Icons.phone_android_rounded,
              color: sleeping
                  ? const Color(0xFF4B5563)
                  : const Color(0xFF10B981),
              size: 12,
            ),
          ]),
        ),
        // Content
        Padding(
          padding: const EdgeInsets.all(ZapSpacing.md),
          child: notifText != null
              ? Container(
                  padding: const EdgeInsets.all(ZapSpacing.sm),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                    border: Border.all(
                        color: const Color(0xFF10B981).withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.bolt_rounded,
                          color: Color(0xFFEF4444), size: 18),
                    ),
                    const SizedBox(width: ZapSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('ZapSafe Emergency',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                          Text(notifText,
                              style: const TextStyle(
                                  color: Color(0xFF9CA3AF),
                                  fontSize: 10,
                                  height: 1.3)),
                        ],
                      ),
                    ),
                  ]),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      sleeping
                          ? Icons.bedtime_rounded
                          : Icons.hourglass_top_rounded,
                      color: sleeping
                          ? const Color(0xFF2A2A2A)
                          : const Color(0xFF3B82F6),
                      size: 32,
                    ),
                    const SizedBox(width: ZapSpacing.sm),
                    Text(
                      sleeping ? 'Phone sleeping…' : 'Waking up…',
                      style: TextStyle(
                          color: sleeping
                              ? const Color(0xFF2A2A2A)
                              : const Color(0xFF3B82F6),
                          fontSize: 12),
                    ),
                  ],
                ),
        ),
      ]),
    );
  }

  Widget _simBtn({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
          ),
        ),
      );
}

// ── Apply button ───────────────────────────────────────────────────────────────
class _ApplyButton extends ConsumerWidget {
  final int index;
  const _ApplyButton({required this.index});

  static const _labels = [
    'Apply notification clarity fix',
    'Apply Doze mode fix',
  ];
  static const _colors = [
    Color(0xFF3B82F6),
    Color(0xFFF59E0B),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applied = ref.watch(_appliedProvider);
    final isDone  = applied[index];
    final color   = _colors[index];

    if (isDone) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withOpacity(0.1),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border:
              Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded,
                color: Color(0xFF10B981), size: 18),
            SizedBox(width: ZapSpacing.sm),
            Text('Fix applied & committed',
                style: TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () async {
        await Future.delayed(const Duration(milliseconds: 500));
        if (!context.mounted) return;
        final updated = List<bool>.from(ref.read(_appliedProvider));
        updated[index] = true;
        ref.read(_appliedProvider.notifier).state = updated;
        final next = updated.indexWhere((v) => !v);
        if (next != -1) {
          ref.read(_activeProblemProvider.notifier).state = next;
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [color, color.withOpacity(0.8)]),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.build_rounded, color: Colors.white, size: 18),
            const SizedBox(width: ZapSpacing.sm),
            Text(_labels[index],
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

// ── Progress summary ───────────────────────────────────────────────────────────
class _ProgressSummary extends StatelessWidget {
  final List<bool> applied;
  const _ProgressSummary({required this.applied});

  @override
  Widget build(BuildContext context) {
    final doneCount = applied.where((a) => a).length;
    final allDone   = doneCount == 2;

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: allDone
            ? const Color(0xFF10B981).withOpacity(0.06)
            : const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(
          color: allDone
              ? const Color(0xFF10B981).withOpacity(0.35)
              : const Color(0xFF2A2A2A),
        ),
      ),
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$doneCount / 2 fixes applied',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            Text(
              allDone
                  ? '→ Day 128: contact delivery UI'
                  : 'Apply remaining fixes above',
              style: TextStyle(
                  color: allDone
                      ? const Color(0xFF10B981)
                      : const Color(0xFF6B7280),
                  fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: doneCount / 2,
            backgroundColor: const Color(0xFF2A2A2A),
            valueColor: AlwaysStoppedAnimation(
              allDone ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
            ),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        _item(applied[0], const Color(0xFF3B82F6),
            'Fix 1 — Notification text clarity (28 reports)'),
        const SizedBox(height: 6),
        _item(applied[1], const Color(0xFFF59E0B),
            'Fix 2 — Samsung Doze mode delay (28 reports)'),
        if (allDone) ...[
          const Divider(height: ZapSpacing.lg, color: Color(0xFF2A2A2A)),
          const Row(children: [
            Icon(Icons.arrow_forward_rounded,
                color: Color(0xFF3B82F6), size: 14),
            SizedBox(width: ZapSpacing.sm),
            Expanded(
              child: Text(
                'Day 128: Add per-contact delivery status UI',
                style: TextStyle(
                    color: Color(0xFF9CA3AF), fontSize: 11),
              ),
            ),
          ]),
        ],
      ]),
    );
  }

  Widget _item(bool done, Color color, String label) => Row(children: [
        Icon(
          done
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          color: done ? const Color(0xFF10B981) : const Color(0xFF4B5563),
          size: 16,
        ),
        const SizedBox(width: ZapSpacing.sm),
        Container(
            width: 8,
            height: 8,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: ZapSpacing.sm),
        Expanded(
          child: Text(label,
              style: TextStyle(
                color:
                    done ? const Color(0xFF6B7280) : Colors.white,
                fontSize: 12,
                decoration: done ? TextDecoration.lineThrough : null,
                decorationColor: const Color(0xFF6B7280),
              )),
        ),
      ]);
}

// ── Shared helpers ─────────────────────────────────────────────────────────────
Widget _metaBox({
  required int reports,
  required String priority,
  required String cause,
  required String fix,
}) =>
    Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(children: [
        Row(children: [
          _chip('$reports reports', const Color(0xFFF59E0B)),
          const SizedBox(width: ZapSpacing.sm),
          _chip(priority, const Color(0xFF3B82F6)),
        ]),
        const SizedBox(height: ZapSpacing.md),
        _metaRow(Icons.search_rounded, const Color(0xFFEF4444),
            'Root cause', cause),
        const SizedBox(height: ZapSpacing.sm),
        _metaRow(Icons.build_rounded, const Color(0xFF10B981), 'Fix', fix),
      ]),
    );

Widget _chip(String label, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );

Widget _metaRow(IconData icon, Color color, String label, String text) =>
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 14),
      const SizedBox(width: ZapSpacing.sm),
      Text('$label: ',
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      Expanded(
        child: Text(text,
            style: const TextStyle(
                color: Color(0xFFD1D5DB), fontSize: 11, height: 1.5)),
      ),
    ]);

Widget _tab(String label, bool active, Color color) => Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: active ? color.withOpacity(0.12) : const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(
          color: active ? color.withOpacity(0.5) : const Color(0xFF2A2A2A),
          width: active ? 2 : 1,
        ),
      ),
      child: Center(
        child: Text(label,
            style: TextStyle(
                color: active ? color : const Color(0xFF6B7280),
                fontSize: 12,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400)),
      ),
    );

Widget _statusChip(IconData icon, Color color, String label,
        {bool loading = false}) =>
    Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        loading
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    color: color, strokeWidth: 2))
            : Icon(icon, color: color, size: 16),
        const SizedBox(width: ZapSpacing.sm),
        Text(label,
            style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ]),
    );

Widget _codeNote(String filename, String code) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: const Color(0xFF1C2128),
              borderRadius: BorderRadius.circular(4)),
          child: Text(filename,
              style: const TextStyle(
                  color: Color(0xFF79C0FF),
                  fontSize: 10,
                  fontFamily: 'monospace')),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Text(code,
            style: const TextStyle(
                color: Color(0xFFE6EDF3),
                fontSize: 11,
                fontFamily: 'monospace',
                height: 1.6)),
      ]),
    );
