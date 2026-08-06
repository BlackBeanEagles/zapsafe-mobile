/// Persistent mode status card — Day 204
///
/// Expandable dashboard header showing safety mode, battery, and last DCS score.
/// Replaces the small static mode badge on the production dashboard.
library;

import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';

/// User-facing dashboard safety modes (distinct from [AppState] machine).
enum SafetyDashboardMode {
  minimal,
  monitoring,
  elevated,
  high,
  critical,
}

/// Snapshot data rendered by [ModeStatusCard].
class ModeStatusData {
  final SafetyDashboardMode mode;
  final int batteryPercent;
  final double lastDcsScore;
  final bool gpsActive;
  final String gpsInterval;
  final String lastDcsAt;
  final int protectionScore;
  final int activeModels;

  const ModeStatusData({
    required this.mode,
    required this.batteryPercent,
    required this.lastDcsScore,
    this.gpsActive = true,
    this.gpsInterval = '30s',
    this.lastDcsAt = '2 min ago',
    this.protectionScore = 78,
    this.activeModels = 4,
  });
}

extension SafetyDashboardModeX on SafetyDashboardMode {
  String get label => switch (this) {
        SafetyDashboardMode.minimal => 'MINIMAL',
        SafetyDashboardMode.monitoring => 'MONITORING',
        SafetyDashboardMode.elevated => 'ELEVATED',
        SafetyDashboardMode.high => 'HIGH',
        SafetyDashboardMode.critical => 'CRITICAL',
      };

  Color get accent => switch (this) {
        SafetyDashboardMode.minimal => ZapColors.neutral,
        SafetyDashboardMode.monitoring => ZapColors.safe,
        SafetyDashboardMode.elevated => ZapColors.warning,
        SafetyDashboardMode.high => const Color(0xFFFF5A36),
        SafetyDashboardMode.critical => ZapColors.danger,
      };

  IconData get icon => switch (this) {
        SafetyDashboardMode.minimal => Icons.nights_stay_rounded,
        SafetyDashboardMode.monitoring => Icons.shield_rounded,
        SafetyDashboardMode.elevated => Icons.warning_amber_rounded,
        SafetyDashboardMode.high => Icons.priority_high_rounded,
        SafetyDashboardMode.critical => Icons.emergency_rounded,
      };

  String get description => switch (this) {
        SafetyDashboardMode.minimal =>
          'Sensors off · SOS still available · lowest battery use',
        SafetyDashboardMode.monitoring =>
          'Default protection · 4 AI models listening · GPS every 30s',
        SafetyDashboardMode.elevated =>
          'Suspicious signal · faster GPS · contacts on standby',
        SafetyDashboardMode.high =>
          'Strong distress cue · countdown may start · check surroundings',
        SafetyDashboardMode.critical =>
          'Maximum alert · SOS imminent or active · pulse visible',
      };

  bool get shouldPulse => this == SafetyDashboardMode.critical;
}

/// Expandable top-of-dashboard mode status card.
class ModeStatusCard extends StatefulWidget {
  final ModeStatusData data;
  final bool expanded;
  final ValueChanged<bool>? onExpandedChanged;
  final bool reduceMotion;

  const ModeStatusCard({
    super.key,
    required this.data,
    this.expanded = false,
    this.onExpandedChanged,
    this.reduceMotion = false,
  });

  @override
  State<ModeStatusCard> createState() => _ModeStatusCardState();
}

