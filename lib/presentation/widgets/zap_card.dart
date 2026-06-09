import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';

/// ZapSafe card surface.
///
/// Used everywhere a grouped piece of content lives — dashboard tiles,
/// contact rows, evidence file blocks. Optionally tappable with a subtle
/// lift animation (scales up to 1.02 and brightens the border) to give
/// the user clear feedback without yelling.
///
/// Usage:
/// ```dart
/// ZapCard(
///   onTap: () => navigateToDetail(),
///   child: Column(children: [...]),
/// )
/// ```
class ZapCard extends StatefulWidget {
  /// Card body. Wrap your content in this.
  final Widget child;

  /// Optional tap handler. If non-null, enables the lift animation.
  final VoidCallback? onTap;

  /// Optional long-press handler.
  final VoidCallback? onLongPress;

  /// Internal padding. Defaults to 16dp on all sides.
  final EdgeInsetsGeometry padding;

  /// External margin. Defaults to no margin (let the parent layout decide).
  final EdgeInsetsGeometry margin;

  /// Override background color. Defaults to [ZapColors.bgCard].
  final Color? backgroundColor;

  /// Override border color. Defaults to [ZapColors.border].
  final Color? borderColor;

  /// Override border width. Defaults to 1.0.
  final double borderWidth;

  /// Override corner radius.
  final double radius;

  /// If true, the border becomes 2px and uses the accent color.
  /// Use for highlighting active/selected cards.
  final bool isHighlighted;

  /// Color used when [isHighlighted] is true. Defaults to danger.
  final Color? highlightColor;

  const ZapCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.all(ZapSpacing.lg),
    this.margin = EdgeInsets.zero,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 1.0,
    this.radius = ZapSpacing.radius,
    this.isHighlighted = false,
    this.highlightColor,
  });

  @override
  State<ZapCard> createState() => _ZapCardState();
}

class _ZapCardState extends State<ZapCard> with SingleTickerProviderStateMixin {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final tappable = widget.onTap != null || widget.onLongPress != null;
    final bg = widget.backgroundColor ?? ZapColors.bgCard;
    final defaultBorder = widget.borderColor ?? ZapColors.border;
    final highlight = widget.highlightColor ?? ZapColors.danger;
    final border = widget.isHighlighted ? highlight : defaultBorder;
    final width = widget.isHighlighted ? 2.0 : widget.borderWidth;

    final card = AnimatedScale(
      scale: _pressed ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: widget.padding,
        decoration: BoxDecoration(
          color: _pressed ? Color.alphaBlend(Colors.white.withOpacity(0.03), bg) : bg,
          borderRadius: BorderRadius.circular(widget.radius),
          border: Border.all(
            color: _pressed ? border.withOpacity(0.85) : border,
            width: width,
          ),
          boxShadow: _pressed && tappable
              ? [
                  BoxShadow(
                    color: highlight.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: widget.child,
      ),
    );

    if (!tappable) {
      return Container(margin: widget.margin, child: card);
    }

    return Container(
      margin: widget.margin,
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: ZapSpacing.minTouchTarget,
          ),
          child: card,
        ),
      ),
    );
  }
}
