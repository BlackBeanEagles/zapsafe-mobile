/// Day 231 — Stealth Mode LP24 Icon Disguise Setup
///
/// Section B (Days 221-240): guide user to swap launcher icon to Calculator
/// (Android activity-alias / iOS alternate icons). Before/after preview,
/// platform limitations, mock apply flow.
///
/// Tag: 🟢 FRONTEND-ONLY · LP24 trusted-location stealth extension.
///
/// Route: [AppRoutes.stealthIconDisguise] → `/stealth-icon-disguise`
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

// ── Disguise catalogue ────────────────────────────────────────────────────────
enum IconDisguise {
  zapsafe,
  calculator,
  weather,
  notes,
}

extension IconDisguiseX on IconDisguise {
  String get label => switch (this) {
        IconDisguise.zapsafe => 'ZapSafe',
        IconDisguise.calculator => 'Calculator',
        IconDisguise.weather => 'Weather',
        IconDisguise.notes => 'Notes',
      };

  String get hiveKey => switch (this) {
        IconDisguise.zapsafe => 'default',
        IconDisguise.calculator => 'calculator',
        IconDisguise.weather => 'weather',
        IconDisguise.notes => 'notes',
      };

  IconData get icon => switch (this) {
        IconDisguise.zapsafe => Icons.bolt_rounded,
        IconDisguise.calculator => Icons.calculate_rounded,
        IconDisguise.weather => Icons.wb_sunny_rounded,
        IconDisguise.notes => Icons.note_alt_rounded,
      };

  Color get color => switch (this) {
        IconDisguise.zapsafe => ZapColors.danger,
        IconDisguise.calculator => const Color(0xFF6B7280),
        IconDisguise.weather => const Color(0xFF3B82F6),
        IconDisguise.notes => const Color(0xFFF59E0B),
      };

  String get androidAlias => switch (this) {
        IconDisguise.zapsafe => '.MainActivity',
        IconDisguise.calculator => '.alias.CalculatorActivity',
        IconDisguise.weather => '.alias.WeatherActivity',
        IconDisguise.notes => '.alias.NotesActivity',
      };

  String get iosAsset => switch (this) {
        IconDisguise.zapsafe => 'AppIcon',
        IconDisguise.calculator => 'AppIcon-Calculator',
        IconDisguise.weather => 'AppIcon-Weather',
        IconDisguise.notes => 'AppIcon-Notes',
      };

  bool get isStealth => this != IconDisguise.zapsafe;
}

const _kRecommended = IconDisguise.calculator;

const _kAndroidSnippet = '''<!-- AndroidManifest.xml — activity-alias (LP24) -->
<activity-alias
    android:name=".alias.CalculatorActivity"
    android:enabled="false"
    android:exported="true"
    android:icon="@mipmap/ic_calculator"
    android:label="Calculator"
    android:targetActivity=".MainActivity">
  <intent-filter>
    <action android:name="android.intent.action.MAIN" />
    <category android:name="android.intent.category.LAUNCHER" />
  </intent-filter>
</activity-alias>''';

const _kIosSnippet = '''// iOS — Info.plist CFBundleAlternateIcons
"CFBundleAlternateIcons": {
  "Calculator": {
    "CFBundleIconFiles": ["AppIcon-Calculator"],
    "UIPrerenderedIcon": false
  }
}
// Dart: flutter_dynamic_icon / alternate_icon (where supported)''';

// ── Providers ─────────────────────────────────────────────────────────────────
final _d231TabProvider = StateProvider<int>((ref) => 0);
final _d231SelectedProvider =
    StateProvider<IconDisguise>((ref) => _kRecommended);
final _d231AppliedProvider = StateProvider<IconDisguise>((ref) => IconDisguise.zapsafe);
final _d231ApplyingProvider = StateProvider<bool>((ref) => false);
final _d231ExpandedPlatformProvider = StateProvider<String?>((ref) => null);

const _kTabs = ['Disguise', 'Platform Notes', 'Spec'];

