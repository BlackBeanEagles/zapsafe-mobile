/// Day 234 — Secret Gesture Configuration
///
/// Section B (Days 221-240): central picker for decoy unlock gestures —
/// tap pattern, volume combo, shake sensitivity. Persists to Hive
/// `secret_gesture_prefs` (mock Riverpod today). Feeds Days 232-233 decoys.
///
/// Tag: 🟢 FRONTEND-ONLY · LP24 stealth gesture hub.
///
/// Route: [AppRoutes.secretGestureConfig] → `/secret-gesture-config`
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
enum TapPattern {
  none,
  cornerSequence,
  calculator767,
  tripleStatusTap,
}

enum VolumeCombo {
  none,
  holdVolDown2s,
  volDownUpDown,
  bothKeys3s,
}

enum ShakeSensitivity {
  off,
  low,
  medium,
  high,
}

extension TapPatternX on TapPattern {
  String get label => switch (this) {
        TapPattern.none => 'None (disabled)',
        TapPattern.cornerSequence => 'Corner tap sequence',
        TapPattern.calculator767 => 'Calculator: === then 767',
        TapPattern.tripleStatusTap => 'Triple-tap status area',
      };

  String get detail => switch (this) {
        TapPattern.none => 'Decoy unlock via gesture disabled.',
        TapPattern.cornerSequence =>
          'TL → TR → BR → BL on decoy shell within 4s.',
        TapPattern.calculator767 =>
          'Day 232 calc: = ×3 then 7-6-7 (SOS keypad).',
        TapPattern.tripleStatusTap =>
          'Three quick taps top-centre of decoy screen.',
      };

  String get decoyHint => switch (this) {
        TapPattern.calculator767 => 'Calculator decoy',
        TapPattern.cornerSequence => 'Weather / generic decoy',
        TapPattern.tripleStatusTap => 'Any decoy shell',
        TapPattern.none => '—',
      };
}

extension VolumeComboX on VolumeCombo {
  String get label => switch (this) {
        VolumeCombo.none => 'None (disabled)',
        VolumeCombo.holdVolDown2s => 'Hold volume-down 2s',
        VolumeCombo.volDownUpDown => 'Vol down → up → down',
        VolumeCombo.bothKeys3s => 'Both volume keys 3s',
      };

  String get detail => switch (this) {
        VolumeCombo.none => 'No volume unlock combo.',
        VolumeCombo.holdVolDown2s =>
          'Default Day 233 weather sim · hold ≥ 2000 ms.',
        VolumeCombo.volDownUpDown =>
          'Three-step combo within 1500 ms window.',
        VolumeCombo.bothKeys3s =>
          'Simultaneous vol+/- hold · Android only on device.',
      };
}

extension ShakeSensitivityX on ShakeSensitivity {
  String get label => switch (this) {
        ShakeSensitivity.off => 'Off',
        ShakeSensitivity.low => 'Low (hard shake)',
        ShakeSensitivity.medium => 'Medium (default)',
        ShakeSensitivity.high => 'High (light shake)',
      };

  double get threshold => switch (this) {
        ShakeSensitivity.off => 0,
        ShakeSensitivity.low => 18.0,
        ShakeSensitivity.medium => 14.5,
        ShakeSensitivity.high => 11.0,
      };
}

class SecretGesturePrefs {
  const SecretGesturePrefs({
    this.tapPattern = TapPattern.cornerSequence,
    this.volumeCombo = VolumeCombo.holdVolDown2s,
    this.shakeSensitivity = ShakeSensitivity.medium,
    this.shakeCount = 3,
    this.shakeWindowMs = 2500,
    this.volumeHoldMs = 2000,
  });

  final TapPattern tapPattern;
  final VolumeCombo volumeCombo;
  final ShakeSensitivity shakeSensitivity;
  final int shakeCount;
  final int shakeWindowMs;
  final int volumeHoldMs;

