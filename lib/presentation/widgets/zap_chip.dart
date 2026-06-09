import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/theme/spacing.dart';

/// A selectable filter chip.
///
/// Unlike [ZapBadge] (read-only status pill), [ZapChip] is interactive —
/// the user taps it to toggle selection. Used for:
/// - Tier filters (Tier 1 / Tier 2 / Tier 3)
/// - Time-of-day heatmap filters (Morning / Evening / Night)
/// - Drill category filters
/// - DCS sensitivity tiers in Settings
///
/// Usage:
/// ```dart
/// ZapChip(
///   label: 'Tier 1',
///   selected: filter == 'tier1',
///   onTap: () => setState(() => filter = 'tier1'),
/// )
/// ```
class ZapChip extends StatelessWidget {
  /// Chip text.
  final String label;

  /// Whether the chip is currently selected (filled vs outline).
  final bool selected;

  /// Tap handler — usually toggles [selected].
  final VoidCallback? onTap;

  /// Optional leading icon. Replaced with a check when [selected].
  final IconData? icon;

  /// Optional trailing icon (e.g. close × for removable chips).
  final IconData? trailingIcon;

  /// Tap handler for the trailing icon.
  final VoidCallback? onTrailingTap;

  /// Accent color when selected. Defaults to theme primary.
  final Color? selectedColor;

  /// If true, the chip shrinks to a more compact size.
  final bool compact;

  const ZapChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.icon,
    this.trailingIcon,
    this.onTrailingTap,
    this.selectedColor,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = selectedColor ?? Theme.of(context).colorScheme.primary;
    final disabled = onTap == null;

    final bg = selected ? accent.withOpacity(disabled ? 0.08 : 0.18) : ZapColors.bgCard;
    final fg = selected ? accent : ZapColors.textPrimary;
    final borderColor = selected ? accent.withOpacity(disabled ? 0.2 : 0.5) : ZapColors.border;
    final borderWidth = selected ? 1.5 : 1.0;

    final padH = compact ? ZapSpacing.md : ZapSpacing.lg;
    final padV = compact ? ZapSpacing.sm : ZapSpacing.md;

    // Show check icon when selected (replaces leading icon)
    final leading = selected
        ? Icon(Icons.check_rounded, size: compact ? 14 : 16, color: accent)
        : (icon == null ? null : Icon(icon, size: compact ? 14 : 16, color: fg));

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leading != null) ...[
          leading,
          SizedBox(width: compact ? ZapSpacing.xs : ZapSpacing.sm),
        ],
        Text(
          label,
          style: ZapTypography.labelMedium.copyWith(
            color: fg.withOpacity(disabled ? 0.5 : 1.0),
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: compact ? 11 : 12,
            letterSpacing: 0.3,
          ),
        ),
        if (trailingIcon != null) ...[
          SizedBox(width: compact ? ZapSpacing.xs : ZapSpacing.sm),
          GestureDetector(
            onTap: onTrailingTap,
            behavior: HitTestBehavior.opaque,
            child: Icon(trailingIcon, size: compact ? 14 : 16, color: fg.withOpacity(0.7)),
          ),
        ],
      ],
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(ZapSpacing.radiusPill),
        splashColor: accent.withOpacity(0.12),
        highlightColor: accent.withOpacity(0.06),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(ZapSpacing.radiusPill),
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          child: content,
        ),
      ),
    );
  }
}

/// A horizontal row of [ZapChip]s that act as radio-button-like filters
/// (one selection at a time). Handy for filter bars.
class ZapChipGroup<T> extends StatelessWidget {
  /// List of (value, label) options.
  final List<({T value, String label, IconData? icon})> options;

  /// Currently selected value. If null, no chip is highlighted.
  final T? selectedValue;

  /// Called when the user taps a different chip.
  final ValueChanged<T> onChanged;

  /// Spacing between chips.
  final double spacing;

  /// Spacing between rows when chips wrap.
  final double runSpacing;

  /// Override the accent color of the selected chip.
  final Color? selectedColor;

  /// Compact size.
  final bool compact;

  const ZapChipGroup({
    super.key,
    required this.options,
    required this.selectedValue,
    required this.onChanged,
    this.spacing = ZapSpacing.sm,
    this.runSpacing = ZapSpacing.sm,
    this.selectedColor,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      children: options.map((opt) {
        return ZapChip(
          label: opt.label,
          icon: opt.icon,
          selected: selectedValue == opt.value,
          selectedColor: selectedColor,
          compact: compact,
          onTap: () => onChanged(opt.value),
        );
      }).toList(),
    );
  }
}
