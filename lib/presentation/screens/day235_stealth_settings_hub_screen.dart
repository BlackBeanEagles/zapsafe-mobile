/// Day 235 — Stealth Settings Hub
///
/// Section B (Days 221-240): consolidates Days 230-234 — status card for
/// hidden mode, icon disguise, decoy shells, and gesture config; quick-test
/// checklist; emergency exit ("Show real app now").
///
/// Tag: 🟢 FRONTEND-ONLY · LP24 stealth command centre.
///
/// Route: [AppRoutes.stealthSettingsHub] → `/stealth-settings-hub`
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

// ── Consolidated stealth snapshot (mock Hive read) ──────────────────────────
class StealthStackSnapshot {
  const StealthStackSnapshot({
    this.hiddenModeEnabled = false,
    this.hiddenSubCount = 0,
    this.iconDisguise = 'ZapSafe (default)',
    this.iconDisguised = false,
    this.activeDecoy = 'None',
    this.gestureSummary =
        'Corner tap · Hold vol-down 2s · 3 shakes / 2500ms @ Medium',
    this.gesturesConfigured = true,
    this.inDecoyShell = false,
  });

  final bool hiddenModeEnabled;
  final int hiddenSubCount;
  final String iconDisguise;
  final bool iconDisguised;
  final String activeDecoy;
  final String gestureSummary;
  final bool gesturesConfigured;
  final bool inDecoyShell;

  int get activeLayerCount => [
        hiddenModeEnabled,
        iconDisguised,
        activeDecoy != 'None',
        gesturesConfigured,
      ].where((v) => v).length;

  StealthLevel get level {
    if (inDecoyShell) return StealthLevel.decoyActive;
    if (activeLayerCount >= 3) return StealthLevel.full;
    if (activeLayerCount >= 1) return StealthLevel.partial;
    return StealthLevel.off;
  }

  StealthStackSnapshot copyWith({
    bool? hiddenModeEnabled,
    int? hiddenSubCount,
    String? iconDisguise,
    bool? iconDisguised,
    String? activeDecoy,
    String? gestureSummary,
    bool? gesturesConfigured,
    bool? inDecoyShell,
  }) {
    return StealthStackSnapshot(
      hiddenModeEnabled: hiddenModeEnabled ?? this.hiddenModeEnabled,
      hiddenSubCount: hiddenSubCount ?? this.hiddenSubCount,
      iconDisguise: iconDisguise ?? this.iconDisguise,
      iconDisguised: iconDisguised ?? this.iconDisguised,
      activeDecoy: activeDecoy ?? this.activeDecoy,
      gestureSummary: gestureSummary ?? this.gestureSummary,
      gesturesConfigured: gesturesConfigured ?? this.gesturesConfigured,
      inDecoyShell: inDecoyShell ?? this.inDecoyShell,
    );
  }

  Map<String, dynamic> toJson() => {
        'hidden_mode_enabled': hiddenModeEnabled,
        'hidden_sub_count': hiddenSubCount,
        'icon_disguise': iconDisguise,
        'icon_disguised': iconDisguised,
        'active_decoy': activeDecoy,
        'gesture_summary': gestureSummary,
        'gestures_configured': gesturesConfigured,
        'in_decoy_shell': inDecoyShell,
        'active_layers': activeLayerCount,
        'stealth_level': level.name,
      };
}

enum StealthLevel { off, partial, full, decoyActive }

extension StealthLevelX on StealthLevel {
  String get label => switch (this) {
        StealthLevel.off => 'STANDARD',
        StealthLevel.partial => 'PARTIAL STEALTH',
        StealthLevel.full => 'FULL STEALTH',
        StealthLevel.decoyActive => 'DECOY SHELL ACTIVE',
      };

  Color get color => switch (this) {
        StealthLevel.off => ZapColors.textMuted,
        StealthLevel.partial => ZapColors.warning,
        StealthLevel.full => ZapColors.safe,
        StealthLevel.decoyActive => ZapColors.danger,
      };

  String get detail => switch (this) {
        StealthLevel.off =>
          'No concealment layers active. Configure Days 230-234 below.',
        StealthLevel.partial =>
          'Some stealth layers on. Review gaps before relying on concealment.',
        StealthLevel.full =>
          'Hidden mode, disguise, decoy, and gestures configured.',
        StealthLevel.decoyActive =>
          'User-facing shell is a decoy. Use emergency exit to restore ZapSafe.',
      };
}

