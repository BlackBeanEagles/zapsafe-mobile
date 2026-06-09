/// Day 57 — ML Analytics Screen
///
/// Route: /ml-analytics
///
/// Displays aggregate ML telemetry for the authenticated user pulled from
/// GET /api/v1/ml/analytics/.
///
/// Three stat cards (detection events, device capability, model downloads)
/// plus a period selector (7 / 30 / 90 days) that re-fetches on change.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/services/ml_analytics_service.dart';
import '../../domain/providers/ml_analytics_providers.dart';
import '../navigation/app_router.dart';
import '../widgets/zap_card.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class Day57MlAnalyticsScreen extends ConsumerStatefulWidget {
  const Day57MlAnalyticsScreen({super.key});

  @override
  ConsumerState<Day57MlAnalyticsScreen> createState() =>
      _Day57MlAnalyticsScreenState();
}

class _Day57MlAnalyticsScreenState
    extends ConsumerState<Day57MlAnalyticsScreen> {
  // Period selector — drives the FutureProvider.family key
  int _days = 30;
  static const _periodOptions = [7, 30, 90];

  @override
  Widget build(BuildContext context) {
    final analyticsAsync = ref.watch(mlAnalyticsProvider(_days));

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: ZapColors.bgPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: ZapColors.textPrimary),
          onPressed: () => context.go(AppRoutes.home),
        ),
        title: Row(
          children: [
            const Text('ML Analytics',
                style: TextStyle(color: ZapColors.textPrimary)),
            const SizedBox(width: ZapSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: ZapSpacing.sm, vertical: 2),
              decoration: BoxDecoration(
                color: ZapColors.warning.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'DAY 57',
                style: ZapTypography.labelSmall.copyWith(
                  color: ZapColors.warning,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: ZapColors.textSecondary, size: 20),
            tooltip: 'Refresh',
            onPressed: () =>
                ref.invalidate(mlAnalyticsProvider(_days)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Period selector ────────────────────────────────────────────
            _PeriodSelector(
              selected: _days,
              options:  _periodOptions,
              onChanged: (d) => setState(() => _days = d),
            ),
            const SizedBox(height: ZapSpacing.xl),

            // ── Content ────────────────────────────────────────────────────
            analyticsAsync.when(
              loading: () => const _LoadingSkeleton(),
              error:   (e, _) => _ErrorState(
                message: e.toString(),
                onRetry: () => ref.invalidate(mlAnalyticsProvider(_days)),
              ),
              data: (result) => _AnalyticsBody(result: result),
            ),

            const SizedBox(height: ZapSpacing.xxxl),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Period selector
// ─────────────────────────────────────────────────────────────────────────────

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({
    required this.selected,
    required this.options,
    required this.onChanged,
  });

  final int selected;
  final List<int> options;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('PERIOD',
            style: ZapTypography.labelSmall.copyWith(
                color: ZapColors.textSecondary, letterSpacing: 1.0)),
        const SizedBox(width: ZapSpacing.md),
        ...options.map((d) {
          final isSelected = d == selected;
          return Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.sm),
            child: GestureDetector(
              onTap: () => onChanged(d),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? ZapColors.warning.withOpacity(0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? ZapColors.warning
                        : ZapColors.textSecondary.withOpacity(0.3),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: Text(
                  '${d}d',
                  style: ZapTypography.labelSmall.copyWith(
                    color: isSelected
                        ? ZapColors.warning
                        : ZapColors.textSecondary,
                    fontWeight: isSelected
                        ? FontWeight.w700
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Analytics body — all three sections
// ─────────────────────────────────────────────────────────────────────────────

class _AnalyticsBody extends StatelessWidget {
  const _AnalyticsBody({required this.result});
  final MLAnalyticsResult result;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d, y · HH:mm');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Generated-at timestamp ─────────────────────────────────────────
        Row(
          children: [
            const Icon(Icons.access_time_rounded,
                size: 13, color: ZapColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              'Updated ${fmt.format(result.generatedAt)}',
              style: ZapTypography.labelSmall
                  .copyWith(color: ZapColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.xl),

        // ── Detection events card ──────────────────────────────────────────
        _DetectionEventsCard(stats: result.detectionEvents),
        const SizedBox(height: ZapSpacing.lg),

        // ── Device capability card ─────────────────────────────────────────
        _DeviceCapabilityCard(stats: result.deviceCapability),
        const SizedBox(height: ZapSpacing.lg),

        // ── Model downloads card ───────────────────────────────────────────
        _ModelDownloadsCard(stats: result.modelDownloads),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Detection Events card
// ─────────────────────────────────────────────────────────────────────────────

class _DetectionEventsCard extends StatelessWidget {
  const _DetectionEventsCard({required this.stats});
  final DetectionEventStats stats;

  static const _typeColors = <String, Color>{
    'scream': ZapColors.danger,
    'motion': ZapColors.warning,
    'scene':  ZapColors.info,
    'dcs':    ZapColors.safe,
  };
  static const _typeLabels = <String, String>{
    'scream': 'Scream',
    'motion': 'Motion',
    'scene':  'Scene',
    'dcs':    'DCS',
  };

  @override
  Widget build(BuildContext context) {
    final confText = stats.avgConfidence != null
        ? '${(stats.avgConfidence! * 100).toStringAsFixed(1)}%'
        : '—';

    return _SectionCard(
      icon: Icons.sensors_rounded,
      color: ZapColors.danger,
      title: 'DETECTION EVENTS',
      subtitle: '${stats.total} event${stats.total == 1 ? '' : 's'} in period',
      child: Column(
        children: [
          // ── Top metrics row ─────────────────────────────────────────────
          Row(
            children: [
              _MetricTile(
                label: 'Total',
                value: '${stats.total}',
                color: ZapColors.danger,
              ),
              _MetricTile(
                label: 'SOS Triggers',
                value: '${stats.sosTriggered}',
                color: ZapColors.danger,
              ),
              _MetricTile(
                label: 'SOS Rate',
                value: '${(stats.sosRate * 100).toStringAsFixed(1)}%',
                color: stats.sosRate > 0.1
                    ? ZapColors.danger
                    : ZapColors.safe,
              ),
              _MetricTile(
                label: 'Avg Confidence',
                value: confText,
                color: ZapColors.info,
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),

          // ── By type ─────────────────────────────────────────────────────
          if (stats.total > 0) ...[
            const _SubLabel('BY TYPE'),
            const SizedBox(height: ZapSpacing.sm),
            _BarChart(
              data: stats.byType,
              total: stats.total,
              colors: _typeColors,
              labels: _typeLabels,
            ),
            const SizedBox(height: ZapSpacing.md),
          ],

          // ── By mode ─────────────────────────────────────────────────────
          const _SubLabel('AI vs HEURISTIC'),
          const SizedBox(height: ZapSpacing.sm),
          _ModeRow(
            aiCount:        stats.byMode['ai'] ?? 0,
            heuristicCount: stats.byMode['heuristic'] ?? 0,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Device Capability card
// ─────────────────────────────────────────────────────────────────────────────

class _DeviceCapabilityCard extends StatelessWidget {
  const _DeviceCapabilityCard({required this.stats});
  final DeviceCapabilityStats stats;

  static const _tierColors = <String, Color>{
    'high':   ZapColors.safe,
    'medium': ZapColors.warning,
    'low':    ZapColors.danger,
  };
  static const _tierLabels = <String, String>{
    'high':   'High',
    'medium': 'Medium',
    'low':    'Low',
  };

  @override
  Widget build(BuildContext context) {
    final infText = stats.avgInferenceMs != null
        ? '${stats.avgInferenceMs!.toStringAsFixed(1)} ms'
        : '—';

    return _SectionCard(
      icon: Icons.smartphone_rounded,
      color: ZapColors.safe,
      title: 'DEVICE CAPABILITY',
      subtitle: '${stats.totalReports} report${stats.totalReports == 1 ? '' : 's'} in period',
      child: Column(
        children: [
          Row(
            children: [
              _MetricTile(
                label: 'Reports',
                value: '${stats.totalReports}',
                color: ZapColors.safe,
              ),
              _MetricTile(
                label: 'Avg Inference',
                value: infText,
                color: ZapColors.info,
              ),
              _MetricTile(
                label: 'AI devices',
                value: '${stats.byMode['ai'] ?? 0}',
                color: ZapColors.safe,
              ),
              _MetricTile(
                label: 'Heuristic',
                value: '${stats.byMode['heuristic'] ?? 0}',
                color: ZapColors.warning,
              ),
            ],
          ),

          if (stats.totalReports > 0) ...[
            const SizedBox(height: ZapSpacing.md),
            const _SubLabel('TIER DISTRIBUTION'),
            const SizedBox(height: ZapSpacing.sm),
            _BarChart(
              data: stats.byTier,
              total: stats.totalReports,
              colors: _tierColors,
              labels: _tierLabels,
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Model Downloads card
// ─────────────────────────────────────────────────────────────────────────────

class _ModelDownloadsCard extends StatelessWidget {
  const _ModelDownloadsCard({required this.stats});
  final ModelDownloadStats stats;

  static const _typeColors = <String, Color>{
    'scream': ZapColors.danger,
    'motion': ZapColors.warning,
    'scene':  ZapColors.info,
    'dcs':    ZapColors.safe,
  };
  static const _typeLabels = <String, String>{
    'scream': 'Scream',
    'motion': 'Motion',
    'scene':  'Scene',
    'dcs':    'DCS',
  };

  @override
  Widget build(BuildContext context) {
    final mb   = stats.totalBytes > 0
        ? '${(stats.totalBytes / 1024 / 1024).toStringAsFixed(1)} MB'
        : '0 MB';
    final rate = '${(stats.sha256VerifiedRate * 100).toStringAsFixed(0)}%';

    return _SectionCard(
      icon: Icons.download_done_rounded,
      color: ZapColors.info,
      title: 'MODEL DOWNLOADS',
      subtitle: '${stats.total} download${stats.total == 1 ? '' : 's'} in period',
      child: Column(
        children: [
          Row(
            children: [
              _MetricTile(
                label: 'Total',
                value: '${stats.total}',
                color: ZapColors.info,
              ),
              _MetricTile(
                label: 'SHA256 ✓',
                value: '${stats.sha256Verified}',
                color: ZapColors.safe,
              ),
              _MetricTile(
                label: 'Verified Rate',
                value: rate,
                color: stats.sha256VerifiedRate >= 0.9
                    ? ZapColors.safe
                    : ZapColors.warning,
              ),
              _MetricTile(
                label: 'Total Size',
                value: mb,
                color: ZapColors.textSecondary,
              ),
            ],
          ),

          if (stats.total > 0) ...[
            const SizedBox(height: ZapSpacing.md),
            const _SubLabel('BY MODEL TYPE'),
            const SizedBox(height: ZapSpacing.sm),
            _BarChart(
              data: stats.byType,
              total: stats.total,
              colors: _typeColors,
              labels: _typeLabels,
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared section card wrapper
// ─────────────────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Padding(
        padding: const EdgeInsets.all(ZapSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: ZapSpacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: ZapTypography.labelSmall.copyWith(
                            color: color,
                            letterSpacing: 1.0,
                            fontWeight: FontWeight.w700)),
                    Text(subtitle,
                        style: ZapTypography.labelSmall.copyWith(
                            color: ZapColors.textSecondary)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: ZapSpacing.md),
            const Divider(color: ZapColors.border, height: 1),
            const SizedBox(height: ZapSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Metric tile — a small labelled number
// ─────────────────────────────────────────────────────────────────────────────

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: ZapTypography.headlineSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: ZapTypography.labelSmall.copyWith(
              color: ZapColors.textSecondary,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Horizontal bar chart (one row per key)
// ─────────────────────────────────────────────────────────────────────────────

class _BarChart extends StatelessWidget {
  const _BarChart({
    required this.data,
    required this.total,
    required this.colors,
    required this.labels,
  });

  final Map<String, int> data;
  final int total;
  final Map<String, Color> colors;
  final Map<String, String> labels;

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.toList();
    return Column(
      children: entries.map((e) {
        final pct   = total > 0 ? e.value / total : 0.0;
        final color = colors[e.key] ?? ZapColors.neutral;
        final label = labels[e.key] ?? e.key;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(
                width: 52,
                child: Text(label,
                    style: ZapTypography.labelSmall
                        .copyWith(color: ZapColors.textSecondary)),
              ),
              Expanded(
                child: Stack(
                  children: [
                    // Background track
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: ZapColors.bgElevated,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    // Fill
                    FractionallySizedBox(
                      widthFactor: pct.clamp(0.0, 1.0),
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: ZapSpacing.sm),
              SizedBox(
                width: 32,
                child: Text(
                  '${e.value}',
                  textAlign: TextAlign.end,
                  style: ZapTypography.labelSmall.copyWith(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AI vs Heuristic horizontal split
// ─────────────────────────────────────────────────────────────────────────────

class _ModeRow extends StatelessWidget {
  const _ModeRow({
    required this.aiCount,
    required this.heuristicCount,
  });

  final int aiCount;
  final int heuristicCount;

  @override
  Widget build(BuildContext context) {
    final total  = aiCount + heuristicCount;
    final aiFrac = total > 0 ? aiCount / total : 0.0;

    return Column(
      children: [
        // Combined bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                if (aiCount > 0)
                  Expanded(
                    flex: aiCount,
                    child: Container(color: ZapColors.safe),
                  ),
                if (heuristicCount > 0)
                  Expanded(
                    flex: heuristicCount,
                    child: Container(color: ZapColors.warning),
                  ),
                if (total == 0)
                  Expanded(
                    child: Container(color: ZapColors.bgElevated),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _ModeLabel(
              color: ZapColors.safe,
              label: 'AI',
              count: aiCount,
              pct: aiFrac,
            ),
            const Spacer(),
            _ModeLabel(
              color: ZapColors.warning,
              label: 'Heuristic',
              count: heuristicCount,
              pct: 1.0 - aiFrac,
              alignRight: true,
            ),
          ],
        ),
      ],
    );
  }
}

class _ModeLabel extends StatelessWidget {
  const _ModeLabel({
    required this.color,
    required this.label,
    required this.count,
    required this.pct,
    this.alignRight = false,
  });

  final Color color;
  final String label;
  final int count;
  final double pct;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    final row = [
      Container(
        width: 8, height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(
        '$label  $count  (${(pct * 100).toStringAsFixed(0)}%)',
        style: ZapTypography.labelSmall
            .copyWith(color: ZapColors.textSecondary),
      ),
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: alignRight ? row.reversed.toList() : row,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-label
// ─────────────────────────────────────────────────────────────────────────────

class _SubLabel extends StatelessWidget {
  const _SubLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: ZapTypography.labelSmall.copyWith(
        color: ZapColors.textSecondary,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading skeleton
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _SkeletonCard(height: 160),
        SizedBox(height: ZapSpacing.lg),
        _SkeletonCard(height: 130),
        SizedBox(height: ZapSpacing.lg),
        _SkeletonCard(height: 150),
      ],
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: SizedBox(
        height: height,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: ZapColors.warning),
              ),
              const SizedBox(height: ZapSpacing.sm),
              Text('Loading…',
                  style: ZapTypography.labelSmall
                      .copyWith(color: ZapColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error state
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Padding(
        padding: const EdgeInsets.all(ZapSpacing.xl),
        child: Column(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: ZapColors.danger, size: 40),
            const SizedBox(height: ZapSpacing.md),
            Text('Failed to load analytics',
                style: ZapTypography.bodyMedium
                    .copyWith(color: ZapColors.textPrimary)),
            const SizedBox(height: 4),
            Text(message,
                style: ZapTypography.labelSmall
                    .copyWith(color: ZapColors.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: ZapSpacing.lg),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
