/// Day 233 — Decoy Weather App Mode
///
/// Section B (Days 221-240): second decoy skin — fake weather forecast UI.
/// Secret unlock via shake pattern (3×) or volume-hold simulation opens
/// safety layer. Hardware SOS remains active in background.
///
/// Tag: 🟢 FRONTEND-ONLY · LP24 stealth · companion to Day 232 calculator.
///
/// Route: [AppRoutes.decoyWeather] → `/decoy-weather`
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

// ── Mock forecast ─────────────────────────────────────────────────────────────
class _HourForecast {
  final String time;
  final IconData icon;
  final int tempC;

  const _HourForecast(this.time, this.icon, this.tempC);
}

class _DayForecast {
  final String day;
  final IconData icon;
  final int high;
  final int low;

  const _DayForecast(this.day, this.icon, this.high, this.low);
}

const _kCity = 'Mumbai';
const _kCondition = 'Partly cloudy';
const _kCurrentTemp = 32;

const _kHourly = [
  _HourForecast('Now', Icons.wb_sunny_rounded, 32),
  _HourForecast('14:00', Icons.wb_cloudy_rounded, 31),
  _HourForecast('15:00', Icons.wb_cloudy_rounded, 30),
  _HourForecast('16:00', Icons.grain_rounded, 29),
  _HourForecast('17:00', Icons.grain_rounded, 28),
  _HourForecast('18:00', Icons.nights_stay_rounded, 27),
  _HourForecast('19:00', Icons.nights_stay_rounded, 27),
];

const _kWeekly = [
  _DayForecast('Mon', Icons.wb_sunny_rounded, 33, 26),
  _DayForecast('Tue', Icons.grain_rounded, 30, 25),
  _DayForecast('Wed', Icons.thunderstorm_rounded, 28, 24),
  _DayForecast('Thu', Icons.wb_cloudy_rounded, 31, 25),
  _DayForecast('Fri', Icons.wb_sunny_rounded, 32, 26),
  _DayForecast('Sat', Icons.wb_sunny_rounded, 33, 27),
  _DayForecast('Sun', Icons.grain_rounded, 29, 25),
];

// ── Unlock state ──────────────────────────────────────────────────────────────
const _kShakeTarget = 3;
const _kShakeWindowMs = 2500;
const _kVolumeHoldMs = 2000;
const _kShakeThreshold = 14.5;

// ── Providers ─────────────────────────────────────────────────────────────────
final _d233TabProvider = StateProvider<int>((ref) => 0);
final _d233ShakeCountProvider = StateProvider<int>((ref) => 0);
final _d233ShakeListeningProvider = StateProvider<bool>((ref) => false);
final _d233VolumeProgressProvider = StateProvider<double>((ref) => 0);
final _d233VolumeHoldingProvider = StateProvider<bool>((ref) => false);
final _d233UnlockCountProvider = StateProvider<int>((ref) => 0);
final _d233LastUnlockMethodProvider = StateProvider<String?>((ref) => null);

const _kTabs = ['Weather', 'Unlock', 'Safety'];

void _triggerUnlock(WidgetRef ref, String method) {
  ref.read(_d233UnlockCountProvider.notifier).update((c) => c + 1);
  ref.read(_d233LastUnlockMethodProvider.notifier).state = method;
  ref.read(_d233ShakeCountProvider.notifier).state = 0;
  ref.read(_d233VolumeProgressProvider.notifier).state = 0;
}

void _showUnlockSheet(BuildContext context, String method) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: ZapColors.bgCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.lock_open_rounded, color: ZapColors.safe),
              SizedBox(width: 8),
              Text(
                'Safety layer unlocked',
                style: TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Decoy weather · unlocked via $method',
            style: const TextStyle(color: ZapColors.textMuted, fontSize: 11),
          ),
          const SizedBox(height: ZapSpacing.lg),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              context.push(AppRoutes.alertPending);
            },
            icon: const Icon(Icons.timer_rounded, size: 18),
            label: const Text('Open Alert Pending'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              backgroundColor: ZapColors.danger,
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              context.push(AppRoutes.sosActive);
            },
            icon: const Icon(Icons.sos_rounded, size: 18),
            label: const Text('Open SOS Active'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              backgroundColor: ZapColors.warning,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              context.go(AppRoutes.home);
            },
            icon: const Icon(Icons.home_rounded, size: 18),
            label: const Text('Exit decoy → ZapSafe nav'),
          ),
        ],
      ),
    ),
  );
}

