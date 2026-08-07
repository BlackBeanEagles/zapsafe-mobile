/// Day 55 — Detection Event Screen.
///
/// Route: /detection-events
///
/// Demonstrates and tests the detection event log endpoint
/// (POST + GET /api/v1/ml/detection-events/).
///
/// Two sections:
///   1. LOG EVENT  — manually submit a simulated DCS detection event.
///      Probe values (tier, mode, inference_ms) are sourced from Day 52's
///      [phoneCapabilityProvider] so the payload is realistic.
///
///   2. EVENT HISTORY — live list of the user's submitted events with
///      client-side filter chips (All / Scream / Motion / Scene / DCS).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/services/detection_event_service.dart';
import '../../data/services/phone_capability_detector.dart';
import '../../domain/providers/detection_event_providers.dart';
import '../../domain/providers/inference_providers.dart';
import '../navigation/app_router.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';

// ─── Screen ───────────────────────────────────────────────────────────────────

class Day55DetectionEventScreen extends ConsumerStatefulWidget {
  const Day55DetectionEventScreen({super.key});

  @override
  ConsumerState<Day55DetectionEventScreen> createState() =>
      _Day55DetectionEventScreenState();
}

class _Day55DetectionEventScreenState
    extends ConsumerState<Day55DetectionEventScreen> {
  // ── Form state ────────────────────────────────────────────────────────────
  DetectionEventType _eventType  = DetectionEventType.scream;
  double             _confidence = 0.87;
  bool               _triggeredSos = false;

  // ── Submit state ──────────────────────────────────────────────────────────
  AsyncValue<DetectionEventRecord>? _submitState;

  // ── History filter ────────────────────────────────────────────────────────
  /// null = show all; set value = filter to one type
  DetectionEventType? _historyFilter;

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> _submit(CapabilityProbeResult probe) async {
    setState(() => _submitState = const AsyncLoading());
    try {
      final svc = ref.read(detectionEventServiceProvider);
      final record = await svc.submit(
        eventType:     _eventType,
        confidence:    _confidence,
        tier:          probe.tier.name,
        detectionMode: probe.shouldUseAi ? 'ai' : 'heuristic',
        inferenceMs:   probe.inferenceMs,
        triggeredSos:  _triggeredSos,
      );
      if (!mounted) return;
      setState(() => _submitState = AsyncData(record));
      ref.invalidate(detectionEventHistoryProvider);
    } catch (e, st) {
      if (!mounted) return;
      setState(() => _submitState = AsyncError(e, st));
    }
  }

  void _resetSubmit() => setState(() => _submitState = null);

  // ── Helpers ───────────────────────────────────────────────────────────────

  List<DetectionEventRecord> _applyFilter(List<DetectionEventRecord> all) {
    if (_historyFilter == null) return all;
    return all.where((e) => e.eventType == _historyFilter).toList();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final capAsync     = ref.watch(phoneCapabilityProvider);
    final historyAsync = ref.watch(detectionEventHistoryProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: ZapColors.bgPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: ZapColors.textPrimary),
          onPressed: () => context.go(AppRoutes.home),
        ),
        title: Row(
          children: [
            const Text('Detection Events',
                style: TextStyle(color: ZapColors.textPrimary)),
            const SizedBox(width: ZapSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: ZapSpacing.sm, vertical: 2),
              decoration: BoxDecoration(
                color: ZapColors.danger.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'DAY 55',
                style: ZapTypography.labelSmall.copyWith(
                  color: ZapColors.danger,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Log event form ─────────────────────────────────────────────
            const _SectionLabel('LOG EVENT'),
            const SizedBox(height: ZapSpacing.sm),
            _LogEventForm(
              selectedType:  _eventType,
              confidence:    _confidence,
              triggeredSos:  _triggeredSos,
              submitState:   _submitState,
              capAsync:      capAsync,
              onTypeChanged: (t) => setState(() {
                _eventType   = t;
                _submitState = null;
              }),
              onConfidenceChanged: (v) => setState(() => _confidence = v),
              onSosToggled: (v) => setState(() => _triggeredSos = v),
              onSubmit: () => capAsync.whenData((p) => _submit(p)),
              onReset:  _resetSubmit,
            ),
            const SizedBox(height: ZapSpacing.xl),

            // ── History ────────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const _SectionLabel('EVENT HISTORY'),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded,
                      color: ZapColors.textSecondary, size: 18),
                  tooltip: 'Refresh',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () =>
                      ref.invalidate(detectionEventHistoryProvider),
                ),
              ],
            ),
            const SizedBox(height: ZapSpacing.sm),

            // Filter chips
            _FilterBar(
              selected: _historyFilter,
              onSelected: (t) => setState(() => _historyFilter = t),
            ),
            const SizedBox(height: ZapSpacing.sm),

            // History list
            historyAsync.when(
              loading: () => const Column(
                children: [
                  _SkeletonCard(height: 80),
                  SizedBox(height: ZapSpacing.sm),
                  _SkeletonCard(height: 80),
                  SizedBox(height: ZapSpacing.sm),
                  _SkeletonCard(height: 80),
                ],
              ),
              error: (e, _) => _HistoryError(
                error:   e.toString(),
                onRetry: () => ref.invalidate(detectionEventHistoryProvider),
              ),
              data: (history) {
                final filtered = _applyFilter(history.events);
                if (filtered.isEmpty) {
                  return _EmptyHistory(filtered: _historyFilter != null);
                }
                return Column(
                  children: filtered
                      .map((r) => Padding(
                            padding: const EdgeInsets.only(
                                bottom: ZapSpacing.sm),
                            child: _EventCard(record: r),
                          ))
                      .toList(),
                );
              },
            ),
            const SizedBox(height: ZapSpacing.xxxl),
          ],
        ),
      ),
    );
  }
}

