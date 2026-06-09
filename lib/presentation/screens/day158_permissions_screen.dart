/// Day 158-160 — App Permissions Management Screen
///
/// 🟢 FRONTEND-ONLY — talks to Android/iOS, never to backend.
/// Uses `permission_handler` package (already in pubspec).
///
/// Why this screen matters:
///   • Users are suspicious of safety apps requesting many permissions
///   • Transparency about WHY each is needed builds trust
///   • Apple/Google review teams verify permission usage is justified
///   • Denied critical permissions break SOS features — users need to know
///
/// Permissions covered:
///   1. Location (always/background) — GPS during SOS
///   2. Microphone              — audio evidence recording
///   3. Camera                  — video evidence recording
///   4. Contacts                — import emergency contacts
///   5. Notifications           — SOS alert delivery
///   6. Physical Activity       — fall/motion detection (M2 model)
///   7. Phone                   — fake call SOS trigger
///   8. Storage / Media         — save evidence files
///
/// Status badges: Granted (green) · Denied (red) · Not Asked (grey)
/// Critical permissions (1, 2, 5) denied → warning banner shown.
/// "Manage" button → openAppSettings() → direct to system app settings.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _activeTabProvider      = StateProvider<int>((ref) => 0);
final _permStatusProvider     = StateProvider<Map<String, _PermStatus>>(
  (ref) => {
    'location':         _PermStatus.granted,
    'microphone':       _PermStatus.granted,
    'camera':           _PermStatus.denied,
    'contacts':         _PermStatus.granted,
    'notifications':    _PermStatus.granted,
    'physicalActivity': _PermStatus.notAsked,
    'phone':            _PermStatus.notAsked,
    'storage':          _PermStatus.granted,
  },
);
final _scanStateProvider      = StateProvider<_ScanState>((ref) => _ScanState.idle);

enum _PermStatus { granted, denied, notAsked }
enum _ScanState  { idle, scanning, done }

// ── Data ───────────────────────────────────────────────────────────────────────
class _Permission {
  final String   id;
  final String   name;
  final IconData icon;
  final Color    color;
  final bool     isCritical;  // denied → warning banner
  final String   whyNeeded;
  final String   featureImpact; // what breaks if denied
  final String   androidPermission; // e.g. ACCESS_FINE_LOCATION
  final String   iosUsageKey;       // e.g. NSLocationAlwaysUsageDescription
  final String   requestMoment;     // when the app asks
  const _Permission({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.isCritical,
    required this.whyNeeded,
    required this.featureImpact,
    required this.androidPermission,
    required this.iosUsageKey,
    required this.requestMoment,
  });
}

