/// Day 183 — Biometric Lock Screen & LP18 Gate
///
/// First day of the Days 183-184 Biometric Lock block.
/// Day 183: Auto-lock screen, local_auth implementation,
///           lock timer config, LP18 gate map, failure handling.
/// Day 184: LP18 gate strengthening — hardened re-auth for
///           sensitive actions + tamper-resistant implementation.
///
/// 🟢 FRONTEND-ONLY — local_auth runs entirely on device.
///    No server call needed. BiometricService wraps local_auth
///    and manages the lock/unlock state via Riverpod.
///
/// LP18 = ZapSafe Locked Protection #18:
///   "All sensitive operations require biometric or PIN confirmation."
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _d183TabProvider         = StateProvider<int>((ref) => 0);
final _lockStateProvider       = StateProvider<_LockState>((ref) => _LockState.unlocked);
final _lockTimerProvider       = StateProvider<_LockTimeout>((ref) => _LockTimeout.min1);
final _biometricTypeProvider   = StateProvider<_BiometricType>((ref) => _BiometricType.fingerprint);
final _failCountProvider       = StateProvider<int>((ref) => 0);
final _countdownProvider       = StateProvider<int>((ref) => 0);
final _expandedLp18Provider    = StateProvider<int?>((ref) => null);
final _expandedCodeProvider    = StateProvider<int?>((ref) => null);

// ── Enums ──────────────────────────────────────────────────────────────────────
enum _LockState  { unlocked, locked, unlocking, failed, lockedOut }
enum _LockTimeout{ immediately, sec30, min1, min5, min15, never }
enum _BiometricType { fingerprint, face, iris, pin }

// ── Data ───────────────────────────────────────────────────────────────────────
const _timeoutLabel = {
  _LockTimeout.immediately: 'Immediately',
  _LockTimeout.sec30:       '30 seconds',
  _LockTimeout.min1:        '1 minute',
  _LockTimeout.min5:        '5 minutes',
  _LockTimeout.min15:       '15 minutes',
  _LockTimeout.never:       'Never',
};

const _biometricIcon = {
  _BiometricType.fingerprint: Icons.fingerprint_rounded,
  _BiometricType.face:        Icons.face_rounded,
  _BiometricType.iris:        Icons.remove_red_eye_rounded,
  _BiometricType.pin:         Icons.pin_rounded,
};

const _biometricLabel = {
  _BiometricType.fingerprint: 'Fingerprint',
  _BiometricType.face:        'Face ID',
  _BiometricType.iris:        'Iris Scan',
  _BiometricType.pin:         'Device PIN',
};

class _Lp18Item {
  final String   feature;
  final String   screen;
  final String   triggerAction;
  final String   biometricPrompt;
  final String   onFailure;
  final IconData icon;
  final Color    color;
  const _Lp18Item({
    required this.feature, required this.screen,
    required this.triggerAction, required this.biometricPrompt,
    required this.onFailure, required this.icon, required this.color,
  });
}

