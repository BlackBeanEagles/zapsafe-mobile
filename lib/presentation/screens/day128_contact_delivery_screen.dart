/// Day 128 — Per-Contact Delivery Status & Brand-Specific Fixes
///
/// Second half of the Days 127-128 notification improvement cycle.
/// Day 127 fixed text clarity + Samsung Doze mode.
/// Day 128 adds:
///   1. Per-contact delivery status UI — real-time checkmarks as each
///      contact's device acknowledges the SOS alert
///   2. Brand-specific notification issues — Xiaomi / Huawei MIUI/EMUI
///      AutoStart restrictions that silently drop notifications
///   3. "Some users not receiving" debug checklist
///   4. Ship v0.5.3 bundling all notification improvements
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _activeTabProvider     = StateProvider<int>((ref) => 0);
final _deliverySimProvider   = StateProvider<_DeliveryState>((ref) => _DeliveryState.idle);
final _contactStatusProvider = StateProvider<List<_ContactStatus>>(
  (ref) => _kContacts.map((c) => _ContactStatus(contact: c)).toList(),
);
final _brandFixesProvider    = StateProvider<List<bool>>(
  (ref) => List.filled(_kBrandFixes.length, false),
);
final _verifyChecksProvider  = StateProvider<List<bool>>(
  (ref) => List.filled(_kVerifyChecks.length, false),
);
final _shipStateProvider     = StateProvider<_ShipState>((ref) => _ShipState.idle);

enum _DeliveryState { idle, sending, partial, allDelivered }
enum _ShipState     { idle, building, uploading, done }

// ── Data models ────────────────────────────────────────────────────────────────
enum _DeliveryStep { pending, sent, delivered, opened, responded }

class _Contact {
  final String name;
  final String initials;
  final Color color;
  final String device;
  final int delayMs; // simulated delivery delay
  const _Contact({
    required this.name,
    required this.initials,
    required this.color,
    required this.device,
    required this.delayMs,
  });
}

class _ContactStatus {
  final _Contact contact;
  _DeliveryStep step;
  String? responseText;
  _ContactStatus({required this.contact, this.step = _DeliveryStep.pending});
}

const _kContacts = [
  _Contact(name: 'Priya Kumar',   initials: 'PK', color: Color(0xFF10B981), device: 'iPhone 14', delayMs: 600),
  _Contact(name: 'Arjun Singh',   initials: 'AS', color: Color(0xFF3B82F6), device: 'Pixel 7',   delayMs: 1000),
  _Contact(name: 'Meera Patel',   initials: 'MP', color: Color(0xFF8B5CF6), device: 'Samsung S23',delayMs: 1500),
  _Contact(name: 'Rahul Sharma',  initials: 'RS', color: Color(0xFFF59E0B), device: 'Xiaomi 12',  delayMs: 2200),
  _Contact(name: 'Anita Desai',   initials: 'AD', color: Color(0xFFF97316), device: 'OnePlus 11', delayMs: 900),
];

class _BrandFix {
  final String brand;
  final Color color;
  final IconData icon;
  final String issue;
  final String fix;
  final List<String> steps;
  const _BrandFix({
    required this.brand,
    required this.color,
    required this.icon,
    required this.issue,
    required this.fix,
    required this.steps,
  });
}

const _kBrandFixes = [
  _BrandFix(
    brand: 'Xiaomi / MIUI',
    color: Color(0xFFEF4444),
    icon: Icons.phone_android_rounded,
    issue: 'MIUI "AutoStart" disabled by default — background apps '
        'cannot launch on notification. ZapSafe never starts to process SOS push.',
    fix: 'Detect MIUI at runtime, prompt user to enable AutoStart in '
        'MIUI Settings → Apps → ZapSafe → AutoStart.',
    steps: [
      'Settings → Apps → Manage Apps → ZapSafe',
      'Tap "Other permissions"',
      'Enable "AutoStart"',
      'Also: Settings → Battery → Battery saver → No restrictions',
    ],
  ),
  _BrandFix(
    brand: 'Huawei / EMUI',
    color: Color(0xFFF97316),
    icon: Icons.phone_android_rounded,
    issue: 'EMUI "App launch" management kills background processes. '
        'Push Messaging service is suspended when screen turns off.',
    fix: 'Detect EMUI, guide user to enable "Auto-launch" and '
        'disable "Battery optimisation" for ZapSafe.',
    steps: [
      'Settings → Apps → ZapSafe → Battery → No restrictions',
      'Settings → Apps → ZapSafe → App launch → Manual → Enable all',
      'Settings → Battery → More settings → Close after screen lock → OFF',
    ],
  ),
  _BrandFix(
    brand: 'OnePlus / OxygenOS',
    color: Color(0xFFF59E0B),
    icon: Icons.phone_android_rounded,
    issue: 'OxygenOS "Smart Battery" aggressively limits background '
        'activity. FCM messages received but app never woken.',
    fix: 'Detect OxygenOS, prompt user to disable Battery Optimisation '
        'for ZapSafe and enable "Auto-launch".',
    steps: [
      'Settings → Battery → Battery optimisation → All apps → ZapSafe → Don\'t optimise',
      'Settings → Apps → ZapSafe → Auto-launch → Enable',
    ],
  ),
];

