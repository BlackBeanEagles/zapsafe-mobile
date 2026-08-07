/// Day 366 — Live SOS Success Dashboard
///
/// Section M (Days 366-370, Post-Launch Week 1): SOS triggered count,
/// delivery success %, and avg acknowledgement time.
///
/// **There is no real launch, so there is no real usage yet.** This screen
/// wires the REAL Day 302 analytics endpoints — `sosSummaryRawProvider`
/// (`GET /api/v1/analytics/sos-summary/`) and `contactResponseRateRawProvider`
/// (`GET /api/v1/analytics/contacts/response-rate/`), both real, live,
/// wired Django endpoints checked directly against `analytics_api_service.dart`
/// and `analytics_api_providers.dart` — rather than fabricating a "MOCK-NOW"
/// dashboard with invented sample numbers. Since nothing has actually
/// launched, calling these for real legitimately returns zero/empty data
/// (or a network error if no backend is reachable from this environment) —
/// that is the CORRECT, honest state, not a bug to hide.
///
/// SOS triggered count → `SosSummary.totalSos`.
/// Avg ack time → `ContactResponseRate.avgAckTimeSecs`.
/// Delivery success % → `ContactResponseRate.overallResponseRate` (the
/// closest real field to "delivery success" — an ack from a trusted
/// contact is the actual signal this app has for "the alert was delivered
/// and someone responded").
///
/// Tag: 🟡 MOCK-NOW → upgraded to 🔵 EXISTING-API where a real endpoint
/// exists (both metrics do); no metric is fabricated.
///
/// Route: [AppRoutes.liveSosDashboard] → `/day-366-live-sos-dashboard`
library;

import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../domain/providers/analytics_api_providers.dart';
import '../navigation/app_router.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const _kAccent = Color(0xFFDC2626);
const _kJsonEncoder = JsonEncoder.withIndent('  ');

Map<String, dynamic> _wiringPayload() => {
      'sos_triggered_count_endpoint': 'GET /api/v1/analytics/sos-summary/',
      'delivery_success_pct_endpoint': 'GET /api/v1/analytics/contacts/response-rate/',
      'avg_ack_time_endpoint': 'GET /api/v1/analytics/contacts/response-rate/',
      'is_publicly_launched': false,
      'expected_state': 'zero/empty until real users exist, or a real network '
          'error if no backend is reachable — both are correct, not bugs',
      'wire_note': 'Real Day 302 endpoints, raw (no mock fallback) — same '
          'pattern as day338_sentry_live_wire_screen.dart',
    };

