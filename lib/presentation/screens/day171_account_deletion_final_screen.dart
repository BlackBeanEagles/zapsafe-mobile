/// Day 171 — Account Deletion: Permanent Deletion & Wiped State
///
/// Third day of the Days 169-172 Account Deletion block.
/// Day 169: Deletion request — warnings, reason, re-auth, submit   ✅
/// Day 170: Grace period — countdown, notifications, cancel         ✅
/// Day 171: Permanent deletion — day-30 trigger, re-auth gate,
///           deletion-in-progress animation, account wiped screen,
///           post-deletion login behaviour.
/// Day 172: Edge cases — active SOS, evidence hold, DPDP retention.
///
/// 🟡 MOCK-NOW — no backend endpoint for the actual hard-delete.
///    This screen documents the full day-30 UX and system behaviour.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _activeTabProvider      = StateProvider<int>((ref) => 0);
final _day30StepProvider      = StateProvider<int>((ref) => 0);     // 0-5
final _day30RunningProvider   = StateProvider<bool>((ref) => false);
final _wipeProgressProvider   = StateProvider<double>((ref) => 0.0);
final _wipedCatsProvider      = StateProvider<int>((ref) => 0);
final _wipeStateProvider      = StateProvider<_WipeState>((ref) => _WipeState.idle);
final _expandedRetainProvider = StateProvider<int?>((ref) => null);

// ── Enums ──────────────────────────────────────────────────────────────────────
enum _WipeState { idle, wiping, done }

// ── Data ───────────────────────────────────────────────────────────────────────
class _Day30Step {
  final IconData icon;
  final Color    color;
  final String   title;
  final String   when;
  final String   detail;
  const _Day30Step({
    required this.icon, required this.color, required this.title,
    required this.when, required this.detail,
  });
}

const _kDay30Steps = [
  _Day30Step(
    icon: Icons.email_rounded, color: Color(0xFF3B82F6),
    title: 'Final reminder email sent',
    when: 'Day 29  09:00',
    detail: 'ZapSafe sends a final reminder email 24 hours before deletion: '
        '"Your account will be permanently deleted tomorrow at midnight." '
        'Includes cancel link valid for 23 hours.',
  ),
  _Day30Step(
    icon: Icons.lock_clock_rounded, color: Color(0xFFF59E0B),
    title: 'Re-auth gate shown',
    when: 'Day 30  on next app open',
    detail: 'The first time the user opens the app on day 30, a full-screen '
        'modal blocks all navigation. Re-authentication (OTP or biometric) '
        'is required to confirm the deletion. User can still cancel here.',
  ),
  _Day30Step(
    icon: Icons.warning_rounded, color: Color(0xFFEF4444),
    title: 'Final warning modal',
    when: 'After re-auth passes',
    detail: 'A red modal with 10-second countdown auto-dismiss. '
        '"Your data will be permanently deleted in 10 seconds." '
        'A "Cancel" button aborts deletion. '
        'If dismissed or countdown completes, deletion begins.',
  ),
  _Day30Step(
    icon: Icons.delete_sweep_rounded, color: Color(0xFFEF4444),
    title: 'Hard delete executes',
    when: 'Day 30  23:59  (or after countdown)',
    detail: 'Server-side deletion job runs. '
        'Data is wiped category by category with audit trail. '
        'Takes 30s–5 min depending on evidence vault size. '
        'User sees animated deletion progress screen.',
  ),
  _Day30Step(
    icon: Icons.no_accounts_rounded, color: Color(0xFF6B7280),
    title: 'Account wiped state',
    when: 'After deletion completes',
    detail: 'App shows "Account Deleted" screen with confirmation receipt. '
        'JWT is invalidated server-side. '
        'App clears local Hive storage. '
        'User is redirected to phone-entry screen.',
  ),
  _Day30Step(
    icon: Icons.mark_email_read_rounded, color: Color(0xFF10B981),
    title: 'Deletion receipt email',
    when: 'Within 5 minutes of completion',
    detail: 'Final email sent to account email address: '
        '"Your ZapSafe account has been permanently deleted." '
        'Includes deletion certificate with timestamp and deletion ID. '
        'Required by GDPR Art. 17(3) notification obligation.',
  ),
];

class _WipeCategory {
  final String   name;
  final IconData icon;
  final Color    color;
  final int      estimatedMs;   // how long deletion takes
  const _WipeCategory({
    required this.name, required this.icon,
    required this.color, required this.estimatedMs,
  });
}

