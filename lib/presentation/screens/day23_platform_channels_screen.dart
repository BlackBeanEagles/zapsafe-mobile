import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../domain/providers/platform_channel_providers.dart';
import '../../native/imu_sample.dart';
import '../../native/platform_channels.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';
import '../widgets/zap_snackbar.dart';

/// Day 23 — consolidated platform-channel surface.
///
/// Shows the three platform-channel domains side by side:
///   - Background service (Day 21 channel, displayed for completeness)
///   - Sensors EventChannel (Day 23 stub emits a 10-Hz sine waveform)
///   - Audio MethodChannel (Day 23 stub flips a boolean)
class Day23PlatformChannelsScreen extends ConsumerStatefulWidget {
  const Day23PlatformChannelsScreen({super.key});

  @override
  ConsumerState<Day23PlatformChannelsScreen> createState() =>
      _Day23PlatformChannelsScreenState();
}

class _Day23PlatformChannelsScreenState
    extends ConsumerState<Day23PlatformChannelsScreen> {
  bool _sensorRunning = false;

  @override
  Widget build(BuildContext context) {
    final sensor = ref.watch(sensorChannelProvider);
    final audio = ref.watch(audioChannelProvider);
    final imuAsync = ref.watch(imuStreamProvider);
    final audioRecording =
        ref.watch(audioRecordingProvider).valueOrNull ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Day 23 · Platform Channels'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(ZapSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeroBanner(),
              const SizedBox(height: ZapSpacing.xl),

              const _SectionLabel('CHANNEL REGISTRY'),
              const SizedBox(height: ZapSpacing.md),
              _RegistryCard(),

              const SizedBox(height: ZapSpacing.xl),

              const _SectionLabel('SENSOR EVENTCHANNEL · IMU STREAM'),
              const SizedBox(height: ZapSpacing.md),
              _SensorCard(
                supported: sensor.supported,
                running: _sensorRunning,
                sample: imuAsync.valueOrNull,
                onStart: () async {
                  final ok = await sensor.start();
                  if (!mounted) return;
                  setState(() => _sensorRunning = ok);
                  if (ok) {
                    ZapSnackbar.success(
                        context, 'Sensor stream started · 10 Hz synthetic waveform');
                  } else {
                    ZapSnackbar.warning(context, 'Sensor channel unavailable here');
                  }
                },
                onStop: () async {
                  await sensor.stop();
                  if (!mounted) return;
                  setState(() => _sensorRunning = false);
                  ZapSnackbar.info(context, 'Sensor stream stopped');
                },
              ),

              const SizedBox(height: ZapSpacing.xl),

              const _SectionLabel('AUDIO METHODCHANNEL'),
              const SizedBox(height: ZapSpacing.md),
              _AudioCard(
                supported: audio.supported,
                recording: audioRecording,
                onStart: () async {
                  final ok = await audio.start();
                  ref.invalidate(audioRecordingProvider);
                  if (!mounted) return;
                  if (ok) {
                    ZapSnackbar.success(
                        context, 'Audio capture started · stub for now');
                  } else {
                    ZapSnackbar.warning(context, 'Audio channel unavailable here');
                  }
                },
                onStop: () async {
                  await audio.stop();
                  ref.invalidate(audioRecordingProvider);
                  if (!mounted) return;
                  ZapSnackbar.info(context, 'Audio capture stopped');
                },
              ),

              const SizedBox(height: ZapSpacing.xxl),

              ZapButton.outlined(
                label: 'BACK TO INDEX',
                icon: Icons.arrow_back_rounded,
                fullWidth: true,
                onPressed: () => context.go('/'),
              ),
              const SizedBox(height: ZapSpacing.huge),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Hero ────────────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ZapColors.info.withOpacity(0.12),
            ZapColors.safe.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.info.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(ZapSpacing.sm),
                decoration: BoxDecoration(
                  color: ZapColors.info.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cable_rounded,
                    color: ZapColors.info, size: 22),
              ),
              const SizedBox(width: ZapSpacing.md),
              const ZapBadge(
                  label: 'MONTH 2 · WEEK 5 · DAY 23',
                  intent: ZapBadgeIntent.info),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          Text(
            'Platform Channels',
            style: ZapTypography.displaySmall.copyWith(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            'One Dart module, every channel — BackgroundServiceChannel + '
            'SensorChannel (EventChannel for IMU) + AudioChannel. The Kotlin '
            'side wires synthetic stubs so the pipeline is fully exercisable '
            'before real sensors land on Day 28 and AudioRecord on Day 26.',
            style: ZapTypography.bodyMedium.copyWith(
              color: ZapColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Registry ────────────────────────────────────────────────────────────────

class _RegistryCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final rows = <(String, String, String, Color)>[
      (
        'BackgroundServiceChannel',
        PlatformChannelNames.backgroundService,
        'MethodChannel · start / stop / isRunning · Day 21',
        ZapColors.danger,
      ),
      (
        'iOS BackgroundProcessing',
        PlatformChannelNames.iosBackground,
        'MethodChannel · scheduleNext / cancel · Day 22',
        ZapColors.info,
      ),
      (
        'SensorChannel · methods',
        PlatformChannelNames.sensors,
        'MethodChannel · start / stop / isStreaming · Day 23',
        ZapColors.warning,
      ),
      (
        'SensorChannel · events',
        PlatformChannelNames.sensorsEvents,
        'EventChannel · ImuSample broadcast · Day 23',
        ZapColors.warning,
      ),
      (
        'AudioChannel',
        PlatformChannelNames.audio,
        'MethodChannel · start / stop / isRecording · Day 23',
        ZapColors.safe,
      ),
    ];

    return ZapCard(
      child: Column(
        children: rows.map((r) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: ZapSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: ZapSpacing.sm),
                  decoration: BoxDecoration(
                    color: r.$4,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.$1,
                        style: ZapTypography.bodyMedium.copyWith(
                          color: ZapColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        r.$2,
                        style: ZapTypography.monoSmall.copyWith(
                          color: r.$4,
                        ),
                      ),
                      Text(
                        r.$3,
                        style: ZapTypography.bodySmall.copyWith(
                          color: ZapColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Sensor card ─────────────────────────────────────────────────────────────

class _SensorCard extends StatelessWidget {
  final bool supported;
  final bool running;
  final ImuSample? sample;
  final VoidCallback onStart;
  final VoidCallback onStop;

  const _SensorCard({
    required this.supported,
    required this.running,
    required this.sample,
    required this.onStart,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'IMU broadcast stream',
                  style: ZapTypography.bodyMedium.copyWith(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _statusChip(running, supported),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          if (sample != null && running) ...[
            _axisRow('ACCEL', sample!.ax, sample!.ay, sample!.az,
                sample!.accelMagnitude, ZapColors.danger),
            const SizedBox(height: ZapSpacing.xs),
            _axisRow('GYRO ', sample!.gx, sample!.gy, sample!.gz,
                sample!.gyroMagnitude, ZapColors.info),
            const SizedBox(height: ZapSpacing.xs),
            Text(
              't = ${sample!.timestampMs} ms',
              style: ZapTypography.monoSmall.copyWith(
                color: ZapColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ] else
            Text(
              running
                  ? 'Waiting for first sample…'
                  : 'Stream stopped. Press START to begin (synthetic stub on Day 23).',
              style: ZapTypography.bodySmall.copyWith(
                color: ZapColors.textSecondary,
              ),
            ),
          const SizedBox(height: ZapSpacing.md),
          Row(
            children: [
              Expanded(
                child: ZapButton.elevated(
                  label: 'START',
                  icon: Icons.play_arrow_rounded,
                  intent: ZapButtonIntent.safe,
                  onPressed: supported && !running ? onStart : null,
                ),
              ),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: ZapButton.outlined(
                  label: 'STOP',
                  icon: Icons.stop_rounded,
                  intent: ZapButtonIntent.warning,
                  onPressed: supported && running ? onStop : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _axisRow(
    String label,
    double x,
    double y,
    double z,
    double mag,
    Color accent,
  ) {
    String f(double v) => v.toStringAsFixed(2).padLeft(7);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: accent.withOpacity(0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: ZapTypography.labelSmall.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: ZapSpacing.sm),
        Expanded(
          child: Text(
            'x=${f(x)}  y=${f(y)}  z=${f(z)}  · |v|=${f(mag)}',
            style: ZapTypography.monoSmall.copyWith(
              color: ZapColors.textPrimary,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusChip(bool running, bool supported) {
    final (label, color) = !supported
        ? ('UNAVAILABLE', ZapColors.textSecondary)
        : running
            ? ('STREAMING', ZapColors.safe)
            : ('STOPPED', ZapColors.warning);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.sm, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: ZapTypography.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ─── Audio card ──────────────────────────────────────────────────────────────

class _AudioCard extends StatelessWidget {
  final bool supported;
  final bool recording;
  final VoidCallback onStart;
  final VoidCallback onStop;
  const _AudioCard({
    required this.supported,
    required this.recording,
    required this.onStart,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final (label, color) = !supported
        ? ('UNAVAILABLE', ZapColors.textSecondary)
        : recording
            ? ('RECORDING', ZapColors.safe)
            : ('IDLE', ZapColors.warning);

    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'AudioRecord pipeline',
                  style: ZapTypography.bodyMedium.copyWith(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.sm, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  label,
                  style: ZapTypography.labelSmall.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            'Day 23 stub flips a boolean. Day 26 wires AudioRecord at 16 kHz '
            'mono with a 450 ms sliding window and RMS-gated VAD.',
            style: ZapTypography.bodySmall.copyWith(
              color: ZapColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: ZapSpacing.md),
          Row(
            children: [
              Expanded(
                child: ZapButton.elevated(
                  label: 'START',
                  icon: Icons.mic_rounded,
                  intent: ZapButtonIntent.safe,
                  onPressed: supported && !recording ? onStart : null,
                ),
              ),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: ZapButton.outlined(
                  label: 'STOP',
                  icon: Icons.mic_off_rounded,
                  intent: ZapButtonIntent.warning,
                  onPressed: supported && recording ? onStop : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Section label ───────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: ZapTypography.labelSmall.copyWith(
            color: ZapColors.textSecondary,
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: ZapSpacing.md),
        const Expanded(child: Divider(color: ZapColors.border)),
      ],
    );
  }
}