// ─── Section helpers ──────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: ZapTypography.labelSmall.copyWith(
        color: ZapColors.textSecondary,
        letterSpacing: 1.1,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: SizedBox(
        height: height,
        child: Center(
          child: Container(
            width: double.infinity,
            height: 14,
            margin: const EdgeInsets.symmetric(horizontal: ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.bgElevated,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Log event form ───────────────────────────────────────────────────────────

class _LogEventForm extends StatelessWidget {
  const _LogEventForm({
    required this.selectedType,
    required this.confidence,
    required this.triggeredSos,
    required this.submitState,
    required this.capAsync,
    required this.onTypeChanged,
    required this.onConfidenceChanged,
    required this.onSosToggled,
    required this.onSubmit,
    required this.onReset,
  });

  final DetectionEventType selectedType;
  final double confidence;
  final bool triggeredSos;
  final AsyncValue<DetectionEventRecord>? submitState;
  final AsyncValue<CapabilityProbeResult> capAsync;
  final ValueChanged<DetectionEventType> onTypeChanged;
  final ValueChanged<double> onConfidenceChanged;
  final ValueChanged<bool> onSosToggled;
  final VoidCallback onSubmit;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final isLoading = submitState is AsyncLoading;
    final isSuccess = submitState is AsyncData<DetectionEventRecord>;

    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Event type chips ──────────────────────────────────────────────
          Text(
            'Event type',
            style: ZapTypography.labelSmall
                .copyWith(color: ZapColors.textSecondary),
          ),
          const SizedBox(height: ZapSpacing.sm),
          Wrap(
            spacing: ZapSpacing.xs,
            children: DetectionEventType.values.map((t) {
              final active = selectedType == t;
              final color  = _typeColor(t);
              return GestureDetector(
                onTap: isLoading ? null : () => onTypeChanged(t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: ZapSpacing.sm, vertical: 6),
                  decoration: BoxDecoration(
                    color: active
                        ? color.withOpacity(0.18)
                        : ZapColors.bgElevated,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: active
                          ? color
                          : ZapColors.textSecondary.withOpacity(0.2),
                      width: active ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_typeIcon(t),
                          color: active ? color : ZapColors.textSecondary,
                          size: 14),
                      const SizedBox(width: ZapSpacing.xs),
                      Text(
                        t.label,
                        style: ZapTypography.labelSmall.copyWith(
                          color: active ? color : ZapColors.textSecondary,
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w400,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: ZapSpacing.md),

          // ── Confidence slider ─────────────────────────────────────────────
          Row(
            children: [
              Text(
                'Confidence',
                style: ZapTypography.labelSmall
                    .copyWith(color: ZapColors.textSecondary),
              ),
              const Spacer(),
              Text(
                confidence.toStringAsFixed(2),
                style: ZapTypography.labelSmall.copyWith(
                  fontFamily: 'IBMPlexMono',
                  color: _confidenceColor(confidence),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor:   _confidenceColor(confidence),
              thumbColor:         _confidenceColor(confidence),
              inactiveTrackColor: ZapColors.bgElevated,
              overlayColor:
                  _confidenceColor(confidence).withOpacity(0.12),
              trackHeight: 4,
            ),
            child: Slider(
              value:    confidence,
              min:      0.0,
              max:      1.0,
              divisions: 100,
              onChanged: isLoading ? null : onConfidenceChanged,
            ),
          ),
          const SizedBox(height: ZapSpacing.xs),

          // ── Triggered SOS switch ──────────────────────────────────────────
          Row(
            children: [
              Text(
                'Triggered SOS',
                style: ZapTypography.labelSmall
                    .copyWith(color: ZapColors.textSecondary),
              ),
              const Spacer(),
              Switch(
                value:        triggeredSos,
                onChanged:    isLoading ? null : onSosToggled,
                activeColor:  ZapColors.danger,
                inactiveThumbColor: ZapColors.textSecondary,
                inactiveTrackColor:
                    ZapColors.bgElevated,
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.xs),

          // ── Probe values row ──────────────────────────────────────────────
          capAsync.when(
            loading: () => const SizedBox.shrink(),
            error:   (_, __) => Text(
              'Run Day 52 probe first to populate tier / mode.',
              style: ZapTypography.bodySmall
                  .copyWith(color: ZapColors.textSecondary),
            ),
            data: (probe) => Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: ZapSpacing.sm, vertical: ZapSpacing.xs),
              decoration: BoxDecoration(
                color: ZapColors.bgElevated,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  _ProbeChip(
                    label: probe.tier.name.toUpperCase(),
                    color: _tierColor(probe.tier),
                  ),
                  const SizedBox(width: ZapSpacing.xs),
                  _ProbeChip(
                    label: probe.shouldUseAi ? 'AI' : 'HEURISTIC',
                    color: probe.shouldUseAi
                        ? ZapColors.safe
                        : ZapColors.warning,
                  ),
                  const SizedBox(width: ZapSpacing.xs),
                  _ProbeChip(
                    label: '${probe.inferenceMs.toStringAsFixed(0)} ms',
                    color: ZapColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: ZapSpacing.md),

          // ── Submit result / button ────────────────────────────────────────
          if (submitState is AsyncLoading)
            Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: ZapColors.danger, strokeWidth: 2),
                ),
                const SizedBox(width: ZapSpacing.sm),
                Text(
                  'Logging event…',
                  style: ZapTypography.bodySmall
                      .copyWith(color: ZapColors.textSecondary),
                ),
              ],
            )
          else if (isSuccess) ...[
            _SuccessRow(
              record:   (submitState as AsyncData<DetectionEventRecord>).value,
              onLogAnother: onReset,
            ),
          ] else ...[
            if (submitState is AsyncError)
              Padding(
                padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
                child: Text(
                  'Error: ${(submitState as AsyncError).error}',
                  style: ZapTypography.bodySmall
                      .copyWith(color: ZapColors.danger),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ZapButton(
              label:   'Log Detection Event',
              icon:    Icons.sensors_rounded,
              onPressed: capAsync.hasValue ? onSubmit : null,
              variant: ZapButtonVariant.elevated,
              intent:  ZapButtonIntent.danger,
            ),
          ],
        ],
      ),
    );
  }

  Color _typeColor(DetectionEventType t) {
    switch (t) {
      case DetectionEventType.scream: return ZapColors.danger;
      case DetectionEventType.motion: return ZapColors.warning;
      case DetectionEventType.scene:  return ZapColors.info;
      case DetectionEventType.dcs:    return ZapColors.safe;
      case DetectionEventType.gunshot: return ZapColors.danger;
      case DetectionEventType.motionB: return ZapColors.warning;
      case DetectionEventType.crowdPanic: return ZapColors.danger;
      case DetectionEventType.vehicleCrash: return ZapColors.danger;
      case DetectionEventType.kConfinement: return ZapColors.warning;
    }
  }

  IconData _typeIcon(DetectionEventType t) {
    switch (t) {
      case DetectionEventType.scream: return Icons.mic_rounded;
      case DetectionEventType.motion: return Icons.directions_run_rounded;
      case DetectionEventType.scene:  return Icons.camera_alt_rounded;
      case DetectionEventType.dcs:    return Icons.hub_rounded;
      case DetectionEventType.gunshot: return Icons.gpp_bad_rounded;
      case DetectionEventType.motionB: return Icons.directions_run_rounded;
      case DetectionEventType.crowdPanic: return Icons.groups_rounded;
      case DetectionEventType.vehicleCrash: return Icons.car_crash_rounded;
      case DetectionEventType.kConfinement: return Icons.lock_clock_rounded;
    }
  }

  Color _confidenceColor(double v) {
    if (v >= 0.85) return ZapColors.danger;
    if (v >= 0.65) return ZapColors.warning;
    return ZapColors.safe;
  }

  Color _tierColor(PhoneCapabilityTier t) {
    switch (t) {
      case PhoneCapabilityTier.high:   return ZapColors.safe;
      case PhoneCapabilityTier.medium: return ZapColors.info;
      case PhoneCapabilityTier.low:    return ZapColors.warning;
    }
  }
}

class _ProbeChip extends StatelessWidget {
  const _ProbeChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: ZapTypography.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 10,
          fontFamily: 'IBMPlexMono',
        ),
      ),
    );
  }
}

class _SuccessRow extends StatelessWidget {
  const _SuccessRow({required this.record, required this.onLogAnother});
  final DetectionEventRecord record;
  final VoidCallback onLogAnother;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.check_circle_rounded,
            color: ZapColors.safe, size: 20),
        const SizedBox(width: ZapSpacing.sm),
        Expanded(
          child: Text(
            '${record.eventTypeDisplay} logged · '
            'conf ${record.confidence.toStringAsFixed(2)}',
            style: ZapTypography.bodySmall
                .copyWith(color: ZapColors.safe),
          ),
        ),
        GestureDetector(
          onTap: onLogAnother,
          child: Text(
            'Log another',
            style: ZapTypography.labelSmall.copyWith(
              color: ZapColors.info,
              decoration: TextDecoration.underline,
              decorationColor: ZapColors.info,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Filter bar ───────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onSelected});
  final DetectionEventType? selected;
  final ValueChanged<DetectionEventType?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // "All" chip
          _FilterChip(
            label:    'All',
            icon:     Icons.filter_list_rounded,
            active:   selected == null,
            color:    ZapColors.textSecondary,
            onTap:    () => onSelected(null),
          ),
          const SizedBox(width: ZapSpacing.xs),
          ...DetectionEventType.values.map((t) => Padding(
                padding: const EdgeInsets.only(right: ZapSpacing.xs),
                child: _FilterChip(
                  label:  t.label,
                  icon:   _typeIcon(t),
                  active: selected == t,
                  color:  _typeColor(t),
                  onTap:  () => onSelected(selected == t ? null : t),
                ),
              )),
        ],
      ),
    );
  }

  Color _typeColor(DetectionEventType t) {
    switch (t) {
      case DetectionEventType.scream: return ZapColors.danger;
      case DetectionEventType.motion: return ZapColors.warning;
      case DetectionEventType.scene:  return ZapColors.info;
      case DetectionEventType.dcs:    return ZapColors.safe;
      case DetectionEventType.gunshot: return ZapColors.danger;
      case DetectionEventType.motionB: return ZapColors.warning;
      case DetectionEventType.crowdPanic: return ZapColors.danger;
      case DetectionEventType.vehicleCrash: return ZapColors.danger;
      case DetectionEventType.kConfinement: return ZapColors.warning;
    }
  }

  IconData _typeIcon(DetectionEventType t) {
    switch (t) {
      case DetectionEventType.scream: return Icons.mic_rounded;
      case DetectionEventType.motion: return Icons.directions_run_rounded;
      case DetectionEventType.scene:  return Icons.camera_alt_rounded;
      case DetectionEventType.dcs:    return Icons.hub_rounded;
      case DetectionEventType.gunshot: return Icons.gpp_bad_rounded;
      case DetectionEventType.motionB: return Icons.directions_run_rounded;
      case DetectionEventType.crowdPanic: return Icons.groups_rounded;
      case DetectionEventType.vehicleCrash: return Icons.car_crash_rounded;
      case DetectionEventType.kConfinement: return Icons.lock_clock_rounded;
    }
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
            horizontal: ZapSpacing.sm, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.15) : ZapColors.bgElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? color
                : ZapColors.textSecondary.withOpacity(0.25),
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 13,
                color: active ? color : ZapColors.textSecondary),
            const SizedBox(width: ZapSpacing.xs),
            Text(
              label,
              style: ZapTypography.labelSmall.copyWith(
                color: active ? color : ZapColors.textSecondary,
                fontWeight:
                    active ? FontWeight.w700 : FontWeight.w400,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── History cards ────────────────────────────────────────────────────────────

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.filtered});
  final bool filtered;

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Column(
        children: [
          Icon(
            filtered
                ? Icons.filter_alt_off_rounded
                : Icons.sensors_off_rounded,
            color: ZapColors.textSecondary,
            size: 36,
          ),
          const SizedBox(height: ZapSpacing.sm),
          Text(
            filtered ? 'No events match this filter' : 'No events yet',
            style: ZapTypography.labelLarge
                .copyWith(color: ZapColors.textSecondary),
          ),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            filtered
                ? 'Try a different filter or log an event above.'
                : 'Log your first detection event above.',
            style: ZapTypography.bodySmall
                .copyWith(color: ZapColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _HistoryError extends StatelessWidget {
  const _HistoryError({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ZapCard(
          child: Row(
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: ZapColors.danger, size: 24),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: Text(
                  error,
                  style: ZapTypography.bodySmall
                      .copyWith(color: ZapColors.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        ZapButton(
          label:     'Retry',
          icon:      Icons.refresh_rounded,
          onPressed: onRetry,
          variant:   ZapButtonVariant.elevated,
          intent:    ZapButtonIntent.info,
        ),
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.record});
  final DetectionEventRecord record;

  Color get _typeColor {
    switch (record.eventType) {
      case DetectionEventType.scream: return ZapColors.danger;
      case DetectionEventType.motion: return ZapColors.warning;
      case DetectionEventType.scene:  return ZapColors.info;
      case DetectionEventType.dcs:    return ZapColors.safe;
      case DetectionEventType.gunshot: return ZapColors.danger;
      case DetectionEventType.motionB: return ZapColors.warning;
      case DetectionEventType.crowdPanic: return ZapColors.danger;
      case DetectionEventType.vehicleCrash: return ZapColors.danger;
      case DetectionEventType.kConfinement: return ZapColors.warning;
    }
  }

  IconData get _typeIcon {
    switch (record.eventType) {
      case DetectionEventType.scream: return Icons.mic_rounded;
      case DetectionEventType.motion: return Icons.directions_run_rounded;
      case DetectionEventType.scene:  return Icons.camera_alt_rounded;
      case DetectionEventType.dcs:    return Icons.hub_rounded;
      case DetectionEventType.gunshot: return Icons.gpp_bad_rounded;
      case DetectionEventType.motionB: return Icons.directions_run_rounded;
      case DetectionEventType.crowdPanic: return Icons.groups_rounded;
      case DetectionEventType.vehicleCrash: return Icons.car_crash_rounded;
      case DetectionEventType.kConfinement: return Icons.lock_clock_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM · HH:mm');
    final confPct = (record.confidence * 100).round();

    return ZapCard(
      child: Row(
        children: [
          // Type icon dot
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _typeColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(_typeIcon, color: _typeColor, size: 20),
          ),
          const SizedBox(width: ZapSpacing.md),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Type badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: _typeColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        record.eventType.label.toUpperCase(),
                        style: ZapTypography.labelSmall.copyWith(
                          color: _typeColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 9,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(width: ZapSpacing.xs),
                    // Mode badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: (record.detectionMode == 'ai'
                                ? ZapColors.safe
                                : ZapColors.warning)
                            .withOpacity(0.10),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        record.detectionMode == 'ai'
                            ? 'AI'
                            : 'HEURISTIC',
                        style: ZapTypography.labelSmall.copyWith(
                          color: record.detectionMode == 'ai'
                              ? ZapColors.safe
                              : ZapColors.warning,
                          fontWeight: FontWeight.w700,
                          fontSize: 9,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    if (record.triggeredSos) ...[
                      const SizedBox(width: ZapSpacing.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: ZapColors.danger.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          'SOS',
                          style: ZapTypography.labelSmall.copyWith(
                            color: ZapColors.danger,
                            fontWeight: FontWeight.w700,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                // Confidence + confidence bar
                Row(
                  children: [
                    Text(
                      '$confPct% confidence',
                      style: ZapTypography.bodyMedium.copyWith(
                        color: ZapColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: ZapSpacing.sm),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: record.confidence,
                          minHeight: 4,
                          backgroundColor: ZapColors.bgElevated,
                          color: _typeColor,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  '${record.inferenceMs.toStringAsFixed(1)} ms · '
                  '${record.tier.toUpperCase()}',
                  style: ZapTypography.bodySmall.copyWith(
                    color: ZapColors.textSecondary,
                    fontSize: 11,
                    fontFamily: 'IBMPlexMono',
                  ),
                ),
              ],
            ),
          ),

          // Timestamp
          const SizedBox(width: ZapSpacing.sm),
          Text(
            fmt.format(record.createdAt),
            style: ZapTypography.labelSmall.copyWith(
              fontFamily: 'IBMPlexMono',
              color: ZapColors.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
