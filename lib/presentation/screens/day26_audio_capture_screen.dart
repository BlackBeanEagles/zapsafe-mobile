import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../domain/providers/platform_channel_providers.dart';
import '../../native/audio_frame.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';
import '../widgets/zap_snackbar.dart';

/// Day 26 — Audio capture pipeline · 16 kHz mono PCM · 450 ms sliding window
/// · RMS-gated VAD · Hann-windowed for the FFT prep Day 27 will consume.
class Day26AudioCaptureScreen extends ConsumerStatefulWidget {
  const Day26AudioCaptureScreen({super.key});

  @override
  ConsumerState<Day26AudioCaptureScreen> createState() =>
      _Day26AudioCaptureScreenState();
}

class _Day26AudioCaptureScreenState
    extends ConsumerState<Day26AudioCaptureScreen> {
  bool _running = false;
  int _framesTotal = 0;
  int _framesVoiced = 0;
  int _framesSuppressed = 0;
  AudioFrame? _latestFrame;

  ProviderSubscription<AsyncValue<AudioFrame>>? _frameSub;

  @override
  void initState() {
    super.initState();
    // Subscribe imperatively so we can update local counters every frame
    // without rebuilding the whole tree.
    _frameSub = ref.listenManual<AsyncValue<AudioFrame>>(
      audioFrameStreamProvider,
      (_, next) {
        next.whenData((frame) {
          if (!mounted) return;
          setState(() {
            _latestFrame = frame;
            _framesTotal++;
            if (frame.voiced) {
              _framesVoiced++;
            } else {
              _framesSuppressed++;
            }
          });
        });
      },
    );
  }

  @override
  void dispose() {
    _frameSub?.close();
    super.dispose();
  }

  Future<void> _start() async {
    final ok = await ref.read(audioChannelProvider).start();
    if (!mounted) return;
    setState(() {
      _running = ok;
      if (ok) {
        _framesTotal = 0;
        _framesVoiced = 0;
        _framesSuppressed = 0;
        _latestFrame = null;
      }
    });
    if (ok) {
      ZapSnackbar.success(context,
          'Capture started · 450 ms windows · 16 kHz mono');
    } else {
      ZapSnackbar.warning(context,
          'Capture refused — grant Microphone permission first (Day 12)');
    }
  }

  Future<void> _stop() async {
    await ref.read(audioChannelProvider).stop();
    if (!mounted) return;
    setState(() => _running = false);
    ZapSnackbar.info(context, 'Capture stopped');
  }

  @override
  Widget build(BuildContext context) {
    final supported = ref.watch(audioChannelProvider).supported;
    final specAsync = ref.watch(audioCaptureSpecProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Day 26 · Audio Capture'),
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

              const _SectionLabel('LIVE RMS'),
              const SizedBox(height: ZapSpacing.md),
              _RmsCard(
                supported: supported,
                running: _running,
                latest: _latestFrame,
              ),

              const SizedBox(height: ZapSpacing.xl),

              const _SectionLabel('FRAME COUNTERS'),
              const SizedBox(height: ZapSpacing.md),
              _CountersCard(
                total: _framesTotal,
                voiced: _framesVoiced,
                suppressed: _framesSuppressed,
              ),

              const SizedBox(height: ZapSpacing.xl),

              const _SectionLabel('CAPTURE SPEC'),
              const SizedBox(height: ZapSpacing.md),
              specAsync.when(
                loading: () => const _LoadingCard(),
                error: (e, _) => _ErrorCard(message: e.toString()),
                data: (s) => _SpecCard(
                  sampleRateHz: s.sampleRateHz,
                  windowMs: s.windowMs,
                  vadThreshold: s.vadThreshold,
                ),
              ),

              const SizedBox(height: ZapSpacing.xl),

              Row(
                children: [
                  Expanded(
                    child: ZapButton.elevated(
                      label: 'START',
                      icon: Icons.mic_rounded,
                      intent: ZapButtonIntent.safe,
                      onPressed: supported && !_running ? _start : null,
                    ),
                  ),
                  const SizedBox(width: ZapSpacing.sm),
                  Expanded(
                    child: ZapButton.outlined(
                      label: 'STOP',
                      icon: Icons.mic_off_rounded,
                      intent: ZapButtonIntent.warning,
                      onPressed: supported && _running ? _stop : null,
                    ),
                  ),
                ],
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
            ZapColors.info.withOpacity(0.14),
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
                child: const Icon(Icons.graphic_eq_rounded,
                    color: ZapColors.info, size: 22),
              ),
              const SizedBox(width: ZapSpacing.md),
              const ZapBadge(
                  label: 'MONTH 2 · WEEK 6 · DAY 26',
                  intent: ZapBadgeIntent.info),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          Text(
            'Audio Capture · VAD',
            style: ZapTypography.displaySmall.copyWith(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            'AudioRecord 16 kHz mono PCM · 450 ms sliding window · RMS-gated '
            'VAD · Hann-windowed for the FFT prep Day 27 will consume. PCM '
            'samples never cross the channel — only the summary frame ships.',
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

// ─── RMS meter ───────────────────────────────────────────────────────────────

class _RmsCard extends StatelessWidget {
  final bool supported;
  final bool running;
  final AudioFrame? latest;
  const _RmsCard({
    required this.supported,
    required this.running,
    required this.latest,
  });

  @override
  Widget build(BuildContext context) {
    final voiced = latest?.voiced ?? false;
    final rms = latest?.rmsEnergy ?? 0;
    final fill = latest?.normalisedEnergy ?? 0;
    final color = voiced ? ZapColors.safe : ZapColors.textSecondary;
    final chipColor = !supported
        ? ZapColors.textSecondary
        : (!running
            ? ZapColors.warning
            : (voiced ? ZapColors.safe : ZapColors.textSecondary));
    final chipLabel = !supported
        ? 'ANDROID-ONLY'
        : (!running ? 'IDLE' : (voiced ? 'VOICED' : 'SILENT'));

    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'RMS energy',
                  style: ZapTypography.bodyMedium.copyWith(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.sm, vertical: 3),
                decoration: BoxDecoration(
                  color: chipColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  chipLabel,
                  style: ZapTypography.labelSmall.copyWith(
                    color: chipColor,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            child: LinearProgressIndicator(
              value: fill,
              minHeight: 14,
              backgroundColor: ZapColors.border,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: ZapSpacing.md),
          if (latest != null) ...[
            _kv('rms', rms.toStringAsFixed(1)),
            _kv('threshold', latest!.threshold.toStringAsFixed(0)),
            _kv('samples', latest!.sampleCount.toString()),
            _kv('window', '${latest!.windowMs} ms'),
            _kv('t', latest!.timestampMs.toString()),
          ] else
            Text(
              running
                  ? 'Waiting for first frame… (≤ 450 ms)'
                  : 'Tap START to begin capturing.',
              style: ZapTypography.bodySmall.copyWith(
                color: ZapColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 90,
              child: Text(
                k,
                style: ZapTypography.labelSmall.copyWith(
                  color: ZapColors.textSecondary,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Text(
              v,
              style: ZapTypography.monoSmall.copyWith(
                color: ZapColors.textPrimary,
              ),
            ),
          ],
        ),
      );
}

// ─── Counters ────────────────────────────────────────────────────────────────

class _CountersCard extends StatelessWidget {
  final int total;
  final int voiced;
  final int suppressed;
  const _CountersCard({
    required this.total,
    required this.voiced,
    required this.suppressed,
  });

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Row(
        children: [
          _counter('TOTAL', total, ZapColors.info),
          _counter('VOICED', voiced, ZapColors.safe),
          _counter('SUPPRESSED', suppressed, ZapColors.textSecondary),
        ],
      ),
    );
  }

  Widget _counter(String label, int value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: ZapTypography.labelSmall.copyWith(
              color: ZapColors.textSecondary,
              letterSpacing: 1.5,
            ),
          ),
          Text(
            value.toString(),
            style: ZapTypography.displaySmall.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Spec ────────────────────────────────────────────────────────────────────

class _SpecCard extends StatelessWidget {
  final int sampleRateHz;
  final int windowMs;
  final double vadThreshold;
  const _SpecCard({
    required this.sampleRateHz,
    required this.windowMs,
    required this.vadThreshold,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('Sample rate', sampleRateHz == 0 ? '—' : '$sampleRateHz Hz'),
      ('Window',      windowMs == 0 ? '—' : '$windowMs ms'),
      ('Samples / window',
          (sampleRateHz == 0 || windowMs == 0)
              ? '—'
              : '${sampleRateHz * windowMs ~/ 1000}'),
      ('VAD threshold', vadThreshold == 0 ? '—' : vadThreshold.toStringAsFixed(0)),
      ('Window function', 'Hann (applied in-place on voiced frames)'),
      ('PCM format', '16-bit mono'),
    ];
    return ZapCard(
      child: Column(
        children: rows.map((r) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 140,
                  child: Text(
                    r.$1,
                    style: ZapTypography.labelSmall.copyWith(
                      color: ZapColors.textSecondary,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    r.$2,
                    style: ZapTypography.monoSmall.copyWith(
                      color: ZapColors.textPrimary,
                    ),
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

// ─── Common helpers ──────────────────────────────────────────────────────────

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

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.border),
      ),
      child: const Row(
        children: [
          SizedBox(
              width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: ZapSpacing.md),
          Text('Reading native capture spec…'),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color: ZapColors.danger.withOpacity(0.1),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.danger.withOpacity(0.3)),
      ),
      child: Text(
        message,
        style: ZapTypography.bodySmall.copyWith(color: ZapColors.danger),
      ),
    );
  }
}
