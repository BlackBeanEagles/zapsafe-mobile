import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/models/dcs_score.dart';
import '../../data/models/motion_features.dart';
import '../../data/models/trigger_event.dart';
import '../../domain/providers/inference_providers.dart';
import '../../ml/inference/dcs_score_watcher.dart';
import '../../native/audio_features.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';
import '../widgets/zap_snackbar.dart';

/// Day 33 — DCS stream + score-watcher live surface.
///
/// Combines two perspectives the Day 32 screen lacked:
///   1. A rolling stream of fusion-scream probabilities so the user can
///      see the noise floor and watch the vote progress in real time.
///   2. A trigger-event log that lets the developer verify the 3-window
///      vote and the auto-SOS bypass are firing on the right thresholds.
class Day33DcsStreamScreen extends ConsumerStatefulWidget {
  const Day33DcsStreamScreen({super.key});

  @override
  ConsumerState<Day33DcsStreamScreen> createState() =>
      _Day33DcsStreamScreenState();
}

class _Day33DcsStreamScreenState
    extends ConsumerState<Day33DcsStreamScreen> {
  final List<double> _recentFusion = [];
  static const int _historyLen = 24;
  final List<TriggerEvent> _events = [];
  static const int _maxEvents = 8;

  ProviderSubscription<AsyncValue<DCSScore>>? _scoreSub;
  ProviderSubscription<AsyncValue<TriggerEvent>>? _eventSub;

  @override
  void initState() {
    super.initState();
    // Trigger eager-init of the providers (otherwise StreamProviders
    // don't subscribe until something `watch`es them).
    _scoreSub = ref.listenManual<AsyncValue<DCSScore>>(
      dcsStreamProvider,
      (_, next) {
        next.whenData((score) {
          if (!mounted) return;
          final scream = score.fusion.classScores['scream'] ?? 0;
          setState(() {
            _recentFusion.add(scream);
            if (_recentFusion.length > _historyLen) {
              _recentFusion.removeRange(
                  0, _recentFusion.length - _historyLen);
            }
          });
        });
      },
    );
    _eventSub = ref.listenManual<AsyncValue<TriggerEvent>>(
      triggerEventStreamProvider,
      (_, next) {
        next.whenData((event) {
          if (!mounted) return;
          setState(() {
            _events.insert(0, event);
            if (_events.length > _maxEvents) {
              _events.removeRange(_maxEvents, _events.length);
            }
          });
          ZapSnackbar.warning(
            context,
            '${event.kind.label} fired · scream ${event.fusedScream.toStringAsFixed(3)}',
          );
        });
      },
    );
  }

  @override
  void dispose() {
    _scoreSub?.close();
    _eventSub?.close();
    super.dispose();
  }

  /// Bypasses native capture and feeds a single synthetic DCSScore
  /// directly to the watcher so the vote can be exercised on a host VM /
  /// silent emulator. The watcher is the same instance the live stream
  /// uses, so each call advances vote state for real.
  Future<void> _injectScore({required double targetFusion}) async {
    final engineAsync = ref.read(dcsEngineProvider);
    final engine = engineAsync.valueOrNull;
    if (engine == null) {
      ZapSnackbar.warning(context, 'Engine still loading');
      return;
    }
    // Construct an audio feature vector that pushes the fusion score to
    // the target band. The engine layout: mfcc[0]→energy band,
    // features[13]→ZCR, features[14]→centroid. We brute-force the
    // higher end of each so the audio path dominates.
    final mfcc = List<double>.filled(13, 0);
    mfcc[0] = targetFusion < 0.4 ? -60 : -5;
    final audio = AudioFeatures(
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      mfcc: mfcc,
      zcr: targetFusion < 0.4 ? 0.02 : 0.5,
      spectralCentroidHz: targetFusion < 0.4 ? 400 : 6000,
    );
    final score = await engine.infer(
      audio: audio,
      motion: MotionFeatures.atRest(timestampMs: audio.timestampMs),
    );

    // Direct observation — bypass the stream so the synthetic injection
    // is deterministic.
    final watcher = ref.read(dcsScoreWatcherProvider);
    final scream = score.fusion.classScores['scream'] ?? 0;

    setState(() {
      _recentFusion.add(scream);
      if (_recentFusion.length > _historyLen) {
        _recentFusion.removeRange(0, _recentFusion.length - _historyLen);
      }
    });

    final event = watcher.observe(score);
    if (event != null) {
      setState(() {
        _events.insert(0, event);
        if (_events.length > _maxEvents) {
          _events.removeRange(_maxEvents, _events.length);
        }
      });
      if (mounted) {
        ZapSnackbar.warning(
          context,
          '${event.kind.label} · vote=${event.consecutiveWindows} · scream=${scream.toStringAsFixed(2)}',
        );
      }
    } else {
      setState(() {});
      if (mounted) {
        ZapSnackbar.info(
          context,
          'scream=${scream.toStringAsFixed(2)} · vote=${watcher.currentConsecutive}/3',
        );
      }
    }
  }

  void _resetWatcher() {
    final watcher = ref.read(dcsScoreWatcherProvider);
    watcher.reset();
    setState(() {});
    ZapSnackbar.info(context, 'Vote state cleared');
  }

  @override
  Widget build(BuildContext context) {
    final watcher = ref.watch(dcsScoreWatcherProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Day 33 · DCS Stream'),
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

              const _SectionLabel('VOTE PROGRESS'),
              const SizedBox(height: ZapSpacing.md),
              _VoteCard(watcher: watcher),

              const SizedBox(height: ZapSpacing.xl),

              const _SectionLabel('RECENT FUSION-SCREAM · LAST 24 WINDOWS'),
              const SizedBox(height: ZapSpacing.md),
              _Sparkline(
                values: _recentFusion,
                alertThreshold: DCSScoreWatcher.alertThreshold,
                autoSosThreshold: DCSScoreWatcher.autoSosThreshold,
              ),

              const SizedBox(height: ZapSpacing.xl),

              const _SectionLabel('INJECT SYNTHETIC SCORE'),
              const SizedBox(height: ZapSpacing.md),
              _InjectButtons(onInject: _injectScore, onReset: _resetWatcher),

              const SizedBox(height: ZapSpacing.xl),

              const _SectionLabel('TRIGGER EVENT LOG'),
              const SizedBox(height: ZapSpacing.md),
              if (_events.isEmpty)
                _EmptyCard(
                  message: 'No triggers yet. Inject 3+ HIGH scores in a row.',
                )
              else
                Column(children: [
                  for (final e in _events) _EventRow(event: e),
                ]),

              const SizedBox(height: ZapSpacing.xxl),

              ZapButton.outlined(
                label: 'OPEN DAY 32 · ENGINE',
                icon: Icons.hub_rounded,
                fullWidth: true,
                onPressed: () => context.go('/dcs-engine'),
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
                child: const Icon(Icons.equalizer_rounded,
                    color: ZapColors.danger, size: 22),
              ),
              const SizedBox(width: ZapSpacing.md),
              const ZapBadge(
                  label: 'MONTH 2 · WEEK 7 · DAY 33',
                  intent: ZapBadgeIntent.danger),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          Text(
            'DCS Stream & Watcher',
            style: ZapTypography.displaySmall.copyWith(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            'fusion-scream probability per window · 3-window vote (≥ 0.75) '
            '→ ALERT_PENDING · single-window override (≥ 0.85) → AUTO_SOS · '
            'LP25 passive flag set on every trigger.',
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

// ─── Vote card ───────────────────────────────────────────────────────────────

class _VoteCard extends StatelessWidget {
  final DCSScoreWatcher watcher;
  const _VoteCard({required this.watcher});

  @override
  Widget build(BuildContext context) {
    final current = watcher.currentConsecutive;
    final required = DCSScoreWatcher.requiredConsecutiveWindows;
    final last = watcher.lastFusedScream;

    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 0; i < required; i++) ...[
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: i < current
                        ? ZapColors.danger
                        : ZapColors.border,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    i < current
                        ? Icons.check_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                if (i < required - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: i < current - 1
                          ? ZapColors.danger
                          : ZapColors.border,
                    ),
                  ),
              ],
              const SizedBox(width: ZapSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: ZapColors.info.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$current / $required',
                  style: ZapTypography.labelSmall.copyWith(
                    color: ZapColors.info,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          _kv('Last fusion-scream', last.toStringAsFixed(3)),
          _kv('Alert threshold', DCSScoreWatcher.alertThreshold.toString()),
          _kv('Auto-SOS threshold', DCSScoreWatcher.autoSosThreshold.toString()),
          _kv('Vote window', '$required consecutive ≥ alert'),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 140,
              child: Text(k,
                  style: ZapTypography.labelSmall.copyWith(
                    color: ZapColors.textSecondary,
                    letterSpacing: 1.2,
                  )),
            ),
            Text(v,
                style: ZapTypography.monoSmall.copyWith(
                  color: ZapColors.textPrimary,
                )),
          ],
        ),
      );
}

// ─── Sparkline ───────────────────────────────────────────────────────────────

class _Sparkline extends StatelessWidget {
  final List<double> values;
  final double alertThreshold;
  final double autoSosThreshold;

  const _Sparkline({
    required this.values,
    required this.alertThreshold,
    required this.autoSosThreshold,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.border),
      ),
      child: values.isEmpty
          ? Center(
              child: Text(
                'No data yet · inject scores or start capture.',
                style: ZapTypography.bodySmall.copyWith(
                  color: ZapColors.textSecondary,
                ),
              ),
            )
          : CustomPaint(
              painter: _SparkPainter(
                values: values,
                alertThreshold: alertThreshold,
                autoSosThreshold: autoSosThreshold,
              ),
              size: Size.infinite,
            ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> values;
  final double alertThreshold;
  final double autoSosThreshold;

  _SparkPainter({
    required this.values,
    required this.alertThreshold,
    required this.autoSosThreshold,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const double yMax = 1.0;
    double yFor(double v) => size.height * (1 - (v / yMax).clamp(0, 1));

    // Threshold lines
    final alertPaint = Paint()
      ..color = ZapColors.warning.withOpacity(0.6)
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(0, yFor(alertThreshold)),
      Offset(size.width, yFor(alertThreshold)),
      alertPaint,
    );
    final sosPaint = Paint()
      ..color = ZapColors.danger.withOpacity(0.6)
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(0, yFor(autoSosThreshold)),
      Offset(size.width, yFor(autoSosThreshold)),
      sosPaint,
    );

    // Bars
    final stride = size.width / values.length;
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      final color = v >= autoSosThreshold
          ? ZapColors.danger
          : v >= alertThreshold
              ? ZapColors.warning
              : ZapColors.safe;
      final barPaint = Paint()..color = color;
      final left = i * stride + 1;
      final right = left + stride - 2;
      final top = yFor(v);
      canvas.drawRect(
        Rect.fromLTRB(left, top, right, size.height),
        barPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.values != values ||
      old.alertThreshold != alertThreshold ||
      old.autoSosThreshold != autoSosThreshold;
}

// ─── Inject buttons ──────────────────────────────────────────────────────────

class _InjectButtons extends StatelessWidget {
  final Future<void> Function({required double targetFusion}) onInject;
  final VoidCallback onReset;
  const _InjectButtons({required this.onInject, required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ZapButton.outlined(
          label: 'INJECT CALM · target 0.10',
          icon: Icons.air_rounded,
          intent: ZapButtonIntent.safe,
          fullWidth: true,
          onPressed: () => onInject(targetFusion: 0.1),
        ),
        const SizedBox(height: ZapSpacing.sm),
        ZapButton.outlined(
          label: 'INJECT HIGH · target 0.80 (alert vote tick)',
          icon: Icons.warning_amber_rounded,
          intent: ZapButtonIntent.warning,
          fullWidth: true,
          onPressed: () => onInject(targetFusion: 0.8),
        ),
        const SizedBox(height: ZapSpacing.sm),
        ZapButton.elevated(
          label: 'INJECT CRITICAL · target 0.90 (AUTO_SOS bypass)',
          icon: Icons.bolt_rounded,
          intent: ZapButtonIntent.danger,
          fullWidth: true,
          onPressed: () => onInject(targetFusion: 0.9),
        ),
        const SizedBox(height: ZapSpacing.sm),
        ZapButton.outlined(
          label: 'RESET VOTE',
          icon: Icons.refresh_rounded,
          intent: ZapButtonIntent.neutral,
          fullWidth: true,
          onPressed: onReset,
        ),
      ],
    );
  }
}

// ─── Event row ───────────────────────────────────────────────────────────────

class _EventRow extends StatelessWidget {
  final TriggerEvent event;
  const _EventRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final isAutoSos = event.kind == TriggerKind.autoSos;
    final color = isAutoSos ? ZapColors.danger : ZapColors.warning;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: ZapSpacing.md, vertical: ZapSpacing.sm),
        decoration: BoxDecoration(
          color: ZapColors.bgCard,
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Icon(
              isAutoSos ? Icons.bolt_rounded : Icons.warning_amber_rounded,
              color: color,
              size: 18,
            ),
            const SizedBox(width: ZapSpacing.sm),
            SizedBox(
              width: 110,
              child: Text(
                event.kind.label,
                style: ZapTypography.labelSmall.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            Expanded(
              child: Text(
                'scream=${event.fusedScream.toStringAsFixed(3)} · '
                'votes=${event.consecutiveWindows} · passive=${event.passive}',
                style: ZapTypography.monoSmall.copyWith(
                  color: ZapColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty + Section ─────────────────────────────────────────────────────────

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
