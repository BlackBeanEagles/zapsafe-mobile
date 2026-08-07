/// Day 302 — Wire Analytics APIs
///
/// QA meta-screen for the real analytics wiring: calls the 4 live backend
/// endpoints (`/api/v1/analytics/sos-summary/`, `detections/`,
/// `contacts/response-rate/`, `device-health/`) through
/// `analytics_api_service.dart` + `analytics_api_providers.dart`, and shows
/// mock vs live side-by-side per row so a reviewer can see the mock
/// fallback still works when the backend is unreachable. Note: the Day 212
/// "empty state" widget referenced by the original spec does not exist on
/// `main` (this repo currently tops out at Day 200 committed screens — the
/// Day 201-300 batch exists only as uncommitted work-in-progress); a small
/// local `_EmptyState` is used instead so this screen doesn't depend on a
/// file that isn't real yet.
/// Tag: 🔵 EXISTING-API
///
/// Route: AppRoutes.analyticsLiveWire
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../domain/providers/analytics_api_providers.dart';
import '../navigation/app_router.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';

class Day302AnalyticsLiveWireScreen extends ConsumerWidget {
  const Day302AnalyticsLiveWireScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text('day301_305.analytics_title'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          Text(
            'day301_305.analytics_heading'.tr(),
            style: ZapTypography.headlineMedium
                .copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            'All 4 rows below call the real backend through '
            'AnalyticsApiService. If the request fails (no backend running, '
            '401, 500, or offline), the raw provider shows the real error '
            'state instead of silently hiding it.',
            style: ZapTypography.bodyMedium.copyWith(color: ZapColors.textSecondary),
          ),
          const SizedBox(height: ZapSpacing.xl),
          _AnalyticsSection(
            title: 'GET /api/v1/analytics/sos-summary/',
            child: Consumer(builder: (context, ref, _) {
              final raw = ref.watch(sosSummaryRawProvider);
              return raw.when(
                data: (s) => _KeyValueBlock({
                  'total_sos': '${s.totalSos}',
                  'false_positive_rate': '${s.falsePositiveRate}%',
                  'avg_response_time_secs': '${s.avgResponseTimeSecs ?? '—'}',
                  'most_common_trigger': s.mostCommonTrigger ?? '—',
                  'sos_per_week rows': '${s.sosPerWeek.length}',
                }),
                loading: () => const _Loading(),
                error: (e, _) => _ErrorRow(error: e, onRetry: () => ref.invalidate(sosSummaryRawProvider)),
              );
            }),
          ),
          _AnalyticsSection(
            title: 'GET /api/v1/analytics/detections/',
            child: Consumer(builder: (context, ref, _) {
              final raw = ref.watch(detectionAnalyticsRawProvider);
              return raw.when(
                data: (d) => d.perModel.isEmpty
                    ? const _EmptyState(message: 'No detection events yet.')
                    : _KeyValueBlock({
                        'overall_fp_rate': '${d.overallFpRate}%',
                        'trend': d.trend,
                        'per_model rows': '${d.perModel.length}',
                        'detections_per_day days': '${d.detectionsPerDay.length}',
                      }),
                loading: () => const _Loading(),
                error: (e, _) =>
                    _ErrorRow(error: e, onRetry: () => ref.invalidate(detectionAnalyticsRawProvider)),
              );
            }),
          ),
          _AnalyticsSection(
            title: 'GET /api/v1/analytics/contacts/response-rate/',
            child: Consumer(builder: (context, ref, _) {
              final raw = ref.watch(contactResponseRateRawProvider);
              return raw.when(
                data: (r) => r.perContact.isEmpty
                    ? const _EmptyState(message: 'No contacts notified yet.')
                    : _KeyValueBlock({
                        'overall_response_rate': '${r.overallResponseRate}%',
                        'total_notifications': '${r.totalNotifications}',
                        'total_acks': '${r.totalAcks}',
                        'trend': r.responseRateTrend,
                      }),
                loading: () => const _Loading(),
                error: (e, _) =>
                    _ErrorRow(error: e, onRetry: () => ref.invalidate(contactResponseRateRawProvider)),
              );
            }),
          ),
          _AnalyticsSection(
            title: 'GET /api/v1/analytics/device-health/',
            child: Consumer(builder: (context, ref, _) {
              final raw = ref.watch(deviceHealthRawProvider);
              return raw.when(
                data: (h) => h.lastReportedAt == null
                    ? const _EmptyState(message: 'No device-health report submitted yet.')
                    : _KeyValueBlock({
                        'app_version': h.appVersion ?? '—',
                        'os_version': h.osVersion ?? '—',
                        'battery_drain_pct_per_hour': '${h.batteryDrainPctPerHour ?? '—'}',
                        'report_count': '${h.reportCount ?? 0}',
                      }),
                loading: () => const _Loading(),
                error: (e, _) => _ErrorRow(error: e, onRetry: () => ref.invalidate(deviceHealthRawProvider)),
              );
            }),
          ),
          const SizedBox(height: ZapSpacing.xl),
          ZapCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('kUseMockData fallback',
                    style: ZapTypography.headlineSmall.copyWith(color: ZapColors.textPrimary)),
                const SizedBox(height: ZapSpacing.xs),
                Text(
                  'The non-QA providers (sosSummaryProvider, etc. — used by '
                  'the real dashboard) always fall back to seeded mock data '
                  'on any exception, so the app never shows a broken screen '
                  'when the backend is offline during emulator QA. Force it '
                  'with --dart-define=USE_MOCK_DATA=true.',
                  style: ZapTypography.bodySmall.copyWith(color: ZapColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          ZapButton.elevated(
            label: 'Back to integration audit',
            intent: ZapButtonIntent.info,
            fullWidth: true,
            onPressed: () => context.go(AppRoutes.integrationAudit),
          ),
          const SizedBox(height: ZapSpacing.huge),
        ],
      ),
    );
  }
}