const _kLp18Items = [
  _Lp18Item(
    feature: 'Evidence Vault',
    screen: 'Day 82 — Evidence Vault screen',
    triggerAction: 'Tapping "Open Vault"',
    biometricPrompt: '"Verify identity to access Evidence Vault"',
    onFailure: '3 failures → key rotation. 5 failures → vault wipe (LP23).',
    icon: Icons.lock_rounded, color: Color(0xFFF59E0B),
  ),
  _Lp18Item(
    feature: 'Contact Deletion / Tier Change',
    screen: 'Day 83 — Contact Management',
    triggerAction: 'Long-press → batch delete, or tier downgrade',
    biometricPrompt: '"Verify identity to modify emergency contacts"',
    onFailure: 'Operation cancelled. No contacts changed.',
    icon: Icons.people_rounded, color: Color(0xFF10B981),
  ),
  _Lp18Item(
    feature: 'Account Deletion Request',
    screen: 'Day 169 — Deletion Request (Step 3)',
    triggerAction: 'Proceeding past the reason step',
    biometricPrompt: '"Confirm your identity before deleting your account"',
    onFailure: 'Deletion request cancelled. Re-navigate to Settings.',
    icon: Icons.delete_rounded, color: Color(0xFFEF4444),
  ),
  _Lp18Item(
    feature: 'Session Revocation',
    screen: 'Day 179 — Active Sessions (non-current)',
    triggerAction: 'Tapping "Sign out this session"',
    biometricPrompt: '"Verify identity to sign out another device"',
    onFailure: 'Session not revoked.',
    icon: Icons.logout_rounded, color: Color(0xFF3B82F6),
  ),
  _Lp18Item(
    feature: 'Privacy Policy Accept (first launch)',
    screen: 'Day 161 — Consent Gate',
    triggerAction: 'App first open — before policy acceptance',
    biometricPrompt: 'Not required at this stage — biometric set up after onboarding.',
    onFailure: 'N/A — biometric not yet enrolled.',
    icon: Icons.policy_rounded, color: Color(0xFF8B5CF6),
  ),
  _Lp18Item(
    feature: 'Duress PIN (LP3)',
    screen: 'Day 39 / Day 76 — SOS Active',
    triggerAction: 'Entering PIN 9999 during active SOS',
    biometricPrompt: 'No biometric — duress PIN bypasses biometric entirely.',
    onFailure: 'N/A — duress PIN is a separate code path.',
    icon: Icons.warning_rounded, color: Color(0xFFEF4444),
  ),
];

class _CodeEntry {
  final String title, subtitle, code;
  const _CodeEntry({required this.title, required this.subtitle, required this.code});
}

const _kCodeEntries = [
  _CodeEntry(
    title: 'BiometricService',
    subtitle: 'Core service wrapping local_auth',
    code: '''// pubspec.yaml
// local_auth: ^2.2.0

import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final _auth = LocalAuthentication();

  /// True if device supports biometrics and has enrolled credentials.
  static Future<bool> isAvailable() async {
    final canCheck = await _auth.canCheckBiometrics;
    final isDeviceSupported = await _auth.isDeviceSupported();
    return canCheck && isDeviceSupported;
  }

  /// Returns list of available biometrics on this device.
  static Future<List<BiometricType>> availableTypes() =>
      _auth.getAvailableBiometrics();

  /// Authenticate with biometric or device PIN fallback.
  /// [reason] is shown in the OS biometric prompt.
  static Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,   // allow device PIN as fallback
          stickyAuth: true,       // don\'t cancel on app backgrounding
          sensitiveTransaction: true,  // extra security indicator (iOS)
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (e) {
      // Handle: notEnrolled, notAvailable, lockedOut, permanentlyLockedOut
      if (e.code == auth_error.notEnrolled) return false;
      if (e.code == auth_error.lockedOut)   throw BiometricLockedOutException();
      return false;
    }
  }
}''',
  ),
  _CodeEntry(
    title: 'AppLockProvider',
    subtitle: 'Riverpod state + auto-lock timer',
    code: '''// lib/services/app_lock_provider.dart

enum AppLockState { unlocked, locked, lockedOut }

class AppLockNotifier extends StateNotifier<AppLockState> {
  AppLockNotifier() : super(AppLockState.unlocked);

  Timer? _lockTimer;
  int _failCount = 0;

  /// Called on app resume (AppLifecycleState.resumed).
  void onAppResume(LockTimeout timeout) {
    if (timeout == LockTimeout.never) return;
    if (state != AppLockState.unlocked) return;
    // If the app was in background longer than the timeout, lock it
    // (In production: compare DateTime.now() against last-foreground timestamp)
    // For demo purposes: lock immediately on resume if timeout == immediately
    if (timeout == LockTimeout.immediately) {
      state = AppLockState.locked;
    }
  }

  /// Called on app pause (AppLifecycleState.paused).
  void onAppPause(LockTimeout timeout) {
    _lockTimer?.cancel();
    if (timeout == LockTimeout.never) return;
    final secs = switch (timeout) {
      LockTimeout.sec30  => 30,
      LockTimeout.min1   => 60,
      LockTimeout.min5   => 300,
      LockTimeout.min15  => 900,
      LockTimeout.immediately => 0,
      LockTimeout.never       => -1,
    };
    if (secs == 0) { state = AppLockState.locked; return; }
    _lockTimer = Timer(Duration(seconds: secs), () {
      if (mounted) state = AppLockState.locked;
    });
  }

  Future<void> unlock() async {
    state = AppLockState.unlocked;
    _failCount = 0;
  }

  void recordFailure() {
    _failCount++;
    if (_failCount >= 5) state = AppLockState.lockedOut;
  }
}

final appLockProvider =
    StateNotifierProvider<AppLockNotifier, AppLockState>(
        (ref) => AppLockNotifier());''',
  ),
  _CodeEntry(
    title: 'Android permissions',
    subtitle: 'AndroidManifest.xml + build.gradle',
    code: '''<!-- android/app/src/main/AndroidManifest.xml -->
<uses-permission android:name="android.permission.USE_BIOMETRIC" />
<!-- Legacy API < 28 -->
<uses-permission android:name="android.permission.USE_FINGERPRINT" />

<!-- In build.gradle: minSdk 23 required for BiometricPrompt -->
android {
    defaultConfig {
        minSdkVersion 23
    }
}''',
  ),
  _CodeEntry(
    title: 'iOS Info.plist',
    subtitle: 'NSFaceIDUsageDescription',
    code: '''<!-- ios/Runner/Info.plist -->

<!-- Required for Face ID — App Store will reject without this -->
<key>NSFaceIDUsageDescription</key>
<string>ZapSafe uses Face ID to protect your Evidence Vault
and sensitive account settings.</string>

<!-- Note: Touch ID does not require a usage description key -->''',
  ),
];

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day183BiometricLockScreen extends ConsumerStatefulWidget {
  const Day183BiometricLockScreen({super.key});
  @override
  ConsumerState<Day183BiometricLockScreen> createState() =>
      _Day183BiometricLockScreenState();
}