class _QuickTestItem {
  final String id;
  final String title;
  final String subtitle;
  final String route;
  final IconData icon;
  final Color color;

  const _QuickTestItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.route,
    required this.icon,
    required this.color,
  });
}

const _kQuickTests = [
  _QuickTestItem(
    id: 'hidden_mode',
    title: 'Day 230 · Hidden mode toggles',
    subtitle: 'Verify master toggle + 4 sub-concealment options',
    route: AppRoutes.hiddenModeToggle,
    icon: Icons.visibility_off_rounded,
    color: Color(0xFF8B5CF6),
  ),
  _QuickTestItem(
    id: 'icon_disguise',
    title: 'Day 231 · Icon disguise',
    subtitle: 'Launcher shows Calculator / Weather / Notes alias',
    route: AppRoutes.stealthIconDisguise,
    icon: Icons.app_settings_alt_rounded,
    color: Color(0xFF6B7280),
  ),
  _QuickTestItem(
    id: 'calc_decoy',
    title: 'Day 232 · Calculator decoy unlock',
    subtitle: 'Secret === then 767 → unlock sheet',
    route: AppRoutes.decoyCalculator,
    icon: Icons.calculate_rounded,
    color: Color(0xFF6B7280),
  ),
  _QuickTestItem(
    id: 'weather_decoy',
    title: 'Day 233 · Weather decoy unlock',
    subtitle: 'Shake ×3 or volume hold → unlock sheet',
    route: AppRoutes.decoyWeather,
    icon: Icons.wb_sunny_rounded,
    color: Color(0xFF3B82F6),
  ),
  _QuickTestItem(
    id: 'gestures',
    title: 'Day 234 · Secret gesture config',
    subtitle: 'Tap pattern · volume combo · shake sensitivity',
    route: AppRoutes.secretGestureConfig,
    icon: Icons.gesture_rounded,
    color: Color(0xFF8B5CF6),
  ),
];

const _kDemoFullStealth = StealthStackSnapshot(
  hiddenModeEnabled: true,
  hiddenSubCount: 3,
  iconDisguise: 'Calculator',
  iconDisguised: true,
  activeDecoy: 'Weather shell',
  gestureSummary:
      'Corner tap · Hold vol-down 2000ms · 3 shakes / 2500ms @ Medium',
  gesturesConfigured: true,
  inDecoyShell: false,
);

const _kDemoDecoyActive = StealthStackSnapshot(
  hiddenModeEnabled: true,
  hiddenSubCount: 4,
  iconDisguise: 'Weather',
  iconDisguised: true,
  activeDecoy: 'Weather shell',
  gestureSummary:
      'Corner tap · Hold vol-down 2000ms · 3 shakes / 2500ms @ Medium',
  gesturesConfigured: true,
  inDecoyShell: true,
);

// ── Providers ─────────────────────────────────────────────────────────────────
final _d235TabProvider = StateProvider<int>((ref) => 0);
final _d235SnapshotProvider =
    StateProvider<StealthStackSnapshot>((ref) => _kDemoFullStealth);
final _d235TestResultsProvider = StateProvider<Map<String, bool>>((ref) => {});
final _d235ExitingProvider = StateProvider<bool>((ref) => false);

const _kExitTargetSnapshot = StealthStackSnapshot(
  hiddenModeEnabled: false,
  iconDisguise: 'ZapSafe (default)',
  activeDecoy: 'None',
  inDecoyShell: false,
);

const _kTabs = ['Status', 'Quick Test', 'Emergency Exit'];

