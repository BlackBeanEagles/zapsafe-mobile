/// Day 244 — Fake Call Feature Polish
///
/// Section C (Days 241-260): realistic incoming-call overlay during discreet
/// SOS Active — caller name + preset photo picker, ring animation, accept/decline
/// mock that returns to SOS. No "SOS" text on the call screen.
///
/// Tag: 🟣 POLISH · LP27-safe call UI · links Day 76 SOS Active.
///
/// Route: [AppRoutes.fakeCallPolish] → `/fake-call-polish`
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const _kSosBackdrop = ZapColors.bgPrimary;
const _kCallAccent = Color(0xFF6366F1);
const _kTabs = ['Settings', 'Demo', 'Safety'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');

const _kPresetAvatars = [
  _CallerAvatar(
    id: 'mom',
    label: 'Mom',
    subtitle: 'Family preset',
    color: Color(0xFFEC4899),
    icon: Icons.person_rounded,
  ),
  _CallerAvatar(
    id: 'office',
    label: 'Office',
    subtitle: 'Work line',
    color: Color(0xFF3B82F6),
    icon: Icons.work_rounded,
  ),
  _CallerAvatar(
    id: 'partner',
    label: 'Alex',
    subtitle: 'Partner',
    color: Color(0xFF8B5CF6),
    icon: Icons.favorite_rounded,
  ),
  _CallerAvatar(
    id: 'friend',
    label: 'Sam',
    subtitle: 'Friend',
    color: Color(0xFF10B981),
    icon: Icons.emoji_emotions_rounded,
  ),
  _CallerAvatar(
    id: 'doctor',
    label: 'Clinic',
    subtitle: 'Medical office',
    color: Color(0xFF14B8A6),
    icon: Icons.local_hospital_rounded,
  ),
  _CallerAvatar(
    id: 'custom',
    label: 'Custom',
    subtitle: 'Uses name below',
    color: Color(0xFF6B7280),
    icon: Icons.account_circle_rounded,
  ),
];

// ── Models ────────────────────────────────────────────────────────────────────
class _CallerAvatar {
  const _CallerAvatar({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  final String id;
  final String label;
  final String subtitle;
  final Color color;
  final IconData icon;
}

enum _CallPhase { idle, ringing, connected, ended }

// ── Providers ─────────────────────────────────────────────────────────────────
final _d244TabProvider = StateProvider<int>((ref) => 0);
final _d244CallerNameProvider = StateProvider<String>((ref) => 'Mom');
final _d244AvatarIdProvider = StateProvider<String>((ref) => 'mom');
final _d244OverlayVisibleProvider = StateProvider<bool>((ref) => false);
final _d244CallPhaseProvider =
    StateProvider<_CallPhase>((ref) => _CallPhase.idle);
final _d244CallStartedAtProvider = StateProvider<DateTime?>((ref) => null);
final _d244TriggerCountProvider = StateProvider<int>((ref) => 0);

// ── Helpers ───────────────────────────────────────────────────────────────────
_CallerAvatar _avatarById(String id) {
  return _kPresetAvatars.firstWhere(
    (a) => a.id == id,
    orElse: () => _kPresetAvatars.first,
  );
}

String _displayCallerName(String name, String avatarId) {
  if (avatarId == 'custom') return name.trim().isEmpty ? 'Unknown' : name.trim();
  return _avatarById(avatarId).label == 'Custom'
      ? name
      : (name.trim().isEmpty ? _avatarById(avatarId).label : name.trim());
}

String _formatCallElapsed(DateTime? started) {
  if (started == null) return '00:00';
  final d = DateTime.now().difference(started);
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}

// ── Screen ────────────────────────────────────────────────────────────────────
class Day244FakeCallPolishScreen extends ConsumerStatefulWidget {
  const Day244FakeCallPolishScreen({super.key});

  @override
  ConsumerState<Day244FakeCallPolishScreen> createState() =>
      _Day244FakeCallPolishScreenState();
}

class _Day244FakeCallPolishScreenState
    extends ConsumerState<Day244FakeCallPolishScreen>
    with TickerProviderStateMixin {
  late final AnimationController _ringController;
  Timer? _connectedTimer;
  Timer? _elapsedTicker;
  final _nameCtrl = TextEditingController(text: 'Mom');

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _nameCtrl.addListener(() {
      ref.read(_d244CallerNameProvider.notifier).state = _nameCtrl.text;
    });
  }

  @override
  void dispose() {
    _ringController.dispose();
    _connectedTimer?.cancel();
    _elapsedTicker?.cancel();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _triggerIncomingCall() {
    ref.read(_d244OverlayVisibleProvider.notifier).state = true;
    ref.read(_d244CallPhaseProvider.notifier).state = _CallPhase.ringing;
    ref.read(_d244CallStartedAtProvider.notifier).state = null;
    ref.read(_d244TriggerCountProvider.notifier).state =
        ref.read(_d244TriggerCountProvider) + 1;
    _ringController.repeat();
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);
  }

  void _dismissOverlay({required String action}) {
    _ringController.stop();
    _ringController.reset();
    _connectedTimer?.cancel();
    _elapsedTicker?.cancel();
    ref.read(_d244OverlayVisibleProvider.notifier).state = false;
    ref.read(_d244CallPhaseProvider.notifier).state = _CallPhase.ended;
    ref.read(_d244CallStartedAtProvider.notifier).state = null;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          action == 'accept'
              ? 'Call ended — returned to discreet screen (SOS continues silently, mock).'
              : 'Call declined — returned to discreet screen (SOS continues silently, mock).',
        ),
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        ref.read(_d244CallPhaseProvider.notifier).state = _CallPhase.idle;
      }
    });
  }

  void _acceptCall() {
    ref.read(_d244CallPhaseProvider.notifier).state = _CallPhase.connected;
    ref.read(_d244CallStartedAtProvider.notifier).state = DateTime.now();
    _ringController.stop();
    HapticFeedback.mediumImpact();

    _elapsedTicker?.cancel();
    _elapsedTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    _connectedTimer?.cancel();
    _connectedTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) _dismissOverlay(action: 'accept');
    });
  }

  void _declineCall() {
    HapticFeedback.lightImpact();
    _dismissOverlay(action: 'decline');
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(_d244TabProvider);
    final overlayVisible = ref.watch(_d244OverlayVisibleProvider);
    final phase = ref.watch(_d244CallPhaseProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 244 · Fake Call'),
        actions: [
          if (phase == _CallPhase.ringing)
            Padding(
              padding: const EdgeInsets.only(right: ZapSpacing.md),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kCallAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                    border:
                        Border.all(color: _kCallAccent.withOpacity(0.45)),
                  ),
                  child: const Text(
                    'RINGING',
                    style: TextStyle(
                      color: _kCallAccent,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _TabBar(
                tab: tab,
                onSelect: (i) => ref.read(_d244TabProvider.notifier).state = i,
              ),
              Expanded(
                child: switch (tab) {
                  0 => _SettingsTab(nameCtrl: _nameCtrl),
                  1 => _DemoTab(onTriggerCall: _triggerIncomingCall),
                  _ => const _SafetyTab(),
                },
              ),
            ],
          ),
          if (overlayVisible)
            _IncomingCallOverlay(
              ringAnimation: _ringController,
              phase: phase,
              onAccept: _acceptCall,
              onDecline: _declineCall,
            ),
        ],
      ),
    );
  }
}