const _kWipeCategories = [
  _WipeCategory(name: 'Location & Safe Zones',    icon: Icons.location_on_rounded,  color: Color(0xFF10B981), estimatedMs: 200),
  _WipeCategory(name: 'Analytics & Usage',        icon: Icons.bar_chart_rounded,    color: Color(0xFF8B5CF6), estimatedMs: 300),
  _WipeCategory(name: 'Activity Audit Log',       icon: Icons.history_rounded,      color: Color(0xFF3B82F6), estimatedMs: 500),
  _WipeCategory(name: 'SOS Events & Incidents',   icon: Icons.warning_rounded,      color: Color(0xFFEF4444), estimatedMs: 800),
  _WipeCategory(name: 'Emergency Contacts',       icon: Icons.people_rounded,       color: Color(0xFF10B981), estimatedMs: 300),
  _WipeCategory(name: 'Profile & Account',        icon: Icons.account_circle_rounded,color: Color(0xFF3B82F6), estimatedMs: 400),
  _WipeCategory(name: 'Evidence Vault',           icon: Icons.lock_rounded,         color: Color(0xFFF59E0B), estimatedMs: 2500),
  _WipeCategory(name: 'App Preferences',          icon: Icons.settings_rounded,     color: Color(0xFF6B7280), estimatedMs: 100),
  _WipeCategory(name: 'JWT & Session Tokens',     icon: Icons.vpn_key_rounded,      color: Color(0xFFEF4444), estimatedMs: 150),
];

class _RetainedItem {
  final String   category;
  final String   reason;
  final String   basis;
  final String   retainedFor;
  final Color    color;
  const _RetainedItem({
    required this.category, required this.reason,
    required this.basis, required this.retainedFor, required this.color,
  });
}

const _kRetained = [
  _RetainedItem(
    category: 'Billing records',
    reason: 'GST Act 2017 requires 7-year retention of transaction records.',
    basis: 'Legal obligation (GDPR Art. 17(3)(b))',
    retainedFor: '7 years from last transaction',
    color: Color(0xFFF59E0B),
  ),
  _RetainedItem(
    category: 'Law-enforcement submitted evidence',
    reason: 'Evidence submitted to police cannot be deleted once in their custody.',
    basis: 'Legal obligation — criminal law',
    retainedFor: 'Duration of legal proceedings',
    color: Color(0xFFEF4444),
  ),
  _RetainedItem(
    category: 'Deletion certificate (anonymised)',
    reason: 'Proof that deletion was completed, required for GDPR accountability.',
    basis: 'GDPR Art. 5(2) accountability principle',
    retainedFor: '3 years',
    color: Color(0xFF8B5CF6),
  ),
  _RetainedItem(
    category: 'Aggregate / anonymised crash stats',
    reason: 'Crash counts with no personal linkage retained for product safety.',
    basis: 'Legitimate interest — no personal data',
    retainedFor: 'Indefinitely (no personal link)',
    color: Color(0xFF6B7280),
  ),
];

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day171AccountDeletionFinalScreen extends ConsumerWidget {
  const Day171AccountDeletionFinalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_activeTabProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Permanent Deletion'),
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: ZapSpacing.md, top: 8, bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4)),
            ),
            child: const Text('DAY 30  ⚠',
                style: TextStyle(color: Color(0xFFEF4444), fontSize: 10,
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
            _TabBar(active: tab,
                onSelect: (t) => ref.read(_activeTabProvider.notifier).state = t),
            const SizedBox(height: ZapSpacing.xl),
            if (tab == 0) const _Day30Tab(),
            if (tab == 1) const _WipeTab(),
            if (tab == 2) const _PostDeletionTab(),
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
            colors: [Color(0xFF120808), Color(0xFF080404), Color(0xFF0A0A0A)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.55), width: 2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: ZapSpacing.sm, runSpacing: ZapSpacing.sm, children: [
          _badge('⚡  DAY 171',                  const Color(0xFFEF4444)),
          _badge('🟡 MOCK-NOW',                  const Color(0xFFF59E0B)),
          _badge('Account Deletion  ·  Day 3/4', const Color(0xFF8B5CF6)),
        ]),
        const SizedBox(height: ZapSpacing.md),
        const Text('Permanent Deletion\n& Account Wiped State',
            style: TextStyle(color: Colors.white, fontSize: 26,
                fontWeight: FontWeight.w900, height: 1.2)),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          'What happens on day 30: re-auth gate, final warning '
          'countdown, animated data wipe, account wiped screen, '
          'post-deletion login behaviour, and legal receipt.',
          style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6)),
        const SizedBox(height: ZapSpacing.md),
        const Row(children: [
          _HStat('6',    '6 day-30 events',  Color(0xFFEF4444)),
          _HStat('9',    '9 wipe categories',Color(0xFFF59E0B)),
          _HStat('4',    '4 retained items', Color(0xFF6B7280)),
          _HStat('GDPR', 'Art. 17(3)',        Color(0xFF3B82F6)),
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
      (Icons.today_rounded,          Color(0xFFEF4444), 'Day 30 Flow'),
      (Icons.delete_sweep_rounded,   Color(0xFFF59E0B), 'Data Wipe'),
      (Icons.no_accounts_rounded,    Color(0xFF6B7280), 'Post-Deletion'),
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
// TAB 1 — Day 30 Flow (6-step walkthrough)
// ══════════════════════════════════════════════════════════════════════════════
class _Day30Tab extends ConsumerWidget {
  const _Day30Tab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentStep = ref.watch(_day30StepProvider);
    final running     = ref.watch(_day30RunningProvider);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.info_outline_rounded, color: const Color(0xFFEF4444),
          text: 'Step through the 6 events that happen on deletion day. '
              'Each step shows the exact screen or system action. '
              'Tap "Next Step" or "Auto-play" to walk through the sequence.'),
      const SizedBox(height: ZapSpacing.lg),

      // ── Step timeline ──────────────────────────────────────────────
      _StepTimeline(current: currentStep, total: _kDay30Steps.length),
      const SizedBox(height: ZapSpacing.xl),

      // ── Active step card ───────────────────────────────────────────
      _Day30StepCard(step: _kDay30Steps[currentStep], index: currentStep),
      const SizedBox(height: ZapSpacing.xl),

      // ── Mock screen for this step ──────────────────────────────────
      const _SectionLabel('MOCK SCREEN  ·  WHAT THE USER SEES'),
      const SizedBox(height: ZapSpacing.md),
      _MockScreen(stepIndex: currentStep),
      const SizedBox(height: ZapSpacing.xl),

      // ── Controls ──────────────────────────────────────────────────
      Row(children: [
        if (currentStep > 0)
          Expanded(child: _outlineBtn('← Prev', const Color(0xFF6B7280),
              () => ref.read(_day30StepProvider.notifier).state = currentStep - 1)),
        if (currentStep > 0) const SizedBox(width: ZapSpacing.sm),
        if (currentStep < _kDay30Steps.length - 1)
          Expanded(flex: 2, child: _primaryBtn(
            label: running ? 'Playing…' : 'Next Step →',
            color: const Color(0xFFEF4444),
            onTap: running ? null : () =>
                ref.read(_day30StepProvider.notifier).state = currentStep + 1,
          )),
        if (currentStep == _kDay30Steps.length - 1)
          Expanded(child: _primaryBtn(
            label: 'Reset  ↺',
            color: const Color(0xFF3B82F6),
            onTap: () => ref.read(_day30StepProvider.notifier).state = 0,
          )),
      ]),
      const SizedBox(height: ZapSpacing.sm),
      if (currentStep < _kDay30Steps.length - 1 && !running)
        _outlineBtn('⚡ Auto-play all steps', const Color(0xFF8B5CF6),
            () => _autoPlay(ref)),

      const SizedBox(height: ZapSpacing.xl),

      // ── Re-auth gate mock (step 1 detail) ─────────────────────────
      if (currentStep == 1) ...[
        const _SectionLabel('RE-AUTH GATE  ·  FULL SCREEN MODAL DETAIL'),
        const SizedBox(height: ZapSpacing.md),
        _ReAuthGateDetail(),
        const SizedBox(height: ZapSpacing.xl),
      ],

      // ── Final warning countdown (step 2 detail) ───────────────────
      if (currentStep == 2) ...[
        const _SectionLabel('FINAL WARNING COUNTDOWN  ·  DETAIL'),
        const SizedBox(height: ZapSpacing.md),
        _FinalWarningDetail(),
        const SizedBox(height: ZapSpacing.xl),
      ],
    ]);
  }

  Future<void> _autoPlay(WidgetRef ref) async {
    ref.read(_day30RunningProvider.notifier).state = true;
    for (int i = 0; i < _kDay30Steps.length; i++) {
      ref.read(_day30StepProvider.notifier).state = i;
      await Future.delayed(const Duration(milliseconds: 1800));
    }
    ref.read(_day30RunningProvider.notifier).state = false;
  }
}

