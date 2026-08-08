/// Day 159 — Permission Request Flow & SOS Feature Availability
///
/// Second day of the Days 158-160 Permissions block.
/// Day 158 built the permissions list + code reference.
/// Day 159 builds the runtime infrastructure:
///
///   1. Permission Request Flow — the "Why we need this" rationale
///      card shown BEFORE each system permission dialog. Users who
///      see context are 2.4× more likely to grant permission.
///      Shows: what it does, what happens if denied, then the system dialog.
///
///   2. SOS Feature Availability Map — given the current permission
///      state, which SOS features are FULLY available, PARTIALLY
///      available, or BLOCKED. Helps users understand consequences.
///
///   3. PermissionStatusBadge — a tiny reusable widget any screen
///      can display to show a permission's current status inline.
///
/// All 🟢 FRONTEND-ONLY — OS-level, zero backend.
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
final _activeTabProvider    = StateProvider<int>((ref) => 0);
final _demoPermProvider     = StateProvider<String>((ref) => 'microphone');
final _flowStepProvider     = StateProvider<int>((ref) => 0);
final _flowStartedProvider  = StateProvider<bool>((ref) => false);

// ── Data ───────────────────────────────────────────────────────────────────────
class _SosFeature {
  final String   name;
  final IconData icon;
  final Color    color;
  final List<String> requiredPermissions; // permission ids that must ALL be granted
  final List<String> optionalPermissions; // improves but not required
  final String   fullDescription;
  final String   partialDescription; // when some optional are missing
  final String   blockedDescription; // when required are missing
  const _SosFeature({
    required this.name,
    required this.icon,
    required this.color,
    required this.requiredPermissions,
    required this.optionalPermissions,
    required this.fullDescription,
    required this.partialDescription,
    required this.blockedDescription,
  });
}

enum _FeatureAvailability { full, partial, blocked }