const _kPermissions = [
  _Permission(
    id: 'location',
    name: 'Location (Always)',
    icon: Icons.location_on_rounded,
    color: Color(0xFFEF4444),
    isCritical: true,
    whyNeeded:
        'Your GPS location is shared with emergency contacts in real-time '
        'during an active SOS event, and used to calculate safe routes and '
        'the community heatmap. The "Always" variant is required so location '
        'works even when the app is in the background during an emergency.',
    featureImpact:
        '🚨 Critical — SOS contacts cannot find you. '
        'Journey mode, safety map, and heatmap are all disabled.',
    androidPermission: 'ACCESS_FINE_LOCATION + ACCESS_BACKGROUND_LOCATION',
    iosUsageKey: 'NSLocationAlwaysAndWhenInUseUsageDescription',
    requestMoment: 'Onboarding Step 2 (first permission asked)',
  ),
  _Permission(
    id: 'microphone',
    name: 'Microphone',
    icon: Icons.mic_rounded,
    color: Color(0xFF8B5CF6),
    isCritical: true,
    whyNeeded:
        'ZapSafe listens for distress sounds (screams, calls for help) using '
        'our on-device AI model. Audio is processed locally — raw audio is '
        'NEVER uploaded. Microphone also records audio evidence during SOS, '
        'stored encrypted on your device.',
    featureImpact:
        '🚨 Critical — AI scream detection disabled. '
        'Audio evidence not captured. SOS still works via manual triggers.',
    androidPermission: 'RECORD_AUDIO',
    iosUsageKey: 'NSMicrophoneUsageDescription',
    requestMoment: 'Onboarding Step 2 (second permission)',
  ),
  _Permission(
    id: 'camera',
    name: 'Camera',
    icon: Icons.videocam_rounded,
    color: Color(0xFF3B82F6),
    isCritical: false,
    whyNeeded:
        'ZapSafe silently captures front and rear video during an active SOS '
        'event. Video is stored AES-256 encrypted on your device only — never '
        'uploaded unless you explicitly export it. This evidence can be crucial '
        'for police reports or legal proceedings.',
    featureImpact:
        '⚠️ Non-critical — video evidence not captured during SOS. '
        'Audio evidence and GPS evidence still work.',
    androidPermission: 'CAMERA',
    iosUsageKey: 'NSCameraUsageDescription',
    requestMoment: 'First SOS trigger (not during onboarding)',
  ),
  _Permission(
    id: 'contacts',
    name: 'Contacts',
    icon: Icons.people_rounded,
    color: Color(0xFF10B981),
    isCritical: false,
    whyNeeded:
        'To let you pick emergency contacts from your phone\'s contact book '
        'instead of typing numbers manually. We READ your contacts — we never '
        'modify, sync, or upload them. Only the contacts you explicitly add '
        'to ZapSafe are stored on our servers.',
    featureImpact:
        '⚠️ Non-critical — you can still add emergency contacts '
        'by typing their phone number manually.',
    androidPermission: 'READ_CONTACTS',
    iosUsageKey: 'NSContactsUsageDescription',
    requestMoment: 'When you tap "Add from contacts" in Step 3 onboarding',
  ),
  _Permission(
    id: 'notifications',
    name: 'Notifications',
    icon: Icons.notifications_rounded,
    color: Color(0xFFF59E0B),
    isCritical: true,
    whyNeeded:
        'SOS alerts, check-in reminders, contact responses, and app updates '
        'must reach you immediately. Without notifications, you miss: '
        'SOS status updates, contact acknowledgements, '
        'policy update alerts, and drill reminders.',
    featureImpact:
        '🚨 Critical — you will not receive SOS alerts or contact responses. '
        'The app works but operates completely silently.',
    androidPermission: 'POST_NOTIFICATIONS (Android 13+)',
    iosUsageKey: 'NSUserNotificationsUsageDescription (implicit via UNUserNotificationCenter)',
    requestMoment: 'After first successful SOS test drill',
  ),
  _Permission(
    id: 'physicalActivity',
    name: 'Physical Activity',
    icon: Icons.directions_run_rounded,
    color: Color(0xFF06B6D4),
    isCritical: false,
    whyNeeded:
        'The accelerometer and gyroscope detect falls, struggles, and assault '
        'motion patterns. Our M2 Motion Anomaly model processes sensor data '
        'entirely on-device. The "Physical Activity" permission is required '
        'on Android 10+ to access step counter and activity recognition.',
    featureImpact:
        '⚠️ Non-critical — motion/fall detection disabled. '
        'Scream and scene detection still work. Manual SOS triggers still work.',
    androidPermission: 'ACTIVITY_RECOGNITION (Android 10+)',
    iosUsageKey: 'NSMotionUsageDescription',
    requestMoment: 'First app launch on Android 10+ devices',
  ),
  _Permission(
    id: 'phone',
    name: 'Phone / Call Management',
    icon: Icons.phone_rounded,
    color: Color(0xFFF97316),
    isCritical: false,
    whyNeeded:
        'Required for the Fake Call SOS trigger — ZapSafe can simulate an '
        'incoming call so you can escape a threatening situation by pretending '
        'to be called. The app never makes real calls or reads your call log. '
        'On iOS this feature is limited by App Store policy.',
    featureImpact:
        '⚠️ Non-critical — Fake Call SOS trigger disabled. '
        '12 other SOS triggers still work.',
    androidPermission: 'CALL_PHONE + READ_PHONE_STATE',
    iosUsageKey: 'Not available on iOS (App Store restriction)',
    requestMoment: 'First use of Fake Call trigger (optional feature)',
  ),
  _Permission(
    id: 'storage',
    name: 'Storage / Media',
    icon: Icons.folder_rounded,
    color: Color(0xFF9CA3AF),
    isCritical: false,
    whyNeeded:
        'On Android 9 and below, ZapSafe needs storage permission to save '
        'encrypted evidence files. On Android 10+ and all iOS versions, '
        'apps have private storage without this permission — so it is only '
        'requested on older Android devices.',
    featureImpact:
        '⚠️ Non-critical on modern devices (Android 10+, all iOS). '
        'On Android 9 or below: evidence files cannot be saved.',
    androidPermission: 'WRITE_EXTERNAL_STORAGE (Android ≤ 9 only)',
    iosUsageKey: 'Not required (app sandbox storage)',
    requestMoment: 'First SOS on Android 9 or below only',
  ),
];

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day158PermissionsScreen extends ConsumerWidget {
  const Day158PermissionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab      = ref.watch(_activeTabProvider);
    final statuses = ref.watch(_permStatusProvider);
    final scanState= ref.watch(_scanStateProvider);

    // Count denied critical permissions
    final criticalDenied = _kPermissions
        .where((p) => p.isCritical && statuses[p.id] == _PermStatus.denied)
        .length;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('App Permissions'),
        elevation: 0,
        actions: [
          if (criticalDenied > 0)
            Padding(
              padding: const EdgeInsets.only(right: ZapSpacing.md),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFFEF4444).withOpacity(0.4)),
                  ),
                  child: Text('$criticalDenied critical',
                      style: const TextStyle(
                          color: Color(0xFFEF4444),
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
              ),
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

            // Scan panel
            const _SectionLabel('STEP 1  ·  SCAN CURRENT STATUS'),
            const SizedBox(height: ZapSpacing.md),
            _ScanPanel(state: scanState, statuses: statuses),
            const SizedBox(height: ZapSpacing.xl),

            // Critical denied warning
            if (criticalDenied > 0) ...[
              _CriticalWarningBanner(denied: criticalDenied),
              const SizedBox(height: ZapSpacing.xl),
            ],

            // Tab bar
            const _SectionLabel('SELECT VIEW'),
            const SizedBox(height: ZapSpacing.md),
            _TabBar(active: tab,
                onSelect: (t) =>
                    ref.read(_activeTabProvider.notifier).state = t),
            const SizedBox(height: ZapSpacing.xl),

            if (tab == 0)
              _PermissionsListTab(statuses: statuses)
            else if (tab == 1)
              const _PermissionsCodeTab()
            else
              _StatusSummaryTab(statuses: statuses),
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
          colors: [Color(0xFF100E04), Color(0xFF080700), Color(0xFF0A0A0A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _badge('⚡  DAY 158', const Color(0xFFF59E0B)),
            const SizedBox(width: ZapSpacing.sm),
            _badge('🟢 OS-LEVEL ONLY', const Color(0xFF10B981)),
            const SizedBox(width: ZapSpacing.sm),
            _badge('Zero backend', const Color(0xFF9CA3AF)),
          ]),
          const SizedBox(height: ZapSpacing.md),
          const Text(
            'App\nPermissions',
            style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                height: 1.2),
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'Every OS permission ZapSafe uses — why it\'s needed, '
            'its current status, and a direct link to system settings. '
            'Denied critical permissions break SOS features.',
            style: TextStyle(
                color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: ZapSpacing.md),
          const Row(children: [
            _HStat('8',    'Permissions',    Color(0xFFF59E0B)),
            _HStat('3',    'Critical',       Color(0xFFEF4444)),
            _HStat('5',    'Optional',       Color(0xFF10B981)),
            _HStat('OS',   'Level only',     Color(0xFF9CA3AF)),
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
                color: color, fontSize: 11,
                fontWeight: FontWeight.w700, letterSpacing: 0.5)),
      );
}

