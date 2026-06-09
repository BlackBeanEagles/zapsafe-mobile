import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/theme/spacing.dart';

/// Semantic intent of a [ZapBadge]. Determines color.
enum ZapBadgeIntent {
  /// Green pill (safe state, verified contact, low risk).
  safe,

  /// Red pill (CRITICAL, danger, SOS active).
  danger,

  /// Orange pill (ELEVATED, warning).
  warning,

  /// Blue pill (info, neutral status).
  info,

  /// Grey pill (disabled, pending).
  neutral,
}

/// Visual style.
enum ZapBadgeStyle {
  /// Filled pill (high prominence).
  filled,

  /// Tinted background (medium prominence). The most common variant.
  tonal,

  /// Just border (low prominence).
  outlined,
}

/// Size preset.
enum ZapBadgeSize {
  /// Compact — for inline use next to body text.
  small,

  /// Default — standalone status indicator.
  medium,
}

/// A status pill used to label a state — connection, SOS mode, verification.
///
/// Usage:
/// ```dart
/// ZapBadge(label: 'SAFE', intent: ZapBadgeIntent.safe)
/// ZapBadge(label: 'CRITICAL', intent: ZapBadgeIntent.danger, icon: Icons.warning)
/// ZapBadge.outlined(label: 'Tier 1', intent: ZapBadgeIntent.info)
/// ```
class ZapBadge extends StatelessWidget {
  /// Text shown inside the pill.
  final String label;

  /// Semantic color intent.
  final ZapBadgeIntent intent;

  /// Visual prominence (filled / tonal / outlined).
  final ZapBadgeStyle style;

  /// Compact or full size.
  final ZapBadgeSize size;

  /// Optional leading icon.
  final IconData? icon;

  /// If true, a small pulsing dot replaces the icon — used for "live" status.
  final bool pulse;

  const ZapBadge({
    super.key,
    required this.label,
    this.intent = ZapBadgeIntent.neutral,
    this.style = ZapBadgeStyle.tonal,
    this.size = ZapBadgeSize.medium,
    this.icon,
    this.pulse = false,
  });

  const ZapBadge.filled({
    super.key,
    required this.label,
    this.intent = ZapBadgeIntent.danger,
    this.size = ZapBadgeSize.medium,
    this.icon,
    this.pulse = false,
  }) : style = ZapBadgeStyle.filled;

  const ZapBadge.outlined({
    super.key,
    required this.label,
    this.intent = ZapBadgeIntent.neutral,
    this.size = ZapBadgeSize.medium,
    this.icon,
    this.pulse = false,
  }) : style = ZapBadgeStyle.outlined;

  Color _accent() {
    switch (intent) {
      case ZapBadgeIntent.safe:
        return ZapColors.safe;
      case ZapBadgeIntent.danger:
        return ZapColors.danger;
      case ZapBadgeIntent.warning:
        return ZapColors.warning;
      case ZapBadgeIntent.info:
        return ZapColors.info;
      case ZapBadgeIntent.neutral:
        return ZapColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent();
    final isSmall = size == ZapBadgeSize.small;
    final fontSize = isSmall ? 10.0 : 11.0;
    final iconSize = isSmall ? 12.0 : 14.0;
    final padH = isSmall ? ZapSpacing.sm : ZapSpacing.md;
    final padV = isSmall ? 4.0 : 6.0;

    final (bg, fg, borderColor, borderWidth) = switch (style) {
      ZapBadgeStyle.filled => (accent, Colors.white, Colors.transparent, 0.0),
      ZapBadgeStyle.tonal => (
          accent.withOpacity(0.15),
          accent,
          accent.withOpacity(0.3),
          1.0,
        ),
      ZapBadgeStyle.outlined => (Colors.transparent, accent, accent, 1.5),
    };

    Widget? leading;
    if (pulse) {
      leading = _PulsingDot(color: fg);
    } else if (icon != null) {
      leading = Icon(icon, size: iconSize, color: fg);
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(ZapSpacing.radiusPill),
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[
            leading,
            const SizedBox(width: ZapSpacing.xs),
          ],
          Text(
            label,
            style: ZapTypography.labelSmall.copyWith(
              color: fg,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.5 + 0.5 * _ctrl.value),
                blurRadius: 4 + 6 * _ctrl.value,
                spreadRadius: _ctrl.value * 2,
              ),
            ],
          ),
        );
      },
    );
  }
}
