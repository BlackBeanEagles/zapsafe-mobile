import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/theme/spacing.dart';

/// Visual variant of a [ZapButton].
enum ZapButtonVariant {
  /// Filled background. The default for primary CTAs (e.g. SOS, save).
  elevated,

  /// Lighter filled background — secondary action that still needs presence.
  tonal,

  /// Just a border + label. Tertiary or cancel-style actions.
  outlined,

  /// No background, no border. Quietest variant — inline links inside cards.
  text,
}

/// Semantic intent — drives the default color when [color] is not provided.
enum ZapButtonIntent {
  /// Red — destructive or emergency action (SOS trigger, delete).
  danger,

  /// Green — confirm or progress (verify, mark resolved).
  safe,

  /// Blue — informational (learn more, view details).
  info,

  /// Orange — caution (proceed with awareness).
  warning,

  /// Neutral — no semantic color, uses theme primary.
  neutral,
}

/// Size preset for [ZapButton].
enum ZapButtonSize {
  /// 75×75dp — WCAG AAA minimum. Default.
  regular,

  /// 88dp tall — emphasized CTAs like dashboard SOS.
  large,
}

/// ZapSafe's primary button.
///
/// One widget, four visual variants, five intents, two sizes — so the entire
/// app uses the same button class. All variants meet WCAG AAA 75×75dp.
///
/// Usage:
/// ```dart
/// ZapButton(
///   label: 'TRIGGER SOS',
///   icon: Icons.warning,
///   variant: ZapButtonVariant.elevated,
///   intent: ZapButtonIntent.danger,
///   onPressed: () => triggerSOS(),
/// )
/// ```
class ZapButton extends StatelessWidget {
  /// The text displayed on the button.
  final String label;

  /// Optional leading icon. Centered with [label].
  final IconData? icon;

  /// Fires when the user taps the button. If null, the button is disabled.
  final VoidCallback? onPressed;

  /// Visual style (filled / tonal / outlined / text).
  final ZapButtonVariant variant;

  /// Semantic color intent (overridden by [color] if provided).
  final ZapButtonIntent intent;

  /// Size preset. Defaults to [ZapButtonSize.regular] = 75dp.
  final ZapButtonSize size;

  /// Show a spinner instead of the label. Disables the button while true.
  final bool isLoading;

  /// Stretch the button to fill its parent's width.
  final bool fullWidth;

  /// Hard-override the accent color (ignores [intent]).
  final Color? color;

  const ZapButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.variant = ZapButtonVariant.elevated,
    this.intent = ZapButtonIntent.danger,
    this.size = ZapButtonSize.regular,
    this.isLoading = false,
    this.fullWidth = false,
    this.color,
  });

  // ─── Convenience constructors ──────────────────────────────────────────

  const ZapButton.elevated({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.intent = ZapButtonIntent.danger,
    this.size = ZapButtonSize.regular,
    this.isLoading = false,
    this.fullWidth = false,
    this.color,
  }) : variant = ZapButtonVariant.elevated;

  const ZapButton.tonal({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.intent = ZapButtonIntent.neutral,
    this.size = ZapButtonSize.regular,
    this.isLoading = false,
    this.fullWidth = false,
    this.color,
  }) : variant = ZapButtonVariant.tonal;

  const ZapButton.outlined({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.intent = ZapButtonIntent.neutral,
    this.size = ZapButtonSize.regular,
    this.isLoading = false,
    this.fullWidth = false,
    this.color,
  }) : variant = ZapButtonVariant.outlined;

  const ZapButton.text({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.intent = ZapButtonIntent.info,
    this.size = ZapButtonSize.regular,
    this.isLoading = false,
    this.fullWidth = false,
    this.color,
  }) : variant = ZapButtonVariant.text;

  // ─── Resolved colors ───────────────────────────────────────────────────

  Color _accent(BuildContext context) {
    if (color != null) return color!;
    switch (intent) {
      case ZapButtonIntent.danger:
        return ZapColors.danger;
      case ZapButtonIntent.safe:
        return ZapColors.safe;
      case ZapButtonIntent.info:
        return ZapColors.info;
      case ZapButtonIntent.warning:
        return ZapColors.warning;
      case ZapButtonIntent.neutral:
        return Theme.of(context).colorScheme.primary;
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || isLoading;
    final accent = _accent(context);
    final height = size == ZapButtonSize.large ? 88.0 : ZapSpacing.minTouchTarget;

    final child = _buildContent(context, accent);

    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled ? null : onPressed,
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        splashColor: accent.withOpacity(0.18),
        highlightColor: accent.withOpacity(0.08),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.xxl),
          decoration: _decorationFor(context, accent, disabled),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );

    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }

  BoxDecoration _decorationFor(BuildContext context, Color accent, bool disabled) {
    final opacity = disabled ? 0.4 : 1.0;
    final radius = BorderRadius.circular(ZapSpacing.radius);

    switch (variant) {
      case ZapButtonVariant.elevated:
        return BoxDecoration(
          color: accent.withOpacity(opacity),
          borderRadius: radius,
        );
      case ZapButtonVariant.tonal:
        return BoxDecoration(
          color: accent.withOpacity(disabled ? 0.06 : 0.15),
          borderRadius: radius,
        );
      case ZapButtonVariant.outlined:
        return BoxDecoration(
          color: Colors.transparent,
          borderRadius: radius,
          border: Border.all(color: accent.withOpacity(opacity), width: 2),
        );
      case ZapButtonVariant.text:
        return BoxDecoration(
          color: Colors.transparent,
          borderRadius: radius,
        );
    }
  }

  Color _foregroundColor(BuildContext context, Color accent) {
    switch (variant) {
      case ZapButtonVariant.elevated:
        return Colors.white;
      case ZapButtonVariant.tonal:
      case ZapButtonVariant.outlined:
      case ZapButtonVariant.text:
        return accent;
    }
  }

  Widget _buildContent(BuildContext context, Color accent) {
    final fg = _foregroundColor(context, accent);

    if (isLoading) {
      return SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          valueColor: AlwaysStoppedAnimation(fg),
        ),
      );
    }

    final labelText = Text(
      label,
      style: ZapTypography.labelLarge.copyWith(
        color: fg,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );

    if (icon == null) return labelText;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: fg, size: 20),
        const SizedBox(width: ZapSpacing.sm),
        labelText,
      ],
    );
  }
}