class _ModeStatusCardState extends State<ModeStatusCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  SafetyDashboardMode? _previousMode;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _syncPulse();
    _previousMode = widget.data.mode;
  }

  @override
  void didUpdateWidget(covariant ModeStatusCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.mode != widget.data.mode) {
      _previousMode = oldWidget.data.mode;
    }
    _syncPulse();
  }

  void _syncPulse() {
    if (widget.data.mode.shouldPulse && !widget.reduceMotion) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    widget.onExpandedChanged?.call(!widget.expanded);
  }

  @override
  Widget build(BuildContext context) {
    final mode = widget.data.mode;
    final color = mode.accent;
    final dcsPercent = (widget.data.lastDcsScore * 100).round();

    return Semantics(
      label:
          '${mode.label} mode. Battery ${widget.data.batteryPercent} percent. '
          'Last distress score $dcsPercent percent. '
          '${widget.expanded ? 'Expanded' : 'Collapsed'}. Tap to '
          '${widget.expanded ? 'collapse' : 'expand'} details.',
      button: true,
      expanded: widget.expanded,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final pulse = mode.shouldPulse && !widget.reduceMotion
              ? 0.35 + _pulseController.value * 0.45
              : 0.35;

          return AnimatedContainer(
            duration: widget.reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(ZapSpacing.radius),
              border: Border.all(
                color: color.withOpacity(pulse),
                width: mode.shouldPulse ? 2 : 1.5,
              ),
              boxShadow: mode.shouldPulse && !widget.reduceMotion
                  ? [
                      BoxShadow(
                        color: color.withOpacity(0.2 * _pulseController.value),
                        blurRadius: 12 + 8 * _pulseController.value,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: child,
          );
        },
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _toggleExpanded,
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            child: AnimatedSize(
              duration: widget.reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 280),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CollapsedRow(
                    mode: mode,
                    batteryPercent: widget.data.batteryPercent,
                    dcsPercent: dcsPercent,
                    expanded: widget.expanded,
                    previousMode: _previousMode,
                    reduceMotion: widget.reduceMotion,
                  ),
                  if (widget.expanded)
                    _ExpandedDetails(
                      data: widget.data,
                      color: color,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CollapsedRow extends StatelessWidget {
  final SafetyDashboardMode mode;
  final int batteryPercent;
  final int dcsPercent;
  final bool expanded;
  final SafetyDashboardMode? previousMode;
  final bool reduceMotion;

  const _CollapsedRow({
    required this.mode,
    required this.batteryPercent,
    required this.dcsPercent,
    required this.expanded,
    required this.previousMode,
    required this.reduceMotion,
  });

  @override
  Widget build(BuildContext context) {
    final color = mode.accent;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ZapSpacing.md,
        vertical: ZapSpacing.md,
      ),
      child: Row(
        children: [
          _ModeIconBadge(
            mode: mode,
            previousMode: previousMode,
            reduceMotion: reduceMotion,
          ),
          const SizedBox(width: ZapSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedDefaultTextStyle(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 320),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    letterSpacing: 0.6,
                  ),
                  child: Text(mode.label),
                ),
                const SizedBox(height: 2),
                Text(
                  mode.description,
                  maxLines: expanded ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: ZapSpacing.sm),
          _BatteryChip(percent: batteryPercent),
          const SizedBox(width: ZapSpacing.sm),
          _DcsChip(percent: dcsPercent, color: color),
          const SizedBox(width: ZapSpacing.xs),
          AnimatedRotation(
            turns: expanded ? 0.5 : 0,
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 220),
            child: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: ZapColors.textSecondary,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeIconBadge extends StatelessWidget {
  final SafetyDashboardMode mode;
  final SafetyDashboardMode? previousMode;
  final bool reduceMotion;

  const _ModeIconBadge({
    required this.mode,
    required this.previousMode,
    required this.reduceMotion,
  });

  @override
  Widget build(BuildContext context) {
    final color = mode.accent;

    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(
        begin: previousMode?.accent ?? color,
        end: color,
      ),
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (context, animatedColor, child) {
        final c = animatedColor ?? color;
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: c.withOpacity(0.18),
            shape: BoxShape.circle,
            border: Border.all(color: c.withOpacity(0.55)),
          ),
          child: Icon(mode.icon, color: c, size: 20),
        );
      },
    );
  }
}

class _BatteryChip extends StatelessWidget {
  final int percent;

  const _BatteryChip({required this.percent});

  IconData get _icon {
    if (percent <= 10) return Icons.battery_0_bar_rounded;
    if (percent <= 25) return Icons.battery_2_bar_rounded;
    if (percent <= 50) return Icons.battery_4_bar_rounded;
    if (percent <= 75) return Icons.battery_5_bar_rounded;
    return Icons.battery_full_rounded;
  }

  Color get _color {
    if (percent <= 10) return ZapColors.danger;
    if (percent <= 20) return ZapColors.warning;
    return ZapColors.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Battery $percent percent',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: ZapColors.bgElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ZapColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon, size: 16, color: _color),
            const SizedBox(width: 4),
            Text(
              '$percent%',
              style: TextStyle(
                color: _color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DcsChip extends StatelessWidget {
  final int percent;
  final Color color;

  const _DcsChip({required this.percent, required this.color});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Last distress score $percent percent',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.graphic_eq_rounded, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              'DCS $percent%',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpandedDetails extends StatelessWidget {
  final ModeStatusData data;
  final Color color;

  const _ExpandedDetails({required this.data, required this.color});

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Protection Score', '${data.protectionScore}/100'),
      ('GPS', data.gpsActive ? 'Active · ${data.gpsInterval} interval' : 'Paused'),
      ('Last DCS reading', data.lastDcsAt),
      ('AI models active', '${data.activeModels}/4'),
      ('Mode guidance', data.mode.description),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ZapSpacing.md,
        0,
        ZapSpacing.md,
        ZapSpacing.md,
      ),
      child: Column(
        children: [
          Divider(color: color.withOpacity(0.25), height: 1),
          const SizedBox(height: ZapSpacing.sm),
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(
                      row.$1,
                      style: const TextStyle(
                        color: ZapColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.$2,
                      style: const TextStyle(
                        color: ZapColors.textPrimary,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
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