const _kVerifyChecks = [
  'Fix 1 (Day 127): Notification text updated across all 6 notification types',
  'Fix 2 (Day 127): Samsung Doze delay < 2s on physical Samsung S23',
  'Fix 3 (Day 128): Per-contact delivery status shows in SOS active screen',
  'Fix 4 (Day 128): Xiaomi AutoStart prompt shown on first SOS on MIUI device',
  'Fix 5 (Day 128): Huawei EMUI prompt shown on first SOS on EMUI device',
  'Fix 6 (Day 128): Contact delivery ACK received via backend webhook',
  'No regression: Standard Android (Pixel, Samsung) notifications unaffected',
];

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day128ContactDeliveryScreen extends ConsumerWidget {
  const Day128ContactDeliveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab        = ref.watch(_activeTabProvider);
    final verChecks  = ref.watch(_verifyChecksProvider);
    final shipState  = ref.watch(_shipStateProvider);
    final allVerified = verChecks.every((c) => c);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Day 128 · Contact Delivery'),
        elevation: 0,
        actions: [
          if (shipState == _ShipState.done)
            TextButton(
              onPressed: () {
                ref.read(_deliverySimProvider.notifier).state = _DeliveryState.idle;
                ref.read(_shipStateProvider.notifier).state   = _ShipState.idle;
                ref.read(_verifyChecksProvider.notifier).state =
                    List.filled(_kVerifyChecks.length, false);
                ref.read(_brandFixesProvider.notifier).state  =
                    List.filled(_kBrandFixes.length, false);
                ref.read(_contactStatusProvider.notifier).state =
                    _kContacts.map((c) => _ContactStatus(contact: c)).toList();
              },
              child: const Text('Reset',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
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

            // Tab bar
            const _SectionLabel('SELECT AREA'),
            const SizedBox(height: ZapSpacing.md),
            _TabBar(active: tab,
                onSelect: (t) =>
                    ref.read(_activeTabProvider.notifier).state = t),
            const SizedBox(height: ZapSpacing.xl),

            if (tab == 0) const _DeliveryStatusTab(),
            if (tab == 1) const _BrandFixesTab(),
            const SizedBox(height: ZapSpacing.xl),

            // Verification
            const _SectionLabel('VERIFICATION CHECKLIST  ·  DAYS 127-128'),
            const SizedBox(height: ZapSpacing.md),
            _VerifyChecklist(checks: verChecks, allDone: allVerified),
            const SizedBox(height: ZapSpacing.xl),

            // Ship
            const _SectionLabel('SHIP  ·  v0.5.3 NOTIFICATION BUNDLE'),
            const SizedBox(height: ZapSpacing.md),
            _ShipPanel(allVerified: allVerified, state: shipState),
            const SizedBox(height: ZapSpacing.xl),

            // Next
            const _SectionLabel('NEXT  ·  DAYS 129-130'),
            const SizedBox(height: ZapSpacing.md),
            const _NextCard(),
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
          colors: [Color(0xFF0A1A30), Color(0xFF060D18), Color(0xFF0A0A0A)],
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
            _badge('⚡  BETA  ·  DAY 128', const Color(0xFF3B82F6)),
            const SizedBox(width: ZapSpacing.sm),
            _badge('v0.5.3 Notif Bundle', const Color(0xFF10B981)),
          ]),
          const SizedBox(height: ZapSpacing.md),
          const Text(
            'Contact Delivery\nStatus & Brand Fixes',
            style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                height: 1.2),
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'Day 127 fixed text clarity and Samsung Doze. '
            'Today: show per-contact delivery checkmarks in the SOS screen, '
            'and fix Xiaomi/Huawei AutoStart restrictions that silently block alerts.',
            style: TextStyle(
                color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: ZapSpacing.md),
          const Row(children: [
            _HStat('5',      'Contacts tracked', Color(0xFF3B82F6)),
            _HStat('3',      'Brand fixes',      Color(0xFFF97316)),
            _HStat('7',      'Verify checks',    Color(0xFF10B981)),
            _HStat('v0.5.3', 'Ship target',      Color(0xFF8B5CF6)),
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
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w800),
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

// ── Tab bar ────────────────────────────────────────────────────────────────────
class _TabBar extends StatelessWidget {
  final int active;
  final ValueChanged<int> onSelect;
  const _TabBar({required this.active, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.people_rounded,          Color(0xFF3B82F6), 'Delivery Status'),
      (Icons.phone_android_rounded,   Color(0xFFF97316), 'Brand Fixes'),
    ];

    return Row(
      children: List.generate(2, (i) {
        final (icon, color, label) = items[i];
        final isActive = i == active;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: EdgeInsets.only(right: i == 0 ? ZapSpacing.sm : 0),
              padding: const EdgeInsets.symmetric(vertical: 12),
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon,
                      color: isActive ? color : const Color(0xFF6B7280),
                      size: 18),
                  const SizedBox(width: 6),
                  Text(label,
                      style: TextStyle(
                          color: isActive ? color : const Color(0xFF6B7280),
                          fontSize: 12,
                          fontWeight: isActive
                              ? FontWeight.w700
                              : FontWeight.w400)),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ── Delivery Status Tab ────────────────────────────────────────────────────────
class _DeliveryStatusTab extends ConsumerWidget {
  const _DeliveryStatusTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final simState = ref.watch(_deliverySimProvider);
    final statuses = ref.watch(_contactStatusProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(
          icon: Icons.info_outline_rounded,
          color: const Color(0xFFEF4444),
          text: 'Problem: After SOS fires, users see "Emergency alert sent" '
              'but have no idea if contacts actually received the notification. '
              'Contact\'s phone could be off, DND, or have notifications blocked.',
        ),
        const SizedBox(height: ZapSpacing.sm),
        _infoBox(
          icon: Icons.lightbulb_rounded,
          color: const Color(0xFF10B981),
          text: 'Fix: Each contact\'s device sends an ACK webhook to the backend '
              'when the notification is displayed. SOS active screen polls '
              'for ACKs and updates delivery status in real time.',
        ),
        const SizedBox(height: ZapSpacing.xl),

        const _SectionLabel('HOW ACK DELIVERY WORKS'),
        const SizedBox(height: ZapSpacing.md),
        const _AckFlowDiagram(),
        const SizedBox(height: ZapSpacing.xl),

        const _SectionLabel('LIVE DEMO  ·  SOS ACTIVE SCREEN'),
        const SizedBox(height: ZapSpacing.md),

        // Mock SOS active screen with delivery status
        _SosActiveWithDelivery(statuses: statuses, simState: simState),
        const SizedBox(height: ZapSpacing.md),

        if (simState == _DeliveryState.idle)
          _actionButton(
            label: 'Simulate SOS sent → contacts notified',
            icon: Icons.bolt_rounded,
            color: const Color(0xFFEF4444),
            onTap: () async {
              ref.read(_deliverySimProvider.notifier).state =
                  _DeliveryState.sending;
              // Simulate contacts receiving one by one
              for (int i = 0; i < _kContacts.length; i++) {
                await Future.delayed(
                    Duration(milliseconds: _kContacts[i].delayMs));
                if (!context.mounted) return;
                final updated = List<_ContactStatus>.from(
                    ref.read(_contactStatusProvider));
                updated[i].step = _DeliveryStep.delivered;
                ref.read(_contactStatusProvider.notifier).state =
                    List.from(updated);
                ref.read(_deliverySimProvider.notifier).state =
                    _DeliveryState.partial;
              }
              // Priya opens and responds
              await Future.delayed(const Duration(milliseconds: 800));
              if (!context.mounted) return;
              final updated2 = List<_ContactStatus>.from(
                  ref.read(_contactStatusProvider));
              updated2[0].step = _DeliveryStep.opened;
              ref.read(_contactStatusProvider.notifier).state =
                  List.from(updated2);

              await Future.delayed(const Duration(milliseconds: 700));
              if (!context.mounted) return;
              final updated3 = List<_ContactStatus>.from(
                  ref.read(_contactStatusProvider));
              updated3[0]
                ..step = _DeliveryStep.responded
                ..responseText = 'On my way! 5 min away';
              ref.read(_contactStatusProvider.notifier).state =
                  List.from(updated3);
              ref.read(_deliverySimProvider.notifier).state =
                  _DeliveryState.allDelivered;
            },
          )
        else if (simState != _DeliveryState.idle)
          GestureDetector(
            onTap: () {
              ref.read(_deliverySimProvider.notifier).state =
                  _DeliveryState.idle;
              ref.read(_contactStatusProvider.notifier).state =
                  _kContacts
                      .map((c) => _ContactStatus(contact: c))
                      .toList();
            },
            child: const Center(
              child: Text('Reset demo',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
            ),
          ),

        const SizedBox(height: ZapSpacing.lg),

        _codeNote('sos_active_screen.dart',
            '// Poll backend for contact ACKs every 3s\n'
            'final acks = ref.watch(contactAckProvider(sosId));\n'
            '\n'
            'ContactDeliveryRow(\n'
            '  contact: contact,\n'
            '  step: acks[contact.id] ?? DeliveryStep.pending,\n'
            ')'),
      ],
    );
  }
}

class _AckFlowDiagram extends StatelessWidget {
  const _AckFlowDiagram();

  @override
  Widget build(BuildContext context) {
    const steps = [
      (Icons.bolt_rounded,              Color(0xFFEF4444), 'SOS fires',
          'App sends FCM push to all 5 contacts'),
      (Icons.smartphone_rounded,        Color(0xFF3B82F6), 'Device receives',
          'FCM delivers to each contact\'s device'),
      (Icons.notifications_active_rounded, Color(0xFFF59E0B), 'Notification shown',
          'OS displays notification — device sends ACK webhook'),
      (Icons.cloud_done_rounded,        Color(0xFF8B5CF6), 'Backend records',
          'POST /api/v1/sos/ack — stores delivery timestamp per contact'),
      (Icons.check_circle_rounded,      Color(0xFF10B981), 'UI updates',
          'SOS screen polls every 3s — checkmark appears per contact'),
    ];

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        children: steps.asMap().entries.map((e) {
          final i = e.key;
          final (icon, color, title, desc) = e.value;
          final isLast = i == steps.length - 1;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                if (!isLast)
                  Container(
                      width: 2, height: 32,
                      color: const Color(0xFF2A2A2A)),
              ]),
              const SizedBox(width: ZapSpacing.md),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: ZapSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                      Text(desc,
                          style: const TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 11,
                              height: 1.4)),
                    ],
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _SosActiveWithDelivery extends StatelessWidget {
  final List<_ContactStatus> statuses;
  final _DeliveryState simState;
  const _SosActiveWithDelivery(
      {required this.statuses, required this.simState});

  @override
  Widget build(BuildContext context) {
    final deliveredCount =
        statuses.where((s) => s.step.index >= _DeliveryStep.delivered.index).length;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0005),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(
          color: simState == _DeliveryState.idle
              ? const Color(0xFF2A2A2A)
              : const Color(0xFFEF4444).withOpacity(0.5),
          width: simState == _DeliveryState.idle ? 1 : 2,
        ),
      ),
      child: Column(children: [
        // App bar
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: ZapSpacing.md, vertical: 12),
          decoration: BoxDecoration(
            color: simState != _DeliveryState.idle
                ? const Color(0xFFEF4444).withOpacity(0.15)
                : const Color(0xFF111111),
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(ZapSpacing.radius - 1)),
          ),
          child: Row(children: [
            Icon(Icons.warning_rounded,
                color: simState != _DeliveryState.idle
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF4B5563),
                size: 18),
            const SizedBox(width: ZapSpacing.sm),
            Text(
              simState == _DeliveryState.idle ? 'SOS ACTIVE' : 'SOS ACTIVE',
              style: TextStyle(
                  color: simState != _DeliveryState.idle
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF4B5563),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1),
            ),
            const Spacer(),
            if (simState != _DeliveryState.idle)
              Text(
                '$deliveredCount/${statuses.length} delivered',
                style: const TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.all(ZapSpacing.md),
          child: Column(children: [
            // Contact delivery rows
            const _SectionLabel('CONTACT DELIVERY STATUS  ·  NEW IN v0.5.3'),
            const SizedBox(height: ZapSpacing.md),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: Column(
                children: statuses.asMap().entries.map((e) {
                  final i      = e.key;
                  final status = e.value;
                  final isLast = i == statuses.length - 1;

                  return Column(children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: ZapSpacing.md, vertical: 10),
                      child: Row(children: [
                        // Avatar
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: status.contact.color.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(status.contact.initials,
                                style: TextStyle(
                                    color: status.contact.color,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(width: ZapSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(status.contact.name,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              if (status.responseText != null)
                                Text('"${status.responseText!}"',
                                    style: const TextStyle(
                                        color: Color(0xFF10B981),
                                        fontSize: 11,
                                        fontStyle: FontStyle.italic))
                              else
                                Text(status.contact.device,
                                    style: const TextStyle(
                                        color: Color(0xFF6B7280),
                                        fontSize: 10)),
                            ],
                          ),
                        ),
                        // Status indicator
                        _DeliveryBadge(step: status.step),
                      ]),
                    ),
                    if (!isLast)
                      const Divider(height: 1, color: Color(0xFF2A2A2A)),
                  ]);
                }).toList(),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _DeliveryBadge extends StatelessWidget {
  final _DeliveryStep step;
  const _DeliveryBadge({required this.step});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    String label;

    switch (step) {
      case _DeliveryStep.pending:
        color = const Color(0xFF4B5563);
        icon  = Icons.schedule_rounded;
        label = 'Pending';
        break;
      case _DeliveryStep.sent:
        color = const Color(0xFF3B82F6);
        icon  = Icons.send_rounded;
        label = 'Sent';
        break;
      case _DeliveryStep.delivered:
        color = const Color(0xFFF59E0B);
        icon  = Icons.done_all_rounded;
        label = 'Delivered';
        break;
      case _DeliveryStep.opened:
        color = const Color(0xFF10B981);
        icon  = Icons.visibility_rounded;
        label = 'Opened';
        break;
      case _DeliveryStep.responded:
        color = const Color(0xFF10B981);
        icon  = Icons.reply_rounded;
        label = 'Responded';
        break;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 11),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ── Brand Fixes Tab ────────────────────────────────────────────────────────────
class _BrandFixesTab extends ConsumerWidget {
  const _BrandFixesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applied = ref.watch(_brandFixesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(
          icon: Icons.info_outline_rounded,
          color: const Color(0xFFF97316),
          text: 'Problem: Xiaomi, Huawei, and OnePlus devices run custom '
              'Android skins (MIUI / EMUI / OxygenOS) that block background '
              'app launches by default — FCM arrives but ZapSafe never '
              'starts to handle it.',
        ),
        const SizedBox(height: ZapSpacing.lg),

        ..._kBrandFixes.asMap().entries.map((e) {
          final i   = e.key;
          final fix = e.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: ZapSpacing.md),
            child: _BrandFixCard(
              brandFix: fix,
              applied: applied[i],
              onApply: () {
                final updated = List<bool>.from(
                    ref.read(_brandFixesProvider));
                updated[i] = true;
                ref.read(_brandFixesProvider.notifier).state = updated;
              },
            ),
          );
        }),
        const SizedBox(height: ZapSpacing.md),

        // Runtime detection code
        _codeNote('device_compat_service.dart',
            '// Detect Chinese OEM at runtime\n'
            'bool get _isMiui =>\n'
            '  SystemProperty.get(\'ro.miui.ui.version.code\') != null;\n'
            '\n'
            'bool get _isEmui =>\n'
            '  SystemProperty.get(\'ro.build.version.emui\') != null;\n'
            '\n'
            '// Show one-time prompt on first SOS\n'
            'if (_isMiui && !prefs.getBool(\'miui_prompt_shown\', false)) {\n'
            '  showMiuiAutoStartPrompt(context);\n'
            '  prefs.setBool(\'miui_prompt_shown\', true);\n'
            '}'),
      ],
    );
  }
}

class _BrandFixCard extends StatefulWidget {
  final _BrandFix brandFix;
  final bool applied;
  final VoidCallback onApply;
  const _BrandFixCard({
    required this.brandFix,
    required this.applied,
    required this.onApply,
  });

  @override
  State<_BrandFixCard> createState() => _BrandFixCardState();
}

class _BrandFixCardState extends State<_BrandFixCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final fix = widget.brandFix;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: widget.applied
            ? const Color(0xFF10B981).withOpacity(0.06)
            : fix.color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(
          color: widget.applied
              ? const Color(0xFF10B981).withOpacity(0.35)
              : fix.color.withOpacity(0.3),
        ),
      ),
      child: Column(children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.all(ZapSpacing.md),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: widget.applied
                      ? const Color(0xFF10B981).withOpacity(0.12)
                      : fix.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  widget.applied ? Icons.check_rounded : fix.icon,
                  color: widget.applied ? const Color(0xFF10B981) : fix.color,
                  size: 20,
                ),
              ),
              const SizedBox(width: ZapSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fix.brand,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    Text(
                      fix.issue,
                      style: const TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 11,
                          height: 1.3),
                      maxLines: _expanded ? 5 : 1,
                      overflow: _expanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                _expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: const Color(0xFF4B5563),
                size: 18,
              ),
            ]),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          child: _expanded
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(
                      ZapSpacing.md, 0, ZapSpacing.md, ZapSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(height: ZapSpacing.md, color: Color(0xFF2A2A2A)),
                      // Fix description
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Icon(Icons.build_rounded,
                            color: Color(0xFF10B981), size: 14),
                        const SizedBox(width: ZapSpacing.sm),
                        Expanded(
                          child: Text(fix.fix,
                              style: const TextStyle(
                                  color: Color(0xFFD1D5DB),
                                  fontSize: 12,
                                  height: 1.5)),
                        ),
                      ]),
                      const SizedBox(height: ZapSpacing.md),
                      // User steps
                      Container(
                        padding: const EdgeInsets.all(ZapSpacing.sm),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D1117),
                          borderRadius:
                              BorderRadius.circular(ZapSpacing.radiusSmall),
                          border: Border.all(color: const Color(0xFF30363D)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('User steps:',
                                style: TextStyle(
                                    color: Color(0xFF79C0FF),
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            ...fix.steps.asMap().entries.map(
                              (e) => Padding(
                                padding: const EdgeInsets.only(bottom: 3),
                                child: Text(
                                  '${e.key + 1}. ${e.value}',
                                  style: const TextStyle(
                                      color: Color(0xFFE6EDF3),
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                      height: 1.4),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: ZapSpacing.md),
                      GestureDetector(
                        onTap: widget.applied ? null : widget.onApply,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: widget.applied
                                ? const Color(0xFF10B981).withOpacity(0.1)
                                : fix.color.withOpacity(0.12),
                            borderRadius:
                                BorderRadius.circular(ZapSpacing.radiusSmall),
                            border: Border.all(
                              color: widget.applied
                                  ? const Color(0xFF10B981).withOpacity(0.4)
                                  : fix.color.withOpacity(0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                widget.applied
                                    ? Icons.check_rounded
                                    : Icons.build_rounded,
                                color: widget.applied
                                    ? const Color(0xFF10B981)
                                    : fix.color,
                                size: 16,
                              ),
                              const SizedBox(width: ZapSpacing.sm),
                              Text(
                                widget.applied
                                    ? 'Fix applied ✅'
                                    : 'Apply ${fix.brand} fix',
                                style: TextStyle(
                                  color: widget.applied
                                      ? const Color(0xFF10B981)
                                      : fix.color,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ]),
    );
  }
}

// ── Verify checklist ───────────────────────────────────────────────────────────
class _VerifyChecklist extends ConsumerWidget {
  final List<bool> checks;
  final bool allDone;
  const _VerifyChecklist({required this.checks, required this.allDone});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doneCount = checks.where((c) => c).length;

    return Container(
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
        Padding(
          padding: const EdgeInsets.all(ZapSpacing.md),
          child: Column(children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$doneCount / ${_kVerifyChecks.length} verified',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                Text(
                  allDone ? '✅ Ready to ship v0.5.3' : 'Tap to verify',
                  style: TextStyle(
                      color: allDone
                          ? const Color(0xFF10B981)
                          : const Color(0xFF6B7280),
                      fontSize: 11,
                      fontWeight: allDone ? FontWeight.w700 : FontWeight.w400),
                ),
              ],
            ),
            const SizedBox(height: ZapSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: doneCount / _kVerifyChecks.length,
                backgroundColor: const Color(0xFF2A2A2A),
                valueColor: AlwaysStoppedAnimation(
                  allDone ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
                ),
                minHeight: 5,
              ),
            ),
          ]),
        ),
        const Divider(height: 1, color: Color(0xFF2A2A2A)),
        ...List.generate(_kVerifyChecks.length, (i) {
          final done   = checks[i];
          final isLast = i == _kVerifyChecks.length - 1;
          return GestureDetector(
            onTap: () {
              final updated = List<bool>.from(
                  ref.read(_verifyChecksProvider));
              updated[i] = !updated[i];
              ref.read(_verifyChecksProvider.notifier).state = updated;
            },
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: ZapSpacing.md, vertical: 11),
                child: Row(children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      color: done
                          ? const Color(0xFF10B981).withOpacity(0.15)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: done
                              ? const Color(0xFF10B981)
                              : const Color(0xFF4B5563)),
                    ),
                    child: done
                        ? const Icon(Icons.check_rounded,
                            color: Color(0xFF10B981), size: 14)
                        : null,
                  ),
                  const SizedBox(width: ZapSpacing.md),
                  Expanded(
                    child: Text(_kVerifyChecks[i],
                        style: TextStyle(
                          color:
                              done ? const Color(0xFF6B7280) : Colors.white,
                          fontSize: 12,
                          decoration:
                              done ? TextDecoration.lineThrough : null,
                          decorationColor: const Color(0xFF6B7280),
                        )),
                  ),
                ]),
              ),
              if (!isLast)
                const Divider(height: 1, color: Color(0xFF2A2A2A)),
            ]),
          );
        }),
      ]),
    );
  }
}

