/// Day 372 — Performance at Scale Report
///
/// Section N (Days 371-380, Scale & Stabilize): a readiness assessment for
/// a hypothetical 10,000-user scale, built from three inputs:
///
/// 1. **DAU** — there is no real launch, so there are no real daily active
///    users. The number shown is a single, clearly-labeled EXAMPLE
///    (illustrative only), never presented as a real measurement.
/// 2. **API latency / error rate** — real, working manual-paste inputs.
///    Nothing here is auto-fetched from a live monitoring dashboard
///    (none exists yet); you paste in real numbers whenever you have them
///    (e.g. from a real backend load-test run or a real APM tool).
/// 3. **The one genuinely real data point available today**: Day 257's
///    real production load test (`zapsafe_backend/ops/
///    LOAD_TEST_RESULTS_DAY257.md`, read directly this session) —
///    ~34 req/s sustained throughput, P95 430ms at 50 concurrent Locust
///    users, 0.00% errors, degraded-but-not-broken at 100 concurrent, on
///    the single 2-OCPU Oracle Always-Free VM. That doc's own conclusion
///    is quoted, not reworded: 10,000 concurrent is "not achievable on
///    this hardware," and a Locust user maps to many real app users
///    since real users idle between actions — so the honest translation
///    of that ceiling into a "real DAU" figure does not exist yet either.
///
/// Tag: 🟢 real manual-paste tool + one real cited data point · DAU
/// example clearly labeled, never treated as real.
///
/// Route: [AppRoutes.performanceScaleReport] → `/day-372-performance-scale`
library;

import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const _kAccent = ZapColors.info;
const _kJsonEncoder = JsonEncoder.withIndent('  ');
const _kExampleDau = 0; // no real launch → no real DAU; example shown separately in UI copy

// Real, read directly from zapsafe_backend/ops/LOAD_TEST_RESULTS_DAY257.md
// this session — not invented.
const _kDay257ReqPerSec = 34;
const _kDay257P50Ms50Users = 88;
const _kDay257P95Ms50Users = 430;
const _kDay257ErrorPct50Users = 0.0;
const _kDay257P50Ms100Users = 1100;
const _kDay257P95Ms100Users = 2500;
const _kDay257ErrorPct100Users = 0.0;

Map<String, dynamic> _payload({required String pastedLatency, required String pastedErrorRate}) => {
      'dau_example_only': _kExampleDau,
      'dau_is_real': false,
      'pasted_api_latency_p95_ms': pastedLatency.isEmpty ? null : pastedLatency,
      'pasted_error_rate_pct': pastedErrorRate.isEmpty ? null : pastedErrorRate,
      'real_day257_production_data': {
        'sustained_req_per_sec': _kDay257ReqPerSec,
        'p50_ms_at_50_concurrent': _kDay257P50Ms50Users,
        'p95_ms_at_50_concurrent': _kDay257P95Ms50Users,
        'error_pct_at_50_concurrent': _kDay257ErrorPct50Users,
        'p50_ms_at_100_concurrent': _kDay257P50Ms100Users,
        'p95_ms_at_100_concurrent': _kDay257P95Ms100Users,
        'error_pct_at_100_concurrent': _kDay257ErrorPct100Users,
        'ten_thousand_concurrent_achievable_on_current_hardware': false,
        'source': 'zapsafe_backend/ops/LOAD_TEST_RESULTS_DAY257.md',
      },
      'wire_note': 'Real manual-paste tool. DAU is an illustrative example '
          'only, never real. Latency/error rate are whatever you paste in. '
          'The Day 257 block is the one genuinely real data point that '
          'exists today.',
    };

// ── Providers ─────────────────────────────────────────────────────────────────
final _d372LatencyProvider = StateProvider<String>((ref) => '');
final _d372ErrorRateProvider = StateProvider<String>((ref) => '');

