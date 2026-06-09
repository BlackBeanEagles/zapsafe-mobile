import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/theme/spacing.dart';

/// The Protection Score ring — the dashboard's hero widget.
///
/// Shows the user's current score (0–100) as a circular gauge. The color
/// reflects readiness:
/// - 80-100  → safe (green)
/// - 50-79   → info (blue)
/// - 20-49   → warning (orange)
/// -  0-19   → danger (red)
///
/// Both the ring stroke and the number animate smoothly when the score
/// changes (e.g. user adds a Tier 2 contact, score jumps from 70 → 85).
///
/// Usage:
/// ```dart
/// ProtectionScoreRing(
///   score: user.protectionScore,
///   size: 200,
///   onTap: () => navigateToScoreDetail(),
/// )
/// ```
class ProtectionScoreRing extends StatefulWidget {
  /// 0..100. Values outside this range are clamped.
  final int score;

  /// Diameter of the ring (and the widget). Default 180dp.
  final double size;

  /// Stroke width of the progress arc. Auto-scales with [size] if null.
  final double? strokeWidth;

  /// Optional tap handler (e.g. open Protection Score detail screen).
  final VoidCallback? onTap;

  /// Animation duration when score changes.
  final Duration duration;

  /// Hide the inner score text + label.
  final bool showLabel;

  /// Override the label text. Default: "PROTECTION".
  final String label;

  const ProtectionScoreRing({
    super.key,
    required this.score,
    this.size = 180,
    this.strokeWidth,
    this.onTap,
    this.duration = const Duration(milliseconds: 1100),
    this.showLabel = true,
    this.label = 'PROTECTION',
  });

  @override
  State<ProtectionScoreRing> createState() => _ProtectionScoreRingState();
}

class _ProtectionScoreRingState extends State<ProtectionScoreRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  int _prevScore = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _anim = Tween<double>(begin: 0, end: widget.score.toDouble().clamp(0, 100))
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
    _prevScore = widget.score;
  }

  @override
  void didUpdateWidget(covariant ProtectionScoreRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.score != oldWidget.score) {
      _anim = Tween<double>(
        begin: _prevScore.toDouble().clamp(0, 100),
        end: widget.score.toDouble().clamp(0, 100),
      ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
      _ctrl
        ..reset()
        ..forward();
      _prevScore = widget.score;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Score → tier color.
  static Color colorForScore(double score) {
    if (score >= 80) return ZapColors.safe;
    if (score >= 50) return ZapColors.info;
    if (score >= 20) return ZapColors.warning;
    return ZapColors.danger;
  }

  static String tierLabel(double score) {
    if (score >= 80) return 'EXCELLENT';
    if (score >= 50) return 'GOOD';
    if (score >= 20) return 'NEEDS WORK';
    return 'AT RISK';
  }

  @override
  Widget build(BuildContext context) {
    final strokeWidth = widget.strokeWidth ?? (widget.size * 0.075);

    final ring = AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final v = _anim.value;
        final color = colorForScore(v);
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _RingPainter(
              progress: v / 100,
              color: color,
              trackColor: ZapColors.bgSurface,
              strokeWidth: strokeWidth,
            ),
            child: widget.showLabel
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          v.round().toString(),
                          style: ZapTypography.displayLarge.copyWith(
                            color: color,
                            fontSize: widget.size * 0.32,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                        SizedBox(height: widget.size * 0.02),
                        Text(
                          widget.label,
                          style: ZapTypography.labelSmall.copyWith(
                            color: ZapColors.textSecondary,
                            letterSpacing: 2,
                            fontSize: widget.size * 0.06,
                          ),
                        ),
                        SizedBox(height: widget.size * 0.01),
                        Text(
                          tierLabel(v),
                          style: ZapTypography.labelSmall.copyWith(
                            color: color,
                            letterSpacing: 1.5,
                            fontSize: widget.size * 0.055,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  )
                : null,
          ),
        );
      },
    );

    if (widget.onTap == null) return ring;

    return InkResponse(
      onTap: widget.onTap,
      radius: widget.size / 2 + ZapSpacing.md,
      child: ring,
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress; // 0..1
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track ring (background)
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweep = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // start at top (12 o'clock)
      sweep,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth;
}