// ── Ship panel ─────────────────────────────────────────────────────────────────
class _ShipPanel extends ConsumerWidget {
  final bool allVerified;
  final _ShipState state;
  const _ShipPanel({required this.allVerified, required this.state});

  static const _kStates = [
    _ShipState.idle, _ShipState.building, _ShipState.uploading, _ShipState.done,
  ];
  static const _kLabels = [
    '', 'Building v0.5.3 release…', 'Uploading to TestFlight + Play…',
    'v0.5.3 live!',
  ];
  static const _kColors = [
    Color(0xFF3B82F6), Color(0xFF3B82F6), Color(0xFFF59E0B), Color(0xFF10B981),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(
          color: state == _ShipState.done
              ? const Color(0xFF10B981).withOpacity(0.4)
              : const Color(0xFF2A2A2A),
        ),
      ),
      child: Column(children: [
        // What's in v0.5.3
        Container(
          padding: const EdgeInsets.all(ZapSpacing.sm),
          margin: const EdgeInsets.only(bottom: ZapSpacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1117),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF30363D)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('v0.5.3 — Notification Improvements',
                  style: TextStyle(
                      color: Color(0xFF79C0FF),
                      fontSize: 11,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700)),
              SizedBox(height: ZapSpacing.sm),
              Text(
                '✨ Per-contact delivery status in SOS active screen\n'
                '⚡ Notification text clarity (specific names + context)\n'
                '⚡ Samsung Android 13 Doze fix (< 2s delivery)\n'
                '⚡ Xiaomi MIUI AutoStart detection + prompt\n'
                '⚡ Huawei EMUI app launch detection + prompt\n'
                '⚡ OnePlus OxygenOS battery optimisation prompt',
                style: TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 11,
                    fontFamily: 'monospace',
                    height: 1.6),
              ),
            ],
          ),
        ),

        if (state == _ShipState.done) ...[
          const Icon(Icons.check_circle_rounded,
              color: Color(0xFF10B981), size: 44),
          const SizedBox(height: ZapSpacing.md),
          const Text('v0.5.3 shipped!',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            '6 notification improvements · 847 testers updated.\n'
            'Days 127-128 complete.',
            style: TextStyle(
                color: Color(0xFF9CA3AF), fontSize: 12, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ] else if (state != _ShipState.idle)
          ...List.generate(2, (i) {
            final idx     = _kStates.indexOf(state);
            final isDone  = i + 1 < idx;
            final isActive= i + 1 == idx;
            return Padding(
              padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
              child: Row(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    color: isDone
                        ? const Color(0xFF10B981).withOpacity(0.15)
                        : isActive
                            ? _kColors[i + 1].withOpacity(0.15)
                            : const Color(0xFF111111),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDone
                          ? const Color(0xFF10B981).withOpacity(0.5)
                          : isActive
                              ? _kColors[i + 1].withOpacity(0.6)
                              : const Color(0xFF2A2A2A),
                    ),
                  ),
                  child: isDone
                      ? const Icon(Icons.check_rounded,
                          color: Color(0xFF10B981), size: 14)
                      : isActive
                          ? Padding(
                              padding: const EdgeInsets.all(5),
                              child: CircularProgressIndicator(
                                  color: _kColors[i + 1], strokeWidth: 2))
                          : null,
                ),
                const SizedBox(width: ZapSpacing.md),
                Text(_kLabels[i + 1],
                    style: TextStyle(
                        color: isDone
                            ? const Color(0xFF6B7280)
                            : isActive
                                ? Colors.white
                                : const Color(0xFF4B5563),
                        fontSize: 13,
                        fontWeight: isActive
                            ? FontWeight.w600
                            : FontWeight.w400)),
              ]),
            );
          })
        else ...[
          if (!allVerified)
            Container(
              padding: const EdgeInsets.all(ZapSpacing.sm),
              margin: const EdgeInsets.only(bottom: ZapSpacing.md),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.08),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                    color: const Color(0xFFF59E0B).withOpacity(0.3)),
              ),
              child: const Row(children: [
                Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFF59E0B), size: 14),
                SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text('Complete all 7 verification checks first',
                      style: TextStyle(
                          color: Color(0xFFF59E0B), fontSize: 11)),
                ),
              ]),
            ),
          GestureDetector(
            onTap: allVerified
                ? () async {
                    for (final s in _kStates.skip(1)) {
                      if (!context.mounted) return;
                      ref.read(_shipStateProvider.notifier).state = s;
                      await Future.delayed(
                          const Duration(milliseconds: 950));
                    }
                  }
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                gradient: allVerified
                    ? const LinearGradient(
                        colors: [Color(0xFF059669), Color(0xFF10B981)])
                    : null,
                color: allVerified ? null : const Color(0xFF111111),
                borderRadius:
                    BorderRadius.circular(ZapSpacing.radiusSmall),
                boxShadow: allVerified
                    ? [
                        BoxShadow(
                          color: const Color(0xFF10B981).withOpacity(0.3),
                          blurRadius: 16, offset: const Offset(0, 4))
                      ]
                    : null,
                border: allVerified
                    ? null
                    : Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.rocket_launch_rounded,
                      color: allVerified
                          ? Colors.white
                          : const Color(0xFF4B5563),
                      size: 18),
                  const SizedBox(width: ZapSpacing.sm),
                  Text(
                    allVerified
                        ? 'Ship v0.5.3 — Notification bundle'
                        : 'Complete verification first',
                    style: TextStyle(
                      color: allVerified
                          ? Colors.white
                          : const Color(0xFF4B5563),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ]),
    );
  }
}

