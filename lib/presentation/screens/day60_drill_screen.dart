/// Day 60 — Drill Mode Screen
///
/// Lets the user run a simulated SOS drill — no real notifications are sent,
/// no emergency services are dialled. Shows contact response times, protection
/// score impact, weakest link, and a recommendation after each drill.
///
/// POST /api/v1/drill/start/            → drill_id
/// GET  /api/v1/drill/{id}/results/     → DrillResult
/// GET  /api/v1/drill/history/?days=90  → DrillHistory
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/services/drill_service.dart';
import '../../domain/providers/drill_providers.dart';

// ─── Screen ───────────────────────────────────────────────────────────────────

class Day60DrillScreen extends ConsumerStatefulWidget {
  const Day60DrillScreen({super.key});

  @override
  ConsumerState<Day60DrillScreen> createState() => _Day60DrillScreenState();
}

class _Day60DrillScreenState extends ConsumerState<Day60DrillScreen> {
  // Drill config flags
  bool _includeTier1       = true;
  bool _includeTier2       = true;
  bool _simulateEscalation = true;

  // Drill run state
  bool         _running  = false;
  String?      _errorMsg;
  DrillResult? _lastResult;

  // ── Start drill ───────────────────────────────────────────────────────────

  Future<void> _startDrill() async {
    setState(() {
      _running   = true;
      _errorMsg  = null;
      _lastResult = null;
    });

    try {
      final svc    = ref.read(drillServiceProvider);
      final drillId = await svc.start(
        includeTier1:       _includeTier1,
        includeTier2:       _includeTier2,
        simulateEscalation: _simulateEscalation,
      );
      final result  = await svc.fetchResults(drillId);

      setState(() {
        _lastResult = result;
      });

      // Refresh history
      ref.invalidate(drillHistoryProvider);
    } catch (e) {
      setState(() => _errorMsg = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _running = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: ZapColors.bgPrimary,
        title: const Text('Drill Mode'),
        actions: [
          IconButton(
            tooltip: 'Refresh history',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(drillHistoryProvider),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header banner ─────────────────────────────────────────────
            _DrillBanner(),
            const SizedBox(height: ZapSpacing.lg),

            // ── Configuration ─────────────────────────────────────────────
            const _SectionLabel('DRILL CONFIGURATION'),
            const SizedBox(height: ZapSpacing.sm),
            _ConfigCard(
              includeTier1:       _includeTier1,
              includeTier2:       _includeTier2,
              simulateEscalation: _simulateEscalation,
              onTier1Changed:  (v) => setState(() => _includeTier1 = v),
              onTier2Changed:  (v) => setState(() => _includeTier2 = v),
              onEscalChanged:  (v) => setState(() => _simulateEscalation = v),
            ),
            const SizedBox(height: ZapSpacing.lg),

            // ── Start button ──────────────────────────────────────────────
            _StartButton(
              running:  _running,
              onPressed: _running ? null : _startDrill,
            ),

            // ── Error ─────────────────────────────────────────────────────
            if (_errorMsg != null) ...[
              const SizedBox(height: ZapSpacing.md),
              _ErrorBanner(message: _errorMsg!),
            ],

            // ── Results ───────────────────────────────────────────────────
            if (_lastResult != null) ...[
              const SizedBox(height: ZapSpacing.xl),
              const _SectionLabel('DRILL RESULTS'),
              const SizedBox(height: ZapSpacing.sm),
              _ResultsCard(result: _lastResult!),
            ],

            // ── History ───────────────────────────────────────────────────
            const SizedBox(height: ZapSpacing.xl),
            const _SectionLabel('DRILL HISTORY  ·  LAST 90 DAYS'),
            const SizedBox(height: ZapSpacing.sm),
            _HistorySection(),
          ],
        ),
      ),
    );
  }
}

// ─── Banner ───────────────────────────────────────────────────────────────────

class _DrillBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.warning.withOpacity(0.12),
        border: Border.all(color: ZapColors.warning.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: ZapColors.warning, size: 20),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PRACTICE MODE — NO REAL ALERTS SENT',
                  style: ZapTypography.labelSmall.copyWith(
                    color: ZapColors.warning,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Contacts are simulated. Emergency services are not contacted. '
                  'Use this to verify your safety circle responds quickly.',
                  style: ZapTypography.bodySmall.copyWith(
                    color: ZapColors.textSecondary,
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

// ─── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: ZapTypography.labelSmall.copyWith(
          color: ZapColors.textSecondary,
          letterSpacing: 0.8,
        ),
      );
}