const _kSosFeatures = [
  _SosFeature(
    name: 'SOS Alert to Contacts',
    icon: Icons.emergency_rounded,
    color: Color(0xFFEF4444),
    requiredPermissions: ['location', 'notifications'],
    optionalPermissions: [],
    fullDescription:
        'Contacts receive push notification + real-time GPS location link. '
        'They can see exactly where you are on a map.',
    partialDescription:
        'Contacts notified but without real-time location '
        '(location or notification permission missing).',
    blockedDescription:
        'Cannot send SOS alerts to contacts. '
        'Both Location and Notifications are required.',
  ),
  _SosFeature(
    name: 'AI Scream Detection',
    icon: Icons.hearing_rounded,
    color: Color(0xFF8B5CF6),
    requiredPermissions: ['microphone'],
    optionalPermissions: [],
    fullDescription:
        'Continuous on-device audio analysis using the M1 Scream Classifier. '
        'Detects distress vocalisations and auto-triggers SOS.',
    partialDescription: '',
    blockedDescription:
        'Microphone required for scream detection. '
        'Auto-trigger via audio is disabled — use manual triggers.',
  ),
  _SosFeature(
    name: 'Motion/Fall Detection',
    icon: Icons.vibration_rounded,
    color: Color(0xFF06B6D4),
    requiredPermissions: ['physicalActivity'],
    optionalPermissions: [],
    fullDescription:
        'M2 Motion Anomaly model processes accelerometer and gyroscope data '
        'to detect falls, struggles, and assault motion patterns.',
    partialDescription: '',
    blockedDescription:
        'Physical Activity permission required on Android 10+. '
        'Motion detection disabled — other triggers still work.',
  ),
  _SosFeature(
    name: 'Audio Evidence',
    icon: Icons.mic_rounded,
    color: Color(0xFFF97316),
    requiredPermissions: ['microphone'],
    optionalPermissions: [],
    fullDescription:
        'Silent audio recording during SOS, stored AES-256 encrypted '
        'on your device. Hash-stamped for legal admissibility.',
    partialDescription: '',
    blockedDescription:
        'Microphone denied. No audio evidence captured during SOS. '
        'GPS and metadata evidence still collected.',
  ),
  _SosFeature(
    name: 'Video Evidence',
    icon: Icons.videocam_rounded,
    color: Color(0xFF3B82F6),
    requiredPermissions: ['camera'],
    optionalPermissions: ['microphone'],
    fullDescription:
        'Silent front + rear camera recording during SOS. '
        'Full video evidence with audio included.',
    partialDescription:
        'Video evidence only (no audio track). '
        'Camera granted but microphone denied.',
    blockedDescription:
        'Camera permission denied. No video evidence captured. '
        'Audio evidence still captured if mic is granted.',
  ),
  _SosFeature(
    name: 'Journey Mode',
    icon: Icons.directions_walk_rounded,
    color: Color(0xFF10B981),
    requiredPermissions: ['location'],
    optionalPermissions: ['notifications'],
    fullDescription:
        'Share your live route with a trusted contact. '
        'They receive notification updates and see your progress on a map.',
    partialDescription:
        'Journey tracking works but contact cannot see notifications '
        '(they see only the WebLink map view).',
    blockedDescription:
        'Location permission required for Journey Mode. '
        'Feature completely disabled.',
  ),
  _SosFeature(
    name: 'Fake Call Trigger',
    icon: Icons.phone_rounded,
    color: Color(0xFFF59E0B),
    requiredPermissions: ['phone'],
    optionalPermissions: [],
    fullDescription:
        'Simulate an incoming call to escape a threatening situation. '
        'Only available on Android (iOS App Store restriction).',
    partialDescription: '',
    blockedDescription:
        'Phone permission required for Fake Call trigger on Android. '
        '12 other SOS triggers still available.',
  ),
  _SosFeature(
    name: 'Add Contacts from Phone Book',
    icon: Icons.person_add_rounded,
    color: Color(0xFF9CA3AF),
    requiredPermissions: ['contacts'],
    optionalPermissions: [],
    fullDescription:
        'Pick emergency contacts directly from your phone\'s contact book '
        'instead of typing numbers manually.',
    partialDescription: '',
    blockedDescription:
        'Contacts permission denied. Add contacts by typing '
        'their phone number manually instead.',
  ),
];

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day159PermissionFlowScreen extends ConsumerWidget {
  const Day159PermissionFlowScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_activeTabProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Permission Flow & Availability'),
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
            if (tab == 0) const _RequestFlowTab(),
            if (tab == 1) const _FeatureAvailabilityTab(),
            if (tab == 2) const _StatusBadgeTab(),
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
          colors: [Color(0xFF0A0A14), Color(0xFF05050A), Color(0xFF0A0A0A)],
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
            _badge('⚡  DAY 159', const Color(0xFF3B82F6)),
            const SizedBox(width: ZapSpacing.sm),
            _badge('🟢 OS-LEVEL', const Color(0xFF10B981)),
          ]),
          const SizedBox(height: ZapSpacing.md),
          const Text(
            'Permission Flow\n& SOS Availability',
            style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                height: 1.2),
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'Rationale cards shown BEFORE system dialogs (2.4× grant rate). '
            'SOS feature availability map based on granted permissions. '
            'Inline status badge widget.',
            style: TextStyle(
                color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: ZapSpacing.md),
          const Row(children: [
            _HStat('2.4×',  'Grant rate boost', Color(0xFF10B981)),
            _HStat('8',     'SOS features',     Color(0xFF3B82F6)),
            _HStat('3',     'States tracked',   Color(0xFF8B5CF6)),
            _HStat('Badge', 'Inline widget',    Color(0xFFF59E0B)),
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
      (Icons.play_circle_rounded,  Color(0xFF3B82F6), 'Request Flow'),
      (Icons.map_rounded,          Color(0xFF10B981), 'SOS Features'),
      (Icons.label_rounded,        Color(0xFFF59E0B), 'Status Badge'),
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
                const SizedBox(height: ZapSpacing.xs),
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

// ── Request Flow Tab ───────────────────────────────────────────────────────────
class _RequestFlowTab extends ConsumerWidget {
  const _RequestFlowTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demoPermId = ref.watch(_demoPermProvider);
    final step       = ref.watch(_flowStepProvider);
    final started    = ref.watch(_flowStartedProvider);

    // Find the perm from Day 158 data
    final perm = _kPermissions.firstWhere(
        (p) => p.id == demoPermId,
        orElse: () => _kPermissions.first);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(
          icon: Icons.info_outline_rounded,
          color: const Color(0xFF3B82F6),
          text: 'Users granted permission 2.4× more often when shown '
              'a plain-language rationale BEFORE the system dialog. '
              'ZapSafe shows a "Why we need this" card first, then triggers '
              'the system prompt only when the user taps "Continue".',
        ),
        const SizedBox(height: ZapSpacing.xl),

        // Permission picker
        const _SectionLabel('SELECT PERMISSION TO DEMO'),
        const SizedBox(height: ZapSpacing.md),
        _PermPicker(
            current: demoPermId,
            onSelect: (id) {
              ref.read(_demoPermProvider.notifier).state = id;
              ref.read(_flowStepProvider.notifier).state = 0;
              ref.read(_flowStartedProvider.notifier).state = false;
            }),
        const SizedBox(height: ZapSpacing.xl),

        // Flow demo
        const _SectionLabel('PERMISSION REQUEST FLOW  ·  LIVE DEMO'),
        const SizedBox(height: ZapSpacing.md),

        if (!started) ...[
          _actionButton(
            label: 'Start permission request flow',
            icon: Icons.play_arrow_rounded,
            color: const Color(0xFF3B82F6),
            onTap: () {
              ref.read(_flowStartedProvider.notifier).state = true;
              ref.read(_flowStepProvider.notifier).state = 0;
            },
          ),
        ] else ...[
          // Progress indicator
          Row(
            children: List.generate(3, (i) {
              final isActive   = i == step;
              final isComplete = i < step;
              const labels = ['Rationale', 'System Dialog', 'Result'];
              const colors = [
                Color(0xFF3B82F6),
                Color(0xFF8B5CF6),
                Color(0xFF10B981),
              ];
              return Expanded(
                child: Row(children: [
                  Expanded(
                    child: Column(children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 4,
                        decoration: BoxDecoration(
                          color: isComplete || isActive
                              ? colors[i]
                              : const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: ZapSpacing.xs),
                      Text(labels[i],
                          style: TextStyle(
                              color: isActive || isComplete
                                  ? colors[i]
                                  : const Color(0xFF4B5563),
                              fontSize: 8,
                              fontWeight: isActive
                                  ? FontWeight.w700
                                  : FontWeight.w400)),
                    ]),
                  ),
                  if (i < 2) const SizedBox(width: ZapSpacing.xs),
                ]),
              );
            }),
          ),
          const SizedBox(height: ZapSpacing.lg),

          // Step content
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _FlowStep(
              key: ValueKey(step),
              step: step,
              perm: perm,
              onNext: step < 2
                  ? () => ref.read(_flowStepProvider.notifier).state = step + 1
                  : null,
              onReset: () {
                ref.read(_flowStartedProvider.notifier).state = false;
                ref.read(_flowStepProvider.notifier).state = 0;
              },
            ),
          ),
        ],
        const SizedBox(height: ZapSpacing.xl),

        // Code for the flow
        const _SectionLabel('IMPLEMENTATION CODE'),
        const SizedBox(height: ZapSpacing.md),
        _codeNote('permission_request_flow.dart',
            '// Show rationale → then system dialog:\n'
            'Future<void> requestWithRationale(\n'
            '    BuildContext context, Permission permission) async {\n'
            '\n'
            '  // Step 1: show our rationale card\n'
            '  final proceed = await showRationaleSheet(\n'
            '      context, permission);\n'
            '  if (!proceed) return; // user dismissed\n'
            '\n'
            '  // Step 2: trigger system dialog\n'
            '  final status = await permission.request();\n'
            '\n'
            '  // Step 3: handle outcome\n'
            '  if (status.isGranted) {\n'
            '    showGrantedConfirmation(context);\n'
            '  } else if (status.isPermanentlyDenied) {\n'
            '    showOpenSettingsSheet(context); // Day 158 pattern\n'
            '  }\n'
            '}'),
      ],
    );
  }
}

