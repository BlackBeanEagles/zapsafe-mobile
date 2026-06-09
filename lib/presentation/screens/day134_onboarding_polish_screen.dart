/// Day 134 — Onboarding Polish, Skip Paths & Timing Test
///
/// Second half of the Days 133-134 onboarding simplification cycle.
/// Day 133 designed the new 4-step flow (7 steps → 4, 5 min → 2 min).
/// Day 134 polishes three remaining gaps:
///
///   1. Permission rationale — replace raw system dialogs with plain-
///      language "Why we need this" cards shown before each dialog
///   2. Experienced-user skip paths — "I already added contacts",
///      "Skip for now" options so power users don't get blocked
///   3. Timed walkthrough test — simulate a fresh user completing
///      the 4-step flow and verify total time < 2 minutes
///
/// Then ships v0.5.6 bundling all fixes from Days 121-134.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _activeTabProvider     = StateProvider<int>((ref) => 0);
final _permExpandedProvider  = StateProvider<int?>((ref) => null);
final _permGrantedProvider   = StateProvider<List<bool>>(
  (ref) => List.filled(_kPermissions.length, false),
);
final _timerProvider         = StateProvider<int>((ref) => 0);        // seconds
final _timerRunningProvider  = StateProvider<bool>((ref) => false);
final _timerStepProvider     = StateProvider<int>((ref) => 0);
final _stepTimesProvider     = StateProvider<List<int?>>(
  (ref) => [null, null, null, null],
);
final _skipChoicesProvider   = StateProvider<Map<String, String>>(
  (ref) => {},
);
final _shipStateProvider     = StateProvider<_ShipState>((ref) => _ShipState.idle);
final _verifyProvider        = StateProvider<List<bool>>(
  (ref) => List.filled(_kVerifyChecks.length, false),
);

enum _ShipState { idle, building, uploading, done }

// ── Data ───────────────────────────────────────────────────────────────────────
class _Permission {
  final String  name;
  final IconData icon;
  final Color   color;
  final String  why;
  final String  whenAsked;
  final String  ifDenied;
  const _Permission({
    required this.name,
    required this.icon,
    required this.color,
    required this.why,
    required this.whenAsked,
    required this.ifDenied,
  });
}

const _kPermissions = [
  _Permission(
    name: 'Microphone',
    icon: Icons.mic_rounded,
    color: Color(0xFFEF4444),
    why: 'ZapSafe listens for distress sounds (screams, '
        'calls for help) to automatically trigger SOS if you\'re in danger.',
    whenAsked: 'Step 2 of onboarding — needed before detection starts',
    ifDenied: 'Detection features unavailable. App still works for '
        'manual SOS and contacts.',
  ),
  _Permission(
    name: 'Location (Always)',
    icon: Icons.location_on_rounded,
    color: Color(0xFF3B82F6),
    why: 'Your location is shared with emergency contacts during SOS '
        'and used to calculate safe routes. Never shared without your consent.',
    whenAsked: 'First time you start a Journey or use the Safety Map',
    ifDenied: 'GPS tracking unavailable. SOS still works but contacts '
        'won\'t see your location.',
  ),
  _Permission(
    name: 'Contacts',
    icon: Icons.people_rounded,
    color: Color(0xFF10B981),
    why: 'To let you pick people from your phone book as emergency '
        'contacts. We read — never modify or sync — your contacts.',
    whenAsked: 'First time you tap "Add from contacts" in Step 3',
    ifDenied: 'You can still add contacts by typing their number manually.',
  ),
  _Permission(
    name: 'Camera',
    icon: Icons.camera_alt_rounded,
    color: Color(0xFF8B5CF6),
    why: 'Silent video evidence is recorded during SOS (stored only on '
        'your device — never uploaded without consent).',
    whenAsked: 'First SOS event — not during onboarding',
    ifDenied: 'Video evidence unavailable. Audio + GPS evidence still '
        'captured.',
  ),
  _Permission(
    name: 'Notifications',
    icon: Icons.notifications_rounded,
    color: Color(0xFFF59E0B),
    why: 'Critical SOS alerts, check-in reminders, and contact '
        'responses need to reach you immediately.',
    whenAsked: 'After your first successful SOS test drill',
    ifDenied: 'You won\'t receive alerts. Strongly recommended — '
        'prompted again after 24h.',
  ),
];

