import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../domain/providers/platform_channel_providers.dart';
import '../../native/audio_features.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';
import '../widgets/zap_snackbar.dart';

/// Day 27 — Feature extraction surface.
///
/// Subscribes to the feature stream and renders MFCC coefficients as a
/// signed bar chart, with ZCR + spectral centroid as scalar readouts.
class Day27AudioFeaturesScreen extends ConsumerStatefulWidget {
  const Day27AudioFeaturesScreen({super.key});

  @override
  ConsumerState<Day27AudioFeaturesScreen> createState() =>
      _Day27AudioFeaturesScreenState();
}

class _Day27AudioFeaturesScreenState
    extends ConsumerState<Day27AudioFeaturesScreen> {
  bool _running = false;
  AudioFeatures? _latest;

  ProviderSubscription<AsyncValue<AudioFeatures>>? _featureSub;

  @override
  void initState() {
    super.initState();
    _featureSub = ref.listenManual<AsyncValue<AudioFeatures>>(
      audioFeatureStreamProvider,
      (_, next) {
        next.whenData((feature) {
          if (!mounted) return;
          setState(() {
            _latest = feature;
          });
        });
      },
    );
  }

  @override
  void dispose() {
    _featureSub?.close();
    super.dispose();
  }

  Future<void> _start() async {
    final ok = await ref.read(audioChannelProvider).start();
    if (!mounted) return;
    setState(() {
      _running = ok;
      if (ok) {
        _latest = null;
      }
    });
    if (ok) {
      ZapSnackbar.success(
          context, 'Capture started · features stream live on voiced windows');
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
    final specAsync = ref.watch(audioFeatureSpecProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Day 27 · Audio Features'),
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

              const _SectionLabel('LIVE FEATURE VECTOR'),
              const SizedBox(height: ZapSpacing.md),
              _VectorCard(latest: _latest, running: _running, supported: supported),

              const SizedBox(height: ZapSpacing.xl),

              const _SectionLabel('MFCC BAR CHART · 13 COEFFICIENTS'),
              const SizedBox(height: ZapSpacing.md),
              _MfccChart(features: _latest),

              const SizedBox(height: ZapSpacing.xl),

              const _SectionLabel('EXTRACTOR SPEC'),
              const SizedBox(height: ZapSpacing.md),
              specAsync.when(
                loading: () => const _LoadingCard(),
                error: (e, _) => _ErrorCard(message: e.toString()),
                data: (s) => _SpecCard(
                  mfccCount: s.mfccCount,
                  melBins: s.melBins,
                  fftSize: s.fftSize,
                ),
              ),

              const SizedBox(height: ZapSpacing.xl),

              Container(
                padding: const EdgeInsets.all(ZapSpacing.md),
                decoration: BoxDecoration(
                  color: ZapColors.info.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                  border: Border.all(color: ZapColors.info.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: ZapColors.info, size: 18),
                    const SizedBox(width: ZapSpacing.sm),
                    Expanded(
                      child: Text(
                        'Feature vectors only emit on VOICED windows. Silent '
                        'frames are skipped at the VAD gate to save battery '
                        'and inference cycles. Day 31\'s TFLite scream '
                        'classifier consumes the same 15-scalar Float32 layout.',
                        style: ZapTypography.bodySmall.copyWith(
                          color: ZapColors.textPrimary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
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
            ZapColors.warning.withOpacity(0.10),
            ZapColors.info.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.warning.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(ZapSpacing.sm),
                decoration: BoxDecoration(
                  color: ZapColors.warning.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.science_rounded,
                    color: ZapColors.warning, size: 22),
              ),
              const SizedBox(width: ZapSpacing.md),
              const ZapBadge(
                  label: 'MONTH 2 · WEEK 6 · DAY 27',
                  intent: ZapBadgeIntent.warning),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          Text(
            'MFCC Feature Extraction',
            style: ZapTypography.displaySmall.copyWith(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            'Pure-Kotlin radix-2 FFT · 26-bin Mel filterbank · DCT-II → 13 MFCC '
            'coefficients. Plus ZCR + spectral centroid. 15 scalars per voiced '
            'window — exactly the input layer Day 31\'s scream classifier needs.',
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

// ─── Live vector card ────────────────────────────────────────────────────────

class _VectorCard extends StatelessWidget {
  final AudioFeatures? latest;
  final bool running;
  final bool supported;
  const _VectorCard({
    required this.latest,
    required this.running,
    required this.supported,
  });

  @override
  Widget build(BuildContext context) {
    if (latest == null) {
      return ZapCard(
        child: Text(
          !supported
              ? 'Feature extraction is Android-only today.'
              : (running
                  ? 'Waiting for first voiced window…'
                  : 'Press START to begin capturing.'),
          style: ZapTypography.bodySmall.copyWith(
            color: ZapColors.textSecondary,
          ),
        ),
      );
    }
    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kv('t', latest!.timestampMs.toString()),
          _kv('dimension', '${latest!.dimension} scalars'),
          _kv('zcr', latest!.zcr.toStringAsFixed(4)),
          _kv('centroid', '${latest!.spectralCentroidHz.toStringAsFixed(1)} Hz'),
          _kv('mfcc[0]', latest!.mfcc.isEmpty ? '—' : latest!.mfcc[0].toStringAsFixed(2)),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 100,
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

// ─── MFCC bar chart ──────────────────────────────────────────────────────────

class _MfccChart extends StatelessWidget {
  final AudioFeatures? features;
  const _MfccChart({required this.features});

  @override
  Widget build(BuildContext context) {
    final coeffs = features?.mfcc ?? const <double>[];
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.border),
      ),
      child: SizedBox(
        height: 180,
        child: coeffs.isEmpty
            ? Center(
                child: Text(
                  'No coefficients yet · waiting for voiced window',
                  style: ZapTypography.bodySmall.copyWith(
                    color: ZapColors.textSecondary,
                  ),
                ),
              )
            : CustomPaint(
                size: const Size(double.infinity, 180),
                painter: _MfccPainter(coeffs: coeffs),
              ),
      ),
    );
  }
}

class _MfccPainter extends CustomPainter {
  final List<double> coeffs;
  _MfccPainter({required this.coeffs});

  @override
  void paint(Canvas canvas, Size size) {
    if (coeffs.isEmpty) return;
    // We render each MFCC as a vertical bar centred on the horizontal mid-line.
    // The amplitude is normalised against the max-abs across this frame so
    // bars are visually comparable regardless of the absolute MFCC scale.
    final maxAbs = coeffs.fold<double>(
      0,
      (acc, v) => math.max(acc, v.abs()),
    );
    if (maxAbs == 0) return;

    final n = coeffs.length;
    final paint = Paint();
    final midY = size.height / 2;
    final barWidth = (size.width - (n - 1) * 4) / n;
    final maxBarHalf = midY - 8;

    // Zero-axis line.
    canvas.drawLine(
      Offset(0, midY),
      Offset(size.width, midY),
      Paint()
        ..color = ZapColors.border
        ..strokeWidth = 1,
    );

    for (var i = 0; i < n; i++) {
      final v = coeffs[i];
      final norm = (v / maxAbs).clamp(-1.0, 1.0);
      final barHeight = norm * maxBarHalf;
      final x = i * (barWidth + 4);
      final color = norm >= 0 ? ZapColors.safe : ZapColors.danger;
      paint.color = color;

      final rect = Rect.fromLTRB(
        x,
        norm >= 0 ? midY - barHeight : midY,
        x + barWidth,
        norm >= 0 ? midY : midY - barHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MfccPainter old) =>
      !_listsEqual(old.coeffs, coeffs);

  bool _listsEqual(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

// ─── Spec card ───────────────────────────────────────────────────────────────

class _SpecCard extends StatelessWidget {
  final int mfccCount;
  final int melBins;
  final int fftSize;
  const _SpecCard({
    required this.mfccCount,
    required this.melBins,
    required this.fftSize,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('MFCC count', mfccCount == 0 ? '—' : '$mfccCount coefficients'),
      ('Mel filterbank', melBins == 0 ? '—' : '$melBins triangular bins · 0 – 8 kHz'),
      ('FFT size', fftSize == 0 ? '—' : '$fftSize samples (radix-2)'),
      ('Window function', 'Hann (applied by Day 26)'),
      ('Channel', 'com.zapsafe/audio.features · EventChannel'),
      ('Output', 'Float32 ready (toFloat32Tensor)'),
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
          Text('Reading extractor spec…'),
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