class _HStat extends StatelessWidget {
  final String value, label;
  final Color  color;
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
          color: Color(0xFF6B7280), fontSize: 10,
          fontWeight: FontWeight.w700, letterSpacing: 1.5));
}

// ── Scan Panel ─────────────────────────────────────────────────────────────────
class _ScanPanel extends ConsumerWidget {
  final _ScanState state;
  final Map<String, _PermStatus> statuses;
  const _ScanPanel({required this.state, required this.statuses});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final granted  = statuses.values.where((s) => s == _PermStatus.granted).length;
    final denied   = statuses.values.where((s) => s == _PermStatus.denied).length;
    final notAsked = statuses.values.where((s) => s == _PermStatus.notAsked).length;

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(children: [
        _codeNote('permission_handler',
            '// Read live permission status (permission_handler package)\n'
            'import \'package:permission_handler/permission_handler.dart\';\n'
            '\n'
            'Future<void> scanPermissions() async {\n'
            '  final location = await Permission.locationAlways.status;\n'
            '  final mic      = await Permission.microphone.status;\n'
            '  final camera   = await Permission.camera.status;\n'
            '  // ... etc\n'
            '  // .status returns: granted | denied | restricted | limited\n'
            '}'),
        const SizedBox(height: ZapSpacing.md),
        if (state == _ScanState.idle)
          _actionButton(
            label: 'Scan permission status (simulated)',
            icon: Icons.radar_rounded,
            color: const Color(0xFFF59E0B),
            onTap: () async {
              ref.read(_scanStateProvider.notifier).state = _ScanState.scanning;
              await Future.delayed(const Duration(milliseconds: 1000));
              if (!context.mounted) return;
              ref.read(_scanStateProvider.notifier).state = _ScanState.done;
            },
          )
        else if (state == _ScanState.scanning)
          _statusChip(Icons.radar_rounded, const Color(0xFFF59E0B),
              'Checking permissions…', loading: true)
        else ...[
          Row(children: [
            _statBox('$granted', 'Granted', const Color(0xFF10B981)),
            const SizedBox(width: ZapSpacing.sm),
            _statBox('$denied', 'Denied', const Color(0xFFEF4444)),
            const SizedBox(width: ZapSpacing.sm),
            _statBox('$notAsked', 'Not asked', const Color(0xFF4B5563)),
          ]),
          const SizedBox(height: ZapSpacing.sm),
          _statusChip(Icons.check_circle_rounded, const Color(0xFF10B981),
              'Scan complete — scroll to see status per permission'),
        ],
      ]),
    );
  }

  Widget _statBox(String value, String label, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: ZapSpacing.sm),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          ),
          child: Column(children: [
            Text(value, style: TextStyle(
                color: color, fontSize: 18, fontWeight: FontWeight.w900)),
            Text(label, style: const TextStyle(
                color: Color(0xFF9CA3AF), fontSize: 9),
                textAlign: TextAlign.center),
          ]),
        ),
      );
}