class _PermPicker extends StatelessWidget {
  final String current;
  final ValueChanged<String> onSelect;
  const _PermPicker({required this.current, required this.onSelect});

  static const _options = [
    ('microphone',       Icons.mic_rounded,          Color(0xFF8B5CF6), 'Microphone'),
    ('location',         Icons.location_on_rounded,  Color(0xFFEF4444), 'Location'),
    ('camera',           Icons.videocam_rounded,     Color(0xFF3B82F6), 'Camera'),
    ('notifications',    Icons.notifications_rounded,Color(0xFFF59E0B), 'Notifications'),
    ('physicalActivity', Icons.directions_run_rounded,Color(0xFF06B6D4),'Activity'),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _options.map((o) {
          final (id, icon, color, label) = o;
          final isActive = id == current;
          return GestureDetector(
            onTap: () => onSelect(id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: ZapSpacing.sm),
              padding: const EdgeInsets.symmetric(
                  horizontal: ZapSpacing.md, vertical: 10),
              decoration: BoxDecoration(
                color: isActive ? color.withOpacity(0.12) : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                  color: isActive ? color.withOpacity(0.5) : const Color(0xFF2A2A2A),
                  width: isActive ? 2 : 1,
                ),
              ),
              child: Row(children: [
                Icon(icon, color: isActive ? color : const Color(0xFF4B5563), size: 16),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        color: isActive ? color : const Color(0xFF6B7280),
                        fontSize: 11,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w400)),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _FlowStep extends StatelessWidget {
  final int step;
  final dynamic perm; // _Permission from Day 158
  final VoidCallback? onNext;
  final VoidCallback onReset;
  const _FlowStep({
    super.key,
    required this.step,
    required this.perm,
    required this.onNext,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    switch (step) {
      case 0:
        return _Step0Rationale(perm: perm, onContinue: onNext!);
      case 1:
        return _Step1SystemDialog(perm: perm, onAllow: onNext!, onDeny: onNext!);
      case 2:
        return _Step2Result(perm: perm, onReset: onReset);
      default:
        return const SizedBox.shrink();
    }
  }
}

class _Step0Rationale extends StatelessWidget {
  final dynamic perm;
  final VoidCallback onContinue;
  const _Step0Rationale({required this.perm, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: (perm.color as Color).withOpacity(0.07),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: (perm.color as Color).withOpacity(0.35), width: 2),
      ),
      child: Column(children: [
        // Label bar
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: ZapSpacing.md, vertical: 8),
          decoration: BoxDecoration(
            color: (perm.color as Color).withOpacity(0.1),
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(ZapSpacing.radius - 2)),
          ),
          child: const Row(children: [
            Icon(Icons.info_outline_rounded, size: 12,
                color: Color(0xFF9CA3AF)),
            SizedBox(width: 6),
            Text('STEP 1 OF 3  ·  Rationale card (our screen)',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 9,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(ZapSpacing.lg),
          child: Column(children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: (perm.color as Color).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(perm.icon as IconData,
                  color: perm.color as Color, size: 32),
            ),
            const SizedBox(height: ZapSpacing.md),
            Text('Why ZapSafe needs ${perm.name}',
                style: const TextStyle(
                    color: Colors.white, fontSize: 16,
                    fontWeight: FontWeight.w800),
                textAlign: TextAlign.center),
            const SizedBox(height: ZapSpacing.sm),
            Text(perm.whyNeeded as String,
                style: const TextStyle(
                    color: Color(0xFFD1D5DB),
                    fontSize: 12, height: 1.65),
                textAlign: TextAlign.center),
            const SizedBox(height: ZapSpacing.lg),
            // If denied warning
            Container(
              padding: const EdgeInsets.all(ZapSpacing.sm),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.08),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              ),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFEF4444), size: 13),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    'If denied: ${perm.featureImpact}',
                    style: const TextStyle(
                        color: Color(0xFFFFD0CA),
                        fontSize: 10, height: 1.4),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: ZapSpacing.lg),
            _actionButton(
              label: 'Continue — allow system to ask',
              icon: Icons.arrow_forward_rounded,
              color: perm.color as Color,
              onTap: onContinue,
            ),
            const SizedBox(height: ZapSpacing.sm),
            const Text('System permission dialog appears next',
                style: TextStyle(color: Color(0xFF4B5563), fontSize: 10),
                textAlign: TextAlign.center),
          ]),
        ),
      ]),
    );
  }
}

