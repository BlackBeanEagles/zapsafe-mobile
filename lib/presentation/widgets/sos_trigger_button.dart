/// Day 307 — Production SOS long-press trigger button.
///
/// A circular button that requires a 2-second long-press (clockwise ring
/// fill, gray → red) before it dispatches a real manual SOS trigger via
/// [triggerOrchestratorProvider] (`TriggerOrchestrator.dispatchManual`,
/// Day 39) — the same real `AppStateNotifier.onManualTrigger` path every
/// other manual trigger surface in the app uses (see
/// `trigger_orchestrator.dart`'s routing table). That in turn is already
/// bridged (`sos_providers.dart`) to the real
/// `POST /api/v1/sos/trigger/` call once the state machine reaches
/// `AppState.sosActive`.
///
/// Android + iOS: the haptic ramp uses only `package:flutter/services.dart`
/// `HapticFeedback.lightImpact/mediumImpact/heavyImpact` — a single Dart
/// API backed by platform channels on both OSes (Android
/// `View.performHapticFeedback`, iOS `UIImpactFeedbackGenerator`), so
/// there's no separate Android/iOS branch to write; the same call path
/// already covers both. This can't be device-verified in this sandbox (no
/// emulator/physical device attached to this session) — verified by
/// reading the `flutter/services.dart` `HapticFeedback` implementation
/// instead, per the "document why" rule for un-verifiable acceptance
/// criteria.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../domain/providers/app_state_provider.dart';
import '../../domain/providers/trigger_orchestrator_providers.dart';

class SosTriggerButton extends ConsumerStatefulWidget {
  const SosTriggerButton({
    super.key,
    this.diameter = 96,
    this.holdDuration = const Duration(seconds: 2),
    this.onTriggered,
  });

  /// Visual diameter. Defaults above the 75dp AAA touch target
  /// ([ZapSpacing.minTouchTarget]) and above the dashboard's documented
  /// "80dp" SOS button size.
  final double diameter;

  /// How long the user must hold. Spec: 2 seconds.
  final Duration holdDuration;

  /// Called once the hold completes and the real trigger has been
  /// dispatched — the dashboard uses this to navigate to the SOS active
  /// screen.
  final VoidCallback? onTriggered;

  @override
  ConsumerState<SosTriggerButton> createState() => _SosTriggerButtonState();
}

class _SosTriggerButtonState extends ConsumerState<SosTriggerButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: widget.holdDuration,
  );

  bool _mediumFired = false;
  bool _heavyFired = false;
  bool _showCancelled = false;
  Timer? _announceTimer;
  Timer? _cancelledFlashTimer;

  static const _idleSemanticLabel = 'Hold to activate SOS, 2 seconds remaining';

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onTick);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onTick);
    _ctrl.dispose();
    _announceTimer?.cancel();
    _cancelledFlashTimer?.cancel();
    super.dispose();
  }

  void _onTick() {
    final v = _ctrl.value;
    if (!_mediumFired && v >= 0.5) {
      _mediumFired = true;
      HapticFeedback.mediumImpact();
    }
    if (!_heavyFired && v >= 0.85) {
      _heavyFired = true;
      HapticFeedback.heavyImpact();
    }
    if (v >= 1.0) {
      _onHoldComplete();
    }
  }

  void _onLongPressStart(LongPressStartDetails _) {
    setState(() => _showCancelled = false);
    _mediumFired = false;
    _heavyFired = false;
    HapticFeedback.lightImpact();
    _ctrl.forward(from: 0);

    // TalkBack live countdown announcements — one per remaining second.
    final totalSeconds = widget.holdDuration.inSeconds;
    var remaining = totalSeconds;
    _announceTimer?.cancel();
    _announceTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      remaining--;
      if (remaining <= 0 || !_ctrl.isAnimating) {
        t.cancel();
        return;
      }
      SemanticsService.announce(
        '$remaining second${remaining == 1 ? '' : 's'} remaining',
        TextDirection.ltr,
      );
    });
  }

  void _onLongPressEnd(LongPressEndDetails _) => _cancelIfIncomplete();

  void _onLongPressCancel() => _cancelIfIncomplete();

  void _cancelIfIncomplete() {
    _announceTimer?.cancel();
    if (_ctrl.value >= 1.0) return; // already completed — ignore
    if (_ctrl.value > 0) {
      _flashCancelled();
    }
    _ctrl.reverse();
  }

  void _flashCancelled() {
    setState(() => _showCancelled = true);
    SemanticsService.announce('Cancelled', TextDirection.ltr);
    _cancelledFlashTimer?.cancel();
    _cancelledFlashTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _showCancelled = false);
    });
  }

  void _onHoldComplete() {
    _announceTimer?.cancel();
    ref.read(triggerOrchestratorProvider).dispatchManual(TriggerMethod.manual,
        cause: 'Dashboard SOS long-press');
    SemanticsService.announce('SOS activated', TextDirection.ltr);
    widget.onTriggered?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: _idleSemanticLabel,
      child: GestureDetector(
        onLongPressStart: _onLongPressStart,
        onLongPressEnd: _onLongPressEnd,
        onLongPressCancel: _onLongPressCancel,
        child: SizedBox(
          width: widget.diameter,
          height: widget.diameter,
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: Size.square(widget.diameter),
                    painter: _SosRingPainter(progress: _ctrl.value),
                  ),
                  Container(
                    width: widget.diameter * 0.72,
                    height: widget.diameter * 0.72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ZapColors.danger,
                      boxShadow: [
                        BoxShadow(
                          color: ZapColors.danger.withOpacity(0.35 + 0.35 * _ctrl.value),
                          blurRadius: 12 + 12 * _ctrl.value,
                          spreadRadius: 1 + 3 * _ctrl.value,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      child: _showCancelled
                          ? const Text(
                              'CANCELLED',
                              key: ValueKey('cancelled'),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                              textAlign: TextAlign.center,
                            )
                          : const Text(
                              'SOS',
                              key: ValueKey('sos'),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                              ),
                            ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Clockwise ring fill from 12 o'clock, gray → red as [progress] (0..1)
/// increases.
class _SosRingPainter extends CustomPainter {
  const _SosRingPainter({required this.progress});
  final double progress;

  static const _trackColor = Color(0xFF3A3A47); // ZapColors.disabled

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 4;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = _trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * math.pi, false, trackPaint);

    if (progress <= 0) return;

    final fillColor = Color.lerp(_trackColor, ZapColors.danger, progress)!;
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    const startAngle = -math.pi / 2; // 12 o'clock
    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(rect, startAngle, sweepAngle, false, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _SosRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