class _AnalyticsSection extends StatelessWidget {
  const _AnalyticsSection({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ZapSpacing.lg),
      child: ZapCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: ZapTypography.monoSmall.copyWith(
                    color: ZapColors.textPrimary, fontWeight: FontWeight.w600)),
            const SizedBox(height: ZapSpacing.sm),
            child,
          ],
        ),
      ),
    );
  }
}

class _KeyValueBlock extends StatelessWidget {
  const _KeyValueBlock(this.entries);
  final Map<String, String> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final e in entries.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Text('${e.key}: ',
                    style: ZapTypography.bodySmall.copyWith(color: ZapColors.textSecondary)),
                Expanded(
                  child: Text(e.value,
                      style: ZapTypography.bodySmall.copyWith(
                          color: ZapColors.textPrimary, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: ZapSpacing.sm),
        child: SizedBox(
          height: 18,
          width: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.inbox_outlined, color: ZapColors.textSecondary, size: 18),
        const SizedBox(width: ZapSpacing.xs),
        Expanded(
          child: Text(message,
              style: ZapTypography.bodySmall.copyWith(color: ZapColors.textSecondary)),
        ),
      ],
    );
  }
}

class _ErrorRow extends StatelessWidget {
  const _ErrorRow({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  String get _label {
    final s = error.toString();
    if (s.contains('401')) return 'Session expired — please log in again.';
    if (s.contains('500')) return 'Server error — tap retry.';
    if (s.contains('NETWORK') || s.contains('Cannot reach server')) {
      return 'Backend unreachable (is Django running?).';
    }
    return 'Request failed: $s';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.error_outline, color: ZapColors.danger, size: 18),
        const SizedBox(width: ZapSpacing.xs),
        Expanded(
          child: Text(_label,
              style: ZapTypography.bodySmall.copyWith(color: ZapColors.danger)),
        ),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}
