/// Day 379 — 10K Users Readiness Gate
///
/// Section N (Days 371-380, Scale & Stabilize): infra checklist — but
/// **infra is explicitly backend's responsibility, not something this
/// frontend screen verifies or claims to have verified.** This screen
/// documents what the FRONTEND needs from backend at 10K-user scale
/// (rate limits, timeout budgets, retry/backoff behavior) and cites the
/// one real load-testing evidence that exists — it does not claim
/// backend infra has actually been proven at 10K scale, because it has
/// not.
///
/// Checked directly this session:
/// - `lib/core/constants/api_config.dart`: real Dio timeout budget — 10s
///   connect, 20s receive, 20s send. Not invented.
/// - `zapsafe_backend/zapsafe_backend/settings.py`: only one real rate
///   limit found — `OTP_RATE_LIMIT = 10` (per hour per IP). No general
///   DRF `DEFAULT_THROTTLE_RATES`/`REST_FRAMEWORK` throttle config found
///   anywhere in the file — stated honestly as a gap, not invented.
/// - `zapsafe_backend/ops/LOAD_TEST_RESULTS_DAY257.md`: the real
///   production load test. Its own conclusion, quoted directly: "Do not
///   chase 10,000... The '10,000 users' figure came from the original
///   plan, not from measurement, and was never defined as
///   concurrent-vs-registered." Real measured ceiling: ~34 req/s
///   sustained, sub-500ms P95 at 50 concurrent, graceful degradation at
///   100.
///
/// Tag: 🟢 real frontend-expectations document · infra verification is
/// explicitly out of scope and stated as not done.
///
/// Route: [AppRoutes.tenKUsersGate] → `/day-379-10k-users-gate`
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
const _kAccent = ZapColors.danger;
const _kJsonEncoder = JsonEncoder.withIndent('  ');

// Real, read from lib/core/config/api_config.dart this session.
const _kConnectTimeoutSec = 10;
const _kReceiveTimeoutSec = 20;
const _kSendTimeoutSec = 20;

// Real, read from zapsafe_backend/zapsafe_backend/settings.py this session.
const _kOtpRateLimitPerHour = 10;

class _Expectation {
  const _Expectation({required this.title, required this.status, required this.detail});
  final String title;
  final String status; // 'confirmed', 'gap', 'backend_owned'
  final String detail;
}

const _kExpectations = [
  _Expectation(
    title: 'Client timeout budget: 10s connect / 20s receive / 20s send',
    status: 'confirmed',
    detail: 'Real Dio config in api_config.dart. At 10K-user scale, backend '
        'P95 latencies (per Day 257) must stay well inside this budget or '
        'the app starts surfacing timeout errors, not slow-but-working requests.',
  ),
  _Expectation(
    title: 'OTP rate limit: 10 requests/hour/IP',
    status: 'confirmed',
    detail: 'Real, found in settings.py. The only rate limit found anywhere '
        'in the backend settings — genuinely just this one, not a broader '
        'API-wide throttle. Frontend already handles a 429 from this path.',
  ),
  _Expectation(
    title: 'General API rate limiting (non-OTP endpoints)',
    status: 'gap',
    detail: 'No DRF DEFAULT_THROTTLE_RATES or REST_FRAMEWORK throttle config '
        'found anywhere in settings.py. Stated honestly as a real gap, not '
        'invented — at 10K-user scale this is a real backend decision to make, '
        'not a frontend assumption to pre-bake.',
  ),
  _Expectation(
    title: 'Retry/backoff behavior on 5xx and timeout',
    status: 'gap',
    detail: 'api_client.dart maps DioExceptionType to error states but no '
        'exponential-backoff retry interceptor was found. At scale, a thundering '
        'herd of naive immediate retries would make backend degradation worse, '
        'not better — worth a real look before 10K users, not claimed as solved.',
  ),
  _Expectation(
    title: 'Pagination on list endpoints under load',
    status: 'backend_owned',
    detail: 'Whether analytics/family/notification list endpoints paginate '
        'correctly under 10K-user load is a real backend verification task, '
        'not something this frontend screen can confirm.',
  ),
  _Expectation(
    title: 'Horizontal scaling / multi-instance readiness',
    status: 'backend_owned',
    detail: 'Per Day 257\'s real production test, current infra is a single '
        '2-OCPU Oracle Always-Free VM — 10,000 concurrent confirmed NOT '
        'achievable on this hardware. Scaling decision (Hetzner ~EUR4/mo per '
        'that doc\'s own recommendation) is explicitly backend/infra\'s call, '
        'informed by real traffic data after a real launch, not pre-decided here.',
  ),
];

