/// Day 386 — Analytics Month 1 Report
///
/// Section O (Days 381-390, Project Close): a real report TEMPLATE for a
/// "Month 1" that has not happened — there is no real public launch, so
/// there is no real Month 1 of usage data to report on. Wires the same 4
/// real backend endpoints Day 302 verified
/// (`day302_analytics_live_wire_screen.dart` — read directly before
/// building this) through the same `analytics_api_providers.dart` raw
/// providers, laid out as a monthly-report document instead of Day 302's
/// per-endpoint QA rows.
///
/// **This will legitimately show empty/zero (or a real network error if
/// the backend isn't running), and that is correct, not a bug.** No
/// number here is fabricated to look like a populated report — every
/// value comes straight from the real `AnalyticsApiService` response, or
/// is explicitly labeled "no data" when the response is empty.
///
/// Tag: 🟢 real backend wiring (same 4 endpoints Day 302 verified) ·
/// template for a Month 1 that has not happened · honest empty state.
///
/// Route: [AppRoutes.analyticsMonth1] → `/day-386-analytics-month1`
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../domain/providers/analytics_api_providers.dart';
import '../navigation/app_router.dart';

const _kAccent = Color(0xFF3B82F6);

class Day386AnalyticsMonth1Screen extends ConsumerWidget {
  const Day386AnalyticsMonth1Screen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(title: Text('day381_390.analytics_month1_title'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(color: ZapColors.danger.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: ZapColors.danger.withOpacity(0.35), width: 2)),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.gpp_bad_rounded, color: ZapColors.danger, size: 20),
                SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    'There is no real Month 1 — the app has not launched. This is a '
                    'REPORT TEMPLATE, wired to the same 4 real backend endpoints Day '
                    '302 verified. Every section below shows the real response — '
                    'empty/zero is correct, not a bug.',
                    style: TextStyle(color: ZapColors.textPrimary, fontSize: 12, height: 1.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          const Text('MONTH 1 SAFETY REPORT (template)', style: TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: ZapSpacing.lg),
          _ReportSection(
            title: 'SOS activity — GET /api/v1/analytics/sos-summary/',
            child: Consumer(builder: (context, ref, _) {
              final raw = ref.watch(sosSummaryRawProvider);
              return raw.when(
                data: (s) => s.totalSos == 0
                    ? const _EmptyRow(message: 'No SOS activations in this period. Real value: 0.')
                    : _KeyValueBlock({
                        'total_sos': '${s.totalSos}',
                        'false_positive_rate': '${s.falsePositiveRate}%',
                        'avg_response_time_secs': '${s.avgResponseTimeSecs ?? '—'}',
                        'most_common_trigger': s.mostCommonTrigger ?? '—',
                      }),
                loading: () => const _Loading(),
                error: (e, _) => _ErrorRow(error: e, onRetry: () => ref.invalidate(sosSummaryRawProvider)),
              );
            }),
          ),
          _ReportSection(
            title: 'Detection model performance — GET /api/v1/analytics/detections/',
            child: Consumer(builder: (context, ref, _) {
              final raw = ref.watch(detectionAnalyticsRawProvider);
              return raw.when(
                data: (d) => d.perModel.isEmpty
                    ? const _EmptyRow(message: 'No detection events this period. Real value: 0 rows.')
                    : _KeyValueBlock({
                        'overall_fp_rate': '${d.overallFpRate}%',
                        'trend': d.trend,
                        'per_model rows': '${d.perModel.length}',
                      }),
                loading: () => const _Loading(),
                error: (e, _) => _ErrorRow(error: e, onRetry: () => ref.invalidate(detectionAnalyticsRawProvider)),
              );
            }),
          ),
          _ReportSection(
            title: 'Trusted contact responsiveness — GET /api/v1/analytics/contacts/response-rate/',
            child: Consumer(builder: (context, ref, _) {
              final raw = ref.watch(contactResponseRateRawProvider);
              return raw.when(
                data: (r) => r.perContact.isEmpty
                    ? const _EmptyRow(message: 'No contacts notified this period. Real value: 0.')
                    : _KeyValueBlock({
                        'overall_response_rate': '${r.overallResponseRate}%',
                        'total_notifications': '${r.totalNotifications}',
                        'total_acks': '${r.totalAcks}',
                      }),
                loading: () => const _Loading(),
                error: (e, _) => _ErrorRow(error: e, onRetry: () => ref.invalidate(contactResponseRateRawProvider)),
              );
            }),
          ),
          _ReportSection(
            title: 'Device health snapshot — GET /api/v1/analytics/device-health/',
            child: Consumer(builder: (context, ref, _) {
              final raw = ref.watch(deviceHealthRawProvider);
              return raw.when(
                data: (h) => h.lastReportedAt == null
                    ? const _EmptyRow(message: 'No device-health report submitted this period.')
                    : _KeyValueBlock({
                        'app_version': h.appVersion ?? '—',
                        'last_reported_at': h.lastReportedAt ?? '—',
                        'report_count': '${h.reportCount ?? 0}',
                      }),
                loading: () => const _Loading(),
                error: (e, _) => _ErrorRow(error: e, onRetry: () => ref.invalidate(deviceHealthRawProvider)),
              );
            }),
          ),
          const SizedBox(height: ZapSpacing.xl),
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(color: ZapColors.info.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: ZapColors.info.withOpacity(0.3))),
            child: const Text(
              'When a real Month 1 exists, this exact template renders it — no code '
              'changes needed, since it already reads the real live endpoints. Day '
              '387 (Year in Review v2) extends this same honesty pattern for an '
              'annual view.',
              style: TextStyle(color: ZapColors.textSecondary, fontSize: 11, height: 1.4),
            ),
          ),
          const SizedBox(height: ZapSpacing.lg),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ActionChip(label: const Text('Day 302 Wiring QA'), onPressed: () => context.push(AppRoutes.analyticsLiveWire)),
            ActionChip(label: const Text('Day 387 Year in Review v2'), onPressed: () => context.push(AppRoutes.yearInReviewV2)),
          ]),
        ],
      ),
    );
  }
}

class _ReportSection extends StatelessWidget {
  const _ReportSection({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: ZapSpacing.md),
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(color: ZapColors.bgCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: ZapColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: _kAccent, fontWeight: FontWeight.w800, fontSize: 11, fontFamily: 'monospace')),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _KeyValueBlock extends StatelessWidget {
  const _KeyValueBlock(this.data);
  final Map<String, String> data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: data.entries.map((e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(children: [
              Expanded(child: Text(e.key, style: const TextStyle(color: ZapColors.textMuted, fontSize: 11))),
              Text(e.value, style: const TextStyle(color: ZapColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w700)),
            ]),
          )).toList(),
    );
  }
}

class _EmptyRow extends StatelessWidget {
  const _EmptyRow({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Text(message, style: const TextStyle(color: ZapColors.textMuted, fontSize: 11, fontStyle: FontStyle.italic));
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2));
}

class _ErrorRow extends StatelessWidget {
  const _ErrorRow({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text('Real error: $error', style: const TextStyle(color: ZapColors.danger, fontSize: 10), maxLines: 2, overflow: TextOverflow.ellipsis)),
        TextButton(onPressed: onRetry, child: const Text('Retry', style: TextStyle(fontSize: 11))),
      ],
    );
  }
}