class _StepTimeline extends StatelessWidget {
  final int current, total;
  const _StepTimeline({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(children: List.generate(total * 2 - 1, (i) {
      if (i.isOdd) {
        final passed = current > i ~/ 2;
        return Expanded(child: Container(
            height: 2,
            color: passed ? const Color(0xFFEF4444) : const Color(0xFF2A2A2A)));
      }
      final idx   = i ~/ 2;
      final isDone= current > idx;
      final isNow = current == idx;
      final color = isNow || isDone
          ? const Color(0xFFEF4444) : const Color(0xFF2A2A2A);
      return Column(mainAxisSize: MainAxisSize.min, children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 28, height: 28,
          decoration: BoxDecoration(
              color: color.withOpacity(isNow ? 0.15 : isDone ? 0.08 : 0.0),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: isNow ? 2 : 1.5)),
          child: isDone
              ? const Icon(Icons.check, color: Color(0xFFEF4444), size: 12)
              : Center(child: Text('${idx + 1}', style: TextStyle(
                  color: color, fontSize: 9, fontWeight: FontWeight.w800)))),
        const SizedBox(height: 3),
        Text('${idx + 1}', style: TextStyle(
            color: isNow ? const Color(0xFFEF4444) : const Color(0xFF4B5563),
            fontSize: 7)),
      ]);
    }));
  }
}