class _Day183BiometricLockScreenState
    extends ConsumerState<Day183BiometricLockScreen>
    with WidgetsBindingObserver {

  Timer? _autoLockTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _autoLockTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(_d183TabProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Biometric Lock  ·  LP18'),
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: ZapSpacing.md, top: 8, bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
            ),
            child: const Text('🟢 FRONTEND-ONLY',
                style: TextStyle(color: Color(0xFF10B981), fontSize: 10,
                    fontWeight: FontWeight.w800)),
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
            _TabBar(active: tab,
                onSelect: (t) => ref.read(_d183TabProvider.notifier).state = t),
            const SizedBox(height: ZapSpacing.xl),
            if (tab == 0) const _LockDemoTab(),
            if (tab == 1) const _ImplementationTab(),
            if (tab == 2) const _Lp18Tab(),
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
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF0A0814), Color(0xFF060508), Color(0xFF0A0A0A)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.5), width: 2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: ZapSpacing.sm, runSpacing: ZapSpacing.sm, children: [
          _badge('⚡  DAY 183',              const Color(0xFF8B5CF6)),
          _badge('🟢 FRONTEND-ONLY',         const Color(0xFF10B981)),
          _badge('Section C  ·  Day 3/10',   const Color(0xFF3B82F6)),
          _badge('LP18 — Biometric Gate',    const Color(0xFFF59E0B)),
        ]),
        const SizedBox(height: ZapSpacing.md),
        const Text('Biometric Lock\nScreen & LP18',
            style: TextStyle(color: Colors.white, fontSize: 26,
                fontWeight: FontWeight.w900, height: 1.2)),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          'Auto-lock after configurable inactivity. '
          'Face ID / fingerprint / device PIN via local_auth. '
          'LP18 gate map — 6 sensitive operations protected. '
          'Failure handling → lockout after 5 attempts.',
          style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6)),
        const SizedBox(height: ZapSpacing.md),
        const Row(children: [
          _HStat('6',    '6 auto-lock options', Color(0xFF8B5CF6)),
          _HStat('3',    '3 biometric types',   Color(0xFF10B981)),
          _HStat('6',    '6 LP18 gates',        Color(0xFFF59E0B)),
          _HStat('5',    'Fail → lockout',       Color(0xFFEF4444)),
        ]),
      ]));

  Widget _badge(String l, Color c) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.withOpacity(0.4))),
      child: Text(l, style: TextStyle(color: c, fontSize: 11,
          fontWeight: FontWeight.w700, letterSpacing: 0.5)));
}

