import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/models/inference_result.dart';
import '../../domain/providers/inference_providers.dart';
import '../../domain/providers/platform_channel_providers.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';
import '../widgets/zap_snackbar.dart';

/// Day 29 — Flutter-side feature → inference surface.
///
/// Subscribes to the inference stream (which is the feature stream fed
/// through whatever [Interpreter] is wired in). The Day 31 real TFLite
/// interpreter will drop in via provider override with zero UI change.
class Day29InferenceScreen extends ConsumerStatefulWidget {
  const Day29InferenceScreen({super.key});

  @override
  ConsumerState<Day29InferenceScreen> createState() =>
      _Day29InferenceScreenState();
}

class _Day29InferenceScreenState
    extends ConsumerState<Day29InferenceScreen> {
  bool _running = false;
  InferenceResult? _latest;
  final List<InferenceResult> _recent = [];
  static const _maxRecent = 12;

  ProviderSubscription<AsyncValue<InferenceResult>>? _resultSub;

  @override
  void initState() {
    super.initState();

    // Listening to the inference stream also forces both the audio service
    // (which feeds it) and the interpreter to materialise.
    _resultSub = ref.listenManual<AsyncValue<InferenceResult>>(
      inferenceResultStreamProvider,
      (_, next) {
        next.whenData((result) {
          if (!mounted) return;
          setState(() {
            _latest = result;
            _recent.insert(0, result);
            if (_recent.length > _maxRecent) {
              _recent.removeRange(_maxRecent, _recent.length);
            }
          });
        });
      },
    );
  }

  @override
  void dispose() {
    _resultSub?.close();
    super.dispose();
  }

  Future<void> _start() async {
    ref.read(audioFeatureServiceProvider).start();
    final ok = await ref.read(audioChannelProvider).start();
    if (!mounted) return;
    setState(() {
      _running = ok;
      if (ok) {
        _recent.clear();
        _latest = null;
        ref.read(audioFeatureServiceProvider).resetStats();
      }
    });
    if (ok) {
      ZapSnackbar.success(context,
          'Capture + inference live · ${ref.read(interpreterProvider).modelLabel}');
    } else {
      ZapSnackbar.warning(context,
          'Audio capture refused · grant Microphone (Day 12) then retry');
    }
  }

  Future<void> _stop() async {
    await ref.read(audioChannelProvider).stop();
    await ref.read(audioFeatureServiceProvider).stop();
    if (!mounted) return;
    setState(() => _running = false);
    ZapSnackbar.info(context, 'Inference stopped');
  }

  @override
  Widget build(BuildContext context) {
    final supported = ref.watch(audioChannelProvider).supported;
    final featuresSupported = ref.watch(audioChannelProvider).featuresSupported;
    final service = ref.watch(audioFeatureServiceProvider);
    final interpreter = ref.watch(interpreterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Day 29 · Inference'),
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
              _HeroBanner(modelLabel: interpreter.modelLabel),
              const SizedBox(height: ZapSpacing.xl),

              const _SectionLabel('LATEST INFERENCE'),
              const SizedBox(height: ZapSpacing.md),
              _LatestCard(
                latest: _latest,
                running: _running,
                supported: supported,
                featuresSupported: featuresSupported,
              ),

              const SizedBox(height: ZapSpacing.xl),

              const _SectionLabel('STATS'),
              const SizedBox(height: ZapSpacing.md),
              _StatsCard(service: service),

              const SizedBox(height: ZapSpacing.xl),

              const _SectionLabel('INTERPRETER'),
              const SizedBox(height: ZapSpacing.md),
              _InterpreterCard(
                modelLabel: interpreter.modelLabel,
                expectedInputSize: interpreter.expectedInputSize,
                classLabels: interpreter.classLabels,
              ),

              const SizedBox(height: ZapSpacing.xl),

              const _SectionLabel('RECENT RESULTS · NEWEST FIRST'),
              const SizedBox(height: ZapSpacing.md),
              if (_recent.isEmpty)
                _EmptyResultsCard(running: _running)
              else
                Column(children: [
                  for (final r in _recent) _ResultRow(result: r),
                ]),

              const SizedBox(height: ZapSpacing.xl),

              Row(
                children: [
                  Expanded(
                    child: ZapButton.elevated(
                      label: 'START',
                      icon: Icons.psychology_rounded,
                      intent: ZapButtonIntent.safe,
                      onPressed:
                          (supported && featuresSupported && !_running) ? _start : null,
                    ),
                  ),
                  const SizedBox(width: ZapSpacing.sm),
                  Expanded(
                    child: ZapButton.outlined(
                      label: 'STOP',
                      icon: Icons.stop_rounded,
                      intent: ZapButtonIntent.warning,
                      onPressed:
                          (supported && featuresSupported && _running) ? _stop : null,
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
  final String modelLabel;
  const _HeroBanner({required this.modelLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ZapColors.danger.withOpacity(0.10),
            ZapColors.warning.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.danger.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(ZapSpacing.sm),
                decoration: BoxDecoration(
                  color: ZapColors.danger.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.psychology_rounded,
                    color: ZapColors.danger, size: 22),
              ),
              const SizedBox(width: ZapSpacing.md),
              const ZapBadge(
                  label: 'MONTH 2 · WEEK 6 · DAY 29',
                  intent: ZapBadgeIntent.danger),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          Text(
            'Feature → Inference Pipeline',
            style: ZapTypography.displaySmall.copyWith(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            'Day 27\'s 15-scalar Float32 vectors flow into a swappable Interpreter '
            'and out as InferenceResults. Active model: $modelLabel. Day 31\'s '
            'real .tflite drops in via provider override — zero UI change.',
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

// ─── Latest card ─────────────────────────────────────────────────────────────

class _LatestCard extends StatelessWidget {
  final InferenceResult? latest;
  final bool running;
  final bool supported;
  final bool featuresSupported;
  const _LatestCard({
    required this.latest,
    required this.running,
    required this.supported,
    required this.featuresSupported,
  });

  @override
  Widget build(BuildContext context) {
    if (!supported || !featuresSupported) {
      return ZapCard(
        child: Text(
          !supported
              ? 'Audio capture is not available on this platform.'
              : 'Feature extraction is Android-only today (iOS lands later).',
          style: ZapTypography.bodySmall.copyWith(
            color: ZapColors.textSecondary,
          ),
        ),
      );
    }
    if (latest == null) {
      return ZapCard(
        child: Text(
          running
              ? 'Waiting for first voiced window…'
              : 'Tap START to begin inference.',
          style: ZapTypography.bodySmall.copyWith(
            color: ZapColors.textSecondary,
          ),
        ),
      );
    }

    final color = _colorFor(latest!.severity);
    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(_iconFor(latest!.label), color: color, size: 26),
              ),
              const SizedBox(width: ZapSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      latest!.label.toUpperCase(),
                      style: ZapTypography.headlineSmall.copyWith(
                        color: ZapColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      'score ${latest!.score.toStringAsFixed(3)} · '
                      '${latest!.latencyMs}ms',
                      style: ZapTypography.monoSmall.copyWith(
                        color: ZapColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (latest!.isConfident)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: ZapColors.danger.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'TRIGGER',
                    style: ZapTypography.labelSmall.copyWith(
                      color: ZapColors.danger,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          for (final entry in latest!.classScores.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: _scoreBar(entry.key, entry.value),
            ),
        ],
      ),
    );
  }

  Widget _scoreBar(String label, double value) {
    final isTop = label == latest!.label;
    final c = isTop ? _colorFor(latest!.severity) : ZapColors.textSecondary;
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: ZapTypography.labelSmall.copyWith(
              color: c,
              fontWeight: isTop ? FontWeight.w700 : FontWeight.w400,
              letterSpacing: 1.0,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 8,
              backgroundColor: ZapColors.border,
              valueColor: AlwaysStoppedAnimation(c),
            ),
          ),
        ),
        const SizedBox(width: ZapSpacing.sm),
        SizedBox(
          width: 48,
          child: Text(
            value.toStringAsFixed(3),
            style: ZapTypography.monoSmall.copyWith(color: c),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Color _colorFor(InferenceSeverity s) => switch (s) {
        InferenceSeverity.none   => ZapColors.textSecondary,
        InferenceSeverity.low    => ZapColors.info,
        InferenceSeverity.medium => ZapColors.warning,
        InferenceSeverity.high   => ZapColors.danger,
      };

  IconData _iconFor(String label) => switch (label) {
        'scream' => Icons.warning_amber_rounded,
        'shout'  => Icons.campaign_rounded,
        _        => Icons.record_voice_over_rounded,
      };
}

// ─── Stats card ──────────────────────────────────────────────────────────────

class _StatsCard extends StatelessWidget {
  final dynamic service; // AudioFeatureService — avoiding type import in this file
  const _StatsCard({required this.service});

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Row(
        children: [
          _stat('FRAMES IN', '${service.framesIn}', ZapColors.info),
          _stat('INFERENCES', '${service.inferencesOut}', ZapColors.safe),
          _stat('TRIGGERS', '${service.triggersFired}', ZapColors.danger),
          _stat('AVG LAT', '${service.averageLatency.inMilliseconds}ms', ZapColors.warning),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
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
          const SizedBox(height: 2),
          Text(
            value,
            style: ZapTypography.headlineSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Interpreter card ────────────────────────────────────────────────────────

class _InterpreterCard extends StatelessWidget {
  final String modelLabel;
  final int expectedInputSize;
  final List<String> classLabels;
  const _InterpreterCard({
    required this.modelLabel,
    required this.expectedInputSize,
    required this.classLabels,
  });

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kv('Model', modelLabel),
          _kv('Input size', '$expectedInputSize × Float32'),
          _kv('Classes', classLabels.join(' · ')),
          _kv('Real TFLite', 'Day 31'),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(
              width: 110,
              child: Text(
                k,
                style: ZapTypography.labelSmall.copyWith(
                  color: ZapColors.textSecondary,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Expanded(
              child: Text(
                v,
                style: ZapTypography.monoSmall.copyWith(
                  color: ZapColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      );
}

// ─── Result row ──────────────────────────────────────────────────────────────

class _ResultRow extends StatelessWidget {
  final InferenceResult result;
  const _ResultRow({required this.result});

  @override
  Widget build(BuildContext context) {
    final color = switch (result.severity) {
      InferenceSeverity.none   => ZapColors.textSecondary,
      InferenceSeverity.low    => ZapColors.info,
      InferenceSeverity.medium => ZapColors.warning,
      InferenceSeverity.high   => ZapColors.danger,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: ZapSpacing.md, vertical: 6),
        decoration: BoxDecoration(
          color: ZapColors.bgCard,
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: ZapColors.border),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              child: Text(
                result.label.toUpperCase(),
                style: ZapTypography.labelSmall.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            Expanded(
              child: Text(
                result.score.toStringAsFixed(3),
                style: ZapTypography.monoSmall.copyWith(color: color),
              ),
            ),
            Text(
              '${result.latencyMs}ms',
              style: ZapTypography.monoSmall.copyWith(
                color: ZapColors.textSecondary,
              ),
            ),
            if (result.isConfident) ...[
              const SizedBox(width: ZapSpacing.sm),
              const Icon(Icons.warning_amber_rounded,
                  color: ZapColors.danger, size: 16),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Empty + Section helpers ─────────────────────────────────────────────────

class _EmptyResultsCard extends StatelessWidget {
  final bool running;
  const _EmptyResultsCard({required this.running});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.border),
      ),
      child: Text(
        running ? 'No inferences yet.' : 'Start to begin streaming inferences.',
        style: ZapTypography.bodySmall.copyWith(
          color: ZapColors.textSecondary,
        ),
      ),
    );
  }
}

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