class _Step1SystemDialog extends StatelessWidget {
  final dynamic perm;
  final VoidCallback onAllow, onDeny;
  const _Step1SystemDialog(
      {required this.perm, required this.onAllow, required this.onDeny});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: ZapSpacing.md, vertical: 8),
          decoration: const BoxDecoration(
            color: Color(0xFF111111),
            borderRadius: BorderRadius.vertical(
                top: Radius.circular(ZapSpacing.radius - 1)),
          ),
          child: const Row(children: [
            Icon(Icons.phone_android_rounded,
                color: Color(0xFF9CA3AF), size: 12),
            SizedBox(width: 6),
            Text('STEP 2 OF 3  ·  System dialog (OS shows this)',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 9,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(ZapSpacing.lg),
          child: Column(children: [
            Icon(perm.icon as IconData,
                color: perm.color as Color, size: 32),
            const SizedBox(height: ZapSpacing.md),
            Text('"ZapSafe" Would Like to\nAccess Your ${perm.name}',
                style: const TextStyle(
                    color: Colors.white, fontSize: 14,
                    fontWeight: FontWeight.w700),
                textAlign: TextAlign.center),
            const SizedBox(height: ZapSpacing.sm),
            Text(
              perm.whyNeeded.toString().split('.').first + '.',
              style: const TextStyle(
                  color: Color(0xFF9CA3AF), fontSize: 12, height: 1.5),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: ZapSpacing.lg),
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: onDeny,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(
                          ZapSpacing.radiusSmall),
                    ),
                    child: const Center(
                      child: Text("Don't Allow",
                          style: TextStyle(
                              color: Color(0xFF9CA3AF), fontSize: 13)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: GestureDetector(
                  onTap: onAllow,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF007AFF),
                      borderRadius: BorderRadius.circular(
                          ZapSpacing.radiusSmall),
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
            const SizedBox(height: ZapSpacing.sm),
            const Text('Tap either button to see the result screen',
                style: TextStyle(color: Color(0xFF4B5563), fontSize: 9),
                textAlign: TextAlign.center),
          ]),
        ),
      ]),
    );
  }
}