// ── Critical Warning Banner ────────────────────────────────────────────────────
class _CriticalWarningBanner extends StatelessWidget {
  final int denied;
  const _CriticalWarningBanner({required this.denied});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withOpacity(0.1),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.45)),
      ),
      child: Row(children: [
        const Icon(Icons.warning_rounded, color: Color(0xFFEF4444), size: 20),
        const SizedBox(width: ZapSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$denied critical permission${denied > 1 ? 's' : ''} denied',
                style: const TextStyle(
                    color: Color(0xFFEF4444), fontSize: 13,
                    fontWeight: FontWeight.w700)),
              const Text(
                'Some SOS features are unavailable. '
                'Tap "Manage" on the permission below to fix.',
                style: TextStyle(
                    color: Color(0xFF9CA3AF), fontSize: 11, height: 1.3)),
            ],
          ),
        ),
      ]),
    );
  }
}

// ── Tab bar ────────────────────────────────────────────────────────────────────
class _TabBar extends StatelessWidget {
  final int active;
  final ValueChanged<int> onSelect;
  const _TabBar({required this.active, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.list_rounded,      Color(0xFFF59E0B), 'Permissions'),
      (Icons.code_rounded,      Color(0xFF3B82F6), 'Code'),
      (Icons.analytics_rounded, Color(0xFF10B981), 'Summary'),
    ];
    return Row(
      children: List.generate(3, (i) {
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
                  width: isActive ? 2 : 1,
                ),
              ),
              child: Column(children: [
                Icon(icon,
                    color: isActive ? color : const Color(0xFF6B7280), size: 18),
                const SizedBox(height: 4),
                Text(label,
                    style: TextStyle(
                        color: isActive ? color : const Color(0xFF6B7280),
                        fontSize: 10,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w400)),
              ]),
            ),
          ),
        );
      }),
    );
  }
}