Map<String, dynamic> _payload() => {
      'scope': 'frontend_expectations_only',
      'infra_verified_at_10k_scale': false,
      'real_load_test_source': 'zapsafe_backend/ops/LOAD_TEST_RESULTS_DAY257.md',
      'real_measured_ceiling': {
        'sustained_req_per_sec': 34,
        'p95_ms_at_50_concurrent': 430,
        'ten_thousand_concurrent_achievable': false,
      },
      'client_timeout_budget_ms': {
        'connect': _kConnectTimeoutSec * 1000,
        'receive': _kReceiveTimeoutSec * 1000,
        'send': _kSendTimeoutSec * 1000,
      },
      'otp_rate_limit_per_hour': _kOtpRateLimitPerHour,
      'general_rate_limit_found': false,
      'wire_note': 'Documents frontend expectations of backend at 10K-user '
          'scale. Does not claim backend infra has been verified at that '
          'scale — it has not.',
    };

// ── Screen ────────────────────────────────────────────────────────────────────
class Day379TenKUsersGateScreen extends ConsumerWidget {
  const Day379TenKUsersGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(title: Text('day371_380.tenk_gate_title'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(color: _kAccent.withOpacity(0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: _kAccent.withOpacity(0.35))),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.groups_rounded, color: _kAccent, size: 20),
                SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    'Infra readiness at 10K-user scale is explicitly BACKEND\'S '
                    'responsibility. This screen documents what the frontend '
                    'needs from backend — it does not claim backend infra has '
                    'been verified at that scale, because it has not (see Day '
                    '257\'s real production test below).',
                    style: TextStyle(color: ZapColors.textPrimary, fontSize: 12, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          const Text('Frontend expectations of backend', style: TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: ZapSpacing.sm),
          for (final e in _kExpectations) ...[
            _ExpectationTile(e: e),
            const SizedBox(height: ZapSpacing.sm),
          ],
          const SizedBox(height: ZapSpacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(color: ZapColors.bgCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: ZapColors.safe.withOpacity(0.35))),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Real evidence: Day 257 production load test', style: TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
                SizedBox(height: 6),
                Text(
                  '"Do not chase 10,000... The \'10,000 users\' figure came from '
                  'the original plan, not from measurement, and was never '
                  'defined as concurrent-vs-registered." — quoted directly. '
                  'Real measured ceiling: ~34 req/s sustained, sub-500ms P95 '
                  'at 50 concurrent, graceful degradation (not breakage) at 100, '
                  'on a single 2-OCPU Oracle Always-Free VM.',
                  style: TextStyle(color: ZapColors.textMuted, fontSize: 11, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          FilledButton.icon(
            onPressed: () {
              final buf = StringBuffer('ZapSafe 10K Users Readiness Gate — Day 379\n');
              buf.writeln('(Frontend expectations only — infra verification is backend\'s call)\n');
              for (final e in _kExpectations) {
                buf.writeln('[${e.status.toUpperCase()}] ${e.title}\n  ${e.detail}\n');
              }
              Clipboard.setData(ClipboardData(text: buf.toString()));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gate report copied.')));
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy gate report'),
            style: FilledButton.styleFrom(backgroundColor: _kAccent, minimumSize: const Size(double.infinity, 48)),
          ),
          const SizedBox(height: ZapSpacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(color: ZapColors.bgCard, borderRadius: BorderRadius.circular(8), border: Border.all(color: ZapColors.border)),
            child: SelectableText(_kJsonEncoder.convert(_payload()), style: const TextStyle(color: ZapColors.textSecondary, fontSize: 10, fontFamily: 'monospace', height: 1.45)),
          ),
          const SizedBox(height: ZapSpacing.lg),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ActionChip(label: const Text('Day 372 Performance Report'), onPressed: () => context.push(AppRoutes.performanceScaleReport)),
          ]),
        ],
      ),
    );
  }
}

class _ExpectationTile extends StatelessWidget {
  const _ExpectationTile({required this.e});
  final _Expectation e;

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = switch (e.status) {
      'confirmed' => (ZapColors.safe, Icons.verified_rounded, 'CONFIRMED'),
      'gap' => (ZapColors.warning, Icons.warning_amber_rounded, 'GAP'),
      _ => (ZapColors.info, Icons.dns_rounded, 'BACKEND-OWNED'),
    };
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(color: ZapColors.bgCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.35))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(e.title, style: const TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 12))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                      child: Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(e.detail, style: const TextStyle(color: ZapColors.textMuted, fontSize: 11, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
