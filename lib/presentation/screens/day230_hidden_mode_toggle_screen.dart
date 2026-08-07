/// Day 230 — Hidden Mode Toggle (Aggressive Concealment)
///
/// Section B (Days 221-240): settings for stealth / LP24 prep — minimize
/// notifications, generic recents title, dim launcher label, stealth alerts.
/// Persisted in Hive box `hidden_mode_prefs` (mock Riverpod state today).
///
/// Tag: 🟢 FRONTEND-ONLY — OS limits apply; some toggles are best-effort.
///
/// Route: [AppRoutes.hiddenModeToggle] → `/hidden-mode-toggle`
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

// ── Hive model ────────────────────────────────────────────────────────────────
const _kHiveBox = 'hidden_mode_prefs';

class HiddenModePrefs {
  const HiddenModePrefs({
    this.enabled = false,
    this.minimizeNotifications = false,
    this.genericRecentsTitle = false,
    this.dimLauncherLabel = false,
    this.stealthLockScreenAlerts = false,
  });

  final bool enabled;
  final bool minimizeNotifications;
  final bool genericRecentsTitle;
  final bool dimLauncherLabel;
  final bool stealthLockScreenAlerts;

  int get activeSubCount => [
        minimizeNotifications,
        genericRecentsTitle,
        dimLauncherLabel,
        stealthLockScreenAlerts,
      ].where((v) => v).length;

  HiddenModePrefs copyWith({
    bool? enabled,
    bool? minimizeNotifications,
    bool? genericRecentsTitle,
    bool? dimLauncherLabel,
    bool? stealthLockScreenAlerts,
  }) {
    return HiddenModePrefs(
      enabled: enabled ?? this.enabled,
      minimizeNotifications:
          minimizeNotifications ?? this.minimizeNotifications,
      genericRecentsTitle: genericRecentsTitle ?? this.genericRecentsTitle,
      dimLauncherLabel: dimLauncherLabel ?? this.dimLauncherLabel,
      stealthLockScreenAlerts:
          stealthLockScreenAlerts ?? this.stealthLockScreenAlerts,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'minimize_notifications': minimizeNotifications,
        'generic_recents_title': genericRecentsTitle,
        'dim_launcher_label': dimLauncherLabel,
        'stealth_lock_screen_alerts': stealthLockScreenAlerts,
        'updated_at': DateTime.now().toIso8601String(),
      };

  factory HiddenModePrefs.fromJson(Map<String, dynamic> json) {
    return HiddenModePrefs(
      enabled: json['enabled'] as bool? ?? false,
      minimizeNotifications: json['minimize_notifications'] as bool? ?? false,
      genericRecentsTitle: json['generic_recents_title'] as bool? ?? false,
      dimLauncherLabel: json['dim_launcher_label'] as bool? ?? false,
      stealthLockScreenAlerts:
          json['stealth_lock_screen_alerts'] as bool? ?? false,
    );
  }
}

const _kDefaultPrefs = HiddenModePrefs();

const _kHiveSnippet = '''// Hive box: hidden_mode_prefs
await Hive.openBox<Map>('hidden_mode_prefs', encryptionCipher: cipher);

Future<void> saveHiddenModePrefs(HiddenModePrefs prefs) async {
  final box = Hive.box<Map>('hidden_mode_prefs');
  await box.put('current', prefs.toJson());
}

HiddenModePrefs loadHiddenModePrefs() {
  final box = Hive.box<Map>('hidden_mode_prefs');
  final raw = box.get('current');
  if (raw == null) return const HiddenModePrefs();
  return HiddenModePrefs.fromJson(Map<String, dynamic>.from(raw));
}''';

class _HiddenToggle {
  final String key;
  final String title;
  final String subtitle;
  final String tradeoff;
  final IconData icon;

