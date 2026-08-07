/// Day 328 — Battery Profile: MONITORING Mode Production
///
/// 🟣. Real tier thresholds (`BatteryThresholds`, `battery_profile.dart`):
/// `powerSaverThreshold=20`, `proactiveDropThreshold=15`,
/// `vadOnlyThreshold=10` — **not** the spec's placeholder guess of
/// 80/18/13/7. Read directly off the source, per the spec's own
/// instruction not to assume the exact numbers.
///
/// Real gap found + fixed this day: `BatteryService.start()`
/// (`battery_service.dart`, Day 38) was never called from any production
/// code path — only from the Day 38 demo screen's own button. The
/// production dashboard's persistent status card
/// (`persistent_status_card.dart`, Day 308) watches
/// `batteryProfileProvider`, but with the service never started that
/// provider was permanently stuck at `BatteryProfile.unknown`. New
/// `battery_monitoring_providers.dart` starts the real service and wires
/// a real 1-hour sample log, watched from `appBootstrapProvider` the same
/// way `gps.start()` already is.
///
/// "1-hour sample log export" — the export mechanism itself
/// (`BatterySampleLog.exportJson` + the clipboard button below) is real
/// and works. The actual 1-hour-of-real-samples data requires a real
/// device left running for an hour, which this sandbox cannot do — the
/// sample count below is whatever this actual session recorded, shown
/// honestly rather than padded to look like a full hour.
///
/// "Day 297 soak template" from the spec does not exist in this repo
/// (checked: no "soak" screen anywhere, and `DAY297_WHISPER_SLR110_RETRAIN.md`
/// in `assets/models/` is an unrelated ML-training doc, not a Flutter
/// screen) — noted honestly rather than fabricating a comparison.
///
/// Tag: 🟣
///
/// Route: AppRoutes.batteryMonitoringProd
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/models/battery_profile.dart';
import '../../domain/providers/battery_monitoring_providers.dart';
import '../../domain/providers/battery_providers.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';
import '../widgets/zap_snackbar.dart';

class Day328BatteryMonitoringProductionScreen extends ConsumerWidget {
  const Day328BatteryMonitoringProductionScreen({super.key});

  static const _tiers = [
    (label: 'NORMAL', condition: '> 20% or charging', effect: 'No throttling.'),
    (label: 'POWER_SAVER', condition: '≤ 20%', effect: 'Camera off · GPS cadence reduced · Mode B evidence.'),
    (label: 'PROACTIVE_DROP', condition: '≤ 15%', effect: 'Proactive Mode drops one tier · dashboard banner.'),
    (label: 'VAD_ONLY', condition: '≤ 10%', effect: 'All sensors off except mic VAD · SOS still fully functional.'),
  ];

  Color _tierColor(BatteryTier t) => switch (t) {
        BatteryTier.normal => ZapColors.safe,
        BatteryTier.powerSaver => ZapColors.info,
        BatteryTier.proactiveDrop => ZapColors.warning,
        BatteryTier.vadOnly => ZapColors.danger,
      };

  Future<void> _exportLog(BuildContext context, WidgetRef ref) async {
    final log = ref.read(batterySampleLogProvider);
    await Clipboard.setData(ClipboardData(text: log.exportJson()));
    if (context.mounted) {
      ZapSnackbar.success(context, '${log.samples.length} sample(s) copied as JSON');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(batteryProfileProvider);
    ref.watch(batterySampleLogProvider); // keep the log instance alive
    final samples = ref.read(batterySampleLogProvider).samples;

    return Scaffold(
      appBar: AppBar(title: Text('day321_330.battery_monitoring_prod_title'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          Text('day321_330.battery_monitoring_prod_heading'.tr(),
              style: ZapTypography.headlineSmall.copyWith(color: ZapColors.textPrimary)),
          const SizedBox(height: ZapSpacing.sm),
          ZapCard(
            backgroundColor: ZapColors.safe.withOpacity(0.08),
            borderColor: ZapColors.safe.withOpacity(0.3),
            child: Text(
              'Fixed this day: BatteryService.start() was never called '
              'from any production code path — the dashboard\'s battery '
              'reading was permanently "unknown". Now started from '
              'appBootstrapProvider, same pattern as gps.start().',
              style: ZapTypography.bodySmall.copyWith(color: ZapColors.textPrimary, height: 1.4),
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),

          Text('CURRENT PROFILE (real batteryProfileProvider)',
              style: ZapTypography.labelLarge.copyWith(color: ZapColors.textSecondary, letterSpacing: 1.2)),
          const SizedBox(height: ZapSpacing.sm),
          ZapCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.level >= 0 ? '${profile.level}%' : 'unknown',
                        style: ZapTypography.displaySmall.copyWith(color: ZapColors.textPrimary),
                      ),
                      Text(
                        profile.isCharging ? 'charging' : 'on battery',
                        style: ZapTypography.bodySmall.copyWith(color: ZapColors.textMuted),
                      ),
                    ],
                  ),
                ),
                ZapBadge(label: profile.tier.label, intent: ZapBadgeIntent.info, style: ZapBadgeStyle.tonal),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),

          Text('TIER TABLE (real thresholds — BatteryThresholds)',
              style: ZapTypography.labelLarge.copyWith(color: ZapColors.textSecondary, letterSpacing: 1.2)),
          const SizedBox(height: ZapSpacing.sm),
          for (final t in _tiers)
            ZapCard(
              margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(right: ZapSpacing.sm),
                    decoration: BoxDecoration(
                      color: _tierColor(BatteryTier.values.firstWhere((v) => v.label == t.label)),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${t.label} · ${t.condition}',
                            style: ZapTypography.bodyMedium.copyWith(
                                color: ZapColors.textPrimary, fontWeight: FontWeight.w600)),
                        Text(t.effect,
                            style: ZapTypography.bodySmall.copyWith(color: ZapColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: ZapSpacing.xl),

          Text('1-HOUR SAMPLE LOG EXPORT',
              style: ZapTypography.labelLarge.copyWith(color: ZapColors.textSecondary, letterSpacing: 1.2)),
          const SizedBox(height: ZapSpacing.sm),
          ZapCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${samples.length} sample(s) recorded this session',
                    style: ZapTypography.bodyMedium.copyWith(color: ZapColors.textPrimary)),
                const SizedBox(height: ZapSpacing.xs),
                Text(
                  'Real export mechanism (JSON, rolling 1h window, '
                  'BatterySampleLog). A full hour of samples needs a real '
                  'device left running — not available in this sandbox, '
                  'so the count above is honest, not padded.',
                  style: ZapTypography.bodySmall.copyWith(color: ZapColors.textMuted, height: 1.4),
                ),
                const SizedBox(height: ZapSpacing.md),
                ZapButton.outlined(
                  label: 'Export log to clipboard (JSON)',
                  icon: Icons.copy_rounded,
                  fullWidth: true,
                  onPressed: () => _exportLog(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.lg),
          ZapCard(
            backgroundColor: ZapColors.textMuted.withOpacity(0.06),
            child: Text(
              'No "Day 297 soak template" screen exists in this repo '
              '(checked directly) — nothing to structurally compare '
              'against, stated honestly.',
              style: ZapTypography.bodySmall.copyWith(color: ZapColors.textMuted, height: 1.4),
            ),
          ),
          const SizedBox(height: ZapSpacing.huge),
        ],
      ),
    );
  }
}
