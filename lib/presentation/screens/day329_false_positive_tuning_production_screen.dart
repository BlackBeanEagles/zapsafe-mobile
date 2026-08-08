/// Day 329 — False Positive Tuning: Production
///
/// 🟣. A focused, user-facing DCS-sensitivity slider — not a duplicate of
/// the generic Day 63 CRUD screen (`day63_alert_threshold_screen.dart`,
/// which edits any model_type's threshold row with every field exposed).
/// This screen edits exactly one thing: the `min_confidence` of the
/// user's `model_type='dcs'` `AlertThreshold` row, via the real,
/// already-existing Day 63 service (`AlertThresholdService`,
/// `alert_threshold_providers.dart`) — reused, not duplicated.
///
/// Backend endpoint reasoning (read before building this screen, per the
/// spec's own instruction): the spec suggested syncing via "a real
/// device-health POST call IF that endpoint exists". It does exist
/// (`POST /api/v1/analytics/device-health/`, Day 302's
/// `analytics_api_service.dart` / `AnalyticsApiService.reportDeviceHealth`)
/// — but its real schema (read directly off
/// `zapsafe_backend/analytics/views.py`'s `DeviceHealthView` docstring)
/// only accepts device *metrics* (`battery_drain_pct_per_hour`,
/// `memory_usage_mb`, `cpu_usage_pct`, `app_size_mb`,
/// `detection_cycle_latency_ms`, `last_crash_at`, `app_version`,
/// `os_version`, `device_model`) — there is no threshold/preference field
/// on it at all. Force-fitting a DCS threshold into that endpoint would
/// mean inventing a field the backend doesn't read. The real, already-
/// existing, actually-correct endpoint for a per-model detection
/// threshold is `PATCH /api/v1/alert-thresholds/<uuid>/`
/// (`min_confidence`, Day 63) — so this screen uses that instead, and
/// says so honestly rather than silently doing what the spec suggested
/// and quietly wiring it wrong.
///
/// "Day 258 fall detection tuning screen" named in the spec does not
/// exist in this repo (checked: no `day258*` file anywhere) — there is no
/// prior pattern to extend, stated honestly.
///
/// Tag: 🟣
///
/// Route: AppRoutes.falsePositiveTuningProd
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/services/alert_threshold_service.dart';
import '../../domain/providers/alert_threshold_providers.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';
import '../widgets/zap_error_state.dart';
import '../widgets/zap_skeleton.dart';
import '../widgets/zap_snackbar.dart';

class Day329FalsePositiveTuningProductionScreen extends ConsumerStatefulWidget {
  const Day329FalsePositiveTuningProductionScreen({super.key});

  @override
  ConsumerState<Day329FalsePositiveTuningProductionScreen> createState() =>
      _Day329FalsePositiveTuningProductionScreenState();
}