class _HStat extends StatelessWidget {
  final String value, label; final Color color;
  const _HStat(this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(value, style: TextStyle(color: color, fontSize: 13,
        fontWeight: FontWeight.w800), textAlign: TextAlign.center),
    Text(label, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 9),
        textAlign: TextAlign.center),
  ]));
}

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
      (Icons.lock_open_rounded,  Color(0xFF8B5CF6), 'Lock Demo'),
      (Icons.code_rounded,       Color(0xFF3B82F6), 'Implementation'),
      (Icons.shield_rounded,     Color(0xFFF59E0B), 'LP18 Gates'),
    ];
    return Row(children: List.generate(3, (i) {
      final (icon, color, label) = items[i];
      final isActive = i == active;
      return Expanded(child: GestureDetector(
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
            const SizedBox(height: 4),
            Text(label, style: TextStyle(
                color: isActive ? color : const Color(0xFF6B7280), fontSize: 9,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400)),
          ]),
        ),
      ));
    }));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 1 — Lock Demo
// ══════════════════════════════════════════════════════════════════════════════
class _LockDemoTab extends ConsumerWidget {
  const _LockDemoTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lockState    = ref.watch(_lockStateProvider);
    final timeout      = ref.watch(_lockTimerProvider);
    final bioType      = ref.watch(_biometricTypeProvider);
    final failCount    = ref.watch(_failCountProvider);
    final _ = ref.watch(_countdownProvider);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.info_outline_rounded, color: const Color(0xFF8B5CF6),
          text: 'Simulates the full auto-lock flow. '
              'Configure the lock timer and biometric type, '
              'then tap "Lock App" to see the lock screen. '
              '"Unlock" simulates a successful biometric response.'),
      const SizedBox(height: ZapSpacing.lg),

      // Lock timer
      const _SectionLabel('AUTO-LOCK TIMER'),
      const SizedBox(height: ZapSpacing.md),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: _LockTimeout.values.map((t) {
          final isActive = t == timeout;
          return GestureDetector(
            onTap: () => ref.read(_lockTimerProvider.notifier).state = t,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              margin: const EdgeInsets.only(right: ZapSpacing.sm),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFF8B5CF6).withOpacity(0.15)
                      : const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: isActive
                          ? const Color(0xFF8B5CF6).withOpacity(0.5)
                          : const Color(0xFF2A2A2A),
                      width: isActive ? 2 : 1)),
              child: Text(_timeoutLabel[t]!, style: TextStyle(
                  color: isActive ? const Color(0xFF8B5CF6) : const Color(0xFF6B7280),
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w400))));
        }).toList()),
      ),
      const SizedBox(height: ZapSpacing.lg),

      // Biometric type
      const _SectionLabel('BIOMETRIC TYPE (DEVICE CAPABILITY)'),
      const SizedBox(height: ZapSpacing.md),
      Row(children: _BiometricType.values.map((b) {
        final isActive = b == bioType;
        return Expanded(child: Padding(
          padding: EdgeInsets.only(right: b != _BiometricType.pin ? ZapSpacing.sm : 0),
          child: GestureDetector(
            onTap: () => ref.read(_biometricTypeProvider.notifier).state = b,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFF8B5CF6).withOpacity(0.12)
                      : const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                  border: Border.all(
                      color: isActive
                          ? const Color(0xFF8B5CF6).withOpacity(0.5)
                          : const Color(0xFF2A2A2A),
                      width: isActive ? 2 : 1)),
              child: Column(children: [
                Icon(_biometricIcon[b]!,
                    color: isActive ? const Color(0xFF8B5CF6) : const Color(0xFF6B7280),
                    size: 20),
                const SizedBox(height: 4),
                Text(_biometricLabel[b]!, style: TextStyle(
                    color: isActive ? const Color(0xFF8B5CF6) : const Color(0xFF6B7280),
                    fontSize: 9,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w400)),
              ]),
            ))));
      }).toList()),
      const SizedBox(height: ZapSpacing.xl),

      // Lock screen mock
      const _SectionLabel('LOCK SCREEN  ·  MOCK UI'),
      const SizedBox(height: ZapSpacing.md),

      AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: lockState == _LockState.unlocked
            ? _UnlockedState(onLock: () {
                ref.read(_lockStateProvider.notifier).state = _LockState.locked;
                ref.read(_failCountProvider.notifier).state = 0;
              })
            : _LockedScreenMock(
                lockState: lockState,
                bioType: bioType,
                failCount: failCount,
                onUnlock: () => _simulateUnlock(ref),
                onFail: () => _simulateFail(ref, failCount),
                onReset: () {
                  ref.read(_lockStateProvider.notifier).state = _LockState.unlocked;
                  ref.read(_failCountProvider.notifier).state = 0;
                },
              ),
      ),

      // Failure explanation
      if (lockState == _LockState.unlocked && failCount == 0) ...[
        const SizedBox(height: ZapSpacing.xl),
        const _SectionLabel('FAILURE HANDLING'),
        const SizedBox(height: ZapSpacing.md),
        Container(
          decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(color: const Color(0xFF2A2A2A))),
          child: Column(children: [
            _failRow(1, 3, const Color(0xFFF59E0B),
                'Attempts 1-2', 'Retry prompt shown. User can try again.'),
            const Divider(height: 1, color: Color(0xFF222222)),
            _failRow(3, 3, const Color(0xFFF59E0B),
                'Attempt 3', 'Warning: "2 attempts remaining before lock"'),
            const Divider(height: 1, color: Color(0xFF222222)),
            _failRow(5, 5, const Color(0xFFEF4444),
                'Attempt 5', 'App locked out. OS PIN required to unlock.'),
            const Divider(height: 1, color: Color(0xFF222222)),
            _failRow(0, 5, const Color(0xFFEF4444),
                'Vault only: 5 failures', 'LP23 cascade: key rotation then vault wipe.'),
          ]),
        ),
      ],
    ]);
  }

  Future<void> _simulateUnlock(WidgetRef ref) async {
    ref.read(_lockStateProvider.notifier).state = _LockState.unlocking;
    await Future.delayed(const Duration(milliseconds: 800));
    ref.read(_lockStateProvider.notifier).state = _LockState.unlocked;
    ref.read(_failCountProvider.notifier).state = 0;
  }

  void _simulateFail(WidgetRef ref, int currentFails) {
    final newCount = currentFails + 1;
    ref.read(_failCountProvider.notifier).state = newCount;
    if (newCount >= 5) {
      ref.read(_lockStateProvider.notifier).state = _LockState.lockedOut;
    } else {
      ref.read(_lockStateProvider.notifier).state = _LockState.failed;
      // Return to locked after brief failed state
      Future.delayed(const Duration(milliseconds: 900), () {
        ref.read(_lockStateProvider.notifier).state = _LockState.locked;
      });
    }
  }

  Widget _failRow(int fails, int max, Color color, String label, String detail) =>
      Padding(
        padding: const EdgeInsets.all(ZapSpacing.md),
        child: Row(children: [
          // Attempt dots
          Row(children: List.generate(max, (i) => Container(
              width: 8, height: 8,
              margin: const EdgeInsets.only(right: 3),
              decoration: BoxDecoration(
                  color: i < fails ? color : const Color(0xFF2A2A2A),
                  shape: BoxShape.circle)))),
          const SizedBox(width: ZapSpacing.md),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: color, fontSize: 10,
                fontWeight: FontWeight.w700)),
            Text(detail, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10)),
          ])),
        ]));
}