class _Day30StepCard extends StatelessWidget {
  final _Day30Step step; final int index;
  const _Day30StepCard({required this.step, required this.index});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
          color: step.color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          border: Border.all(color: step.color.withOpacity(0.45), width: 2)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
                color: step.color.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(step.icon, color: step.color, size: 20)),
          const SizedBox(width: ZapSpacing.md),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Step ${index + 1} of ${_kDay30Steps.length}',
                style: TextStyle(color: step.color, fontSize: 10,
                    fontWeight: FontWeight.w700, letterSpacing: 1)),
            Text(step.title, style: const TextStyle(color: Colors.white,
                fontSize: 14, fontWeight: FontWeight.w800)),
          ])),
        ]),
        const SizedBox(height: ZapSpacing.md),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
              color: step.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Text('⏰  ${step.when}', style: TextStyle(
              color: step.color, fontSize: 10, fontWeight: FontWeight.w700))),
        const SizedBox(height: ZapSpacing.md),
        Text(step.detail, style: const TextStyle(
            color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6)),
      ]),
    );
  }
}

// ── Mock screen per step ───────────────────────────────────────────────────────
class _MockScreen extends StatelessWidget {
  final int stepIndex;
  const _MockScreen({required this.stepIndex});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          border: Border.all(color: const Color(0xFF2A2A2A))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Phone notch bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.md, vertical: 8),
          decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(ZapSpacing.radius),
                  topRight: Radius.circular(ZapSpacing.radius))),
          child: Row(children: [
            const Icon(Icons.smartphone_rounded, color: Color(0xFF4B5563), size: 13),
            const SizedBox(width: 6),
            Text(_stepMockLabel(stepIndex),
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10)),
          ])),
        Padding(
          padding: const EdgeInsets.all(ZapSpacing.md),
          child: _stepMockContent(stepIndex),
        ),
      ]),
    );
  }

  String _stepMockLabel(int i) => switch (i) {
    0 => 'Email client  ·  ZapSafe final reminder',
    1 => 'ZapSafe app  ·  Full-screen re-auth gate',
    2 => 'ZapSafe app  ·  Final warning modal',
    3 => 'ZapSafe app  ·  Deletion in progress',
    4 => 'ZapSafe app  ·  Account wiped screen',
    _ => 'Email client  ·  Deletion receipt',
  };

  Widget _stepMockContent(int i) => switch (i) {
    0 => _mockEmail(),
    1 => _mockReAuthGate(),
    2 => _mockFinalWarning(),
    3 => _mockDeletionProgress(),
    4 => _mockWipedState(),
    _ => _mockReceiptEmail(),
  };

  // Step 0 — reminder email
  Widget _mockEmail() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _emailHeader('ZapSafe <noreply@zapsafe.app>', 'FINAL NOTICE: Your account deletes in 24 hours'),
    const SizedBox(height: ZapSpacing.md),
    const Text('Hi Priya,\n\nThis is your final reminder that your ZapSafe account will be permanently deleted tomorrow (June 29, 2026) at midnight.\n\nIf this was a mistake, tap the button below to cancel.',
        style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 11, height: 1.6)),
    const SizedBox(height: ZapSpacing.md),
    _mockBtn('Cancel Deletion', const Color(0xFF10B981)),
    const SizedBox(height: ZapSpacing.sm),
    const Text('If you do nothing, your account will be deleted automatically.',
        style: TextStyle(color: Color(0xFF6B7280), fontSize: 10)),
  ]);

  // Step 1 — re-auth gate
  Widget _mockReAuthGate() => Column(children: [
    const Icon(Icons.lock_clock_rounded, color: Color(0xFFF59E0B), size: 32),
    const SizedBox(height: ZapSpacing.sm),
    const Text('Identity Verification Required',
        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
        textAlign: TextAlign.center),
    const SizedBox(height: 6),
    const Text('Your account is scheduled for deletion today. Please verify your identity to proceed.',
        style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11, height: 1.5), textAlign: TextAlign.center),
    const SizedBox(height: ZapSpacing.md),
    _mockBtn('Send OTP to +91 ****3210', const Color(0xFF8B5CF6)),
    const SizedBox(height: ZapSpacing.sm),
    _mockBtnOutline('Cancel Deletion Instead', const Color(0xFF10B981)),
  ]);

  // Step 2 — final warning countdown
  Widget _mockFinalWarning() => Column(children: [
    Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withOpacity(0.08),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.5))),
      child: Column(children: [
        const Icon(Icons.delete_forever_rounded, color: Color(0xFFEF4444), size: 28),
        const SizedBox(height: ZapSpacing.sm),
        const Text('PERMANENT DELETION IN', style: TextStyle(
            color: Color(0xFF9CA3AF), fontSize: 10, letterSpacing: 2)),
        const Text('10', style: TextStyle(color: Color(0xFFEF4444),
            fontSize: 48, fontWeight: FontWeight.w900, height: 1.0)),
        const Text('seconds', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 10)),
        const SizedBox(height: ZapSpacing.md),
        _mockBtnOutline('Cancel — Don\'t Delete', const Color(0xFF10B981)),
      ])),
  ]);

  // Step 3 — deletion in progress
  Widget _mockDeletionProgress() => Column(children: [
    const Icon(Icons.delete_sweep_rounded, color: Color(0xFFEF4444), size: 28),
    const SizedBox(height: ZapSpacing.sm),
    const Text('Permanently deleting your data…',
        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
        textAlign: TextAlign.center),
    const SizedBox(height: ZapSpacing.md),
    ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: const LinearProgressIndicator(
        value: 0.6,
        backgroundColor: Color(0xFF2A2A2A),
        valueColor: AlwaysStoppedAnimation(Color(0xFFEF4444)),
        minHeight: 6)),
    const SizedBox(height: ZapSpacing.sm),
    const Text('Erasing Evidence Vault…  (60%)',
        style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 10)),
    const SizedBox(height: ZapSpacing.md),
    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      _doneChip('Location ✓'),
      const SizedBox(width: ZapSpacing.xs),
      _doneChip('Analytics ✓'),
      const SizedBox(width: ZapSpacing.xs),
      _doneChip('Contacts ✓'),
    ]),
    const SizedBox(height: ZapSpacing.xs),
    const Text('Do not close the app.', style: TextStyle(
        color: Color(0xFF6B7280), fontSize: 9)),
  ]);

  // Step 4 — account wiped
  Widget _mockWipedState() => Column(children: [
    const Icon(Icons.no_accounts_rounded, color: Color(0xFF6B7280), size: 32),
    const SizedBox(height: ZapSpacing.sm),
    const Text('Account Deleted', style: TextStyle(
        color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
        textAlign: TextAlign.center),
    const SizedBox(height: 6),
    const Text('Your ZapSafe account and personal data have been permanently deleted.',
        style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11, height: 1.5),
        textAlign: TextAlign.center),
    const SizedBox(height: ZapSpacing.md),
    Container(
      padding: const EdgeInsets.all(ZapSpacing.sm),
      decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: const Color(0xFF2A2A2A))),
      child: Column(children: [
        _kvSmall('Deletion ID', 'del_20260530_xyz'),
        _kvSmall('Completed', 'June 29, 2026  23:59'),
        _kvSmall('Receipt sent to', 'p***a@gmail.com'),
      ])),
    const SizedBox(height: ZapSpacing.md),
    _mockBtn('Create New Account', const Color(0xFF3B82F6)),
  ]);

  // Step 5 — receipt email
  Widget _mockReceiptEmail() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _emailHeader('ZapSafe <noreply@zapsafe.app>', 'Your ZapSafe account has been deleted'),
    const SizedBox(height: ZapSpacing.md),
    const Text('Hi Priya,\n\nYour ZapSafe account has been permanently deleted as requested.\n\nDeletion certificate:\n• ID: del_20260530_xyz\n• Completed: June 29, 2026  23:59 IST\n• Data wiped: 9 categories\n• Retained: billing records only\n\nThank you for using ZapSafe.',
        style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 11, height: 1.6)),
    const SizedBox(height: ZapSpacing.sm),
    const Text('This email is your official receipt. Keep it for your records.',
        style: TextStyle(color: Color(0xFF6B7280), fontSize: 10)),
  ]);

  static Widget _emailHeader(String from, String subject) => Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
    Container(
      padding: const EdgeInsets.all(ZapSpacing.sm),
      decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: const Color(0xFF2A2A2A))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('From: ', style: TextStyle(color: Color(0xFF6B7280), fontSize: 10)),
          Text(from, style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 10)),
        ]),
        const SizedBox(height: 3),
        Row(children: [
          const Text('Subject: ', style: TextStyle(color: Color(0xFF6B7280), fontSize: 10)),
          Expanded(child: Text(subject, style: const TextStyle(
              color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700))),
        ]),
      ])),
  ]);

  static Widget _mockBtn(String label, Color color) => Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color, color.withOpacity(0.8)]),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall)),
      child: Center(child: Text(label, style: const TextStyle(
          color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))));

  static Widget _mockBtnOutline(String label, Color color) => Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: color.withOpacity(0.4))),
      child: Center(child: Text(label, style: TextStyle(
          color: color, fontSize: 11, fontWeight: FontWeight.w600))));

  static Widget _doneChip(String label) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
          color: const Color(0xFF10B981).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: const TextStyle(
          color: Color(0xFF10B981), fontSize: 9, fontWeight: FontWeight.w700)));

  static Widget _kvSmall(String k, String v) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        SizedBox(width: 80, child: Text(k, style: const TextStyle(
            color: Color(0xFF6B7280), fontSize: 9))),
        Expanded(child: Text(v, style: const TextStyle(
            color: Color(0xFFD1D5DB), fontSize: 9, fontFamily: 'monospace'))),
      ]));
}

