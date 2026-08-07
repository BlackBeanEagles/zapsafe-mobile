/// Day 328 — Battery Profile MONITORING-mode production wire.
///
/// Real gap found: [batteryServiceProvider] (Day 38,
/// `battery_providers.dart`) was constructed and watched by the
/// production dashboard's [batteryProfileProvider]
/// (`persistent_status_card.dart`, Day 308), but `BatteryService.start()`
/// was **never called from any production code path** — only from the
/// Day 38 demo screen's own button. So the real production dashboard's
/// battery reading was permanently stuck at [BatteryProfile.unknown]
/// (level -1), silently, because nothing ever triggered the first real
/// `battery_plus` read. [batteryMonitoringBootstrapProvider] closes that
/// gap the same way `gps.start()` is already gated in
/// `app_bootstrap_providers.dart` — watched from `appBootstrapProvider`.
///
/// Also wires [BatterySampleLog] (`battery_sample_log.dart`) to the real
/// [batteryProfileStreamProvider] so every real profile change this
/// session gets recorded for the Day 328 export screen.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/battery_profile.dart';
import '../battery/battery_sample_log.dart';
import 'battery_providers.dart';

/// Singleton log — survives for the app session so the export screen can
/// show everything recorded since boot, not just since the screen opened.
final batterySampleLogProvider = Provider<BatterySampleLog>((ref) {
  return BatterySampleLog();
});

/// Starts the real battery service (if not already started) and records
/// every emitted [BatteryProfile] into [batterySampleLogProvider]. Reading
/// this from [appBootstrapProvider] is what turns real production battery
/// monitoring on.
final batteryMonitoringBootstrapProvider = Provider<void>((ref) {
  final svc = ref.watch(batteryServiceProvider);
  if (!svc.isStarted) {
    unawaited(svc.start());
  }

  final log = ref.watch(batterySampleLogProvider);
  ref.listen<AsyncValue<BatteryProfile>>(batteryProfileStreamProvider, (_, next) {
    next.whenData(log.record);
  });
});