class _Step2Result extends StatelessWidget {
  final dynamic perm;
  final VoidCallback onReset;
  const _Step2Result({required this.perm, required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withOpacity(0.07),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(
            color: const Color(0xFF10B981).withOpacity(0.4)),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: ZapSpacing.md, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withOpacity(0.1),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          ),
          child: const Text('STEP 3 OF 3  ·  Result (our screen again)',
              style: TextStyle(color: Color(0xFF10B981), fontSize: 9,
                  fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Icon(Icons.check_circle_rounded,
            color: Color(0xFF10B981), size: 44),
        const SizedBox(height: ZapSpacing.md),
        const Text('Permission Granted!',
            style: TextStyle(
                color: Colors.white, fontSize: 18,
                fontWeight: FontWeight.w800),
            textAlign: TextAlign.center),
        const SizedBox(height: ZapSpacing.sm),
        Text(
          '${perm.name} is now enabled. '
          'ZapSafe can use it as described.',
          style: const TextStyle(
              color: Color(0xFF9CA3AF), fontSize: 12, height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: ZapSpacing.lg),
        GestureDetector(
          onTap: onReset,
          child: const Text('↺ Run demo again',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
        ),
      ]),
    );
  }
}

// ── Feature Availability Tab ───────────────────────────────────────────────────
class _FeatureAvailabilityTab extends ConsumerWidget {
  const _FeatureAvailabilityTab();