// ── Re-auth gate detail ────────────────────────────────────────────────────────
class _ReAuthGateDetail extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: const Color(0xFF2A2A2A))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SectionLabel('WHY RE-AUTH ON DAY 30?'),
        const SizedBox(height: ZapSpacing.sm),
        ...[
          ('Prevents accidental deletion',
              'User may have forgotten they submitted a request 30 days ago. '
              'Re-auth forces conscious action.'),
          ('Protects against account takeover',
              'If an attacker submitted the deletion request, re-auth '
              'blocks them from completing the wipe without physical device access.'),
          ('Legal requirement',
              'DPDP §13 requires the data fiduciary to ensure the request '
              'was made by the data principal — re-auth fulfils this.'),
          ('Biometric or OTP',
              'If device biometric is enrolled: Face ID / fingerprint. '
              'Fallback: OTP to registered phone. '
              'No password — ZapSafe is phone-number based.'),
        ].map((t) => Padding(
              padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.circle, color: Color(0xFFF59E0B), size: 6),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.$1, style: const TextStyle(color: Colors.white,
                      fontSize: 11, fontWeight: FontWeight.w600)),
                  Text(t.$2, style: const TextStyle(color: Color(0xFF9CA3AF),
                      fontSize: 10, height: 1.4)),
                ])),
              ]))),
      ]));
}

