import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/services/compatibility_service.dart';
import '../../domain/providers/compatibility_providers.dart';
import '../navigation/app_router.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';

/// Day 53 — Device Compatibility Matrix Screen.
///
/// Route: /compatibility-matrix
///
/// Fetches GET /api/v1/ml/compatibility-matrix/ and renders:
///   • Summary chips (AI count, Heuristic count, Pass/Fail/Untested)
///   • Filterable device list with mode badge + response-time bar
///   • Per-device detail card (OS, battery impact, notes, tested date)
///   • Refresh button
class Day53CompatibilityMatrixScreen extends ConsumerStatefulWidget {
  const Day53CompatibilityMatrixScreen({super.key});

  @override
  ConsumerState<Day53CompatibilityMatrixScreen> createState() =>
      _Day53CompatibilityMatrixScreenState();
}

class _Day53CompatibilityMatrixScreenState
    extends ConsumerState<Day53CompatibilityMatrixScreen> {
  /// Active filter — null = show all.
  DeviceDetectionMode? _modeFilter;
  bool _refreshing = false;

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    ref.invalidate(compatibilityMatrixProvider);
    // Allow Riverpod to kick off the new request before clearing the flag.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (mounted) setState(() => _refreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final matrixAsync = ref.watch(compatibilityMatrixProvider);

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
            const Text('Compatibility Matrix',
                style: TextStyle(color: ZapColors.textPrimary)),
            const SizedBox(width: ZapSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: ZapSpacing.sm, vertical: 2),
              decoration: BoxDecoration(
                color: ZapColors.safe.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'DAY 53',
                style: ZapTypography.labelSmall.copyWith(
                  color: ZapColors.safe,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
      body: matrixAsync.when(
        loading: () => const _LoadingBody(),
        error:   (err, _) => _ErrorBody(error: err.toString(), onRetry: _refresh),
        data:    (result) => _MatrixBody(
          result:       result,
          modeFilter:   _modeFilter,
          refreshing:   _refreshing,
          onFilterChange: (mode) => setState(() => _modeFilter = mode),
          onRefresh:    _refresh,
        ),
      ),
    );
  }
}

// ─── Loading skeleton ─────────────────────────────────────────────────────────

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('SUMMARY'),
          const SizedBox(height: ZapSpacing.sm),
          const _SkeletonCard(height: 68),
          const SizedBox(height: ZapSpacing.xl),
          const _SectionLabel('DEVICES'),
          const SizedBox(height: ZapSpacing.sm),
          for (var i = 0; i < 5; i++) ...[
            const _SkeletonCard(height: 72),
            const SizedBox(height: ZapSpacing.sm),
          ],
        ],
      ),
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
          child: Container(
            width: double.infinity,
            height: 14,
            margin: const EdgeInsets.symmetric(horizontal: ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.bgElevated,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Error body ───────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ZapCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.cloud_off_rounded,
                    color: ZapColors.danger, size: 32),
                const SizedBox(height: ZapSpacing.sm),
                Text(
                  'Could not load matrix',
                  style: ZapTypography.labelLarge
                      .copyWith(color: ZapColors.danger),
                ),
                const SizedBox(height: ZapSpacing.xs),
                Text(
                  error,
                  style: ZapTypography.bodySmall
                      .copyWith(color: ZapColors.textSecondary),
                ),
                const SizedBox(height: ZapSpacing.xs),
                Text(
                  'Make sure the backend is running.',
                  style: ZapTypography.labelSmall
                      .copyWith(color: ZapColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          ZapButton(
            label: 'Retry',
            icon: Icons.refresh_rounded,
            onPressed: onRetry,
            variant: ZapButtonVariant.elevated,
            intent: ZapButtonIntent.info,
          ),
        ],
      ),
    );
  }
}

// ─── Main body ────────────────────────────────────────────────────────────────

class _MatrixBody extends StatelessWidget {
  const _MatrixBody({
    required this.result,
    required this.modeFilter,
    required this.refreshing,
    required this.onFilterChange,
    required this.onRefresh,
  });

  final CompatibilityMatrixResult result;
  final DeviceDetectionMode?      modeFilter;
  final bool                      refreshing;
  final ValueChanged<DeviceDetectionMode?> onFilterChange;
  final VoidCallback              onRefresh;

