/// Day 255 — Child Mode Admin Lock
///
/// Section C (Days 241-260): parent sets admin PIN — child profile cannot
/// cancel SOS without the family admin PIN (extends Family Profiles #18).
///
/// Tag: 🟢 FRONTEND-ONLY · mock PIN gate · child SOS cancel demo.
///
/// Route: [AppRoutes.childModeAdmin] → `/child-mode-admin`
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const _kAccent = Color(0xFF0D9488);
const _kChildColor = Color(0xFF10B981);
const _kTabs = ['Setup', 'Demo', 'Info'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');
const _kPinLength = 4;
const _kDemoAdminPin = '2580';

const _kChildProfile = _ChildProfile(
  id: 'fam_child_006',
  name: 'Arjun Mehta',
  age: 12,
  device: 'Samsung Tab A8',
  relation: 'Son',
);

const _kRestrictions = [
  _ChildRestriction(
    icon: Icons.emergency_rounded,
    title: 'SOS cancel blocked',
    detail: 'Child cannot end an active SOS without admin PIN.',
  ),
  _ChildRestriction(
    icon: Icons.contacts_rounded,
    title: 'Contacts read-only',
    detail: 'Emergency contact list managed by family admin only.',
  ),
  _ChildRestriction(
    icon: Icons.settings_rounded,
    title: 'Settings locked',
    detail: 'Cannot disable location, notifications, or child mode.',
  ),
  _ChildRestriction(
    icon: Icons.logout_rounded,
    title: 'Sign-out blocked',
    detail: 'Child profile stays signed in under admin supervision.',
  ),
];

enum _DemoPhase { idle, sosActive, pinRequired, cancelled }

enum _PinSetupStep { enter, confirm }

// ── Models ────────────────────────────────────────────────────────────────────
class _ChildProfile {
  const _ChildProfile({
    required this.id,
    required this.name,
    required this.age,
    required this.device,
    required this.relation,
  });

  final String id;
  final String name;
  final int age;
  final String device;
  final String relation;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'age': age,
        'device': device,
        'relation': relation,
        'child_profile': true,
      };
}