// ── Final warning countdown detail ─────────────────────────────────────────────
class _FinalWarningDetail extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: const Color(0xFF2A2A2A))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SectionLabel('10-SECOND COUNTDOWN  ·  IMPLEMENTATION'),
        const SizedBox(height: ZapSpacing.md),
        _infoBox(icon: Icons.timer_rounded, color: const Color(0xFFEF4444),
            text: 'The 10-second countdown serves two purposes: '
                '(1) last chance to cancel with zero friction — tap Cancel, done. '
                '(2) creates a deliberate pause so the user registers the gravity.'),
        const SizedBox(height: ZapSpacing.md),
        ...[
          ('Countdown timer', '10 → 0, 1 second intervals. '
              'Text turns red below 5. "Cancel" button always visible.'),
          ('Auto-dismiss on 0', 'If user does nothing, deletion starts automatically. '
              'No extra confirmation needed — user already did re-auth.'),
          ('Cancel during countdown', 'Tapping Cancel calls '
              'DELETE /api/v1/account/deletion-request immediately. '
              'Returns to dashboard. Grace period cancelled.'),
          ('Device offline', 'If the app cannot reach the server at 0, '
              'deletion is queued server-side and proceeds when server reconnects. '
              'App shows "Deletion scheduled" instead of progress screen.'),
        ].map((t) => Padding(
              padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.circle, color: Color(0xFFEF4444), size: 6),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.$1, style: const TextStyle(color: Colors.white,
                      fontSize: 11, fontWeight: FontWeight.w600)),
                  Text(t.$2, style: const TextStyle(color: Color(0xFF9CA3AF),
                      fontSize: 10, height: 1.4)),
                ])),
              ]))),
      ]));
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — Data Wipe Animation
// ══════════════════════════════════════════════════════════════════════════════
class _WipeTab extends ConsumerWidget {
  const _WipeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wipedCount  = ref.watch(_wipedCatsProvider);
    final wipeProgress= ref.watch(_wipeProgressProvider);
    final wipeState   = ref.watch(_wipeStateProvider);
    final total       = _kWipeCategories.length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.delete_sweep_rounded, color: const Color(0xFFF59E0B),
          text: 'Simulates the animated deletion-in-progress screen shown to the '
              'user. Data is wiped category by category with a live progress bar. '
              'Evidence Vault takes longest due to file sizes.'),
      const SizedBox(height: ZapSpacing.lg),

      // ── Progress header ────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFFEF4444).withOpacity(0.07),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.35))),
        child: Column(children: [
          Row(children: [
            if (wipeState == _WipeState.wiping)
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(
                  color: Color(0xFFEF4444), strokeWidth: 2)),
            if (wipeState == _WipeState.done)
              const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
            if (wipeState == _WipeState.idle)
              const Icon(Icons.delete_sweep_rounded, color: Color(0xFFEF4444), size: 18),
            const SizedBox(width: ZapSpacing.sm),
            Text(
              wipeState == _WipeState.done
                  ? 'All data permanently deleted ✅'
                  : wipeState == _WipeState.wiping
                      ? 'Erasing ${wipedCount < total ? _kWipeCategories[wipedCount].name : "…"}…'
                      : 'Tap "Start Wipe Simulation" below',
              style: TextStyle(
                  color: wipeState == _WipeState.done
                      ? const Color(0xFF10B981) : Colors.white,
                  fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
          if (wipeState != _WipeState.idle) ...[
            const SizedBox(height: ZapSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                  value: wipeProgress,
                  backgroundColor: const Color(0xFF2A2A2A),
                  valueColor: AlwaysStoppedAnimation(
                      wipeState == _WipeState.done
                          ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                  minHeight: 7)),
            const SizedBox(height: 6),
            Row(children: [
              Text('$wipedCount / $total categories wiped',
                  style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 10)),
              const Spacer(),
              Text('${(wipeProgress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(color: Color(0xFFEF4444), fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ]),
          ],
        ]),
      ),
      const SizedBox(height: ZapSpacing.lg),

      // ── Category list ──────────────────────────────────────────────
      const _SectionLabel('9 DATA CATEGORIES  ·  DELETION ORDER'),
      const SizedBox(height: ZapSpacing.md),
      ..._kWipeCategories.asMap().entries.map((e) {
        final i   = e.key;
        final cat = e.value;
        final isDone   = wipedCount > i;
        final isActive = wipeState == _WipeState.wiping && wipedCount == i;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
          padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.md, vertical: 10),
          decoration: BoxDecoration(
              color: isDone
                  ? const Color(0xFF10B981).withOpacity(0.06)
                  : isActive
                      ? const Color(0xFFEF4444).withOpacity(0.08)
                      : const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(
                  color: isDone
                      ? const Color(0xFF10B981).withOpacity(0.3)
                      : isActive
                          ? const Color(0xFFEF4444).withOpacity(0.4)
                          : const Color(0xFF2A2A2A),
                  width: isActive ? 2 : 1)),
          child: Row(children: [
            Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                    color: cat.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(7)),
                child: Icon(cat.icon, color: cat.color, size: 14)),
            const SizedBox(width: ZapSpacing.md),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(cat.name, style: const TextStyle(color: Colors.white,
                  fontSize: 11, fontWeight: FontWeight.w500)),
              Text('~${cat.estimatedMs < 1000
                  ? "${cat.estimatedMs}ms" : "${(cat.estimatedMs / 1000).toStringAsFixed(1)}s"}',
                  style: const TextStyle(color: Color(0xFF4B5563), fontSize: 9)),
            ])),
            if (isActive)
              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(
                  color: Color(0xFFEF4444), strokeWidth: 2))
            else if (isDone)
              const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16)
            else
              const Icon(Icons.hourglass_top_rounded, color: Color(0xFF2A2A2A), size: 14),
          ]),
        );
      }),

      const SizedBox(height: ZapSpacing.xl),

      // Controls
      if (wipeState == _WipeState.idle)
        _primaryBtn(
          label: 'Start Wipe Simulation  ⚠',
          color: const Color(0xFFEF4444),
          onTap: () => _startWipe(ref),
        ),
      if (wipeState == _WipeState.done) ...[
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.07),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(color: const Color(0xFF10B981).withOpacity(0.35))),
          child: const Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
              SizedBox(width: ZapSpacing.sm),
              Text('Wipe complete — 9 categories deleted',
                  style: TextStyle(color: Color(0xFF10B981), fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ]),
            SizedBox(height: 6),
            Text('In production, deletion certificate is generated and '
                'receipt email is queued within 5 minutes.',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11,
                    height: 1.5), textAlign: TextAlign.center),
          ])),
        const SizedBox(height: ZapSpacing.md),
        _outlineBtn('Reset simulation  ↺', const Color(0xFF6B7280), () {
          ref.read(_wipeStateProvider.notifier).state    = _WipeState.idle;
          ref.read(_wipedCatsProvider.notifier).state   = 0;
          ref.read(_wipeProgressProvider.notifier).state= 0.0;
        }),
      ],
    ]);
  }

  Future<void> _startWipe(WidgetRef ref) async {
    ref.read(_wipeStateProvider.notifier).state = _WipeState.wiping;
    final total = _kWipeCategories.length;
    for (int i = 0; i < total; i++) {
      ref.read(_wipedCatsProvider.notifier).state = i;
      final cat = _kWipeCategories[i];
      // Simulate deletion time (compressed for demo)
      final demoMs = (cat.estimatedMs * 0.3).round().clamp(100, 800);
      await Future.delayed(Duration(milliseconds: demoMs));
      ref.read(_wipedCatsProvider.notifier).state = i + 1;
      ref.read(_wipeProgressProvider.notifier).state = (i + 1) / total;
    }
    ref.read(_wipeStateProvider.notifier).state = _WipeState.done;
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 3 — Post-Deletion State
// ══════════════════════════════════════════════════════════════════════════════
class _PostDeletionTab extends ConsumerWidget {
  const _PostDeletionTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(_expandedRetainProvider);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.no_accounts_rounded, color: const Color(0xFF6B7280),
          text: 'What happens if a deleted user tries to log in, what data '
              'is retained (and why), and the deletion certificate details.'),
      const SizedBox(height: ZapSpacing.lg),

      // ── Login attempt mock ─────────────────────────────────────────
      const _SectionLabel('IF DELETED USER TRIES TO LOG IN'),
      const SizedBox(height: ZapSpacing.md),
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A))),
        child: Column(children: [
          // Mock phone entry
          Container(
            padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.md, vertical: 10),
            decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(color: const Color(0xFF2A2A2A))),
            child: const Row(children: [
              Text('+91 ', style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
              Text('98765 43210', style: TextStyle(color: Colors.white, fontSize: 13)),
            ])),
          const SizedBox(height: ZapSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.12),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.4))),
            child: const Center(child: Text('Send OTP',
                style: TextStyle(color: Color(0xFF3B82F6), fontSize: 12,
                    fontWeight: FontWeight.w700)))),
          const SizedBox(height: ZapSpacing.md),
          // Error state
          Container(
            padding: const EdgeInsets.all(ZapSpacing.sm),
            decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.08),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4))),
            child: const Row(children: [
              Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 16),
              SizedBox(width: ZapSpacing.sm),
              Expanded(child: Text(
                'No account found for this number. '
                'The account may have been deleted. '
                'Tap below to create a new account.',
                style: TextStyle(color: Color(0xFFEF4444), fontSize: 11, height: 1.4))),
            ])),
          const SizedBox(height: ZapSpacing.sm),
          const Text('API: POST /auth/send-otp → 404 { "error": "account_not_found" }',
              style: TextStyle(color: Color(0xFF4B5563), fontSize: 9,
                  fontFamily: 'monospace')),
        ]),
      ),
      const SizedBox(height: ZapSpacing.lg),

      // ── Deletion certificate ───────────────────────────────────────
      const _SectionLabel('DELETION CERTIFICATE'),
      const SizedBox(height: ZapSpacing.md),
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFF8B5CF6).withOpacity(0.06),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.verified_rounded, color: Color(0xFF8B5CF6), size: 16),
            SizedBox(width: ZapSpacing.sm),
            Text('ZapSafe Deletion Certificate',
                style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: ZapSpacing.md),
          _certRow('Deletion ID',    'del_20260530_xyz123'),
          _certRow('Account',        '+91 98765 43210'),
          _certRow('Requested',      'May 30, 2026  14:30 IST'),
          _certRow('Completed',      'June 29, 2026  23:59 IST'),
          _certRow('Data wiped',     '9 categories (see wipe tab)'),
          _certRow('Data retained',  '4 categories (legal basis)'),
          _certRow('DPDP basis',     '§13 Right to Erasure'),
          _certRow('GDPR basis',     'Art. 17 Right to be forgotten'),
          _certRow('Certificate hash','sha256: e3b0c442…'),
        ]),
      ),
      const SizedBox(height: ZapSpacing.lg),

      // ── Retained data ──────────────────────────────────────────────
      const _SectionLabel('DATA RETAINED AFTER DELETION  ·  4 ITEMS'),
      const SizedBox(height: ZapSpacing.md),
      ..._kRetained.asMap().entries.map((e) {
        final i    = e.key;
        final item = e.value;
        final isExp = expanded == i;
        return GestureDetector(
          onTap: () => ref.read(_expandedRetainProvider.notifier).state =
              isExp ? null : i,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            decoration: BoxDecoration(
                color: isExp
                    ? item.color.withOpacity(0.06) : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                    color: isExp
                        ? item.color.withOpacity(0.35) : const Color(0xFF2A2A2A),
                    width: isExp ? 2 : 1)),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(ZapSpacing.md),
                child: Row(children: [
                  Container(width: 10, height: 10,
                      decoration: BoxDecoration(
                          color: item.color, shape: BoxShape.circle)),
                  const SizedBox(width: ZapSpacing.md),
                  Expanded(child: Text(item.category, style: const TextStyle(
                      color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
                  Icon(isExp ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                      color: const Color(0xFF4B5563), size: 14),
                ])),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: isExp ? Padding(
                  padding: const EdgeInsets.fromLTRB(
                      ZapSpacing.md, 0, ZapSpacing.md, ZapSpacing.md),
                  child: Container(
                    padding: const EdgeInsets.all(ZapSpacing.sm),
                    decoration: BoxDecoration(
                        color: const Color(0xFF111111),
                        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                        border: Border.all(color: const Color(0xFF2A2A2A))),
                    child: Column(children: [
                      _certRow('Reason',       item.reason),
                      _certRow('Legal basis',  item.basis),
                      _certRow('Retained for', item.retainedFor),
                    ])),
                ) : const SizedBox.shrink(),
              ),
            ]),
          ),
        );
      }),

      const SizedBox(height: ZapSpacing.xl),

      // ── Block complete ─────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        decoration: BoxDecoration(
            color: const Color(0xFF6B7280).withOpacity(0.07),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: const Color(0xFF6B7280).withOpacity(0.35))),
        child: Column(children: [
          const Text('🗑️', style: TextStyle(fontSize: 36)),
          const SizedBox(height: ZapSpacing.sm),
          const Text('Days 169-171 Complete',
              style: TextStyle(color: Colors.white, fontSize: 14,
                  fontWeight: FontWeight.w800), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Wrap(spacing: ZapSpacing.sm, runSpacing: ZapSpacing.sm, children: const [
            _Chip('Request flow ✅',    Color(0xFF8B5CF6)),
            _Chip('Grace period UI ✅', Color(0xFFF59E0B)),
            _Chip('Day-30 walkthrough ✅', Color(0xFFEF4444)),
            _Chip('Wipe animation ✅',  Color(0xFFF59E0B)),
            _Chip('Wiped state ✅',     Color(0xFF6B7280)),
            _Chip('5 API endpoints ✅', Color(0xFF3B82F6)),
          ]),
          const SizedBox(height: ZapSpacing.md),
          const Text('Day 172 → Edge cases: active SOS block, '
              'evidence hold, DPDP 30-day retention, linked devices.',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 11),
              textAlign: TextAlign.center),
        ]),
      ),
    ]);
  }

  static Widget _certRow(String k, String v) => Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 110, child: Text(k, style: const TextStyle(
            color: Color(0xFF6B7280), fontSize: 10))),
        Expanded(child: Text(v, style: const TextStyle(
            color: Color(0xFFD1D5DB), fontSize: 10,
            fontFamily: 'monospace', height: 1.4))),
      ]));
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
            fontSize: 13, fontWeight: FontWeight.w700)))));

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