class _UnlockedState extends StatelessWidget {
  final VoidCallback onLock;
  const _UnlockedState({required this.onLock});

  @override
  Widget build(BuildContext context) => Column(children: [
    Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
          color: const Color(0xFF10B981).withOpacity(0.07),
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.35))),
      child: Column(children: [
        const Icon(Icons.lock_open_rounded, color: Color(0xFF10B981), size: 36),
        const SizedBox(height: ZapSpacing.sm),
        const Text('App is unlocked', style: TextStyle(
            color: Color(0xFF10B981), fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text('Tap below to simulate locking the app '
            '(as if user backgrounded it past the timeout).',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
            textAlign: TextAlign.center),
      ])),
    const SizedBox(height: ZapSpacing.md),
    _primaryBtn(label: 'Lock App (simulate background)',
        color: const Color(0xFF8B5CF6), onTap: onLock),
  ]);
}

class _LockedScreenMock extends StatelessWidget {
  final _LockState lockState; final _BiometricType bioType;
  final int failCount;
  final VoidCallback onUnlock, onFail, onReset;
  const _LockedScreenMock({
    required this.lockState, required this.bioType, required this.failCount,
    required this.onUnlock, required this.onFail, required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final isLockedOut = lockState == _LockState.lockedOut;
    final isUnlocking = lockState == _LockState.unlocking;
    final isFailed    = lockState == _LockState.failed;

    return Container(
      decoration: BoxDecoration(
          color: const Color(0xFF050508),
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          border: Border.all(
              color: isLockedOut
                  ? const Color(0xFFEF4444).withOpacity(0.5)
                  : const Color(0xFF8B5CF6).withOpacity(0.4),
              width: 2)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Phone header strip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.md, vertical: 8),
          decoration: const BoxDecoration(
              color: Color(0xFF0A0A0A),
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(ZapSpacing.radius),
                  topRight: Radius.circular(ZapSpacing.radius))),
          child: Row(children: [
            const Icon(Icons.smartphone_rounded, color: Color(0xFF4B5563), size: 12),
            const SizedBox(width: 6),
            const Text('ZapSafe  ·  Lock Screen',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 10)),
            const Spacer(),
            // SOS always visible even when locked
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8)),
              child: const Text('SOS', style: TextStyle(
                  color: Color(0xFFEF4444), fontSize: 9, fontWeight: FontWeight.w800))),
          ])),

        Padding(
          padding: const EdgeInsets.all(ZapSpacing.xl),
          child: Column(children: [
            // ZapSafe logo placeholder
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: const Color(0xFF8B5CF6).withOpacity(0.3))),
              child: const Icon(Icons.bolt_rounded,
                  color: Color(0xFF8B5CF6), size: 30)),
            const SizedBox(height: ZapSpacing.md),
            const Text('ZapSafe', style: TextStyle(color: Colors.white,
                fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              isLockedOut
                  ? 'Too many failed attempts.\nUse your device PIN to unlock.'
                  : isFailed
                      ? '✗ Authentication failed  ·  ${5 - failCount} attempts remaining'
                      : 'Unlock to continue',
              style: TextStyle(
                  color: isLockedOut || isFailed
                      ? const Color(0xFFEF4444) : const Color(0xFF9CA3AF),
                  fontSize: 12, height: 1.4),
              textAlign: TextAlign.center),
            const SizedBox(height: ZapSpacing.xl),

            if (!isLockedOut) ...[
              // Biometric button
              if (isUnlocking)
                Column(children: [
                  const SizedBox(
                    width: 56, height: 56,
                    child: CircularProgressIndicator(
                        color: Color(0xFF8B5CF6), strokeWidth: 3)),
                  const SizedBox(height: ZapSpacing.sm),
                  const Text('Verifying…',
                      style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 11)),
                ])
              else
                GestureDetector(
                  onTap: onUnlock,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 70, height: 70,
                    decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withOpacity(0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFF8B5CF6).withOpacity(0.5), width: 2)),
                    child: Icon(_biometricIcon[bioType]!,
                        color: const Color(0xFF8B5CF6), size: 32))),
              const SizedBox(height: ZapSpacing.sm),
              Text(_biometricLabel[bioType]!,
                  style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
              const SizedBox(height: ZapSpacing.lg),
              // Fail button
              GestureDetector(
                onTap: onFail,
                child: const Text('Simulate failure →',
                    style: TextStyle(color: Color(0xFF4B5563), fontSize: 10,
                        decoration: TextDecoration.underline))),
            ] else ...[
              // Locked out — PIN entry mock
              Container(
                padding: const EdgeInsets.all(ZapSpacing.md),
                decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                    border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3))),
                child: const Text('Biometric locked. Enter device PIN to unlock.',
                    style: TextStyle(color: Color(0xFFEF4444), fontSize: 11),
                    textAlign: TextAlign.center)),
            ],
            const SizedBox(height: ZapSpacing.xl),
            GestureDetector(
              onTap: onReset,
              child: const Text('Reset demo',
                  style: TextStyle(color: Color(0xFF3A3A3A), fontSize: 9,
                      decoration: TextDecoration.underline))),
          ]),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — Implementation
