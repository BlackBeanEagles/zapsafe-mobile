/// Day 160 — Permission Recovery Guide & Health Dashboard
///
/// Third and final day of the Days 158-160 Permissions block.
/// Day 158: permissions list + code reference.
/// Day 159: request flow + SOS feature map + status badge.
/// Day 160: completing the block with:
///
///   1. Permission Recovery Guide — device/OEM-specific step-by-step
///      instructions for RE-ENABLING a permanently denied permission.
///      Users who tap "Don't ask again" see no system dialog ever again —
///      they must go through Settings manually. This guide helps them.
///
///   2. Request Timing Map — documents WHEN each permission is requested
///      during the app lifecycle (not all on first launch). Each has a
///      clear "Why now?" explanation matching the in-context pattern.
///
///   3. Permission Health Dashboard — the final comprehensive view:
///      score, quick-fix button for each denied permission, and the
///      complete path from 0 granted → all granted.
///
/// All 🟢 FRONTEND-ONLY — zero backend. Section B begins next.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';
// Shared symbols copied from day158 (private symbols can't cross library boundaries)
enum _PermStatus { granted, denied, notAsked }

class _Permission {
  final String   id;
  final String   name;
  final IconData icon;
  final Color    color;
  final bool     isCritical;
  final String   whyNeeded;
  final String   featureImpact;
  final String   androidPermission;
  final String   iosUsageKey;
  final String   requestMoment;
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
  _Permission(id: 'location', name: 'Location (Always)', icon: Icons.location_on_rounded, color: Color(0xFFEF4444), isCritical: true,
    whyNeeded: 'GPS location shared with emergency contacts in real-time during SOS.',
    featureImpact: 'Critical — SOS contacts cannot find you. Journey mode, safety map, and heatmap are all disabled.',
    androidPermission: 'ACCESS_FINE_LOCATION + ACCESS_BACKGROUND_LOCATION', iosUsageKey: 'NSLocationAlwaysAndWhenInUseUsageDescription', requestMoment: 'Onboarding Step 2'),
  _Permission(id: 'microphone', name: 'Microphone', icon: Icons.mic_rounded, color: Color(0xFF8B5CF6), isCritical: true,
    whyNeeded: 'Listens for distress sounds using on-device AI model.',
    featureImpact: 'Critical — AI scream detection disabled. Audio evidence not captured.',
    androidPermission: 'RECORD_AUDIO', iosUsageKey: 'NSMicrophoneUsageDescription', requestMoment: 'Onboarding Step 2'),
  _Permission(id: 'camera', name: 'Camera', icon: Icons.videocam_rounded, color: Color(0xFF3B82F6), isCritical: false,
    whyNeeded: 'Silently captures video during SOS events.',
    featureImpact: 'Non-critical — video evidence not captured during SOS.',
    androidPermission: 'CAMERA', iosUsageKey: 'NSCameraUsageDescription', requestMoment: 'First SOS trigger'),
  _Permission(id: 'contacts', name: 'Contacts', icon: Icons.people_rounded, color: Color(0xFF10B981), isCritical: false,
    whyNeeded: 'Pick emergency contacts from contact book.',
    featureImpact: 'Non-critical — can still add contacts by typing manually.',
    androidPermission: 'READ_CONTACTS', iosUsageKey: 'NSContactsUsageDescription', requestMoment: 'Onboarding Step 3'),
  _Permission(id: 'notifications', name: 'Notifications', icon: Icons.notifications_rounded, color: Color(0xFFF59E0B), isCritical: true,
    whyNeeded: 'SOS alerts, check-in reminders, contact responses.',
    featureImpact: 'Critical — you will not receive SOS alerts or contact responses.',
    androidPermission: 'POST_NOTIFICATIONS (Android 13+)', iosUsageKey: 'NSUserNotificationsUsageDescription', requestMoment: 'After first SOS test drill'),
  _Permission(id: 'physicalActivity', name: 'Physical Activity', icon: Icons.directions_run_rounded, color: Color(0xFF06B6D4), isCritical: false,
    whyNeeded: 'Detects falls, struggles, and assault motion patterns.',
    featureImpact: 'Non-critical — motion/fall detection disabled.',
    androidPermission: 'ACTIVITY_RECOGNITION (Android 10+)', iosUsageKey: 'NSMotionUsageDescription', requestMoment: 'First app launch on Android 10+'),
  _Permission(id: 'phone', name: 'Phone / Call Management', icon: Icons.phone_rounded, color: Color(0xFFF97316), isCritical: false,
    whyNeeded: 'Required for Fake Call SOS trigger.',
    featureImpact: 'Non-critical — Fake Call SOS trigger disabled.',
    androidPermission: 'CALL_PHONE + READ_PHONE_STATE', iosUsageKey: 'Not available on iOS', requestMoment: 'First use of Fake Call trigger'),
  _Permission(id: 'storage', name: 'Storage / Media', icon: Icons.folder_rounded, color: Color(0xFF9CA3AF), isCritical: false,
    whyNeeded: 'On Android 9 and below, needed to save encrypted evidence files.',
    featureImpact: 'Non-critical on modern devices. On Android 9 or below: evidence files cannot be saved.',
    androidPermission: 'WRITE_EXTERNAL_STORAGE (Android <= 9 only)', iosUsageKey: 'Not required', requestMoment: 'First SOS on Android 9 or below'),
];

