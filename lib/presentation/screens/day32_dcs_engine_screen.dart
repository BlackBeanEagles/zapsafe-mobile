import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/models/dcs_score.dart';
import '../../data/models/motion_features.dart';
import '../../domain/providers/inference_providers.dart';
import '../../ml/inference/dcs_inference_engine.dart';
import '../../native/audio_features.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';
import '../widgets/zap_snackbar.dart';

/// Day 32 — DCS composite engine surface.
///
/// Loads the engine, lets the user run synthetic scenarios through it
/// (calm / walking / scream + impact), and displays the per-model
/// breakdown plus fused score. Surfaces the per-slot REAL/STUB status
/// so the developer can see at a glance which models are live.
class Day32DcsEngineScreen extends ConsumerStatefulWidget {
  const Day32DcsEngineScreen({super.key});

  @override
  ConsumerState<Day32DcsEngineScreen> createState() =>
      _Day32DcsEngineScreenState();
}

class _Day32DcsEngineScreenState extends ConsumerState<Day32DcsEngineScreen> {
  DCSScore? _last;
  String? _lastScenario;
  bool _running = false;

  Future<void> _simulate(_Scenario scenario) async {
    setState(() => _running = true);
    try {
      final engineAsync = ref.read(dcsEngineProvider);
      final engine = engineAsync.valueOrNull;
      if (engine == null) {
        if (mounted) {
          ZapSnackbar.warning(context, 'Engine still loading');
        }
        return;
      }
      final result = await engine.infer(
        audio: scenario.audio(),
        motion: scenario.motion(),
        sceneFeatures: Float32List(8),
      );
      if (!mounted) return;
      setState(() {
        _last = result;
        _lastScenario = scenario.name;
      });
      ZapSnackbar.info(
        context,
        '${scenario.name}: fusion ${result.fusion.score.toStringAsFixed(3)}',
      );
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final engineAsync = ref.watch(dcsEngineProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Day 32 · DCS Engine'),
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

              const _SectionLabel('SLOT STATUS · 4 INTERPRETERS'),
              const SizedBox(height: ZapSpacing.md),
              engineAsync.when(
                loading: () => const _LoadingCard(),
                error: (e, _) => _ErrorCard(message: e.toString()),
                data: (engine) => _SlotTable(engine: engine),
              ),

              const SizedBox(height: ZapSpacing.xl),

              const _SectionLabel('SIMULATE A SCENARIO'),
              const SizedBox(height: ZapSpacing.md),
              _SimulationButtons(
                running: _running,
                onPick: _simulate,
              ),

              const SizedBox(height: ZapSpacing.xl),

              const _SectionLabel('LATEST DCS SCORE'),
              const SizedBox(height: ZapSpacing.md),
              if (_last == null)
                _EmptyCard(message: 'Pick a scenario above to run one pass.')
              else
                _DcsScoreCard(score: _last!, scenario: _lastScenario ?? '—'),

              const SizedBox(height: ZapSpacing.xl),

              const _SectionLabel('TRIGGER POLICY'),
              const SizedBox(height: ZapSpacing.md),
              _PolicyCard(),

              const SizedBox(height: ZapSpacing.xxl),

              ZapButton.outlined(
                label: 'OPEN DAY 31 · MODELS',
                icon: Icons.precision_manufacturing_rounded,
                fullWidth: true,
                onPressed: () => context.go('/tflite-models'),
              ),
              const SizedBox(height: ZapSpacing.sm),
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
                child: const Icon(Icons.hub_rounded,
                    color: ZapColors.danger, size: 22),
              ),
              const SizedBox(width: ZapSpacing.md),
              const ZapBadge(
                  label: 'MONTH 2 · WEEK 7 · DAY 32',
                  intent: ZapBadgeIntent.danger),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          Text(
            'DCS Inference Engine',
            style: ZapTypography.displaySmall.copyWith(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            'Four interpreters loaded in parallel · scream + motion + scene + '
            'fusion · per-slot stub fallback · synthesises "at rest" inputs '
            'when motion or scene aren\'t available. Returns a DCSScore '
            'every infer() call.',
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

// ─── Slot status table ──────────────────────────────────────────────────────

class _SlotTable extends StatelessWidget {
  final DCSInferenceEngine engine;
  const _SlotTable({required this.engine});

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Column(
        children: [
          for (final s in engine.slotStatuses)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: ZapSpacing.xs),
              child: Row(
                children: [
                  SizedBox(
                    width: 86,
                    child: Text(
                      s.slot,
                      style: ZapTypography.labelSmall.copyWith(
                        color: ZapColors.textSecondary,
                        letterSpacing: 1.0,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      s.label,
                      style: ZapTypography.monoSmall.copyWith(
                        color: ZapColors.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.sm, vertical: 3),
                    decoration: BoxDecoration(
                      color: (s.real ? ZapColors.safe : ZapColors.warning)
                          .withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      s.real ? 'REAL' : 'STUB',
                      style: ZapTypography.labelSmall.copyWith(
                        color: s.real ? ZapColors.safe : ZapColors.warning,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: ZapSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: ZapSpacing.sm, vertical: ZapSpacing.xs),
            decoration: BoxDecoration(
              color: ZapColors.info.withOpacity(0.10),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: ZapColors.info, size: 14),
                const SizedBox(width: ZapSpacing.xs),
                Expanded(
                  child: Text(
                    'engine.runs = ${engine.runs} · all 4 slots load in '
                    'parallel · partial failures fall back per-slot.',
                    style: ZapTypography.labelSmall.copyWith(
                      color: ZapColors.info,
                      letterSpacing: 0.8,
                    ),
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

// ─── Simulation buttons ──────────────────────────────────────────────────────

class _SimulationButtons extends StatelessWidget {
  final bool running;
  final void Function(_Scenario) onPick;

  const _SimulationButtons({required this.running, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final s in _scenarios)
          Padding(
            padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
            child: ZapButton.outlined(
              label: s.name,
              icon: s.icon,
              intent: s.intent,
              fullWidth: true,
              onPressed: running ? null : () => onPick(s),
            ),
          ),
      ],
    );
  }
}

// ─── DCS score card ──────────────────────────────────────────────────────────

class _DcsScoreCard extends StatelessWidget {
  final DCSScore score;
  final String scenario;
  const _DcsScoreCard({required this.score, required this.scenario});

  @override
  Widget build(BuildContext context) {
    final triggered = score.triggerCandidate;
    final headerColor = triggered ? ZapColors.danger : ZapColors.safe;

    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.sm, vertical: 3),
                decoration: BoxDecoration(
                  color: headerColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  triggered ? 'TRIGGER CANDIDATE' : 'BELOW THRESHOLD',
                  style: ZapTypography.labelSmall.copyWith(
                    color: headerColor,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                scenario,
                style: ZapTypography.labelSmall.copyWith(
                  color: ZapColors.textSecondary,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          for (final row in score.rows) _scoreRow(row.slot, row.result),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            't = ${score.timestampMs} · fusion → ${score.fusion.label} '
            '· ${score.fusion.latencyMs}ms',
            style: ZapTypography.monoSmall.copyWith(
              color: ZapColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreRow(String slot, dynamic result) {
    // `result` is `InferenceResult?`; we keep the type loose so this widget
    // doesn't need to import the model.
    final isNull = result == null;
    final label = isNull ? '—' : result.label;
    final score = isNull ? 0.0 : result.score as double;
    final color = score >= 0.7
        ? ZapColors.danger
        : score >= 0.4
            ? ZapColors.warning
            : ZapColors.safe;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ZapSpacing.xs),
      child: Row(
        children: [
          SizedBox(
            width: 86,
            child: Text(
              slot,
              style: ZapTypography.labelSmall.copyWith(
                color: ZapColors.textSecondary,
                letterSpacing: 1.0,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            width: 64,
            child: Text(
              label.toUpperCase(),
              style: ZapTypography.labelSmall.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: score.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: ZapColors.border,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
          const SizedBox(width: ZapSpacing.sm),
          SizedBox(
            width: 48,
            child: Text(
              score.toStringAsFixed(3),
              style: ZapTypography.monoSmall.copyWith(color: color),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Policy explainer ────────────────────────────────────────────────────────

class _PolicyCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row('Trigger candidate', 'fusion ≥ 0.70 (Day 29 default)',
              ZapColors.warning),
          _row('ALERT_PENDING fires', 'Day 33 layers a 3-window vote on top',
              ZapColors.danger),
          _row('Auto-SOS override', 'fusion ≥ 0.85 — bypass vote, fire now',
              ZapColors.danger),
          _row('Fusion stub weights', '0.5 audio · 0.3 motion · 0.2 scene',
              ZapColors.info),
          _row('Real fusion model', 'XGBoost · backend Month 7–8',
              ZapColors.info),
        ],
      ),
    );
  }

  Widget _row(String label, String detail, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: ZapTypography.labelSmall.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
          ),
          Expanded(
            child: Text(
              detail,
              style: ZapTypography.bodySmall.copyWith(
                color: ZapColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section + Empty + Loading + Error ──────────────────────────────────────

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

class _EmptyCard extends StatelessWidget {
  final String message;
  const _EmptyCard({required this.message});

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
        message,
        style: ZapTypography.bodySmall.copyWith(
          color: ZapColors.textSecondary,
        ),
      ),
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
          Text('Loading 4 interpreters in parallel…'),
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

// ─── Scenario builders ───────────────────────────────────────────────────────

class _Scenario {
  final String name;
  final IconData icon;
  final ZapButtonIntent intent;
  final AudioFeatures Function() audio;
  final MotionFeatures Function() motion;

  const _Scenario({
    required this.name,
    required this.icon,
    required this.intent,
    required this.audio,
    required this.motion,
  });
}

AudioFeatures _quietAudio() => AudioFeatures(
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      mfcc: List<double>.filled(13, 0),
      zcr: 0.05,
      spectralCentroidHz: 800,
    );

AudioFeatures _shoutAudio() => AudioFeatures(
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      mfcc: const [-40, 5, 8, -3, 4, 2, 1, 1, 0, 0, 0, 0, 0],
      zcr: 0.18,
      spectralCentroidHz: 2500,
    );

AudioFeatures _screamAudio() => AudioFeatures(
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      mfcc: const [-10, 20, 12, -4, 6, 3, 2, 1, 1, 0, 0, 0, 0],
      zcr: 0.30,
      spectralCentroidHz: 3800,
    );

final List<_Scenario> _scenarios = [
  _Scenario(
    name: 'CALM · phone on desk',
    icon: Icons.bed_rounded,
    intent: ZapButtonIntent.safe,
    audio: _quietAudio,
    motion: MotionFeatures.atRest,
  ),
  _Scenario(
    name: 'WALKING · normal commute',
    icon: Icons.directions_walk_rounded,
    intent: ZapButtonIntent.info,
    audio: _quietAudio,
    motion: MotionFeatures.walking,
  ),
  _Scenario(
    name: 'SHOUT + walking',
    icon: Icons.campaign_rounded,
    intent: ZapButtonIntent.warning,
    audio: _shoutAudio,
    motion: MotionFeatures.walking,
  ),
  _Scenario(
    name: 'SCREAM + impact',
    icon: Icons.warning_amber_rounded,
    intent: ZapButtonIntent.danger,
    audio: _screamAudio,
    motion: MotionFeatures.impact,
  ),
];
