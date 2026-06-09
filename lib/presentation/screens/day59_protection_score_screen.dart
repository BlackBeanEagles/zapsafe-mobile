/// Day 59 — Protection Score Screen
///
/// Shows the user's live Protection Score (0-100), a 7-component breakdown,
/// ranked next-actions, and a 30-day sparkline history.
///
/// GET /api/v1/protection-score/         — score + breakdown + next_actions
/// GET /api/v1/protection-score/history/ — 30-day daily snapshots
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/services/protection_score_service.dart';
import '../../domain/providers/protection_score_providers.dart';

// ─── Screen ───────────────────────────────────────────────────────────────────

class Day59ProtectionScoreScreen extends ConsumerWidget {
  const Day59ProtectionScoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scoreAsync   = ref.watch(protectionScoreProvider);
    final historyAsync = ref.watch(protectionScoreHistoryProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: ZapColors.bgPrimary,
        title: const Text('Protection Score'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(protectionScoreProvider);
              ref.invalidate(protectionScoreHistoryProvider);
            },
          ),
        ],
      ),
      body: scoreAsync.when(
        loading: () => const _LoadingState(),
        error: (e, _) => _ErrorState(
          message: e.toString(),
          onRetry: () {
            ref.invalidate(protectionScoreProvider);
            ref.invalidate(protectionScoreHistoryProvider);
          },
        ),
        data: (result) => _ScoreBody(
          result:       result,
          historyAsync: historyAsync,
        ),
      ),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _ScoreBody extends StatelessWidget {
  const _ScoreBody({
    required this.result,
    required this.historyAsync,
  });

  final ProtectionScoreResult        result;
  final AsyncValue<ScoreHistory>     historyAsync;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ScoreHero(result: result),
          const SizedBox(height: ZapSpacing.xl),
          if (result.nextActions.isNotEmpty) ...[
            _NextActionsCard(actions: result.nextActions),
            const SizedBox(height: ZapSpacing.lg),
          ],
          _BreakdownCard(components: result.breakdown),
          const SizedBox(height: ZapSpacing.lg),
          _HistoryCard(historyAsync: historyAsync),
          const SizedBox(height: ZapSpacing.xxxl),
        ],
      ),
    );
  }
}

// ─── Score hero ───────────────────────────────────────────────────────────────

class _ScoreHero extends StatelessWidget {
  const _ScoreHero({required this.result});
  final ProtectionScoreResult result;