  _FeatureAvailability _getAvailability(
      _SosFeature feature, Map<String, _PermStatus> statuses) {
    // Check required permissions
    final requiredMet = feature.requiredPermissions
        .every((id) => statuses[id] == _PermStatus.granted);
    if (!requiredMet) return _FeatureAvailability.blocked;

    // Check optional permissions
    if (feature.optionalPermissions.isEmpty) {
      return _FeatureAvailability.full;
    }
    final allOptionalMet = feature.optionalPermissions
        .every((id) => statuses[id] == _PermStatus.granted);
    return allOptionalMet
        ? _FeatureAvailability.full
        : _FeatureAvailability.partial;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statuses = ref.watch(_permStatusProvider);

    final full    = _kSosFeatures.where((f) =>
        _getAvailability(f, statuses) == _FeatureAvailability.full).length;
    final partial = _kSosFeatures.where((f) =>
        _getAvailability(f, statuses) == _FeatureAvailability.partial).length;
    final blocked = _kSosFeatures.where((f) =>
        _getAvailability(f, statuses) == _FeatureAvailability.blocked).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(
          icon: Icons.map_rounded,
          color: const Color(0xFF10B981),
          text: 'Based on the current permission state from Day 158, '
              'this map shows which SOS features are fully available, '
              'partially limited, or completely blocked. '
              'Change the simulated permissions on Day 158 to see this update.',
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Summary row
        Row(children: [
          _availBox(full, 'Full', const Color(0xFF10B981), Icons.check_circle_rounded),
          const SizedBox(width: ZapSpacing.sm),
          _availBox(partial, 'Partial', const Color(0xFFF59E0B), Icons.warning_rounded),
          const SizedBox(width: ZapSpacing.sm),
          _availBox(blocked, 'Blocked', const Color(0xFFEF4444), Icons.block_rounded),
        ]),
        const SizedBox(height: ZapSpacing.lg),

        // Feature list
        const _SectionLabel('SOS FEATURES  ·  TAP TO SEE DETAIL'),
        const SizedBox(height: ZapSpacing.md),
        ..._kSosFeatures.map((feature) {
          final avail = _getAvailability(feature, statuses);
          return Padding(
            padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
            child: _FeatureAvailCard(feature: feature, availability: avail, statuses: statuses),
          );
        }),
      ],
    );
  }

  Widget _availBox(int count, String label, Color color, IconData icon) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: ZapSpacing.md),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: ZapSpacing.xs),
            Text('$count', style: TextStyle(
                color: color, fontSize: 20, fontWeight: FontWeight.w900)),
            Text(label, style: const TextStyle(
                color: Color(0xFF9CA3AF), fontSize: 9),
                textAlign: TextAlign.center),
          ]),
        ),
      );
}

class _FeatureAvailCard extends StatefulWidget {
  final _SosFeature              feature;
  final _FeatureAvailability     availability;
  final Map<String, _PermStatus> statuses;
  const _FeatureAvailCard({
    required this.feature,
    required this.availability,
    required this.statuses,
  });