class _SkipOption {
  final String step;
  final String blockingText;
  final Color  color;
  final IconData icon;
  final List<String> skipChoices;
  const _SkipOption({
    required this.step,
    required this.blockingText,
    required this.color,
    required this.icon,
    required this.skipChoices,
  });
}

const _kSkipOptions = [
  _SkipOption(
    step: 'Step 2 · Permission',
    blockingText: 'Microphone permission dialog',
    color: Color(0xFFEF4444),
    icon: Icons.mic_rounded,
    skipChoices: [
      'Allow microphone',
      'Skip — I\'ll enable it later in Settings',
    ],
  ),
  _SkipOption(
    step: 'Step 3 · Emergency Contact',
    blockingText: 'Requires adding at least 1 contact',
    color: Color(0xFFF59E0B),
    icon: Icons.person_add_rounded,
    skipChoices: [
      'Add a contact now',
      'I already have contacts — skip',
      'Skip for now — I\'ll add later',
    ],
  ),
  _SkipOption(
    step: 'Step 4 · SOS Test',
    blockingText: '"Test SOS" button — felt mandatory',
    color: Color(0xFF8B5CF6),
    icon: Icons.shield_rounded,
    skipChoices: [
      'Run quick test drill',
      'Skip test — go straight to dashboard',
    ],
  ),
];

// Per-step target durations (seconds)
const _kStepTargets = [30, 20, 40, 20];
const _kStepNames   = ['Welcome', 'Permission', 'Contact', 'Protected'];

const _kVerifyChecks = [
  'Step 2: "Why we need this" rationale shown before system dialog',
  'Step 3: "Skip for now" option visible and functional',
  'Step 3: "I already added contacts" skip bypasses contact picker',
  'Step 4: "Skip test" option goes straight to Dashboard',
  'Timed test: total < 2 min on real device',
  'Drop-off test: simulate 20 users — < 10% abandon at Step 2',
  'No regression: existing contacts + permissions not reset on update',
];

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day134OnboardingPolishScreen extends ConsumerWidget {
  const Day134OnboardingPolishScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_activeTabProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Day 134 · Onboarding Polish'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Hero(),
            const SizedBox(height: ZapSpacing.xl),

            const _SectionLabel('SELECT AREA'),
            const SizedBox(height: ZapSpacing.md),
            _TabBar(active: tab,
                onSelect: (t) =>
                    ref.read(_activeTabProvider.notifier).state = t),
            const SizedBox(height: ZapSpacing.xl),

            if (tab == 0) const _PermissionRationaleTab(),
            if (tab == 1) const _SkipPathsTab(),
            if (tab == 2) const _TimingTestTab(),
            const SizedBox(height: ZapSpacing.xl),

            // Verify + ship
            const _SectionLabel('VERIFICATION  ·  DAYS 133-134'),
            const SizedBox(height: ZapSpacing.md),
            const _VerifyChecklist(),
            const SizedBox(height: ZapSpacing.xl),

            const _SectionLabel('SHIP  ·  v0.5.6 COMPLETE BETA ITERATION'),
            const SizedBox(height: ZapSpacing.md),
            const _ShipPanel(),
            const SizedBox(height: ZapSpacing.xl),

            const _SectionLabel('NEXT  ·  DAYS 135-137'),
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
          colors: [Color(0xFF0A1520), Color(0xFF050B10), Color(0xFF0A0A0A)],
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
            _badge('⚡  BETA  ·  DAY 134', const Color(0xFF3B82F6)),
            const SizedBox(width: ZapSpacing.sm),
            _badge('v0.5.6 Final', const Color(0xFF10B981)),
          ]),
          const SizedBox(height: ZapSpacing.md),
          const Text(
            'Onboarding Polish\n& Timing Test',
            style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                height: 1.2),
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'Add "Why we need this" rationale before each permission. '
            'Add skip paths so experienced users aren\'t blocked. '
            'Run timed test to confirm < 2 min. Ship v0.5.6.',
            style: TextStyle(
                color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: ZapSpacing.md),
          const Row(children: [
            _HStat('5',     'Permissions\nexplained',  Color(0xFF3B82F6)),
            _HStat('3',     'Skip paths',              Color(0xFFF59E0B)),
            _HStat('< 2m',  'Target time',             Color(0xFF10B981)),
            _HStat('v0.5.6','Final ship',              Color(0xFF8B5CF6)),
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
  final Color  color;
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
              style: const TextStyle(
                  color: Color(0xFF9CA3AF), fontSize: 9, height: 1.3),
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
      (Icons.privacy_tip_rounded,   Color(0xFF3B82F6), 'Permissions'),
      (Icons.fast_forward_rounded,  Color(0xFFF59E0B), 'Skip Paths'),
      (Icons.timer_rounded,         Color(0xFF10B981), 'Timing Test'),
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
                color: isActive
                    ? color.withOpacity(0.12)
                    : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                  color: isActive ? color.withOpacity(0.5) : const Color(0xFF2A2A2A),
                  width: isActive ? 2 : 1,
                ),
              ),
              child: Column(children: [
                Icon(icon,
                    color: isActive ? color : const Color(0xFF6B7280),
                    size: 18),
                const SizedBox(height: 4),
                Text(label,
                    style: TextStyle(
                        color: isActive ? color : const Color(0xFF6B7280),
                        fontSize: 10,
                        fontWeight:
                            isActive ? FontWeight.w700 : FontWeight.w400)),
              ]),
            ),
          ),
        );
      }),
    );
  }
}