// ── Permissions List Tab ───────────────────────────────────────────────────────
class _PermissionsListTab extends ConsumerWidget {
  final Map<String, _PermStatus> statuses;
  const _PermissionsListTab({required this.statuses});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: _kPermissions.map((perm) {
        final status = statuses[perm.id] ?? _PermStatus.notAsked;
        return Padding(
          padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
          child: _PermissionCard(
            perm: perm,
            status: status,
            onSimulateChange: (s) {
              final updated = Map<String, _PermStatus>.from(
                  ref.read(_permStatusProvider));
              updated[perm.id] = s;
              ref.read(_permStatusProvider.notifier).state = updated;
            },
          ),
        );
      }).toList(),
    );
  }
}

class _PermissionCard extends StatefulWidget {
  final _Permission perm;
  final _PermStatus status;
  final ValueChanged<_PermStatus> onSimulateChange;
  const _PermissionCard({
    required this.perm,
    required this.status,
    required this.onSimulateChange,
  });

  @override
  State<_PermissionCard> createState() => _PermissionCardState();
}

class _PermissionCardState extends State<_PermissionCard> {
  bool _expanded = false;

  Color get _statusColor {
    switch (widget.status) {
      case _PermStatus.granted:   return const Color(0xFF10B981);
      case _PermStatus.denied:    return const Color(0xFFEF4444);
      case _PermStatus.notAsked:  return const Color(0xFF4B5563);
    }
  }

  String get _statusLabel {
    switch (widget.status) {
      case _PermStatus.granted:   return 'Granted';
      case _PermStatus.denied:    return 'Denied';
      case _PermStatus.notAsked:  return 'Not asked';
    }
  }