// ── Screen ────────────────────────────────────────────────────────────────────
class Day235StealthSettingsHubScreen extends ConsumerWidget {
  const Day235StealthSettingsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d235TabProvider);
    final snapshot = ref.watch(_d235SnapshotProvider);
    final level = snapshot.level;

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 235 · Stealth Hub'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: ZapSpacing.sm, vertical: ZapSpacing.xs),
                decoration: BoxDecoration(
                  color: level.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: level.color.withOpacity(0.45)),
                ),
                child: Text(
                  level.label,
                  style: TextStyle(
                    color: level.color,
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
          _TabBar(
            tab: tab,
            onSelect: (i) => ref.read(_d235TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (tab) {
              0 => const _StatusTab(),
              1 => const _QuickTestTab(),
              _ => const _EmergencyExitTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Status ─────────────────────────────────────────────────────────────
class _StatusTab extends ConsumerWidget {
  const _StatusTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(_d235SnapshotProvider);
    final level = snapshot.level;

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
            '🟢 FRONTEND-ONLY · Section B Day 15/20 · LP24 command centre · Days 230-234',
            style: TextStyle(color: ZapColors.safe, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        _StatusHeroCard(snapshot: snapshot, level: level),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Stealth stack (Days 230-234)',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        _LayerCard(
          day: '230',
          title: 'Hidden mode',
          status: snapshot.hiddenModeEnabled
              ? 'ON · ${snapshot.hiddenSubCount}/4 subs'
              : 'OFF',
          ok: snapshot.hiddenModeEnabled,
          icon: Icons.visibility_off_rounded,
          color: const Color(0xFF8B5CF6),
          route: AppRoutes.hiddenModeToggle,
        ),
        _LayerCard(
          day: '231',
          title: 'Icon disguise',
          status: snapshot.iconDisguised
              ? snapshot.iconDisguise
              : 'Default ZapSafe icon',
          ok: snapshot.iconDisguised,
          icon: Icons.app_settings_alt_rounded,
          color: const Color(0xFF6B7280),
          route: AppRoutes.stealthIconDisguise,
        ),
        _LayerCard(
          day: '232',
          title: 'Calculator decoy',
          status: snapshot.activeDecoy.contains('Calculator') ||
                  snapshot.iconDisguise == 'Calculator'
              ? 'Ready · === then 767'
              : 'Available (not primary shell)',
          ok: snapshot.activeDecoy.contains('Calculator') ||
              snapshot.iconDisguise == 'Calculator',
          icon: Icons.calculate_rounded,
          color: const Color(0xFF6B7280),
          route: AppRoutes.decoyCalculator,
        ),
        _LayerCard(
          day: '233',
          title: 'Weather decoy',
          status: snapshot.inDecoyShell
              ? 'ACTIVE SHELL'
              : snapshot.activeDecoy.contains('Weather')
                  ? 'Ready · shake / volume'
                  : 'Available',
          ok: snapshot.activeDecoy.contains('Weather') || snapshot.inDecoyShell,
          icon: Icons.wb_sunny_rounded,
          color: const Color(0xFF3B82F6),
          route: AppRoutes.decoyWeather,
        ),
        _LayerCard(
          day: '234',
          title: 'Secret gestures',
          status: snapshot.gesturesConfigured
              ? snapshot.gestureSummary
              : 'Not configured',
          ok: snapshot.gesturesConfigured,
          icon: Icons.gesture_rounded,
          color: const Color(0xFF8B5CF6),
          route: AppRoutes.secretGestureConfig,
        ),
        const SizedBox(height: ZapSpacing.lg),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              label: const Text('Simulate full stealth'),
              onPressed: () => ref.read(_d235SnapshotProvider.notifier).state =
                  _kDemoFullStealth,
            ),
            ActionChip(
              label: const Text('Simulate decoy shell'),
              onPressed: () => ref.read(_d235SnapshotProvider.notifier).state =
                  _kDemoDecoyActive,
            ),
            ActionChip(
              label: const Text('Reset to standard'),
              onPressed: () => ref.read(_d235SnapshotProvider.notifier).state =
                  const StealthStackSnapshot(),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatusHeroCard extends StatelessWidget {
  final StealthStackSnapshot snapshot;
  final StealthLevel level;

  const _StatusHeroCard({required this.snapshot, required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            level.color.withOpacity(0.18),
            ZapColors.bgCard,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: level.color.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_moon_rounded, color: level.color, size: 28),
              const SizedBox(width: ZapSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      level.label,
                      style: TextStyle(
                        color: level.color,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      level.detail,
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
          const SizedBox(height: ZapSpacing.md),
          Row(
            children: [
              _MetricChip(
                label: 'Layers',
                value: '${snapshot.activeLayerCount}/4',
              ),
              const SizedBox(width: ZapSpacing.sm),
              _MetricChip(
                label: 'Decoy',
                value: snapshot.inDecoyShell ? 'LIVE' : 'Idle',
              ),
              const SizedBox(width: ZapSpacing.sm),
              _MetricChip(
                label: 'Icon',
                value: snapshot.iconDisguised ? 'Hidden' : 'Visible',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;

  const _MetricChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ZapColors.bgPrimary.withOpacity(0.6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ZapColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: ZapColors.textMuted, fontSize: 9),
          ),
          Text(
            value,
            style: const TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _LayerCard extends StatelessWidget {
  final String day;
  final String title;
  final String status;
  final bool ok;
  final IconData icon;
  final Color color;
  final String route;

  const _LayerCard({
    required this.day,
    required this.title,
    required this.status,
    required this.ok,
    required this.icon,
    required this.color,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(
          color: ok ? color.withOpacity(0.45) : ZapColors.border,
        ),
      ),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: color.withOpacity(0.15),
          child: Icon(icon, color: color, size: 18),
        ),
        title: Text(
          'Day $day · $title',
          style: const TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        subtitle: Text(
          status,
          style: TextStyle(
            color: ok ? ZapColors.textSecondary : ZapColors.textMuted,
            fontSize: 10,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(
          ok
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          color: ok ? ZapColors.safe : ZapColors.textMuted,
          size: 20,
        ),
        onTap: () => context.push(route),
      ),
    );
  }
}

// ── Tab 1: Quick Test ─────────────────────────────────────────────────────────
class _QuickTestTab extends ConsumerWidget {
  const _QuickTestTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(_d235TestResultsProvider);
    final passed = results.values.where((v) => v).length;
    final total = _kQuickTests.length;

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: ZapColors.border),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 52,
                height: 52,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: total == 0 ? 0 : passed / total,
                      strokeWidth: 5,
                      backgroundColor: ZapColors.border,
                      color: passed == total ? ZapColors.safe : ZapColors.info,
                    ),
                    Text(
                      '$passed/$total',
                      style: const TextStyle(
                        color: ZapColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: ZapSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Stealth regression checklist',
                      style: TextStyle(
                        color: ZapColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      passed == total
                          ? 'All $total layers verified ✅'
                          : 'Open each screen, verify behaviour, mark pass.',
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
        ..._kQuickTests.map(
          (item) => _TestRow(
            item: item,
            passed: results[item.id] ?? false,
            onToggle: (v) {
              ref.read(_d235TestResultsProvider.notifier).update(
                    (m) => {...m, item.id: v},
                  );
            },
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () =>
                    ref.read(_d235TestResultsProvider.notifier).state = {},
                child: const Text('Reset checklist'),
              ),
            ),
            const SizedBox(width: ZapSpacing.sm),
            Expanded(
              child: FilledButton(
                onPressed: () {
                  final all = {
                    for (final t in _kQuickTests) t.id: true,
                  };
                  ref.read(_d235TestResultsProvider.notifier).state = all;
                },
                style: FilledButton.styleFrom(backgroundColor: ZapColors.safe),
                child: const Text('Mark all pass'),
              ),
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.lg),
        FilledButton.icon(
          onPressed: passed == total
              ? () {
                  Clipboard.setData(
                    ClipboardData(
                      text: 'ZapSafe stealth QA — $passed/$total pass\n'
                          '${DateTime.now().toIso8601String()}',
                    ),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied QA report')),
                  );
                }
              : null,
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text('Copy pass report'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            backgroundColor: ZapColors.info,
          ),
        ),
      ],
    );
  }
}

class _TestRow extends StatelessWidget {
  final _QuickTestItem item;
  final bool passed;
  final ValueChanged<bool> onToggle;

  const _TestRow({
    required this.item,
    required this.passed,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(
          color: passed ? ZapColors.safe.withOpacity(0.45) : ZapColors.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(ZapSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(item.icon, color: item.color, size: 18),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    item.title,
                    style: const TextStyle(
                      color: ZapColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
                Switch(
                  value: passed,
                  onChanged: onToggle,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Text(
                item.subtitle,
                style: const TextStyle(
                  color: ZapColors.textMuted,
                  fontSize: 10,
                ),
              ),
            ),
            const SizedBox(height: ZapSpacing.sm),
            Row(
              children: [
                TextButton(
                  onPressed: () => context.push(item.route),
                  child:
                      const Text('Open & test', style: TextStyle(fontSize: 11)),
                ),
                if (passed)
                  const Text(
                    'PASS',
                    style: TextStyle(
                      color: ZapColors.safe,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tab 2: Emergency Exit ─────────────────────────────────────────────────────
class _EmergencyExitTab extends ConsumerWidget {
  const _EmergencyExitTab();

  Future<void> _showRealApp(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ZapColors.bgCard,
        title: const Text(
          'Show real app now?',
          style: TextStyle(color: ZapColors.textPrimary),
        ),
        content: const Text(
          'This will:\n'
          '• Exit any active decoy shell\n'
          '• Restore ZapSafe launcher icon (mock)\n'
          '• Disable hidden-mode concealment (mock)\n'
          '• Navigate to the real home screen\n\n'
          'Hardware SOS and volume SOS triggers remain active.',
          style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: ZapColors.danger),
            child: const Text('Show real app'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    ref.read(_d235ExitingProvider.notifier).state = true;
    await Future<void>.delayed(const Duration(milliseconds: 900));
    ref.read(_d235SnapshotProvider.notifier).state =
        const StealthStackSnapshot();
    ref.read(_d235TestResultsProvider.notifier).state = {};
    ref.read(_d235ExitingProvider.notifier).state = false;

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Stealth disabled · returning to ZapSafe home'),
      ),
    );
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(_d235SnapshotProvider);
    final exiting = ref.watch(_d235ExitingProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.lg),
          decoration: BoxDecoration(
            color: ZapColors.danger.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ZapColors.danger.withOpacity(0.35)),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.emergency_rounded,
                color: ZapColors.danger,
                size: 40,
              ),
              const SizedBox(height: ZapSpacing.sm),
              const Text(
                'Emergency exit',
                style: TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: ZapSpacing.sm),
              const Text(
                'Instantly drop stealth and show the real ZapSafe app. '
                'Use when concealment is no longer safe or you need full UI access.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ZapColors.textSecondary,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: ZapSpacing.lg),
              FilledButton.icon(
                onPressed: exiting ? null : () => _showRealApp(context, ref),
                icon: exiting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.home_rounded, size: 20),
                label: Text(
                  exiting ? 'Restoring…' : 'Show real app now',
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  backgroundColor: ZapColors.danger,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        if (snapshot.inDecoyShell)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(ZapSpacing.sm),
            decoration: BoxDecoration(
              color: ZapColors.warning.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: ZapColors.warning.withOpacity(0.35)),
            ),
            child: const Text(
              'Decoy shell detected — emergency exit will dismiss it first.',
              style: TextStyle(color: ZapColors.warning, fontSize: 11),
            ),
          ),
        const _ExitStep(
          step: '1',
          title: 'Exit decoy shell',
          body: 'Weather/Calculator UI dismissed → ZapSafe chrome.',
        ),
        const _ExitStep(
          step: '2',
          title: 'Restore launcher icon',
          body: 'activity-alias disabled · AppIcon default (mock).',
        ),
        const _ExitStep(
          step: '3',
          title: 'Disable hidden mode',
          body: 'hidden_mode_prefs.enabled = false (mock Hive write).',
        ),
        const _ExitStep(
          step: '4',
          title: 'Navigate home',
          body: 'context.go(AppRoutes.home) — real SOS dashboard.',
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: ZapColors.border),
          ),
          child: SelectableText(
            const JsonEncoder.withIndent('  ').convert(
              _kExitTargetSnapshot.toJson(),
            ),
            style: const TextStyle(
              color: ZapColors.textSecondary,
              fontFamily: 'monospace',
              fontSize: 10,
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.info.withOpacity(0.1),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: ZapColors.info.withOpacity(0.3)),
          ),
          child: const Text(
            'Tomorrow: Day 240 — Section B milestone (catch-up complete).',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _ExitStep extends StatelessWidget {
  final String step;
  final String title;
  final String body;

  const _ExitStep({
    required this.step,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: ZapColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: ZapColors.danger.withOpacity(0.15),
            child: Text(
              step,
              style: const TextStyle(
                color: ZapColors.danger,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: ZapSpacing.md),
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
                const SizedBox(height: 2),
                Text(
                  body,
                  style: const TextStyle(
                    color: ZapColors.textMuted,
                    fontSize: 10,
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
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