  SecretGesturePrefs copyWith({
    TapPattern? tapPattern,
    VolumeCombo? volumeCombo,
    ShakeSensitivity? shakeSensitivity,
    int? shakeCount,
    int? shakeWindowMs,
    int? volumeHoldMs,
  }) {
    return SecretGesturePrefs(
      tapPattern: tapPattern ?? this.tapPattern,
      volumeCombo: volumeCombo ?? this.volumeCombo,
      shakeSensitivity: shakeSensitivity ?? this.shakeSensitivity,
      shakeCount: shakeCount ?? this.shakeCount,
      shakeWindowMs: shakeWindowMs ?? this.shakeWindowMs,
      volumeHoldMs: volumeHoldMs ?? this.volumeHoldMs,
    );
  }

  Map<String, dynamic> toComparableMap() => {
        'tap_pattern': tapPattern.name,
        'volume_combo': volumeCombo.name,
        'shake_sensitivity': shakeSensitivity.name,
        'shake_count': shakeCount,
        'shake_window_ms': shakeWindowMs,
        'volume_hold_ms': volumeHoldMs,
        'shake_threshold': shakeSensitivity.threshold,
      };

  Map<String, dynamic> toJson({DateTime? updatedAt}) => {
        ...toComparableMap(),
        'updated_at': (updatedAt ?? DateTime.now()).toIso8601String(),
      };
}

const _kDefaultPrefs = SecretGesturePrefs();

const _kHiveSnippet = '''// Hive box: secret_gesture_prefs
await Hive.openBox<Map>('secret_gesture_prefs', encryptionCipher: cipher);

Future<void> saveSecretGesturePrefs(SecretGesturePrefs prefs) async {
  final box = Hive.box<Map>('secret_gesture_prefs');
  await box.put('current', prefs.toJson());
}

SecretGesturePrefs loadSecretGesturePrefs() {
  final raw = Hive.box<Map>('secret_gesture_prefs').get('current');
  if (raw == null) return const SecretGesturePrefs();
  return SecretGesturePrefs.fromJson(Map<String, dynamic>.from(raw));
}''';

// ── Providers ─────────────────────────────────────────────────────────────────
final _d234TabProvider = StateProvider<int>((ref) => 0);
final _d234PrefsProvider =
    StateProvider<SecretGesturePrefs>((ref) => _kDefaultPrefs);
final _d234SavedProvider =
    StateProvider<SecretGesturePrefs>((ref) => _kDefaultPrefs);
final _d234SavingProvider = StateProvider<bool>((ref) => false);

const _kTabs = ['Gestures', 'Summary', 'Hive Box'];

bool _isDirty(SecretGesturePrefs a, SecretGesturePrefs b) =>
    jsonEncode(a.toComparableMap()) != jsonEncode(b.toComparableMap());

Future<void> _mockSave(WidgetRef ref) async {
  ref.read(_d234SavingProvider.notifier).state = true;
  await Future<void>.delayed(const Duration(milliseconds: 700));
  final prefs = ref.read(_d234PrefsProvider);
  ref.read(_d234SavedProvider.notifier).state = prefs.copyWith();
  ref.read(_d234SavingProvider.notifier).state = false;
}

String _summaryLine(SecretGesturePrefs prefs) {
  final parts = <String>[];
  if (prefs.tapPattern != TapPattern.none) {
    parts.add(prefs.tapPattern.label);
  }
  if (prefs.volumeCombo != VolumeCombo.none) {
    parts.add(prefs.volumeCombo.label);
  }
  if (prefs.shakeSensitivity != ShakeSensitivity.off) {
    parts.add(
      '${prefs.shakeCount} shakes / ${prefs.shakeWindowMs}ms @ ${prefs.shakeSensitivity.label}',
    );
  }
  return parts.isEmpty ? 'All gestures disabled' : parts.join(' · ');
}