  @override
  State<_FeatureAvailCard> createState() => _FeatureAvailCardState();
}

class _FeatureAvailCardState extends State<_FeatureAvailCard> {
  bool _expanded = false;

  Color get _availColor {
    switch (widget.availability) {
      case _FeatureAvailability.full:    return const Color(0xFF10B981);
      case _FeatureAvailability.partial: return const Color(0xFFF59E0B);
      case _FeatureAvailability.blocked: return const Color(0xFFEF4444);
    }
  }

  String get _availLabel {
    switch (widget.availability) {
      case _FeatureAvailability.full:    return 'Full ✅';
      case _FeatureAvailability.partial: return 'Partial ⚠️';
      case _FeatureAvailability.blocked: return 'Blocked 🚫';
    }
  }

  String get _description {
    switch (widget.availability) {
      case _FeatureAvailability.full:    return widget.feature.fullDescription;
      case _FeatureAvailability.partial: return widget.feature.partialDescription;
      case _FeatureAvailability.blocked: return widget.feature.blockedDescription;
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.feature;

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _availColor.withOpacity(0.05),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: _availColor.withOpacity(0.25)),
        ),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(ZapSpacing.md),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: f.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(f.icon, color: f.color, size: 18),
              ),
              const SizedBox(width: ZapSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(f.name,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    // Required permissions chips
                    Wrap(
                      spacing: 4, runSpacing: 4,
                      children: f.requiredPermissions.map((id) {
                        final granted = widget.statuses[id] == _PermStatus.granted;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: granted
                                ? const Color(0xFF10B981).withOpacity(0.1)
                                : const Color(0xFFEF4444).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(id,
                              style: TextStyle(
                                color: granted
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFEF4444),
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                              )),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(_availLabel,
                    style: TextStyle(
                        color: _availColor, fontSize: 10,
                        fontWeight: FontWeight.w700)),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: const Color(0xFF4B5563), size: 16),
              ]),
            ]),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(
                        ZapSpacing.md, 0, ZapSpacing.md, ZapSpacing.md),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(ZapSpacing.sm),
                      decoration: BoxDecoration(
                        color: _availColor.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(
                            ZapSpacing.radiusSmall),
                        border: Border.all(
                            color: _availColor.withOpacity(0.2)),
                      ),
                      child: Text(_description,
                          style: const TextStyle(
                              color: Color(0xFFD1D5DB),
                              fontSize: 11, height: 1.5)),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ]),
      ),
    );
  }
}