class _ChildRestriction {
  const _ChildRestriction({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;
}

// ── Providers ─────────────────────────────────────────────────────────────────
final _d255TabProvider = StateProvider<int>((ref) => 0);
final _d255LockEnabledProvider = StateProvider<bool>((ref) => false);
final _d255PinConfiguredProvider = StateProvider<bool>((ref) => false);
final _d255StoredPinProvider = StateProvider<String?>((ref) => null);
final _d255SetupStepProvider =
    StateProvider<_PinSetupStep>((ref) => _PinSetupStep.enter);
final _d255DraftPinProvider = StateProvider<String>((ref) => '');
final _d255SetupEntryProvider = StateProvider<String>((ref) => '');
final _d255DemoPhaseProvider =
    StateProvider<_DemoPhase>((ref) => _DemoPhase.idle);
final _d255DemoPinEntryProvider = StateProvider<String>((ref) => '');
final _d255PinErrorProvider = StateProvider<String?>((ref) => null);

// ── Screen ────────────────────────────────────────────────────────────────────
class Day255ChildModeAdminScreen extends ConsumerWidget {
  const Day255ChildModeAdminScreen({super.key});

  void _appendSetupDigit(WidgetRef ref, String digit) {
    final entry = ref.read(_d255SetupEntryProvider);
    if (entry.length >= _kPinLength) return;
    ref.read(_d255SetupEntryProvider.notifier).state = entry + digit;
  }

  void _backspaceSetup(WidgetRef ref) {
    final entry = ref.read(_d255SetupEntryProvider);
    if (entry.isEmpty) return;
    ref.read(_d255SetupEntryProvider.notifier).state =
        entry.substring(0, entry.length - 1);
  }

  void _submitSetupPin(WidgetRef ref, BuildContext context) {
    final entry = ref.read(_d255SetupEntryProvider);
    if (entry.length != _kPinLength) {
      ref.read(_d255PinErrorProvider.notifier).state =
          'Enter $_kPinLength digits.';
      return;
    }

    final step = ref.read(_d255SetupStepProvider);
    if (step == _PinSetupStep.enter) {
      ref.read(_d255DraftPinProvider.notifier).state = entry;
      ref.read(_d255SetupStepProvider.notifier).state = _PinSetupStep.confirm;
      ref.read(_d255SetupEntryProvider.notifier).state = '';
      ref.read(_d255PinErrorProvider.notifier).state = null;
      return;
    }

    final draft = ref.read(_d255DraftPinProvider);
    if (entry != draft) {
      ref.read(_d255PinErrorProvider.notifier).state = 'PINs do not match.';
      ref.read(_d255SetupEntryProvider.notifier).state = '';
      HapticFeedback.heavyImpact();
      return;
    }

    ref.read(_d255StoredPinProvider.notifier).state = entry;
    ref.read(_d255PinConfiguredProvider.notifier).state = true;
    ref.read(_d255LockEnabledProvider.notifier).state = true;
    ref.read(_d255SetupStepProvider.notifier).state = _PinSetupStep.enter;
    ref.read(_d255SetupEntryProvider.notifier).state = '';
    ref.read(_d255DraftPinProvider.notifier).state = '';
    ref.read(_d255PinErrorProvider.notifier).state = null;
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Admin PIN saved · child lock enabled.')),
    );
  }

  void _appendDemoDigit(WidgetRef ref, String digit) {
    final entry = ref.read(_d255DemoPinEntryProvider);
    if (entry.length >= _kPinLength) return;
    ref.read(_d255DemoPinEntryProvider.notifier).state = entry + digit;
    if (entry.length + 1 == _kPinLength) {
      _verifyDemoPin(ref, entry + digit);
    }
  }

  void _backspaceDemo(WidgetRef ref) {
    final entry = ref.read(_d255DemoPinEntryProvider);
    if (entry.isEmpty) return;
    ref.read(_d255DemoPinEntryProvider.notifier).state =
        entry.substring(0, entry.length - 1);
    ref.read(_d255PinErrorProvider.notifier).state = null;
  }

  void _verifyDemoPin(WidgetRef ref, String entered) {
    final stored = ref.read(_d255StoredPinProvider);
    final expected = stored ?? _kDemoAdminPin;
    if (entered == expected) {
      ref.read(_d255DemoPhaseProvider.notifier).state = _DemoPhase.cancelled;
      ref.read(_d255DemoPinEntryProvider.notifier).state = '';
      ref.read(_d255PinErrorProvider.notifier).state = null;
      HapticFeedback.mediumImpact();
    } else {
      ref.read(_d255PinErrorProvider.notifier).state = 'Incorrect admin PIN.';
      ref.read(_d255DemoPinEntryProvider.notifier).state = '';
      HapticFeedback.heavyImpact();
    }
  }

  void _startChildSosDemo(WidgetRef ref, BuildContext context) {
    if (!ref.read(_d255LockEnabledProvider)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enable child lock and set admin PIN on Setup tab first.'),
        ),
      );
      ref.read(_d255TabProvider.notifier).state = 0;
      return;
    }
    ref.read(_d255DemoPhaseProvider.notifier).state = _DemoPhase.sosActive;
    ref.read(_d255DemoPinEntryProvider.notifier).state = '';
    ref.read(_d255PinErrorProvider.notifier).state = null;
    ref.read(_d255TabProvider.notifier).state = 1;
    HapticFeedback.heavyImpact();
  }

  void _childCancelAttempt(WidgetRef ref, BuildContext context) {
    ref.read(_d255DemoPhaseProvider.notifier).state = _DemoPhase.pinRequired;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cancel blocked — admin PIN required (child mode).'),
      ),
    );
  }

  void _resetDemo(WidgetRef ref) {
    ref.read(_d255DemoPhaseProvider.notifier).state = _DemoPhase.idle;
    ref.read(_d255DemoPinEntryProvider.notifier).state = '';
    ref.read(_d255PinErrorProvider.notifier).state = null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d255TabProvider);
    final lockEnabled = ref.watch(_d255LockEnabledProvider);
    final demoPhase = ref.watch(_d255DemoPhaseProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 255 · Child Admin Lock'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: lockEnabled
                      ? _kAccent.withOpacity(0.15)
                      : ZapColors.textMuted.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: lockEnabled
                        ? _kAccent.withOpacity(0.45)
                        : ZapColors.border,
                  ),
                ),
                child: Text(
                  lockEnabled ? 'LOCK ON' : 'LOCK OFF',
                  style: TextStyle(
                    color: lockEnabled ? _kAccent : ZapColors.textMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (demoPhase == _DemoPhase.sosActive ||
              demoPhase == _DemoPhase.pinRequired)
            const _ChildSosBanner(),
          _TabBar(
            tab: tab,
            onSelect: (i) => ref.read(_d255TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (tab) {
              0 => _SetupTab(
                  onDigit: (d) => _appendSetupDigit(ref, d),
                  onBackspace: () => _backspaceSetup(ref),
                  onSubmit: () => _submitSetupPin(ref, context),
                  onToggleLock: (v) =>
                      ref.read(_d255LockEnabledProvider.notifier).state = v,
                ),
              1 => _DemoTab(
                  onStartSos: () => _startChildSosDemo(ref, context),
                  onChildCancel: () => _childCancelAttempt(ref, context),
                  onDigit: (d) => _appendDemoDigit(ref, d),
                  onBackspace: () => _backspaceDemo(ref),
                  onReset: () => _resetDemo(ref),
                ),
              _ => const _InfoTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Banner ────────────────────────────────────────────────────────────────────
class _ChildSosBanner extends StatelessWidget {
  const _ChildSosBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: ZapSpacing.lg,
        vertical: ZapSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: ZapColors.danger.withOpacity(0.12),
        border: Border(
          bottom: BorderSide(color: ZapColors.danger.withOpacity(0.4)),
        ),
      ),
      child: const Row(
        children: [
          Icon(Icons.child_care_rounded, color: ZapColors.danger, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Child SOS active · cancel requires family admin PIN',
              style: TextStyle(
                color: ZapColors.danger,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Setup ──────────────────────────────────────────────────────────────
class _SetupTab extends ConsumerWidget {
  const _SetupTab({
    required this.onDigit,
    required this.onBackspace,
    required this.onSubmit,
    required this.onToggleLock,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onSubmit;
  final ValueChanged<bool> onToggleLock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lockEnabled = ref.watch(_d255LockEnabledProvider);
    final pinConfigured = ref.watch(_d255PinConfiguredProvider);
    final step = ref.watch(_d255SetupStepProvider);
    final entry = ref.watch(_d255SetupEntryProvider);
    final error = ref.watch(_d255PinErrorProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _kChildColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _kChildColor.withOpacity(0.35)),
          ),
          child: const Text(
            '🟢 FRONTEND-ONLY · Section C Day 15/20 · Family Profiles #18',
            style: TextStyle(color: _kChildColor, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: _kChildColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kChildColor.withOpacity(0.35)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: _kChildColor.withOpacity(0.2),
                child: const Icon(Icons.child_care_rounded, color: _kChildColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _kChildProfile.name,
                      style: const TextStyle(
                        color: ZapColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${_kChildProfile.relation} · age ${_kChildProfile.age} · '
                      '${_kChildProfile.device}',
                      style: const TextStyle(
                        color: ZapColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Enable child admin lock',
            style: TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          subtitle: const Text(
            'When on, child cannot cancel SOS without admin PIN.',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 11),
          ),
          value: lockEnabled,
          activeColor: _kAccent,
          onChanged: pinConfigured ? onToggleLock : null,
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Restrictions applied',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        ..._kRestrictions.map(
          (r) => _RestrictionTile(restriction: r),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Text(
          pinConfigured
              ? step == _PinSetupStep.enter
                  ? 'Change admin PIN · enter new PIN'
                  : 'Confirm new admin PIN'
              : step == _PinSetupStep.enter
                  ? 'Set family admin PIN'
                  : 'Confirm admin PIN',
          style: const TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        _PinDots(filled: entry.length, length: _kPinLength),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(
            error,
            style: const TextStyle(color: ZapColors.danger, fontSize: 11),
          ),
        ],
        const SizedBox(height: ZapSpacing.lg),
        _PinPad(
          onDigit: onDigit,
          onBackspace: onBackspace,
          onSubmit: entry.length == _kPinLength ? onSubmit : null,
        ),
        if (pinConfigured) ...[
          const SizedBox(height: ZapSpacing.md),
          Text(
            'Demo tab uses PIN ending in ··80 (mock)',
            style: TextStyle(
              color: ZapColors.textMuted.withOpacity(0.8),
              fontSize: 10,
            ),
          ),
        ],
      ],
    );
  }
}

// ── Tab 1: Demo ───────────────────────────────────────────────────────────────
class _DemoTab extends ConsumerWidget {
  const _DemoTab({
    required this.onStartSos,
    required this.onChildCancel,
    required this.onDigit,
    required this.onBackspace,
    required this.onReset,
  });

  final VoidCallback onStartSos;
  final VoidCallback onChildCancel;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = ref.watch(_d255DemoPhaseProvider);
    final pinEntry = ref.watch(_d255DemoPinEntryProvider);
    final error = ref.watch(_d255PinErrorProvider);
    final lockEnabled = ref.watch(_d255LockEnabledProvider);

    if (phase == _DemoPhase.idle) {
      return ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          Icon(
            Icons.smartphone_rounded,
            size: 64,
            color: ZapColors.textMuted.withOpacity(0.35),
          ),
          const SizedBox(height: ZapSpacing.lg),
          const Text(
            'Child device demo',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          Text(
            lockEnabled
                ? 'Simulate ${_kChildProfile.name}\'s device triggering SOS, '
                    'then try to cancel as the child.'
                : 'Complete Setup tab first — set admin PIN and enable lock.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ZapColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: ZapSpacing.lg),
          FilledButton.icon(
            onPressed: lockEnabled ? onStartSos : null,
            icon: const Icon(Icons.emergency_rounded),
            label: const Text('Simulate child SOS'),
            style: FilledButton.styleFrom(
              backgroundColor: ZapColors.danger,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      );
    }

    if (phase == _DemoPhase.cancelled) {
      return ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          Icon(
            Icons.check_circle_rounded,
            size: 72,
            color: ZapColors.safe.withOpacity(0.85),
          ),
          const SizedBox(height: ZapSpacing.lg),
          const Text(
            'SOS cancelled with admin PIN',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'Child cancel alone would have been blocked. Parent PIN verified.',
            textAlign: TextAlign.center,
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: ZapSpacing.lg),
          OutlinedButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reset demo'),
          ),
        ],
      );
    }

    final showPinPad = phase == _DemoPhase.pinRequired;

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.lg),
          decoration: BoxDecoration(
            color: ZapColors.danger.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ZapColors.danger.withOpacity(0.35)),
          ),
          child: Column(
            children: [
              const Icon(Icons.emergency_rounded, color: ZapColors.danger, size: 48),
              const SizedBox(height: 12),
              const Text(
                'SOS ACTIVE',
                style: TextStyle(
                  color: ZapColors.danger,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_kChildProfile.name}\'s device · contacts notified (mock)',
                style: const TextStyle(
                  color: ZapColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: ZapSpacing.lg),
              if (!showPinPad)
                OutlinedButton(
                  onPressed: onChildCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ZapColors.textPrimary,
                  ),
                  child: const Text('Cancel SOS (child tap)'),
                ),
            ],
          ),
        ),
        if (showPinPad) ...[
          const SizedBox(height: ZapSpacing.lg),
          const Text(
            'Enter family admin PIN',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: ZapSpacing.md),
          _PinDots(filled: pinEntry.length, length: _kPinLength),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: ZapColors.danger, fontSize: 11),
            ),
          ],
          const SizedBox(height: ZapSpacing.lg),
          _PinPad(
            onDigit: onDigit,
            onBackspace: onBackspace,
          ),
        ],
        const SizedBox(height: ZapSpacing.lg),
        OutlinedButton.icon(
          onPressed: onReset,
          icon: const Icon(Icons.stop_circle_outlined),
          label: const Text('End demo'),
        ),
      ],
    );
  }
}

// ── Tab 2: Info ───────────────────────────────────────────────────────────────
class _InfoTab extends ConsumerWidget {
  const _InfoTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lockEnabled = ref.watch(_d255LockEnabledProvider);
    final pinConfigured = ref.watch(_d255PinConfiguredProvider);

    final payload = {
      'child_profile': _kChildProfile.toJson(),
      'admin_lock_enabled': lockEnabled,
      'admin_pin_configured': pinConfigured,
      'restrictions': _kRestrictions
          .map((r) => {'title': r.title, 'detail': r.detail})
          .toList(),
      'sos_cancel_policy': 'admin_pin_required',
    };

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text(
          'Child Mode Admin Lock',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          'Extends Family Profiles (#18): parents set a separate admin PIN. '
          'Child profiles can trigger SOS but cannot cancel it or change '
          'safety settings without the parent PIN — prevents accidental or '
          'coerced cancellation.',
          style: TextStyle(
            color: ZapColors.textSecondary,
            fontSize: 12,
            height: 1.45,
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'PUT /api/v1/family/child-mode/config/ (mock)',
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
              const SnackBar(content: Text('Child mode config JSON copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy config JSON'),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const _PolicyRow(
          icon: Icons.link_rounded,
          title: 'Related screens',
          subtitle:
              'Day 253 dashboard shows child profile badge · Day 254 history '
              'logs admin-PIN cancels · Day 76 duress PIN is separate.',
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
            'Next: Day 365 — Global Launch Milestone '
            '(Phase 2 finale · worldwide rollout).',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              label: const Text('Day 256 SOS Widget'),
              onPressed: () => context.push(AppRoutes.homeWidgetSos),
            ),
            ActionChip(
              label: const Text('Day 254 SOS History'),
              onPressed: () => context.push(AppRoutes.familySosHistory),
            ),
            ActionChip(
              label: const Text('Day 253 Family Dashboard'),
              onPressed: () => context.push(AppRoutes.familyAlertsDashboard),
            ),
            ActionChip(
              label: const Text('Day 76 SOS Active'),
              onPressed: () => context.push(AppRoutes.sosActive),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────
class _RestrictionTile extends StatelessWidget {
  const _RestrictionTile({required this.restriction});

  final _ChildRestriction restriction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(restriction.icon, color: _kAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  restriction.title,
                  style: const TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                Text(
                  restriction.detail,
                  style: const TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 11,
                    height: 1.35,
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

class _PinDots extends StatelessWidget {
  const _PinDots({required this.filled, required this.length});

  final int filled;
  final int length;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (i) {
        final active = i < filled;
        return Container(
          width: 14,
          height: 14,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? _kAccent : Colors.transparent,
            border: Border.all(
              color: active ? _kAccent : ZapColors.textMuted,
              width: 2,
            ),
          ),
        );
      }),
    );
  }
}

class _PinPad extends StatelessWidget {
  const _PinPad({
    required this.onDigit,
    required this.onBackspace,
    this.onSubmit,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫'];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.6,
      ),
      itemCount: keys.length,
      itemBuilder: (context, i) {
        final key = keys[i];
        if (key.isEmpty) {
          return onSubmit != null
              ? FilledButton(
                  onPressed: onSubmit,
                  style: FilledButton.styleFrom(backgroundColor: _kAccent),
                  child: const Text('OK'),
                )
              : const SizedBox.shrink();
        }
        if (key == '⌫') {
          return OutlinedButton(
            onPressed: onBackspace,
            child: const Icon(Icons.backspace_outlined, size: 20),
          );
        }
        return OutlinedButton(
          onPressed: () {
            HapticFeedback.selectionClick();
            onDigit(key);
          },
          child: Text(
            key,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      },
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
    return Row(
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
                      color: selected ? _kAccent : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  _kTabs[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? _kAccent : ZapColors.textMuted,
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