// ─── Config card ──────────────────────────────────────────────────────────────

class _ConfigCard extends StatelessWidget {
  const _ConfigCard({
    required this.includeTier1,
    required this.includeTier2,
    required this.simulateEscalation,
    required this.onTier1Changed,
    required this.onTier2Changed,
    required this.onEscalChanged,
  });

  final bool                  includeTier1;
  final bool                  includeTier2;
  final bool                  simulateEscalation;
  final ValueChanged<bool>    onTier1Changed;
  final ValueChanged<bool>    onTier2Changed;
  final ValueChanged<bool>    onEscalChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZapColors.bgElevated),
      ),
      child: Column(
        children: [
          _ToggleRow(
            icon: Icons.person_rounded,
            label: 'Include Tier 1 contact',
            subtitle: 'Your closest trusted person',
            value: includeTier1,
            onChanged: onTier1Changed,
          ),
          const Divider(height: 1, color: ZapColors.bgElevated),
          _ToggleRow(
            icon: Icons.group_rounded,
            label: 'Include Tier 2 contacts',
            subtitle: 'Up to 5 secondary contacts',
            value: includeTier2,
            onChanged: onTier2Changed,
          ),
          const Divider(height: 1, color: ZapColors.bgElevated),
          _ToggleRow(
            icon: Icons.trending_up_rounded,
            label: 'Simulate escalation',
            subtitle: 'Test Tier 2 escalation flow',
            value: simulateEscalation,
            onChanged: onEscalChanged,
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData           icon;
  final String             label;
  final String             subtitle;
  final bool               value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ZapSpacing.md,
        vertical: ZapSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: ZapColors.textSecondary),
          const SizedBox(width: ZapSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: ZapTypography.labelMedium),
                Text(
                  subtitle,
                  style: ZapTypography.bodySmall.copyWith(
                    color: ZapColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: ZapColors.safe,
          ),
        ],
      ),
    );
  }
}

// ─── Start button ─────────────────────────────────────────────────────────────

class _StartButton extends StatelessWidget {
  const _StartButton({
    required this.running,
    required this.onPressed,
  });