  @override
  Widget build(BuildContext context) {
    final color = _bandColor(result.band);
    final ts    = DateFormat('d MMM, HH:mm').format(result.lastUpdated);

    return Column(
      children: [
        // Circular score gauge
        SizedBox(
          width: 160,
          height: 160,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(160, 160),
                painter: _ArcPainter(
                  fraction: result.score / 100,
                  color:    color,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${result.score}',
                    style: ZapTypography.displayMedium.copyWith(
                      color:      color,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '/ 100',
                    style: ZapTypography.labelSmall.copyWith(
                      color: ZapColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        // Band badge
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: ZapSpacing.md,
            vertical:   ZapSpacing.xs,
          ),
          decoration: BoxDecoration(
            color:        color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border:       Border.all(color: color.withOpacity(0.4)),
          ),
          child: Text(
            result.band.toUpperCase(),
            style: ZapTypography.labelMedium.copyWith(
              color:       color,
              fontWeight:  FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Text(
          'Updated $ts',
          style: ZapTypography.labelSmall.copyWith(
            color: ZapColors.textMuted,
          ),
        ),
      ],
    );
  }
}

// ─── Arc painter ──────────────────────────────────────────────────────────────

class _ArcPainter extends CustomPainter {
  const _ArcPainter({required this.fraction, required this.color});
  final double fraction;
  final Color  color;

  @override
  void paint(Canvas canvas, Size size) {
    final cx  = size.width  / 2;
    final cy  = size.height / 2;
    final r   = (size.width - 16) / 2;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    // Track
    canvas.drawArc(
      rect,
      _kStart,
      _kSweep,
      false,
      Paint()
        ..color       = ZapColors.bgElevated
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap   = StrokeCap.round,
    );

    // Fill
    if (fraction > 0) {
      canvas.drawArc(
        rect,
        _kStart,
        _kSweep * fraction,
        false,
        Paint()
          ..color       = color
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeCap   = StrokeCap.round,
      );
    }
  }

  static const _kStart = math.pi * 0.75;
  static const _kSweep = math.pi * 1.5;

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.fraction != fraction || old.color != color;
}

// ─── Next actions card ────────────────────────────────────────────────────────

class _NextActionsCard extends StatelessWidget {
  const _NextActionsCard({required this.actions});
  final List<NextAction> actions;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon:  Icons.bolt_rounded,
      color: ZapColors.warning,
      title: 'Next Actions',
      child: Column(
        children: actions.map((a) => _ActionRow(action: a)).toList(),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.action});
  final NextAction action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ZapSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: ZapSpacing.sm,
              vertical:   2,
            ),
            decoration: BoxDecoration(
              color:        ZapColors.warning.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '+${action.impact} pts',
              style: ZapTypography.labelSmall.copyWith(
                color:      ZapColors.warning,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: ZapSpacing.md),
          Expanded(
            child: Text(
              action.description,
              style: ZapTypography.bodyMedium.copyWith(
                color: ZapColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Breakdown card ───────────────────────────────────────────────────────────

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.components});
  final List<ScoreComponent> components;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon:  Icons.bar_chart_rounded,
      color: ZapColors.info,
      title: 'Score Breakdown',
      child: Column(
        children: components
            .map((c) => _ComponentRow(component: c))
            .toList(),
      ),
    );
  }
}

class _ComponentRow extends StatelessWidget {
  const _ComponentRow({required this.component});
  final ScoreComponent component;

  @override
  Widget build(BuildContext context) {
    final pct   = component.maxScore > 0
        ? component.score / component.maxScore
        : 0.0;
    final color = component.complete ? ZapColors.safe : ZapColors.textMuted;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ZapSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                component.complete
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size:  16,
                color: color,
              ),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: Text(
                  component.label,
                  style: ZapTypography.bodyMedium.copyWith(
                    color: component.complete
                        ? ZapColors.textPrimary
                        : ZapColors.textSecondary,
                  ),
                ),
              ),
              Text(
                '${component.score}/${component.maxScore}',
                style: ZapTypography.labelSmall.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value:            pct,
              minHeight:        5,
              backgroundColor:  ZapColors.bgElevated,
              valueColor:       AlwaysStoppedAnimation<Color>(
                component.complete ? ZapColors.safe : ZapColors.info,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── History card ─────────────────────────────────────────────────────────────

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.historyAsync});
  final AsyncValue<ScoreHistory> historyAsync;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon:  Icons.timeline_rounded,
      color: ZapColors.neutral,
      title: '30-Day History',
      child: historyAsync.when(
        loading: () => const SizedBox(
          height: 80,
          child: Center(
            child: CircularProgressIndicator(
              color: ZapColors.info,
              strokeWidth: 2,
            ),
          ),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.symmetric(vertical: ZapSpacing.md),
          child: Text(
            'Could not load history',
            style: ZapTypography.bodySmall.copyWith(
              color: ZapColors.textMuted,
            ),
          ),
        ),
        data: (history) {
          if (history.snapshots.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: ZapSpacing.lg),
              child: Text(
                'No history yet — check back tomorrow.',
                style: ZapTypography.bodySmall.copyWith(
                  color: ZapColors.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
            );
          }
          return _Sparkline(snapshots: history.snapshots);
        },
      ),
    );
  }
}

// ─── Sparkline ────────────────────────────────────────────────────────────────