// ── Screen ────────────────────────────────────────────────────────────────────
class Day372PerformanceScaleScreen extends ConsumerWidget {
  const Day372PerformanceScaleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latency = ref.watch(_d372LatencyProvider);
    final errorRate = ref.watch(_d372ErrorRateProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(title: Text('day371_380.performance_scale_title'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(color: _kAccent.withOpacity(0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: _kAccent.withOpacity(0.3))),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.speed_rounded, color: _kAccent, size: 20),
                SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    'A readiness assessment for a HYPOTHETICAL 10,000-user '
                    'scale. There is no real launch, so no real DAU exists — '
                    'that field is a labeled example only. Latency/error rate '
                    'are real manual-paste inputs. The one genuinely real '
                    'data point available today is Day 257\'s real production '
                    'load test, shown below.',
                    style: TextStyle(color: ZapColors.textPrimary, fontSize: 12, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),

          const Text('1. Daily Active Users', style: TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: ZapSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(color: ZapColors.warning.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: ZapColors.warning.withOpacity(0.35))),
            child: const Row(
              children: [
                Icon(Icons.groups_rounded, color: ZapColors.warning),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('EXAMPLE — illustrative only, not real: 10,000 DAU', style: TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
                      SizedBox(height: 2),
                      Text('Real DAU is currently 0 because there is no real launch. This card exists to show what a 10K-scale readiness target looks like.', style: TextStyle(color: ZapColors.textMuted, fontSize: 11, height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),

          const Text('2. API latency (manual paste)', style: TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: 4),
          const Text('Paste a real P95 latency figure (ms) from a real load-test run or APM tool.', style: TextStyle(color: ZapColors.textMuted, fontSize: 11)),
          const SizedBox(height: ZapSpacing.sm),
          TextField(
            keyboardType: TextInputType.number,
            onChanged: (v) => ref.read(_d372LatencyProvider.notifier).state = v,
            style: const TextStyle(color: ZapColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'e.g. 430 (ms)',
              filled: true, fillColor: ZapColors.bgCard,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),

          const Text('3. Error rate (manual paste)', style: TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: 4),
          const Text('Paste a real error rate percentage from a real load-test run.', style: TextStyle(color: ZapColors.textMuted, fontSize: 11)),
          const SizedBox(height: ZapSpacing.sm),
          TextField(
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (v) => ref.read(_d372ErrorRateProvider.notifier).state = v,
            style: const TextStyle(color: ZapColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'e.g. 0.0 (%)',
              filled: true, fillColor: ZapColors.bgCard,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),

          const Text('4. Real data point: Day 257 production load test', style: TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: 4),
          const Text('The only real production performance measurement that exists today.', style: TextStyle(color: ZapColors.textMuted, fontSize: 11)),
          const SizedBox(height: ZapSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(color: ZapColors.bgCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: ZapColors.safe.withOpacity(0.35))),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MetricRow('Sustained throughput', '$_kDay257ReqPerSec req/s'),
                _MetricRow('P50 @ 50 concurrent', '${_kDay257P50Ms50Users}ms'),
                _MetricRow('P95 @ 50 concurrent', '${_kDay257P95Ms50Users}ms'),
                _MetricRow('Error rate @ 50 concurrent', '$_kDay257ErrorPct50Users%'),
                _MetricRow('P95 @ 100 concurrent', '${_kDay257P95Ms100Users}ms (degraded, not broken)'),
                _MetricRow('Error rate @ 100 concurrent', '$_kDay257ErrorPct100Users%'),
                Divider(color: ZapColors.border, height: 20),
                Text(
                  '"10,000 concurrent is not achievable on this hardware" — '
                  'quoted directly from the real doc. A Locust user is not a '
                  'real app user (real users idle between actions), so the '
                  'honest translation to a real DAU ceiling does not exist '
                  'yet — that needs real traffic data after launch.',
                  style: TextStyle(color: ZapColors.textMuted, fontSize: 11, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),

          FilledButton.icon(
            onPressed: () {
              final report = 'ZapSafe Performance at Scale Report — Day 372\n\n'
                  'DAU: EXAMPLE ONLY, not real (real launch has not happened)\n'
                  'Pasted API latency (P95): ${latency.isEmpty ? "(not entered)" : "$latency ms"}\n'
                  'Pasted error rate: ${errorRate.isEmpty ? "(not entered)" : "$errorRate%"}\n\n'
                  'Real Day 257 production data:\n'
                  '  Sustained throughput: $_kDay257ReqPerSec req/s\n'
                  '  P95 @ 50 concurrent: ${_kDay257P95Ms50Users}ms, $_kDay257ErrorPct50Users% errors\n'
                  '  P95 @ 100 concurrent: ${_kDay257P95Ms100Users}ms, $_kDay257ErrorPct100Users% errors (degraded, not broken)\n'
                  '  10,000 concurrent: not achievable on current hardware\n';
              Clipboard.setData(ClipboardData(text: report));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report copied.')));
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy report'),
            style: FilledButton.styleFrom(backgroundColor: _kAccent, minimumSize: const Size(double.infinity, 48)),
          ),
          const SizedBox(height: ZapSpacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(color: ZapColors.bgCard, borderRadius: BorderRadius.circular(8), border: Border.all(color: ZapColors.border)),
            child: SelectableText(_kJsonEncoder.convert(_payload(pastedLatency: latency, pastedErrorRate: errorRate)), style: const TextStyle(color: ZapColors.textSecondary, fontSize: 10, fontFamily: 'monospace', height: 1.45)),
          ),
          const SizedBox(height: ZapSpacing.lg),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ActionChip(label: const Text('Day 379 10K Readiness Gate'), onPressed: () => context.push(AppRoutes.tenKUsersGate)),
            ActionChip(label: const Text('Day 371 Rollout Checklist'), onPressed: () => context.push(AppRoutes.rollout100Checklist)),
          ]),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: ZapColors.textMuted, fontSize: 12)),
          Text(value, style: const TextStyle(color: ZapColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