// ── Screen ────────────────────────────────────────────────────────────────────
class Day233DecoyWeatherScreen extends ConsumerStatefulWidget {
  const Day233DecoyWeatherScreen({super.key});

  @override
  ConsumerState<Day233DecoyWeatherScreen> createState() =>
      _Day233DecoyWeatherScreenState();
}

class _Day233DecoyWeatherScreenState
    extends ConsumerState<Day233DecoyWeatherScreen> {
  StreamSubscription<AccelerometerEvent>? _accelSub;
  DateTime? _shakeWindowStart;
  DateTime? _lastShakePeak;

  @override
  void dispose() {
    _accelSub?.cancel();
    super.dispose();
  }

  void _registerShake() {
    final now = DateTime.now();
    if (_lastShakePeak != null &&
        now.difference(_lastShakePeak!).inMilliseconds < 400) {
      return;
    }
    _lastShakePeak = now;
    _shakeWindowStart ??= now;
    if (now.difference(_shakeWindowStart!).inMilliseconds > _kShakeWindowMs) {
      _shakeWindowStart = now;
      ref.read(_d233ShakeCountProvider.notifier).state = 0;
    }
    final next = ref.read(_d233ShakeCountProvider) + 1;
    ref.read(_d233ShakeCountProvider.notifier).state = next;
    if (next >= _kShakeTarget) {
      _shakeWindowStart = null;
      _triggerUnlock(ref, 'shake ×$_kShakeTarget');
      _showUnlockSheet(context, 'shake ×$_kShakeTarget');
    }
  }

  void _startShakeListener() {
    _accelSub?.cancel();
    ref.read(_d233ShakeListeningProvider.notifier).state = true;
    _shakeWindowStart = null;
    ref.read(_d233ShakeCountProvider.notifier).state = 0;

    _accelSub = accelerometerEventStream().listen((e) {
      final mag = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
      if (mag >= _kShakeThreshold) {
        _registerShake();
      }
    });
  }

  void _stopShakeListener() {
    _accelSub?.cancel();
    _accelSub = null;
    ref.read(_d233ShakeListeningProvider.notifier).state = false;
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(_d233TabProvider);
    final unlockCount = ref.watch(_d233UnlockCountProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0B3D91),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        title: const Text('Weather'),
        centerTitle: true,
        actions: [
          if (unlockCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: ZapSpacing.md),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: ZapColors.safe.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'UNLOCKED',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _WeatherTabBar(
            tab: tab,
            onSelect: (i) => ref.read(_d233TabProvider.notifier).state = i,
          ),
          Expanded(
            child: ColoredBox(
              color: tab == 0 ? Colors.transparent : ZapColors.bgPrimary,
              child: switch (tab) {
                0 => const _WeatherTab(),
                1 => _UnlockTab(
                    onStartShake: _startShakeListener,
                    onStopShake: _stopShakeListener,
                    onShakeSimulate: () {
                      for (var i = 0; i < _kShakeTarget; i++) {
                        _registerShake();
                      }
                    },
                    onVolumeUnlock: () {
                      _triggerUnlock(ref, 'volume hold');
                      _showUnlockSheet(context, 'volume hold 2s');
                    },
                  ),
                _ => const _SafetyTab(),
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Weather ────────────────────────────────────────────────────────────
class _WeatherTab extends StatelessWidget {
  const _WeatherTab();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1565C0), Color(0xFF0D47A1), Color(0xFF08306B)],
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          const Row(
            children: [
              Icon(Icons.location_on_rounded,
                  color: Colors.white70, size: 18),
              SizedBox(width: 4),
              Text(
                _kCity,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Spacer(),
              Text(
                'Updated 10:42',
                style: TextStyle(color: Colors.white54, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.xl),
          Center(
            child: Column(
              children: [
                Icon(Icons.wb_cloudy_rounded,
                    color: Colors.white.withOpacity(0.9), size: 72),
                const SizedBox(height: 8),
                const Text(
                  '$_kCurrentTemp°',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 64,
                    fontWeight: FontWeight.w200,
                  ),
                ),
                Text(
                  _kCondition,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'H:33°  L:26° · Feels like 35°',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          SizedBox(
            height: 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _kHourly.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final h = _kHourly[i];
                return Container(
                  width: 56,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        h.time,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                      Icon(h.icon, color: Colors.white, size: 22),
                      Text(
                        '${h.tempC}°',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: ZapSpacing.lg),
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '7-day forecast',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: ZapSpacing.sm),
                ..._kWeekly.map(
                  (d) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 36,
                          child: Text(
                            d.day,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Icon(d.icon, color: Colors.white, size: 20),
                        const Spacer(),
                        Text(
                          '${d.low}°',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${d.high}°',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.md),
          Text(
            'Mock forecast · decoy skin only',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.45),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab 1: Unlock ─────────────────────────────────────────────────────────────
class _UnlockTab extends ConsumerStatefulWidget {
  final VoidCallback onStartShake;
  final VoidCallback onStopShake;
  final VoidCallback onShakeSimulate;
  final VoidCallback onVolumeUnlock;

  const _UnlockTab({
    required this.onStartShake,
    required this.onStopShake,
    required this.onShakeSimulate,
    required this.onVolumeUnlock,
  });

  @override
  ConsumerState<_UnlockTab> createState() => _UnlockTabState();
}

class _UnlockTabState extends ConsumerState<_UnlockTab> {
  Timer? _volumeTimer;
  int _volumeElapsed = 0;

  @override
  void dispose() {
    _volumeTimer?.cancel();
    super.dispose();
  }

  void _startVolumeHold() {
    ref.read(_d233VolumeHoldingProvider.notifier).state = true;
    _volumeElapsed = 0;
    ref.read(_d233VolumeProgressProvider.notifier).state = 0;
    _volumeTimer?.cancel();
    _volumeTimer = Timer.periodic(const Duration(milliseconds: 50), (t) {
      _volumeElapsed += 50;
      final p = (_volumeElapsed / _kVolumeHoldMs).clamp(0.0, 1.0);
      ref.read(_d233VolumeProgressProvider.notifier).state = p;
      if (_volumeElapsed >= _kVolumeHoldMs) {
        t.cancel();
        ref.read(_d233VolumeHoldingProvider.notifier).state = false;
        widget.onVolumeUnlock();
      }
    });
  }

  void _cancelVolumeHold() {
    _volumeTimer?.cancel();
    ref.read(_d233VolumeHoldingProvider.notifier).state = false;
    ref.read(_d233VolumeProgressProvider.notifier).state = 0;
  }

  @override
  Widget build(BuildContext context) {
    final shakeCount = ref.watch(_d233ShakeCountProvider);
    final listening = ref.watch(_d233ShakeListeningProvider);
    final volumeProgress = ref.watch(_d233VolumeProgressProvider);
    final holding = ref.watch(_d233VolumeHoldingProvider);
    final unlockCount = ref.watch(_d233UnlockCountProvider);
    final lastMethod = ref.watch(_d233LastUnlockMethodProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: ZapColors.safe.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: ZapColors.safe.withOpacity(0.35)),
          ),
          child: const Text(
            '🟢 FRONTEND-ONLY · Section B Day 13/20 · LP24 weather decoy',
            style: TextStyle(color: ZapColors.safe, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        _UnlockCard(
          icon: Icons.vibration_rounded,
          color: const Color(0xFF3B82F6),
          title: 'Shake pattern',
          subtitle:
              '$_kShakeTarget shakes within ${_kShakeWindowMs ~/ 1000}s opens safety layer.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                listening
                    ? 'Listening… $shakeCount / $_kShakeTarget'
                    : 'Accelerometer listener off',
                style: const TextStyle(
                  color: ZapColors.textMuted,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: listening
                          ? widget.onStopShake
                          : widget.onStartShake,
                      child: Text(listening ? 'Stop listener' : 'Start listener'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: widget.onShakeSimulate,
                      child: const Text('Simulate 3 shakes'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        _UnlockCard(
          icon: Icons.volume_down_rounded,
          color: const Color(0xFF8B5CF6),
          title: 'Volume hold',
          subtitle:
              'Hold volume-down ${_kVolumeHoldMs ~/ 1000}s (simulated below). '
              'Day 234 configures real combo.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: volumeProgress,
                  minHeight: 8,
                  backgroundColor: ZapColors.border,
                  color: const Color(0xFF8B5CF6),
                ),
              ),
              const SizedBox(height: 8),
              Listener(
                onPointerDown: (_) => _startVolumeHold(),
                onPointerUp: (_) => _cancelVolumeHold(),
                onPointerCancel: (_) => _cancelVolumeHold(),
                child: Container(
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: holding
                        ? const Color(0xFF8B5CF6).withOpacity(0.2)
                        : ZapColors.bgElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: holding
                          ? const Color(0xFF8B5CF6)
                          : ZapColors.border,
                    ),
                  ),
                  child: Text(
                    holding
                        ? 'Hold… ${(volumeProgress * 100).round()}%'
                        : 'Press and hold (simulate volume-down)',
                    style: const TextStyle(
                      color: ZapColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.border),
          ),
          child: Text(
            unlockCount == 0
                ? 'No unlocks this session'
                : 'Unlocked $unlockCount time(s) · last: $lastMethod',
            style: const TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              label: const Text('Day 232 Calculator'),
              onPressed: () => context.push(AppRoutes.decoyCalculator),
            ),
            ActionChip(
              label: const Text('Day 234 Gesture config'),
              onPressed: () => context.push(AppRoutes.secretGestureConfig),
            ),
            ActionChip(
              label: const Text('Day 231 Icon disguise'),
              onPressed: () => context.push(AppRoutes.stealthIconDisguise),
            ),
          ],
        ),
      ],
    );
  }
}

class _UnlockCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget child;

  const _UnlockCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ZapColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: ZapColors.textMuted, fontSize: 10),
          ),
          const SizedBox(height: ZapSpacing.md),
          child,
        ],
      ),
    );
  }
}

// ── Tab 2: Safety ─────────────────────────────────────────────────────────────
class _SafetyTab extends StatelessWidget {
  const _SafetyTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.danger.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.danger.withOpacity(0.4)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.sos_rounded, color: ZapColors.danger),
                  SizedBox(width: 8),
                  Text(
                    'Hardware SOS always works',
                    style: TextStyle(
                      color: ZapColors.danger,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'Weather decoy does not disable power-button SOS, background DCS, '
                'or IMU fall detection. Only the visible UI is disguised.',
                style: TextStyle(color: ZapColors.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Decoy skins (LP24)',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        ListTile(
          dense: true,
          leading: const Icon(Icons.calculate_rounded, color: ZapColors.textMuted),
          title: const Text('Day 232 · Calculator',
              style: TextStyle(color: ZapColors.textPrimary, fontSize: 12)),
          subtitle: const Text('=== then 767',
              style: TextStyle(color: ZapColors.textMuted, fontSize: 10)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.push(AppRoutes.decoyCalculator),
        ),
        const ListTile(
          dense: true,
          leading: Icon(Icons.wb_sunny_rounded, color: Color(0xFF3B82F6)),
          title: Text('Day 233 · Weather (this screen)',
              style: TextStyle(color: ZapColors.textPrimary, fontSize: 12)),
          subtitle: Text('Shake ×3 or volume hold',
              style: TextStyle(color: ZapColors.textMuted, fontSize: 10)),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.border),
          ),
          child: const SelectableText(
            'Hive: hidden_mode_prefs.decoy_shell = "weather"\n'
            'shake_pattern: 3 peaks / 2.5s window\n'
            'volume_hold_ms: 2000\n'
            '→ secret_gesture_prefs (Day 234 hub)',
            style: TextStyle(
              color: ZapColors.textSecondary,
              fontFamily: 'monospace',
              fontSize: 10,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.info.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.info.withOpacity(0.3)),
          ),
          child: const Text(
            'Tomorrow: Day 240 — Section B milestone.',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _WeatherTabBar extends StatelessWidget {
  final int tab;
  final ValueChanged<int> onSelect;

  const _WeatherTabBar({required this.tab, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1565C0),
      child: Row(
        children: List.generate(_kTabs.length, (i) {
          final selected = tab == i;
          return Expanded(
            child: InkWell(
              onTap: () => onSelect(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected ? Colors.white : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  _kTabs[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white60,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 10,
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
