// Day 97 — Accessibility Settings
//
// Six sections: Text & Display · Colour & Vision · Motion ·
// Audio & Haptics · Screen Reader · SOS & Emergency.
// Live preview card reflects every setting change in real time.
// "Reset" action in AppBar restores all defaults via a confirm dialog.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/theme/spacing.dart';
import '../../domain/providers/accessibility_providers.dart';

// ─── Screen ───────────────────────────────────────────────────────────────────

class Day97AccessibilitySettingsScreen extends ConsumerWidget {
  const Day97AccessibilitySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state    = ref.watch(accessibilityProvider);
    final notifier = ref.read(accessibilityProvider.notifier);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: ZapColors.bgPrimary,
        elevation: 0,
        title: Text(
          'Accessibility',
          style: ZapTypography.headlineSmall.copyWith(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          if (!state.isDefault)
            TextButton(
              onPressed: () =>
                  _confirmReset(context, notifier),
              child: Text(
                'Reset',
                style: ZapTypography.labelMedium.copyWith(
                  color: ZapColors.danger,
                ),
              ),
            ),
          const SizedBox(width: ZapSpacing.sm),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.lg),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: ZapSpacing.md),

                // ─── Live preview ─────────────────────────────────────
                _PreviewCard(state: state),
                const SizedBox(height: ZapSpacing.xl),

                // ─── Text & Display ───────────────────────────────────
                const _SectionHeader(
                  icon: Icons.text_fields_rounded,
                  label: 'Text & Display',
                  color: ZapColors.info,
                ),
                const SizedBox(height: ZapSpacing.sm),
                _SettingsCard(
                  children: [
                    _FontSizeRow(
                      current:  state.fontScale,
                      onSelect: notifier.setFontScale,
                    ),
                    const _SettingsDivider(),
                    _ToggleTile(
                      icon:     Icons.format_bold_rounded,
                      label:    'Bold Text',
                      subtitle: 'Increases weight for all body copy',
                      value:    state.boldText,
                      onToggle: notifier.toggleBoldText,
                    ),
                    const _SettingsDivider(),
                    _ToggleTile(
                      icon:     Icons.space_bar_rounded,
                      label:    'Wide Letter Spacing',
                      subtitle: 'Improves readability for dyslexia',
                      value:    state.wideLetterSpacing,
                      onToggle: notifier.toggleWideLetterSpacing,
                    ),
                  ],
                ),
                const SizedBox(height: ZapSpacing.xl),

                // ─── Colour & Vision ──────────────────────────────────
                const _SectionHeader(
                  icon:  Icons.palette_rounded,
                  label: 'Colour & Vision',
                  color: ZapColors.warning,
                ),
                const SizedBox(height: ZapSpacing.sm),
                _SettingsCard(
                  children: [
                    _ColorModeRow(
                      current:  state.colorMode,
                      onSelect: notifier.setColorMode,
                    ),
                    const _SettingsDivider(),
                    _ToggleTile(
                      icon:     Icons.blur_off_rounded,
                      label:    'Reduce Transparency',
                      subtitle: 'Makes overlays and sheets fully opaque',
                      value:    state.reduceTransparency,
                      onToggle: notifier.toggleReduceTransparency,
                    ),
                  ],
                ),
                const SizedBox(height: ZapSpacing.xl),

                // ─── Motion ───────────────────────────────────────────
                const _SectionHeader(
                  icon:  Icons.animation_rounded,
                  label: 'Motion',
                  color: ZapColors.safe,
                ),
                const SizedBox(height: ZapSpacing.sm),
                _SettingsCard(
                  children: [
                    _ToggleTile(
                      icon:     Icons.motion_photos_off_rounded,
                      label:    'Reduce Motion',
                      subtitle: 'Limits parallax and auto-play effects',
                      value:    state.reduceMotion,
                      onToggle: notifier.toggleReduceMotion,
                    ),
                    const _SettingsDivider(),
                    _AnimSpeedRow(
                      current:  state.animationSpeed,
                      onSelect: notifier.setAnimationSpeed,
                    ),
                  ],
                ),
                const SizedBox(height: ZapSpacing.xl),