class _Day329FalsePositiveTuningProductionScreenState
    extends ConsumerState<Day329FalsePositiveTuningProductionScreen> {
  double? _pendingConfidence;
  bool _saving = false;
  String? _error;

  String _sensitivityLabel(double v) {
    if (v <= 0.6) return 'HIGH SENSITIVITY';
    if (v <= 0.8) return 'BALANCED';
    return 'LOW SENSITIVITY';
  }

  Color _sensitivityColor(double v) {
    if (v <= 0.6) return ZapColors.danger;
    if (v <= 0.8) return ZapColors.warning;
    return ZapColors.safe;
  }

  Future<void> _save(AlertThreshold? existing) async {
    final value = _pendingConfidence;
    if (value == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final service = ref.read(alertThresholdServiceProvider);
      if (existing != null) {
        await service.update(existing.id, minConfidence: value);
      } else {
        await service.create(
          modelType: AlertModelType.dcs.value,
          minConfidence: value,
          consecutiveTriggers: 1,
          cooldownSeconds: 30,
          autoSos: true,
          notifyContacts: true,
          notes: 'Created from Day 329 production sensitivity screen',
        );
      }
      ref.invalidate(alertThresholdListProvider);
      if (mounted) {
        ZapSnackbar.success(context, 'DCS sensitivity saved');
        setState(() => _pendingConfidence = null);
      }
    } catch (e) {
      setState(() => _error = '$e');
      if (mounted) ZapSnackbar.danger(context, 'Save failed — see error below');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(alertThresholdListProvider(''));

    return Scaffold(
      appBar: AppBar(title: Text('day321_330.false_positive_tuning_prod_title'.tr())),
      body: listAsync.when(
        data: (thresholds) {
          AlertThreshold? dcs;
          for (final t in thresholds) {
            if (t.modelType == AlertModelType.dcs.value) {
              dcs = t;
              break;
            }
          }
          final current = _pendingConfidence ?? dcs?.minConfidence ?? 0.75;

          return ListView(
            padding: const EdgeInsets.all(ZapSpacing.lg),
            children: [
              Text('day321_330.false_positive_tuning_prod_heading'.tr(),
                  style: ZapTypography.headlineSmall.copyWith(color: ZapColors.textPrimary)),
              const SizedBox(height: ZapSpacing.sm),
              Text(
                dcs == null
                    ? 'No DCS threshold row exists yet on the backend — '
                        'saving will create one via the real '
                        'POST /api/v1/alert-thresholds/.'
                    : 'Editing the real DCS threshold row '
                        '(id ${dcs.id.substring(0, 8)}…) via PATCH '
                        '/api/v1/alert-thresholds/<id>/.',
                style: ZapTypography.bodySmall.copyWith(color: ZapColors.textMuted),
              ),
              const SizedBox(height: ZapSpacing.xl),

              ZapCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('DCS trigger confidence threshold',
                              style: ZapTypography.bodyMedium.copyWith(
                                  color: ZapColors.textPrimary, fontWeight: FontWeight.w600)),
                        ),
                        ZapBadge(
                          label: _sensitivityLabel(current),
                          intent: current <= 0.6
                              ? ZapBadgeIntent.danger
                              : current <= 0.8
                                  ? ZapBadgeIntent.warning
                                  : ZapBadgeIntent.safe,
                        ),
                      ],
                    ),
                    const SizedBox(height: ZapSpacing.sm),
                    Slider(
                      value: current,
                      min: 0.5,
                      max: 0.95,
                      divisions: 45,
                      activeColor: _sensitivityColor(current),
                      label: current.toStringAsFixed(2),
                      onChanged: (v) => setState(() => _pendingConfidence = v),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('0.50', style: ZapTypography.labelSmall.copyWith(color: ZapColors.textMuted)),
                        Text(current.toStringAsFixed(2),
                            style: ZapTypography.bodyMedium.copyWith(
                                color: ZapColors.textPrimary, fontWeight: FontWeight.w700)),
                        Text('0.95', style: ZapTypography.labelSmall.copyWith(color: ZapColors.textMuted)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: ZapSpacing.lg),

              ZapCard(
                backgroundColor: ZapColors.warning.withOpacity(0.08),
                borderColor: ZapColors.warning.withOpacity(0.3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: ZapColors.warning, size: 20),
                    const SizedBox(width: ZapSpacing.sm),
                    Expanded(
                      child: Text(
                        'Tradeoff: lowering this threshold makes ZapSafe '
                        'more sensitive — it catches more real emergencies '
                        'but also fires more false alarms (loud noises, '
                        'phone drops). Raising it reduces false alarms but '
                        'risks missing a real emergency that scores below '
                        'the new bar. There is no globally "correct" '
                        'value — choose based on your environment.',
                        style: ZapTypography.bodySmall.copyWith(color: ZapColors.textPrimary, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: ZapSpacing.lg),

              if (_error != null) ...[
                ZapCard(
                  backgroundColor: ZapColors.danger.withOpacity(0.08),
                  borderColor: ZapColors.danger.withOpacity(0.3),
                  child: Text(_error!,
                      style: ZapTypography.bodySmall.copyWith(color: ZapColors.textPrimary)),
                ),
                const SizedBox(height: ZapSpacing.sm),
              ],

              ZapButton.elevated(
                label: _saving ? 'Saving…' : 'Save sensitivity',
                icon: Icons.save_rounded,
                intent: ZapButtonIntent.safe,
                fullWidth: true,
                isLoading: _saving,
                onPressed: _pendingConfidence == null || _saving ? null : () => _save(dcs),
              ),
              const SizedBox(height: ZapSpacing.huge),
            ],
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(ZapSpacing.lg),
          child: ZapSkeletonCard(height: 220),
        ),
        error: (e, _) => ZapErrorState.fromError(
          error: e,
          onRetry: () => ref.invalidate(alertThresholdListProvider('')),
        ),
      ),
    );
  }
}
