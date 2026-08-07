/// SOS long-press ring button — Day 203
///
/// Circular clockwise fill (gray → red) during a fixed 2-second hold.
/// Haptic feedback intensifies with progress; early release shows "Cancelled".
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/colors.dart';

/// Fixed SOS long-press duration — do not change (life-safety spec).
const Duration kSosLongPressDuration = Duration(seconds: 2);

/// Visual phase of the SOS hold interaction.
enum SosLongPressPhase {
  idle,
  holding,
  triggered,
  cancelled,
}

/// Dashboard SOS control with animated progress ring and haptic ramp.
class SosLongPressRingButton extends StatefulWidget {
  final VoidCallback? onTriggered;
  final ValueChanged<SosLongPressPhase>? onPhaseChanged;
  final double size;
  final bool enabled;
  final bool hapticsEnabled;
  final bool reduceMotion;

  const SosLongPressRingButton({
    super.key,
    this.onTriggered,
    this.onPhaseChanged,
    this.size = 80,
    this.enabled = true,
    this.hapticsEnabled = true,
    this.reduceMotion = false,
  });

  @override
  State<SosLongPressRingButton> createState() => _SosLongPressRingButtonState();
}

class _SosLongPressRingButtonState extends State<SosLongPressRingButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  SosLongPressPhase _phase = SosLongPressPhase.idle;
  bool _holding = false;
  int _lastHapticStep = -1;
  bool _cancelFlashVisible = false;

  static const _ringStroke = 5.0;
  static const _ringGap = 6.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: kSosLongPressDuration,
    )..addListener(_onProgress);
    _controller.addStatusListener(_onStatus);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onProgress)
      ..removeStatusListener(_onStatus)
      ..dispose();
    super.dispose();
  }

  void _setPhase(SosLongPressPhase phase) {
    if (_phase == phase) return;
    _phase = phase;
    widget.onPhaseChanged?.call(phase);
  }

  void _onProgress() {
    if (!widget.hapticsEnabled || !_holding) return;
    final step = (_controller.value * 4).floor().clamp(0, 3);
    if (step <= _lastHapticStep) return;
    _lastHapticStep = step;
    switch (step) {
      case 0:
        HapticFeedback.lightImpact();
      case 1:
        HapticFeedback.mediumImpact();
      case 2:
        HapticFeedback.mediumImpact();
      case 3:
        HapticFeedback.heavyImpact();
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !_holding) return;
    _holding = false;
    _setPhase(SosLongPressPhase.triggered);
    if (widget.hapticsEnabled) {
      HapticFeedback.heavyImpact();
    }
    widget.onTriggered?.call();
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      _controller.reset();
      _setPhase(SosLongPressPhase.idle);
    });
  }

  void _beginHold() {
    if (!widget.enabled || _phase == SosLongPressPhase.triggered) return;
    _holding = true;
    _lastHapticStep = -1;
    _cancelFlashVisible = false;
    _setPhase(SosLongPressPhase.holding);
    if (widget.hapticsEnabled) {
      HapticFeedback.selectionClick();
    }
    _controller.forward(from: _controller.value);
  }

  Future<void> _endHold({required bool completed}) async {
    if (!_holding) return;
    _holding = false;
    if (completed) return;

    _controller.stop();
    final hadProgress = _controller.value > 0.02;
    _controller.reset();
    _lastHapticStep = -1;

    if (!hadProgress) {
      _setPhase(SosLongPressPhase.idle);
      return;
    }

    _setPhase(SosLongPressPhase.cancelled);
    if (widget.hapticsEnabled) {
      HapticFeedback.lightImpact();
    }
    setState(() => _cancelFlashVisible = true);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    setState(() => _cancelFlashVisible = false);
    _setPhase(SosLongPressPhase.idle);
  }

  @override
  Widget build(BuildContext context) {
    final outer = widget.size + (_ringGap + _ringStroke) * 2;
    final progress = _controller.value;

    return Semantics(
      label: 'Emergency SOS. Press and hold for 2 seconds to activate.',
      hint: 'Release early to cancel',
      button: true,
      enabled: widget.enabled,
      child: SizedBox(
        width: outer,
        height: outer,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) => _beginHold(),
          onPointerUp: (_) => _endHold(completed: _controller.value >= 1.0),
          onPointerCancel: (_) => _endHold(completed: false),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: Size.square(outer),
                    painter: _SosLongPressRingPainter(
                      progress: widget.reduceMotion
                          ? (progress > 0 ? 1.0 : 0.0)
                          : progress,
                      trackColor: ZapColors.disabled,
                      fillColor: Color.lerp(
                            ZapColors.neutral,
                            ZapColors.danger,
                            progress.clamp(0.0, 1.0),
                          ) ??
                          ZapColors.danger,
                      strokeWidth: _ringStroke,
                    ),
                  ),
                  child!,
                  if (_cancelFlashVisible)
                    Positioned(
                      top: 0,
                      child: _CancelledFlash(),
                    ),
                ],
              );
            },
            child: _SosCore(
              size: widget.size,
              enabled: widget.enabled,
              progress: progress,
            ),
          ),
        ),
      ),
    );
  }
}

class _SosCore extends StatelessWidget {
  final double size;
  final bool enabled;
  final double progress;

  const _SosCore({
    required this.size,
    required this.enabled,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final glow = progress.clamp(0.0, 1.0);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: enabled ? ZapColors.danger : ZapColors.disabled,
        boxShadow: [
          if (enabled && glow > 0)
            BoxShadow(
              color: ZapColors.danger.withOpacity(0.25 + glow * 0.35),
              blurRadius: 12 + glow * 10,
              spreadRadius: 1 + glow * 2,
            ),
        ],
      ),
      child: Icon(
        Icons.emergency_rounded,
        color: enabled ? Colors.white : ZapColors.textMuted,
        size: size * 0.42,
      ),
    );
  }
}

class _CancelledFlash extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 200),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, -8 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: ZapColors.bgElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ZapColors.border),
        ),
        child: const Text(
          'Cancelled',
          style: TextStyle(
            color: ZapColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _SosLongPressRingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color fillColor;
  final double strokeWidth;

  const _SosLongPressRingPainter({
    required this.progress,
    required this.trackColor,
    required this.fillColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final fill = Paint()
      ..color = fillColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, 0, math.pi * 2, false, track);

    if (progress > 0) {
      final sweep = math.pi * 2 * progress.clamp(0.0, 1.0);
      canvas.drawArc(rect, -math.pi / 2, sweep, false, fill);
    }
  }

  @override
  bool shouldRepaint(covariant _SosLongPressRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
