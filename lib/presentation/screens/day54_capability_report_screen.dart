/// Day 54 — Capability Report Screen.
///
/// Route: /capability-report
///
/// Closes the loop between the local probe (Day 52) and backend telemetry
/// (Day 54 API).  Two responsibilities:
///
///   1. SUBMIT — sends the current device's probe result to the backend
///      via POST /api/v1/ml/device-capability/.
///
///   2. HISTORY — lists all capability reports the authenticated user has
///      ever submitted via GET /api/v1/ml/device-capability/.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/services/capability_report_service.dart';
import '../../data/services/phone_capability_detector.dart';
import '../../domain/providers/capability_report_providers.dart';
import '../../domain/providers/inference_providers.dart';
import '../navigation/app_router.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';

// ─── Screen ───────────────────────────────────────────────────────────────────

class Day54CapabilityReportScreen extends ConsumerStatefulWidget {
  const Day54CapabilityReportScreen({super.key});

  @override
  ConsumerState<Day54CapabilityReportScreen> createState() =>
      _Day54CapabilityReportScreenState();
}

class _Day54CapabilityReportScreenState
    extends ConsumerState<Day54CapabilityReportScreen> {
  /// Tracks the in-flight / completed POST.
  /// - null         → not yet attempted
  /// - AsyncLoading → in progress
  /// - AsyncData    → success
  /// - AsyncError   → failed
  AsyncValue<CapabilityReportRecord>? _submitState;

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> _submit(CapabilityProbeResult probe) async {
    setState(() => _submitState = const AsyncLoading());
    try {
      final svc = ref.read(capabilityReportServiceProvider);
      final record = await svc.submit(probe);
      if (!mounted) return;
      setState(() => _submitState = AsyncData(record));
      // Refresh the history list so the new entry appears immediately.
      ref.invalidate(capabilityReportHistoryProvider);
    } catch (e, st) {
      if (!mounted) return;
      setState(() => _submitState = AsyncError(e, st));
    }
  }

  void _resetAndRetry(CapabilityProbeResult probe) {
    setState(() => _submitState = null);
    _submit(probe);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final capAsync     = ref.watch(phoneCapabilityProvider);
    final historyAsync = ref.watch(capabilityReportHistoryProvider);

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
            const Text('Capability Report',
                style: TextStyle(color: ZapColors.textPrimary)),
            const SizedBox(width: ZapSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: ZapSpacing.sm, vertical: 2),
              decoration: BoxDecoration(
                color: ZapColors.info.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'DAY 54',
                style: ZapTypography.labelSmall.copyWith(
                  color: ZapColors.info,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Your device ───────────────────────────────────────────────
            const _SectionLabel('YOUR DEVICE'),
            const SizedBox(height: ZapSpacing.sm),
            capAsync.when(
              loading: () => const _SkeletonCard(height: 140),
              error:   (e, _) => _ProbeError(error: e.toString()),
              data:    (probe) => _ProbeCard(probe: probe),
            ),
            const SizedBox(height: ZapSpacing.xl),

            // ── Submit section ────────────────────────────────────────────
            const _SectionLabel('SUBMIT TO BACKEND'),
            const SizedBox(height: ZapSpacing.sm),
            capAsync.when(
              loading: () => const SizedBox.shrink(),
              error:   (_, __) => const SizedBox.shrink(),
              data:    (probe) => _SubmitSection(
                probe:    probe,
                state:    _submitState,
                onSubmit: () => _submit(probe),
                onRetry:  () => _resetAndRetry(probe),
              ),
            ),
            const SizedBox(height: ZapSpacing.xl),

            // ── History ───────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const _SectionLabel('SUBMITTED REPORTS'),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded,
                      color: ZapColors.textSecondary, size: 18),
                  tooltip: 'Refresh history',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () =>
                      ref.invalidate(capabilityReportHistoryProvider),
                ),
              ],
            ),
            const SizedBox(height: ZapSpacing.sm),
            historyAsync.when(
              loading: () => const Column(
                children: [
                  _SkeletonCard(height: 88),
                  SizedBox(height: ZapSpacing.sm),
                  _SkeletonCard(height: 88),
                ],
              ),
              error: (e, _) => _HistoryError(
                error:   e.toString(),
                onRetry: () => ref.invalidate(capabilityReportHistoryProvider),
              ),
              data: (history) => history.count == 0
                  ? const _EmptyHistory()
                  : Column(
                      children: history.reports
                          .map(
                            (r) => Padding(
                              padding: const EdgeInsets.only(
                                  bottom: ZapSpacing.sm),
                              child: _ReportCard(record: r),
                            ),
                          )
                          .toList(),
                    ),
            ),
            const SizedBox(height: ZapSpacing.xxxl),
          ],
        ),
      ),
    );
  }
}