  IconData get _statusIcon {
    switch (widget.status) {
      case _PermStatus.granted:   return Icons.check_circle_rounded;
      case _PermStatus.denied:    return Icons.cancel_rounded;
      case _PermStatus.notAsked:  return Icons.help_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final perm = widget.perm;
    final isDenied = widget.status == _PermStatus.denied;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isDenied && perm.isCritical
            ? const Color(0xFFEF4444).withOpacity(0.06)
            : perm.color.withOpacity(0.04),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(
          color: isDenied && perm.isCritical
              ? const Color(0xFFEF4444).withOpacity(0.35)
              : const Color(0xFF2A2A2A),
          width: isDenied && perm.isCritical ? 2 : 1,
        ),
      ),
      child: Column(children: [
        // Main row
        Padding(
          padding: const EdgeInsets.all(ZapSpacing.md),
          child: Row(children: [
            // Icon
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: perm.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(perm.icon, color: perm.color, size: 20),
            ),
            const SizedBox(width: ZapSpacing.md),
            // Name + status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(perm.name,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13,
                              fontWeight: FontWeight.w700)),
                    ),
                    if (perm.isCritical)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text('Critical',
                            style: TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 8,
                                fontWeight: FontWeight.w800)),
                      ),
                  ]),
                  Text(perm.whyNeeded,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 10)),
                ],
              ),
            ),
            const SizedBox(width: ZapSpacing.sm),
            // Status badge
            Column(children: [
              Row(children: [
                Icon(_statusIcon, color: _statusColor, size: 12),
                const SizedBox(width: 4),
                Text(_statusLabel,
                    style: TextStyle(
                        color: _statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 4),
              // Manage button
              GestureDetector(
                onTap: () {
                  // In production: await openAppSettings();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Open system settings for ${perm.name}'),
                      backgroundColor: perm.color,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: perm.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: perm.color.withOpacity(0.35)),
                  ),
                  child: Text('Manage',
                      style: TextStyle(
                          color: perm.color,
                          fontSize: 9,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ]),
        ),

        // Expand toggle
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.only(
                left: ZapSpacing.md, right: ZapSpacing.md,
                bottom: ZapSpacing.sm),
            child: Row(children: [
              const SizedBox(width: 52), // align with text
              Icon(
                _expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: const Color(0xFF4B5563), size: 14),
              const SizedBox(width: 4),
              Text(
                _expanded ? 'Hide details' : 'Why is this needed?',
                style: TextStyle(
                    color: perm.color.withOpacity(0.7),
                    fontSize: 10,
                    fontWeight: FontWeight.w600),
              ),
            ]),
          ),
        ),

        // Expanded detail
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          child: _expanded
              ? Container(
                  margin: const EdgeInsets.fromLTRB(
                      ZapSpacing.md, 0, ZapSpacing.md, ZapSpacing.md),
                  child: Column(children: [
                    // Why needed
                    _detailBox(
                        Icons.help_outline_rounded,
                        const Color(0xFF3B82F6),
                        'Why ZapSafe needs this',
                        perm.whyNeeded),
                    const SizedBox(height: ZapSpacing.sm),
                    // Feature impact
                    _detailBox(
                        perm.isCritical
                            ? Icons.warning_rounded
                            : Icons.info_outline_rounded,
                        perm.isCritical
                            ? const Color(0xFFEF4444)
                            : const Color(0xFFF59E0B),
                        'If denied',
                        perm.featureImpact),
                    const SizedBox(height: ZapSpacing.sm),
                    // Technical
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(ZapSpacing.sm),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D1117),
                        borderRadius: BorderRadius.circular(
                            ZapSpacing.radiusSmall),
                        border: Border.all(color: const Color(0xFF30363D)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Android: ${perm.androidPermission}\n'
                            'iOS key: ${perm.iosUsageKey}\n'
                            'When asked: ${perm.requestMoment}',
                            style: const TextStyle(
                                color: Color(0xFF9CA3AF),
                                fontSize: 9,
                                fontFamily: 'monospace',
                                height: 1.6),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: ZapSpacing.sm),
                    // Simulate toggle (demo only)
                    Row(children: [
                      const Text('Simulate: ',
                          style: TextStyle(
                              color: Color(0xFF4B5563), fontSize: 10)),
                      ...[_PermStatus.granted, _PermStatus.denied, _PermStatus.notAsked]
                          .map((s) {
                        final isActive = widget.status == s;
                        final c = s == _PermStatus.granted
                            ? const Color(0xFF10B981)
                            : s == _PermStatus.denied
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF4B5563);
                        final l = s == _PermStatus.granted
                            ? 'Granted'
                            : s == _PermStatus.denied
                                ? 'Denied'
                                : 'Not asked';
                        return GestureDetector(
                          onTap: () => widget.onSimulateChange(s),
                          child: Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? c.withOpacity(0.15)
                                  : const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: isActive
                                      ? c.withOpacity(0.5)
                                      : const Color(0xFF2A2A2A)),
                            ),
                            child: Text(l,
                                style: TextStyle(
                                    color: isActive ? c : const Color(0xFF4B5563),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700)),
                          ),
                        );
                      }),
                    ]),
                  ]),
                )
              : const SizedBox.shrink(),
        ),
      ]),
    );
  }

  Widget _detailBox(IconData icon, Color color, String label, String text) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(ZapSpacing.sm),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: color, size: 12),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 9,
                    fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          ]),
          const SizedBox(height: 4),
          Text(text,
              style: const TextStyle(
                  color: Color(0xFFD1D5DB), fontSize: 11, height: 1.5)),
        ]),
      );
}

// ── Code Tab ───────────────────────────────────────────────────────────────────
class _PermissionsCodeTab extends StatelessWidget {
  const _PermissionsCodeTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(
          icon: Icons.code_rounded,
          color: const Color(0xFF3B82F6),
          text: 'The `permission_handler` package is already in pubspec.yaml. '
              'These are the actual Dart calls used to check and request '
              'each permission. In production, run these on screen load.',
        ),
        const SizedBox(height: ZapSpacing.lg),

        const _SectionLabel('CHECK STATUS'),
        const SizedBox(height: ZapSpacing.md),
        _codeNote('permission_service.dart',
            'import \'package:permission_handler/permission_handler.dart\';\n'
            '\n'
            'class PermissionService {\n'
            '  static Future<Map<String, PermissionStatus>> checkAll() async {\n'
            '    return {\n'
            '      \'location\':         await Permission.locationAlways.status,\n'
            '      \'microphone\':       await Permission.microphone.status,\n'
            '      \'camera\':           await Permission.camera.status,\n'
            '      \'contacts\':         await Permission.contacts.status,\n'
            '      \'notifications\':    await Permission.notification.status,\n'
            '      \'physicalActivity\': await Permission.activityRecognition.status,\n'
            '      \'phone\':            await Permission.phone.status,\n'
            '      \'storage\':          await Permission.storage.status,\n'
            '    };\n'
            '  }\n'
            '}'),
        const SizedBox(height: ZapSpacing.lg),