// ══════════════════════════════════════════════════════════════════════════════
class _ImplementationTab extends ConsumerWidget {
  const _ImplementationTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(_expandedCodeProvider);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.code_rounded, color: const Color(0xFF3B82F6),
          text: '4 code snippets: BiometricService (local_auth wrapper), '
              'AppLockProvider (Riverpod state + auto-lock timer), '
              'Android permissions, and iOS Info.plist.'),
      const SizedBox(height: ZapSpacing.lg),

      ..._kCodeEntries.asMap().entries.map((e) {
        final i      = e.key;
        final entry  = e.value;
        final isExp  = expanded == i;
        const colors = [Color(0xFF3B82F6), Color(0xFF8B5CF6),
                        Color(0xFF3DDC84), Color(0xFF9CA3AF)];
        final color  = colors[i];

        return GestureDetector(
          onTap: () => ref.read(_expandedCodeProvider.notifier).state =
              isExp ? null : i,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            decoration: BoxDecoration(
                color: isExp ? color.withOpacity(0.07) : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                    color: isExp ? color.withOpacity(0.4) : const Color(0xFF2A2A2A),
                    width: isExp ? 2 : 1)),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(ZapSpacing.md),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text('DART', style: TextStyle(color: color,
                        fontSize: 9, fontWeight: FontWeight.w800))),
                  const SizedBox(width: ZapSpacing.md),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(entry.title, style: const TextStyle(color: Colors.white,
                        fontSize: 12, fontWeight: FontWeight.w600)),
                    Text(entry.subtitle, style: const TextStyle(
                        color: Color(0xFF6B7280), fontSize: 10)),
                  ])),
                  Icon(isExp ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                      color: const Color(0xFF4B5563), size: 16),
                ])),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                child: isExp
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(
                            ZapSpacing.md, 0, ZapSpacing.md, ZapSpacing.md),
                        child: _codeBlock(context, entry.code))
                    : const SizedBox.shrink(),
              ),
            ]),
          ),
        );
      }),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 3 — LP18 Gates