// ── Permission Rationale Tab ───────────────────────────────────────────────────
class _PermissionRationaleTab extends ConsumerWidget {
  const _PermissionRationaleTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(_permExpandedProvider);
    final granted  = ref.watch(_permGrantedProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(
          icon: Icons.warning_amber_rounded,
          color: const Color(0xFFEF4444),
          text: 'Old: Show 5 raw system dialogs in sequence — 34% abandon. '
              'New: Show one at a time, each with a "Why we need this" '
              'card before the system prompt.',
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Before/after preview
        const _SectionLabel('BEFORE vs AFTER'),
        const SizedBox(height: ZapSpacing.md),
        Row(children: [
          Expanded(child: _permBox(
            label: 'BEFORE', color: const Color(0xFFEF4444),
            items: ['Microphone', 'Location', 'Contacts', 'Camera', 'Notifications'],
            isAfter: false,
          )),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(child: _permBox(
            label: 'AFTER', color: const Color(0xFF10B981),
            items: ['Mic only (Step 2)', '4 others deferred'],
            isAfter: true,
          )),
        ]),
        const SizedBox(height: ZapSpacing.xl),

        // Per-permission rationale cards
        const _SectionLabel('PERMISSION RATIONALE CARDS  ·  TAP TO SIMULATE'),
        const SizedBox(height: ZapSpacing.md),
        ..._kPermissions.asMap().entries.map((e) {
          final i    = e.key;
          final perm = e.value;
          final isOpen  = expanded == i;
          final isDone  = granted[i];

          return Padding(
            padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
            child: GestureDetector(
              onTap: () => ref
                  .read(_permExpandedProvider.notifier)
                  .state = isOpen ? null : i,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isOpen
                      ? perm.color.withOpacity(0.07)
                      : const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                  border: Border.all(
                    color: isDone
                        ? const Color(0xFF10B981).withOpacity(0.4)
                        : isOpen
                            ? perm.color.withOpacity(0.4)
                            : const Color(0xFF2A2A2A),
                  ),
                ),
                child: Column(children: [
                  Padding(
                    padding: const EdgeInsets.all(ZapSpacing.md),
                    child: Row(children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: isDone
                              ? const Color(0xFF10B981).withOpacity(0.12)
                              : perm.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isDone ? Icons.check_rounded : perm.icon,
                          color: isDone ? const Color(0xFF10B981) : perm.color,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: ZapSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(perm.name,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                            Text(perm.whenAsked,
                                style: const TextStyle(
                                    color: Color(0xFF9CA3AF), fontSize: 10)),
                          ],
                        ),
                      ),
                      Icon(
                        isOpen
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: const Color(0xFF4B5563), size: 18),
                    ]),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    child: isOpen
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(
                                ZapSpacing.md, 0, ZapSpacing.md, ZapSpacing.md),
                            child: Column(children: [
                              const Divider(height: ZapSpacing.md,
                                  color: Color(0xFF2A2A2A)),
                              // Rationale card mockup
                              _RationaleCardMockup(perm: perm),
                              const SizedBox(height: ZapSpacing.md),
                              // System dialog mockup
                              _SystemDialogMockup(
                                perm: perm,
                                granted: isDone,
                                onAllow: () {
                                  final updated = List<bool>.from(
                                      ref.read(_permGrantedProvider));
                                  updated[i] = true;
                                  ref
                                      .read(_permGrantedProvider.notifier)
                                      .state = updated;
                                  ref
                                      .read(_permExpandedProvider.notifier)
                                      .state = null;
                                },
                                onDeny: () {
                                  ref
                                      .read(_permExpandedProvider.notifier)
                                      .state = null;
                                },
                              ),
                            ]),
                          )
                        : const SizedBox.shrink(),
                  ),
                ]),
              ),
            ),
          );
        }),

        // Granted summary
        const SizedBox(height: ZapSpacing.md),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.sm),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withOpacity(0.07),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
          ),
          child: Text(
            '${granted.where((g) => g).length} / ${_kPermissions.length} permissions granted',
            style: const TextStyle(color: Color(0xFF10B981), fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _permBox({
    required String label,
    required Color color,
    required List<String> items,
    required bool isAfter,
  }) =>
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1)),
            const SizedBox(height: ZapSpacing.sm),
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        isAfter ? Icons.check_rounded : Icons.warning_rounded,
                        color: color, size: 12,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(item,
                            style: TextStyle(
                                color: color.withOpacity(0.9),
                                fontSize: 11)),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      );
}