// ── Status Badge Tab ───────────────────────────────────────────────────────────
class _StatusBadgeTab extends ConsumerWidget {
  const _StatusBadgeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statuses = ref.watch(_permStatusProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(
          icon: Icons.label_rounded,
          color: const Color(0xFFF59E0B),
          text: 'The PermissionStatusBadge widget can be placed inline '
              'on any screen that requires a permission. '
              'Shows a compact status and taps to open the '
              'permissions screen.',
        ),
        const SizedBox(height: ZapSpacing.xl),

        const _SectionLabel('BADGE VARIANTS  ·  LIVE PREVIEW'),
        const SizedBox(height: ZapSpacing.md),

        // Live badge examples
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('All 8 permissions — tap to simulate change',
                  style: TextStyle(
                      color: Color(0xFF6B7280), fontSize: 10,
                      letterSpacing: 0.5)),
              const SizedBox(height: ZapSpacing.md),
              Wrap(
                spacing: ZapSpacing.sm, runSpacing: ZapSpacing.sm,
                children: _kPermissions.map((p) {
                  final status = statuses[p.id] ?? _PermStatus.notAsked;
                  return PermissionStatusBadge(
                    permissionName: p.name.split(' ').first,
                    icon: p.icon,
                    color: p.color,
                    status: status,
                    onTap: () {
                      // Cycle through states
                      final updated = Map<String, _PermStatus>.from(
                          ref.read(_permStatusProvider));
                      updated[p.id] = status == _PermStatus.granted
                          ? _PermStatus.denied
                          : status == _PermStatus.denied
                              ? _PermStatus.notAsked
                              : _PermStatus.granted;
                      ref.read(_permStatusProvider.notifier).state = updated;
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: ZapSpacing.sm),
              const Text('Tap any badge to cycle: Granted → Denied → Not asked',
                  style: TextStyle(color: Color(0xFF4B5563), fontSize: 9)),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.xl),

        // Usage example
        const _SectionLabel('EXAMPLE  ·  EVIDENCE VAULT SCREEN'),
        const SizedBox(height: ZapSpacing.md),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1117),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: const Color(0xFF30363D)),
          ),
          child: Column(children: [
            // Mock screen header
            const Row(children: [
              Icon(Icons.lock_rounded, color: Color(0xFF8B5CF6), size: 18),
              SizedBox(width: ZapSpacing.sm),
              Text('Evidence Vault',
                  style: TextStyle(
                      color: Colors.white, fontSize: 14,
                      fontWeight: FontWeight.w700)),
              Spacer(),
            ]),
            const SizedBox(height: ZapSpacing.sm),
            // Permission badges inline
            Row(children: [
              const Text('Requires: ',
                  style: TextStyle(color: Color(0xFF4B5563), fontSize: 10)),
              PermissionStatusBadge(
                permissionName: 'Mic',
                icon: Icons.mic_rounded,
                color: const Color(0xFF8B5CF6),
                status: statuses['microphone'] ?? _PermStatus.notAsked,
                onTap: () {},
              ),
              const SizedBox(width: 6),
              PermissionStatusBadge(
                permissionName: 'Camera',
                icon: Icons.videocam_rounded,
                color: const Color(0xFF3B82F6),
                status: statuses['camera'] ?? _PermStatus.notAsked,
                onTap: () {},
              ),
            ]),
          ]),
        ),
        const SizedBox(height: ZapSpacing.lg),

        _codeNote('widgets/permission_status_badge.dart',
            '// Inline permission status — place anywhere:\n'
            'PermissionStatusBadge(\n'
            '  permissionName: \'Mic\',\n'
            '  icon: Icons.mic_rounded,\n'
            '  color: const Color(0xFF8B5CF6),\n'
            '  status: PermissionService.status(\'microphone\'),\n'
            '  onTap: () => context.push(AppRoutes.appPermissions),\n'
            ')'),
      ],
    );
  }
}

// ── PermissionStatusBadge widget ───────────────────────────────────────────────
/// Reusable inline permission status indicator.
class PermissionStatusBadge extends StatelessWidget {
  final String      permissionName;
  final IconData    icon;
  final Color       color;
  final _PermStatus status;
  final VoidCallback onTap;

  const PermissionStatusBadge({
    super.key,
    required this.permissionName,
    required this.icon,
    required this.color,
    required this.status,
    required this.onTap,
  });

  Color get _statusColor {
    switch (status) {
      case _PermStatus.granted:  return const Color(0xFF10B981);
      case _PermStatus.denied:   return const Color(0xFFEF4444);
      case _PermStatus.notAsked: return const Color(0xFF4B5563);
    }
  }

  IconData get _statusIcon {
    switch (status) {
      case _PermStatus.granted:  return Icons.check_circle_rounded;
      case _PermStatus.denied:   return Icons.cancel_rounded;
      case _PermStatus.notAsked: return Icons.help_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: _statusColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _statusColor.withOpacity(0.35)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: ZapSpacing.xs),
          Text(permissionName,
              style: const TextStyle(
                  color: Colors.white, fontSize: 10,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: ZapSpacing.xs),
          Icon(_statusIcon, color: _statusColor, size: 10),
        ]),
      ),
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