  const _HiddenToggle({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.tradeoff,
    required this.icon,
  });
}

const _kSubToggles = [
  _HiddenToggle(
    key: 'minimize_notifications',
    title: 'Minimize notifications',
    subtitle:
        'Heads-up suppressed · vibration off · generic channel for non-SOS',
    tradeoff:
        'Contacts may miss delivery receipts. SOS alerts still fire but '
        'use minimal visibility unless stealth lock-screen is off.',
    icon: Icons.notifications_off_outlined,
  ),
  _HiddenToggle(
    key: 'generic_recents_title',
    title: 'Generic app name in recents',
    subtitle: 'App switcher shows "Utilities" instead of ZapSafe',
    tradeoff:
        'Android/iOS may ignore custom titles on some OEM skins. '
        'You must remember which decoy name you chose.',
    icon: Icons.layers_rounded,
  ),
  _HiddenToggle(
    key: 'dim_launcher_label',
    title: 'Dim launcher label',
    subtitle: 'Short neutral label under home-screen icon',
    tradeoff:
        'Launcher may still show full name until Day 231 icon disguise '
        'is applied. Dim label alone does not change the icon.',
    icon: Icons.home_outlined,
  ),
  _HiddenToggle(
    key: 'stealth_lock_screen_alerts',
    title: 'Stealth lock-screen alerts',
    subtitle: 'SOS push text replaced with neutral "System service" copy',
    tradeoff:
        'Critical for concealment but slows contact recognition. '
        'Hardware SOS and volume triggers remain active.',
    icon: Icons.lock_outline_rounded,
  ),
];

// ── Providers ─────────────────────────────────────────────────────────────────
final _d230TabProvider = StateProvider<int>((ref) => 0);
final _d230PrefsProvider =
    StateProvider<HiddenModePrefs>((ref) => _kDefaultPrefs);
final _d230SavedProvider =
    StateProvider<HiddenModePrefs>((ref) => _kDefaultPrefs);
final _d230SavingProvider = StateProvider<bool>((ref) => false);
final _d230ExpandedProvider = StateProvider<String?>((ref) => null);

const _kTabs = ['Toggles', 'Preview', 'Hive Box'];

bool _isDirty(HiddenModePrefs current, HiddenModePrefs saved) =>
    jsonEncode(current.toJson()) != jsonEncode(saved.toJson());

bool _subEnabled(HiddenModePrefs prefs, String key) => switch (key) {
      'minimize_notifications' => prefs.minimizeNotifications,
      'generic_recents_title' => prefs.genericRecentsTitle,
      'dim_launcher_label' => prefs.dimLauncherLabel,
      'stealth_lock_screen_alerts' => prefs.stealthLockScreenAlerts,
      _ => false,
    };

HiddenModePrefs _setSub(HiddenModePrefs prefs, String key, bool value) =>
    switch (key) {
      'minimize_notifications' =>
        prefs.copyWith(minimizeNotifications: value),
      'generic_recents_title' => prefs.copyWith(genericRecentsTitle: value),
      'dim_launcher_label' => prefs.copyWith(dimLauncherLabel: value),
      'stealth_lock_screen_alerts' =>
        prefs.copyWith(stealthLockScreenAlerts: value),
      _ => prefs,
    };

Future<void> _mockSave(WidgetRef ref) async {
  ref.read(_d230SavingProvider.notifier).state = true;
  await Future<void>.delayed(const Duration(milliseconds: 700));
  final prefs = ref.read(_d230PrefsProvider);
  ref.read(_d230SavedProvider.notifier).state = prefs;
  ref.read(_d230SavingProvider.notifier).state = false;
}

// ── Screen ────────────────────────────────────────────────────────────────────
class Day230HiddenModeToggleScreen extends ConsumerWidget {
  const Day230HiddenModeToggleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d230TabProvider);
    final prefs = ref.watch(_d230PrefsProvider);
    final saved = ref.watch(_d230SavedProvider);
    final dirty = _isDirty(prefs, saved);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 230 · Hidden Mode'),
        actions: [
          if (dirty)
            Padding(
              padding: const EdgeInsets.only(right: ZapSpacing.sm),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: ZapColors.warning.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                    border:
                        Border.all(color: ZapColors.warning.withOpacity(0.4)),
                  ),
                  child: const Text(
                    'UNSAVED',
                    style: TextStyle(
                      color: ZapColors.warning,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: prefs.enabled
                      ? ZapColors.danger.withOpacity(0.12)
                      : ZapColors.textMuted.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: prefs.enabled
                        ? ZapColors.danger.withOpacity(0.4)
                        : ZapColors.border,
                  ),
                ),
                child: Text(
                  prefs.enabled ? 'HIDDEN ON' : 'STANDARD',
                  style: TextStyle(
                    color: prefs.enabled ? ZapColors.danger : ZapColors.textMuted,
                    fontSize: 10,
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
          _TabBar(
            tab: tab,
            onSelect: (i) => ref.read(_d230TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (tab) {
              0 => const _TogglesTab(),
              1 => const _PreviewTab(),
              _ => const _HiveBoxTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Toggles ────────────────────────────────────────────────────────────
class _TogglesTab extends ConsumerWidget {
  const _TogglesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(_d230PrefsProvider);
    final saved = ref.watch(_d230SavedProvider);
    final saving = ref.watch(_d230SavingProvider);
    final expanded = ref.watch(_d230ExpandedProvider);
    final dirty = _isDirty(prefs, saved);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: ZapColors.safe.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: ZapColors.safe.withOpacity(0.35)),
          ),
          child: const Text(
            '🟢 FRONTEND-ONLY · Section B Day 10/20 · LP24 stealth prep · Hive hidden_mode_prefs',
            style: TextStyle(color: ZapColors.safe, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.warning.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.warning.withOpacity(0.45)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: ZapColors.warning, size: 20),
                  SizedBox(width: ZapSpacing.sm),
                  Text(
                    'Tradeoffs — read before enabling',
                    style: TextStyle(
                      color: ZapColors.warning,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              SizedBox(height: ZapSpacing.sm),
              Text(
                'Hidden Mode reduces visibility of ZapSafe on your device. '
                'SOS still works via hardware triggers, but contacts may '
                'receive slower acknowledgements and neutral notification text. '
                'Not a substitute for police dispatch — use when concealment '
                'outweighs discoverability.',
                style: TextStyle(color: ZapColors.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        _MasterToggleCard(
          enabled: prefs.enabled,
          subCount: prefs.activeSubCount,
          onChanged: (v) {
            ref.read(_d230PrefsProvider.notifier).update(
                  (p) => p.copyWith(
                    enabled: v,
                    minimizeNotifications: v ? p.minimizeNotifications : false,
                    genericRecentsTitle: v ? p.genericRecentsTitle : false,
                    dimLauncherLabel: v ? p.dimLauncherLabel : false,
                    stealthLockScreenAlerts:
                        v ? p.stealthLockScreenAlerts : false,
                  ),
                );
          },
        ),
        const SizedBox(height: ZapSpacing.md),
        ..._kSubToggles.map((t) {
          final on = _subEnabled(prefs, t.key);
          final isExp = expanded == t.key;
          return Container(
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            decoration: BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: on && prefs.enabled
                    ? ZapColors.danger.withOpacity(0.35)
                    : ZapColors.border,
              ),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  value: on && prefs.enabled,
                  onChanged: !prefs.enabled
                      ? null
                      : (v) => ref.read(_d230PrefsProvider.notifier).update(
                            (p) => _setSub(p, t.key, v),
                          ),
                  activeColor: ZapColors.danger,
                  secondary: Icon(t.icon, color: ZapColors.textSecondary),
                  title: Text(
                    t.title,
                    style: const TextStyle(
                      color: ZapColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  subtitle: Text(
                    t.subtitle,
                    style: const TextStyle(
                      color: ZapColors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => ref
                      .read(_d230ExpandedProvider.notifier)
                      .state = isExp ? null : t.key,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(
                      children: [
                        Text(
                          isExp ? 'Hide tradeoff' : 'Why this matters',
                          style: const TextStyle(
                            color: ZapColors.info,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Icon(
                          isExp
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: ZapColors.info,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
                if (isExp)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Text(
                      t.tradeoff,
                      style: const TextStyle(
                        color: ZapColors.textSecondary,
                        fontSize: 10,
                        height: 1.4,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
        const SizedBox(height: ZapSpacing.md),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: !dirty || saving
                    ? null
                    : () {
                        ref.read(_d230PrefsProvider.notifier).state = saved;
                      },
                child: const Text('Discard'),
              ),
            ),
            const SizedBox(width: ZapSpacing.sm),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: !dirty || saving
                    ? null
                    : () async {
                        await _mockSave(ref);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Saved to Hive hidden_mode_prefs',
                              ),
                            ),
                          );
                        }
                      },
                icon: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded, size: 18),
                label: Text(saving ? 'Saving…' : 'Save to Hive'),
                style: FilledButton.styleFrom(
                  backgroundColor: ZapColors.safe,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.sm),
        Wrap(
          spacing: 8,
          children: [
            ActionChip(
              label: const Text('Day 229 regression'),
              onPressed: () => context.push(AppRoutes.featureRegressionRunner),
            ),
            ActionChip(
              label: const Text('Day 231 Icon disguise'),
              onPressed: () => context.push(AppRoutes.stealthIconDisguise),
            ),
            ActionChip(
              label: const Text('Enable all subs'),
              onPressed: !prefs.enabled
                  ? null
                  : () {
                      ref.read(_d230PrefsProvider.notifier).state =
                          prefs.copyWith(
                        minimizeNotifications: true,
                        genericRecentsTitle: true,
                        dimLauncherLabel: true,
                        stealthLockScreenAlerts: true,
                      );
                    },
            ),
          ],
        ),
      ],
    );
  }
}

class _MasterToggleCard extends StatelessWidget {
  final bool enabled;
  final int subCount;
  final ValueChanged<bool> onChanged;

  const _MasterToggleCard({
    required this.enabled,
    required this.subCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: enabled
            ? ZapColors.danger.withOpacity(0.08)
            : ZapColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: enabled
              ? ZapColors.danger.withOpacity(0.45)
              : ZapColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.visibility_off_rounded,
            color: enabled ? ZapColors.danger : ZapColors.textMuted,
            size: 28,
          ),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hidden Mode',
                  style: TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                Text(
                  enabled
                      ? 'Active · $subCount/4 sub-toggles on'
                      : 'Off — standard ZapSafe visibility',
                  style: const TextStyle(
                    color: ZapColors.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            onChanged: onChanged,
            activeColor: ZapColors.danger,
          ),
        ],
      ),
    );
  }
}

// ── Tab 1: Preview ────────────────────────────────────────────────────────────
class _PreviewTab extends ConsumerWidget {
  const _PreviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(_d230PrefsProvider);

    final recentsName = prefs.enabled && prefs.genericRecentsTitle
        ? 'Utilities'
        : 'ZapSafe';
    final launcherLabel = prefs.enabled && prefs.dimLauncherLabel
        ? 'Tools'
        : 'ZapSafe';
    final notifTitle = prefs.enabled && prefs.stealthLockScreenAlerts
        ? 'System service'
        : 'SOS ALERT — Priya needs help';
    final notifBody = prefs.enabled && prefs.stealthLockScreenAlerts
        ? 'Background task requires attention'
        : 'Tap to view location · Bandra West';
    final showHeadsUp = !(prefs.enabled && prefs.minimizeNotifications);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text(
          'Live concealment preview',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: ZapSpacing.xs),
        Text(
          prefs.enabled
              ? 'Mock OS surfaces with Hidden Mode ${prefs.activeSubCount}/4 active'
              : 'Enable Hidden Mode on Toggles tab to preview',
          style: const TextStyle(color: ZapColors.textMuted, fontSize: 11),
        ),
        const SizedBox(height: ZapSpacing.lg),
        _PreviewPanel(
          title: 'App switcher / recents',
          child: Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2332),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: ZapColors.danger.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.bolt_rounded, color: Colors.white),
                ),
                const SizedBox(width: ZapSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recentsName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      prefs.genericRecentsTitle && prefs.enabled
                          ? 'generic_recents_title = true'
                          : 'Standard branding',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        _PreviewPanel(
          title: 'Home screen launcher',
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: ZapColors.danger,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.bolt_rounded, color: Colors.white),
              ),
              const SizedBox(height: 6),
              Text(
                launcherLabel,
                style: TextStyle(
                  color: prefs.dimLauncherLabel && prefs.enabled
                      ? ZapColors.textMuted
                      : ZapColors.textPrimary,
                  fontSize: prefs.dimLauncherLabel && prefs.enabled ? 9 : 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        _PreviewPanel(
          title: 'Lock-screen notification',
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.bgElevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ZapColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showHeadsUp)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: ZapColors.info.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Heads-up visible',
                      style: TextStyle(color: ZapColors.info, fontSize: 9),
                    ),
                  )
                else
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: ZapColors.textMuted.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Minimized — status bar only',
                      style: TextStyle(
                        color: ZapColors.textMuted,
                        fontSize: 9,
                      ),
                    ),
                  ),
                Text(
                  notifTitle,
                  style: const TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: ZapSpacing.xs),
                Text(
                  notifBody,
                  style: const TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
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
            'Tomorrow: Day 240 — Section B milestone.',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _PreviewPanel extends StatelessWidget {
  final String title;
  final Widget child;

  const _PreviewPanel({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: ZapSpacing.md),
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ZapColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: ZapColors.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: ZapSpacing.md),
          Center(child: child),
        ],
      ),
    );
  }
}

// ── Tab 2: Hive box ───────────────────────────────────────────────────────────
class _HiveBoxTab extends ConsumerWidget {
  const _HiveBoxTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(_d230SavedProvider);
    final json = const JsonEncoder.withIndent('  ').convert(prefs.toJson());

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: ZapColors.warning.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: ZapColors.warning.withOpacity(0.35)),
          ),
          child: const Text(
            'Hive box · $_kHiveBox · encrypted with app cipher (Day 187)',
            style: TextStyle(color: ZapColors.warning, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Saved preferences (last write)',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w700,
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
            json,
            style: const TextStyle(
              color: ZapColors.textSecondary,
              fontFamily: 'monospace',
              fontSize: 10,
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Storage implementation',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w700,
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
          child: const SelectableText(
            _kHiveSnippet,
            style: TextStyle(
              color: ZapColors.textSecondary,
              fontFamily: 'monospace',
              fontSize: 10,
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        FilledButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: json));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Copied saved JSON')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text('Copy saved JSON'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 75),
            backgroundColor: ZapColors.info,
          ),
        ),
      ],
    );
  }
}

class _TabBar extends StatelessWidget {
  final int tab;
  final ValueChanged<int> onSelect;

  const _TabBar({required this.tab, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ZapColors.bgCard,
      child: Row(
        children: List.generate(_kTabs.length, (i) {
          final selected = tab == i;
          return Expanded(
            child: Semantics(
              label: '${_kTabs[i]} tab',
              button: true,
              selected: selected,
              child: InkWell(
                onTap: () => onSelect(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: ZapSpacing.md),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: selected ? ZapColors.info : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    _kTabs[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected
                          ? ZapColors.textPrimary
                          : ZapColors.textSecondary,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 10,
                    ),
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