  List<CompatibilityEntry> get _filtered {
    if (modeFilter == null) return result.devices;
    return result.devices
        .where((d) => d.detectionMode == modeFilter)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Summary chips ─────────────────────────────────────────────
          const _SectionLabel('SUMMARY'),
          const SizedBox(height: ZapSpacing.sm),
          _SummaryCard(summary: result.summary),
          const SizedBox(height: ZapSpacing.xl),

          // ── Filter bar ────────────────────────────────────────────────
          const _SectionLabel('FILTER BY MODE'),
          const SizedBox(height: ZapSpacing.sm),
          _FilterBar(current: modeFilter, onChanged: onFilterChange),
          const SizedBox(height: ZapSpacing.xl),

          // ── Device list ───────────────────────────────────────────────
          _SectionLabel('DEVICES (${filtered.length})'),
          const SizedBox(height: ZapSpacing.sm),
          if (filtered.isEmpty)
            _EmptyFilterResult(onClear: () => onFilterChange(null))
          else
            ...filtered.map((d) => Padding(
                  padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
                  child: _DeviceCard(entry: d),
                )),

          const SizedBox(height: ZapSpacing.xl),

          // ── Refresh ───────────────────────────────────────────────────
          ZapButton(
            label: refreshing ? 'Refreshing…' : 'Refresh from Server',
            icon: refreshing ? null : Icons.sync_rounded,
            onPressed: refreshing ? null : onRefresh,
            variant: ZapButtonVariant.elevated,
            intent: ZapButtonIntent.info,
            isLoading: refreshing,
          ),
          const SizedBox(height: ZapSpacing.xxxl),
        ],
      ),
    );
  }
}