// ─── Section helpers ──────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: ZapTypography.labelSmall.copyWith(
        color: ZapColors.textSecondary,
        letterSpacing: 1.1,
        fontWeight: FontWeight.w600,
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
            height: 16,
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

// ─── Probe card ───────────────────────────────────────────────────────────────

class _ProbeCard extends StatelessWidget {
  const _ProbeCard({required this.probe});
  final CapabilityProbeResult probe;

  Color get _tierColor {
    switch (probe.tier) {
      case PhoneCapabilityTier.high:   return ZapColors.safe;
      case PhoneCapabilityTier.medium: return ZapColors.info;
      case PhoneCapabilityTier.low:    return ZapColors.warning;
    }
  }

  String get _tierLabel {
    switch (probe.tier) {
      case PhoneCapabilityTier.high:   return 'HIGH';
      case PhoneCapabilityTier.medium: return 'MEDIUM';
      case PhoneCapabilityTier.low:    return 'LOW';
    }
  }

  IconData get _tierIcon {
    switch (probe.tier) {
      case PhoneCapabilityTier.high:   return Icons.bolt_rounded;
      case PhoneCapabilityTier.medium: return Icons.speed_rounded;
      case PhoneCapabilityTier.low:    return Icons.memory_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Row(
        children: [
          // Tier icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _tierColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(_tierIcon, color: _tierColor, size: 28),
          ),
          const SizedBox(width: ZapSpacing.md),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: ZapSpacing.sm, vertical: 2),
                      decoration: BoxDecoration(
                        color: _tierColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _tierLabel,
                        style: ZapTypography.labelSmall.copyWith(
                          color: _tierColor,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(width: ZapSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: ZapSpacing.sm, vertical: 2),
                      decoration: BoxDecoration(
                        color: (probe.shouldUseAi
                                ? ZapColors.safe
                                : ZapColors.warning)
                            .withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        probe.shouldUseAi ? 'AI' : 'HEURISTIC',
                        style: ZapTypography.labelSmall.copyWith(
                          color: probe.shouldUseAi
                              ? ZapColors.safe
                              : ZapColors.warning,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ZapSpacing.xs),
                Text(
                  '${probe.inferenceMs.toStringAsFixed(1)} ms inference',
                  style: ZapTypography.headlineSmall.copyWith(
                    fontFamily: 'IBMPlexMono',
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  probe.tierLabel,
                  style: ZapTypography.bodySmall
                      .copyWith(color: ZapColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProbeError extends StatelessWidget {
  const _ProbeError({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: ZapColors.danger, size: 28),
          const SizedBox(width: ZapSpacing.md),
          Expanded(
            child: Text(
              'Probe unavailable — run Day 52 first.\n$error',
              style: ZapTypography.bodySmall
                  .copyWith(color: ZapColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Submit section ───────────────────────────────────────────────────────────

class _SubmitSection extends StatelessWidget {
  const _SubmitSection({
    required this.probe,
    required this.state,
    required this.onSubmit,
    required this.onRetry,
  });

  final CapabilityProbeResult probe;
  final AsyncValue<CapabilityReportRecord>? state;
  final VoidCallback onSubmit;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    // ── Loading ──────────────────────────────────────────────────────────────
    if (state is AsyncLoading) {
      return ZapCard(
        child: Row(
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                  color: ZapColors.info, strokeWidth: 2),
            ),
            const SizedBox(width: ZapSpacing.md),
            Text(
              'Submitting report…',
              style: ZapTypography.bodyMedium
                  .copyWith(color: ZapColors.textSecondary),
            ),
          ],
        ),
      );
    }

    // ── Success ───────────────────────────────────────────────────────────────
    if (state is AsyncData<CapabilityReportRecord>) {
      final record = (state as AsyncData<CapabilityReportRecord>).value;
      return _SuccessCard(record: record, onResubmit: onSubmit);
    }

    // ── Error ─────────────────────────────────────────────────────────────────
    if (state is AsyncError) {
      final err = (state as AsyncError).error;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ZapCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.cloud_off_rounded,
                    color: ZapColors.danger, size: 28),
                const SizedBox(height: ZapSpacing.sm),
                Text(
                  'Submission failed',
                  style: ZapTypography.labelLarge
                      .copyWith(color: ZapColors.danger),
                ),
                const SizedBox(height: ZapSpacing.xs),
                Text(
                  err.toString(),
                  style: ZapTypography.bodySmall
                      .copyWith(color: ZapColors.textSecondary),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          ZapButton(
            label: 'Retry Submit',
            icon: Icons.refresh_rounded,
            onPressed: onRetry,
            variant: ZapButtonVariant.elevated,
            intent: ZapButtonIntent.warning,
          ),
        ],
      );
    }

    // ── Idle (null state) ─────────────────────────────────────────────────────
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ZapCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.cloud_upload_outlined,
                  color: ZapColors.info, size: 28),
              const SizedBox(height: ZapSpacing.sm),
              Text(
                'Send this result to ZapSafe',
                style: ZapTypography.labelLarge
                    .copyWith(color: ZapColors.textPrimary),
              ),
              const SizedBox(height: ZapSpacing.xs),
              Text(
                'Your probe result helps the team understand the real-world '
                'device spread. No personal data is collected — only the '
                'inference speed, tier, and app version.',
                style: ZapTypography.bodySmall
                    .copyWith(color: ZapColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        ZapButton(
          label: 'Submit to Backend',
          icon: Icons.cloud_upload_rounded,
          onPressed: onSubmit,
          variant: ZapButtonVariant.elevated,
          intent: ZapButtonIntent.info,
        ),
      ],
    );
  }
}

class _SuccessCard extends StatelessWidget {
  const _SuccessCard({required this.record, required this.onResubmit});
  final CapabilityReportRecord record;
  final VoidCallback onResubmit;

  Color get _tierColor {
    switch (record.tier) {
      case 'high':   return ZapColors.safe;
      case 'medium': return ZapColors.info;
      default:       return ZapColors.warning;
    }
  }

  String get _tierBadge => record.tier.toUpperCase();

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy · HH:mm');
    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: ZapColors.safe, size: 28),
              const SizedBox(width: ZapSpacing.sm),
              Text(
                'Report submitted',
                style: ZapTypography.labelLarge
                    .copyWith(color: ZapColors.safe),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),

          // Tier row
          _InfoRow(
            label: 'Tier',
            value: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: ZapSpacing.sm, vertical: 2),
              decoration: BoxDecoration(
                color: _tierColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _tierBadge,
                style: ZapTypography.labelSmall.copyWith(
                  color: _tierColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          _InfoRow(
            label: 'Inference',
            value: Text(
              '${record.inferenceMs.toStringAsFixed(1)} ms',
              style: ZapTypography.bodyMedium.copyWith(
                fontFamily: 'IBMPlexMono',
                color: ZapColors.textPrimary,
              ),
            ),
          ),
          _InfoRow(
            label: 'Mode',
            value: Text(
              record.detectionMode == 'ai' ? 'AI (TFLite)' : 'Heuristic',
              style: ZapTypography.bodyMedium
                  .copyWith(color: ZapColors.textPrimary),
            ),
          ),
          if (record.deviceModel.isNotEmpty)
            _InfoRow(
              label: 'Device',
              value: Text(
                record.deviceModel,
                style: ZapTypography.bodyMedium
                    .copyWith(color: ZapColors.textPrimary),
              ),
            ),
          _InfoRow(
            label: 'Logged at',
            value: Text(
              fmt.format(record.createdAt),
              style: ZapTypography.bodySmall.copyWith(
                fontFamily: 'IBMPlexMono',
                color: ZapColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: ZapSpacing.md),

          // Re-submit link
          GestureDetector(
            onTap: onResubmit,
            child: Text(
              'Submit again',
              style: ZapTypography.labelSmall.copyWith(
                color: ZapColors.info,
                decoration: TextDecoration.underline,
                decorationColor: ZapColors.info,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: ZapTypography.labelSmall.copyWith(
                color: ZapColors.textSecondary,
              ),
            ),
          ),
          Expanded(child: value),
        ],
      ),
    );
  }
}

// ─── History ──────────────────────────────────────────────────────────────────

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Column(
        children: [
          const Icon(Icons.history_toggle_off_rounded,
              color: ZapColors.textSecondary, size: 40),
          const SizedBox(height: ZapSpacing.sm),
          Text(
            'No reports yet',
            style: ZapTypography.labelLarge
                .copyWith(color: ZapColors.textSecondary),
          ),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            'Submit your first report above.',
            style: ZapTypography.bodySmall
                .copyWith(color: ZapColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _HistoryError extends StatelessWidget {
  const _HistoryError({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ZapCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: ZapColors.danger, size: 28),
              const SizedBox(height: ZapSpacing.sm),
              Text(
                'Could not load history',
                style: ZapTypography.labelLarge
                    .copyWith(color: ZapColors.danger),
              ),
              const SizedBox(height: ZapSpacing.xs),
              Text(
                error,
                style: ZapTypography.bodySmall
                    .copyWith(color: ZapColors.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        ZapButton(
          label: 'Retry',
          icon: Icons.refresh_rounded,
          onPressed: onRetry,
          variant: ZapButtonVariant.elevated,
          intent: ZapButtonIntent.info,
        ),
      ],
    );
  }
}

/// One submitted report card in the history list.
class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.record});
  final CapabilityReportRecord record;

  Color get _tierColor {
    switch (record.tier) {
      case 'high':   return ZapColors.safe;
      case 'medium': return ZapColors.info;
      default:       return ZapColors.warning;
    }
  }

  IconData get _tierIcon {
    switch (record.tier) {
      case 'high':   return Icons.bolt_rounded;
      case 'medium': return Icons.speed_rounded;
      default:       return Icons.memory_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM · HH:mm');
    return ZapCard(
      child: Row(
        children: [
          // Tier icon dot
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _tierColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(_tierIcon, color: _tierColor, size: 22),
          ),
          const SizedBox(width: ZapSpacing.md),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Tier badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: _tierColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        record.tier.toUpperCase(),
                        style: ZapTypography.labelSmall.copyWith(
                          color: _tierColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(width: ZapSpacing.xs),
                    // Mode badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: (record.detectionMode == 'ai'
                                ? ZapColors.safe
                                : ZapColors.warning)
                            .withOpacity(0.10),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        record.detectionMode == 'ai' ? 'AI' : 'HEURISTIC',
                        style: ZapTypography.labelSmall.copyWith(
                          color: record.detectionMode == 'ai'
                              ? ZapColors.safe
                              : ZapColors.warning,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${record.inferenceMs.toStringAsFixed(1)} ms'
                  '${record.deviceModel.isNotEmpty ? '  ·  ${record.deviceModel}' : ''}',
                  style: ZapTypography.bodyMedium.copyWith(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (record.osName.isNotEmpty)
                  Text(
                    '${record.osName}${record.osVersion.isNotEmpty ? ' ${record.osVersion}' : ''}',
                    style: ZapTypography.bodySmall
                        .copyWith(color: ZapColors.textSecondary, fontSize: 11),
                  ),
              ],
            ),
          ),

          // Timestamp
          Text(
            fmt.format(record.createdAt),
            style: ZapTypography.labelSmall.copyWith(
              fontFamily: 'IBMPlexMono',
              color: ZapColors.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