final _permStatusProvider = StateProvider<Map<String, _PermStatus>>(
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

// ── Providers ──────────────────────────────────────────────────────────────────
final _activeTabProvider     = StateProvider<int>((ref) => 0);
final _selectedOemProvider   = StateProvider<_OemType>((ref) => _OemType.stock);
final _selectedPermForGuide  = StateProvider<String>((ref) => 'microphone');

enum _OemType { stock, samsung, xiaomi, huawei, ios }

// ── Data ───────────────────────────────────────────────────────────────────────
class _OemGuide {
  final _OemType type;
  final String   name;
  final Color    color;
  final IconData icon;
  final List<String> steps;
  const _OemGuide({
    required this.type,
    required this.name,
    required this.color,
    required this.icon,
    required this.steps,
  });
}

const _kOemGuides = [
  _OemGuide(
    type: _OemType.stock,
    name: 'Android (Stock)',
    color: Color(0xFF3DDC84),
    icon: Icons.android_rounded,
    steps: [
      'Open the Settings app',
      'Tap "Apps" or "Applications"',
      'Find and tap "ZapSafe" in the list',
      'Tap "Permissions"',
      'Find the permission you want to enable',
      'Tap it and select "Allow" or "Allow all the time"',
      'Return to ZapSafe — the feature is now available',
    ],
  ),
  _OemGuide(
    type: _OemType.samsung,
    name: 'Samsung (One UI)',
    color: Color(0xFF1428A0),
    icon: Icons.phone_android_rounded,
    steps: [
      'Open Settings → Apps',
      'Tap the three-dot menu (⋮) → "Permission manager"',
      'OR: Settings → Privacy → Permission manager',
      'Tap the permission type (e.g., "Microphone")',
      'Find ZapSafe in the list',
      'Tap ZapSafe → select "Allow" or "Allow only while using"',
      'For Location: also disable "Battery optimization" for ZapSafe',
      'One UI 5+: also enable "Allow background activity"',
    ],
  ),
  _OemGuide(
    type: _OemType.xiaomi,
    name: 'Xiaomi (MIUI)',
    color: Color(0xFFFF6900),
    icon: Icons.phone_android_rounded,
    steps: [
      'Open Settings → Apps → Manage apps',
      'Find and tap "ZapSafe"',
      'Tap "Permissions" → grant the required permission',
      'IMPORTANT: Also tap "Other permissions"',
      '→ Enable "AutoStart" (CRITICAL for background SOS)',
      '→ Enable "Show on lock screen"',
      'Go to Settings → Battery & Performance',
      '→ Choose apps → ZapSafe → No restrictions',
    ],
  ),
  _OemGuide(
    type: _OemType.huawei,
    name: 'Huawei (EMUI)',
    color: Color(0xFFCF0A2C),
    icon: Icons.phone_android_rounded,
    steps: [
      'Open Settings → Apps → Apps',
      'Find and tap "ZapSafe"',
      'Tap "Permissions" → grant required permission',
      'CRITICAL: Tap "App launch"',
      '→ Switch to Manual management',
      '→ Enable "Auto-launch", "Secondary launch", "Run in background"',
      'Go to Battery → App launch → ZapSafe → Manage manually',
      '→ Turn ON "Run in background" and "Launch on start-up"',
    ],
  ),
  _OemGuide(
    type: _OemType.ios,
    name: 'iOS',
    color: Color(0xFF9CA3AF),
    icon: Icons.apple_rounded,
    steps: [
      'Open the Settings app (grey gear icon)',
      'Scroll down and tap "ZapSafe"',
      'Tap the permission you want to change',
      'For Location: select "Always" (not just "While Using")',
      'For Microphone: toggle ON',
      'For Contacts: toggle ON',
      'Return to ZapSafe — changes take effect immediately',
      'Note: iOS may re-ask for location after app update',
    ],
  ),
];

class _TimingEntry {
  final String   permissionId;
  final String   permissionName;
  final IconData icon;
  final Color    color;
  final String   when;
  final String   whyNow;
  const _TimingEntry({
    required this.permissionId,
    required this.permissionName,
    required this.icon,
    required this.color,
    required this.when,
    required this.whyNow,
  });
}

const _kTimingEntries = [
  _TimingEntry(
    permissionId: 'location',
    permissionName: 'Location',
    icon: Icons.location_on_rounded,
    color: Color(0xFFEF4444),
    when: 'Onboarding Step 2 — first permission requested',
    whyNow:
        'Asked first because it is the most critical for the app\'s core function. '
        'Users who grant location are 3× more likely to grant subsequent permissions. '
        '"Your location is needed to notify contacts where you are during SOS."',
  ),
  _TimingEntry(
    permissionId: 'microphone',
    permissionName: 'Microphone',
    icon: Icons.mic_rounded,
    color: Color(0xFF8B5CF6),
    when: 'Onboarding Step 2 — immediately after location',
    whyNow:
        'Grouped with location in Step 2 because both are "core safety" permissions. '
        'Shown immediately after location while user is in the consent mindset. '
        '"We listen for screams to auto-trigger SOS — all processing is on-device."',
  ),
  _TimingEntry(
    permissionId: 'notifications',
    permissionName: 'Notifications',
    icon: Icons.notifications_rounded,
    color: Color(0xFFF59E0B),
    when: 'After first SOS test drill — Step 4 of onboarding',
    whyNow:
        'Deferred until after the user runs their first drill. '
        'By then they have seen SOS in action and understand WHY notifications matter. '
        '"Your contacts need to receive the alert — enable notifications."',
  ),
  _TimingEntry(
    permissionId: 'contacts',
    permissionName: 'Contacts',
    icon: Icons.people_rounded,
    color: Color(0xFF10B981),
    when: 'When user taps "Add from contacts" — Step 3 of onboarding',
    whyNow:
        'Requested in-context when the user explicitly tries to pick a contact. '
        'Never asked proactively. "Pick from your phone book to avoid typos."',
  ),
  _TimingEntry(
    permissionId: 'camera',
    permissionName: 'Camera',
    icon: Icons.videocam_rounded,
    color: Color(0xFF3B82F6),
    when: 'First SOS trigger after onboarding (not during onboarding)',
    whyNow:
        'Deferred to first real use — not during onboarding. '
        'Users in onboarding have enough new information. '
        '"During your first SOS, video evidence was ready to start. Allow camera?"',
  ),
  _TimingEntry(
    permissionId: 'physicalActivity',
    permissionName: 'Physical Activity',
    icon: Icons.directions_run_rounded,
    color: Color(0xFF06B6D4),
    when: 'First app launch on Android 10+ (background, silent on lower)',
    whyNow:
        'Required on Android 10+ for sensor access. Asked on first launch '
        'with minimal explanation — it\'s low-friction and users rarely deny it. '
        '"ZapSafe uses motion sensors to detect falls."',
  ),
  _TimingEntry(
    permissionId: 'phone',
    permissionName: 'Phone',
    icon: Icons.phone_rounded,
    color: Color(0xFFF97316),
    when: 'First use of Fake Call trigger (optional feature)',
    whyNow:
        'Only requested if the user activates the Fake Call feature. '
        'Optional feature — most users never need this. '
        '"Fake Call trigger needs phone access to simulate an incoming call."',
  ),
  _TimingEntry(
    permissionId: 'storage',
    permissionName: 'Storage',
    icon: Icons.folder_rounded,
    color: Color(0xFF9CA3AF),
    when: 'First SOS on Android 9 or below only',
    whyNow:
        'Not needed on Android 10+ (app private storage). '
        'Only requested on Android 9 and below during the first SOS event. '
        'Silent on modern devices.',
  ),
];

// Health thresholds
int _calcHealthScore(Map<String, _PermStatus> statuses) {
  int score = 0;
  for (final perm in _kPermissions) {
    final status = statuses[perm.id] ?? _PermStatus.notAsked;
    if (status == _PermStatus.granted) {
      score += perm.isCritical ? 20 : 10;
    }
  }
  return score.clamp(0, 100);
}

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day160PermissionRecoveryScreen extends ConsumerWidget {
  const Day160PermissionRecoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_activeTabProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Permission Recovery & Health'),
        elevation: 0,
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
            _TabBar(active: tab,
                onSelect: (t) =>
                    ref.read(_activeTabProvider.notifier).state = t),
            const SizedBox(height: ZapSpacing.xl),
            if (tab == 0) const _RecoveryGuideTab(),
            if (tab == 1) const _TimingMapTab(),
            if (tab == 2) const _HealthDashboardTab(),
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
          colors: [Color(0xFF100A04), Color(0xFF080500), Color(0xFF0A0A0A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFFF97316).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _badge('⚡  DAY 160', const Color(0xFFF97316)),
            const SizedBox(width: ZapSpacing.sm),
            _badge('🟢 OS-LEVEL', const Color(0xFF10B981)),
            const SizedBox(width: ZapSpacing.sm),
            _badge('Section B next', const Color(0xFF9CA3AF)),
          ]),
          const SizedBox(height: ZapSpacing.md),
          const Text(
            'Permission Recovery\n& Health Dashboard',
            style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                height: 1.2),
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'OEM-specific guides for re-enabling denied permissions. '
            'Request timing map. Final permission health score — '
            'completing the 3-day permissions block.',
            style: TextStyle(
                color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: ZapSpacing.md),
          const Row(children: [
            _HStat('5',    'OEM guides',      Color(0xFFF97316)),
            _HStat('8',    'Timing entries',  Color(0xFF3B82F6)),
            _HStat('Score','Health meter',    Color(0xFF10B981)),
            _HStat('B→',   'Section B next',  Color(0xFF9CA3AF)),
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
                  color: color, fontSize: 13, fontWeight: FontWeight.w800),
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

// ── Tab bar ────────────────────────────────────────────────────────────────────
class _TabBar extends StatelessWidget {
  final int active;
  final ValueChanged<int> onSelect;
  const _TabBar({required this.active, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.healing_rounded,    Color(0xFFF97316), 'Recovery'),
      (Icons.timeline_rounded,   Color(0xFF3B82F6), 'Timing'),
      (Icons.health_and_safety_rounded, Color(0xFF10B981), 'Health'),
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
                Icon(icon, color: isActive ? color : const Color(0xFF6B7280), size: 18),
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

// ── Recovery Guide Tab ─────────────────────────────────────────────────────────
class _RecoveryGuideTab extends ConsumerWidget {
  const _RecoveryGuideTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final oem    = ref.watch(_selectedOemProvider);
    final guide  = _kOemGuides.firstWhere((g) => g.type == oem);
    final permId = ref.watch(_selectedPermForGuide);
    final perm   = _kPermissions.firstWhere(
        (p) => p.id == permId,
        orElse: () => _kPermissions.first);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(
          icon: Icons.healing_rounded,
          color: const Color(0xFFF97316),
          text: 'When a user taps "Don\'t Ask Again" on the system dialog, '
              'the permission is permanently denied — the system dialog '
              'never appears again. The user MUST go through Settings manually. '
              'This guide provides OEM-specific steps.',
        ),
        const SizedBox(height: ZapSpacing.xl),

        // Permission selector
        const _SectionLabel('1. SELECT THE DENIED PERMISSION'),
        const SizedBox(height: ZapSpacing.md),
        _PermSelector(
            current: permId,
            onSelect: (id) =>
                ref.read(_selectedPermForGuide.notifier).state = id),
        const SizedBox(height: ZapSpacing.xl),

        // OEM selector
        const _SectionLabel('2. SELECT DEVICE / OS'),
        const SizedBox(height: ZapSpacing.md),
        _OemSelector(
            current: oem,
            onSelect: (t) =>
                ref.read(_selectedOemProvider.notifier).state = t),
        const SizedBox(height: ZapSpacing.xl),

        // Guide
        const _SectionLabel('3. FOLLOW THESE STEPS'),
        const SizedBox(height: ZapSpacing.md),
        _GuideCard(guide: guide, perm: perm),
        const SizedBox(height: ZapSpacing.lg),

        // "Open Settings" button
        _actionButton(
          label: 'Open ZapSafe in system settings (demo)',
          icon: Icons.settings_rounded,
          color: guide.color,
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'In production: openAppSettings() → '
                  'Settings → Apps → ZapSafe → Permissions'),
              backgroundColor: guide.color,
              duration: const Duration(seconds: 3),
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Important note for critical permissions
        if (perm.isCritical)
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withOpacity(0.08),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(
                  color: const Color(0xFFEF4444).withOpacity(0.35)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.priority_high_rounded,
                    color: Color(0xFFEF4444), size: 16),
                SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    'This is a CRITICAL permission. ZapSafe cannot fully '
                    'protect you without it. Please enable it and run a '
                    'test drill (Settings → Drill Mode) to confirm everything works.',
                    style: TextStyle(
                        color: Color(0xFFFFD0CA),
                        fontSize: 11, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PermSelector extends StatelessWidget {
  final String current;
  final ValueChanged<String> onSelect;
  const _PermSelector({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _kPermissions.map((p) {
          final isActive = p.id == current;
          return GestureDetector(
            onTap: () => onSelect(p.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: ZapSpacing.sm),
              padding: const EdgeInsets.symmetric(
                  horizontal: ZapSpacing.md, vertical: 9),
              decoration: BoxDecoration(
                color: isActive ? p.color.withOpacity(0.12) : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                    color: isActive ? p.color.withOpacity(0.5) : const Color(0xFF2A2A2A),
                    width: isActive ? 2 : 1),
              ),
              child: Row(children: [
                Icon(p.icon,
                    color: isActive ? p.color : const Color(0xFF4B5563),
                    size: 14),
                const SizedBox(width: 5),
                Text(p.name.split(' ').first,
                    style: TextStyle(
                        color: isActive ? p.color : const Color(0xFF6B7280),
                        fontSize: 10,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w400)),
                if (p.isCritical) ...[
                  const SizedBox(width: 4),
                  Container(
                    width: 6, height: 6,
                    decoration: const BoxDecoration(
                        color: Color(0xFFEF4444), shape: BoxShape.circle),
                  ),
                ],
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _OemSelector extends StatelessWidget {
  final _OemType current;
  final ValueChanged<_OemType> onSelect;
  const _OemSelector({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _kOemGuides.map((g) {
        final isActive = g.type == current;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(g.type),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: EdgeInsets.only(
                  right: g != _kOemGuides.last ? ZapSpacing.sm : 0),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isActive ? g.color.withOpacity(0.12) : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                    color: isActive ? g.color.withOpacity(0.5) : const Color(0xFF2A2A2A),
                    width: isActive ? 2 : 1),
              ),
              child: Column(children: [
                Icon(g.icon,
                    color: isActive ? g.color : const Color(0xFF4B5563), size: 18),
                const SizedBox(height: 3),
                Text(g.name.split(' ').first,
                    style: TextStyle(
                        color: isActive ? g.color : const Color(0xFF6B7280),
                        fontSize: 9,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w400),
                    textAlign: TextAlign.center),
              ]),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _GuideCard extends StatelessWidget {
  final _OemGuide guide;
  final dynamic   perm;
  const _GuideCard({required this.guide, required this.perm});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: guide.color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: guide.color.withOpacity(0.35), width: 2),
      ),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: guide.color.withOpacity(0.1),
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(ZapSpacing.radius - 2)),
          ),
          child: Row(children: [
            Icon(guide.icon, color: guide.color, size: 18),
            const SizedBox(width: ZapSpacing.sm),
            Text('${guide.name} · Re-enable ${(perm.name as String).split(' ').first}',
                style: TextStyle(
                    color: guide.color, fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
        // Steps
        Padding(
          padding: const EdgeInsets.all(ZapSpacing.md),
          child: Column(
            children: guide.steps.asMap().entries.map((e) {
              final i    = e.key;
              final step = e.value;
              final isLast = i == guide.steps.length - 1;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(children: [
                    Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(
                        color: guide.color.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text('${i + 1}',
                            style: TextStyle(
                                color: guide.color,
                                fontSize: 11,
                                fontWeight: FontWeight.w800)),
                      ),
                    ),
                    if (!isLast)
                      Container(
                          width: 2,
                          height: 24,
                          color: guide.color.withOpacity(0.2)),
                  ]),
                  const SizedBox(width: ZapSpacing.sm),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(
                          bottom: ZapSpacing.sm, top: 3),
                      child: Text(step,
                          style: const TextStyle(
                              color: Color(0xFFD1D5DB),
                              fontSize: 12, height: 1.4)),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }
}

// ── Timing Map Tab ─────────────────────────────────────────────────────────────
class _TimingMapTab extends StatelessWidget {
  const _TimingMapTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(
          icon: Icons.timeline_rounded,
          color: const Color(0xFF3B82F6),
          text: 'Never request all permissions on first launch — '
              'this is the #1 reason users deny and uninstall. '
              'Each permission is requested at the exact moment '
              'it is needed, with full context.',
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Timeline
        ..._kTimingEntries.asMap().entries.map((e) {
          final i     = e.key;
          final entry = e.value;
          final isLast= i == _kTimingEntries.length - 1;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline line + icon
              Column(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: entry.color.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: entry.color.withOpacity(0.4)),
                  ),
                  child: Icon(entry.icon, color: entry.color, size: 18),
                ),
                if (!isLast)
                  Container(
                      width: 2, height: 40,
                      color: const Color(0xFF2A2A2A)),
              ]),
              const SizedBox(width: ZapSpacing.md),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                      bottom: isLast ? 0 : ZapSpacing.sm, top: 6),
                  child: Container(
                    padding: const EdgeInsets.all(ZapSpacing.md),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius:
                          BorderRadius.circular(ZapSpacing.radiusSmall),
                      border: Border.all(color: const Color(0xFF2A2A2A)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Text(entry.permissionName,
                                style: TextStyle(
                                    color: entry.color,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ]),
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: entry.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('📍 ${entry.when}',
                              style: TextStyle(
                                  color: entry.color,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(height: ZapSpacing.sm),
                        Text(entry.whyNow,
                            style: const TextStyle(
                                color: Color(0xFF9CA3AF),
                                fontSize: 11, height: 1.4)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
        const SizedBox(height: ZapSpacing.lg),

        _codeNote('permission_timing_guide',
            '// Principle: ask at the right moment, not all at once\n'
            '//\n'
            '// ✅ DO: Request location in onboarding AFTER explaining SOS\n'
            '// ✅ DO: Request camera on first SOS with "video evidence ready?"\n'
            '// ✅ DO: Request contacts when user taps "Add from contacts"\n'
            '//\n'
            '// ❌ DON\'T: Request all 8 permissions on app first launch\n'
            '// ❌ DON\'T: Request before user understands why\n'
            '// ❌ DON\'T: Request optional permissions before core ones'),
      ],
    );
  }
}

// ── Health Dashboard Tab ───────────────────────────────────────────────────────
class _HealthDashboardTab extends ConsumerWidget {
  const _HealthDashboardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statuses = ref.watch(_permStatusProvider);
    final score    = _calcHealthScore(statuses);

    final granted  = _kPermissions.where((p) => statuses[p.id] == _PermStatus.granted).length;
    final denied   = _kPermissions.where((p) => statuses[p.id] == _PermStatus.denied).length;
    final notAsked = _kPermissions.where((p) => statuses[p.id] == _PermStatus.notAsked).length;

    final scoreColor = score >= 80
        ? const Color(0xFF10B981)
        : score >= 50
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Score ring
        Container(
          padding: const EdgeInsets.all(ZapSpacing.lg),
          decoration: BoxDecoration(
            color: scoreColor.withOpacity(0.07),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: scoreColor.withOpacity(0.4)),
          ),
          child: Column(children: [
            Row(children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scoreColor.withOpacity(0.12),
                  border: Border.all(
                      color: scoreColor.withOpacity(0.5), width: 3),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$score',
                          style: TextStyle(
                              color: scoreColor, fontSize: 28,
                              fontWeight: FontWeight.w900)),
                      Text('/100',
                          style: TextStyle(
                              color: scoreColor.withOpacity(0.6),
                              fontSize: 9)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: ZapSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      score >= 80
                          ? 'Permission Health: Excellent'
                          : score >= 50
                              ? 'Permission Health: Good'
                              : 'Permission Health: Action Needed',
                      style: TextStyle(
                          color: scoreColor, fontSize: 15,
                          fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$granted granted · $denied denied · $notAsked not asked',
                      style: const TextStyle(
                          color: Color(0xFF9CA3AF), fontSize: 11),
                    ),
                    const SizedBox(height: ZapSpacing.sm),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: score / 100,
                        backgroundColor: const Color(0xFF2A2A2A),
                        valueColor: AlwaysStoppedAnimation(scoreColor),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: ZapSpacing.xl),

        // Score breakdown
        const _SectionLabel('SCORE BREAKDOWN'),
        const SizedBox(height: ZapSpacing.sm),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.sm),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Column(children: [
            _scoreRow('Critical permission (×3)', 20,
                '20 pts each when granted', const Color(0xFFEF4444)),
            const Divider(height: ZapSpacing.sm, color: Color(0xFF2A2A2A)),
            _scoreRow('Optional permission (×5)', 10,
                '10 pts each when granted', const Color(0xFF3B82F6)),
          ]),
        ),
        const SizedBox(height: ZapSpacing.xl),

        // Quick fix cards for denied permissions
        if (denied > 0) ...[
          const _SectionLabel('QUICK FIX  ·  DENIED PERMISSIONS'),
          const SizedBox(height: ZapSpacing.md),
          ..._kPermissions
              .where((p) => statuses[p.id] == _PermStatus.denied)
              .map((p) => _QuickFixCard(perm: p, ref: ref)),
          const SizedBox(height: ZapSpacing.xl),
        ],

        // All permissions health rows
        const _SectionLabel('ALL PERMISSIONS  ·  CURRENT HEALTH'),
        const SizedBox(height: ZapSpacing.md),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Column(
            children: _kPermissions.asMap().entries.map((e) {
              final i      = e.key;
              final perm   = e.value;
              final status = statuses[perm.id] ?? _PermStatus.notAsked;
              final isLast = i == _kPermissions.length - 1;
              final statusColor = status == _PermStatus.granted
                  ? const Color(0xFF10B981)
                  : status == _PermStatus.denied
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF4B5563);
              final pts = status == _PermStatus.granted
                  ? (perm.isCritical ? 20 : 10)
                  : 0;

              return Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: ZapSpacing.md, vertical: 10),
                  child: Row(children: [
                    Icon(perm.icon, color: perm.color, size: 16),
                    const SizedBox(width: ZapSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(perm.name,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                          Row(children: [
                            if (perm.isCritical)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                margin: const EdgeInsets.only(right: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: const Text('Critical',
                                    style: TextStyle(
                                        color: Color(0xFFEF4444),
                                        fontSize: 7,
                                        fontWeight: FontWeight.w800)),
                              ),
                            Text(
                              status == _PermStatus.granted
                                  ? 'Granted'
                                  : status == _PermStatus.denied
                                      ? 'Denied — tap to fix'
                                      : 'Not yet requested',
                              style: TextStyle(
                                  color: statusColor,
                                  fontSize: 9),
                            ),
                          ]),
                        ],
                      ),
                    ),
                    // Points
                    Column(children: [
                      Text('+$pts',
                          style: TextStyle(
                              color: pts > 0
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF4B5563),
                              fontSize: 14,
                              fontWeight: FontWeight.w900)),
                      Text('pts',
                          style: const TextStyle(
                              color: Color(0xFF4B5563), fontSize: 8)),
                    ]),
                    const SizedBox(width: ZapSpacing.sm),
                    // Simulate toggle
                    GestureDetector(
                      onTap: () {
                        final updated = Map<String, _PermStatus>.from(
                            ref.read(_permStatusProvider));
                        final current = updated[perm.id] ?? _PermStatus.notAsked;
                        updated[perm.id] = current == _PermStatus.granted
                            ? _PermStatus.denied
                            : current == _PermStatus.denied
                                ? _PermStatus.notAsked
                                : _PermStatus.granted;
                        ref.read(_permStatusProvider.notifier).state = updated;
                      },
                      child: Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: statusColor.withOpacity(0.35)),
                        ),
                        child: Icon(
                          status == _PermStatus.granted
                              ? Icons.check_rounded
                              : status == _PermStatus.denied
                                  ? Icons.close_rounded
                                  : Icons.help_outline_rounded,
                          color: statusColor, size: 14),
                      ),
                    ),
                  ]),
                ),
                if (!isLast)
                  const Divider(height: 1, color: Color(0xFF2A2A2A)),
              ]);
            }).toList(),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Block B teaser
        Container(
          padding: const EdgeInsets.all(ZapSpacing.lg),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              const Color(0xFF8B5CF6).withOpacity(0.12),
              const Color(0xFF8B5CF6).withOpacity(0.04),
            ]),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(
                color: const Color(0xFF8B5CF6).withOpacity(0.4)),
          ),
          child: Column(children: [
            const Icon(Icons.check_circle_rounded,
                color: Color(0xFF10B981), size: 36),
            const SizedBox(height: ZapSpacing.md),
            const Text('Days 158-160: Permissions Block Complete ✅',
                style: TextStyle(
                    color: Colors.white, fontSize: 15,
                    fontWeight: FontWeight.w800),
                textAlign: TextAlign.center),
            const SizedBox(height: ZapSpacing.sm),
            const Text(
              'Day 158: permissions list + code\n'
              'Day 159: request flow + SOS map + badge\n'
              'Day 160: recovery guide + timing + health',
              style: TextStyle(
                  color: Color(0xFF9CA3AF), fontSize: 12, height: 1.6),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: ZapSpacing.lg),
            _infoBox(
              icon: Icons.arrow_forward_rounded,
              color: const Color(0xFF8B5CF6),
              text: 'Days 161-162: First-Launch Consent Flow — '
                  'the gate that appears before the dashboard on first run, '
                  'requiring Privacy Policy + Terms acceptance.',
            ),
          ]),
        ),
      ],
    );
  }

  Widget _scoreRow(String label, int pts, String desc, Color color) =>
      Padding(
        padding: const EdgeInsets.all(ZapSpacing.sm),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('+$pts pts',
                style: TextStyle(
                    color: color, fontSize: 11,
                    fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 11)),
                Text(desc,
                    style: const TextStyle(
                        color: Color(0xFF6B7280), fontSize: 9)),
              ],
            ),
          ),
        ]),
      );
}

class _QuickFixCard extends StatelessWidget {
  final dynamic  perm;
  final WidgetRef ref;
  const _QuickFixCard({required this.perm, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withOpacity(0.07),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(
            color: const Color(0xFFEF4444).withOpacity(0.35)),
      ),
      child: Row(children: [
        Icon(perm.icon as IconData,
            color: perm.color as Color, size: 18),
        const SizedBox(width: ZapSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(perm.name as String,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const Text('Denied — open Settings to re-enable',
                  style: TextStyle(
                      color: Color(0xFFEF4444), fontSize: 10)),
            ],
          ),
        ),
        GestureDetector(
          onTap: () {
            // Simulate granting
            final updated = Map<String, _PermStatus>.from(
                ref.read(_permStatusProvider));
            updated[perm.id as String] = _PermStatus.granted;
            ref.read(_permStatusProvider.notifier).state = updated;
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: (perm.color as Color),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Fix now',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
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