class _RationaleCardMockup extends StatelessWidget {
  final _Permission perm;
  const _RationaleCardMockup({required this.perm});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: perm.color.withOpacity(0.35), width: 2),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: perm.color.withOpacity(0.1),
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(ZapSpacing.radiusSmall - 2)),
          ),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: perm.color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(perm.icon, color: perm.color, size: 20),
            ),
            const SizedBox(width: ZapSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Why ZapSafe needs ${perm.name}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                  const Text('Shown before system dialog',
                      style: TextStyle(
                          color: Color(0xFF9CA3AF), fontSize: 10)),
                ],
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(ZapSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(perm.why,
                  style: const TextStyle(
                      color: Color(0xFFD1D5DB),
                      fontSize: 12,
                      height: 1.6)),
              const SizedBox(height: ZapSpacing.sm),
              Container(
                padding: const EdgeInsets.all(ZapSpacing.sm),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1117),
                  borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                ),
                child: Row(children: [
                  const Icon(Icons.lock_rounded,
                      color: Color(0xFF4B5563), size: 12),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'If denied: ${perm.ifDenied}',
                      style: const TextStyle(
                          color: Color(0xFF6B7280), fontSize: 11, height: 1.4),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: ZapSpacing.md),
              Text(
                '↓ System permission dialog appears next',
                style: TextStyle(
                    color: perm.color.withOpacity(0.7),
                    fontSize: 11,
                    fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _SystemDialogMockup extends StatelessWidget {
  final _Permission perm;
  final bool granted;
  final VoidCallback onAllow, onDeny;
  const _SystemDialogMockup({
    required this.perm,
    required this.granted,
    required this.onAllow,
    required this.onDeny,
  });

  @override
  Widget build(BuildContext context) {
    if (granted) {
      return Container(
        padding: const EdgeInsets.all(ZapSpacing.sm),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withOpacity(0.1),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.35)),
        ),
        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
          SizedBox(width: ZapSpacing.sm),
          Text('Permission granted ✅',
              style: TextStyle(
                  color: Color(0xFF10B981),
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ]),
      );
    }

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: const Color(0xFF3A3A3C)),
      ),
      child: Column(children: [
        Text(
          '"ZapSafe" Would Like to Access Your ${perm.name}',
          style: const TextStyle(
              color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: ZapSpacing.sm),
        Text(perm.why,
            style: const TextStyle(
                color: Color(0xFF9CA3AF), fontSize: 11, height: 1.4),
            textAlign: TextAlign.center),
        const SizedBox(height: ZapSpacing.md),
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: onDeny,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                ),
                child: const Center(
                  child: Text("Don't Allow",
                      style: TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 13)),
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
                  borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
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
    );
  }
}