class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.snapshots});
  final List<ScoreSnapshot> snapshots;

  @override
  Widget build(BuildContext context) {
    // snapshots are newest-first; reverse for chart (oldest-left)
    final ordered = snapshots.reversed.toList();
    final maxScore = ordered.fold<int>(
      1,
      (m, s) => s.score > m ? s.score : m,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 72,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: ordered.map((snap) {
              final frac  = maxScore > 0 ? snap.score / 100 : 0.0;
              final color = _bandColor(_scoreToSimpleBand(snap.score));
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Tooltip(
                    message: '${DateFormat("d MMM").format(snap.snapshotDate)}'
                        '\n${snap.score}/100',
                    child: Container(
                      height: math.max(4, 72 * frac),
                      decoration: BoxDecoration(
                        color:        color.withOpacity(0.75),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              DateFormat('d MMM').format(ordered.first.snapshotDate),
              style: ZapTypography.labelSmall.copyWith(
                color: ZapColors.textMuted,
              ),
            ),
            Text(
              DateFormat('d MMM').format(ordered.last.snapshotDate),
              style: ZapTypography.labelSmall.copyWith(
                color: ZapColors.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.sm),
        // Latest delta badge
        if (snapshots.isNotEmpty) ...[
          const Divider(color: ZapColors.divider, height: 1),
          const SizedBox(height: ZapSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${snapshots.length} day${snapshots.length == 1 ? '' : 's'} tracked',
                style: ZapTypography.labelSmall.copyWith(
                  color: ZapColors.textMuted,
                ),
              ),
              _DeltaBadge(delta: snapshots.first.delta),
            ],
          ),
        ],
      ],
    );
  }
}

class _DeltaBadge extends StatelessWidget {
  const _DeltaBadge({required this.delta});
  final int delta;

  @override
  Widget build(BuildContext context) {
    if (delta == 0) {
      return Text(
        '± 0 vs yesterday',
        style: ZapTypography.labelSmall.copyWith(
          color: ZapColors.textMuted,
        ),
      );
    }
    final positive = delta > 0;
    final color    = positive ? ZapColors.safe : ZapColors.danger;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          positive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
          size:  14,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          '${positive ? '+' : ''}$delta vs yesterday',
          style: ZapTypography.labelSmall.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─── Reusable section card ────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final Color    color;
  final String   title;
  final Widget   child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color:        ZapColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: ZapColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: ZapSpacing.sm),
              Text(
                title,
                style: ZapTypography.labelMedium.copyWith(
                  color:      color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          const Divider(color: ZapColors.divider, height: 1),
          const SizedBox(height: ZapSpacing.md),
          child,
        ],
      ),
    );
  }
}

// ─── Loading / error states ───────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: ZapColors.safe, strokeWidth: 2),
          SizedBox(height: ZapSpacing.lg),
          Text(
            'Calculating your score…',
            style: TextStyle(color: ZapColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String   message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ZapSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: ZapColors.danger),
            const SizedBox(height: ZapSpacing.md),
            Text(
              'Failed to load score',
              style: ZapTypography.headlineSmall.copyWith(
                color: ZapColors.textPrimary,
              ),
            ),
            const SizedBox(height: ZapSpacing.sm),
            Text(
              message,
              style: ZapTypography.bodySmall.copyWith(
                color: ZapColors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: ZapSpacing.xl),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(
                foregroundColor: ZapColors.safe,
                side: const BorderSide(color: ZapColors.safe),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Utilities ────────────────────────────────────────────────────────────────

Color _bandColor(String band) {
  switch (band) {
    case 'maximum':  return ZapColors.safe;
    case 'strong':   return ZapColors.safe;
    case 'good':     return ZapColors.info;
    case 'moderate': return ZapColors.warning;
    case 'low':      return ZapColors.warning;
    default:         return ZapColors.danger; // critical
  }
}

String _scoreToSimpleBand(int score) {
  if (score >= 90) return 'maximum';
  if (score >= 75) return 'strong';
  if (score >= 60) return 'good';
  if (score >= 40) return 'moderate';
  if (score >= 20) return 'low';
  return 'critical';
}