// ── Next card ──────────────────────────────────────────────────────────────────
class _NextCard extends StatelessWidget {
  const _NextCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(children: [
        _row(const Color(0xFF8B5CF6), 'Days 129-130',
            'Performance optimisation — cold start 5s → 2s, '
            'battery drain, memory usage on low-RAM devices'),
        const Divider(height: 1, color: Color(0xFF2A2A2A)),
        _row(const Color(0xFF3B82F6), 'Days 131-132',
            'Fix memory leaks — location listener, image cache, '
            'database connection cleanup'),
        const Divider(height: 1, color: Color(0xFF2A2A2A)),
        _row(const Color(0xFF10B981), 'Days 133-134',
            'Simplify onboarding — reduce 7 steps → 4, '
            'add permission explanations, target < 2 min total'),
      ]),
    );
  }

  Widget _row(Color color, String days, String action) => Padding(
        padding: const EdgeInsets.all(ZapSpacing.md),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              width: 8, height: 8,
              margin: const EdgeInsets.only(top: 4),
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: ZapSpacing.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(days,
                  style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
              Text(action,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13, height: 1.4)),
            ]),
          ),
        ]),
      );
}

// ── Shared helpers ─────────────────────────────────────────────────────────────
Widget _infoBox({
  required IconData icon,
  required Color color,
  required String text,
}) =>
    Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: ZapSpacing.sm),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6)),
        ),
      ]),
    );

Widget _actionButton({
  required String label,
  required IconData icon,
  required Color color,
  required VoidCallback onTap,
}) =>
    GestureDetector(
      onTap: onTap,
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
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: ZapSpacing.sm),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
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
