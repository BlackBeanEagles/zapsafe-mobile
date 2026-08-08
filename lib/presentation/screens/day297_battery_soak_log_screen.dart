/// Day 297 — Battery & Thermal Soak Test Log
///
/// Section E (Days 281-300): log template for 8-hour MONITORING mode soak on a
/// real device — hourly battery %, thermal state, and drain notes.
///
/// Tag: 🟢 FRONTEND-ONLY · soak log template · no device telemetry API.
///
/// Route: [AppRoutes.batterySoakLog] → `/battery-soak-log`
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const _kAccent = Color(0xFFF97316);
const _kTabs = ['Soak', 'Log', 'Info'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');
const _kSoakHours = 8;
const _kSoakDurationSec = _kSoakHours * 3600;
const _kMaxDrainPct = 25;
const _kAccelFactor = 120; // 1 real sec = 2 simulated min

enum _ThermalState { normal, warm, hot, throttled }

enum _CheckpointStatus { pending, pass, warn, fail }

class _DeviceProfile {
  const _DeviceProfile({
    required this.id,
    required this.label,
    required this.platform,
    required this.startBattery,
    required this.drainPerHour,
  });

  final String id;
  final String label;
  final String platform;
  final int startBattery;
  final double drainPerHour;
}

const _kDevices = [
  _DeviceProfile(
    id: 'pixel_8',
    label: 'Pixel 8 · Android 14',
    platform: 'android',
    startBattery: 100,
    drainPerHour: 2.8,
  ),
  _DeviceProfile(
    id: 'galaxy_s24',
    label: 'Galaxy S24 · Android 14',
    platform: 'android',
    startBattery: 100,
    drainPerHour: 3.1,
  ),
  _DeviceProfile(
    id: 'iphone_15',
    label: 'iPhone 15 · iOS 18',
    platform: 'ios',
    startBattery: 100,
    drainPerHour: 2.4,
  ),
  _DeviceProfile(
    id: 'iphone_14',
    label: 'iPhone 14 · iOS 17',
    platform: 'ios',
    startBattery: 100,
    drainPerHour: 2.9,
  ),
];

class _SoakCheckpoint {
  const _SoakCheckpoint({
    required this.hour,
    required this.batteryPct,
    required this.thermal,
    required this.drainPerHr,
    required this.notes,
    required this.status,
  });

  final int hour;
  final int batteryPct;
  final _ThermalState thermal;
  final String drainPerHr;
  final String notes;
  final _CheckpointStatus status;

  Map<String, dynamic> toJson() => {
        'hour': hour,
        'battery_pct': batteryPct,
        'thermal': _thermalKey(thermal),
        'drain_per_hr': drainPerHr,
        'notes': notes,
        'status': _statusKey(status),
      };
}

_DeviceProfile _deviceById(String id) =>
    _kDevices.firstWhere((d) => d.id == id, orElse: () => _kDevices.first);

String _thermalKey(_ThermalState t) => switch (t) {
      _ThermalState.normal => 'normal',
      _ThermalState.warm => 'warm',
      _ThermalState.hot => 'hot',
      _ThermalState.throttled => 'throttled',
    };

String _thermalLabel(_ThermalState t) => switch (t) {
      _ThermalState.normal => 'Normal',
      _ThermalState.warm => 'Warm',
      _ThermalState.hot => 'Hot',
      _ThermalState.throttled => 'Throttled',
    };

Color _thermalColor(_ThermalState t) => switch (t) {
      _ThermalState.normal => ZapColors.safe,
      _ThermalState.warm => ZapColors.warning,
      _ThermalState.hot => const Color(0xFFF97316),
      _ThermalState.throttled => ZapColors.danger,
    };

String _statusKey(_CheckpointStatus s) => switch (s) {
      _CheckpointStatus.pending => 'pending',
      _CheckpointStatus.pass => 'pass',
      _CheckpointStatus.warn => 'warn',
      _CheckpointStatus.fail => 'fail',
    };

Color _statusColor(_CheckpointStatus s) => switch (s) {
      _CheckpointStatus.pending => ZapColors.textMuted,
      _CheckpointStatus.pass => ZapColors.safe,
      _CheckpointStatus.warn => ZapColors.warning,
      _CheckpointStatus.fail => ZapColors.danger,
    };

_ThermalState _thermalAtHour(_DeviceProfile device, int hour) {
  final base = device.drainPerHour;
  if (hour < 3) return _ThermalState.normal;
  if (hour < 5) return _ThermalState.warm;
  if (device.platform == 'android' && hour >= 7 && base > 3.0) {
    return _ThermalState.throttled;
  }
  if (hour >= 6) return _ThermalState.hot;
  return _ThermalState.warm;
}

int _batteryAtHour(_DeviceProfile device, int hour) {
  final drain = (device.drainPerHour * hour).round();
  return math.max(100 - drain, 0);
}

_CheckpointStatus _statusForCheckpoint(_SoakCheckpoint cp) {
  if (cp.thermal == _ThermalState.throttled) return _CheckpointStatus.fail;
  if (cp.batteryPct < 100 - _kMaxDrainPct) return _CheckpointStatus.warn;
  if (cp.thermal == _ThermalState.hot) return _CheckpointStatus.warn;
  return _CheckpointStatus.pass;
}

_SoakCheckpoint _generateCheckpoint(_DeviceProfile device, int hour) {
  final battery = _batteryAtHour(device, hour);
  final thermal = _thermalAtHour(device, hour);
  final drainStr = '${device.drainPerHour.toStringAsFixed(1)}%/hr';
  final notes = switch (thermal) {
    _ThermalState.throttled =>
      'CPU throttled — verify SOS path latency < 800ms.',
    _ThermalState.hot => 'Device warm — MONITORING geofence active.',
    _ThermalState.warm => 'Steady MONITORING mode · no user interaction.',
    _ThermalState.normal => 'Baseline soak · screen off · pocket carry.',
  };
  final cp = _SoakCheckpoint(
    hour: hour,
    batteryPct: battery,
    thermal: thermal,
    drainPerHr: drainStr,
    notes: notes,
    status: _CheckpointStatus.pending,
  );
  return _SoakCheckpoint(
    hour: hour,
    batteryPct: battery,
    thermal: thermal,
    drainPerHr: drainStr,
    notes: notes,
    status: _statusForCheckpoint(cp),
  );
}

List<_SoakCheckpoint> _generateAllCheckpoints(_DeviceProfile device) =>
    List.generate(_kSoakHours + 1, (h) => _generateCheckpoint(device, h));

String _formatDuration(int totalSec) {
  final h = totalSec ~/ 3600;
  final m = (totalSec % 3600) ~/ 60;
  final s = totalSec % 60;
  return '${h.toString().padLeft(2, '0')}:'
      '${m.toString().padLeft(2, '0')}:'
      '${s.toString().padLeft(2, '0')}';
}

Map<String, dynamic> _soakPayload({
  required String deviceId,
  required int elapsedSec,
  required List<_SoakCheckpoint> checkpoints,
}) {
  final logged =
      checkpoints.where((c) => c.status != _CheckpointStatus.pending).length;
  final start = checkpoints.isNotEmpty ? checkpoints.first.batteryPct : 100;
  final end = checkpoints.isNotEmpty ? checkpoints.last.batteryPct : 100;
  return {
    'endpoint': 'POST /api/v1/qa/battery-soak-log/',
    'mode': 'MONITORING',
    'duration_hours': _kSoakHours,
    'device_id': deviceId,
    'elapsed_sec': elapsedSec,
    'checkpoints_logged': logged,
    'total_drain_pct': start - end,
    'max_drain_gate_pct': _kMaxDrainPct,
    'checkpoints': checkpoints.map((c) => c.toJson()).toList(),
    'wire_note': '8hr soak template · real device QA log',
  };
}

String _buildSoakReport({
  required _DeviceProfile device,
  required List<_SoakCheckpoint> checkpoints,
}) {
  final buf = StringBuffer(
    'ZapSafe Battery & Thermal Soak Log\n'
    'Device: ${device.label}\n'
    'Mode: MONITORING · ${_kSoakHours}h target\n\n',
  );
  for (final cp in checkpoints) {
    buf.writeln(
      'T+${cp.hour}h · ${cp.batteryPct}% · '
      '${_thermalLabel(cp.thermal)} · ${_statusKey(cp.status).toUpperCase()}',
    );
    buf.writeln('  Drain: ${cp.drainPerHr} · ${cp.notes}');
  }
  if (checkpoints.length >= 2) {
    final drain = checkpoints.first.batteryPct - checkpoints.last.batteryPct;
    buf.writeln();
    buf.writeln('Total drain: $drain% (gate ≤ $_kMaxDrainPct%)');
  }
  return buf.toString();
}

String _buildCsv(List<_SoakCheckpoint> checkpoints) {
  final buf =
      StringBuffer('hour,battery_pct,thermal,drain_per_hr,status,notes\n');
  for (final cp in checkpoints) {
    buf.writeln(
      '${cp.hour},${cp.batteryPct},${_thermalKey(cp.thermal)},'
      '"${cp.drainPerHr}",${_statusKey(cp.status)},"${cp.notes}"',
    );
  }
  return buf.toString();
}

// ── Providers ─────────────────────────────────────────────────────────────────
final _d297TabProvider = StateProvider<int>((ref) => 0);
final _d297DeviceProvider = StateProvider<String>((ref) => _kDevices.first.id);
final _d297RunningProvider = StateProvider<bool>((ref) => false);
final _d297ElapsedProvider = StateProvider<int>((ref) => 0);
final _d297CheckpointsProvider =
    StateProvider<List<_SoakCheckpoint>>((ref) => []);
final _d297TimerProvider = StateProvider<Timer?>((ref) => null);

// ── Screen ────────────────────────────────────────────────────────────────────
class Day297BatterySoakLogScreen extends ConsumerStatefulWidget {
  const Day297BatterySoakLogScreen({super.key});

  @override
  ConsumerState<Day297BatterySoakLogScreen> createState() =>
      _Day297BatterySoakLogScreenState();
}

class _Day297BatterySoakLogScreenState
    extends ConsumerState<Day297BatterySoakLogScreen> {
  @override
  void dispose() {
    ref.read(_d297TimerProvider.notifier).state?.cancel();
    super.dispose();
  }

  void _stopTimer() {
    ref.read(_d297TimerProvider.notifier).state?.cancel();
    ref.read(_d297TimerProvider.notifier).state = null;
    ref.read(_d297RunningProvider.notifier).state = false;
  }

  void _startSoak() {
    if (ref.read(_d297RunningProvider)) return;
    ref.read(_d297RunningProvider.notifier).state = true;
    ref.read(_d297ElapsedProvider.notifier).state = 0;
    ref.read(_d297CheckpointsProvider.notifier).state = [];

    final timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final next = ref.read(_d297ElapsedProvider) + _kAccelFactor;
      if (next >= _kSoakDurationSec) {
        ref.read(_d297ElapsedProvider.notifier).state = _kSoakDurationSec;
        _stopTimer();
        _autoFillCheckpoints();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('8hr soak complete — log filled.')),
          );
        }
      } else {
        ref.read(_d297ElapsedProvider.notifier).state = next;
      }
    });
    ref.read(_d297TimerProvider.notifier).state = timer;
  }

  void _autoFillCheckpoints() {
    final device = _deviceById(ref.read(_d297DeviceProvider));
    ref.read(_d297CheckpointsProvider.notifier).state =
        _generateAllCheckpoints(device);
  }

  void _resetSoak() {
    _stopTimer();
    ref.read(_d297ElapsedProvider.notifier).state = 0;
    ref.read(_d297CheckpointsProvider.notifier).state = [];
  }

  @override
  Widget build(BuildContext context) {
    final logged = ref.watch(_d297CheckpointsProvider).length;

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 297 · Battery Soak Log'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: ZapSpacing.sm, vertical: ZapSpacing.xs),
                decoration: BoxDecoration(
                  color: _kAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _kAccent.withOpacity(0.45)),
                ),
                child: Text(
                  '$logged/${_kSoakHours + 1} checkpoints',
                  style: const TextStyle(
                    color: _kAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _TabBar(
            tab: ref.watch(_d297TabProvider),
            onSelect: (i) => ref.read(_d297TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (ref.watch(_d297TabProvider)) {
              0 => _SoakTab(
                  onStart: _startSoak,
                  onStop: _stopTimer,
                  onReset: _resetSoak,
                  onAutoFill: _autoFillCheckpoints,
                ),
              1 => const _LogTab(),
              _ => const _InfoTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Soak ───────────────────────────────────────────────────────────────
class _SoakTab extends ConsumerWidget {
  const _SoakTab({
    required this.onStart,
    required this.onStop,
    required this.onReset,
    required this.onAutoFill,
  });

  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onReset;
  final VoidCallback onAutoFill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceId = ref.watch(_d297DeviceProvider);
    final device = _deviceById(deviceId);
    final running = ref.watch(_d297RunningProvider);
    final elapsed = ref.watch(_d297ElapsedProvider);
    final progress = elapsed / _kSoakDurationSec;
    final currentHour = (elapsed / 3600).floor().clamp(0, _kSoakHours);
    final liveBattery = _batteryAtHour(device, currentHour);
    final liveThermal = _thermalAtHour(device, currentHour);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _SectionTitle(
          title: '8hr MONITORING soak',
          subtitle:
              'Real device · screen off · pocket carry · accelerated timer',
        ),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: _kAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kAccent.withOpacity(0.35)),
          ),
          child: const Row(
            children: [
              Icon(Icons.sensors_rounded, color: _kAccent),
              SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: Text(
                  'MONITORING mode active — passive geofence + heartbeat. '
                  'No SOS session during soak unless testing thermal SOS path.',
                  style: TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        DropdownButtonFormField<String>(
          value: deviceId,
          decoration: const InputDecoration(
            labelText: 'Test device',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: _kDevices
              .map(
                (d) => DropdownMenuItem(
                  value: d.id,
                  child: Text(d.label, style: const TextStyle(fontSize: 12)),
                ),
              )
              .toList(),
          onChanged: running
              ? null
              : (v) {
                  if (v != null) {
                    ref.read(_d297DeviceProvider.notifier).state = v;
                  }
                },
        ),
        const SizedBox(height: ZapSpacing.lg),
        Text(
          _formatDuration(elapsed),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: ZapColors.textPrimary,
            fontSize: 32,
            fontWeight: FontWeight.w900,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          '/ ${_formatDuration(_kSoakDurationSec)} target',
          textAlign: TextAlign.center,
          style: const TextStyle(color: ZapColors.textMuted, fontSize: 11),
        ),
        const SizedBox(height: ZapSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: ZapColors.border,
            color: _kAccent,
            minHeight: 8,
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Row(
          children: [
            Expanded(
              child: _LiveMetricCard(
                icon: Icons.battery_charging_full_rounded,
                label: 'Battery',
                value: '$liveBattery%',
                color: liveBattery > 75
                    ? ZapColors.safe
                    : liveBattery > 50
                        ? ZapColors.warning
                        : ZapColors.danger,
              ),
            ),
            const SizedBox(width: ZapSpacing.sm),
            Expanded(
              child: _LiveMetricCard(
                icon: Icons.thermostat_rounded,
                label: 'Thermal',
                value: _thermalLabel(liveThermal),
                color: _thermalColor(liveThermal),
              ),
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.md),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: running ? onStop : onStart,
                icon: Icon(
                    running ? Icons.pause_rounded : Icons.play_arrow_rounded),
                label: Text(running ? 'Pause soak' : 'Start soak'),
                style: FilledButton.styleFrom(backgroundColor: _kAccent),
              ),
            ),
            const SizedBox(width: ZapSpacing.sm),
            IconButton(
              onPressed: running ? null : onReset,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Reset',
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.sm),
        OutlinedButton.icon(
          onPressed: running ? null : onAutoFill,
          icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
          label: const Text('Auto-fill 8hr log (mock)'),
        ),
      ],
    );
  }
}

class _LiveMetricCard extends StatelessWidget {
  const _LiveMetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            label,
            style: const TextStyle(color: ZapColors.textMuted, fontSize: 10),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab 1: Log ────────────────────────────────────────────────────────────────
class _LogTab extends ConsumerWidget {
  const _LogTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = _deviceById(ref.watch(_d297DeviceProvider));
    final checkpoints = ref.watch(_d297CheckpointsProvider);
    final totalDrain = checkpoints.length >= 2
        ? checkpoints.first.batteryPct - checkpoints.last.batteryPct
        : 0;
    final gatePass = totalDrain <= _kMaxDrainPct;
    final hasThrottle = checkpoints.any(
      (c) => c.thermal == _ThermalState.throttled,
    );

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _SectionTitle(
          title: 'Hourly soak log',
          subtitle: 'T+0 → T+8h · battery · thermal · drain notes',
        ),
        if (checkpoints.isEmpty)
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(color: ZapColors.border),
            ),
            child: const Text(
              'No checkpoints yet — start soak or tap Auto-fill on Soak tab.',
              style: TextStyle(color: ZapColors.textMuted, fontSize: 11),
            ),
          )
        else ...[
          if (checkpoints.length >= 2)
            Container(
              padding: const EdgeInsets.all(ZapSpacing.md),
              margin: const EdgeInsets.only(bottom: ZapSpacing.md),
              decoration: BoxDecoration(
                color: (gatePass && !hasThrottle)
                    ? ZapColors.safe.withOpacity(0.12)
                    : ZapColors.warning.withOpacity(0.12),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                  color: (gatePass && !hasThrottle)
                      ? ZapColors.safe.withOpacity(0.4)
                      : ZapColors.warning.withOpacity(0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    (gatePass && !hasThrottle)
                        ? Icons.check_circle_rounded
                        : Icons.warning_amber_rounded,
                    color: (gatePass && !hasThrottle)
                        ? ZapColors.safe
                        : ZapColors.warning,
                  ),
                  const SizedBox(width: ZapSpacing.sm),
                  Expanded(
                    child: Text(
                      'Drain $totalDrain% (gate ≤ $_kMaxDrainPct%)'
                      '${hasThrottle ? ' · thermal throttle detected' : ''}',
                      style: TextStyle(
                        color: (gatePass && !hasThrottle)
                            ? ZapColors.safe
                            : ZapColors.warning,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ...checkpoints.map(
            (cp) => Container(
              margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
              padding: const EdgeInsets.all(ZapSpacing.md),
              decoration: BoxDecoration(
                color: ZapColors.bgCard,
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                  color: _statusColor(cp.status).withOpacity(0.35),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: _kAccent.withOpacity(0.15),
                    child: Text(
                      'T+${cp.hour}',
                      style: const TextStyle(
                        color: _kAccent,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: ZapSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${cp.batteryPct}% battery',
                              style: const TextStyle(
                                color: ZapColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _thermalLabel(cp.thermal),
                              style: TextStyle(
                                color: _thermalColor(cp.thermal),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${cp.drainPerHr} · ${_statusKey(cp.status).toUpperCase()}',
                          style: const TextStyle(
                            color: ZapColors.textMuted,
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          cp.notes,
                          style: const TextStyle(
                            color: ZapColors.textSecondary,
                            fontSize: 10,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: ZapSpacing.md),
        FilledButton.icon(
          onPressed: checkpoints.isEmpty
              ? null
              : () {
                  Clipboard.setData(
                    ClipboardData(
                      text: _buildSoakReport(
                        device: device,
                        checkpoints: checkpoints,
                      ),
                    ),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Soak report copied.')),
                  );
                },
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text('Copy soak report'),
          style: FilledButton.styleFrom(backgroundColor: _kAccent),
        ),
        const SizedBox(height: ZapSpacing.sm),
        OutlinedButton.icon(
          onPressed: checkpoints.isEmpty
              ? null
              : () {
                  Clipboard.setData(
                    ClipboardData(text: _buildCsv(checkpoints)),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('CSV exported.')),
                  );
                },
          icon: const Icon(Icons.table_chart_rounded, size: 16),
          label: const Text('Export CSV'),
        ),
      ],
    );
  }
}

// ── Tab 2: Info ───────────────────────────────────────────────────────────────
class _InfoTab extends ConsumerWidget {
  const _InfoTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payload = _soakPayload(
      deviceId: ref.watch(_d297DeviceProvider),
      elapsedSec: ref.watch(_d297ElapsedProvider),
      checkpoints: ref.watch(_d297CheckpointsProvider),
    );

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _SectionTitle(
          title: 'Battery & thermal soak',
          subtitle: 'Day 295 Phase 2 Week 9 · pre-launch device QA template.',
        ),
        const _PolicyRow(
          icon: Icons.battery_charging_full_rounded,
          title: '8hr MONITORING soak',
          subtitle:
              'Screen off · pocket carry · passive geofence · no user taps.',
        ),
        const _PolicyRow(
          icon: Icons.thermostat_rounded,
          title: 'Thermal gates',
          subtitle: 'Log normal/warm/hot/throttled · SOS path if throttled.',
        ),
        const _PolicyRow(
          icon: Icons.speed_rounded,
          title: 'Drain gate',
          subtitle:
              'Total drain ≤ $_kMaxDrainPct% over 8h · hourly checkpoints.',
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'API contract (mock)',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: ZapColors.border),
          ),
          child: SelectableText(
            _kJsonEncoder.convert(payload),
            style: const TextStyle(
              color: ZapColors.textSecondary,
              fontSize: 10,
              fontFamily: 'monospace',
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(
              ClipboardData(text: _kJsonEncoder.convert(payload)),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Soak spec copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy spec JSON'),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.info.withOpacity(0.1),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: ZapColors.info.withOpacity(0.3)),
          ),
          child: const Text(
            'Next: Day 365 — Global Launch Milestone '
            '(Phase 2 finale · worldwide rollout).',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              label: const Text('Day 21 Background'),
              onPressed: () => context.push(AppRoutes.backgroundEngine),
            ),
            ActionChip(
              label: const Text('Day 296 Parity'),
              onPressed: () => context.push(AppRoutes.platformParityAudit),
            ),
            ActionChip(
              label: const Text('Day 295 Roadmap'),
              onPressed: () => context.push(AppRoutes.phase2Roadmap),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
              color: ZapColors.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicyRow extends StatelessWidget {
  const _PolicyRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ZapSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: _kAccent),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.tab, required this.onSelect});

  final int tab;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ZapColors.bgCard,
      child: Row(
        children: List.generate(_kTabs.length, (i) {
          final selected = tab == i;
          return Expanded(
            child: InkWell(
              onTap: () => onSelect(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: ZapSpacing.md),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected ? _kAccent : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  _kTabs[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? _kAccent : ZapColors.textMuted,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