// ── Screen ────────────────────────────────────────────────────────────────────
class Day234SecretGestureConfigScreen extends ConsumerWidget {
  const Day234SecretGestureConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d234TabProvider);
    final prefs = ref.watch(_d234PrefsProvider);
    final saved = ref.watch(_d234SavedProvider);
    final dirty = _isDirty(prefs, saved);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 234 · Secret Gestures'),
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
        ],
      ),
      body: Column(
        children: [
          _TabBar(
            tab: tab,
            onSelect: (i) => ref.read(_d234TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (tab) {
              0 => const _GesturesTab(),
              1 => const _SummaryTab(),
              _ => const _HiveBoxTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Gestures ───────────────────────────────────────────────────────────
class _GesturesTab extends ConsumerWidget {
  const _GesturesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(_d234PrefsProvider);
    final saved = ref.watch(_d234SavedProvider);
    final saving = ref.watch(_d234SavingProvider);
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
            '🟢 FRONTEND-ONLY · Section B Day 14/20 · LP24 gesture hub · feeds decoys 232-233',
            style: TextStyle(color: ZapColors.safe, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const _SectionHeader(
          icon: Icons.touch_app_rounded,
          title: 'Tap pattern',
          color: Color(0xFF3B82F6),
        ),
        ...TapPattern.values.map(
          (p) => _OptionTile(
            selected: prefs.tapPattern == p,
            title: p.label,
            subtitle: p.detail,
            badge: p.decoyHint,
            onTap: () => ref.read(_d234PrefsProvider.notifier).update(
                  (s) => s.copyWith(tapPattern: p),
                ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const _SectionHeader(
          icon: Icons.volume_down_rounded,
          title: 'Volume combo',
          color: Color(0xFF8B5CF6),
        ),
        ...VolumeCombo.values.map(
          (v) => _OptionTile(
            selected: prefs.volumeCombo == v,
            title: v.label,
            subtitle: v.detail,
            onTap: () => ref.read(_d234PrefsProvider.notifier).update(
                  (s) => s.copyWith(volumeCombo: v),
                ),
          ),
        ),
        if (prefs.volumeCombo == VolumeCombo.holdVolDown2s ||
            prefs.volumeCombo == VolumeCombo.bothKeys3s) ...[
          const SizedBox(height: ZapSpacing.sm),
          Text(
            'Hold duration: ${prefs.volumeHoldMs} ms',
            style: const TextStyle(color: ZapColors.textMuted, fontSize: 11),
          ),
          Slider(
            value: prefs.volumeHoldMs.toDouble(),
            min: 1000,
            max: 4000,
            divisions: 6,
            label: '${prefs.volumeHoldMs}ms',
            onChanged: (v) => ref.read(_d234PrefsProvider.notifier).update(
                  (s) => s.copyWith(volumeHoldMs: v.round()),
                ),
          ),
        ],
        const SizedBox(height: ZapSpacing.lg),
        const _SectionHeader(
          icon: Icons.vibration_rounded,
          title: 'Shake sensitivity',
          color: Color(0xFFF59E0B),
        ),
        ...ShakeSensitivity.values.map(
          (s) => _OptionTile(
            selected: prefs.shakeSensitivity == s,
            title: s.label,
            subtitle: s == ShakeSensitivity.off
                ? 'Accelerometer unlock disabled'
                : 'Threshold ${s.threshold} m/s² · Day 233 default = Medium',
            onTap: () => ref.read(_d234PrefsProvider.notifier).update(
                  (p) => p.copyWith(shakeSensitivity: s),
                ),
          ),
        ),
        if (prefs.shakeSensitivity != ShakeSensitivity.off) ...[
          const SizedBox(height: ZapSpacing.sm),
          Text(
            'Shake count: ${prefs.shakeCount}',
            style: const TextStyle(color: ZapColors.textMuted, fontSize: 11),
          ),
          Slider(
            value: prefs.shakeCount.toDouble(),
            min: 2,
            max: 5,
            divisions: 3,
            label: '${prefs.shakeCount}',
            onChanged: (v) => ref.read(_d234PrefsProvider.notifier).update(
                  (s) => s.copyWith(shakeCount: v.round()),
                ),
          ),
          Text(
            'Window: ${prefs.shakeWindowMs} ms',
            style: const TextStyle(color: ZapColors.textMuted, fontSize: 11),
          ),
          Slider(
            value: prefs.shakeWindowMs.toDouble(),
            min: 1500,
            max: 4000,
            divisions: 5,
            label: '${prefs.shakeWindowMs}ms',
            onChanged: (v) => ref.read(_d234PrefsProvider.notifier).update(
                  (s) => s.copyWith(shakeWindowMs: v.round()),
                ),
          ),
        ],
        const SizedBox(height: ZapSpacing.lg),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: !dirty || saving
                    ? null
                    : () {
                        ref.read(_d234PrefsProvider.notifier).state = saved;
                      },
                child: const Text('Discard'),
              ),
            ),
            const SizedBox(width: 8),
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
                                'Saved to Hive secret_gesture_prefs',
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
                style: FilledButton.styleFrom(backgroundColor: ZapColors.safe),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final bool selected;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;

  const _OptionTile({
    required this.selected,
    required this.title,
    required this.subtitle,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? ZapColors.info : ZapColors.border,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ZapSpacing.md,
            vertical: ZapSpacing.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? ZapColors.info : ZapColors.textMuted,
                size: 20,
              ),
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
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: ZapColors.textMuted,
                        fontSize: 10,
                      ),
                    ),
                    if (badge != null && badge != '—') ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: ZapColors.info.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badge!,
                          style: const TextStyle(
                            color: ZapColors.info,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tab 1: Summary ────────────────────────────────────────────────────────────
class _SummaryTab extends ConsumerWidget {
  const _SummaryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(_d234SavedProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Active configuration',
                style: TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _summaryLine(prefs),
                style: const TextStyle(
                  color: ZapColors.textSecondary,
                  fontSize: 11,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        _DecoyMapCard(
          title: 'Day 232 · Calculator decoy',
          icon: Icons.calculate_rounded,
          color: const Color(0xFF6B7280),
          tap: prefs.tapPattern == TapPattern.calculator767
              ? prefs.tapPattern.label
              : 'Uses global tap (may differ)',
          volume: prefs.volumeCombo.label,
          shake: prefs.shakeSensitivity == ShakeSensitivity.off
              ? 'Off'
              : '${prefs.shakeCount}× @ ${prefs.shakeSensitivity.threshold}',
          route: AppRoutes.decoyCalculator,
        ),
        _DecoyMapCard(
          title: 'Day 233 · Weather decoy',
          icon: Icons.wb_sunny_rounded,
          color: const Color(0xFF3B82F6),
          tap: prefs.tapPattern.label,
          volume: prefs.volumeCombo.label,
          shake: prefs.shakeSensitivity == ShakeSensitivity.off
              ? 'Off'
              : '${prefs.shakeCount}× / ${prefs.shakeWindowMs}ms',
          route: AppRoutes.decoyWeather,
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Quick test',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              label: const Text('Test calculator decoy'),
              onPressed: () => context.push(AppRoutes.decoyCalculator),
            ),
            ActionChip(
              label: const Text('Test weather decoy'),
              onPressed: () => context.push(AppRoutes.decoyWeather),
            ),
            ActionChip(
              label: const Text('Day 230 hidden mode'),
              onPressed: () => context.push(AppRoutes.hiddenModeToggle),
            ),
            ActionChip(
              label: const Text('Day 235 Stealth hub'),
              onPressed: () => context.push(AppRoutes.stealthSettingsHub),
            ),
          ],
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

class _DecoyMapCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String tap;
  final String volume;
  final String shake;
  final String route;

  const _DecoyMapCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.tap,
    required this.volume,
    required this.shake,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ZapColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => context.push(route),
                child: const Text('Open', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
          _MapRow(label: 'Tap', value: tap),
          _MapRow(label: 'Volume', value: volume),
          _MapRow(label: 'Shake', value: shake),
        ],
      ),
    );
  }
}

class _MapRow extends StatelessWidget {
  final String label;
  final String value;

  const _MapRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(
              label,
              style: const TextStyle(color: ZapColors.textMuted, fontSize: 10),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: ZapColors.textSecondary,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab 2: Hive ───────────────────────────────────────────────────────────────
class _HiveBoxTab extends ConsumerWidget {
  const _HiveBoxTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(_d234SavedProvider);
    final json = const JsonEncoder.withIndent('  ').convert(saved.toJson());

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
            'Hive box · secret_gesture_prefs · encrypted (Day 187 cipher)',
            style: TextStyle(color: ZapColors.warning, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
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
              fontSize: 9,
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
            minimumSize: const Size(double.infinity, 48),
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