// ── Skip Paths Tab ─────────────────────────────────────────────────────────────
class _SkipPathsTab extends ConsumerWidget {
  const _SkipPathsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choices = ref.watch(_skipChoicesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(
          icon: Icons.fast_forward_rounded,
          color: const Color(0xFFF59E0B),
          text: 'Experienced users who already have contacts saved or '
              'understand permissions shouldn\'t be forced through every '
              'step. Skip options reduce frustration without compromising '
              'safety for new users.',
        ),
        const SizedBox(height: ZapSpacing.xl),

        ..._kSkipOptions.asMap().entries.map((e) {
          final i    = e.key;
          final opt  = e.value;
          final chosen = choices[opt.step];

          return Padding(
            padding: const EdgeInsets.only(bottom: ZapSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: opt.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(opt.icon, color: opt.color, size: 18),
                  ),
                  const SizedBox(width: ZapSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(opt.step,
                            style: TextStyle(
                                color: opt.color,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                        Text(opt.blockingText,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: ZapSpacing.md),

                // Choice buttons
                ...opt.skipChoices.asMap().entries.map((ce) {
                  final ci     = ce.key;
                  final choice = ce.value;
                  final isPrimary = ci == 0;
                  final isChosen  = chosen == choice;
                  final choiceColor = isPrimary ? opt.color : const Color(0xFF4B5563);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
                    child: GestureDetector(
                      onTap: () {
                        final updated = Map<String, String>.from(
                            ref.read(_skipChoicesProvider));
                        updated[opt.step] = choice;
                        ref.read(_skipChoicesProvider.notifier).state = updated;
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(ZapSpacing.md),
                        decoration: BoxDecoration(
                          color: isChosen
                              ? choiceColor.withOpacity(0.12)
                              : const Color(0xFF1A1A1A),
                          borderRadius:
                              BorderRadius.circular(ZapSpacing.radiusSmall),
                          border: Border.all(
                            color: isChosen
                                ? choiceColor.withOpacity(0.5)
                                : const Color(0xFF2A2A2A),
                            width: isChosen ? 2 : 1,
                          ),
                        ),
                        child: Row(children: [
                          Container(
                            width: 20, height: 20,
                            decoration: BoxDecoration(
                              color: isChosen
                                  ? choiceColor.withOpacity(0.15)
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: isChosen
                                      ? choiceColor
                                      : const Color(0xFF4B5563)),
                            ),
                            child: isChosen
                                ? Icon(Icons.check_rounded,
                                    color: choiceColor, size: 12)
                                : null,
                          ),
                          const SizedBox(width: ZapSpacing.md),
                          Expanded(
                            child: Text(choice,
                                style: TextStyle(
                                    color: isChosen
                                        ? Colors.white
                                        : const Color(0xFFD1D5DB),
                                    fontSize: 13)),
                          ),
                          if (isPrimary)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: opt.color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('Recommended',
                                  style: TextStyle(
                                      color: opt.color,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700)),
                            ),
                        ]),
                      ),
                    ),
                  );
                }),

                if (chosen != null) ...[
                  const SizedBox(height: ZapSpacing.sm),
                  Container(
                    padding: const EdgeInsets.all(ZapSpacing.sm),
                    decoration: BoxDecoration(
                      color: opt.color.withOpacity(0.07),
                      borderRadius:
                          BorderRadius.circular(ZapSpacing.radiusSmall),
                      border: Border.all(color: opt.color.withOpacity(0.25)),
                    ),
                    child: Row(children: [
                      Icon(Icons.check_circle_rounded,
                          color: opt.color, size: 14),
                      const SizedBox(width: ZapSpacing.sm),
                      Expanded(
                        child: Text(
                          'Selected: "$chosen"',
                          style: TextStyle(
                              color: opt.color, fontSize: 11),
                        ),
                      ),
                    ]),
                  ),
                ],
                if (i < _kSkipOptions.length - 1)
                  const Padding(
                    padding: EdgeInsets.only(top: ZapSpacing.sm),
                    child: Divider(color: Color(0xFF2A2A2A)),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ── Timing Test Tab ────────────────────────────────────────────────────────────
class _TimingTestTab extends ConsumerStatefulWidget {
  const _TimingTestTab();

  @override
  ConsumerState<_TimingTestTab> createState() => _TimingTestTabState();
}

class _TimingTestTabState extends ConsumerState<_TimingTestTab> {

  void _startStep() {
    final step    = ref.read(_timerStepProvider);
    final times   = List<int?>.from(ref.read(_stepTimesProvider));
    final elapsed = ref.read(_timerProvider);

    if (step < 4) {
      // Record time for current step
      final prevTime = step == 0 ? 0 : _sumBefore(times, step);
      times[step] = elapsed - prevTime;
      ref.read(_stepTimesProvider.notifier).state = times;
      ref.read(_timerStepProvider.notifier).state = step + 1;

      if (step == 3) {
        // Done
        ref.read(_timerRunningProvider.notifier).state = false;
      }
    }
  }

  int _sumBefore(List<int?> times, int before) {
    int sum = 0;
    for (int i = 0; i < before; i++) {
      sum += times[i] ?? 0;
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    final elapsed  = ref.watch(_timerProvider);
    final running  = ref.watch(_timerRunningProvider);
    final step     = ref.watch(_timerStepProvider);
    final times    = ref.watch(_stepTimesProvider);
    final done     = step == 4;
    final totalSec = done ? elapsed : null;

    // Tick the timer
    ref.listen(_timerRunningProvider, (_, isRunning) {
      if (isRunning) _tick();
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(
          icon: Icons.timer_rounded,
          color: const Color(0xFF10B981),
          text: 'Simulate a fresh user completing all 4 steps. '
              'Tap "Next step" after each step completes. '
              'Target: all 4 steps in under 2 minutes (120 seconds).',
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Stopwatch
        Container(
          padding: const EdgeInsets.all(ZapSpacing.lg),
          decoration: BoxDecoration(
            color: done
                ? (totalSec! <= 120
                    ? const Color(0xFF10B981).withOpacity(0.08)
                    : const Color(0xFFEF4444).withOpacity(0.08))
                : const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(
              color: done
                  ? (totalSec! <= 120
                      ? const Color(0xFF10B981).withOpacity(0.4)
                      : const Color(0xFFEF4444).withOpacity(0.4))
                  : const Color(0xFF2A2A2A),
            ),
          ),
          child: Column(children: [
            // Big timer
            Text(
              _fmt(elapsed),
              style: TextStyle(
                color: elapsed > 120
                    ? const Color(0xFFEF4444)
                    : elapsed > 90
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF10B981),
                fontSize: 48,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
              ),
            ),
            const Text('Target: < 2:00',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
            const SizedBox(height: ZapSpacing.lg),

            // Step indicators
            Row(
              children: List.generate(4, (i) {
                final isDone    = i < step;
                final isActive  = i == step && running;
                final stepTime  = times[i];
                final target    = _kStepTargets[i];
                final overTarget = stepTime != null && stepTime > target;
                final stepColor = isDone
                    ? (overTarget
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF10B981))
                    : isActive
                        ? const Color(0xFF3B82F6)
                        : const Color(0xFF2A2A2A);

                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i < 3 ? 6 : 0),
                    child: Column(children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 6,
                        decoration: BoxDecoration(
                          color: stepColor,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (isDone && stepTime != null)
                        Text(_fmt(stepTime),
                            style: TextStyle(
                                color: overTarget
                                    ? const Color(0xFFF59E0B)
                                    : const Color(0xFF10B981),
                                fontSize: 9,
                                fontFamily: 'monospace'))
                      else
                        Text(_kStepNames[i],
                            style: TextStyle(
                                color: isActive
                                    ? const Color(0xFF3B82F6)
                                    : const Color(0xFF4B5563),
                                fontSize: 8),
                            textAlign: TextAlign.center),
                    ]),
                  ),
                );
              }),
            ),
            const SizedBox(height: ZapSpacing.lg),

            // Controls
            if (!running && !done)
              _actionButton(
                label: 'Start timer',
                icon: Icons.play_arrow_rounded,
                color: const Color(0xFF10B981),
                onTap: () {
                  ref.read(_timerProvider.notifier).state      = 0;
                  ref.read(_timerStepProvider.notifier).state  = 0;
                  ref.read(_stepTimesProvider.notifier).state  = [null, null, null, null];
                  ref.read(_timerRunningProvider.notifier).state = true;
                  _tick();
                },
              )
            else if (running && !done)
              Column(children: [
                Text(
                  step < 4
                      ? 'Current step: ${_kStepNames[step]} '
                        '(target ${_kStepTargets[step]}s)'
                      : 'Done!',
                  style: const TextStyle(
                      color: Color(0xFF9CA3AF), fontSize: 12),
                ),
                const SizedBox(height: ZapSpacing.md),
                _actionButton(
                  label: step < 3
                      ? 'Step ${step + 1} done → next'
                      : 'Step 4 done → finish',
                  icon: Icons.arrow_forward_rounded,
                  color: const Color(0xFF3B82F6),
                  onTap: _startStep,
                ),
              ])
            else if (done) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    totalSec! <= 120
                        ? Icons.check_circle_rounded
                        : Icons.warning_rounded,
                    color: totalSec <= 120
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                    size: 28,
                  ),
                  const SizedBox(width: ZapSpacing.sm),
                  Text(
                    totalSec <= 120
                        ? '✅ ${_fmt(totalSec)} — Under 2 min!'
                        : '❌ ${_fmt(totalSec)} — Over 2 min',
                    style: TextStyle(
                        color: totalSec <= 120
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                        fontSize: 16,
                        fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: ZapSpacing.md),
              GestureDetector(
                onTap: () {
                  ref.read(_timerProvider.notifier).state      = 0;
                  ref.read(_timerRunningProvider.notifier).state = false;
                  ref.read(_timerStepProvider.notifier).state  = 0;
                  ref.read(_stepTimesProvider.notifier).state  = [null, null, null, null];
                },
                child: const Text('Run again',
                    style: TextStyle(
                        color: Color(0xFF6B7280), fontSize: 12)),
              ),
            ],
          ]),
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Target breakdown
        const _SectionLabel('STEP TIME TARGETS'),
        const SizedBox(height: ZapSpacing.md),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Column(
            children: _kStepNames.asMap().entries.map((e) {
              final i      = e.key;
              final name   = e.value;
              final target = _kStepTargets[i];
              final actual = times[i];
              final isLast = i == _kStepNames.length - 1;

              return Column(children: [
                Padding(
                  padding: const EdgeInsets.all(ZapSpacing.md),
                  child: Row(children: [
                    Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text('${i + 1}',
                            style: const TextStyle(
                                color: Color(0xFF9CA3AF),
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: ZapSpacing.md),
                    Expanded(
                      child: Text(name,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13)),
                    ),
                    Text(
                      '< ${target}s',
                      style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 11,
                          fontFamily: 'monospace'),
                    ),
                    if (actual != null) ...[
                      const SizedBox(width: ZapSpacing.sm),
                      Text(
                        _fmt(actual),
                        style: TextStyle(
                          color: actual <= target
                              ? const Color(0xFF10B981)
                              : const Color(0xFFF59E0B),
                          fontSize: 11,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ]),
                ),
                if (!isLast)
                  const Divider(height: 1, color: Color(0xFF2A2A2A)),
              ]);
            }).toList(),
          ),
        ),
      ],
    );
  }

  void _tick() async {
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    if (ref.read(_timerRunningProvider)) {
      ref.read(_timerProvider.notifier).state++;
      _tick();
    }
  }

  String _fmt(int secs) {
    final m = secs ~/ 60;
    final s = secs % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

// ── Verify Checklist ───────────────────────────────────────────────────────────
class _VerifyChecklist extends ConsumerWidget {
  const _VerifyChecklist();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checks    = ref.watch(_verifyProvider);
    final doneCount = checks.where((c) => c).length;
    final allDone   = doneCount == _kVerifyChecks.length;

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
            Row(children: [
              Text('$doneCount / ${_kVerifyChecks.length} verified',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(
                allDone ? '✅ Ready to ship v0.5.6' : 'Tap to verify',
                style: TextStyle(
                    color: allDone
                        ? const Color(0xFF10B981)
                        : const Color(0xFF6B7280),
                    fontSize: 11),
              ),
            ]),
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
              final updated = List<bool>.from(ref.read(_verifyProvider));
              updated[i] = !updated[i];
              ref.read(_verifyProvider.notifier).state = updated;
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
                          color: done
                              ? const Color(0xFF6B7280)
                              : Colors.white,
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

// ── Ship Panel ─────────────────────────────────────────────────────────────────
class _ShipPanel extends ConsumerWidget {
  const _ShipPanel();

  static const _kStates = [
    _ShipState.idle, _ShipState.building,
    _ShipState.uploading, _ShipState.done,
  ];
  static const _kLabels = [
    '', 'Building v0.5.6 release…',
    'Uploading to TestFlight + Play…', 'v0.5.6 live!',
  ];
  static const _kColors = [
    Color(0xFF10B981), Color(0xFF10B981),
    Color(0xFFF59E0B), Color(0xFF10B981),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state       = ref.watch(_shipStateProvider);
    final verChecks   = ref.watch(_verifyProvider);
    final allVerified = verChecks.every((c) => c);

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
        _codeNote('changelog',
            'v0.5.6 — Complete Beta Iteration (Days 121-134)\n'
            '\n'
            'Onboarding (Days 133-134):\n'
            '  ✨ 7-step → 4-step flow (34% → ~8% abandon target)\n'
            '  ✨ Permission rationale cards before system dialogs\n'
            '  ✨ Skip paths: contact optional, test drill optional\n'
            '  ⚡ Total time 5 min → < 2 min\n'
            '\n'
            'Previous fixes bundled:\n'
            '  ⚡ Memory leaks × 5 (v0.5.5)\n'
            '  ⚡ Performance (v0.5.4)\n'
            '  ⚡ Notifications + delivery status (v0.5.3)\n'
            '  ⚡ False positive fixes (v0.5.2)\n'
            '  ⚡ Crash fixes × 3 (v0.5.1)'),
        const SizedBox(height: ZapSpacing.md),
        if (state == _ShipState.done) ...[
          const Icon(Icons.rocket_launch_rounded,
              color: Color(0xFF10B981), size: 44),
          const SizedBox(height: ZapSpacing.md),
          const Text('v0.5.6 shipped!',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'Complete beta iteration cycle (Days 121-134) done.\n'
            '847 testers updated.',
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
                  child: Text('Complete all 7 verify checks first',
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
                          blurRadius: 16,
                          offset: const Offset(0, 4))
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
                        ? 'Ship v0.5.6 — Complete beta iteration'
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

// ── Next Card ──────────────────────────────────────────────────────────────────
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
        _row(const Color(0xFF8B5CF6), 'Day 135',
            'Bundle & tag v0.5.6 final build — '
            'complete beta iteration Days 121-134 changelog'),
        const Divider(height: 1, color: Color(0xFF2A2A2A)),
        _row(const Color(0xFF3B82F6), 'Days 136-137',
            'Second feedback round — measure retention, '
            'crash rate, FP rate, onboarding completion after all fixes'),
        const Divider(height: 1, color: Color(0xFF2A2A2A)),
        _row(const Color(0xFF10B981), 'Days 138-139',
            'Final polish — only bug fixes, no new features. '
            'Final accessibility check + security review'),
        const Divider(height: 1, color: Color(0xFF2A2A2A)),
        _row(const Color(0xFFF59E0B), 'Day 140',
            'Tag v0.5-beta-final — production-ready app '
            'tested by 1,000 users, ready for App Store submission'),
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
                blurRadius: 14,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: ZapSpacing.sm),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
        ]),
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