// ── Screen ────────────────────────────────────────────────────────────────────
class Day366LiveSosDashboardScreen extends ConsumerWidget {
  const Day366LiveSosDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(title: Text('day361_370.sos_dashboard_title'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(color: _kAccent.withOpacity(0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: _kAccent.withOpacity(0.3))),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_rounded, color: _kAccent, size: 20),
                SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    'These 3 metrics are wired to REAL backend endpoints (Day '
                    '302), not fabricated. Because there is no real launch yet, '
                    'they legitimately show zero, empty, or an error state — '
                    'that is correct, not broken.',
                    style: TextStyle(color: ZapColors.textPrimary, fontSize: 12, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          Consumer(builder: (context, ref, _) {
            final raw = ref.watch(sosSummaryRawProvider);
            return raw.when(
              data: (s) => _MetricCard(
                icon: Icons.emergency_rounded,
                label: 'SOS triggered count',
                endpoint: 'GET /api/v1/analytics/sos-summary/',
                value: '${s.totalSos}',
                empty: s.totalSos == 0,
                emptyMessage: 'No SOS sessions triggered yet — expected, since '
                    'no real launch has happened.',
              ),
              loading: () => const _MetricLoading(label: 'SOS triggered count'),
              error: (e, _) => _MetricError(label: 'SOS triggered count', error: e, onRetry: () => ref.invalidate(sosSummaryRawProvider)),
            );
          }),
          const SizedBox(height: ZapSpacing.md),
          Consumer(builder: (context, ref, _) {
            final raw = ref.watch(contactResponseRateRawProvider);
            return raw.when(
              data: (r) => _MetricCard(
                icon: Icons.check_circle_rounded,
                label: 'Delivery success % (contact ack rate)',
                endpoint: 'GET /api/v1/analytics/contacts/response-rate/',
                value: r.totalNotifications == 0 ? '—' : '${r.overallResponseRate}%',
                empty: r.totalNotifications == 0,
                emptyMessage: 'No contacts notified yet — expected, since no '
                    'real SOS session has fired for real.',
              ),
              loading: () => const _MetricLoading(label: 'Delivery success %'),
              error: (e, _) => _MetricError(label: 'Delivery success %', error: e, onRetry: () => ref.invalidate(contactResponseRateRawProvider)),
            );
          }),
          const SizedBox(height: ZapSpacing.md),
          Consumer(builder: (context, ref, _) {
            final raw = ref.watch(contactResponseRateRawProvider);
            return raw.when(
              data: (r) => _MetricCard(
                icon: Icons.timer_rounded,
                label: 'Avg acknowledgement time',
                endpoint: 'GET /api/v1/analytics/contacts/response-rate/',
                value: r.totalAcks == 0 ? '—' : '${r.avgAckTimeSecs}s',
                empty: r.totalAcks == 0,
                emptyMessage: 'No acknowledgements recorded yet.',
              ),
              loading: () => const _MetricLoading(label: 'Avg ack time'),
              error: (e, _) => _MetricError(label: 'Avg ack time', error: e, onRetry: () => ref.invalidate(contactResponseRateRawProvider)),
            );
          }),
          const SizedBox(height: ZapSpacing.xl),
          const Text('Wiring (real, no mock fallback)', style: TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: ZapSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(color: ZapColors.bgCard, borderRadius: BorderRadius.circular(8), border: Border.all(color: ZapColors.border)),
            child: SelectableText(_kJsonEncoder.convert(_wiringPayload()), style: const TextStyle(color: ZapColors.textSecondary, fontSize: 10, fontFamily: 'monospace', height: 1.45)),
          ),
          const SizedBox(height: ZapSpacing.sm),
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _kJsonEncoder.convert(_wiringPayload())));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wiring spec copied.')));
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy spec JSON'),
          ),
          const SizedBox(height: ZapSpacing.lg),
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(color: ZapColors.info.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: ZapColors.info.withOpacity(0.3))),
            child: const Text('Next: Day 367 — Ratings & Reviews Monitor (manual-paste tool).', style: TextStyle(color: ZapColors.textSecondary, fontSize: 13)),
          ),
          const SizedBox(height: ZapSpacing.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(label: const Text('Day 302 Analytics Live Wire'), onPressed: () => context.push(AppRoutes.analyticsLiveWire)),
              ActionChip(label: const Text('Day 365 Launch Preview'), onPressed: () => context.push(AppRoutes.publicLaunchMilestone)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.icon, required this.label, required this.endpoint, required this.value, required this.empty, required this.emptyMessage});
  final IconData icon;
  final String label;
  final String endpoint;
  final String value;
  final bool empty;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(color: ZapColors.bgCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: ZapColors.border)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _kAccent, size: 24),
          const SizedBox(width: ZapSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 12)),
                Text(endpoint, style: const TextStyle(color: ZapColors.textMuted, fontSize: 9, fontFamily: 'monospace')),
                const SizedBox(height: 6),
                Text(value, style: TextStyle(color: empty ? ZapColors.textMuted : ZapColors.textPrimary, fontWeight: FontWeight.w900, fontSize: 22)),
                if (empty) ...[
                  const SizedBox(height: 4),
                  Text(emptyMessage, style: const TextStyle(color: ZapColors.textMuted, fontSize: 10, height: 1.4)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricLoading extends StatelessWidget {
  const _MetricLoading({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(color: ZapColors.bgCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: ZapColors.border)),
      child: Row(
        children: [
          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: ZapSpacing.md),
          Text('Loading $label…', style: const TextStyle(color: ZapColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}

class _MetricError extends StatelessWidget {
  const _MetricError({required this.label, required this.error, required this.onRetry});
  final String label;
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(color: ZapColors.danger.withOpacity(0.06), borderRadius: BorderRadius.circular(10), border: Border.all(color: ZapColors.danger.withOpacity(0.35))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: ZapColors.danger, size: 20),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$label — request failed', style: const TextStyle(color: ZapColors.danger, fontWeight: FontWeight.w700, fontSize: 12)),
                Text('$error', style: const TextStyle(color: ZapColors.textMuted, fontSize: 10), maxLines: 2, overflow: TextOverflow.ellipsis),
                const Text('Real error state — no backend reachable from this environment, or 401/500. Not hidden behind a fake number.', style: TextStyle(color: ZapColors.textSecondary, fontSize: 10, height: 1.4)),
              ],
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry', style: TextStyle(fontSize: 11))),
        ],
      ),
    );
  }
}