// ── Tab 0: Settings ───────────────────────────────────────────────────────────
class _SettingsTab extends ConsumerWidget {
  const _SettingsTab({required this.nameCtrl});

  final TextEditingController nameCtrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatarId = ref.watch(_d244AvatarIdProvider);
    final avatar = _avatarById(avatarId);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _kCallAccent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _kCallAccent.withOpacity(0.35)),
          ),
          child: const Text(
            '🟣 POLISH · Section C Day 4/20 · caller disguise · no SOS text on call UI',
            style: TextStyle(color: _kCallAccent, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: avatar.color.withOpacity(0.25),
                child: Icon(avatar.icon, color: avatar.color, size: 44),
              ),
              const SizedBox(height: ZapSpacing.sm),
              Text(
                _displayCallerName(nameCtrl.text, avatarId),
                style: const TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const Text(
                'Preview · incoming call screen',
                style: TextStyle(color: ZapColors.textMuted, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Caller name',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        TextField(
          controller: nameCtrl,
          style: const TextStyle(color: ZapColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Name shown on incoming call',
            hintStyle: const TextStyle(color: ZapColors.textMuted),
            prefixIcon: const Icon(Icons.badge_rounded, color: ZapColors.textMuted),
            filled: true,
            fillColor: ZapColors.bgCard,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: ZapColors.border),
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Caller photo (preset picker)',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.xs),
        const Text(
          'Production uses device photo picker. Mock presets for QA — no gallery permission needed.',
          style: TextStyle(color: ZapColors.textMuted, fontSize: 11),
        ),
        const SizedBox(height: ZapSpacing.sm),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.85,
          children: _kPresetAvatars.map((a) {
            final selected = avatarId == a.id;
            return Material(
              color: selected
                  ? a.color.withOpacity(0.15)
                  : ZapColors.bgCard,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: () {
                  ref.read(_d244AvatarIdProvider.notifier).state = a.id;
                  if (a.id != 'custom') {
                    nameCtrl.text = a.label;
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? a.color : ZapColors.border,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: a.color.withOpacity(0.2),
                        child: Icon(a.icon, color: a.color, size: 24),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        a.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: selected
                              ? ZapColors.textPrimary
                              : ZapColors.textSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.warning.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.warning.withOpacity(0.3)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.visibility_off_rounded, color: ZapColors.warning, size: 18),
              SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: Text(
                  'Safety: call screen must never show "SOS", "Emergency", or ZapSafe branding. '
                  'Looks like a normal phone call to an observer.',
                  style: TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 11,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Tab 1: Demo ───────────────────────────────────────────────────────────────
class _DemoTab extends ConsumerWidget {
  const _DemoTab({required this.onTriggerCall});

  final VoidCallback onTriggerCall;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final triggers = ref.watch(_d244TriggerCountProvider);
    final overlayVisible = ref.watch(_d244OverlayVisibleProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text(
          'SOS Active backdrop (mock)',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.xs),
        const Text(
          'LP27 discreet screen runs underneath. Fake call overlays it — attacker sees a normal call.',
          style: TextStyle(color: ZapColors.textMuted, fontSize: 11),
        ),
        const SizedBox(height: ZapSpacing.md),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 9 / 16,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const _MockSosBackdrop(elapsed: '02:34'),
                if (overlayVisible)
                  Container(color: Colors.black.withOpacity(0.55)),
              ],
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: overlayVisible ? null : onTriggerCall,
            icon: const Icon(Icons.phone_in_talk_rounded),
            label: Text(
              overlayVisible ? 'Call overlay active…' : 'Trigger incoming call',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _kCallAccent,
              disabledBackgroundColor: ZapColors.textMuted.withOpacity(0.2),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Text(
          'Demo triggers: $triggers · Accept/decline returns to discreet screen',
          textAlign: TextAlign.center,
          style: const TextStyle(color: ZapColors.textMuted, fontSize: 10),
        ),
        const SizedBox(height: ZapSpacing.lg),
        OutlinedButton.icon(
          onPressed: () => context.push(AppRoutes.sosActive),
          icon: const Icon(Icons.lock_rounded, size: 18),
          label: const Text('Day 76 · Real SOS Active screen'),
        ),
      ],
    );
  }
}

// ── Tab 2: Safety ─────────────────────────────────────────────────────────────
class _SafetyTab extends ConsumerWidget {
  const _SafetyTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(_d244CallerNameProvider);
    final avatarId = ref.watch(_d244AvatarIdProvider);
    final phase = ref.watch(_d244CallPhaseProvider);
    final triggers = ref.watch(_d244TriggerCountProvider);

    final payload = {
      'feature': 'fake_call_polish',
      'version': '2.0.0',
      'section': 'C',
      'day': 244,
      'caller_name': _displayCallerName(name, avatarId),
      'avatar_preset_id': avatarId,
      'call_phase': phase.name,
      'demo_triggers': triggers,
      'sos_text_on_call_screen': false,
      'allowed_call_screen_words': ['caller name', 'mobile', 'decline', 'accept'],
      'forbidden_call_screen_words': ['SOS', 'Emergency', 'ZapSafe', 'Help', 'Alert'],
      'sos_active_route': AppRoutes.sosActive,
      'overlay_type': 'full_screen_incoming_call',
      'ring_animation': 'pulse_rings_1800ms',
    };

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: ZapColors.danger.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: ZapColors.danger.withOpacity(0.35)),
          ),
          child: const Text(
            '🟣 POLISH · Deflect attention during SOS · call UI must look 100% normal',
            style: TextStyle(color: ZapColors.danger, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Safety constraints',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        const _PolicyRow(
          icon: Icons.phone_in_talk_rounded,
          title: 'Full-screen incoming call overlay',
          subtitle:
              'Ring animation, avatar, caller name — identical to system call UI.',
        ),
        const _PolicyRow(
          icon: Icons.block_rounded,
          title: 'Zero SOS exposure',
          subtitle:
              'No "SOS", "Emergency", or app branding on the call screen (LP27).',
        ),
        const _PolicyRow(
          icon: Icons.check_circle_rounded,
          title: 'Accept / decline → return to SOS',
          subtitle:
              'Both actions dismiss overlay; backend SOS continues silently (mock).',
        ),
        const SizedBox(height: ZapSpacing.md),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => context.push(AppRoutes.sosActive),
            icon: const Icon(Icons.emergency_rounded),
            label: const Text('Day 76 · SOS Active (discreet mode)'),
            style: FilledButton.styleFrom(
              backgroundColor: _kSosBackdrop,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'API contract (mock)',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.border),
          ),
          child: SelectableText(
            _kJsonEncoder.convert(payload),
            style: const TextStyle(
              color: ZapColors.textSecondary,
              fontSize: 10,
              fontFamily: 'monospace',
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(
              ClipboardData(text: _kJsonEncoder.convert(payload)),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Fake call JSON copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy fake call JSON'),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.info.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.info.withOpacity(0.3)),
          ),
          child: const Text(
            'Next: Day 365 — Global Launch Milestone.',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              label: const Text('Day 252 Group Panic'),
              onPressed: () => context.push(AppRoutes.groupJourneyPanic),
            ),
            ActionChip(
              label: const Text('Day 251 Live Map'),
              onPressed: () => context.push(AppRoutes.groupJourneyLiveMap),
            ),
            ActionChip(
              label: const Text('Day 250 Group Journey'),
              onPressed: () => context.push(AppRoutes.groupJourneyCreate),
            ),
            ActionChip(
              label: const Text('Day 249 Voice Assistants'),
              onPressed: () => context.push(AppRoutes.voiceAssistantSetup),
            ),
            ActionChip(
              label: const Text('Day 248 Siri Shortcuts'),
              onPressed: () => context.push(AppRoutes.siriShortcuts),
            ),
            ActionChip(
              label: const Text('Day 247 Haptic Patterns'),
              onPressed: () => context.push(AppRoutes.hapticPatterns),
            ),
            ActionChip(
              label: const Text('Day 246 Visual Alerts'),
              onPressed: () => context.push(AppRoutes.hearingImpairedVisual),
            ),
            ActionChip(
              label: const Text('Day 245 Offline SOS'),
              onPressed: () => context.push(AppRoutes.offlineSosUx),
            ),
            ActionChip(
              label: const Text('Day 243 Ride Safety'),
              onPressed: () => context.push(AppRoutes.rideSafetyV2),
            ),
            ActionChip(
              label: const Text('Day 241 Journey Mode'),
              onPressed: () => context.push(AppRoutes.journeyModeV2),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Mock SOS backdrop ─────────────────────────────────────────────────────────
class _MockSosBackdrop extends StatelessWidget {
  const _MockSosBackdrop({required this.elapsed});

  final String elapsed;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kSosBackdrop,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '68%',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.35),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            elapsed,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 48,
              fontWeight: FontWeight.w300,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const Spacer(flex: 2),
          Text(
            '28.6141  77.2092',
            style: TextStyle(
              color: Colors.white.withOpacity(0.12),
              fontSize: 9,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: ZapSpacing.xxl),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              3,
              (_) => Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Incoming call overlay ───────────────────────────────────────────────────────
class _IncomingCallOverlay extends ConsumerWidget {
  const _IncomingCallOverlay({
    required this.ringAnimation,
    required this.phase,
    required this.onAccept,
    required this.onDecline,
  });

  final AnimationController ringAnimation;
  final _CallPhase phase;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(_d244CallerNameProvider);
    final avatarId = ref.watch(_d244AvatarIdProvider);
    final avatar = _avatarById(avatarId);
    final displayName = _displayCallerName(name, avatarId);
    final startedAt = ref.watch(_d244CallStartedAtProvider);
    final isConnected = phase == _CallPhase.connected;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1E1B4B),
              Color(0xFF0F172A),
              Color(0xFF020617),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: ZapSpacing.huge),
              if (isConnected) ...[
                const Text(
                  'mobile',
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
                const SizedBox(height: ZapSpacing.sm),
                Text(
                  _formatCallElapsed(startedAt),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ] else ...[
                const Text(
                  'mobile',
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
                const SizedBox(height: ZapSpacing.sm),
                const Text(
                  'Incoming call…',
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                ),
              ],
              const SizedBox(height: ZapSpacing.xxxl),
              SizedBox(
                width: 160,
                height: 160,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (!isConnected)
                      ...List.generate(3, (i) {
                        return AnimatedBuilder(
                          animation: ringAnimation,
                          builder: (context, child) {
                            final t = (ringAnimation.value + i * 0.33) % 1.0;
                            final scale = 1.0 + t * 0.8;
                            final opacity = (1.0 - t) * 0.45;
                            return Transform.scale(
                              scale: scale,
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: avatar.color.withOpacity(opacity),
                                    width: 2,
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      }),
                    CircleAvatar(
                      radius: 56,
                      backgroundColor: avatar.color.withOpacity(0.25),
                      child: Icon(avatar.icon, color: avatar.color, size: 56),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: ZapSpacing.xxl),
              Text(
                displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const Spacer(),
              if (isConnected)
                Padding(
                  padding: const EdgeInsets.only(bottom: 48),
                  child: _CallActionButton(
                    label: 'End',
                    icon: Icons.call_end_rounded,
                    color: ZapColors.danger,
                    onTap: onDecline,
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _CallActionButton(
                        label: 'Decline',
                        icon: Icons.call_end_rounded,
                        color: ZapColors.danger,
                        onTap: onDecline,
                      ),
                      _CallActionButton(
                        label: 'Accept',
                        icon: Icons.call_rounded,
                        color: const Color(0xFF22C55E),
                        onTap: onAccept,
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: ZapSpacing.xxxl),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallActionButton extends StatelessWidget {
  const _CallActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 64,
              height: 64,
              child: Icon(icon, color: Colors.white, size: 28),
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}

class _PolicyRow extends StatelessWidget {
  const _PolicyRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: ZapColors.info, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.tab, required this.onSelect});

  final int tab;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ZapColors.bgCard,
      child: Row(
        children: List.generate(_kTabs.length, (i) {
          final selected = tab == i;
          return Expanded(
            child: InkWell(
              onTap: () => onSelect(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected ? _kCallAccent : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  _kTabs[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? _kCallAccent : ZapColors.textMuted,
                    fontWeight:
                        selected ? FontWeight.w800 : FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