        const _SectionLabel('REQUEST PERMISSION'),
        const SizedBox(height: ZapSpacing.md),
        _codeNote('request_permission.dart',
            '// Request a single permission:\n'
            'final status = await Permission.microphone.request();\n'
            '\n'
            '// Handle all outcomes:\n'
            'switch (status) {\n'
            '  case PermissionStatus.granted:\n'
            '    // Start recording\n'
            '    break;\n'
            '  case PermissionStatus.denied:\n'
            '    // Show explanation, offer to re-request\n'
            '    break;\n'
            '  case PermissionStatus.permanentlyDenied:\n'
            '    // User chose "Don\'t ask again" — must open settings\n'
            '    await openAppSettings();\n'
            '    break;\n'
            '  default:\n'
            '    break;\n'
            '}'),
        const SizedBox(height: ZapSpacing.lg),

        const _SectionLabel('OPEN SYSTEM SETTINGS'),
        const SizedBox(height: ZapSpacing.md),
        _codeNote('manage_button.dart',
            '// "Manage" button → jump to this app\'s system settings:\n'
            'import \'package:permission_handler/permission_handler.dart\';\n'
            '\n'
            'Future<void> onManageTapped() async {\n'
            '  // Opens: Settings → Apps → ZapSafe → Permissions\n'
            '  final opened = await openAppSettings();\n'
            '  if (!opened) {\n'
            '    showSnackBar(\'Cannot open settings on this device\');\n'
            '  }\n'
            '}'),
        const SizedBox(height: ZapSpacing.lg),

        const _SectionLabel('ANDROID MANIFEST'),
        const SizedBox(height: ZapSpacing.md),
        _codeNote('AndroidManifest.xml',
            '<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />\n'
            '<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />\n'
            '<uses-permission android:name="android.permission.RECORD_AUDIO" />\n'
            '<uses-permission android:name="android.permission.CAMERA" />\n'
            '<uses-permission android:name="android.permission.READ_CONTACTS" />\n'
            '<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />\n'
            '<uses-permission android:name="android.permission.ACTIVITY_RECOGNITION" />\n'
            '<uses-permission android:name="android.permission.CALL_PHONE" />\n'
            '<uses-permission android:name="android.permission.READ_PHONE_STATE" />'),
        const SizedBox(height: ZapSpacing.lg),

        const _SectionLabel('iOS INFO.PLIST KEYS'),
        const SizedBox(height: ZapSpacing.md),
        _codeNote('Info.plist',
            '<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>\n'
            '<string>ZapSafe needs your location to share with emergency contacts during SOS.</string>\n'
            '\n'
            '<key>NSMicrophoneUsageDescription</key>\n'
            '<string>ZapSafe records audio evidence during SOS events, stored encrypted on your device.</string>\n'
            '\n'
            '<key>NSCameraUsageDescription</key>\n'
            '<string>ZapSafe records silent video evidence during SOS events.</string>\n'
            '\n'
            '<key>NSContactsUsageDescription</key>\n'
            '<string>To let you add emergency contacts from your phone book.</string>\n'
            '\n'
            '<key>NSMotionUsageDescription</key>\n'
            '<string>To detect falls and assault motion patterns for emergency detection.</string>'),
      ],
    );
  }
}

// ── Summary Tab ────────────────────────────────────────────────────────────────
class _StatusSummaryTab extends StatelessWidget {
  final Map<String, _PermStatus> statuses;
  const _StatusSummaryTab({required this.statuses});