// ══════════════════════════════════════════════════════════════════════════════
class _Lp18Tab extends ConsumerWidget {
  const _Lp18Tab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(_expandedLp18Provider);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.shield_rounded, color: const Color(0xFFF59E0B),
          text: 'LP18 (Locked Protection #18): "All sensitive operations require '
              'biometric or PIN confirmation." '
              '6 features gated — each with its specific prompt, '
              'trigger action, and failure behaviour.'),
      const SizedBox(height: ZapSpacing.lg),

      // LP18 badge
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withOpacity(0.07),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.35))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.security_rounded, color: Color(0xFFF59E0B), size: 16),
            SizedBox(width: ZapSpacing.sm),
            Text('ZapSafe LP18 Compliance', style: TextStyle(
                color: Color(0xFFF59E0B), fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          const Text(
            'Status: ✅ Active — local_auth called before each gated operation.\n'
            'Platform: Android uses BiometricPrompt API / iOS uses LAContext.\n'
            'Fallback: Device PIN always allowed — no biometric-only lock-in.\n'
            'SOS bypass: SOS button is NEVER behind a biometric gate.',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11, height: 1.6)),
        ])),
      const SizedBox(height: ZapSpacing.lg),

      const _SectionLabel('6 LP18-GATED OPERATIONS  ·  TAP TO EXPAND'),
      const SizedBox(height: ZapSpacing.md),

      ..._kLp18Items.asMap().entries.map((e) {
        final i    = e.key;
        final item = e.value;
        final isExp= expanded == i;

        return GestureDetector(
          onTap: () => ref.read(_expandedLp18Provider.notifier).state =
              isExp ? null : i,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            decoration: BoxDecoration(
                color: isExp ? item.color.withOpacity(0.07) : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                    color: isExp ? item.color.withOpacity(0.4) : const Color(0xFF2A2A2A),
                    width: isExp ? 2 : 1)),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(ZapSpacing.md),
                child: Row(children: [
                  Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                        color: item.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8)),
                    child: Icon(item.icon, color: item.color, size: 16)),
                  const SizedBox(width: ZapSpacing.md),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item.feature, style: const TextStyle(color: Colors.white,
                        fontSize: 12, fontWeight: FontWeight.w700)),
                    Text(item.screen, style: const TextStyle(
                        color: Color(0xFF6B7280), fontSize: 10)),
                  ])),
                  Icon(isExp ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                      color: const Color(0xFF4B5563), size: 16),
                ]),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                child: isExp
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(
                            ZapSpacing.md, 0, ZapSpacing.md, ZapSpacing.md),
                        child: Container(
                          padding: const EdgeInsets.all(ZapSpacing.md),
                          decoration: BoxDecoration(
                              color: const Color(0xFF111111),
                              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                              border: Border.all(color: const Color(0xFF2A2A2A))),
                          child: Column(children: [
                            _lp18Row('Trigger',  item.triggerAction,
                                Icons.bolt_rounded, item.color),
                            const SizedBox(height: 8),
                            _lp18Row('Prompt',   item.biometricPrompt,
                                Icons.fingerprint_rounded, const Color(0xFF8B5CF6)),
                            const SizedBox(height: 8),
                            _lp18Row('On failure', item.onFailure,
                                Icons.cancel_rounded, const Color(0xFFEF4444)),
                          ])))
                    : const SizedBox.shrink(),
              ),
            ]),
          ),
        );
      }),

      const SizedBox(height: ZapSpacing.lg),
      _infoBox(icon: Icons.arrow_forward_rounded, color: const Color(0xFF8B5CF6),
          text: 'Day 184 strengthens LP18 gates: '
              'detects biometric bypass attempts, adds '
              'cryptographic binding (key generated inside secure enclave '
              'that requires biometric to unlock), and builds the '
              'Days 183-184 block sign-off screen.'),
    ]);
  }

  Widget _lp18Row(String k, String v, IconData icon, Color color) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 6),
        SizedBox(width: 62, child: Text(k, style: TextStyle(
            color: color, fontSize: 9, fontWeight: FontWeight.w700))),
        Expanded(child: Text(v, style: const TextStyle(
            color: Color(0xFFD1D5DB), fontSize: 10, height: 1.4))),
      ]);
}

// ── Shared helpers ─────────────────────────────────────────────────────────────
Widget _primaryBtn({required String label, required Color color,
    required VoidCallback onTap}) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color, color.withOpacity(0.8)]),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            boxShadow: [BoxShadow(color: color.withOpacity(0.3),
                blurRadius: 14, offset: const Offset(0, 4))]),
        child: Center(child: Text(label, style: const TextStyle(
            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)))));

Widget _codeBlock(BuildContext context, String code) => GestureDetector(
    onLongPress: () {
      Clipboard.setData(ClipboardData(text: code));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Copied'), backgroundColor: Color(0xFF1A1A1A),
          duration: Duration(seconds: 1)));
    },
    child: Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: const Color(0xFF2A2A2A))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Expanded(child: Text('long-press to copy',
              style: TextStyle(color: Color(0xFF4B5563), fontSize: 9))),
          Icon(Icons.copy_rounded, color: Color(0xFF4B5563), size: 12),
        ]),
        const SizedBox(height: ZapSpacing.sm),
        Text(code, style: const TextStyle(color: Color(0xFF86EFAC),
            fontSize: 10, fontFamily: 'monospace', height: 1.6)),
      ])));

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