  final bool          running;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor:  running ? ZapColors.bgElevated : ZapColors.safe,
          foregroundColor:  running ? ZapColors.textSecondary : ZapColors.bgPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        icon: running
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: ZapColors.textSecondary,
                ),
              )
            : const Icon(Icons.play_arrow_rounded, size: 22),
        label: Text(
          running ? 'Running drill…' : 'Start Drill',
          style: ZapTypography.labelMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ─── Error banner ─────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.danger.withOpacity(0.1),
        border: Border.all(color: ZapColors.danger.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: ZapColors.danger, size: 18),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: ZapTypography.bodySmall.copyWith(color: ZapColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Results card ─────────────────────────────────────────────────────────────

class _ResultsCard extends StatelessWidget {
  const _ResultsCard({required this.result});
  final DrillResult result;

  @override
  Widget build(BuildContext context) {
    final allAcked = result.contactResults.isNotEmpty &&
        result.contactResults.every((c) => c.acked);

    return Container(
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: allAcked
              ? ZapColors.safe.withOpacity(0.5)
              : ZapColors.warning.withOpacity(0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          _ResultsHeader(allAcked: allAcked),

          // ── Score impact ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              ZapSpacing.md, 0, ZapSpacing.md, ZapSpacing.sm,
            ),
            child: _ScoreImpactRow(result: result),
          ),

          // ── Contacts ────────────────────────────────────────────────────
          if (result.contactResults.isNotEmpty) ...[
            const Divider(height: 1, color: ZapColors.bgElevated),
            Padding(
              padding: const EdgeInsets.all(ZapSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CONTACT RESPONSES',
                    style: ZapTypography.labelSmall.copyWith(
                      color: ZapColors.textSecondary,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: ZapSpacing.sm),
                  ...result.contactResults.map(
                    (c) => _ContactRow(contact: c),
                  ),
                ],
              ),
            ),
          ] else ...[
            const Divider(height: 1, color: ZapColors.bgElevated),
            Padding(
              padding: const EdgeInsets.all(ZapSpacing.md),
              child: Row(
                children: [
                  const Icon(Icons.person_off_rounded,
                      size: 16, color: ZapColors.textSecondary),
                  const SizedBox(width: ZapSpacing.sm),
                  Text(
                    'No contacts in this drill',
                    style: ZapTypography.bodySmall.copyWith(
                      color: ZapColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Weakest link ────────────────────────────────────────────────
          if (result.weakestLink.isNotEmpty) ...[
            const Divider(height: 1, color: ZapColors.bgElevated),
            Padding(
              padding: const EdgeInsets.all(ZapSpacing.md),
              child: Row(
                children: [
                  const Icon(Icons.link_rounded,
                      size: 16, color: ZapColors.warning),
                  const SizedBox(width: ZapSpacing.sm),
                  Text(
                    'Slowest: ',
                    style: ZapTypography.labelSmall.copyWith(
                      color: ZapColors.warning,
                    ),
                  ),
                  Text(
                    result.weakestLink,
                    style: ZapTypography.bodySmall,
                  ),
                ],
              ),
            ),
          ],

          // ── Recommendation ──────────────────────────────────────────────
          if (result.recommendation.isNotEmpty) ...[
            const Divider(height: 1, color: ZapColors.bgElevated),
            Padding(
              padding: const EdgeInsets.all(ZapSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline_rounded,
                      size: 16, color: ZapColors.info),
                  const SizedBox(width: ZapSpacing.sm),
                  Expanded(
                    child: Text(
                      result.recommendation,
                      style: ZapTypography.bodySmall.copyWith(
                        color: ZapColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader({required this.allAcked});
  final bool allAcked;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: ZapSpacing.md,
        vertical: ZapSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: allAcked
            ? ZapColors.safe.withOpacity(0.12)
            : ZapColors.warning.withOpacity(0.10),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          Icon(
            allAcked
                ? Icons.check_circle_rounded
                : Icons.warning_amber_rounded,
            size: 18,
            color: allAcked ? ZapColors.safe : ZapColors.warning,
          ),
          const SizedBox(width: ZapSpacing.sm),
          Text(
            allAcked ? 'All contacts responded' : 'Some contacts missed',
            style: ZapTypography.labelMedium.copyWith(
              color: allAcked ? ZapColors.safe : ZapColors.warning,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreImpactRow extends StatelessWidget {
  const _ScoreImpactRow({required this.result});
  final DrillResult result;

  @override
  Widget build(BuildContext context) {
    final delta = result.scoreDelta;
    final deltaColor = delta > 0
        ? ZapColors.safe
        : delta < 0
            ? ZapColors.danger
            : ZapColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ZapSpacing.sm),
      child: Row(
        children: [
          const Icon(Icons.shield_rounded, size: 16, color: ZapColors.textSecondary),
          const SizedBox(width: ZapSpacing.sm),
          Text(
            'Score: ',
            style: ZapTypography.labelSmall.copyWith(
              color: ZapColors.textSecondary,
            ),
          ),
          Text(
            '${result.protectionScoreBefore}',
            style: ZapTypography.labelMedium,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: ZapSpacing.xs),
            child: Icon(Icons.arrow_forward_rounded,
                size: 14, color: ZapColors.textSecondary),
          ),
          Text(
            '${result.protectionScoreAfter}',
            style: ZapTypography.labelMedium,
          ),
          const SizedBox(width: ZapSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: deltaColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              delta > 0 ? '+$delta' : '$delta',
              style: ZapTypography.labelSmall.copyWith(color: deltaColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.contact});
  final DrillContactResult contact;

  @override
  Widget build(BuildContext context) {
    final tierLabel = contact.tier == 1 ? 'T1' : 'T2';
    final tierColor = contact.tier == 1 ? ZapColors.danger : ZapColors.warning;

    return Padding(
      padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
      child: Row(
        children: [
          // Ack status icon
          Icon(
            contact.acked
                ? Icons.check_circle_rounded
                : Icons.cancel_rounded,
            size: 16,
            color: contact.acked ? ZapColors.safe : ZapColors.danger,
          ),
          const SizedBox(width: ZapSpacing.sm),
          // Tier badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: tierColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              tierLabel,
              style: ZapTypography.labelSmall.copyWith(
                color: tierColor,
                fontSize: 10,
              ),
            ),
          ),
          const SizedBox(width: ZapSpacing.sm),
          // Name
          Expanded(
            child: Text(contact.contactName, style: ZapTypography.bodySmall),
          ),
          // Response time
          if (contact.acked)
            Text(
              '${(contact.ackTimeMs / 1000).toStringAsFixed(1)}s',
              style: ZapTypography.labelSmall.copyWith(
                color: ZapColors.textSecondary,
              ),
            )
          else
            Text(
              'No response',
              style: ZapTypography.labelSmall.copyWith(
                color: ZapColors.danger.withOpacity(0.7),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── History section ──────────────────────────────────────────────────────────

class _HistorySection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(drillHistoryProvider);

    return historyAsync.when(
      loading: () => const _HistoryLoading(),
      error: (e, _) => _HistoryError(
        message: e.toString().replaceFirst('Exception: ', ''),
        onRetry: () => ref.invalidate(drillHistoryProvider),
      ),
      data: (history) {
        if (history.drills.isEmpty) {
          return const _HistoryEmpty();
        }
        return Column(
          children: history.drills.map((d) => _HistoryCard(drill: d)).toList(),
        );
      },
    );
  }
}

class _HistoryLoading extends StatelessWidget {
  const _HistoryLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.xl),
      alignment: Alignment.center,
      child: const CircularProgressIndicator(strokeWidth: 2),
    );
  }
}

class _HistoryError extends StatelessWidget {
  const _HistoryError({required this.message, required this.onRetry});
  final String       message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZapColors.bgElevated),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: ZapColors.danger, size: 28),
          const SizedBox(height: ZapSpacing.sm),
          Text(
            message,
            style: ZapTypography.bodySmall.copyWith(
              color: ZapColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: ZapSpacing.md),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _HistoryEmpty extends StatelessWidget {
  const _HistoryEmpty();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.xl),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZapColors.bgElevated),
      ),
      child: Column(
        children: [
          Icon(Icons.fitness_center_rounded,
              size: 32, color: ZapColors.textSecondary.withOpacity(0.4)),
          const SizedBox(height: ZapSpacing.sm),
          Text(
            'No drills yet',
            style: ZapTypography.labelMedium.copyWith(
              color: ZapColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Run your first drill above to see results here.',
            style: ZapTypography.bodySmall.copyWith(
              color: ZapColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.drill});
  final DrillHistoryItem drill;

  @override
  Widget build(BuildContext context) {
    final deltaColor = drill.scoreDelta > 0
        ? ZapColors.safe
        : drill.scoreDelta < 0
            ? ZapColors.danger
            : ZapColors.textSecondary;

    final fmt = DateFormat('MMM d, HH:mm');

    return Container(
      margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: ZapSpacing.md,
        vertical: ZapSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ZapColors.bgElevated),
      ),
      child: Row(
        children: [
          // Left: icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: ZapColors.safe.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.fitness_center_rounded,
              size: 18,
              color: ZapColors.safe,
            ),
          ),
          const SizedBox(width: ZapSpacing.md),

          // Middle: date + avg response
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fmt.format(drill.startedAt),
                  style: ZapTypography.labelMedium,
                ),
                if (drill.avgResponseMs != null)
                  Text(
                    'Avg response: ${(drill.avgResponseMs! / 1000).toStringAsFixed(1)}s',
                    style: ZapTypography.bodySmall.copyWith(
                      color: ZapColors.textSecondary,
                    ),
                  )
                else
                  Text(
                    'No contacts responded',
                    style: ZapTypography.bodySmall.copyWith(
                      color: ZapColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),

          // Right: score delta
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: deltaColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              drill.scoreDelta > 0
                  ? '+${drill.scoreDelta} pts'
                  : '${drill.scoreDelta} pts',
              style: ZapTypography.labelSmall.copyWith(color: deltaColor),
            ),
          ),
        ],
      ),
    );
  }
}