  @override
  Widget build(BuildContext context) {
    // Group by status
    final granted  = _kPermissions.where((p) => statuses[p.id] == _PermStatus.granted).toList();
    final denied   = _kPermissions.where((p) => statuses[p.id] == _PermStatus.denied).toList();
    final notAsked = _kPermissions.where((p) => statuses[p.id] == _PermStatus.notAsked).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Overview
        Row(children: [
          _summaryBox(granted.length, 'Granted', const Color(0xFF10B981),
              Icons.check_circle_rounded),
          const SizedBox(width: ZapSpacing.sm),
          _summaryBox(denied.length, 'Denied', const Color(0xFFEF4444),
              Icons.cancel_rounded),
          const SizedBox(width: ZapSpacing.sm),
          _summaryBox(notAsked.length, 'Not asked', const Color(0xFF4B5563),
              Icons.help_outline_rounded),
        ]),
        const SizedBox(height: ZapSpacing.xl),

        // Denied (if any)
        if (denied.isNotEmpty) ...[
          const _SectionLabel('ACTION REQUIRED  ·  DENIED PERMISSIONS'),
          const SizedBox(height: ZapSpacing.md),
          ..._permRows(denied, const Color(0xFFEF4444), statuses),
          const SizedBox(height: ZapSpacing.xl),
        ],

        // Not asked
        if (notAsked.isNotEmpty) ...[
          const _SectionLabel('OPTIONAL  ·  NEVER REQUESTED YET'),
          const SizedBox(height: ZapSpacing.md),
          ..._permRows(notAsked, const Color(0xFF4B5563), statuses),
          const SizedBox(height: ZapSpacing.xl),
        ],

        // Granted
        const _SectionLabel('ALL GOOD  ·  GRANTED PERMISSIONS'),
        const SizedBox(height: ZapSpacing.md),
        ..._permRows(granted, const Color(0xFF10B981), statuses),
      ],
    );
  }

  List<Widget> _permRows(List<_Permission> perms, Color color,
      Map<String, _PermStatus> statuses) =>
      perms.map((p) {
        final status = statuses[p.id] ?? _PermStatus.notAsked;
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(
              horizontal: ZapSpacing.md, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Row(children: [
            Icon(p.icon, color: p.color, size: 16),
            const SizedBox(width: ZapSpacing.md),
            Expanded(
              child: Text(p.name,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 12)),
            ),
            if (p.isCritical)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('Critical',
                    style: TextStyle(
                        color: Color(0xFFEF4444), fontSize: 8,
                        fontWeight: FontWeight.w800)),
              ),
            const SizedBox(width: ZapSpacing.sm),
            Icon(
              status == _PermStatus.granted
                  ? Icons.check_circle_rounded
                  : status == _PermStatus.denied
                      ? Icons.cancel_rounded
                      : Icons.help_outline_rounded,
              color: color, size: 14),
            const SizedBox(width: 4),
            Text(
              status == _PermStatus.granted
                  ? 'Granted'
                  : status == _PermStatus.denied
                      ? 'Denied'
                      : 'Not asked',
              style: TextStyle(
                  color: color, fontSize: 10,
                  fontWeight: FontWeight.w700)),
          ]),
        );
      }).toList();

  Widget _summaryBox(int count, String label, Color color, IconData icon) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: ZapSpacing.md),
          decoration: BoxDecoration(
            color: color.withOpacity(0.07),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text('$count',
                style: TextStyle(
                    color: color, fontSize: 20, fontWeight: FontWeight.w900)),
            Text(label,
                style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 9),
                textAlign: TextAlign.center),
          ]),
        ),
      );
}

// ── Shared helpers ─────────────────────────────────────────────────────────────
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
          gradient: LinearGradient(colors: [color, color.withOpacity(0.8)]),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.3), blurRadius: 14,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: ZapSpacing.sm),
          Text(label,
              style: const TextStyle(
                  color: Colors.white, fontSize: 14,
                  fontWeight: FontWeight.w700)),
        ]),
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
            ? SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(color: color, strokeWidth: 2))
            : Icon(icon, color: color, size: 16),
        const SizedBox(width: ZapSpacing.sm),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    );

Widget _infoBox({required IconData icon, required Color color, required String text}) =>
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
        Expanded(child: Text(text,
            style: const TextStyle(
                color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6))),
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
                  color: Color(0xFF79C0FF), fontSize: 10,
                  fontFamily: 'monospace')),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Text(code,
            style: const TextStyle(
                color: Color(0xFFE6EDF3), fontSize: 10,
                fontFamily: 'monospace', height: 1.6)),
      ]),
    );