// ─── Summary card ─────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});
  final CompatibilitySummary summary;

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Row(
        children: [
          _SummaryChip(
            label: '${summary.aiDevices}',
            sublabel: 'AI',
            color: ZapColors.safe,
            icon: Icons.bolt_rounded,
          ),
          _SummaryChip(
            label: '${summary.heuristicDevices}',
            sublabel: 'Heuristic',
            color: ZapColors.warning,
            icon: Icons.memory_rounded,
          ),
          _SummaryChip(
            label: '${summary.pass}',
            sublabel: 'Pass',
            color: ZapColors.safe,
            icon: Icons.check_circle_rounded,
          ),
          if (summary.fail > 0)
            _SummaryChip(
              label: '${summary.fail}',
              sublabel: 'Fail',
              color: ZapColors.danger,
              icon: Icons.cancel_rounded,
            ),
          if (summary.untested > 0)
            _SummaryChip(
              label: '${summary.untested}',
              sublabel: 'Untested',
              color: ZapColors.textMuted,
              icon: Icons.help_outline_rounded,
            ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.sublabel,
    required this.color,
    required this.icon,
  });

  final String label;
  final String sublabel;
  final Color  color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            label,
            style: ZapTypography.headlineSmall.copyWith(
              color: color,
              fontFamily: 'IBMPlexMono',
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            sublabel,
            style: ZapTypography.labelSmall.copyWith(
              color: ZapColors.textSecondary,
              fontSize: 9,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Filter bar ───────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.current, required this.onChanged});
  final DeviceDetectionMode? current;
  final ValueChanged<DeviceDetectionMode?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _FilterChip(
          label: 'All',
          active: current == null,
          color: ZapColors.info,
          onTap: () => onChanged(null),
        ),
        const SizedBox(width: ZapSpacing.sm),
        _FilterChip(
          label: 'AI only',
          active: current == DeviceDetectionMode.ai,
          color: ZapColors.safe,
          onTap: () => onChanged(DeviceDetectionMode.ai),
        ),
        const SizedBox(width: ZapSpacing.sm),
        _FilterChip(
          label: 'Heuristic only',
          active: current == DeviceDetectionMode.heuristic,
          color: ZapColors.warning,
          onTap: () => onChanged(DeviceDetectionMode.heuristic),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(
            horizontal: ZapSpacing.md, vertical: ZapSpacing.xs),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.15) : ZapColors.bgElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: ZapTypography.labelSmall.copyWith(
            color: active ? color : ZapColors.textSecondary,
            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ─── Device card ──────────────────────────────────────────────────────────────

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.entry});
  final CompatibilityEntry entry;

  Color get _modeColor => entry.detectionMode == DeviceDetectionMode.ai
      ? ZapColors.safe
      : ZapColors.warning;

  IconData get _modeIcon => entry.detectionMode == DeviceDetectionMode.ai
      ? Icons.bolt_rounded
      : Icons.memory_rounded;

  Color get _statusColor {
    switch (entry.status) {
      case DeviceCompatStatus.pass:     return ZapColors.safe;
      case DeviceCompatStatus.fail:     return ZapColors.danger;
      case DeviceCompatStatus.untested: return ZapColors.textMuted;
    }
  }

  IconData get _statusIcon {
    switch (entry.status) {
      case DeviceCompatStatus.pass:     return Icons.check_circle_rounded;
      case DeviceCompatStatus.fail:     return Icons.cancel_rounded;
      case DeviceCompatStatus.untested: return Icons.help_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Response-time bar: 1000 ms = full width, capped
    final barFraction =
        (entry.expectedResponseMs / 1000.0).clamp(0.05, 1.0);

    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ────────────────────────────────────────────────
          Row(
            children: [
              // Mode badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: ZapSpacing.sm, vertical: 2),
                decoration: BoxDecoration(
                  color: _modeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_modeIcon, color: _modeColor, size: 12),
                    const SizedBox(width: 3),
                    Text(
                      entry.detectionMode == DeviceDetectionMode.ai
                          ? 'AI'
                          : 'HEURISTIC',
                      style: ZapTypography.labelSmall.copyWith(
                        color: _modeColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Status
              Icon(_statusIcon, color: _statusColor, size: 16),
              const SizedBox(width: ZapSpacing.xs),
              Text(
                entry.statusDisplay,
                style: ZapTypography.labelSmall.copyWith(
                  color: _statusColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.sm),

          // ── Device name + OS ──────────────────────────────────────────
          Text(
            entry.deviceName,
            style: ZapTypography.labelLarge.copyWith(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            '${entry.osName} ${entry.osVersion}  ·  ${entry.year}',
            style: ZapTypography.bodySmall
                .copyWith(color: ZapColors.textSecondary),
          ),
          const SizedBox(height: ZapSpacing.sm),

          // ── Response-time bar ─────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '< ${entry.expectedResponseMs} ms',
                      style: ZapTypography.labelSmall.copyWith(
                        color: _modeColor,
                        fontFamily: 'IBMPlexMono',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: barFraction,
                        minHeight: 4,
                        backgroundColor: ZapColors.bgElevated,
                        color: _modeColor.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: ZapSpacing.lg),
              // Battery impact
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${entry.batteryImpactPct.toStringAsFixed(1)}%',
                    style: ZapTypography.labelSmall.copyWith(
                      color: ZapColors.textPrimary,
                      fontFamily: 'IBMPlexMono',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'battery / SOS',
                    style: ZapTypography.labelSmall.copyWith(
                      color: ZapColors.textMuted,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // ── Notes ─────────────────────────────────────────────────────
          if (entry.notes.isNotEmpty) ...[
            const SizedBox(height: ZapSpacing.sm),
            Text(
              entry.notes,
              style: ZapTypography.labelSmall.copyWith(
                color: ZapColors.textMuted,
                fontStyle: FontStyle.italic,
                fontSize: 11,
              ),
            ),
          ],

          // ── Tested date ───────────────────────────────────────────────
          if (entry.testedDate != null) ...[
            const SizedBox(height: ZapSpacing.xs),
            Text(
              'Tested ${_formatDate(entry.testedDate!)}',
              style: ZapTypography.labelSmall.copyWith(
                color: ZapColors.textMuted,
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

// ─── Empty filter result ──────────────────────────────────────────────────────

class _EmptyFilterResult extends StatelessWidget {
  const _EmptyFilterResult({required this.onClear});
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Column(
        children: [
          const Icon(Icons.filter_list_off_rounded,
              color: ZapColors.textMuted, size: 32),
          const SizedBox(height: ZapSpacing.sm),
          Text(
            'No devices match this filter',
            style: ZapTypography.labelMedium
                .copyWith(color: ZapColors.textSecondary),
          ),
          const SizedBox(height: ZapSpacing.sm),
          GestureDetector(
            onTap: onClear,
            child: Text(
              'Clear filter',
              style: ZapTypography.labelSmall.copyWith(
                color: ZapColors.info,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: ZapTypography.labelSmall.copyWith(
          color: ZapColors.textSecondary,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w600,
        ),
      );
}