String _platformLabel() {
  if (kIsWeb) return 'Web preview';
  if (Platform.isAndroid) return 'Android';
  if (Platform.isIOS) return 'iOS';
  return 'Desktop / other';
}

Future<void> _mockApply(WidgetRef ref, IconDisguise disguise) async {
  ref.read(_d231ApplyingProvider.notifier).state = true;
  await Future<void>.delayed(const Duration(milliseconds: 1100));
  ref.read(_d231AppliedProvider.notifier).state = disguise;
  ref.read(_d231ApplyingProvider.notifier).state = false;
}

// ── Screen ────────────────────────────────────────────────────────────────────
class Day231StealthIconDisguiseScreen extends ConsumerWidget {
  const Day231StealthIconDisguiseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d231TabProvider);
    final applied = ref.watch(_d231AppliedProvider);
    final disguised = applied.isStealth;

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 231 · Icon Disguise'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: disguised
                      ? ZapColors.safe.withOpacity(0.15)
                      : ZapColors.textMuted.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: disguised
                        ? ZapColors.safe.withOpacity(0.45)
                        : ZapColors.border,
                  ),
                ),
                child: Text(
                  disguised ? 'DISGUISED' : 'DEFAULT',
                  style: TextStyle(
                    color: disguised ? ZapColors.safe : ZapColors.textMuted,
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
            onSelect: (i) => ref.read(_d231TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (tab) {
              0 => const _DisguiseTab(),
              1 => const _PlatformNotesTab(),
              _ => const _SpecTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Disguise ───────────────────────────────────────────────────────────
class _DisguiseTab extends ConsumerWidget {
  const _DisguiseTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(_d231SelectedProvider);
    final applied = ref.watch(_d231AppliedProvider);
    final applying = ref.watch(_d231ApplyingProvider);

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
          child: Text(
            '🟢 FRONTEND-ONLY · Section B Day 11/20 · LP24 icon disguise · ${_platformLabel()}',
            style: const TextStyle(color: ZapColors.safe, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Wrap(
          spacing: 8,
          children: [
            ActionChip(
              label: const Text('Day 230 Hidden Mode'),
              onPressed: () => context.push(AppRoutes.hiddenModeToggle),
            ),
            ActionChip(
              avatar: const Icon(Icons.star_rounded, size: 16),
              label: const Text('Recommended: Calculator'),
              onPressed: () =>
                  ref.read(_d231SelectedProvider.notifier).state =
                      _kRecommended,
            ),
            ActionChip(
              label: const Text('Day 232 Calculator'),
              onPressed: () => context.push(AppRoutes.decoyCalculator),
            ),
            ActionChip(
              label: const Text('Day 233 Weather decoy'),
              onPressed: () => context.push(AppRoutes.decoyWeather),
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Before / after launcher preview',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Row(
          children: [
            Expanded(
              child: _LauncherPreviewCard(
                title: 'Before',
                disguise: IconDisguise.zapsafe,
                highlighted: applied == IconDisguise.zapsafe,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.arrow_forward_rounded,
                  color: ZapColors.textMuted),
            ),
            Expanded(
              child: _LauncherPreviewCard(
                title: 'After (selected)',
                disguise: selected,
                highlighted: selected.isStealth,
              ),
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Choose disguise icon',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.35,
          children: IconDisguise.values.map((d) {
            final sel = selected == d;
            return Material(
              color: sel
                  ? d.color.withOpacity(0.12)
                  : ZapColors.bgCard,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: () =>
                    ref.read(_d231SelectedProvider.notifier).state = d,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: sel ? d.color : ZapColors.border,
                      width: sel ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: d.color,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(d.icon, color: Colors.white, size: 26),
                      ),
                      const SizedBox(height: ZapSpacing.sm),
                      Text(
                        d.label,
                        style: TextStyle(
                          color: sel
                              ? ZapColors.textPrimary
                              : ZapColors.textSecondary,
                          fontWeight:
                              sel ? FontWeight.w800 : FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                      if (d == _kRecommended)
                        const Text(
                          'LP24 default',
                          style: TextStyle(
                            color: ZapColors.info,
                            fontSize: 8,
                          ),
                        ),
                      if (d == applied)
                        const Text(
                          'APPLIED',
                          style: TextStyle(
                            color: ZapColors.safe,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
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
        if (applied.isStealth && applied == selected)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ZapSpacing.md),
            margin: const EdgeInsets.only(bottom: ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.safe.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ZapColors.safe.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_rounded,
                    color: ZapColors.safe, size: 22),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    '${applied.label} disguise active · launcher shows neutral icon',
                    style: const TextStyle(
                      color: ZapColors.safe,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Semantics(
          label: 'Apply icon disguise',
          button: true,
          child: FilledButton.icon(
            onPressed: applying || selected == applied
                ? null
                : () async {
                    await _mockApply(ref, selected);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            selected == IconDisguise.zapsafe
                                ? 'Restored default ZapSafe icon'
                                : 'Applied ${selected.label} disguise (mock)',
                          ),
                          backgroundColor: ZapColors.safe,
                        ),
                      );
                    }
                  },
            icon: applying
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    selected == IconDisguise.zapsafe
                        ? Icons.restore_rounded
                        : Icons.visibility_off_rounded,
                    size: 18,
                  ),
            label: Text(
              applying
                  ? 'Applying…'
                  : selected == IconDisguise.zapsafe
                      ? 'Restore ZapSafe icon'
                      : 'Apply ${selected.label} disguise',
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 75),
              backgroundColor: selected.isStealth
                  ? ZapColors.danger
                  : ZapColors.info,
            ),
          ),
        ),
        if (selected == applied && selected.isStealth) ...[
          const SizedBox(height: ZapSpacing.sm),
          OutlinedButton(
            onPressed: applying
                ? null
                : () async {
                    ref.read(_d231SelectedProvider.notifier).state =
                        IconDisguise.zapsafe;
                    await _mockApply(ref, IconDisguise.zapsafe);
                  },
            child: const Text('Reset disguise (demo)'),
          ),
        ],
      ],
    );
  }
}

class _LauncherPreviewCard extends StatelessWidget {
  final String title;
  final IconDisguise disguise;
  final bool highlighted;

  const _LauncherPreviewCard({
    required this.title,
    required this.disguise,
    required this.highlighted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlighted
              ? disguise.color.withOpacity(0.5)
              : ZapColors.border,
        ),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: ZapColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZapSpacing.md),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: disguise.color,
              borderRadius: BorderRadius.circular(14),
              boxShadow: highlighted
                  ? [
                      BoxShadow(
                        color: disguise.color.withOpacity(0.35),
                        blurRadius: 12,
                      ),
                    ]
                  : null,
            ),
            child: Icon(disguise.icon, color: Colors.white, size: 30),
          ),
          const SizedBox(height: ZapSpacing.sm),
          Text(
            disguise.label,
            style: const TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab 1: Platform notes ─────────────────────────────────────────────────────
class _PlatformNotesTab extends ConsumerWidget {
  const _PlatformNotesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(_d231ExpandedPlatformProvider);
    final selected = ref.watch(_d231SelectedProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        _PlatformCard(
          id: 'android',
          expanded: expanded == 'android',
          onToggle: () => ref.read(_d231ExpandedPlatformProvider.notifier).state =
              expanded == 'android' ? null : 'android',
          icon: Icons.android_rounded,
          color: const Color(0xFF3DDC84),
          title: 'Android · activity-alias',
          summary:
              'Enable one alias at a time in AndroidManifest. Calculator alias '
              'hides ZapSafe branding from launcher.',
          bullets: const [
            'Each disguise = separate activity-alias targeting MainActivity',
            'Only one LAUNCHER alias enabled=true at a time',
            'Some OEM launchers cache icon — user may need to reboot',
            'Hardware SOS + volume triggers unaffected (same MainActivity)',
            'Day 232 decoy shell opens after tap on disguised icon',
          ],
          limitation:
              'Cannot change icon without reinstall on Android 12+ if alias '
              'not declared upfront. ZapSafe ships all aliases disabled except default.',
        ),
        const SizedBox(height: ZapSpacing.sm),
        _PlatformCard(
          id: 'ios',
          expanded: expanded == 'ios',
          onToggle: () => ref.read(_d231ExpandedPlatformProvider.notifier).state =
              expanded == 'ios' ? null : 'ios',
          icon: Icons.apple_rounded,
          color: const Color(0xFF9CA3AF),
          title: 'iOS · alternate app icons',
          summary:
              'CFBundleAlternateIcons in Info.plist. User must approve icon '
              'change in Settings on some iOS versions.',
          bullets: const [
            'Alternate icons bundled at build time (AppIcon-Calculator etc.)',
            'setAlternateIconName via platform channel or plugin',
            'iOS 10.3+ supports alternate icons — no alias concept',
            'App Store review: disguise must not impersonate Apple apps',
            'SOS widgets / shortcuts keep real ZapSafe name internally',
          ],
          limitation:
              'iOS shows system alert first time icon changes. '
              'Cannot use arbitrary icons at runtime — only pre-declared assets.',
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.info.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.info.withOpacity(0.3)),
          ),
          child: Text(
            'Selected disguise maps to ${selected.androidAlias} (Android) · '
            '${selected.iosAsset} (iOS asset).',
            style: const TextStyle(
              color: ZapColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}

class _PlatformCard extends StatelessWidget {
  final String id;
  final bool expanded;
  final VoidCallback onToggle;
  final IconData icon;
  final Color color;
  final String title;
  final String summary;
  final List<String> bullets;
  final String limitation;

  const _PlatformCard({
    required this.id,
    required this.expanded,
    required this.onToggle,
    required this.icon,
    required this.color,
    required this.title,
    required this.summary,
    required this.bullets,
    required this.limitation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ZapColors.border),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            child: Padding(
              padding: const EdgeInsets.all(ZapSpacing.md),
              child: Row(
                children: [
                  Icon(icon, color: color, size: 24),
                  const SizedBox(width: ZapSpacing.sm),
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
                          summary,
                          style: const TextStyle(
                            color: ZapColors.textMuted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: ZapColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(color: ZapColors.border, height: 1),
            Padding(
              padding: const EdgeInsets.all(ZapSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final b in bullets)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ',
                              style: TextStyle(color: ZapColors.info)),
                          Expanded(
                            child: Text(
                              b,
                              style: const TextStyle(
                                color: ZapColors.textSecondary,
                                fontSize: 10,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ZapColors.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: ZapColors.warning.withOpacity(0.35),
                      ),
                    ),
                    child: Text(
                      'Limitation: $limitation',
                      style: const TextStyle(
                        color: ZapColors.textSecondary,
                        fontSize: 10,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Tab 2: Spec ───────────────────────────────────────────────────────────────
class _SpecTab extends ConsumerWidget {
  const _SpecTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applied = ref.watch(_d231AppliedProvider);
    final selected = ref.watch(_d231SelectedProvider);

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
            'LP24 · Icon disguise stored in Hive hidden_mode_prefs.icon_disguise',
            style: TextStyle(color: ZapColors.warning, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        _SpecRow(label: 'Applied', value: applied.label),
        _SpecRow(label: 'Selected', value: selected.label),
        _SpecRow(label: 'Hive key', value: applied.hiveKey),
        _SpecRow(label: 'Android alias', value: applied.androidAlias),
        _SpecRow(label: 'iOS asset', value: applied.iosAsset),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Android manifest snippet',
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
            _kAndroidSnippet,
            style: TextStyle(
              color: ZapColors.textSecondary,
              fontFamily: 'monospace',
              fontSize: 9,
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        const Text(
          'iOS alternate icons',
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
            _kIosSnippet,
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
            Clipboard.setData(
              const ClipboardData(text: _kAndroidSnippet),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Copied Android snippet')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text('Copy Android snippet'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 75),
            backgroundColor: ZapColors.bgElevated,
            foregroundColor: ZapColors.textPrimary,
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

class _SpecRow extends StatelessWidget {
  final String label;
  final String value;

  const _SpecRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
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
                fontFamily: 'monospace',
                fontSize: 10,
              ),
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