                // ─── Audio & Haptics ──────────────────────────────────
                const _SectionHeader(
                  icon:  Icons.vibration_rounded,
                  label: 'Audio & Haptics',
                  color: ZapColors.textSecondary,
                ),
                const SizedBox(height: ZapSpacing.sm),
                _SettingsCard(
                  children: [
                    _ToggleTile(
                      icon:     Icons.vibration_rounded,
                      label:    'Haptic Feedback',
                      subtitle: 'Vibration on taps, toggles, and alerts',
                      value:    state.hapticFeedback,
                      onToggle: notifier.toggleHapticFeedback,
                    ),
                    const _SettingsDivider(),
                    _ToggleTile(
                      icon:     Icons.volume_up_rounded,
                      label:    'Sound Effects',
                      subtitle: 'UI confirmation tones and alert chimes',
                      value:    state.soundEffects,
                      onToggle: notifier.toggleSoundEffects,
                    ),
                  ],
                ),
                const SizedBox(height: ZapSpacing.xl),

                // ─── Screen Reader ────────────────────────────────────
                const _SectionHeader(
                  icon:  Icons.record_voice_over_rounded,
                  label: 'Screen Reader',
                  color: ZapColors.info,
                ),
                const SizedBox(height: ZapSpacing.sm),
                _SettingsCard(
                  children: [
                    _ToggleTile(
                      icon:     Icons.record_voice_over_rounded,
                      label:    'Screen Reader Optimized',
                      subtitle: 'Enhanced TalkBack / VoiceOver semantics',
                      value:    state.screenReaderOptimized,
                      onToggle: notifier.toggleScreenReaderOptimized,
                    ),
                    if (state.screenReaderOptimized) ...[
                      const _SettingsDivider(),
                      const _InfoBanner(
                        icon:    Icons.info_outline_rounded,
                        color:   ZapColors.info,
                        message: 'All interactive elements now expose '
                            'semantic labels and navigation hints to '
                            'TalkBack and VoiceOver.',
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: ZapSpacing.xl),

                // ─── SOS & Emergency ──────────────────────────────────
                const _SectionHeader(
                  icon:  Icons.crisis_alert_rounded,
                  label: 'SOS & Emergency',
                  color: ZapColors.danger,
                ),
                const SizedBox(height: ZapSpacing.sm),
                _SettingsCard(
                  children: [
                    _ToggleTile(
                      icon:     Icons.touch_app_rounded,
                      label:    'Large SOS Button',
                      subtitle: 'Bigger tap target for faster activation',
                      value:    state.largeSOSButton,
                      onToggle: notifier.toggleLargeSOSButton,
                    ),
                    const _SettingsDivider(),
                    _ToggleTile(
                      icon:     Icons.layers_clear_rounded,
                      label:    'Simplified Panic Mode',
                      subtitle: 'Shows only emergency controls during SOS',
                      value:    state.simplifiedPanicMode,
                      onToggle: notifier.toggleSimplifiedPanicMode,
                    ),
                    if (state.simplifiedPanicMode) ...[
                      const _SettingsDivider(),
                      const _InfoBanner(
                        icon:    Icons.warning_amber_rounded,
                        color:   ZapColors.warning,
                        message: 'When an SOS is active the interface '
                            'will reduce to essential emergency controls '
                            'only — all other UI is hidden.',
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: ZapSpacing.xxxl),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Reset confirmation ───────────────────────────────────────────────────────

Future<void> _confirmReset(
  BuildContext context,
  AccessibilityNotifier notifier,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: ZapColors.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
      ),
      title: Text(
        'Reset to Defaults?',
        style: ZapTypography.headlineSmall.copyWith(
          color: ZapColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Text(
        'All accessibility settings will be restored to their original values.',
        style: ZapTypography.bodyMedium.copyWith(
          color: ZapColors.textSecondary,
          height: 1.5,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(
            'Cancel',
            style: ZapTypography.labelMedium.copyWith(
              color: ZapColors.textSecondary,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(
            'Reset',
            style: ZapTypography.labelMedium.copyWith(
              color: ZapColors.danger,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
  if (ok == true) {
    notifier.resetToDefaults();
  }
}

// ─── Live preview card ────────────────────────────────────────────────────────

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.state});
  final AccessibilityState state;

  @override
  Widget build(BuildContext context) {
    final safe   = state.colorMode.safeColor;
    final danger = state.colorMode.dangerColor;
    final weight = state.boldText ? FontWeight.w700 : FontWeight.w500;
    final ls     = state.wideLetterSpacing ? 1.2 : 0.0;
    final scale  = state.fontScale.scale;

    return Container(
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── header row ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
                ZapSpacing.md, ZapSpacing.sm, ZapSpacing.md, ZapSpacing.sm),
            child: Row(
              children: [
                const Icon(Icons.preview_rounded,
                    size: 13, color: ZapColors.textSecondary),
                const SizedBox(width: ZapSpacing.xs),
                Text(
                  'LIVE PREVIEW',
                  style: ZapTypography.labelSmall.copyWith(
                    color: ZapColors.textSecondary,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (state.colorMode != ColorMode.normal)
                  _ActiveBadge(state.colorMode.label),
                if (state.boldText)
                  const _ActiveBadge('Bold'),
                if (state.wideLetterSpacing)
                  const _ActiveBadge('Wide'),
                if (state.largeSOSButton)
                  const _ActiveBadge('Large SOS'),
              ],
            ),
          ),
          const Divider(color: ZapColors.divider, height: 1),

          // ── preview content ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(ZapSpacing.lg),
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Alert heading
                  Text(
                    'Emergency Alert',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: weight,
                      color: danger,
                      letterSpacing: ls,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Body copy
                  Text(
                    'Aarti Sharma triggered SOS. Location sharing is active.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          state.boldText ? FontWeight.w500 : FontWeight.w400,
                      color: ZapColors.textPrimary,
                      letterSpacing: ls * 0.6,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Buttons row
                  Row(
                    children: [
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: state.largeSOSButton ? 68 : 50,
                          decoration: BoxDecoration(
                            color: danger.withOpacity(0.12),
                            borderRadius:
                                BorderRadius.circular(ZapSpacing.radiusSmall),
                            border: Border.all(
                              color: danger.withOpacity(0.55),
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'TRIGGER SOS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: danger,
                                letterSpacing: ls + 1.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: ZapSpacing.sm),
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: state.largeSOSButton ? 68 : 50,
                          decoration: BoxDecoration(
                            color: safe.withOpacity(0.12),
                            borderRadius:
                                BorderRadius.circular(ZapSpacing.radiusSmall),
                            border: Border.all(
                              color: safe.withOpacity(0.55),
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              "I'M SAFE",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: safe,
                                letterSpacing: ls + 1.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Font scale indicator
                  const SizedBox(height: ZapSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        state.fontScale.description,
                        style: const TextStyle(
                          fontSize: 10,
                          color: ZapColors.textMuted,
                        ),
                      ),
                      Text(
                        state.colorMode.label,
                        style: const TextStyle(
                          fontSize: 10,
                          color: ZapColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveBadge extends StatelessWidget {
  const _ActiveBadge(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: ZapColors.info.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: ZapColors.info.withOpacity(0.4), width: 1),
      ),
      child: Text(
        label,
        style: ZapTypography.labelSmall.copyWith(
          fontSize: 9,
          color: ZapColors.info,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─── Layout primitives ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String   label;
  final Color    color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: ZapSpacing.xs),
        Text(
          label.toUpperCase(),
          style: ZapTypography.labelSmall.copyWith(
            color: color,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: ZapSpacing.md),
        const Expanded(child: Divider(color: ZapColors.border)),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.border, width: 1),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      color: ZapColors.divider,
      height: 1,
      indent: 52,
    );
  }
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onToggle,
  });

  final IconData     icon;
  final String       label;
  final String       subtitle;
  final bool         value;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(ZapSpacing.radius),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ZapSpacing.lg,
          vertical: ZapSpacing.md,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: value ? ZapColors.info : ZapColors.textMuted,
            ),
            const SizedBox(width: ZapSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: ZapTypography.labelLarge.copyWith(
                      color: ZapColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: ZapTypography.bodySmall.copyWith(
                      color: ZapColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: (_) => onToggle(),
              activeColor: ZapColors.info,
              activeTrackColor: ZapColors.info.withOpacity(0.3),
              inactiveThumbColor: ZapColors.textMuted,
              inactiveTrackColor: ZapColors.bgElevated,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.icon,
    required this.color,
    required this.message,
  });

  final IconData icon;
  final Color    color;
  final String   message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          ZapSpacing.lg, ZapSpacing.sm, ZapSpacing.lg, ZapSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: ZapTypography.bodySmall.copyWith(
                color: color,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Font size selector ───────────────────────────────────────────────────────

class _FontSizeRow extends StatelessWidget {
  const _FontSizeRow({
    required this.current,
    required this.onSelect,
  });

  final FontScale            current;
  final ValueChanged<FontScale> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.text_fields_rounded,
                  size: 18, color: ZapColors.textMuted),
              const SizedBox(width: ZapSpacing.sm),
              Text(
                'Font Size',
                style: ZapTypography.labelLarge.copyWith(
                  color: ZapColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                current.description,
                style: ZapTypography.bodySmall.copyWith(
                  color: ZapColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: FontScale.values.map((fs) {
              final selected = fs == current;
              return GestureDetector(
                onTap: () => onSelect(fs),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: selected
                        ? ZapColors.info.withOpacity(0.18)
                        : ZapColors.bgElevated,
                    borderRadius:
                        BorderRadius.circular(ZapSpacing.radiusSmall),
                    border: Border.all(
                      color: selected ? ZapColors.info : ZapColors.border,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'A',
                      style: TextStyle(
                        fontSize:   fs.selectorSize,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: selected
                            ? ZapColors.info
                            : ZapColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─── Colour mode selector ─────────────────────────────────────────────────────

class _ColorModeRow extends StatelessWidget {
  const _ColorModeRow({
    required this.current,
    required this.onSelect,
  });

  final ColorMode            current;
  final ValueChanged<ColorMode> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.palette_rounded,
                  size: 18, color: ZapColors.textMuted),
              const SizedBox(width: ZapSpacing.sm),
              Text(
                'Colour Filter',
                style: ZapTypography.labelLarge.copyWith(
                  color: ZapColors.textPrimary,
                ),
              ),
              const Spacer(),
              if (current != ColorMode.normal)
                Text(
                  current.label,
                  style: ZapTypography.bodySmall.copyWith(
                    color: ZapColors.info,
                  ),
                ),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          SizedBox(
            height: 86,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: ColorMode.values.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: ZapSpacing.sm),
              itemBuilder: (_, i) {
                final mode     = ColorMode.values[i];
                final selected = mode == current;
                return GestureDetector(
                  onTap: () => onSelect(mode),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 96,
                    padding: const EdgeInsets.symmetric(
                      horizontal: ZapSpacing.sm,
                      vertical: ZapSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? ZapColors.info.withOpacity(0.12)
                          : ZapColors.bgElevated,
                      borderRadius:
                          BorderRadius.circular(ZapSpacing.radiusSmall),
                      border: Border.all(
                        color: selected ? ZapColors.info : ZapColors.border,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // two colour dots
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _ColorDot(color: mode.safeColor),
                            const SizedBox(width: 6),
                            _ColorDot(color: mode.dangerColor),
                          ],
                        ),
                        const SizedBox(height: ZapSpacing.xs),
                        Text(
                          mode.label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: ZapTypography.labelSmall.copyWith(
                            fontSize: 10,
                            color: selected
                                ? ZapColors.info
                                : ZapColors.textPrimary,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

// ─── Animation speed selector ─────────────────────────────────────────────────

class _AnimSpeedRow extends StatelessWidget {
  const _AnimSpeedRow({
    required this.current,
    required this.onSelect,
  });

  final AnimationSpeed            current;
  final ValueChanged<AnimationSpeed> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ZapSpacing.lg,
        vertical: ZapSpacing.md,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.speed_rounded,
            size: 20,
            color: ZapColors.textMuted,
          ),
          const SizedBox(width: ZapSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Animation Speed',
                  style: ZapTypography.labelLarge.copyWith(
                    color: ZapColors.textPrimary,
                  ),
                ),
                const SizedBox(height: ZapSpacing.sm),
                Row(
                  children: AnimationSpeed.values.map((spd) {
                    final selected = spd == current;
                    final isFirst  = spd == AnimationSpeed.values.first;
                    final isLast   = spd == AnimationSpeed.values.last;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => onSelect(spd),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding:
                              const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(
                            color: selected
                                ? ZapColors.info.withOpacity(0.2)
                                : ZapColors.bgElevated,
                            border: Border.all(
                              color: selected
                                  ? ZapColors.info
                                  : ZapColors.border,
                            ),
                            borderRadius: BorderRadius.horizontal(
                              left: isFirst
                                  ? const Radius.circular(6)
                                  : Radius.zero,
                              right: isLast
                                  ? const Radius.circular(6)
                                  : Radius.zero,
                            ),
                          ),
                          child: Text(
                            spd.label,
                            textAlign: TextAlign.center,
                            style: ZapTypography.labelSmall.copyWith(
                              color: selected
                                  ? ZapColors.info
                                  : ZapColors.textSecondary,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
